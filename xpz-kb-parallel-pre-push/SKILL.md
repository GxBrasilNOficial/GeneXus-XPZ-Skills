---
name: xpz-kb-parallel-pre-push
description: Valida o estado de uma pasta paralela de KB GeneXus antes do push (rotina pré-push de pasta paralela), rodando o orquestrador de gates mecânicos local do repositório ativo; não é a rotina pré-push do repositório de skills (documento 13)
---

# xpz-kb-parallel-pre-push

Roda a rotina pré-push de uma **pasta paralela de KB GeneXus**: invoca o orquestrador compartilhado `scripts\Invoke-XpzKbParallelPrePushPhase1.ps1` para consolidar gates mecânicos (G0–G5 + K1–K4/K8/K9/K11) sobre o estado dessa pasta antes de um push, e classifica o resultado em `pushReadiness` (`ready`/`warn`/`blocked`). Reporta ao usuário e não publica nada por conta própria.

**Esta skill NÃO é a rotina pré-push do repositório de skills `GeneXus-XPZ-Skills`** — essa é o documento [`13-revisao-pre-push.md`](../13-revisao-pre-push.md) (e o tier reforçado [`14-revisao-pre-push-reforcada.md`](../14-revisao-pre-push-reforcada.md)). Aquela rotina valida o **repositório de skills** antes de publicar; esta valida o estado de uma **pasta paralela de KB** (com `ObjetosDaKbEmXml/`, `KbIntelligence/` etc.) antes de o usuário fazer push dessa KB. São coisas diferentes, com autoridade documental diferente.

---

## GUIDELINE

- Identificar a raiz da **pasta paralela da KB** pelo contexto e rodar o orquestrador compartilhado contra ela; não reimplementar gates à mão.
- A saída do orquestrador é **JSON de máquina por padrão**; `pushReadiness` é a leitura principal. `unknown` em qualquer gate **bloqueia** (fail-closed) — nunca tratar `unknown` como "ok".
- A rotina é de **análise e relatório**. Apresentar o diagnóstico ao usuário; não aplicar correções nem fazer push sem autorização explícita depois do relatório.
- Não delegar o veredito de gate a subagente/LLM secundário; o juízo fica com o agente principal.
- Se a pasta paralela ainda não estiver montada, validada ou mapeada, parar e usar `xpz-kb-parallel-setup` antes desta rotina.
- Os gates **K8** (auditoria de setup) e **K9** (gate de índice) consomem **wrappers locais** da pasta paralela por **contrato estruturado** (`-AsJson`). Se K8/K9 bloquearem por wrapper local ausente, ambíguo ou defasado (sem repasse de `-AsJson`), a correção é via `xpz-kb-parallel-setup` (`atualizar_bootstrap_local` / `corrigir_wrapper_local`) — não editar o wrapper por conta própria nesta skill.
- Os estados-string consumidos de K8 (`estado_operacional_sugerido`) e K9 (`status`/`reason`) são **contrato compartilhado** com `xpz-kb-parallel-setup`; renomeá-los lá quebra esta rotina (ver `fase1-mecanica.md`).

## PATH RESOLUTION

