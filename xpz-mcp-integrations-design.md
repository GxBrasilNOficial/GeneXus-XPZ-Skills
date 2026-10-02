# xpz-mcp-integrations — design da skill (v1)

## Papel do documento

Design **vivo** (não congelado) da skill nova `xpz-mcp-integrations`. Registra as decisões
travadas na sessão de planejamento de **2026-10-02** e a evidência empírica coletada nela.
É o insumo de handoff: a implementação acontece em sessão própria. **A revisão por pares do
design (fase F0) ainda está pendente** — pela norma do repositório, nenhuma implementação
começa antes dela.

Este documento **não** é doc operacional da skill. Quando a skill existir, o contrato
operacional vive em `xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ que têm acesso ao **Jev/System One** (modelo de decisão do TypeSafe,
exposto por MCP) não dispõem hoje de um caminho gerenciado para instalar, auditar, reparar,
atualizar e remover esse componente MCP nos clientes de agente. A configuração validada na
máquina de referência é manual e **não é portátil** (path absoluto pessoal + `npx` flutuante).

A skill `xpz-skills-setup` **não** cobre esse domínio: ela registra skills XPZ, instrucionais
globais, `nexa`/`gam`, bootstrap git e o MCP **interno** `xpz-global-instructions` do Cursor —
não gerencia MCP de terceiros. Por isso a frente nasce como skill dedicada.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`.
- **Clientes:** OpenCode e Codex.
- **Ciclo:** detectar → instalar (vendorizado) → auditar → reparar → atualizar (consciente) →
  remover.
- **Credencial:** cofre neutro da própria skill (não preso a nenhum cliente).
- **Público:** comunidade (repo público `GxBrasilNOficial`).

## Não-escopo da v1

- **Fork** do pacote (avaliado; adiado para outro dia).
- Cursor e Claude Code (fases seguintes).
- Instalar as ferramentas de agente (Codex, OpenCode, Cursor, Claude Code).
- Criar conta, assinatura ou aceitar termos por conta do usuário.
- Instalar automaticamente a skill de agente que o pacote do Jev distribui (`skills/jev/`).
- Configurar uso automático do Jev pelos agentes.
- Gerenciar MCPs sem descritor.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome da skill | `xpz-mcp-integrations` |
| 2 | Runtime do componente | pacote **vendorizado** e pinado; **sem `npx`** no início |
| 3 | Node ausente | **detectar** e **oferecer** instalar via `winget`, sempre com aprovação explícita |
| 4 | Escopo v1 | **OpenCode + Codex** |
| 5 | Credencial | **cofre neutro da skill**; env como override; `auth.json` do OpenCode só importação opcional |
| 6 | Fornecedor | presets do pacote + modo **`compatible`** para terceiros informados na hora |
| 7 | Fork | **não** na v1 |
| 8 | Público | comunidade (doc neutra, sem path pessoal, ausência de Jev não é erro) |

## Arquitetura

### Motor genérico dirigido por descritor

O motor conhece o conceito «componente MCP externo» — comando, transporte stdio, mapa de
variáveis de ambiente, fonte de credencial, clientes suportados e passos de validação. Cada
componente é um **descritor de dados** (ex.: `components/jev.json`). Jev é o 1º descritor;
adicionar fornecedor/cliente é acrescentar dado, não reescrever a solução.

### Fronteira com `xpz-skills-setup`

- `xpz-skills-setup`: registro de skills XPZ, instrucionais globais, `nexa`/`gam`, bootstrap
  git, MCP **interno** `xpz-global-instructions` do Cursor.
- `xpz-mcp-integrations`: componentes MCP **externos opcionais**.
- Como ambas podem tocar os mesmos arquivos de cliente (`opencode.jsonc`, `config.toml`,
  `~/.cursor/mcp.json`), vale a regra: **merge sempre**, preservando comentários e demais
  servidores; **backup** antes de escrever; **nunca** remover entrada de outro dono.
- `xpz-skills-setup/SKILL.md` deve ganhar um ponteiro para esta skill (no padrão do ponteiro
  do `reviewer-ro`, mas com motor real).

### Scripts

Seguem a convenção do repositório: motores compartilhados em `scripts/`, exemplos/molde na
pasta da skill. Frentes previstas (nomes provisórios):

