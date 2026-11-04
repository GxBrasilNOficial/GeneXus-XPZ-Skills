# Fixtures — agente opencode `reviewer-ro` (least-privilege)

Fixtures versionados que ancoram os claims empíricos do agente `reviewer-ro` (revisor por pares
"sem execução/escrita") contra deriva de versão do opencode. Fonte-verdade **do design** (congelado;
pins de versão ali são históricos):
[`opencode-reviewer-ro-least-privilege-design.md`](../../../opencode-reviewer-ro-least-privilege-design.md).
Fonte-verdade **da versão medida** (viva): `VERSION.txt` neste diretório.

Consumidos por `scripts/OpenCodeReviewerRoGuard.ps1` (pré-check runtime), por
`scripts/Test-OpenCodeReviewerRoSelfTest.ps1` (gate de processo/CI) e por
`scripts/Test-OpenCodeReviewerRoContentProtection.ps1` (matriz comportamental).

## Versão medida

`VERSION.txt` = **2.2.5**, promovida em 2026-11-03 após revalidar o conjunto obrigatório:
descoberta por `opencode debug agents`, perfis project-local (36 regras) e global-only (21),
equivalência `permission`/`tools`, aviso de fallback, matriz de 32 casos comportamentais com
modelo explícito + 2 casos `grep` estruturais, e os self-tests existentes. A matriz usou
`opencode run --format json` e o modelo explícito
`opencode-go/deepseek-v4.1-flash`; o recibo está em `content-protection.receipt.json` e o resumo
em `content-protection.sample.txt`.

A captura 1.18.33 anterior permanece recuperável pelo histórico do Git; não há diretório de
compatibilidade simultânea.

