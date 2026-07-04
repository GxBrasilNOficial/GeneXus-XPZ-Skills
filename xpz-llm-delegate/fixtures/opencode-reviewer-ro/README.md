# Fixtures — agente opencode `reviewer-ro` (least-privilege)

Fixtures versionados que ancoram os claims empíricos do agente `reviewer-ro` (revisor por pares
"sem execução/escrita") contra deriva de versão do opencode. Fonte-verdade do design:
[`opencode-reviewer-ro-least-privilege-design.md`](../../../opencode-reviewer-ro-least-privilege-design.md).

Consumidos por `scripts/OpenCodeReviewerRoGuard.ps1` (pré-check runtime) e por
`scripts/Test-OpenCodeReviewerRoSelfTest.ps1` (gate de processo/CI).

## Versão medida

`VERSION.txt` = **1.4.4**. O pré-check compara `opencode --version` contra este valor
(cláusula de validade). Versão diferente ⇒ BLOCK com motivo `version` — os claims de resolução
podem não valer; re-capturar os fixtures e revisitar D2/D3 antes de reativar.

## Arquivos

- `VERSION.txt` — versão do opencode contra a qual os claims foram medidos.
- `fallback-warning.txt` — warning verbatim que o opencode emite em `run --agent <ausente>` (cai
  silenciosamente no `build` full-access). O pós-check varre o stderr por
  `not found. Falling back to default agent`.
- `agentlist-reviewer-ro.sample.txt` — bloco canônico (sanitizado) do `opencode agent list` para o
  `reviewer-ro` na forma `permission`. Os caminhos reais de `external_directory` (dirs de skills da
  máquina) foram substituídos por `<SANITIZED_SKILL_DIR>`; as regras de ferramenta são as reais.
  Base do parser e do fake-exe do self-test.

## Resolução efetiva medida (1.4.4) — `agent list`, last-match-wins

Excluindo `external_directory` (regras por-padrão) e os gates internos (`doom_loop`, `question`,
`plan_enter`, `plan_exit`):

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
`opencode run` headless; o `external_directory: deny` explícito do reviewer-ro torna o confinamento
de leitura ao cwd garantido e independente do modo).

## Como re-capturar (refresh após upgrade do opencode)

Numa cwd que descubra o `.opencode/agent/reviewer-ro.md` project-local (a raiz deste repo):

```
opencode --version
opencode agent list        # extrair o bloco `reviewer-ro (all)`
```

Atualizar `VERSION.txt`, `agentlist-reviewer-ro.sample.txt` (sanitizando os paths de
`external_directory`) e re-rodar `scripts/Test-OpenCodeReviewerRoSelfTest.ps1` até verde antes de
reativar o default `-Agent reviewer-ro`.