- Este `SKILL.md` fica numa subpasta de skill sob a raiz do repositório de skills; os motores compartilhados ficam em `..\scripts\` relativos a esta pasta.
- Toda referência `../arquivo.md` resolve a partir da pasta deste `SKILL.md`, não do diretório de trabalho corrente.
- O `-RepoRoot` do orquestrador é a raiz da **pasta paralela da KB** (alvo da validação), que normalmente **não** é o repositório de skills onde o motor mora.
- Quando a sessão publicar um caminho desta skill, usar o caminho publicado como autoritativo; não inferir caminho alternativo por heurística.

---

## TRIGGERS

Use esta skill para:
- Validar o estado de uma pasta paralela de KB GeneXus antes de o usuário fazer push dessa KB
- Rodar a Fase 1 mecânica (orquestrador de gates) sobre uma pasta paralela
- Fazer a triagem estrutural (Fase 2a) e a classificação de regime (Fase 2b) de um conjunto de mudanças da pasta paralela antes do push
- Interpretar o `pushReadiness` e os gates de uma rodada já executada

Do NOT use esta skill para:
- A rotina pré-push do **repositório de skills** `GeneXus-XPZ-Skills` (use o documento [`13-revisao-pre-push.md`](../13-revisao-pre-push.md) e, opcionalmente, o tier reforçado [`14`](../14-revisao-pre-push-reforcada.md))
- Preparar, validar ou auditar a **estrutura** da pasta paralela e seus wrappers locais (use `xpz-kb-parallel-setup`)
- Sincronizar/conferir XPZ no acervo (use `xpz-sync`)
- Gerar ou empacotar objetos XML (use `xpz-builder`)
- Registrar esta skill nas ferramentas de agente (use `xpz-skills-setup`)

---

## RESPONSABILIDADES

- Distinguir explicitamente **pré-push de pasta paralela de KB** (esta skill) de **pré-push do repositório de skills** (documento 13) — não confundir os dois contextos no relatório.
- Tratar o orquestrador `scripts\Invoke-XpzKbParallelPrePushPhase1.ps1` como motor compartilhado e agnóstico de KB; parametrizar caminhos não-padrão pela config local `kb-parallel-pre-push.config.json` (campos `setupAuditWrapper`/`indexGateWrapper` + bloco `layerTokens`), nunca por edição do motor.
- Ler `pushReadiness` como leitura principal; **`exit 0` ready, `2` warn, `1` blocked**; `unknown` consolida em `blocked`.
- Para os gates **K8/K9**, reconhecer que a resolução do wrapper local tem 4 desfechos (`config` / `config` apontando arquivo inexistente=block / `convention` com exatamente 1 candidato=ok / `none` ou `ambiguous`=block) e encaminhar correção de wrapper à `xpz-kb-parallel-setup`.
- Não declarar push liberado quando `pushReadiness` ≠ `ready`; `warn` exige decisão consciente do usuário, `blocked` proíbe push até saneamento.
- Apresentar relatório por rodada (ver moldes em `examples/`) e parar; correções e push só após autorização explícita.

---

## WORKFLOW (uma rodada de pré-push de pasta paralela)

1. Confirmar que o alvo é uma **pasta paralela de KB** (não o repositório de skills → nesse caso, usar o documento 13). Se a pasta ainda não estiver montada/validada, parar e usar `xpz-kb-parallel-setup`.
2. Garantir referência remota fresca: `git -C <pasta-paralela> fetch origin` antes de rodar (ou usar `-SkipFetch` conscientemente, assumindo a `BaseRef` local).
3. Rodar o orquestrador: `pwsh -File <repo-skills>\scripts\Invoke-XpzKbParallelPrePushPhase1.ps1 -RepoRoot <pasta-paralela>` (JSON de máquina por padrão; `-AsText` para leitura humana).
4. Ler `pushReadiness`:
   - `ready` (exit 0) → Fase 1 mecânica sem bloqueio; seguir para a triagem 2a/2b.
   - `warn` (exit 2) → há gate warn (ex.: branch≠main, working tree sujo, whitespace só no acervo ou em XML novo/adicionado da frente); reportar e pedir decisão do usuário. Em G4, `warn` não autoriza limpeza global: corrigir só linhas novas/editadas; o 9-FD decide trim forte quando houver baseline por GUID único.
   - `blocked` (exit 1) → há gate `block` **ou** `unknown`; push proibido até saneamento. Diagnosticar cada gate por `fase1-mecanica.md`.
5. Para gates **K8/K9** em `block`: se a causa for wrapper local ausente/ambíguo/defasado (`resolvedBy` = `none`/`ambiguous`, ou `resolvedBy='config'` apontando arquivo inexistente, ou contrato `-AsJson` não emitido), encaminhar à `xpz-kb-parallel-setup` (`atualizar_bootstrap_local`/`corrigir_wrapper_local`). Não editar o wrapper aqui.
   - Se **K9** bloquear por falha de rebuild/índice e o acervo tiver `Menubar/` com `type="gxlegacy/Menubar"` residual, tratar como migração pós-reclassificação (`01k` / `xpz-sync` / passo 8.g de `xpz-kb-parallel-setup`): re-sync ou limpeza **antes** de insistir no gate. Não é bug do orquestrador.
6. Fase 2a estrutural: rodar `Test-XpzKbFrenteHygiene.ps1` (higiene de frente/pacote) — ver `fase2a-estrutural.md`. A correção dos `warn` (remover frentes não-conformes / pacotes órfãos) é a **forma canônica** via `Remove-XpzKbFrenteHygieneFindings.ps1` (fail-safe: dry-run por padrão, `-Apply` sob decisão humana, consome o JSON do motor como fonte de verdade) — **NUNCA** um passo automático desta rotina nem deleção ad-hoc.
7. Fase 2b: classificar o regime das mudanças (`Compare-XpzChecksums` descarta SAME; roteamento por regime, build como autoridade) — ver `fase2b-classificador-de-regime.md`. É **classificador**, não selo determinístico.
8. Montar o relatório da rodada (molde em `examples/`) e **parar**. Correções e push só após autorização explícita do usuário.

---

## SATÉLITES

- [`fase1-mecanica.md`](fase1-mecanica.md) — contrato dos gates G0–G5 + K1–K4/K8/K9/K11 do orquestrador (severidade consolidada, `unknown`⇒`blocked`, exit codes, descoberta de wrapper, parâmetros e tokens de camada).
- [`fase2a-estrutural.md`](fase2a-estrutural.md) — `Test-XpzKbFrenteHygiene` (diagnóstico) + executor de faxina `Remove-XpzKbFrenteHygieneFindings` (correção fail-safe, fora da pré-push) + checklist de agente; nuance cabeça-detalhe do F1.
- [`fase2b-classificador-de-regime.md`](fase2b-classificador-de-regime.md) — classificador de regime (F1 → roteamento → build como autoridade), catálogo de padrões aceitos por-KB.

---

## CONSTRAINTS

- NUNCA tratar esta rotina como a pré-push do repositório de skills; a autoridade daquela é o documento [`13`](../13-revisao-pre-push.md).
- NUNCA tratar `unknown` como aprovação; `unknown` consolida em `pushReadiness=blocked` (fail-closed).
- NUNCA declarar push liberado com `pushReadiness` ≠ `ready` sem decisão explícita do usuário; `blocked` proíbe push.
- NUNCA editar o orquestrador ou os motores compartilhados para "ajustar" um caso de uma KB; parametrizar pela config local `kb-parallel-pre-push.config.json`.
- NUNCA corrigir wrapper local de K8/K9 a partir desta skill; encaminhar à `xpz-kb-parallel-setup`.
- NUNCA renomear os estados-string consumidos de K8/K9 sem alinhar os dois lados (esta skill e `xpz-kb-parallel-setup`); são contrato compartilhado.
- NUNCA aplicar correções nem fazer push entre o relatório e a autorização explícita do usuário, independentemente do tamanho ou obviedade do gap.
- NUNCA rodar esta rotina numa pasta paralela ainda não montada/validada; usar `xpz-kb-parallel-setup` antes.
- NUNCA delegar o veredito de gate a subagente/LLM secundário.
