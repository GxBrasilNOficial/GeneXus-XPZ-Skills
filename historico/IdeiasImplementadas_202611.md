# Ideias Implementadas - 2026-11

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

## Indentação de Source: `indent-context-depth-drift` (wrap / recontextualização) — 2026-11-20

Implementado em 2026-11-20 conforme design congelado `RoundId=wrap-indent-v4-20261120-080658` (decisão humana B: congelar; prova na implementação/self-test). Origem: recorte «Fora desta pendência / drift estrutural em linha preserved» que constava na entrada de expansão de allowlist Events em `999-ideias-pendentes.md` (decisão B 2026-11-17 adiava; demanda real de wrap under-indent reabriu). Removido desse parágrafo do `999` ao fechar a frente; a entrada Events permanece só para expansão de allowlist.

**Escopo entregue.** Motor `Test-GeneXusSourceIndentation.ps1` emite `indent-context-depth-drift` (warn) com baseline `compared`, classes LCS `preserved`/`reindented`, quando a profundidade estrutural sobe e o recuo não acompanha — **sem** exigir `-AbsoluteIndentCheck`. Mesma bifurcação de under-depth (inclui `unitMode=none`). Guardas: `unitMode=mixed` e `inconclusiveLocal` impedem afirmar drift; `indent-unit-mismatch-in-delta` é finding à parte e **não** suprime o drift (ABORT continua ancorado nele). BaselinePath/AcervoPath no mesmo path resolvido de InputPath → `no-baseline-unresolved`. Gate de **processo** (ABORT de empacotamento) lê `parts[].baselineStatus` da part do wrap, não o agregado top-level; `probablyImportable` e 9-FD intocados. Absolute continua opt-in consultivo para under-depth herdado sem aumento de profundidade. C (hint editor) e D (wrapper exemplo) fora desta frente; setup ganhou só ponteiro para o gate no `xpz-builder`. Docs: `xpz-builder` SKILL/checklist/`procedure.md`, `02`, `08`, `09`, CHANGELOG trilíngue.

**Validação.** `Test-GeneXusSourceIndentationSelfTest.ps1` casos 28–39 (wrap fail/pass, Absolute herdado sem drift, Baseline/Acervo=Input unresolved, `unitMode=none`, reindented drift, G1 unit-mismatch sem depth+ com moda tab inequívoca, G2 inconclusiveLocal com depth+, anti-duplicata drift×Absolute, drift não engolido por unit-mismatch, Absolute+wrap ainda emite drift). Token: `OK: Test-GeneXusSourceIndentationSelfTest.ps1`.

**Residual (opção A, 2026-11-20).** Classe LCS `changed` fica fora do laço de drift (congelamento: só `preserved`/`reindented`). Em wrap com linha recontextualizada **e** editada no mesmo delta, o motor pode emitir só `indent-under-depth` (consultivo) sem `indent-context-depth-drift`; o ABORT de processo documentado, ancorado no drift, **não** dispara nesse eixo. Aceito como residual desta frente — não alargar o motor agora; endurecimento futuro (emitir drift também em `changed`, ou ABORT também em under-depth com baseline `compared`) fica fora.

**Adendo documental (2026-11-20, pós-parecer pasta paralela).** Reforço só em docs: NEVER omitir o +1 do corpo recontextualizado para “minimizar churn”; baseline de wrap = snapshot **imediatamente** pré-wrap (`-AcervoPath` só se for esse estado). C (hint no `Edit-GeneXusXmlSurgical`) e endurecimento do residual `changed` foram anotados como entradas novas em `999-ideias-pendentes.md` (maturidade `ideia`); D (wrapper local) permanece só com o ponteiro na setup.

### Rastreabilidade

