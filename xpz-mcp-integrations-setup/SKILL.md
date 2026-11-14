---
name: xpz-mcp-integrations-setup
description: Instala, audita, repara, atualiza e remove componentes MCP externos opcionais nos clientes de agente; na v1 cobre o Jev/System One em OpenCode e Codex, com pacote vendorizado, credencial em cofre DPAPI e nada gravado sem aprovacao
---

# xpz-mcp-integrations-setup

Skill de ciclo de vida de **componentes MCP externos opcionais** nos clientes de
agente. A v1 cobre o **Jev/System One** (`@jkudish/jev-mcp` 0.13.0) em
**OpenCode** e **Codex**, no Windows. O motor e dirigido por descritor
(`components/jev.json`); o fornecedor implementado e **`compatible`** com o
preset **Command Code**.

Esta skill **nao** gerencia skills, instrucionais globais, `nexa`/`gam`, bootstrap
git nem o MCP interno do Cursor. Isso continua com a `xpz-skills-setup`.

## GUIDELINE

- **Auditar antes de agir.** O ponto de entrada e `scripts/Test-McpIntegrations.ps1`.
  Ele nao grava, nao remove e nao altera config de cliente, e nao cria arquivo
  temporario: a sonda TOML do Codex recebe o `config.toml` pela entrada padrao.
- **Nada gravado sem aprovacao explicita.** Mostre estados, achados e a acao
  oferecida; so execute o mutador depois do `sim`/`aprova` do usuario.
- **Diff antes da escrita.** Rode o mutador com `-WhatIf` quando houver duvida,
  mostre o diff e peca aprovacao.
- **Chave so no cofre DPAPI.** Nunca grave a chave em `opencode.json(c)`,
  `config.toml`, `config.json`, log, prompt ou mensagem.
- **Sem `npx` em runtime.** O pacote e vendorizado e pinado por integrity
  sha512 no lockfile; a instalacao usa `npm ci --ignore-scripts`.
- **Nao editar config de cliente a mao.** Use os adaptadores; eles preservam
  comentarios e demais entradas e falham fechado em conflito.
- **Nao usar `-CheckCredential` sem autorizacao por execucao.** E uma chamada
  autenticada online opt-in; `boot_ok` nao prova credencial.
- **Nao usar `claude mcp list`.** Claude Code esta no F2; se a frente voltar,
  a auditoria e `claude mcp get`.

## FRONTEIRA COM A `xpz-skills-setup`

| Skill | Escopo |
|---|---|
| `xpz-mcp-integrations-setup` | MCPs externos opcionais, cofre DPAPI, vendorizacao do componente, config de cliente |
| `xpz-skills-setup` | registro de skills, instrucionais globais, `nexa`/`gam`, bootstrap git, MCP interno do Cursor |

As duas podem escrever no mesmo `opencode.jsonc`. A skill de integracoes **nao**
toca em `agent.reviewer-ro`, `instructions` ou outras chaves; o adaptador
preserva o restante do arquivo. A ponte documental entre as duas fica na
`xpz-skills-setup`, fora do recibo de revisao.

## ESCOPO DA V1

- **Componente:** Jev/System One (`@jkudish/jev-mcp` 0.13.0).
- **Clientes:** OpenCode (global `~/.config/opencode/`) e Codex
  (`~/.codex/config.toml`).
- **Plataforma:** Windows. Cofre DPAPI `CurrentUser`, sem roaming.
- **Ciclo:** detectar, instalar, auditar, reparar, atualizar, remover.
- **Credencial:** cofre neutro; importacao unica de `opencode auth export`
  (preferido) ou `auth.json` (reserva). A reserva procura
  `.local\share\opencode\auth.json` (OpenCode V2) e depois
  `.config\opencode\auth.json` (legado), aceitando `type=key` e `type=api`;
  a selecao continua restrita a `commandcode` e o resultado diagnostica
  caminhos tentados e provedores encontrados, sem valores de chave.
- **Fornecedor:** somente `compatible` com preset Command Code; os outros quatro
  modos ficam no F4.

## NAO-ESCOPO DA V1

Fork; Cursor; Claude Code; macOS/Linux; instalar ferramentas de agente; criar
conta; `skills/jev/`; uso automatico; MCPs sem descritor; vender fornecedores
nao provados; projeto-local do OpenCode (`.opencode/`).

