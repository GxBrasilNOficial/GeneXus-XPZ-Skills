# Ideias Implementadas — 2026-08

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Preferidos por orquestrador (schema 3, cascata, nativo rota A)

Implementado em 2026-08-27 a partir do manuscrito v20 (`pref-orch-plan-v20-20260826`).

Breaking público da lista de revisores preferidos da `xpz-llm-delegate`:

- Cascata `preferred-reviewers.<orchestrator>.json` → `preferred-reviewers.json` (machine); `-Orchestrator`/`-Scope` obrigatórios no corpo; fail-closed se o ficheiro efetivo for ilegível ou `schemaVersion` ≠ 3 (sem migração automática de schema 1/2).
- Titulares `delegation-cli` (6 backends CLI) e `orchestrator-native-subagent` (rota A); `reasoningEffort` top-level; `invokeArgs` obrigatório; skip silencioso → throw tipado (`reason` nu).
- Diversidade: allowlist `Test-LlmDelegateFamilyKnown` + `droppedUnknownFamilies`; piso = Criador de `targetModelKey` (tese B — nativo não herda a ferramenta).
- Gate: `Resolve-OrchestratorNativeModelLocality.ps1` (nunca `local`); dispatcher com defesa de leak, índices de ledger e `panel-summary` SchemaVersion 3.
- Closeout: `-PreferredReviewersSnapshotJson` + proveniência + eco `effortApplied` (`unset` / `unsupported` nesta frente).
- Seed Cursor schema 3 gravado na máquina (`preferred-reviewers.cursor.json`).

Entradas do `999` atualizadas (não removidas por completo): esforço de raciocínio (parcial — persistência + eco; knobs nos adapters pendentes) e premissa do fallback 529 alinhada à tese B.

### Rastreabilidade

- Arquivos materiais: `scripts/Set-LlmDelegatePreferredReviewers.ps1`, `scripts/Resolve-LlmDelegatePreferredReviewers.ps1`, `scripts/Resolve-OrchestratorNativeModelLocality.ps1`, `scripts/Resolve-LlmDelegateAuthorization.ps1`, `scripts/Resolve-LlmDelegatePanelDiversity.ps1`, `scripts/LlmDelegateTargetFamilySupport.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`, self-tests associados, `xpz-llm-delegate/SKILL.md`, `xpz-skills-setup/SKILL.md`, `15`/`14`/`08`/`09`/`AGENTS.md`/`999`/`CHANGELOG.md`.
- Commit material: `18c3ebe` (`Implementa preferidos por orquestrador (schema 3, cascata, nativo).`).
- Commit material (closeout): `15455ae` (`Neutraliza motivo de curadoria no recibo do closeout.`).
- Commit material (pós-v20): `758a901` (`Fecha gaps pós-v20: teste de leak nativo, README e recibo.`).
