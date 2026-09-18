# Relatório de pré-push de pasta paralela — PRIMEIRA PASSADA (molde)

> Molde de relatório da **primeira passada** de uma rodada de pré-push de pasta paralela de KB (estilo do experimento-001). Preencher com a saída real do orquestrador e dos motores; **não** inventar números. Apresentar ao usuário e **parar** — correções/push só após autorização explícita.

## Identificação da rodada

- **Pasta paralela (KB):** `<caminho>`
- **Repositório de skills (motor):** `<caminho>\GeneXus-XPZ-Skills`
- **BaseRef:** `origin/main`  ·  **Range:** `<BaseRef..HEAD>`
- **fetch:** `<ok|skipped|failed>`  ·  **config encontrado:** `<true|false>`
- **commitsAhead:** `<n>`  ·  **commitsBehind:** `<n>`

## Fase 1 — mecânica (`Invoke-XpzKbParallelPrePushPhase1.ps1`)

**pushReadiness:** `<ready|warn|blocked>` (exit `<0|2|1>`)

| Gate | Status | Mensagem |
|---|---|---|
| G0 fetch | `<...>` | `<...>` |
| G1 commitsBehind | `<...>` | `<...>` |
| G2 branch | `<...>` | `<...>` |
| G3 working tree | `<...>` | `<...>` |
| G4 diff --check | `<...>` | `<...>` |
| G5 parse PS local | `<...>` | `<...>` |
| K1/K2 paths | `<...>` | `<...>` |
| K3/K4 camadas | `<...>` | `<...>` |
| K8 setup | `<...>` | `<estado_operacional_sugerido=...; resolvedBy=...>` |
| K9 índice | `<...>` | `<status/reason; resolvedBy=...>` |
| K11 not-not | `<...>` | `<...>` |

> Se K8/K9 = `block` por wrapper local ausente/ambíguo/defasado → encaminhar à `xpz-kb-parallel-setup` (`atualizar_bootstrap_local`/`corrigir_wrapper_local`).

## Fase 2a — estrutural (`Test-XpzKbFrenteHygiene.ps1`)

- **status:** `<ok|warn>`
- frentes não-conformes: `<lista ou nenhuma>`
- pacotes órfãos: `<lista ou nenhum>`  ·  pacotes não padronizados: `<lista ou nenhum>`
- checklist de agente: `<itens pendentes ou OK>`
- remediação (ação separada, sob decisão humana — **não** é passo da pré-push): via `Remove-XpzKbFrenteHygieneFindings.ps1` (fail-safe — dry-run por padrão, `-Apply`); ver `fase2a-estrutural.md`

## Fase 2b — classificação de regime (`Compare-XpzChecksums.ps1` + roteamento)

- F1: SAME `<n>` · DIFF `<n>` · NEW `<n>` · DELETED `<n>`
- regimes encontrados (não-SAME): `<aditivo data-bearing / aditivo computado / delete / rename / troca de tipo-chave / alto volume / lógica de negócio>`
- itens `suspeito-por-omissão` (triagem, não veredito): `<lista>`
- itens roteados ao build (`xpz-msbuild-build` / `FailIfReorg`): `<lista>`

## Fase 2c — caça a regressão óbvia (triagem de agente, não prova)

- objetos elegíveis (não-SAME com Source relevante): `<n>`  ·  lidos: `<n>`  ·  cobertura: `<total | parcial | N/A | indisponível — F1 unknown>`
- não lidos (cobertura parcial — listar nominalmente): `<lista ou n/a>`
- classificação por objeto: `<aditivo | reescreveu ramo | ruído/lastUpdate | NEW-contrato | DELETED-N/A | regime-2b-N/A | estrutural-visual (GxMultiForm/layout)>`
- suspeitas: `<lista ou nenhuma>`  ·  padrões suprimidos pelo catálogo da KB: `<lista>`
- **triagem:** `<nada óbvio | suspeitas | precisa teste manual/caso real | N/A>`

> Triagem, não prova. "Nada óbvio" NÃO é ausência de regressão e NÃO altera `pushReadiness`.
> No regime "lógica de negócio", a autoridade continua sendo o teste funcional (`fase2b`).
> Layout WebPanel (`GxMultiForm`): estrutural-visual; checklist de código via eventos — preferir `Search-GeneXusXmlSourceBlock.ps1 -Block events`.

## Veredito e próximos passos (sem ação automática)

- **Leitura:** `<resumo do que a Fase 1 bloqueou/avisou e o que a 2a/2b/2c classificou/triou>`
- **Push:** `<proibido | permitido sob decisão do usuário | pendente de saneamento>` — derivado **somente** de `pushReadiness` (Fase 1) e decisão do usuário; a Fase 2c **não** libera push.
- **Pendências sugeridas (aguardando autorização):** `<lista>`

> Este relatório é diagnóstico. Nenhuma correção, commit ou push foi feito.