Versão diferente ⇒ BLOCK `version`. O diagnóstico
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` separa
`needsFixtureRecapture` de bloqueio estrutural; não substitui recaptura completa.
Self-test determinístico/fake-exe não prova sozinho o comportamento de uma versão nova.

## Arquivos

- `VERSION.txt` — versão legitimamente promovida; comparar com o semver de `opencode --version`
  (a CLI 2.2.5 imprime `opencode v2.2.5`; o guard normaliza para `2.2.5`).
- `debug-agents-project-local.sample.json` — captura real de `opencode debug agents` na raiz
  deste repositório (project-local `reviewer-ro` + global), com 36 regras. Campos `system` e
  `description` foram omitidos; `id`, `name`, `mode`, `hidden` e `permissions` são verbatim.
- `debug-agents-global-only.sample.json` — a mesma captura em pasta neutra, só com a definição
  global, 21 regras. A sequência única de 21 regras coincide entre os dois perfis; no perfil
  project-local as 15 triplas do bloco do agente aparecem duas vezes.
- `equiv-permission-vs-tools.sample.json` — probes reais `probe-perm`/`probe-tools` em config
  JSONC sintética carregada com `opencode --standalone debug agents`:
  `permission: { webfetch: deny }` e `tools: { webfetch: false }` resolvem `webfetch * deny`.
  Esses probes não são agentes reviewer-ro válidos.
- `fallback-warning.txt` — linha JSON de erro do stdout de
  `opencode run --agent fixture-agent-missing` na 2.2.5 (timestamp e sessionID sanitizados);
  nessa versão o stderr fica vazio e o exit é 1. O pós-check reconhece esse erro pelo evento
  JSONL `type=error` e pela mensagem `error.message` iniciada por `Agent not found:`. O accessor
  `Get-OpenCodeReviewerRoFallbackWarningPattern` cobre somente o aviso legado
  `agent "..." not found. Falling back to default agent` no stderr; texto comum no stdout que
  cite qualquer formato não conta como fallback.
- `read-outside-cwd-blocked.sample.txt` — recibo sanitizado do caso `outside` da matriz
  comportamental 2.2.5: leitura de arquivo fora do cwd negada por `external_directory`,
  sentinela ausente.
- `content-protection.sample.txt` — resumo dos 34 casos (32 comportamentais + 2 estruturais).
- `content-protection.receipt.json` — recibo máquina-legível com nome, perfil, classe,
  arquivo de evidência, evento, resultado esperado/obtido e veredito de cada caso, além de
  versão e modelo.

## Revalidar uma captura existente

Use `pwsh -NoProfile -File scripts/Test-OpenCodeReviewerRoContentProtection.ps1 -EvidenceDirectory <diretorio-da-captura>`
para revalidar sem executar `opencode run`. Se a captura usar outro modelo além do default, passe
`-Model` com o id registrado no recibo. A captura deve conter `receipt.json` e `evidence/`, com os
34 JSONL dos casos e `debug-agents-local.json`/`debug-agents-global.json`. O script confere a versão
instalada, o modelo, os 34 casos esperados, classes, `exitCode`, aprovação e arquivos não vazios;
divergências bloqueiam antes de qualquer execução de modelo. O `receipt.json` bruto precisa conter
`workspaceRoot` absoluto da captura; recibos sanitizados do repositório não substituem esse arquivo.

O recibo regenerado registra `evidenceSource` na raiz e `toolEventCount` por caso. No início, o
script também verifica que seu parser rejeita uma linha JSONL malformada.
O self-test sintético de caminhos também roda antes da matriz; `-PathValidationSelfTestOnly`
executa só esse self-test, sem chamar o OpenCode.

Nos casos `read-deny`, `read-allow` e `external-deny`, o verificador exige que `input.path` corresponda ao caminho esperado. Aceita a forma relativa pedida ou a forma lexical absoluta baseada no cwd do caso; normaliza apenas `/` e `\` e preserva segmentos `.`/`..`.

Na revalidação, a raiz temporária nova é remapeada para `workspaceRoot` da captura ao comparar cwd e
caminhos absolutos. Isso preserva a prova original sem resolver segmentos `.`/`..`.

## Resolução efetiva medida (2.2.5) — bloco estrutural canônico

A âncora é o último `permission: "*", pattern: "*", action: "deny"`. Depois dela o guard exige a
sequência canônica completa, na ordem, sem regras extras. Regras anteriores à âncora podem
variar; a âncora isola o sufixo efetivo. `debug agents` usa os campos `action`, `resource` e
`effect`; o guard os converte para `permission`, `pattern` e `action`, preservando ordem e
duplicatas.

| permission efetiva | contrato após a âncora |
| --- | --- |
| `*` | `deny` (âncora) |
| `read` | mapa ordenado abaixo |
| `grep` | `deny` |
| `glob` / `list` | `allow` |
| `edit` | `deny` |
| `shell` (normalizado para `bash`) | `deny` |
| `webfetch` / `websearch` | `deny` |
| `subagent` (normalizado para `task`) | `deny` |
| `external_directory` padrão `*` | `deny` |
| `browser` | `deny` |
| `skill` padrão `browser` | `deny` |

Mapa read, em ordem: `* allow`, `*.env deny`, `*.env.* deny`, `.env.example allow`,
`*/.env.example allow`. Disponíveis `{read,glob,list}`; read não é reduzido à ação da última
exceção. A exceção exige nome exato e conteúdo sanitizado pelo operador: `service.env.example` e
`.env.example.local` ficam negados. No Windows o CLI ignora caixa e `*` cruza separadores; regras
contra caminho inteiro podem negar diretório com `.env.` conservadoramente.
`.env~`/`.env-example` não são protegidos.

Na 2.2.5 o sufixo medido **não** contém exceção `allow` de tool-output: `external_directory` é
apenas `* deny`. Qualquer regra adicional depois do bloco (incluindo um `allow` tardio) bloqueia.
`glob` e `read` de diretório podem mostrar nomes; `list` tem permissão, mas a enumeração
observada veio por `read` de diretório, não por uma ferramenta `list` separada.

`subcwd-example-project-local` mede a leitura de `../.env.example` a partir da subpasta no perfil
project-local: é permitida quando o caminho permanece dentro do git worktree do cwd.
`subcwd-example` mede o mesmo caminho no perfil global-only e é **negado por
`external_directory`**. Os dois resultados são medidos separadamente, não presumidos.

Exceções internas de `external_directory` não provam isolamento absoluto; não foram ampliadas.
Links/aliases, outros segredos, prompt/dossiê e carregamento automático de instruções seguem fora
do recorte. Provas comportamentais e estruturais são distintas; fora dos casos medidos,
equivalência é premissa, não garantia de isolamento.

## Prova dos adapters (2.2.5)

Em workspace sintético mínimo (não em `C:\Dev`), com o shim `opencode.cmd` resolvido pela máquina:

- `Invoke-OpenCode.ps1 -Model opencode-go/deepseek-v4.1-flash -Variant low ...` retornou
  resposta; o argv usou `--model opencode-go/deepseek-v4.1-flash#low`, não `--variant`.
