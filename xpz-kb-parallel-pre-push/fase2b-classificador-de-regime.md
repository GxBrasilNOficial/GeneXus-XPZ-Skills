# Fase 2b — classificador de regime

Satélite de [`SKILL.md`](SKILL.md). A Fase 2b **não** é um runbook determinístico que dá selo de aprovação. É um **classificador de regime**: a triagem estática barata roteia cada mudança para quem realmente tem autoridade sobre ela — em vários regimes, esse é o **build** (`xpz-msbuild-build` com `FailIfReorg`), não a análise estática de XML.

> Decisão de design fechada (`999-ideias-pendentes.md`): **não cristalizar runbook 2b determinístico** — é classificador, com o build como autoridade. As 4 probes empíricas mostraram que o peso de regressão está na IDE e no build, não na enumeração estática.

## Passo 1 — F1: descartar `SAME` (`Compare-XpzChecksums.ps1`)

O filtro F1 compara o atributo `checksum` no `<Object>` raiz dos XMLs do acervo entre `BaseRef` e `HEAD`, classificando cada arquivo alterado como **SAME** (checksum idêntico — mudou só por re-export, tipicamente `lastUpdate`), **DIFF**, **NEW** ou **DELETED**. É classificador puro: não bloqueia, só rotula.

```text
pwsh -File <repo-skills>\scripts\Compare-XpzChecksums.ps1 -RepoRoot <pasta-paralela-da-KB>
```

Saída JSON por padrão (`status` `ok`|`unknown`, `baseRef`, `repoRoot`, `range`, `results[]`); **exit 0 ok, 3 unknown (falha de git)**. F1 nunca bloqueia.

> **Cabeça-detalhe:** descartar `SAME` é correto para o **arquivo**, mas não prova que a cabeça associada está fora do raio de impacto (o detalhe pode ter mudado). Ver [`fase2a-estrutural.md`](fase2a-estrutural.md).

## Passo 2 — roteamento por regime

Sobre o que **não** for `SAME`, classificar o regime e rotear:

| Regime | Tratamento | Autoridade |
|---|---|---|
| **Aditivo data-bearing** (atributo novo com FK/stored, nenhum removido) | **único lugar onde a estática agrega**: `who-uses(Table)` ∪ `who-uses(Transaction)`; shortlist de omissão = navegadores intocados ranqueados por afinidade. Status `suspeito-por-omissão` = **triagem, não veredito** | estática (triagem) + análise do agente |
| **Aditivo computado** (atributo novo com `<Formula>`) | **pular** — não há risco de omissão | — |
| **delete** (atributo/objeto removido) | desenvolvimento normal mediado pela IDE: a referência estrutural costuma ser barrada na própria IDE antes de chegar ao acervo referenciado. **Não tratar como garantia universal** — referência só-em-código permanece ponta aberta; o **build permanece backstop** | IDE (mediação) + build (backstop) |
| **rename** | propagado pela IDE — não-evento | IDE |
| **troca de tipo/domínio/chave** | reorg não-backward-compatible. **A autoridade é o build com `FailIfReorg`**, não a enumeração estática | build (`xpz-msbuild-build`) |
| **alto volume** (>~20 dependentes) | rotear ao build em vez de enumerar | build |
| **lógica de negócio** (cálculo que compila e roda errado) | fora do alcance da estática e do build estrutural | só teste funcional |

`suspeito-por-omissão` é um rótulo de **triagem** que pede atenção do analista — nunca um veredito de regressão por si só.

## Catálogo de padrões aceitos (arquivo por-KB)

Certos padrões de código são intencionais e não devem disparar triagem repetidamente (ex.: `procVoltaDo*QueFoi`, `SelectTab(2);SelectTab(1)`, blocos `csharp` conhecidos). Esse catálogo é **por-KB**: cada pasta paralela mantém o seu, porque os padrões dependem das convenções daquela KB.

- Molde: `examples/kb-parallel-pre-push-accepted-patterns.example.json`.
- A pasta paralela materializa o seu próprio arquivo (a `xpz-kb-parallel-setup` pode ofertar a cópia no bootstrap); esta skill apenas **consulta** o catálogo para suprimir ruído conhecido na triagem.
- Padrão não catalogado não é erro — é candidato a inspeção; se for legítimo e recorrente, o usuário decide adicioná-lo ao catálogo da KB.

## O que a Fase 2b entrega

Uma **classificação** por mudança (regime + roteamento + rótulos de triagem), não um carimbo de "sem regressão". O relatório da rodada (molde em `examples/`) registra os regimes encontrados, os itens `suspeito-por-omissão` e os que foram roteados ao build — para o usuário decidir o push com consciência do que a estática cobre e do que só o build/teste funcional cobre.

Após classificar, se houver `DIFF`/`NEW` com Source relevante (tipicamente regime **lógica de negócio** / Procedure / WebPanel), o agente executa a **Fase 2c** — caça a regressão óbvia como **apresentação estruturada** no relatório ([`fase2c-caca-regressao-agente.md`](fase2c-caca-regressao-agente.md)). A 2c **não** amplia esta 2b a runbook determinístico nem prova ausência de regressão.