- `50dfe39` — Detecta drift de profundidade no wrap de Source.
- `2d1cdd4` — Fecha G1/G2 das guardas do laço de drift de indentação.
- `8fb6fc2` — Evita findings duplicados entre laço de drift e Absolute.
- `46cb19f` — Aponta o gate de wrap-indent na setup sem tornar wrapper obrigatório.
- `12d6842` — Impede que unit-mismatch engula indent-context-depth-drift.
- `1b88fd5` — Ancora o caso 38 na mesma linha preserved e alinha o Escopo.
- `08c1276` — Reforça self-test 35/39, limpa CHANGELOG ES/EN e registra residual `changed`.

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
- `Test-McpLauncherSelfTest.ps1` — 55 asserts na medição de 2026-11-13 (era 45 na entrega inicial; subiu com predicado ACL, CreateExclusive, auditoria ACL e lockAcquired), token `XPZ_MCP_LAUNCHER_SELFTEST_OK`.
- `Test-McpCredentialSelfTest.ps1` — 19 asserts, token `XPZ_MCP_CREDENTIAL_SELFTEST_OK`.
- `Test-McpExitCodesSelfTest.ps1` — 169 asserts na medição de 2026-11-13 (era 166; subiu com `Resolve-McpGapsExitCode`), token `XPZ_MCP_EXIT_CODES_SELFTEST_OK`.
- `Test-McpIntegrationsSelfTest.ps1` — 75 asserts sem o gate do dist na medição de 2026-11-13 (era 53/54 na entrega; subiu com warn ACL, CreateExclusive, manifesto vazio, install/repair sem cofre e ACL do manifesto em repair), token `XPZ_MCP_INTEGRATIONS_SELFTEST_OK`.
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
- Commit material: `dc17375` — Sonda TOML do Codex lê o config pela entrada padrão, sem arquivo temporário.
- Commit material: `87fb50a` — `vaultRemoved` reflete o cofre de fato em `-RemoveVault`.
- Commit material: `c34bdf8` — `changed` do Uninstall só com mudança real em disco ou no manifesto.
- Commit material: `7edc4d0` — Sonda de credencial não segue redirecionamento (`-MaximumRedirection 0`).
- Commit material: `c7768d0` — `3xx` na sonda de credencial conta como endpoint não alcançável.
- Commit material: `676bf20` — Remove registro órfão do manifesto quando a configuração do cliente não existe.
- Commit material: `84cb040` — `Set-McpManifest` não regrava manifesto com o mesmo conteúdo lógico.
- Commit material: `8e85cb3` — Auditor avisa sobre registro órfão (`registro_orfao`) com a ação de Uninstall.
- Commit material: `bdf0a5a` — `Set-McpManifest` compara conteúdo com chaves ordenadas.
- Commit material: `2391053` — Auditor trata manifesto corrompido como bloqueio (exit 67).
- Commit material: `1c0e98b` — Auditor reporta configuração do Codex não regular como conflito, sem sugerir Install.
- Commit material (teste): `f958d0a` — Reparo do Install com manifesto só reformatado.
- Commit material (teste): `e3172f2` — Install com configuração ausente e registro presente.

**Correção pós-painel reforçada (2026-11-13).** Além do warn ACL e do CreateExclusive: install barra `credencial_ausente` antes de qualquer escrita; `Resolve-McpGapsExitCode` impede exit 0 com `INTEGRATIONS_GAPS`; install/uninstall exigem clientes pedidos tratados para `INTEGRATIONS_OK`; uninstall persiste `clients` vazio; integrity/fixture de boot alinhados. Decisão humana: com `-Client all`, gravação parcial entre clientes é aceitável; conflito/`edicao_manual_necessaria` não toca o cliente afetado e não faz rollback dos demais; o agente deve apresentar o cliente e o erro do achado. Paridade documental: `credencial_ausente` blocking no `SKILL` offline; assimetria `acl_nao_aplicavel` ecoada em `02` e `08`. Gate de cofre ausente no install cobre também `repair` (além de `install`/`update`); self-test `no-cred-repair`. Exit 68 reservado/`engines: []` (warn `python_indisponivel` não vira exit de processo); `999` de allowlist reduzido a resumo público; `AGENTS.md` lista `xpz-codex-apply-patch-alternative`. `Set-McpManifest` reaplica ACL so-dono também em `unchanged` (repair / record-e2e). Lock transacional: só remove `.xpz-mcp.lock` se esta execução o adquiriu (`lockAcquired`).

