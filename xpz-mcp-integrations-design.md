# xpz-mcp-integrations — design da skill (v3)

## Papel do documento

Design **vivo** (não congelado) da skill nova `xpz-mcp-integrations`. Registra as decisões
travadas na sessão de planejamento de **2026-10-02** e a evidência empírica coletada nela.

A **v2** incorporou a pré-análise do mesmo dia. A **v3** incorpora a **revisão por pares de F0**
(4 revisores, famílias meta/openai/anthropic; veredito unânime **revisa**) — ver «Evidência
coletada». A v3 é a versão consolidada pós-painel e **ainda não foi re-submetida** ao painel
(`vNextState=pendingResubmission`); pela norma do repositório, nenhuma implementação começa
antes do fechamento dessa re-submissão ou de um congelamento auditado.

Este documento **não** é doc operacional da skill. Quando a skill existir, o contrato
operacional vive em `xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ que têm acesso ao **Jev/System One** (modelo de decisão do TypeSafe,
exposto por MCP) não dispõem hoje de um caminho gerenciado para instalar, auditar, reparar,
atualizar e remover esse componente MCP nos clientes de agente. A configuração validada na
máquina de referência é manual e **não é portátil**. Os defeitos concretos dela são: **path
pessoal absoluto** do wrapper, **dependência de rede/cache em runtime**, **transitivas sem pin**
e a **chave amarrada ao `auth.json` do OpenCode** (não a um cofre neutro).

A skill `xpz-skills-setup` **não** cobre esse domínio: ela registra skills XPZ, instrucionais
globais, `nexa`/`gam`, bootstrap git e o MCP **interno** `xpz-global-instructions` do Cursor —
não gerencia MCP de terceiros. Por isso a frente nasce como skill dedicada.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`.
- **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows**. GeneXus roda de fato só em Windows, então a v1 não se disfarça de
  multi-OS; caminhos de macOS/Linux estão **fora** da v1.
- **Ciclo:** detectar → instalar (vendorizado) → auditar → reparar → atualizar (consciente) →
  remover.
- **Credencial:** cofre neutro da própria skill (não preso a nenhum cliente).
- **Público:** comunidade (repo público `GxBrasilNOficial`).

**A `v1` (OpenCode + Codex) só se completa ao fim do F2.** O F1 entrega a parte OpenCode e o
núcleo (descritor, cofre, wrapper); **sozinho, o F1 não constitui a v1**.

## Não-escopo da v1

- **Fork** do pacote (avaliado; adiado para outro dia).
- Cursor e Claude Code (fases seguintes).
- macOS/Linux e qualquer portabilidade multi-OS (fora da v1; a doc não promete).
- Instalar as ferramentas de agente (Codex, OpenCode, Cursor, Claude Code).
- Criar conta, assinatura ou aceitar termos por conta do usuário.
- Instalar automaticamente a skill de agente que o pacote do Jev distribui (`skills/jev/`).
- Configurar uso automático do Jev pelos agentes.
- Gerenciar MCPs sem descritor.
- Vender como "validados" fornecedores que não foram provados nesta skill (ver Fornecedor).

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome da skill | `xpz-mcp-integrations` |
| 2 | Runtime do componente | pacote **vendorizado** e pinado; **sem `npx`** no início |
| 3 | Node | **detectar** ausência **e** versão `< 22`; **oferecer** instalar via `winget` (id `OpenJS.NodeJS.LTS`), sempre com aprovação explícita; se houver gerenciador de versão (`nvm`/`fnm`/`volta`), **relatar**, não instalar |
| 3b | npm | pré-requisito próprio da vendorização (detectado à parte do Node) |
| 4 | Plataforma da v1 | **Windows** (explícita; multi-OS fora) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2; ver Escopo) |
| 6 | Credencial | **cofre neutro**; chave protegida por **DPAPI**, desprotegida por **launcher PowerShell** (não por wrapper Node); env como override; `auth.json` do OpenCode só importação opcional |
| 7 | Fornecedor | **todos os modos que o pacote declara**; válido = `compatible`/Command Code (**parcial**: ver Fornecedor); os outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade (doc neutra, sem path pessoal, ausência de Jev não é erro) |

