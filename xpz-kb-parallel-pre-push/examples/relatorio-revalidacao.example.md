# Relatório de pré-push de pasta paralela — RE-VALIDAÇÃO (molde)

> Molde de relatório de **re-validação** (segunda passada após o usuário aplicar correções de uma primeira passada — estilo do experimento-002). O foco é o **delta**: o que mudou de status desde a passada anterior. Apresentar ao usuário e **parar**.

## Identificação da rodada

- **Pasta paralela (KB):** `<caminho>`
- **Range:** `<BaseRef..HEAD>`  ·  **fetch:** `<ok|skipped|failed>`
- **Passada anterior:** `<referência/horário do relatório de primeira passada>`
- **Correções aplicadas pelo usuário desde então:** `<resumo>`

## Delta de gates (Fase 1)

**pushReadiness:** `<antes>` → `<agora>`

| Gate | Antes | Agora | Mudou? |
|---|---|---|---|
| G1 commitsBehind | `<...>` | `<...>` | `<sim/não>` |
| G3 working tree | `<...>` | `<...>` | `<sim/não>` |
| G4 diff --check | `<...>` | `<...>` | `<sim/não>` |
| G5 parse PS local | `<...>` | `<...>` | `<sim/não>` |
| K8 setup | `<...>` | `<...>` | `<sim/não>` |
| K9 índice | `<...>` | `<...>` | `<sim/não>` |
| K11 not-not | `<...>` | `<...>` | `<sim/não>` |

> Listar apenas os gates que mudaram de status ou cuja causa foi endereçada; manter os demais como "estável".

## Itens reabertos ou ainda pendentes

- bloqueios que **persistem**: `<lista>`
- novos `unknown` (ex.: fetch falho nesta passada): `<lista>`  → lembrar que `unknown` mantém `pushReadiness=blocked`
- itens de Fase 2a/2b/2c reclassificados: `<lista>`

## Delta Fase 2c

- suspeitas **novas** / **resolvidas** / **persistentes**: `<listas>`
- mudança de cobertura parcial (se houver): `<resumo; listar nominalmente o que ficou de fora>`
- **triagem atual:** `<nada óbvio | suspeitas | precisa teste manual/caso real | N/A>`

> Triagem, não prova. "Nada óbvio" NÃO é ausência de regressão e NÃO altera `pushReadiness`.

## Veredito da re-validação (sem ação automática)

- **Convergiu para `ready`?** `<sim/não>` — se não, o que falta.
- **Push:** `<proibido | permitido sob decisão do usuário | pendente>` — só a partir de `pushReadiness` (Fase 1) + decisão do usuário; a Fase 2c não libera push.

> Este relatório é diagnóstico. Nenhuma correção, commit ou push foi feito.