## Revisor opencode — `opencode run` usa o `PWD` do ambiente (correção de segurança)

Implementado em 2026-11-14 conforme o plano v4 congelado por decisão do mantenedor, após 3 rodadas de revisão por pares (deepseek, meta, openai, anthropic). Origem: achado da rotina pré-push dos commits da frente MCP.

**Incidente.** O guard do `reviewer-ro` valida definição estática e `opencode debug agents` no diretório real, mas o `opencode run` 2.2.7 adota o `PWD` do ambiente quando ele existe — para arquivos lidos e para a config project-local do agente. O Git Bash exporta `PWD` e o `pwsh` filho não o atualiza ao trocar de pasta. Num teste com conteúdo sintético rodado do Git Bash, o `run` leu o README real do repositório; num A/B, carregou o agente de outra pasta, nunca validado pelo guard.

**Evidência resumida.** Medições E1–E11 (A/B sintéticos): `run` segue `PWD` também com `--standalone`; `debug agents` ignora `PWD`; `Start-Process -WorkingDirectory D -Environment @{PWD=D}` fixa o filho sem tocar o pai; Claude Code (`-Cd`) não é afetado; `-ArgumentList` não cita elementos com espaço. Tabela completa na nota de 2026-11-14 do D4 em `opencode-reviewer-ro-least-privilege-design.md`.

**Decisão e entrega.** Fixar diretório real e `PWD` no processo filho do `run` com a mesma string entregue ao pré-check (`(Get-Location).ProviderPath`), sem alterar o ambiente do pai: `Invoke-OpenCode.ps1`, runner de `Start-OpenCodeJob.ps1` (com argumentos de caminho citados e `workingDirectory` no `request.json`) e matriz `Test-OpenCodeReviewerRoContentProtection.ps1`. `Test-OpenCodeAgentResolves` ganhou `-WorkingDirectory` opcional. Self-test com controle anti-vacuidade, síncrono, assíncrono, caminho com espaço e `PWD` do pai inalterado; os casos novos falham contra o código anterior. A promoção de versão ganhou o passo sem modelo da premissa E9. Pendências no `999`; alternativas descartadas no `998`.

### Rastreabilidade

- Commit material: `6b62c03` — Fixa diretório real e PWD no filho do opencode run (reviewer-ro).
- Aceite (2026-11-14, opencode 2.2.7, conteúdo sintético): matriz completa **rodada do Git Bash** (invocador com `PWD` exportado), sem `-EvidenceDirectory` e sem `-Only`, modelo `opencode-go/deepseek-v4.1-flash` — 32/32 comportamentais e 2/2 estruturais (`OPENCODE_REVIEWER_RO_MATRIX_OK`); antes da correção, o mesmo arranjo falhava (E1). Prova de ponta a ponta pelo contorno da SKILL (`pwsh -Command "Set-Location '<A>'; & Invoke-OpenCode.ps1 ..."` chamado do Git Bash com `PWD` apontando para B, em caminho 8.3): resposta com `MARCADOR_README_A` e `MARCADOR_AGENTE_A`, nada de B. Passo E9 sem modelo: `debug agents` em A com e sem `PWD=B` deu saídas idênticas (`bash deny`), controle em B `allow`. Self-tests e parse limpos; os casos novos do self-test falham contra o código anterior.
- Pré-push do `13` (HEAD `108a773`): 1 gap confirmado e corrigido no commit seguinte — o lançamento do watcher no `Start-OpenCodeJob.ps1` também passou a citar os caminhos (`-File`, `-TempDir`), mesmo defeito E10 do runner. Sem teste automatizado próprio (os self-tests usam `-NoWatcher`); o helper e a forma `pwsh -File` são os mesmos provados pelo caso `(pwd-espaco)` do runner.

## Lexer e gate 9-PNW: verificação do efeito em frente com barra antes de aspa — 2026-11-14

