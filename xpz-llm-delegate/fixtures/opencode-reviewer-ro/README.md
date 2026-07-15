# Fixtures — agente opencode `reviewer-ro` (least-privilege)

Fixtures versionados que ancoram os claims empíricos do agente `reviewer-ro` (revisor por pares
"sem execução/escrita") contra deriva de versão do opencode. Fonte-verdade do design:
[`opencode-reviewer-ro-least-privilege-design.md`](../../../opencode-reviewer-ro-least-privilege-design.md).

Consumidos por `scripts/OpenCodeReviewerRoGuard.ps1` (pré-check runtime) e por
`scripts/Test-OpenCodeReviewerRoSelfTest.ps1` (gate de processo/CI).

## Versão medida

`VERSION.txt` = **1.17.20**. O pré-check compara `opencode --version` contra este valor
(cláusula de validade). Versão diferente ⇒ BLOCK com motivo `version` — os claims de resolução
podem não valer. Antes de concluir falha operacional, rode
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` a partir da raiz do repo:
`needsFixtureRecapture` significa que a estrutura local está OK, mas os fixtures empíricos ainda
não foram promovidos para a versão instalada; `blocked` indica problema estrutural a corrigir.

## Arquivos

- `VERSION.txt` — versão do opencode contra a qual os claims foram medidos.
- `fallback-warning.txt` — warning verbatim que o opencode emite em `run --agent <ausente>` (cai
  silenciosamente no agente default, hoje `build` full-access). O pós-check varre o stderr pelo
  padrão lógico exposto por `Get-OpenCodeReviewerRoFallbackWarningPattern`; no contrato v2 do
  watcher esse mesmo valor alimenta `fallbackDetail.stderrPattern` sem copiar o literal em outros
  produtores/consumidores.
- `agentlist-reviewer-ro.sample.txt` — bloco canônico (sanitizado) do `opencode agent list` para o
  `reviewer-ro` na forma `permission`. Os caminhos reais de `external_directory` (dirs de skills da
  máquina) foram substituídos por `<SANITIZED_SKILL_DIR>`; as regras de ferramenta são as reais.
  Base do parser e do fake-exe do self-test.
- `equiv-permission-vs-tools.sample.txt` — **equivalência `permission: deny` ≡ `tools: false`**
  (medida em 1.17.20): dois agentes-probe que negam a MESMA tool (`webfetch`), um pela forma
  `permission: { webfetch: deny }`, outro pela forma `tools: { webfetch: false }`, resolvem
  **idêntico** no `agent list` — ambos `webfetch → deny`. Ancora a refutação da nota antiga
  migrada para `historico/IdeiasImplementadas_202607.md` («`tools: false` mais forte que
  `permission: deny`»).
- `merge-global-only-reviewer-ro.sample.txt` — resolução do `reviewer-ro` quando **só** o global
  provisionado aplica (cwd sem `.opencode/`). Em 1.17.20 a captura sanitizada resolve o mesmo
  contrato least-privilege do project-local: `*` final `deny` + allow-set `{read,grep,glob,list}`.
  Como o bloco efetivo hoje fica byte-equivalente ao fixture project-local, este fixture cobre o
  contrato efetivo fora da raiz do repo; ele não prova, sozinho, semântica de merge/substituição
  campo a campo.
- `read-outside-cwd-blocked.sample.txt` — **captura behavioral** (design D4 «leitura fora do cwd
  bloqueada headless»): reviewer-ro (com glm-5.2) pedido para ler um arquivo FORA do cwd → **sem
  leak** do sentinela; a resolução `external_directory[*]=deny` é a rede mecânica. Golden/documental
  (o self-test determinístico não re-executa o modelo real; a asserção CI vive no caso (d)).

## Resolução efetiva medida (1.17.20) — `agent list`, last-match-wins

Excluindo `external_directory` e os gates internos (`doom_loop`, `question`, `plan_enter`,
`plan_exit`):

| permission | ação efetiva |
|------------|--------------|
| `*`        | **deny** (curinga default-deny; o bloco project-local aparece por último e sobrepõe o `* allow` global) |
| `read`     | allow |
| `grep`     | allow |
| `glob`     | allow |
| `list`     | allow |
| `edit`     | deny |
| `bash`     | deny |
| `webfetch` | deny |
| `websearch`| deny |
| `task`     | deny |

**allow-set resolvido = `{read, grep, glob, list}`** (o pré-check assere o CONJUNTO exato — trava
divergência por ausência E por excesso, ex.: `bash` reaparecendo por regra tardia da global).

`external_directory` padrão `*` resolve **deny** (a base do opencode é `ask`, auto-rejeitada em
`opencode run` headless; o `external_directory: deny` explícito do reviewer-ro torna o bloqueio
padrão de leitura fora do cwd independente do modo). Os fixtures 1.17.20 também trazem exceções
`allow` para diretórios internos do opencode, como `<SANITIZED_OPENCODE_TOOL_OUTPUT_DIR>`; o guard
atual verifica o padrão `*`, não uma proibição absoluta de todo path externo específico.

Risco residual urgente: os fixtures 1.17.20 mostram regras nativas `read "*.env" -> ask` e
`read "*.env.*" -> ask` antes do bloco final do `reviewer-ro`, que volta a permitir `read "*"`.
Pela regra `last-match-wins`, isso tende a deixar `.env` legível dentro do cwd; o recorte está
registrado em `999-ideias-pendentes.md` como alta prioridade.

## Como re-capturar (refresh após upgrade do opencode)

Numa cwd que descubra o `.opencode/agent/reviewer-ro.md` project-local (a raiz deste repo):

```
opencode --version
opencode agent list        # extrair o bloco `reviewer-ro (all)`
```

Atualizar `VERSION.txt`, `agentlist-reviewer-ro.sample.txt` (sanitizando os paths de
`external_directory`) e re-rodar `scripts/Test-OpenCodeReviewerRoSelfTest.ps1` até verde antes de
reativar o default `-Agent reviewer-ro`. O diagnóstico estrutural
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` ajuda a confirmar o estado
instalado, mas não substitui a recaptura behavioral (`read-outside-cwd-blocked.sample.txt`) quando a
versão do opencode muda.