- `Start-OpenCodeJob.ps1 -Model opencode-go/deepseek-v4.1-flash -NoWatcher ...` gravou
  `.args.json` com `run --format json --model opencode-go/deepseek-v4.1-flash --agent
  reviewer-ro` (sem variante), `.exitcode.txt` = 0, stream com `text` e `step_finish` e stderr
  vazio; o processo filho encerrou.

Essas provas são de integração do adapter; a matriz de conteúdo tem 32 casos comportamentais e
2 casos estruturais.

## Como re-capturar (refresh após upgrade do opencode)

Numa cwd que descubra o `.opencode/agent/reviewer-ro.md` project-local (a raiz deste repo):

```
opencode --version
opencode debug agents        # perfil project-local (36 regras)
```

Numa pasta neutra, sem `.opencode/agent/reviewer-ro.md` nas pastas acima:

```
opencode debug agents        # perfil global-only (21 regras)
```

Atualizar o set re-medido completo (sanitizando paths/IDs onde couber):

1. `VERSION.txt`
2. `debug-agents-project-local.sample.json`
3. `debug-agents-global-only.sample.json`
4. `equiv-permission-vs-tools.sample.json` — config JSONC sintética com `probe-perm` e
   `probe-tools`, carregada via `opencode --standalone debug agents`
5. `fallback-warning.txt` — stdout verbatim de `run --agent <ausente>`; na 2.2.5 é JSON de erro
   no stdout, com exit 1 e stderr vazio. Sanitizar timestamp/sessionID.
6. `read-outside-cwd-blocked.sample.txt` e `content-protection.sample.txt` — derivados da matriz
   comportamental; tokens reais → `<SENTINELA>`
7. `content-protection.receipt.json` — recibo da matriz

A matriz comportamental é executada pelo script existente, sem criar scripts novos:

```
pwsh -NoProfile -File scripts/Test-OpenCodeReviewerRoContentProtection.ps1 `
  -OutputDirectory <pasta-nova> -Model opencode-go/deepseek-v4.1-flash
```

Ela monta workspace sintético mínimo e descartável, roda 32 casos com `opencode run --format json`
(exigindo evento `tool_use` em cada um) e confirma os 2 casos `grep` por `grep * deny` em
`opencode debug agents`. Ausência de evento comportamental é inconclusiva e bloqueia a promoção;
não contar `toolNotObserved` como aprovação. `names-glob` exige evento `glob` e `names-read`
exige `read` de diretório, ambos com nomes visíveis. `names-list` aceita evento `read`, `glob`
ou `list` com nomes visíveis; a captura atual usou `read`. A CLI 2.2.5 não oferece mais
`opencode debug agent --tool`; não usar essa interface antiga.

Re-rodar `scripts/Test-OpenCodeReviewerRoSelfTest.ps1` e os demais self-tests até verde antes de
reativar o default `-Agent reviewer-ro`. O diagnóstico estrutural
`scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` confirma o estado instalado, mas
não substitui a recaptura acima quando a versão do opencode muda.

Nota operacional: free-tier Zen (`opencode/big-pickle` etc.) pode responder no app gráfico e
falhar no CLI com `FreeTierError`. Para a matriz comportamental use modelo CLI-capable explícito
(assinatura ChatGPT OAuth, OpenCode Go com cota, ou provider com saldo).