## CAMINHOS GERENCIADOS

Tudo sob `%LOCALAPPDATA%\xpz-mcp-integrations\`. O nome da skill é
`xpz-mcp-integrations-setup`; o diretório de dados permanece
`%LOCALAPPDATA%\xpz-mcp-integrations` como namespace estável de runtime.

```text
config.json                  registro nao secreto (baseUrl, model, endpointConfirmed)
install-manifest.json        versao, launcher, hashes emitidos e e2e
vault\credential.blob        DPAPI CurrentUser; unica fonte da chave na v1
launcher-<versao>.ps1        copia emitida do molde; o cliente aponta para ela
vendor-<versao>\             package.json + lock + node_modules instalados
```

O molde do launcher fica versionado em `templates/launcher.ps1`. O repositorio e
a fonte revisavel; a copia emitida tem sentinela e hash no manifesto. Nao ha
junction/symlink nem indirecao mutavel.

## DESCRITOR

`components/jev.json` declara, para cada fornecedor, `secretEnvVar`, variaveis
publicas permitidas, campos obrigatorios, regras de exclusividade, preset e
regra de endpoint. O schema e **fail-closed**: chave desconhecida, modo
implementado diferente de `compatible`, integrity invalida ou preset inexistente
bloqueiam. O descritor e validado no F1 e no self-test.

## FLUXO OPERACIONAL

1. **Auditar**

   ```powershell
   pwsh -NoProfile -File scripts/Test-McpIntegrations.ps1
   ```

   O stdout e JSON de maquina. Leia `overall`, `findings`, `clients` e
   `nextActions`. `INTEGRATIONS_OK` e **estrutural**: entrada reconhecida em cada
   cliente gerenciado e nenhum achado `blocking`. Credencial verificada e um eixo
   separado. Para fixtures, `-InputPath <json>` aceita `userProfile`/`localAppData`;
   sem ele, o motor usa o ambiente real.

2. **Credencial (se ausente)**

   ```powershell
   pwsh -NoProfile -File scripts/Set-McpCredential.ps1 -Action set
   # ou, para bootstrap unico:
   pwsh -NoProfile -File scripts/Set-McpCredential.ps1 -Action import -ImportFromOpenCode
   ```

   A importacao **nao altera** `auth.json` e nao imprime a chave. Se houver mais
   de uma credencial ativa para `commandcode`, o estado e `credencial_ambigua` e
   nada e gravado.

3. **Planejar a instalacao**

   ```powershell
   pwsh -NoProfile -File scripts/Install-McpIntegration.ps1 -Action install -Client all -WhatIf
   ```

   Mostre o diff/plano. O instalador cria o managed root com ACL so-dono, instala
   o vendor, emite o launcher, grava `config.json` e a entrada nos clientes.

4. **Executar a instalacao aprovada**

   ```powershell
   pwsh -NoProfile -File scripts/Install-McpIntegration.ps1 -Action install -Client all
   ```

   Com `-Client all`, conflito ou `edicao_manual_necessaria` em um cliente **nao**
   desfaz o que ja foi gravado noutro cliente nem vendor/launcher/`config`.
   Apresente sempre o **cliente** e o **erro** (`findings[].client` + `message` /
   trecho-diff) e pare para decisao humana naquele cliente; o overall pode sair
   `INTEGRATIONS_GAPS` com gravacao parcial intencional.

5. **Revalidar e pedir recarga**

   Rode a auditoria de novo. `escrito`/`recarga_pendente` significam que a
   entrada existe, mas o cliente pode precisar de reload/reinicio. A skill
   informa a acao; nao reinicia o cliente sozinha.

6. **Reparar** (re-resolve Node, re-emite launcher/config):

   ```powershell
   pwsh -NoProfile -File scripts/Install-McpIntegration.ps1 -Action repair -Client all
   ```

7. **Atualizar** (consciente, com `-AllowUpdate`; nunca por existir versao nova):

   ```powershell
   pwsh -NoProfile -File scripts/Install-McpIntegration.ps1 -Action update -Client all -AllowUpdate
   ```

   A atualizacao de versao exige novo `package.json`/`package-lock.json` no
   repositorio. Rollback = versao anterior do repositorio + backup do config.

8. **Remover a entrada**

   ```powershell
   pwsh -NoProfile -File scripts/Uninstall-McpIntegration.ps1 -Client all
   ```

   Preserva cofre, `auth.json`, fornecedor e demais MCPs. Launcher, vendor,
   config e manifesto so saem com `-RemoveSkillData`; `-RemoveVault` remove o
   cofre. Ambos explicitos.

   `changed` no JSON vale so para mudanca real em disco ou no manifesto (com
   `-WhatIf` e sempre `false`; o plano aparece em `planned` e nos campos
   `*Removed`).

   `-RemoveSkillData` exige manifesto sem clientes **e** nenhuma entrada jev
   live restante (OpenCode/Codex); se ainda houver, `dados_compartilhados_em_uso`
   (exit 67) e o shared permanece.

   Conflito `opencode.json`+`jsonc`, heuristica Codex (quoted/inline/subtable)
   ou Codex sem Python com qualquer `mcp_servers` (fail-closed) tambem
   bloqueiam. Install em `unchanged` reancora hash no manifesto quando a
   ancora falta (ex.: manifesto perdido).

## OPENCODE

- **Raiz gerenciada:** global `~/.config/opencode/`.
- **Alvo:** `opencode.json` **ou** `opencode.jsonc`. Se os dois existirem,
  `entrada_em_conflito` e nada e gravado.
- **Forma canonica:** `mcp.servers.jev`, `type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo `environment`
  (nao `env`), `disabled` como desligamento.