Origem: item de verificação de processo que acompanhava o registro `lexer-barra-aspa-bloco-nativo-20261114` de `999-ideias-pendentes.md`. Era uma checagem (reexecutar o gate 9-PNW nas frentes afetadas e comparar o resultado), não uma ideia de implementação.

**Escopo verificado.** Numa frente de relatório de KB privada, quatro Procedures tinham barra antes de aspa e nenhum `New`/`EndNew`. Com o lexer anterior, os quatro falhavam com `new-extraction-incomplete: unsupported backslash quote escape`. Com o lexer atual, extraem zero blocos sem erro (medido em leitura, com as duas versões do módulo). O gate 9-PNW executado sobre a frente registrou `status=pass` e `operationalStatus=clear`, sem atribuições `New`.

**Limites registrados.**
- O commit ativo na execução do gate não foi registrado. A linha do tempo (commit do lexer antes do pacote, commit do scanner depois) indica o commit do lexer, mas é inferência.
- A frente não tinha `New`, então o `pass` mostra que a extração não bloqueou, não que atribuições em `New` sejam graváveis.
- Um nome de Procedure repetido no relatório da execução não foi confirmado como defeito do gate. Se for confirmado, vira item próprio.
- Um aviso de compilação da mesma frente, sem relação com o lexer, não foi comparado com o acervo.

### Rastreabilidade

- `28f41bd` — Lexer: barra antes de aspa em código GeneXus e bloco nativo csharp/java.
- `4eb6afa` — Scanner de sanidade alinhado ao lexer: barra antes de aspa e bloco nativo.

## MCP — configuração em link simbólico: reprodução física do conflito — 2026-11-14

Origem: dúvida aberta no commit `bb256c7`, que corrigiu o caminho de configuração que não é arquivo regular. A correção foi fechada pelo código e pelo teste 9j (diretório no lugar do arquivo), mas a reprodução com link simbólico real ficou pendente porque criar link exige privilégio ou Modo de Desenvolvedor.

**Evidência.** Em PowerShell com privilégio, num arquivo temporário fora do repositório, um link simbólico para um arquivo regular devolveu `Test-McpRegularFile` = `False` e `Test-McpConfigPathNonRegular` = `True`. Ou seja, o link cai no ramo de conflito bloqueante, e não no de ausência. A pasta de teste foi removida depois da medição.

**Limite registrado.** A medição cobre o predicado (`Test-McpRegularFile` e `Test-McpConfigPathNonRegular`), não a remoção completa com `-RemoveSkillData`. Esse fluxo ficou coberto pelo teste 9j com diretório. Um caso de remoção com link real foi escrito no self-test como subcaso condicional a privilégio (`SKIP` sem privilégio), no bloco que hoje se chama `9n`.

**Validação com privilégio.** Rodada em PowerShell 7 elevado, com `Test-McpIntegrationsSelfTest.ps1`: `XPZ_MCP_INTEGRATIONS_SELFTEST_OK: 227 asserts`, sem `SKIP` do bloco de link. O total corresponde ao estado commitado em `1c0e98b`, quando o bloco ainda se chamava `9l` (222 asserts sem privilégio, mais 5 do caso com link real). O bloco entrou nesse commit junto com a correção do auditor de outra sessão, sem mensagem própria.

**Mudanças depois dessa validação.** Em `17b11fe`, o bloco foi renomeado de `9l` para `9n`, para resolver colisão com outro bloco `9l` de outra sessão; a lógica não mudou. Em `34d0ed4`, entrou o bloco `9m` (um único conflito para cliente detectado), que acrescenta um assert. Sem privilégio, o HEAD atual passa com 223 asserts. Com privilégio, o HEAD atual (`0767796`) passou com `XPZ_MCP_INTEGRATIONS_SELFTEST_OK: 228 asserts`, sem `SKIP` do bloco de link.

### Rastreabilidade

- `bb256c7` — Configuração que não é arquivo regular vira conflito bloqueante.
- `1c0e98b` — Auditor reporta configuração do Codex não regular como conflito (contém o bloco de link real, então chamado `9l` e depois renomeado para `9n` em `17b11fe`).