- auditoria read-only do componente × cliente;
- instalador/reparador com merge (JSONC do OpenCode; TOML do Codex) + backup + idempotência;
- desinstalador (remove entrada e wrapper gerado; **preserva** cofre e demais MCPs);
- gerador do wrapper portátil a partir de molde;
- vendorizador do pacote (pin + integridade + lockfile);
- self-tests determinísticos offline.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`.
- **Versão fixada:** `0.13.0`.
  - npm `dist.integrity`: `sha512-0fFOAJwlsntMdHu4+t40H4BObOowfqVsZdMnU1tbqIHojbWotRia8quh8/SjEtwpC0CbemZF9TpBDbFNBhnRGw==`
  - npm `dist.shasum`: `5b70663fc97d579e5cf8f0dd4c40ebdaaf46fb75`
  - tag git `v0.13.0` → commit `5e0ca5cacd1556dc0b8c227648843d3ebf5bdc93`
- **`engines.node`:** `>= 22`. Dependências do pacote: `zod`, `@typesafe-ai/sdk`,
  `@jkudish/jev-agent-tools`, `@modelcontextprotocol/node`, `@modelcontextprotocol/server`.
- **Vendor:** instalação única em `%LOCALAPPDATA%\xpz-mcp-integrations\` com
  `npm install --ignore-scripts` + `package-lock.json` travado; o wrapper passa a invocar
  `node <vendor>\node_modules\@jkudish\jev-mcp\dist\index.js`. **Sem rede no início** e sem
  variação de dependências transitivas entre execuções.
- O pacote de terceiros **não** é comitado no nosso repositório.

### Wrapper portátil (molde gerado pela skill)

- Node/ESM, **sem segredo**, deriva `%USERPROFILE%`/`$HOME` (nada de path absoluto pessoal).
- Lê do cofre a configuração **não secreta** (fornecedor, URL base, modelo) e a **chave** em
  runtime; injeta **somente** a variável de credencial no processo filho.
- Preserva o stdio do MCP; falha com mensagem segura se a chave não existir.
- O wrapper de referência da máquina (`~/.config/opencode/jev-mcp-wrapper.mjs`) serve como
  **molde arquitetural**, não como código portátil: hoje ele hardcoda o path do usuário e usa
  `npx -y ...` (ambos corrigidos neste desenho).

## Fornecedor

O pacote aceita **cinco** modos (`dist/provider.d.ts` → `JevProvider`):
`typesafe`, `openrouter`, `cloudflare`, `vercel`, `compatible`.

| Modo (`JEV_PROVIDER`) | Credencial | Base / modelo |
|---|---|---|
| `typesafe` (padrão do pacote) | `TYPESAFE_API_KEY` | `api.typesafe.ai`; `JEV_MCP_MODEL` (default `jev-latest`) |
| `openrouter` | `OPENROUTER_API_KEY` | `JEV_OPENROUTER_BASE_URL` |
| `cloudflare` | `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` (ou `JEV_CLOUDFLARE_*`) | `JEV_CLOUDFLARE_BASE_URL` |
| `vercel` | **a confirmar na implementação** | **a confirmar na implementação** |
| `compatible` | `JEV_API_KEY` | `JEV_API_BASE_URL` + `JEV_MCP_MODEL` |

- **Command Code** (validado) é um preset `compatible`:
  `JEV_API_BASE_URL=https://api.commandcode.ai/provider/v1/systemone`,
  `JEV_MCP_MODEL=typesafe/jev`, chave gerada pelo usuário **no site do Command Code**
  (independente de qualquer harness de agente).
- **Fornecedor terceiro do usuário:** o setup pergunta URL base e modelo na hora e registra
  como configuração não secreta; a chave entra pelo caminho seguro. Pré-requisito: o endpoint
  tem de falar o **mesmo protocolo System One/Jev** (não serve qualquer API OpenAI avulsa).

## Credencial

- **Cofre neutro:** `%LOCALAPPDATA%\xpz-mcp-integrations\` (fora do repositório e fora de
  qualquer config de cliente), no mesmo espírito da curadoria de `%LOCALAPPDATA%\xpz-llm-delegate\`.
- **Ordem de resolução do wrapper:** (1) variável de ambiente já presente; (2) cofre da skill;
  (3) falha com mensagem segura orientando a configurar.
- **Chave nunca** é impressa, logada, copiada para config de cliente ou para doc, nem enviada
  ao Jev. A entrada é feita por **comando local com entrada oculta** no terminal do usuário —
  **nunca pelo chat**.
- `auth.json` do OpenCode (entrada do fornecedor `commandcode`): **importação opcional e
  explícita**, nunca dependência. Um usuário só de Codex configura a chave direto no cofre.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, seção `mcp.jev`
  (`type: local`, `command: ["node", "<wrapper>"]`, campo **`environment`**, não `env`).
  Merge que **preserva comentários**; backup antes de qualquer escrita; idempotente.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]`. Merge de TOML é mais delicado que
  JSON; entra com **risco declarado** e self-test próprio.

## Auditoria (estados)