## Arquitetura

### Motor genérico dirigido por descritor

O motor conhece o conceito «componente MCP externo» — comando, transporte stdio, mapa de
variáveis de ambiente, fonte de credencial, clientes suportados e passos de validação. Cada
componente é um **descritor de dados** (ex.: `components/jev.json`). Jev é o 1º descritor;
adicionar fornecedor/cliente é acrescentar dado, não reescrever a solução. O descritor tem
**validação de schema fail-closed** e self-test próprio.

### Fronteira com `xpz-skills-setup`

- `xpz-skills-setup`: registro de skills XPZ, instrucionais globais, `nexa`/`gam`, bootstrap
  git, MCP **interno** `xpz-global-instructions` do Cursor.
- `xpz-mcp-integrations`: componentes MCP **externos opcionais**.
- Como ambas podem tocar os mesmos arquivos de cliente (`opencode.jsonc`, `config.toml`,
  `~/.cursor/mcp.json`), vale a regra: **merge sempre**, preservando comentários e demais
  servidores; **backup** antes de escrever; **nunca** remover entrada de outro dono.
- `xpz-skills-setup/SKILL.md` ganha um **ponteiro documental** (roteamento: MCP externo
  opcional vive nesta skill), **sem motor**. Não confundir com o ponteiro do `reviewer-ro`,
  cujo traço é justamente **não** ter motor. A skill nova entra sozinha no inventário da setup
  (subpasta com `SKILL.md`); **registrar a skill ≠ instalar o componente** e a setup **não**
  pode tratá-la como gatilho de instalação (mesma disciplina do anti-padrão `reviewer-ro`).
  `AGENTS.md` (que enumera as skills) precisa ser atualizado.

### Scripts

Convenção do repositório: motores compartilhados em `scripts/`, exemplos/molde na pasta da
skill. Frentes previstas (nomes provisórios):

- auditoria read-only do componente × cliente;
- instalador/reparador com merge (JSONC do OpenCode; TOML do Codex) + backup + idempotência;
- desinstalador (remove entrada e wrapper; **preserva** cofre e demais MCPs);
- gerador do launcher portátil a partir de molde;
- vendorizador do pacote (pin + integridade + lockfile);
- self-tests determinísticos offline.