## Indentação de Source: índice GUID→candidatos uma vez por execução — 2026-11-17

Origem: entrada «Indentação de Source: índice/cache GUID→path na resolução de baseline — 2026-11-17» de `999-ideias-pendentes.md`, removida após a implementação. Diagnóstico externo: com acervo ~15k XML e 2 Procedures, N×`Select-String` (~12 s por GUID) dominava ~24 s de ~28 s; Absolute não era o custo; `-BaselinePath` isolado ~3 s.

**Escopo entregue.** `Initialize-AcervoDirectoryGuidCandidateIndex` monta, uma vez por execução (quando `-AcervoPath` é pasta e não há `-BaselinePath`), o mapa textual dos GUIDs Procedure in-scope com uma enumeração `*.xml -Force` e um `ReadAllText` por arquivo; `Resolve-BaselineObjectNode` reutiliza o mapa. Fallback por GUID preservado se o índice não cobrir a raiz. JSON aditivo de pré-filtro: `acervoDirectoryIndexUsed`, `acervoDirectoryPrefilterPassCount`, `acervoDirectoryPrefilterFileReads`. Semântica de duplicata/ocultos/falha de leitura preservada; identidade de GUID endurecida depois do índice: rejeição antecipada de GUID vazio (`d3c9455`) e `Normalize-ObjectGuid` (Trim + `TryParse`, rejeita Empty/inválido; alinha índice/`Find`/pré-filtro/offset) para espaços nas bordas, zero e não-UUID — evita falso `no-baseline-new-object` introduzido ou deixado aberto pelo caminho do índice.

**Validação.** `Test-GeneXusSourceIndentationSelfTest.ps1`: caso 23 (ExportFile com 2 Procedures + contadores 1 passagem/N leituras); caso 24 (ExportFile misto GUID ok + vazio → unresolved no vazio); casos 25–27 (GUID padded → compared; zero e `YOUR-GUID-HERE` → unresolved). Docs: `02`, `09`, CHANGELOG, SKILL/checklist.

**Fora do escopo.** Absolute default; streaming parcial de JSON; LCS em Source muito grande; progresso/aviso para pastas grandes.

### Rastreabilidade

- `aa5da49` — Monta índice GUID->candidatos uma vez na indentação.
- `981116d` — Protege o índice da indentação com contadores e remove BOM.
- `d3c9455` — GUID vazio na indentação volta a ser unresolved com índice.
- `cdcf475` — Normaliza GUID da indentação e fecha eixos irmãos.

## Linhas do pós-build com contagens variáveis contam como evento não registrado a cada build — 2026-11-22

Origem: entrada «Linhas do pós-build com contagens variáveis contam como evento não registrado a cada build» de `999-ideias-pendentes.md`, removida após a implementação. Texto original copiado integralmente abaixo. Plano final e quatro rodadas de revisão por pares em `Temp/revisao-por-pares/20261122-posbuild/` (desenho congelado pelo usuário).

### Entrada original


- **Importância** — média: não produz resultado limpo indevido, mas deixa o status `pendente` em build bom e obriga leitura manual; o contorno disponível (registrar a linha literal) se desfaz no build seguinte em que a contagem mudar. O gate de deploy não depende disso (decide por `exit 0` e build concluído).
- **Maturidade** — ideia (decisão de desenho em aberto: qual rota de normalização e qual o recorte das linhas aceitas).

**Contexto.** Registrado em 2026-10-26, na revisão da frente de Categoria B, depois da dispensa do compressor (commit `1f68037`), inicialmente só para a linha `[APLICADO]`. Ampliado no mesmo dia, depois de uma frente de WebPanel de relatório em KB de produção (pasta paralela): o mesmo efeito aparece em mais três linhas de saída do pós-build, todas com números que mudam de um build para outro.