Por componente × cliente, no padrão de relatório + oferta de resolução da `xpz-skills-setup`:

- `OK`
- `ausente`
- `entrada_quebrada` / `entrada_divergente`
- `versao_defasada` (instalada ≠ fixada)
- `atualizacao_disponivel` (informa; **nunca** auto-atualiza)
- `fornecedor_ausente`
- `credencial_ausente`
- `node_ausente`

Nada é gravado sem confirmação explícita do usuário.

## Atualizar e remover

- **Atualizar:** só consciente — ler changelog/release notes, verificar breaking changes e
  variáveis de ambiente, backup, atualizar, testar, permitir rollback. Nunca por existir
  versão nova.
- **Remover:** desabilitar/remover a entrada, remover o wrapper **criado pela skill**,
  preservar cofre, `auth.json`, fornecedor e os demais MCPs.

## Testes

- **Self-tests offline/determinísticos** (detecção, merge JSONC/TOML, idempotência, backup,
  rollback) = gate do repositório. Sem rede e sem chave.
- **E2E** com `jev_classify` (conteúdo fictício) = **validação manual opt-in**, documentada;
  nunca gate automático (exige credencial e rede).

## Documentação e paridade

- `README.md` trilíngue, `CHANGELOG.md` trilíngue, `09-inventario-e-rastreabilidade-publica.md`,
  `08-guia-para-agente-gpt.md` quando aplicável, ponteiro em `xpz-skills-setup/SKILL.md`.
- Preparar para os gates `Test-PrePushNewTokenPropagation.ps1` e
  `Test-PrePushSharedScriptSkillCoverage.ps1`.

## Fases

- **F0** — este design + **revisão por pares**.
- **F1** — esqueleto da skill + descritor Jev (Command Code) + wrapper portátil + cofre/
  credencial + adaptador OpenCode + self-tests offline + docs.
- **F2** — adaptador Codex (TOML) + auditoria de versão/drift + update/rollback.
- **F3** — Cursor + Claude Code.
- **F4** — opcionais: fornecedores extras (`compatible`/`typesafe`), backend Python alternativo,
  fork/espelho do pacote.

## Riscos e decisões em aberto

- **Merge de TOML (Codex)** é o ponto mais frágil; tratar com self-test e postura conservadora.
- **Auditoria real do pacote:** o npm publica `dist` já compilado (JS), não o fonte TypeScript;
  auditar = comparar com build do tag `v0.13.0` ou revisar o próprio `dist`. Revisão pontual,
  não bloqueia a v1.
- **Compatibilidade de fornecedores de terceiros** com o protocolo System One precisa ser
  confirmada caso a caso.
- **Node é dependência de runtime JS** do componente; não há rota sem runtime JS sem
  reimplementar as ferramentas (avaliado e rejeitado para a v1).
- **Fornecedor padrão:** o setup deve perguntar (Command Code × outro); na máquina de
  referência, Command Code fica como default validado.

## Evidência coletada (2026-10-02)

- `node v24.18.0` e `python 3.14` presentes na máquina de referência.
- `@jkudish/jev-mcp@0.13.0` vendorizado em pasta temporária via `npm install --ignore-scripts`
  (9 pacotes, `package-lock.json` gerado).
- **Boot offline** do servidor vendorizado com env fictício + `initialize` MCP → resposta
  `server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`, `tools.listChanged=false`. Confirma
  que dá para eliminar o `npx`.
- Variáveis de ambiente referenciadas no `dist`: `JEV_PROVIDER`, `JEV_API_BASE_URL`,
  `JEV_API_KEY`, `JEV_MCP_MODEL`, `TYPESAFE_API_KEY`, `OPENROUTER_API_KEY`,
  `JEV_OPENROUTER_BASE_URL`, `CLOUDFLARE_*`/`JEV_CLOUDFLARE_*`, além dos `JEV_MCP_*` de
  transporte/concorrência/timeout.
- Modos de fornecedor confirmados em `dist/provider.d.ts`.
- Alternativa **Python** de terceiro encontrada no PyPI (`typesafe-mcp`, 9 tools, sem
  dependências de runtime), porém com **outra superfície de ferramentas** e **não validada**
  contra o endpoint do Command Code — registrada como opção de F4, não como default.

## Referências

- Repositório do pacote: `https://github.com/jkudish/jev-mcp` (MIT).
- Doc do System One / TypeSafe: `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md` — fronteira de responsabilidade.
- `15-revisao-por-pares.md` e `xpz-llm-delegate/SKILL.md` — o fornecedor `commandcode/*`
  também aparece ali como **catálogo de vozes** do painel de revisão; **não confundir** os dois
  usos de `commandcode/*` (voz de painel × endpoint do Jev).
