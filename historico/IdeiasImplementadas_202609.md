# Ideias Implementadas — 2026-09

Registro de ideias que sairam de 999-ideias-pendentes.md por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Preservar mais evidencia quando o `claude` sai `1` sem saida classificavel

Implementado em 2026-09-01 a partir do manuscrito `Temp/manuscript-claude-evidence-preservation-v3.md`.

Tres falhas de diagnostico foram corrigidas no adapter sincrono do Claude Code (`Invoke-ClaudeCode.ps1`) e na biblioteca de suporte (`ClaudeCodeCliSupport.ps1`):

1. **Filtro de ruido de ambiente ampliado para `deny`:** `Test-ClaudeCodeEnvironmentNoiseLine` e `Remove-ClaudeCodeEnvironmentNoise` passaram a filtrar avisos `Permission deny rule (...)` e `Ignoring N permissions.deny entries...` alem dos `allow` ja cobertos. Corrige o incidente de 2026-08-31 onde avisos `Write vs Edit` no stderr dominaram o diagnostico erroneamente.

2. **Sentinelas de spend-limit/cota adicionadas:** `Get-ClaudeCodeErrorMessage` agora busca `spend limit`, `monthly limit`, `rate limit`, `usage limit`, `quota` e a URL `claude.ai/settings/usage` no texto combinado de stdout+stderr limpo. A rota sincrona preserva a evidencia textual no BLOCK sem criar o estado estruturado `quota` reservado ao sidecar assincrono.

3. **Ramo de erro reestruturado em `Invoke-ClaudeCode.ps1`:** Em `exit != 0` sem erro reconhecido, o adapter agora preserva evidencia de ambos os canais (stdout + stderr limpo de ruido, ate 8 linhas cada) em vez de despejar stderr bruto. O caso `exit 0 + stdout vazio` mantem o comportamento anterior. A mensagem nao afirma mais "sem resposta" quando ha texto presente em algum canal.

Testes adicionados em `Test-ClaudeCodeCliSupportSelfTest.ps1`: filtragem de deny (unitario), extracao simetrica de spend-limit (stdout e stderr), stderr misto (ruido + erro real), ruido puro, exit 0 com ruido + resposta valida, e 3 cenarios E2E com `New-FakeClaudeCodeExe` refatorado para goto/labels (SPEND_LIMIT, NOISE_ONLY, UNCLASSIFIED). Total: 93 testes passando.

Documentacao atualizada: `xpz-llm-delegate/SKILL.md` (deny + spend-limit sync), `09-inventario-e-rastreabilidade-publica.md` (ponteiros dos 2 scripts), `CHANGELOG.md` (3 idiomas).

Entrada residual preservada em `999-ideias-pendentes.md`: item 5 (avaliar paridade minima de evidencia de cota na rota sync sem misturar o circuito do painel — frente dedicada futura).

### Rastreabilidade

- Commit material: `71480d5` (`feat(claude-code): preservar evidencia textual em exit 1 e ampliar filtro de ruido`)
- Arquivos materiais: `scripts/ClaudeCodeCliSupport.ps1`, `scripts/Invoke-ClaudeCode.ps1`, `scripts/Test-ClaudeCodeCliSupportSelfTest.ps1`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`, `999-ideias-pendentes.md`.
