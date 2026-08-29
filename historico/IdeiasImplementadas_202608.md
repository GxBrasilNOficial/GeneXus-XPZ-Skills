# Ideias Implementadas — 2026-08

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Matriz git-capable vs semantic-only vs argv-limited no `14` (operador da pré-push reforçada)

Implementado em 2026-08-28 a partir do manuscrito v4 (`matriz-14-plan-v4`).

Documentação operacional no `14-revisao-pre-push-reforcada.md`: tabela única backend/rota × papel no painel × fora do painel (adapter XPZ) × transporte do dossiê, com remissões ao invariante git-capable, ao `15` e ao parágrafo de Omissão. Ponteiro ampliado no `13` sem nomear backends. Manutenção explícita (uma rota por linha; o gate de paridade não detecta ausência de linha nova). Ordem ao validar composição do painel: (1) ≥1 git-capable → (2) piso de famílias no `15` → (3) transporte/omissão. Sem alteração de motor.

Resíduos do painel v3 incorporados no v4: whitespace do `<!-- backend-parity: ignore -->` na Omissão; glosa Posição B; sandbox «no painel»; ponteiro ancorado no `13`; redação «não detecta a ausência de uma linha nova».

Limitações fora desta frente permanecem no `999`: perfil git-capable in-panel; modo dossiê compacto; compatibilidade `-MechanicalScriptPath`.

### Rastreabilidade

- Arquivos materiais: `14-revisao-pre-push-reforcada.md`, `13-revisao-pre-push.md`, `CHANGELOG.md` (pt/es/en).
- Commit material: `8260e59` (`Documenta matriz operacional capacidade × transporte no 14.`).
- Commit material: `8337d8c` (`Explicitar ordem de validacao do painel reforcado no 14.`).

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
- Commit material (closeout path): `a4de10e` (`Faz prompt e recibo do closeout ecoarem o path resolvido da oferta.`).
