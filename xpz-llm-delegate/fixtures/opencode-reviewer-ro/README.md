# Fixtures — agente opencode `reviewer-ro` (least-privilege)

Fixtures versionados que ancoram os claims empíricos do agente `reviewer-ro` (revisor por pares
"sem execução/escrita") contra deriva de versão do opencode. Fonte-verdade **do design** (congelado;
pins de versão ali são históricos):
[`opencode-reviewer-ro-least-privilege-design.md`](../../../opencode-reviewer-ro-least-privilege-design.md).
Fonte-verdade **da versão medida** (viva): `VERSION.txt` neste diretório.

Consumidos por `scripts/OpenCodeReviewerRoGuard.ps1` (pré-check runtime) e por
`scripts/Test-OpenCodeReviewerRoSelfTest.ps1` (gate de processo/CI).

## Versão medida

`VERSION.txt` = **1.18.33**, promovida em 2026-10-08 após revalidar o conjunto
obrigatório: project-local/global-only com política FINAL, equivalência permission/tools,
warning de fallback e prova behavioral real `run`. A suíte de conteúdo `debug agent`
também passou (33 casos). Histórico 1.18.30 não foi renomeado como prova nova.

Versão diferente ⇒ BLOCK `version`. O diagnóstico
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` separa
`needsFixtureRecapture` de bloqueio estrutural; não substitui recaptura completa.
Self-test determinístico/fake-exe não prova sozinho o comportamento de uma versão nova.

## Arquivos

- `VERSION.txt` — versão legitimamente promovida; comparar com `opencode --version`.
- `agentlist-reviewer-ro.sample.txt` — bloco real project-local em workspace Git sintético,
  com Markdown FINAL e runtime do filho redirecionado; paths internos sanitizados.
- `merge-global-only-reviewer-ro.sample.txt` — bloco real JSONC global-only sintético,
  produzido pelo instalador; descoberta project-local desabilitada só nesta captura.
  Mesmo contrato efetivo do Markdown; não prova merge/substituição campo a campo.
- `equiv-permission-vs-tools.sample.txt` — probes reais `probe-perm`/`probe-tools`:
  `permission: { webfetch: deny }` e `tools: { webfetch: false }` resolvem webfetch deny.
  Esses probes não são agentes reviewer-ro válidos.
- `fallback-warning.txt` — linha verbatim do stderr de `run --agent fixture-agent-missing`,
  capturada antes do erro intencional de modelo inexistente (sem modelo chamado).
  Nesta captura 1.18.33 não houve ANSI; não adicionar nem remover escapes emitidos.
  O accessor `Get-OpenCodeReviewerRoFallbackWarningPattern` permanece a fonte do padrão
  lógico usado pelos adapters/watcher; não exige prefixo ou coloração.
- `read-outside-cwd-blocked.sample.txt` — captura real `opencode run` com
  `commandcode/deepseek/deepseek-v4.1-flash`, configuração normal sem edição global,
  workspace sintético e Markdown FINAL: quatro read, dois erros por permissão,
  fonte comum/exemplo legíveis, token protegido ausente. Inclui .env interno e arquivo
  externo ordinary.txt (fora das exceções internas); não é sonda debug nem autocensura.
- `content-protection.sample.txt` — recibo sanitizado dos 33 casos reais
  `opencode debug agent`, sem modelo; Markdown/JSONC, caminhos e cwd em subpasta Git.
  Erro de permissão comprova deny; exit 1 sozinho não prova. Debug deixa ask passar,
  portanto não usar esta sonda para afirmar comportamento ask headless.

## Resolução efetiva medida (1.18.33) — bloco estrutural canônico

A âncora é o último `permission: "*", pattern: "*", action: "deny"`.
Depois dela o guard exige a sequência canônica completa, sem regras extras,
seguida somente da exceção tool-output interna já medida e presente antes da âncora.
Reaberturas tardias read/grep, `*` e curingas de nome de ferramenta bloqueiam.
Não basta encontrar cinco pares em qualquer posição; o guard não emula caminhos/wildcards.

| permission | contrato após a âncora |
| --- | --- |
| `*` | deny |
| `read` | mapa ordenado abaixo |
| `grep` | deny |
| `glob` / `list` | allow |
| `edit` / `bash` / `webfetch` / `websearch` / `task` | deny |
| `external_directory` padrão `*` | deny |

Mapa read, em ordem: `* allow`, `*.env deny`, `*.env.* deny`,
`.env.example allow`, `*/.env.example allow`. Disponíveis `{read,glob,list}`;
read não é reduzido à ação da última exceção. A exceção exige nome exato e conteúdo
sanitizado pelo operador: service.env.example e .env.example.local ficam negados.
No Windows o CLI ignora caixa e `*` cruza separadores; regras contra caminho inteiro
podem negar diretório com .env. conservadoramente. .env~/.env-example não são protegidos.
`glob` e leitura de diretório mostram nomes; `list` não apareceu na sonda 1.18.33.

Exceções internas de `external_directory` não provam isolamento absoluto;
não foram ampliadas. Links/aliases, outros segredos, prompt/dossiê e carregamento
automático de instruções seguem fora do recorte. Provas debug e run são distintas;
fora dos casos medidos, equivalência é premissa, não garantia de isolamento.

## Como re-capturar (refresh após upgrade do opencode)

Numa cwd que descubra o `.opencode/agent/reviewer-ro.md` project-local (a raiz deste repo):

```
opencode --version
opencode agent list        # extrair o bloco `reviewer-ro (all)`
```

Atualizar o set re-medido completo (sanitizando paths de `external_directory` onde couber):

1. `VERSION.txt`
2. `agentlist-reviewer-ro.sample.txt` (project-local)
3. `merge-global-only-reviewer-ro.sample.txt` (cwd sem `.opencode/`)
4. `equiv-permission-vs-tools.sample.txt`
5. `fallback-warning.txt` (stderr verbatim de `run --agent <ausente>`; manter ANSI se houver)
6. `read-outside-cwd-blocked.sample.txt` (captura behavioral D4; token real → `<SENTINELA>`)
7. `content-protection.sample.txt` (política final em Markdown/JSONC; suíte sintética sem modelo)

Re-rodar `scripts/Test-OpenCodeReviewerRoSelfTest.ps1` até verde antes de reativar o default
`-Agent reviewer-ro`. O diagnóstico estrutural
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` confirma o estado instalado, mas
não substitui a recaptura acima quando a versão do opencode muda.

Nota operacional: free-tier Zen (`opencode/big-pickle` etc.) pode responder no app gráfico e
falhar no CLI com `FreeTierError` («free tier can only be used from within OpenCode»). Para B1/D4
use modelo CLI-capable (assinatura ChatGPT OAuth, OpenCode Go com cota, ou provider com saldo).