**Linhas afetadas (saída do `PostBuild-Gx.bat` em environment .NET Core + PostgreSQL).**
- `[APLICADO] .js varridos=<n> | arquivos com chave negativa em gx.domain=<n> | chaves corrigidas=<n>` (`Fix-GxNegativeDomainKeys`): muda com cada `.js` novo na pasta `web` e quando aparece chave negativa.
- `<arquivo>.js -> <n> chave(s)`: só aparece quando o `Fix-GxNegativeDomainKeys` corrige alguma chave; o nome do arquivo e a contagem variam. Visto como `<objeto>.js -> 1 chave(s)` nos builds de 2026-10-25. Em 2026-11-13 apareceu para 6 arquivos no mesmo build, com 8 chaves cada.
- `Verify-GxJs: verificados <n> .js (modulos pulados: <n> | placeholders pulados: <n>) | invalidos: 0 | tempo: <n> ms`: hoje só o `tempo` é normalizado; as contagens entram na impressão digital.
- `CommonRspHealth: OK - GeneXus.Programs.Common.csproj ok (<n> itens, <n> dominios); genexus.programs.common.bld ok (<n> itens, <n> dominios); <n> gxdomain*.cs no disco`: muda quando entra domínio novo.

**Estado observado (leitura do código).**
- `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1`, `Get-GeneXusPostBuildEventNormalizedHash` (linhas 177–180): a única normalização além de trim/espaços/caixa é o trecho `tempo: <n> ms` da linha `Verify-GxJs` com `invalidos: 0`.
- `Get-GeneXusPostBuildEventClassification` marca `shouldDowngrade` quando há evento inesperado. `Invoke-GeneXusKbBuildAll.ps1` só rebaixa o status `compilou limpo`.

**Evidência em build real (2026-10-25 e 2026-10-26, KB de produção, environment .NET Core + PostgreSQL).**
- 2026-10-25: nos builds das rodadas do WebPanel de relatório, as linhas `[APLICADO] … chaves corrigidas=1`, `<objeto>.js -> 1 chave(s)`, `Verify-GxJs: verificados 2176 …` e `CommonRspHealth: OK …` saíram como "Evento pos-build NAO registrado".
- 2026-10-26: Build All incremental com `exit 0`, sem reorg, `deployBinFreshness=fresh`, `Verify-GxJs` com `invalidos: 0` e `Build All Task Sucesso`. Mesmo assim, o status ficou `operação concluída, pendente de confirmação funcional`, porque três dessas linhas não tinham impressão digital registrada (relatório JSON do BuildAll sob `Temp/` da pasta paralela).
- Contorno aplicado: wrapper local `Register-*KbPostBuildEvents.ps1` regravou o registro do environment em `kb-source-metadata.md` com os 10 eventos do build; a reclassificação deu `unexpected=[]` e `shouldDowngrade=false`.
- O contorno não dura. O registro anterior já guardava `.js varridos=2974` e `verificados 2184`; o novo guarda `2966` e `2176`. Basta um `.js` ou um domínio a mais para a linha deixar de bater e o status voltar a `pendente`.
- 2026-11-13: BuildAll saudável (KB FabricaBrasil18, environment NETPostgreSQL) com 6 arquivos × 8 chaves negativas, somando 48 linhas `<arquivo>.js(N): Syntax error : }`. O contorno corrigiu as 48 chaves e `Verify-GxJs` fechou com `invalidos: 0`. O exit 48 desse dia veio do reconhecedor do compressor, que supunha uma linha de erro por arquivo; corrigido em 2026-11-14 (ver CHANGELOG). A correção do compressor não altera a decisão em aberto deste item.

**Ideia de solução.**
1. Tratar como evento conhecido, comparando a forma e não as contagens, apenas as famílias de linha conhecidas acima (lista fechada de padrões, por exemplo `^\[aplicado\] \.js varridos=\d+ \| …`, `^\S+\.js -> \d+ chave\(s\)$`, `verify-gxjs: verificados \d+ …`, `commonrsphealth: ok - …`). As contagens continuam no diagnóstico como evidência.
2. Alternativa: o registro de evento pós-build aceitar padrão com contagens variáveis em vez de impressão digital fixa.
3. Não substituir números de forma genérica em qualquer linha: isso esconderia mudanças reais em comandos e caminhos (por exemplo, um `.bat` de deploy diferente).
4. Condicionar a aceitação a sinais de saúde já presentes nas próprias linhas: `invalidos: 0` no `Verify-GxJs` e `OK` no `CommonRspHealth`. Linha com `invalidos` diferente de zero ou `CommonRspHealth` diferente de `OK` continua inesperada.
5. Teste: fixtures com contagens diferentes (`chaves corrigidas=0` e `=1`, `verificados 2176` e `2184`, com e sem a linha por arquivo) devem produzir a mesma classificação; `invalidos: 1` e `CommonRspHealth: FALHA` devem continuar rebaixando.