- **Forma legada:** `mcp.jev` reconhecida para leitura; migracao com
  `-MigrateLegacy` e diff aprovado, **ou** quando o hash da entrada ja
  estiver no `install-manifest.json` (emissao anterior desta skill). Se as
  duas formas coexistirem, conflito.
- **Auditoria da forma legada:** `mcp.jev` unico e migravel →
  `edicao_manual_necessaria` (exit 67) com
  `Install-McpIntegration.ps1 -Client opencode -MigrateLegacy` no
  `nextActions`; canonico editado, duas formas coexistindo ou grafia nao
  migravel → `entrada_em_conflito` (exit 66).
- **Edicao:** mecanismo JSONC ja usado pelo `reviewer-ro` (insercao textual +
  `ConvertFrom-Jsonc` + comparacao pos-edicao). Qualquer falha → nada gravado,
  `edicao_manual_necessaria` e trecho pronto.
- **Reconhecimento:** a skill substitui/remove entrada se for byte-identica
  a forma que ela emitiria agora (`baseUrl`/`model` do `config.json`
  efetivo; sem config, o preset) **ou** se o hash estiver no
  `install-manifest.json`; qualquer outra coisa e conflito.

## CODEX

- **Alvo:** `~/.codex/config.toml`.
- **Bloco:** `[mcp_servers.jev]` entre marcadores de comentario da skill.
- **Deteccao/validacao:** `tomllib` do Python 3.11+ (somente leitura), cobrindo
  qualquer grafia equivalente. Sem Python 3.11+, o Codex cai em
  `edicao_manual_necessaria` com o trecho pronto; o resto da skill segue.
- **Migracao manual:** a grafia e classificada **antes** de sugerir
  `-MigrateLegacy`. So um unico cabecalho `[mcp_servers.jev]` e migravel (com
  `-MigrateLegacy`); outras grafias (ex.: `mcp_servers.jev.command`) →
  `entrada_em_conflito` (exit 66) direto, sem `manual`/`nextActions` de migrate.
  A auditoria classifica o caso migravel como `edicao_manual_necessaria`
  (exit 67) e o `nextActions` inclui
  `Install-McpIntegration.ps1 -Client codex -MigrateLegacy`.
- **Encerramento:** o bloco emitido e o unico trecho que a skill substitui ou
  remove; o restante do TOML e preservado.

## AUDITORIA, ESTADOS E EXIT CODES

Estados por cliente, **um valor so**, na ordem:

`nao_configurado` → `escrito` → `recarga_pendente` → `boot_ok` →
`endpoint_alcancavel` → `credencial_verificada` → `e2e_opt_in_confirmado`.

