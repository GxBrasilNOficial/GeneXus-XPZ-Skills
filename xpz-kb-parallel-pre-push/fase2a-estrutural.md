# Fase 2a — estrutural (higiene de frente e pacote)

Satélite de [`SKILL.md`](SKILL.md). A Fase 2a é **parcial scriptada** (o que é mecanicamente verificável vira gate) **+ checklist de agente** (o resto). Nunca bloqueia push — emite `warn` para o usuário decidir.

## Motor: `Test-XpzKbFrenteHygiene.ps1`

Motor compartilhado, agnóstico de KB, **filesystem-only** (não usa git). Valida a higiene das pastas de geração e de pacotes de importação da pasta paralela.

```text
pwsh -File <repo-skills>\scripts\Test-XpzKbFrenteHygiene.ps1 -RepoRoot <pasta-paralela-da-KB>
```

- **`-RepoRoot`** *(default: diretório corrente)* — raiz da pasta paralela.
- **`-FrentesDirName`** *(default: `ObjetosGeradosParaImportacaoNaKbNoGenexus`)* — pasta de geração por frente.
- **`-PacotesDirName`** *(default: `PacotesGeradosParaImportacaoNaKbNoGenexus`)* — pasta de pacotes.
- **`-AsText`** saída humana; **`-AsJson`** é no-op (JSON é o default).

### Cheques

- **Cheque 1 — subpasta de frente** deve seguir `NomeCurto_GUID_YYYYMMDD` (regra de `xpz-kb-parallel-setup`). `NomeCurto` pode conter underscores (frentes derivadas como `CriaAnimalRefatora_..._20260520_ba03` são legítimas); o GUID e o `YYYYMMDD` ancoram o final, e um sufixo alfanumérico opcional após a data (como `_ba03`) é aceito. Frente com nome fora desse padrão aparece no relatório, mas o executor de faxina só a remove com plano salvo e decisão humana. Severidade: **warn**.
- **Cheque 2 — pacote** `<frenteName>_<nn>.{import_file.xml,xpz}` deve ter `<frenteName>` existindo como subpasta-fonte de frente. Pacote **órfão** = sem subpasta-fonte rastreável. Severidade: **warn**.

Ambos são `warn` (não bloqueiam) porque podem ter justificativa legítima (frente deletada após import bem-sucedido; frente experimental fora do padrão). O usuário decide aceitar ou corrigir.

### Contrato de saída

JSON de máquina por padrão. Campos: `Kind` (`xpz-frente-hygiene-result`), `SchemaVersion` (`2`), `status` (`ok`|`warn`), `exitCode`, `repoRoot`, `frentesDir`, `pacotesDir` (caminhos resolvidos/normalizados), `frentesValidas`, `frentesNaoConformes[]` (nomes), `pacotesOk`, `pacotesOrfaos[]` (`{pacote, frenteEsperada}`), `pacotesNaoPadronizados[]`, `pacotesVinculados[]` (`{pacote, frente, frenteStatus}` com `frenteStatus` = `valida`|`naoConforme`|`ausente`; base da cascata), `sidecarsOrfaos[]` (sidecar `<pacote>.package-inventory.json` sem o pacote correspondente) e `pacotesRejeitados[]` (`{base, contagem}` de `<base>.rejected.<A..Z>`; informativo). **Exit: 0 ok, 2 warn.** Fase 2a nunca bloqueia push.

Este JSON é o **contrato de consumo** do executor de faxina (ver abaixo): renomear/retipar campos aqui quebra o executor; o lockstep é travado por `Test-XpzKbFrenteHygieneCleanupSelfTest.ps1`.

## Higiene local: as pastas inspecionadas são tipicamente gitignoradas

`ObjetosGeradosParaImportacaoNaKbNoGenexus/` e `PacotesGeradosParaImportacaoNaKbNoGenexus/` são **área de trabalho local** — na maioria das KBs paralelas elas são **gitignoradas**. Portanto os `warn` da Fase 2a são **higiene da área de trabalho local**, distinta do conteúdo que vai no push: calibra a severidade na leitura (não confundir com problema do que será publicado). Quando são gitignoradas, **remoção ali não tem recuperação por git**. Por isso o executor abaixo envia à **Lixeira do Windows** por padrão e exige plano salvo para qualquer remoção. A Lixeira **não é backup**: as políticas do Windows podem esvaziá-la, e a verificação só relata uma perda que já aconteceu.

## Faxina: `Remove-XpzKbFrenteHygieneFindings.ps1` (forma canônica de corrigir)

Motor compartilhado, agnóstico de KB, **filesystem-only**. **Consome** o JSON de `Test-XpzKbFrenteHygiene` (fonte de verdade única — não reimplementa o matching) e remove exatamente o flagado.

