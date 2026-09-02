# Ideias Implementadas — 2026-09

Registro de ideias que sairam de 999-ideias-pendentes.md por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Preservar mais evidencia quando o `claude` sai `1` sem saida classificavel

Implementado em 2026-09-01 a partir do manuscrito `Temp/manuscript-claude-evidence-preservation-v3.md`.

Quatro falhas de diagnostico e runtime foram corrigidas nos adapters do Claude Code (`Invoke-ClaudeCode.ps1`, `Invoke-ClaudeCodeAsync.ps1`) e na biblioteca de suporte (`ClaudeCodeCliSupport.ps1`):

1. **Filtro de ruido de ambiente ampliado para `deny`:** `Test-ClaudeCodeEnvironmentNoiseLine` e `Remove-ClaudeCodeEnvironmentNoise` passaram a filtrar avisos `Permission deny rule (...)` e `Ignoring N permissions.deny entries...` alem dos `allow` ja cobertos. Corrige o incidente de 2026-08-31 onde avisos `Write vs Edit` no stderr dominaram o diagnostico erroneamente.

2. **Sentinelas de spend-limit/session-limit/cota adicionadas:** `Get-ClaudeCodeErrorMessage` agora busca `spend limit`, `monthly limit`, `session limit`, `rate limit`, `usage limit`, `quota` e a URL `claude.ai/settings/usage` no texto combinado de stdout+stderr limpo. A rota sincrona preserva a evidencia textual no BLOCK sem criar o estado estruturado `quota` reservado ao sidecar assincrono.

3. **Ramo de erro reestruturado em `Invoke-ClaudeCode.ps1`:** Em `exit != 0` sem erro reconhecido, o adapter agora preserva evidencia de ambos os canais (stdout + stderr limpo de ruido, ate 8 linhas cada) em vez de despejar stderr bruto. O caso `exit 0 + stdout vazio` mantem o comportamento anterior. A mensagem nao afirma mais "sem resposta" quando ha texto presente em algum canal.

4. **Correcao de overflow em `durationMs`:** `Invoke-ClaudeCodeAsync.ps1` e `Invoke-LlmDelegatePanelDispatch.ps1` migraram o casting de `durationMs` para `[long]`, eliminando estouro de `Int32` ao calcular milissegundos em intervalos de calendario e desbloqueando a suite `Test-ClaudeCodeAsyncSelfTest.ps1`.

Testes adicionados em `Test-ClaudeCodeCliSupportSelfTest.ps1`: filtragem de deny (unitario), extracao simetrica de spend-limit (stdout e stderr), session limit medido em producao, stderr misto (ruido + erro real), ruido puro, exit 0 com ruido + resposta valida, e 3 cenarios E2E com `New-FakeClaudeCodeExe` refatorado para goto/labels (SPEND_LIMIT, NOISE_ONLY, UNCLASSIFIED). Total: 97 testes passando no suporte síncrono e suite assíncrona verde.

Documentacao atualizada: `xpz-llm-delegate/SKILL.md` (deny + spend-limit/session-limit sync), `09-inventario-e-rastreabilidade-publica.md` (ponteiros dos scripts), `CHANGELOG.md` (3 idiomas).

Entrada residual preservada em `999-ideias-pendentes.md`: item 5 (avaliar paridade minima de evidencia de cota na rota sync sem misturar o circuito do painel — frente dedicada futura).

### Rastreabilidade

- Commit material: `0e61cc8` (`feat(claude-code): preservar evidencia textual em exit 1 e ampliar filtro de ruido`)
- Commit material (refinamento em producao): `94ffe02` (`feat(claude-code): adicionar sentinela de session limit ao extrator de erro`)
- Commit material (alinhamento documental): `2919d39` (`docs(claude-code): alinhar session limit na documentacao, changelog e rastreabilidade historica`)
- Commit material (fix factual e durationMs): `1ef6ca8` (`fix(claude-code): corrigir contagem de testes, paridade deny no SKILL e overflow de durationMs no async`)
- Commit material (documentacao durationMs): `8a4e64b` (`docs(claude-code): documentar correcao durationMs no changelog e atualizar historico`)
- Arquivos materiais: `scripts/ClaudeCodeCliSupport.ps1`, `scripts/Invoke-ClaudeCode.ps1`, `scripts/Invoke-ClaudeCodeAsync.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, `scripts/Test-ClaudeCodeCliSupportSelfTest.ps1`, `scripts/Test-ClaudeCodeAsyncSelfTest.ps1`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`, `999-ideias-pendentes.md`.