- **Offline:** os achados (`ausente`, `entrada_*`, `vendor_*`, `launcher_*`,
  `node_*`, `config_*`, `credencial_ausente` **blocking**, `acl_nao_aplicavel`
  como **warn** na auditoria) sao diagnosticos, nao estados concorrentes.
  `credencial_ausente` derruba `INTEGRATIONS_OK` (exit 61). O warn de ACL cobre
  raiz gerenciada, `config.json`, manifesto, `vault\` e blob quando existem;
  nao derruba `INTEGRATIONS_OK` sozinho.
- **Sondas de pre-requisito:** `Get-McpCommandInfo` só classifica os comandos
  como presentes se iniciarem, terminarem em até 8 s com exit code 0 e a saída
  contiver uma versão reconhecida para aquele comando. `pwsh` funcional em
  `WindowsApps` continua elegível; stub de outros comandos nessa pasta continua
  recusado.
- **Precedencia de exit code:** com mais de um achado `blocking`, vence o
  primeiro codigo presente em `precedence` no `exit-codes.catalog.json`:
  `67 > 66 > 61 > 62 > 63 > 64 > 65 > 60`. `nextActions` segue a mesma ordem.
  `69` fica fora (falha interna do trap); `68` e warn-only.
- **`nextActions` e menu:** a lista e de **acoes possiveis**, nao de uma
  sequencia de execucao. O primeiro item casa com o exit code, mas pode
  depender de outro: a migracao manual exige cofre
  (`Set-McpCredential.ps1`) antes de
  `Install-McpIntegration.ps1 -MigrateLegacy`.
- **`boot_ok`:** so prova que o servidor sobe; o boot sai `0` ate com chave
  invalida. Use `-CheckBoot` (local, opt-in) para medir.
- **`credencial_verificada`:** so por `-CheckCredential` (online opt-in, uma
  chamada autenticada por execucao). Criterio: `200` e `answers` com a chave do
  probe e `noul` numerico em `[0,1]`; `choice` nao e usado.
- **`endpoint_alcancavel`:** diagnostico separado; nao implica credencial.
- **`e2e_opt_in_confirmado`:** so depois de E2E manual aprovado com
  `jev_classify`; registre com
  `Install-McpIntegration.ps1 -Action record-e2e -Client <cliente>`.

Faixa reservada de exit codes: **60-69** (tabela completa em
`exit-codes.catalog.json`, sem colisao com o catalogo MSBuild).

| Exit | Quando |
|---|---|
| 0 | sucesso / `INTEGRATIONS_OK` |
| 60 | gaps sem codigo especifico |
| 61 | credencial ausente/ilegivel |
| 62 | config ausente/invalida ou endpoint nao confirmado |
| 63 | Node/npm/pwsh insuficiente |
| 64 | vendor ausente/divergente ou `npm ci` falhou |
| 65 | launcher ausente/divergente |
| 66 | entrada quebrada/divergente/em conflito |
| 67 | edicao manual, ACL, lock, corrida ou credencial ambigua |
| 68 | reservado na v1 (python_indisponivel e warn; GAPS so com warn → piso 60) |
| 69 | falha interna do launcher/motor |

Os cinco motores (`Test-McpIntegrations`, `Install-McpIntegration`,
`Uninstall-McpIntegration`, `Invoke-McpVendor` e `Set-McpCredential`) capturam
falha no nivel do script via `Write-McpInternalFailure`/`Resolve-McpTrapFailure`:
`XPZ_MCP_LOCKED`/`XPZ_MCP_RACE`/`ACL` → exit **67** com o codigo correspondente;
demais falhas internas → exit **69** e achado `erro_interno`. O launcher tambem
usa 69 para falha interna. Se a falha ocorrer antes do carregamento da biblioteca
de suporte, o JSON de contingencia usa `kind=xpz-mcp-integrations-setup-internal-error`
e exit 69.

## SEGURANCA E LIMITES

- **Cofre:** DPAPI `CurrentUser`, sem entropia adicional; ACL so-dono no diretorio
  e no blob. `acl_nao_aplicavel` **bloqueia** mutadores de blob na v1; na
  auditoria offline o mesmo codigo e **warn** (descoberta precoce, sem vetar
  `INTEGRATIONS_OK`).
- **Limite honesto:** DPAPI protege em repouso; nao protege contra processo do
  mesmo usuario, inspecao do ambiente do filho nem roaming.
- **Launcher:** `ProcessStartInfo` com stdio herdado, ambiente limpo + allowlist
  do descritor, `JEV_API_KEY` lida do cofre, zero bytes do launcher em stdout e
  exit code do filho propagado. O encerramento depende do fim do stdin; se o
  cliente nao fechar, o filho pode ficar orfao (risco aceito sem Job Object).
- **Rede:** o instalador so usa rede em install/update (`npm ci`); o launcher/MCP
  so fala com o endpoint configurado. A contencao de rede **nao foi demonstrada**
  nesta maquina; o teste isolado e endurecimento opt-in do Anexo B.4.6 do design.
- **`dist`:** evidencia sanitizada commitada com proveniencia; o gate do F1 e
  revisao estatica + boot sem chave. Nao valida credencial/endpoint/modelo.

## SELF-TESTS

Offline, declarados no `09` e **nao** rodados pelo orquestrador de pre-push:

```powershell
pwsh -NoProfile -File scripts/Test-McpOpenCodeAdapterSelfTest.ps1
pwsh -NoProfile -File scripts/Test-McpCodexAdapterSelfTest.ps1
pwsh -NoProfile -File scripts/Test-McpLauncherSelfTest.ps1
pwsh -NoProfile -File scripts/Test-McpCredentialSelfTest.ps1
pwsh -NoProfile -File scripts/Test-McpExitCodesSelfTest.ps1
pwsh -NoProfile -File scripts/Test-McpIntegrationsSelfTest.ps1
```

Gate do `dist` (exige vendor real instalado em um managed root descartavel):

```powershell
$root = Join-Path $env:TEMP ('xpz-mcp-dist-' + [guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA = $root
$env:USERPROFILE = $root
pwsh -NoProfile -File scripts/Invoke-McpVendor.ps1
pwsh -NoProfile -File scripts/Test-McpDistEvidenceSelfTest.ps1 -ManagedRoot (Join-Path $root 'xpz-mcp-integrations')
# nunca aponte para o root de producao
```

O gate recusa `-ManagedRoot` que ja contenha `install-manifest.json`, `config.json`,
`vault\` ou `launcher-*.ps1`; o root deve ter apenas o `vendor-0.13.0` necessario.
O que o teste criar e removido no `finally`.

Tokens: `XPZ_MCP_OPENCODE_ADAPTER_SELFTEST_OK`,
`XPZ_MCP_CODEX_ADAPTER_SELFTEST_OK`, `XPZ_MCP_LAUNCHER_SELFTEST_OK`,
`XPZ_MCP_CREDENTIAL_SELFTEST_OK`, `XPZ_MCP_EXIT_CODES_SELFTEST_OK`,
`XPZ_MCP_INTEGRATIONS_SELFTEST_OK`, `XPZ_MCP_DIST_EVIDENCE_SELFTEST_OK`.

## TRIGGERS

Use esta skill para:

- instalar/auditar/reparar/atualizar/remover o Jev/System One em OpenCode/Codex;
- diagnosticar por que o MCP nao aparece ou nao responde;
- importar a credencial `commandcode` do OpenCode para o cofre DPAPI;
- revisar o pacote vendorizado, o launcher e a evidencia do `dist`;
- reconciliar uma entrada manual `mcp.jev`/`[mcp_servers.jev]` com a forma
  gerenciada, com diff e aprovacao.

## DO NOT USE

- para registrar skills ou instrucionais globais (use `xpz-skills-setup`);
- para instalar Node, npm, pwsh ou Python automaticamente (a skill detecta e
  oferece o comando; a instalacao e do usuario);
- para criar conta no provedor ou escolher fornecedor fora do preset;
- para editar config de cliente a mao quando o adaptador recusar;
- para rodar `-CheckCredential` sem autorizacao explicita por execucao;
- para prometer contencao de rede ou E2E nao demonstrados.

## REFERENCIAS

- `xpz-mcp-integrations-design.md` (design v24.2; F1 congelado em 2026-11-09).
- `xpz-skills-setup/SKILL.md` (fronteira).
- `xpz-llm-delegate/SKILL.md` (mecanismo JSONC do `reviewer-ro`; o
  `commandcode/*` ali e catalogo de vozes do painel, nao o endpoint do Jev).
- `https://github.com/jkudish/jev-mcp` (MIT).
