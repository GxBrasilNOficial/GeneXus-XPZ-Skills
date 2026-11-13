# Ideias Implementadas - 2026-11

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

## Skill `xpz-mcp-integrations-setup` — componente MCP externo opcional (Jev/System One) — implementação da v1

Implementado em 2026-11-09 conforme o design v24.2 congelado por decisão humana (`resubmissionDeclinedByHuman`, `RoundId=mcp-int-v24-freeze-20261109`). Origem: entrada «Skill `xpz-mcp-integrations-setup` — componente MCP externo opcional (Jev/System One)» de `999-ideias-pendentes.md`, removida após a implementação.

**Escopo entregue.** Skill nova `xpz-mcp-integrations-setup` para instalar, auditar, reparar, atualizar e remover componentes MCP externos opcionais. A v1 cobre o **Jev/System One** (`@jkudish/jev-mcp` 0.13.0) em **OpenCode** e **Codex**, no Windows. O fornecedor implementado é só `compatible` com o preset **Command Code**; os outros quatro modos ficam no F4. Claude Code e Cursor ficam fora da v1.

**Propriedades preservadas.** Sem `npx` em runtime; pin por **integrity sha512** no lockfile comitado; `npm ci --ignore-scripts --no-audit --no-fund` em `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-0.13.0\`; chave **só** no cofre DPAPI `CurrentUser`, nunca no config do cliente; backup antes de gravar config; nada gravado sem aprovação; ciclo instalar/auditar/reparar/atualizar/remover.

**Artefatos principais.**

- `xpz-mcp-integrations-setup/SKILL.md` — contrato normativo, fluxo, estados, exit codes e limites.
- `xpz-mcp-integrations-setup/components/jev.json` — descritor fail-closed (5 modos como dado; 1 implementado).
- `xpz-mcp-integrations-setup/templates/launcher.ps1` — molde do launcher `ProcessStartInfo` com stdio herdado e ambiente limpo por allowlist.
- `xpz-mcp-integrations-setup/vendor/package.json` + `package-lock.json` — pin 0.13.0; integrity `sha512-0fFOAJwlsntMdHu4+t40H4BObOowfqVsZdMnU1tbqIHojbWotRia8quh8/SjEtwpC0CbemZF9TpBDbFNBhnRGw==`; árvore de 9 pacotes.
- `xpz-mcp-integrations-setup/fixtures/` — evidência sanitizada do `dist` (provider `compatible`, `engines.node`, `prepare`, boot, EOF, licença MIT, proveniência, revisão estática), fixtures JSONC/TOML e `auth export`.
- `xpz-mcp-integrations-setup/exit-codes.catalog.json` — faixa reservada 60-69, sem colisão com `scripts/msbuild-exit-codes.catalog.json`.
- `scripts/McpIntegrationSupport.ps1`, `McpVaultSupport.ps1`, `McpLauncherSupport.ps1`, `McpVendorSupport.ps1`, `McpOpenCodeSupport.ps1`, `McpCodexSupport.ps1`, `McpTomlProbe.py` — motores/support.
- `scripts/Test-McpIntegrations.ps1` — auditoria read-only, `overall` estrutural, `-CheckBoot` local opt-in, `-CheckCredential` online opt-in.
- `scripts/Install-McpIntegration.ps1` — instalar/reparar/atualizar/registrar E2E; `-WhatIf`.
- `scripts/Uninstall-McpIntegration.ps1` — remover só entrada reconhecida; preserva cofre/config por padrão.
- `scripts/Invoke-McpVendor.ps1` — vendorização pinada.
- `scripts/Set-McpCredential.ps1` — cofre DPAPI e import único de `opencode auth export`/`auth.json`.

**OpenCode.** Forma canônica `mcp.servers.jev` (`type: local`, `command`, `environment`, `disabled`); forma legada `mcp.jev` reconhecida para leitura/migração; coexistência é `entrada_em_conflito`. A edição reusa o mecanismo JSONC do `reviewer-ro` (`Find-JsoncMatchingBrace`/`Find-JsoncKeyValueSpan` copiadas; `ConvertFrom-Jsonc` por dot-source do Guard) com validação pós-edição por comparação de objetos. Entrada só é substituída/removida se byte-idêntica a um hash do `install-manifest.json`.

**Codex.** Bloco `[mcp_servers.jev]` entre marcadores de comentário próprios; detecção/validação por `tomllib` (Python 3.11+, somente leitura). Sem Python, o Codex cai em `edicao_manual_necessaria` com o trecho pronto. Grafias equivalentes são detectadas sem escrita; a migração manual só aceita um único cabeçalho canônico com `-MigrateLegacy`; outras grafias são conflito.

**Auditoria.** `INTEGRATIONS_OK` é estrutural: entrada reconhecida em cada cliente gerenciado e nenhum achado `blocking`; credencial é eixo separado. Estados por cliente: `nao_configurado` → `escrito` → `recarga_pendente` → `boot_ok` → `endpoint_alcancavel` → `credencial_verificada` → `e2e_opt_in_confirmado`. `boot_ok` não promove saúde; `-CheckCredential` exige autorização por execução e só promove com `200` e `answers` contendo a chave do probe e `noul` numérico em `[0,1]`.

**Validação executada.**

- `Test-McpOpenCodeAdapterSelfTest.ps1` — 38 asserts, token `XPZ_MCP_OPENCODE_ADAPTER_SELFTEST_OK`.
- `Test-McpCodexAdapterSelfTest.ps1` — 44 asserts, token `XPZ_MCP_CODEX_ADAPTER_SELFTEST_OK`.
- `Test-McpLauncherSelfTest.ps1` — 52 asserts na medição de 2026-11-13 (era 45 na entrega inicial; subiu com predicado ACL, CreateExclusive e auditoria ACL), token `XPZ_MCP_LAUNCHER_SELFTEST_OK`.
- `Test-McpCredentialSelfTest.ps1` — 19 asserts, token `XPZ_MCP_CREDENTIAL_SELFTEST_OK`.
- `Test-McpExitCodesSelfTest.ps1` — 169 asserts na medição de 2026-11-13 (era 166; subiu com `Resolve-McpGapsExitCode`), token `XPZ_MCP_EXIT_CODES_SELFTEST_OK`.
- `Test-McpIntegrationsSelfTest.ps1` — 67 asserts sem o gate do dist na medição de 2026-11-13 (era 53/54 na entrega; subiu com warn ACL, CreateExclusive, manifesto vazio e install sem cofre), token `XPZ_MCP_INTEGRATIONS_SELFTEST_OK`.
- `Test-McpDistEvidenceSelfTest.ps1` — 24 asserts (gate do F1 com vendor real, revisão estática e boot sem chave), token `XPZ_MCP_DIST_EVIDENCE_SELFTEST_OK`.

**Correção pós-pré-push (2026-11-09).** O exit 69, prometido no catálogo para os motores, passou a ser emitido pelos cinco motores por captura de erro no nível do script; o catálogo foi alinhado aos emissores reais de 60-65 e o self-test de exit codes passou a validar a matriz de emissores e a provar o 69 em cada motor.

**Correção pós-revisão por pares (2026-11-09).** A reserva `auth.json` passou a cobrir OpenCode V2 (`.local\share`) e legado (`.config`), aceitando `type=key`/`type=api` e diagnosticando caminhos/provedores; a auditoria separa entrada manual migrável (`edicao_manual_necessaria`, `nextAction -MigrateLegacy`) de conflito; o exit code segue a `precedence` do catálogo e o `nextActions` a mesma ordem, agora rotulado como `possible-actions` (menu, não sequência); o gate do `dist` recusa root com manifesto/config/vault/launcher e limpa o que criar; o `import -WhatIf` expõe `credentialSource` e `import`; o design marca `-CheckUpdates` como F2.
- `Test-XpzParameterNamingContract.ps1` — `XPZ_PARAMETER_NAMING_CONTRACT_OK`.
- Boot real medido: `initialize` respondido por `jev-mcp 0.13.0`, exit 0; EOF encerra; stdin aberto deixa o processo vivo (órfão é risco aceito sem Job Object).

**Limites e pendências.** A contenção de rede **não foi demonstrada** nesta máquina (Windows Sandbox indisponível em 2026-11-09); o gate do F1 é revisão estática do `dist` + boot sem chave. O wire do modo `compatible` foi exercitado no E2E de 2026-11-09 (`-CheckCredential` 200/`answers_ok` e `jev_find` nos dois clientes); o host Command Code também foi medido com chamada autenticada em 2026-11-09. Claude Code (A.13), divergência cofre × export (B.9), Cursor, os outros quatro fornecedores, backend Python e os endurecimentos do Anexo B ficam no F2/F4. A anotação das fixtures sanitizadas no `GeneXus-XPZ-PrivateMap` deve ser avaliada em contexto operacional separado; nada foi editado fora desta base pública.

**Execução real (2026-11-09).** A instalação foi executada na máquina de referência em duas etapas, com backup manual persistente em `%LOCALAPPDATA%\xpz-mcp-integrations-backups\20261109-153019` e backups transacionais `.xpz-mcp.bak-*` do próprio instalador; os hashes SHA-256 dos dois conjuntos coincidem. `Set-McpCredential.ps1 -Action import -ImportFromOpenCode` gravou o cofre (`written=True`). `Install-McpIntegration.ps1 -Action install -Client all -MigrateLegacy` retornou `INTEGRATIONS_OK`, com OpenCode e Codex em `written`. A verificação pós-instalação deu `INTEGRATIONS_OK` na auditoria estrutural, `boot_ok` com exit 0 no `-CheckBoot`, e `credencial_verificada` no `-CheckCredential` (`200`, `answers_ok`). O E2E foi executado nos dois clientes: `jev_find` no OpenCode (probabilidades 1 e 0) e `jev/jev_find` no Codex (1 e 0), com `-Action record-e2e` gravando os carimbos em `install-manifest.json` (`e2e.opencode` e `e2e.codex`). O `jev-mcp-wrapper.mjs` antigo foi removido após a migração; os backups foram mantidos. O estado de runtime vive em `%LOCALAPPDATA%\xpz-mcp-integrations\install-manifest.json`, não neste repositório.

**Nome e namespace (2026-11-09).** A skill foi renomeada de `xpz-mcp-integrations` para `xpz-mcp-integrations-setup` antes do primeiro commit. Os scripts seguem o padrão `verbo + domínio` (`Test-McpIntegrations`, `Install-McpIntegration`, `McpVaultSupport` etc.), sem o prefixo `Xpz`; o diretório de dados de runtime permanece `%LOCALAPPDATA%\xpz-mcp-integrations` como namespace estável; o desenho mantém o nome histórico com nota no topo. O marcador do bloco Codex e a sentinela do launcher passaram a usar `xpz-mcp-integrations-setup:*`.

**Rastreabilidade.** Design: `xpz-mcp-integrations-design.md` (v24.2). Dono documental: `xpz-mcp-integrations-setup/SKILL.md`. Índice de ponteiros: `09-inventario-e-rastreabilidade-publica.md`. Contrato de runtime: `02-regras-operacionais-e-runtime.md`. Guia do agente: `08-guia-para-agente-gpt.md`. CHANGELOG/README/SECURITY trilíngues atualizados. O pin do pacote e a evidência do `dist` ficam em `vendor/` e `fixtures/dist/0.13.0/`.

### Rastreabilidade

- Commit material: `a643071` — Adiciona a skill xpz-mcp-integrations-setup e o ciclo de MCPs externos.
- Commit material: `59b7073` — Corrige o exit 69 dos motores e alinha o catalogo de exit codes.
- Commit material: `70ac932` — Corrige reserva de credencial, auditoria manual e precedencia de exit.
- Commit material: `084f3d5` — Rotula nextActions como menu e corrige -CheckUpdates no design.
- Commit material: `e37bbd7` — Predicado ACL so-dono (SID+FullControl) no vault MCP.
- Commit material: `46c7bdb` — CreateExclusive na escrita transacional MCP.
- Commit material: `34619c8` — Warn `acl_nao_aplicavel` na auditoria offline (A.9).
- Commit material: `a321ded` — Credencial antes de gravar, piso 60 em GAPS, manifesto clients vazio.
- Commit material: `58eb33c` — Corrige portugues residual na entrada espanhola do CHANGELOG MCP.
- Commit material: `15c1591` — Alinha A.9/exit 60/uninstall e sanitiza literal de allowlist no 999.

**Correção pós-painel reforçada (2026-11-13).** Além do warn ACL e do CreateExclusive: install barra `credencial_ausente` antes de qualquer escrita; `Resolve-McpGapsExitCode` impede exit 0 com `INTEGRATIONS_GAPS`; install/uninstall exigem clientes pedidos tratados para `INTEGRATIONS_OK`; uninstall persiste `clients` vazio; integrity/fixture de boot alinhados. Decisão humana: com `-Client all`, gravação parcial entre clientes é aceitável; conflito/`edicao_manual_necessaria` não toca o cliente afetado e não faz rollback dos demais; o agente deve apresentar o cliente e o erro do achado. Paridade documental: `credencial_ausente` blocking no `SKILL` offline; assimetria `acl_nao_aplicavel` ecoada em `02` e `08`.