```text
# 1) dry-run: mostra o plano completo (inclui a cascata) e grava o plano salvo
pwsh -File <repo-skills>\scripts\Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot <pasta-paralela> -PlanPath <arquivo-novo-fora-das-pastas-alvo>
# 2) apply: só roda com o plano salvo; para se os campos comparados diferirem
pwsh -File <repo-skills>\scripts\Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot <pasta-paralela> -Apply -JsonPath <arquivo-do-passo-1>
```

- **Dois passos obrigatórios.** O dry-run (sem `-Apply`) não remove nada e grava o plano com `-PlanPath` (arquivo novo, fora de `frentesDir` e `pacotesDir`). O `-Apply` exige `-JsonPath` com esse plano; sem ele, `blocked`. Se os campos comparados diferem do plano salvo, `blocked`, sem remover nada. `-WhatIf` com `-Apply` mostra `whatif`.
- **Plano salvo (formato do arquivo de `-PlanPath`):** JSON com `Kind='xpz-frente-hygiene-plan'` e `SchemaVersion=1`. Essa versão é a do *plano*: é independente da `SchemaVersion=2` da saída do executor e da do motor. Campos: `repoRoot`, `frentesDir`, `pacotesDir` (caminhos canônicos), `scope`, `method` (`recycle` | `permanent` | `backup`), `exclusions[]` (`{kind, name, status='excluido'}`) e `items[]` (`{kind, name, path, method, bytes, files, mtimeMaxTicks, pathsSha256}`), com `kind` = `sidecar` | `pacote` | `frente`, na ordem de execução (pacote antes do sidecar; frentes por último).
- **Validação do `-Apply` contra o plano salvo:** `Kind` e `SchemaVersion=1` (outro valor → `blocked`); `repoRoot`, `frentesDir`, `pacotesDir` e `scope` devem bater com a execução atual (senão `blocked`); o conjunto de `items` e `exclusions` recalculado deve ser igual ao salvo, comparando `kind`, `name`, `method`, `files`, `bytes`, `mtimeMaxTicks` e `pathsSha256`. Diferença nesses campos → `blocked`, sem remover nada. `pathsSha256` representa os caminhos relativos, não o conteúdo. Para uma frente, `files` e `bytes` são totais e `mtimeMaxTicks` é a data mais recente dos arquivos; assim, alterações de conteúdo podem passar despercebidas se esses campos e os caminhos permanecerem iguais. O `path` gravado no plano é informativo: na execução ele é recalculado a partir de `name`, e nomes com separador ou `..` são recusados.
- **Método:** padrão é **Lixeira do Windows** (`SendToRecycleBin` com `UIOption.OnlyErrorDialogs`: janela do Windows só aparece em caso de erro). `-Permanente` apaga em definitivo (explícito). `-Backup <dir> -RunStamp <id>` move para fora das pastas-alvo, no mesmo volume, com `backup-manifest.jsonl`. `-Permanente` e `-Backup` não combinam.
- **Pré-condições da Lixeira** (verificadas antes da primeira ação, para a lista inteira): sessão não elevada; volume fixo local; `NukeOnDelete` = 0 explícito; `MaxCapacity` legível; a lista cabe no limite descontada a ocupação do usuário atual. Qualquer falha → `blocked`, sem fallback para apagamento definitivo.
- **Verificação após cada envio:** o caminho original sumiu, existe um registro `$I` novo com esse caminho (para arquivos, também o tamanho), e o par `$R` do tipo esperado está presente. Falha → `hard-stop` com a fila parada. Limite declarado: cobre só a Lixeira do usuário atual.
- **Cascata:** a remoção de uma frente não conforme aparece no plano pelos pacotes que ela orfana (`pacotesVinculados` do motor). Um plano único cobre a cascata; não há passadas repetidas.
- **Exclusões:** `-ExcludeFrente <nome>` e `-ExcludePacote <nome>`, nome exato. Nome sem correspondência no disco → `blocked`. Excluídos aparecem em `exclusions[]` e deixam o status em `applied-with-skips`.
- **Escopo:** `-Scope` `Frentes`|`Pacotes`|`Ambos` (default `Ambos`). Órfão fora do escopo é resíduo (`applied-with-skips`), não `applied-clean`. `pacotesNaoPadronizados` **nunca** é tocado.
- **Sidecar:** `<pacote>.package-inventory.json` sai junto com o pacote. Sidecar órfão é só informado.
- **`.rejected` de pacote removido nesta execução:** fica no disco e não altera o status (`applied-clean` continua possível), mas aparece em `rejeitadosRestantes` no resultado do `-Apply` e no texto. Limpeza é manual pelo operador (`02-regras-operacionais-e-runtime.md`).
- **`.rejected`:** informativo (`pacotesRejeitados[]`). Não é removido nem altera o status.
- **Segurança:** ancora os diretórios-base sob `-RepoRoot` canônico, recusa reparse point (junction/symlink) no caminho ou no item, e remove diretório por descida bottom-up: lista os descendentes com `Get-ChildItem -Recurse` e apaga item a item, recusando reparse point em cada um.
- **Saída:** 1 linha JSON (`Kind='xpz-frente-hygiene-cleanup-result'`, `SchemaVersion=2`); texto humano só com `-AsText`. `status`: `clean`|`findings`|`whatif`|`blocked`|`applied-clean`|`applied-with-skips`|`hard-stop`. **Exit:** 0 `clean`/`whatif`/`applied-clean`; 2 `findings`; 3 `applied-with-skips`; 1 `blocked`/`hard-stop`. Automação lê `status`, não o número.
- **Não é passo automático da pré-push.** A pré-push continua sendo análise + relatório; a faxina é ação separada, sob decisão humana. Validação: `Test-XpzKbFrenteHygieneCleanupSelfTest.ps1` (token `XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK`). O caso de Lixeira real é opt-in: `XPZ_FAXINA_SELFTEST_LIXEIRA=1`.
- **Não testado:** arquivo bloqueado (aberto na IDE) durante o envio; rede e outros volumes; Lixeira desativada por política; cota estourada; `subst`.