**Decisões em aberto.** Rota 1 (lista fechada de formas no motor) ou rota 2 (padrão no registro); se a linha `[APLICADO]` e a linha por arquivo valem só com a dispensa do compressor reconhecida ou também isoladas; se o registro literal já gravado deve ser migrado ou só tolerado.

**Relacionado.** A leitura de sinais que pode dar resultado limpo por falha (entrada «Falha ao ler os sinais do BuildAll deixa o resultado como limpo (falso “roundtrip ok”)») tem prioridade maior que este item.

**Retomada.** A condição original ("primeiro build real com a dispensa ativa") foi atendida em 2026-10-26: o status ficou `pendente` na prática, conforme a evidência acima. Falta decidir a rota. Nenhuma ação automática.


**Decisões fechadas.**
- Rota híbrida: as formas conhecidas ficam no motor, como lista fechada de três famílias (`[APLICADO]` do `Fix-GxNegativeDomainKeys`, `Verify-GxJs` com `invalidos: 0` e `CommonRspHealth: ok`); o registro por environment continua como autoridade.
- `[APLICADO]` é aceito sem depender de outra linha.
- Registro gravado pela forma antiga continua aceito para as linhas de família, com aviso `legacyMatchCount`; a primeira regravação troca a forma.
- Sem `-ParallelKbRoot` ou `-KbMetadataPath`, o registro não é consultado: `registryStatus.state` e aviso próprio (`metadataNotProvided`, `environmentNameUnavailable`, `noEntryForEnvironment`).
- Recusado por sobre-engenharia: aceitar linha por arquivo, regex tolerante a espaçamento, marcador de esquema na metadata, catálogo de famílias por KB, `-WhatIf` no Register e motor compartilhado com o reconhecedor do compressor.

**Escopo entregue.** `GeneXusMsBuildPostBuildEventsSupport.ps1` (`Get-GeneXusPostBuildEventFamilyHash`, `legacyMatchCount`); `GeneXusKbDeploymentEnvironmentSupport.ps1` (`Get-GeneXusPostBuildEventRegistryState`); wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` (`registryStatus` e avisos); `Register-GeneXusKbPostBuildEvents.ps1` (um fingerprint por hash, `removedHashCount`). A forma legada `Get-GeneXusPostBuildEventNormalizedHash` ficou igual.

**Validação.** Self-tests: `Test-GeneXusPostBuildEventClassificationSelfTest.ps1`, `Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1`, `Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1` (inclui os quatro estados e a precedência), `Test-GeneXusMsBuildBuildAllEndToEndSelfTest.ps1` (cenário PB1–PB4) e `Test-GeneXusMsBuildSpecifyGenerateEndToEndSelfTest.ps1` (SG1–SG2). Vetores fixos do hash legado conferidos no HEAD.

**Fora do escopo.** Linha por arquivo (entrada curta no `999`, com critério de reabertura); caso conhecido do compressor de estáticos (continua `pendente` por desenho); `MSB3491`; entrada do `999` sobre falha de leitura de sinais do BuildAll.

**Adoção.** Pastas paralelas existentes: registrar de novo cada environment a partir de um build saudável. Até lá, o status segue o comportamento anterior, com o aviso de formato antigo quando alguma linha bater pelo legado. A frente altera arquivos que entram na assinatura do setup; a reauditoria das pastas paralelas fica pendente.

### Rastreabilidade

- `8f64aae` — Corrige falso pendente por evento pos-build no BuildAll e SpecifyGenerate.