**Suporte JSONC compartilhado — frente própria, não F1.** Existe hoje um localizador JSONC
privado em `Install-OpenCodeReviewerRoAgent.ps1` (`Find-JsoncMatchingBrace`/
`Find-JsoncKeyValueSpan`) que **só pula strings, não pula comentários** — um bloco
`// "mcp": {...}` desalinha o span e corrompe. Além disso, o que está duplicado não é só o
localizador, e sim o **parser** (`OpenCodeReviewerRoGuard.ps1::ConvertFrom-Jsonc` e
`Build-LlmDelegateCapabilityManifest.ps1::ConvertFrom-JsoncText`). A correção é uma **frente
própria curta** que cria `scripts/OpenCodeJsoncSupport.ps1` com um scanner **ciente de
strings, escapes, `//` e `/* */`** + operações localizadas de insert/update/remove para valores
de objeto, **refatorando os três consumidores** e re-rodando os self-tests existentes
(`Test-OpenCodeReviewerRoSelfTest.ps1`, `Test-LlmDelegateCapabilityManifestSelfTest.ps1`, além
do `OpenCodeReviewerRoGuard`). Só depois o F1 do MCP **consome** esse suporte estabilizado.
Motivo de ser frente própria: a refatoração toca o instrumento de revisão (`reviewer-ro`);
fazê-la dentro da frente que será revisada é risco auto-referente. O dono documental do script
refatorado é `xpz-llm-delegate/SKILL.md` (não a setup).

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`.
- **Versão fixada:** `0.13.0`.
  - npm `dist.integrity`: `sha512-0fFOAJwlsntMdHu4+t40H4BObOowfqVsZdMnU1tbqIHojbWotRia8quh8/SjEtwpC0CbemZF9TpBDbFNBhnRGw==`
  - npm `dist.shasum`: `5b70663fc97d579e5cf8f0dd4c40ebdaaf46fb75`
  - tag git `v0.13.0` → commit `5e0ca5cacd1556dc0b8c227648843d3ebf5bdc93`
- **`engines.node`:** `>= 22`. Dependências diretas do pacote: `zod`, `@typesafe-ai/sdk`,
  `@jkudish/jev-agent-tools`, `@modelcontextprotocol/node`, `@modelcontextprotocol/server`.
- **Artefatos commitados:** um `package.json` **de pin** (versão **exata** `"0.13.0"`, sem
  `^`/`~`) e o `package-lock.json`. O **lockfile é a fonte autoritativa de integridade**; o
  `dist.integrity` do descritor é **asserção** conferida contra o lock (não uma segunda
  verdade).
- **Vendor:** instalação única em `%LOCALAPPDATA%\xpz-mcp-integrations\vendor\` com
  **`npm ci`** (a partir dos dois arquivos commitados) + `--ignore-scripts`. `npm` é
  pré-requisito próprio. Verificação de integridade do pacote raiz contra o lock. **Sem rede no
  runtime** do wrapper; sem variação de transitivas entre execuções. O pacote de terceiros em si
  **não** é comitado. **Rollback:** preservar o diretório `vendor\` anterior e restaurá-lo
  (ou re-`npm ci` com o lock anterior) em caso de falha/reversão.
- **Reavaliação de segurança:** a API é `0.x` (instável) e o projeto declara que só a versão mais
  recente recebe correções; a atualização é **consciente** (ler release notes, testar, permitir
  rollback), não automática.

### Launcher portátil (molde gerado pela skill)

- **O comando do MCP é um launcher PowerShell**, não um wrapper Node:
  `command: ["pwsh", "-NoProfile", "-File", "<launcher>.ps1"]`. O launcher:
  1. desprotege a chave do cofre com **DPAPI** (`System.Security.Cryptography.ProtectedData`),
     em memória, **nunca por argv**;
  2. resolve o caminho **absoluto** do `node` (gravado na instalação; ver Auditoria);
  3. faz `Start-Process` de `node <vendor>\node_modules\@jkudish\jev-mcp\dist\index.js` com a
     variável de credencial **só** no ambiente do filho, preservando o stdio do MCP.
- **Por que launcher PowerShell e não wrapper Node que chama `pwsh`:** a rota Node→pwsh devolve o
  segredo pelo stdout de um filho, que pode ser capturado por política de transcrição de
  PowerShell (`Start-Transcript`/GPO); `-NoProfile` não desliga transcrição de máquina. O
  launcher descriptografa no próprio processo e o segredo não cruza fronteira de processo por
  pipe.
- **Dependência de runtime:** o launcher exige `pwsh` (7.4+). O repo já tem precedente de gate de
  runtime (`scripts/Test-XpzPowerShellRuntime.ps1`); a auditoria reporta estado próprio se
  `pwsh` faltar.
- **Marcador de propriedade:** o launcher gerado carrega uma **sentinela** no cabeçalho e é
  registrado num **manifesto** do cofre. O uninstall remove **somente se** sentinela **e** path
  constarem do manifesto; órfão sem manifesto é **reportado**, não removido sem confirmação.
- O wrapper de referência da máquina (`~/.config/opencode/jev-mcp-wrapper.mjs`) serve como molde
  arquitetural, não como código portátil (path pessoal absoluto; chave amarrada ao `auth.json`).

## Fornecedor

O pacote aceita **cinco** modos (`dist/provider.d.ts` → `JevProvider`):
`typesafe`, `openrouter`, `cloudflare`, `vercel`, `compatible`.

| Modo (`JEV_PROVIDER`) | Credencial | Endpoint / wire | Status aqui |
|---|---|---|---|
| `typesafe` (padrão do pacote) | `TYPESAFE_API_KEY` | transport do SDK (`@jkudish/jev-agent-tools`); modelo default `jev-latest` | **experimental opt-in** |
| `openrouter` | `OPENROUTER_API_KEY` | `POST {JEV_OPENROUTER_BASE_URL:-https://openrouter.ai/api}/alpha/decisions`; headers `HTTP-Referer`/`X-Title`/`X-OpenRouter-Title`; `jev-latest`→`jev-1.13`; slug `typesafe/*` | **experimental opt-in** |
| `cloudflare` | `JEV_CLOUDFLARE_API_TOKEN` ou `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | `POST {JEV_CLOUDFLARE_BASE_URL:-https://api.cloudflare.com/client/v4}/accounts/<id>/ai/run`; envelope `{model, input:{state,questions}}` e resposta aninhada; slug `typesafe/jev` | **experimental opt-in** |
| `vercel` | `AI_GATEWAY_API_KEY` | transport do SDK (Vercel AI Gateway) | **experimental opt-in** |
| `compatible` | `JEV_API_KEY` | `POST` direto na **URL completa** `JEV_API_BASE_URL`, `Authorization: Bearer`; corpo `{model, state, questions}` → resposta `{answers, usage?}` | **parcial** (ver abaixo) |

Fatos lidos do `dist/provider.js` (não presumidos):

- **`compatible` não é "qualquer API compatível com OpenAI".** É um endpoint que tem de falar o
  **mesmo contrato System One/Jev** `{state, questions}` → `{answers}`. A URL é usada **como
  veio**.
- **Os modos não são intercambiáveis.** `cloudflare` e `vercel` usam **envelopes próprios** —
  `compatible` não dirige as APIs nativas deles.
- Com `JEV_PROVIDER` **ausente** (`auto`), o pacote **infere** o fornecedor pela presença de
  variáveis de ambiente (compatível como fallback).

- **`compatible` — status "parcial":** a evidência registrada prova o **handshake MCP** com env
  fictício, **não** que o caminho `compatible` → Command Code devolve decisão. O E2E real (com
  chave) é validação manual opt-in, a registrar quando existir. Enquanto isso, a doc e o
  relatório usam "parcial", não "validado".
- **Command Code** é o preset `compatible` sugerido: `JEV_API_BASE_URL=https://api.commandcode.ai/provider/v1/systemone`,
  `JEV_MCP_MODEL=typesafe/jev`, chave gerada pelo usuário no site do Command Code.
- **Experimental opt-in:** os 4 modos não provados ficam **fora do caminho feliz** e **fora dos
  self-tests do F1**; só entram por escolha explícita do usuário, com aviso de que não foram
  validados nesta skill.
- **Fornecedor terceiro do usuário:** o setup pergunta URL base e modelo na hora; a chave entra
  pelo caminho seguro. Pré-requisito: falar o **mesmo protocolo System One/Jev**.
- **O setup pergunta o fornecedor**; Command Code é apenas o **preset sugerido**, nunca presumido
  (ausência de Jev não é erro).
- **Import de `auth.json`:** opcional e explícito, com ressalva de que a credencial
  `commandcode/*` do OpenCode é credencial de **gateway de LLM** — assumir que serve como chave
  de decisão do System One precisa ser confirmado pelo usuário.

## Credencial

- **Cofre neutro:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (fora do repositório e de
  config de cliente), em `%LOCALAPPDATA%` lido **do ambiente** (é redirecionável — não compor a
  partir de `%USERPROFILE%`). `vendor\` e `vault\` separados.
- **Proteção em repouso:** a chave é criptografada com **DPAPI** (escopo do usuário). O cofre não
  é portátil entre máquinas/perfis; recadastrar no outro PC é aceitável. A descriptografia é do
  **launcher PowerShell** (ver Launcher).
- **Limite honesto do DPAPI (declarar no `SKILL.md`/`README`):** protege **em repouso** (backup,
  sync em nuvem, outro usuário do SO, print de tela). **Não** protege contra processo do **mesmo
  usuário** (inclusive o shell do agente) nem contra inspeção do ambiente do filho. É um ganho
  real sobre o estado atual (chave em texto claro no `auth.json`), não uma promessa absoluta.
- **Fronteira de confiança:** a chave é entregue ao processo `jev-mcp` (env do filho) e enviada
  por ele ao **endpoint configurado**, como credencial de transporte — essa é a finalidade. O que
  não pode acontecer é vazar para **log/config/doc/chat/outro destino**. Comprometimento do
  pacote de terceiro = possível exfiltração da chave; daí o pin + integridade + `--ignore-scripts`
  + atualização consciente + a revisão do `dist`.
- **Ordem de resolução do launcher:** (1) variável de ambiente já presente; (2) cofre; (3) falha
  com mensagem segura. Quando env e cofre existirem e **divergirem**, a auditoria informa
  `credencial_divergente_env_vs_cofre` (sem mudar a ordem).
- **Chave nunca** é impressa, logada, copiada para config de cliente ou para doc. A entrada é por
  **comando local com entrada oculta** — **nunca pelo chat**.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, seção `mcp.jev`
  (`type: local`, `command: ["pwsh", "-NoProfile", "-File", "<launcher>"]`, campo
  **`environment`**, não `env`). Merge via o **suporte JSONC compartilhado**; backup antes de
  escrever; idempotente. Se já existir uma entrada `jev` divergente (criada à mão ou por outro
  integrador), reportar `entrada_em_conflito` e **bloquear sobrescrita** por padrão, exigindo
  decisão explícita (adotar/substituir/usar outro nome).
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**). O shape é mais hostil do que
  "inserir um bloco": a env vive em **sub-tabela própria** `[mcp_servers.jev.env]` (ordem
  importa em TOML); o arquivo real mistura string básica (`"`) e **literal** (`'...'`), que o
  mini-parser existente (`Resolve-CodexModelLocality.ps1`) não vê; o span de update tem de ir
  até o próximo cabeçalho **não-filho**; `enabled=false` é o caminho natural de "desabilitar" no
  uninstall; `env_vars` filtra o ambiente herdado e **ameaça** o passo (1) da ordem de resolução
  do launcher. F2 exige **prova empírica do shape** (o `config.toml` da máquina serve de
  fixture) e self-test cobrindo literal-string, sub-tabela `.env` e update com filhos.

## Auditoria (estados)

Por componente × cliente, no padrão de relatório + oferta de resolução da `xpz-skills-setup`.
**Gate offline/determinístico** (sem rede) cobre:

- `OK`
- `ausente`
- `entrada_quebrada` / `entrada_divergente` / `entrada_em_conflito`
- `versao_defasada` (instalada ≠ fixada)
- `vendor_ausente` / `vendor_divergente` (falta ou não bate com o pin/lock)
- `wrapper_ausente` / `wrapper_divergente` (launcher ausente ou fora do descritor)
- `node_ausente` / `node_incompativel` (`< 22`) / `node_path_nao_resolve`
- `pwsh_ausente`
- `fornecedor_ausente` / `fornecedor_nao_validado` (informativo; não bloqueia)
- `credencial_ausente` / `credencial_divergente_env_vs_cofre` (informativo)

**Checagem online opt-in** (`-CheckUpdates`, com rede): `atualizacao_disponivel` — informa, nunca
auto-atualiza. Fica **fora** do gate offline.

Nada é gravado sem confirmação explícita do usuário. A comparação de paths expande variáveis
(`%USERPROFILE%`/`%LOCALAPPDATA%`) antes de decidir `entrada_divergente`; o reparo regenera o
path na máquina atual.

## Atualizar e remover

- **Atualizar:** só consciente — ler changelog/release notes, verificar breaking changes e
  variáveis de ambiente, backup, atualizar, testar, permitir rollback. Nunca por existir versão
  nova.
- **Remover:** com o mesmo wrapper servindo OpenCode **e** Codex, o manifesto registra
  **referências por cliente** e o launcher só é removido quando **não restar referência** de
  nenhum cliente. Remoção do launcher exige **sentinela no cabeçalho E** path no manifesto;
  órfão = reportar. Preservar cofre, `auth.json`, fornecedor e os demais MCPs. No Codex,
  preferir `enabled=false` a apagar texto.

## Testes

- **Self-tests offline/determinísticos** (detecção, merge JSONC, idempotência, backup, rollback,
  **validação de schema do descritor**) = insumo de qualidade. Incluem um teste do **launcher com
  filho falso**: resolve cofre/env, injeta **exatamente** a variável esperada, preserva stdio,
  **não** vaza segredo em erro e **não** inicia rede. Sem rede e sem chave.
- **Os self-tests não são rodados pelo orquestrador de pré-push** (`Invoke-PrePushMechanicalChecks.ps1`
  roda parse + gates consultivos). A skill declara o comando explícito de cada um e registra em
  `09` com `Validação:`/`Tokens:`. Os self-tests de **TOML** pertencem ao **F2**.
- **E2E** com `jev_classify` (conteúdo fictício) = **validação manual opt-in**, documentada;
  nunca gate automático (exige credencial e rede). É pré-requisito de qualquer alegação de
  "validado".

## Documentação e paridade

- `README.md` trilíngue — atenção: as skills são enumeradas em **seis** pontos (abertura + lista,
  nas três línguas).
- `CHANGELOG.md` trilíngue.
- `09-inventario-e-rastreabilidade-publica.md` — entradas no formato completo (`Dono:` **+**
  `Validação:`/`Tokens:`/`Exit:`).
- `02-regras-operacionais-e-runtime.md` — contrato de motor (`Kind=`/`SchemaVersion`, `status`/
  `exitCode`/`blockingReasons`, labels `*_SKIPPED` sob `-WhatIf`, `-InputPath` para entrada).
- `08-guia-para-agente-gpt.md` quando aplicável.
- `SECURITY.md` — linha sobre o cofre (primeira feature de segredo em repouso do repo).
- `AGENTS.md` (enumeração "Trabalho nas skills XPZ") e ponteiro **documental** em
  `xpz-skills-setup/SKILL.md`.
- `xpz-llm-delegate/SKILL.md` — dono do script refatorado (`Install-OpenCodeReviewerRoAgent.ps1`)
  e do `OpenCodeReviewerRoGuard.ps1`; o módulo JSONC novo precisa ser citado pelas duas skills
  donas (o gate `Test-PrePushSharedScriptSkillCoverage.ps1` vai sinalizar).
- `999-ideias-pendentes.md` — sincronizar a entrada da skill **quando o design congelar** (não a
  cada versão).
- Conformidade de runtime: `#requires -Version 7.4`; escrita UTF-8 **sem BOM** via
  `scripts/Utf8NoBomEncodingSupport.ps1`; molde `.example.ps1`.
- **Nota:** `Test-XpzParameterNamingContract.ps1` **não** é gate geral — ele trava uma lista fixa
  do empacotamento XPZ. A convenção real está em `02` + formato do `09`.
- Preparar para `Test-PrePushNewTokenPropagation.ps1` e `Test-PrePushSharedScriptSkillCoverage.ps1`.

## Fases

- **F0** — design + **revisão por pares** (feita; v3 consolidada, pendente de re-submissão).
- **F1-pre (frente própria)** — `scripts/OpenCodeJsoncSupport.ps1` (scanner ciente de comentários
  + operações localizadas) e refatoração dos três consumidores, com self-tests e pré-push.
- **F1** — esqueleto da skill (parte OpenCode + núcleo) e **do** adaptador OpenCode +
  descritor Jev (Command Code) + launcher + cofre/credencial (DPAPI) + vendorizador
  (package.json/lockfile/`npm ci`) + self-tests offline + docs. **F1 sozinho ≠ v1.**
- **F2** — adaptador Codex (TOML, prova empírica do shape) + self-tests de TOML + auditoria de
  versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (reconciliar o motor do `~/.cursor/mcp.json`, hoje reescrito por
  `Install-CursorGlobalInstructionsMcp.ps1` sem preservar chaves de topo).
- **F4** — opcionais: validação dos fornecedores experimentais, backend Python alternativo,
  fork/espelho do pacote.

## Riscos e decisões em aberto

- **Merge de TOML (Codex)** é o ponto mais frágil; postura conservadora (bloco localizado
  idempotente, ciente de sub-tabela `.env` e string literal) + prova empírica + self-test, no F2.
- **Revisão do `dist`:** o npm publica `dist` compilado. Mínimo antes do E2E com chave real:
  endpoints de rede efetivos batem com a tabela de Fornecedor (sem hosts extras); sem
  `child_process`/`spawn` além do stdio; sem leitura de arquivos fora do necessário; sem
  `postinstall` (o `--ignore-scripts` cobre, mas conferir o `package.json`).
- **Fornecedores experimentais:** expostos só sob opt-in, fora do caminho feliz e dos self-tests.
- **Node/pwsh são dependências de runtime** (JS + launcher); não há rota sem runtime JS sem
  reimplementar as ferramentas (rejeitado para a v1).
- **Fornecedor padrão:** o setup **pergunta**; Command Code fica como preset sugerido.

## Evidência coletada (2026-10-02)

- `node v24.18.0` e `python 3.14` presentes na máquina de referência.
- `@jkudish/jev-mcp@0.13.0` vendorizado em pasta temporária via `npm install --ignore-scripts`
  (9 pacotes, `package-lock.json` gerado); o `package.json` registra `^0.13.0` (caret) — daí o
  pin **exato** no artefato versionado da skill.
- **Boot offline** do servidor vendorizado com env fictício + `initialize` MCP → resposta
  `server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`, `tools.listChanged=false`.
- **`dist/provider.js` lido** (vendorizado em `%TEMP%\opencode\jev-probe\`): os cinco modos, os
  endpoints/envelopes, a inferência `auto` e o contrato do `compatible`. Base da tabela de
  Fornecedor.
- **Revisão por pares (F0)** — RoundId `mcp-integrations-f0-v2`: 4 titulares da lista preferida
  (meta/openai/anthropic; stealth fora do piso), `panelReady`, 4× **revisa**, `vNextState=pendingResubmission`,
  `closeoutReady=false` (`vnext-pending-resubmission`). Achados incorporados nesta v3.
- Alternativa **Python** de terceiro no PyPI (`typesafe-mcp`) — opção de F4, não default.

## Referências

- Repositório do pacote: `https://github.com/jkudish/jev-mcp` (MIT).
- Doc do System One / TypeSafe: `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md` — fronteira de responsabilidade.
- `15-revisao-por-pares.md` e `xpz-llm-delegate/SKILL.md` — o fornecedor `commandcode/*`
  também aparece ali como **catálogo de vozes** do painel de revisão; **não confundir** os dois
  usos de `commandcode/*` (voz de painel × endpoint do Jev).