### Limitações aceitas (decisão do operador, 2026-11-16)

Registradas para não serem reabertas sem motivo novo. Nenhuma delas bloqueia o uso do executor.

| Limitação | Comportamento atual | Decisão |
|---|---|---|
| Arquivo aberto entre a checagem e o envio | A checagem de arquivo em uso roda antes da primeira ação. Uma janela curta permanece: se um arquivo for aberto nesse intervalo, o envio pode falhar (hard-stop) ou seguir. No envio à Lixeira o dano é recuperável. Em `-Permanente` a janela é mais grave, porque a remoção é definitiva. | Aceita. Risco baixo e calculado para o uso atual (envio à Lixeira). Revisar se o modo `-Permanente` passar a ser usado de rotina. |
| `subst` (unidade virtual) | A leitura da política da Lixeira usa a letra da unidade do `-RepoRoot`. Com `subst`, pode ler o volume virtual em vez do disco real. O pior caso previsto é bloqueio (lado seguro) ou leitura de política do volume errado. Não verificado. | Aceita sem teste. |
| Cota da Lixeira por usuário | A checagem de limite considera só a ocupação do usuário atual. | Aceita (decisão do operador). |
| Rede, mídia removível, Lixeira desativada por política, cota estourada | Bloqueiam antes da primeira ação, pelas pré-condições do método Lixeira. Não testado na prática. | Aceita: o bloqueio é o comportamento esperado. |
| `-Backup` em outro volume | Recusado com mensagem de erro. | Já registrado no 999. |

## Nuance cabeça-detalhe (vinda do F1)

O filtro F1 (`Compare-XpzChecksums`, ver [`fase2b-classificador-de-regime.md`](fase2b-classificador-de-regime.md)) descarta arquivos `SAME` (checksum inalterado). **Atenção:** `SAME` no **arquivo** X não implica que a **cabeça/objeto** associado a X esteja fora do raio de impacto. Um objeto cabeça pode ter checksum inalterado enquanto seu **detalhe** (outro arquivo) mudou e carrega dependentes. "Descartar SAME cedo" é correto para o **arquivo**, mas o analista **não** pode concluir, só do `SAME`, que a cabeça está fora de escopo — a triagem estrutural (esta fase) e o roteamento de regime (2b) tratam disso.

## Checklist de agente (parte não scriptada)

Além dos dois cheques mecânicos, antes de declarar a Fase 2a saneada:

- [ ] A frente ativa vive na própria subpasta `NomeCurto_GUID_YYYYMMDD` (não na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus`).
- [ ] Não há XML de referência/exemplo/template/molde deixado na subpasta da frente como se fosse objeto a importar.
- [ ] A pasta de pacotes está **plana** (sem subpastas por frente).
- [ ] Pacotes órfãos reportados pelo motor têm justificativa explícita (frente já importada/removida) ou foram corrigidos — a forma **canônica** de corrigir é o executor `Remove-XpzKbFrenteHygieneFindings.ps1` (dry-run com `-PlanPath`, depois `-Apply -JsonPath` sob decisão humana), não deleção manual/ad-hoc.
- [ ] Frentes não-conformes reportadas têm justificativa (experimental) ou foram renomeadas para o padrão; quando a decisão for remover, usar o executor (acima), não recontar/apagar à mão.

O resultado da Fase 2a entra no relatório da rodada (molde em `examples/`) como `warn` consolidável, nunca como bloqueio automático.
