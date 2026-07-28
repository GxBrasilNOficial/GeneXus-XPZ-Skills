# AGENTS.md

## Leitura obrigatória

- Ler primeiro o `README.md` local antes de agir.
- Reler a documentação local quando o contexto da conversa ficar longo, ambíguo ou perder aderência às convenções da raiz.

## Edição local pelo Codex

- Nesta raiz, para uma alteração textual já aprovada, usar normalmente a ferramenta Codex `apply_patch` quando a rota nativa estiver disponível e nenhuma instrução de maior precedência a proibir.
- Manter `xpz-codex-apply-patch-alternative/SKILL.md` e `scripts/Apply-ApprovedPatch.ps1` como backup auditável quando a ferramenta nativa estiver indisponível, falhar antes de qualquer escrita local e a árvore/índice permanecerem sem modificação, ou quando houver instrução humana expressa.
- Na rota de backup, `pwsh -File` recebe argv literal, inclusive via `ProcessStartInfo.ArgumentList`; por isso, transmita o patch unificado textual como Base64 contíguo por stdin para `-DryRun`, com `-RepositoryRoot` e um único `-AllowedPath` por ciclo. Para vários arquivos, repetir ciclos independentes de stage -> apply, sem atomicidade entre ciclos já aplicados. Se `-AllowedPath` for repetido, o binder falha antes do motor: stdout fica sem JSON e o diagnóstico deve ser lido no stderr. Só então chamar `-StagedPatchId` + `-ExpectedPatchSha256` para aplicar.
- Após qualquer aplicação, reler o trecho alterado, conferir encoding/EOL e executar o parse ou teste pertinente. Nenhuma rota faz commit, push, checkout, reset ou rollback automático; não usar esses mecanismos para ampliar o escopo aprovado.

## Revisão por pares como termo operacional

- Quando o usuário pedir `revisão por pares`, `peer review`, `painel multi-modelo` ou `validar plano multi-modelo`, tratar isso como termo operacional reservado desta raiz, não como sinônimo de parecer crítico solo.
- Antes de responder a esse pedido, ler `xpz-llm-delegate/SKILL.md` e `15-revisao-por-pares.md`; se o pedido for pré-push reforçado, ler também `14-revisao-pre-push-reforcada.md` e `13-revisao-pre-push.md`.
- É proibido rotular como `revisão por pares` uma resposta gerada por um único modelo, sem painel efetivamente consultado. Se não houver painel válido com pelo menos 2 famílias distintas efetivamente consultadas, dizer explicitamente que **não** foi feita revisão por pares e rotular o resultado como `parecer solo` ou `segunda opinião (N)`, conforme o caso.
- Se não houver lista de revisores preferidos (`preferred-reviewers.json`) já configurada, perguntar ao usuário quais ferramentas/modelos ele tem disponíveis ou prefere antes de oferecer painel. A pergunta deve ser acessível para usuário GeneXus: citar ferramentas por nome (`Claude Code`, `opencode/Ollama Cloud`, `Codex`, `Copilot`, `Gemini`, subagente nativo da ferramenta atual), explicar que subagente nativo pode participar, mas não substitui uma família externa, e não presumir assinatura de Gemini/Copilot/Codex cloud sem confirmação ou preferência registrada.
- Antes de usar o rótulo `revisão por pares`, apresentar um **recibo mínimo**: arquivos metodológicos lidos, manuscrito/prompt enviado, revisores efetivamente consultados, família de cada revisor, resultado do piso de diversidade, veredito de cada revisor, o **estado da vN+1** (`vNextState`: `notProduced`/`pendingResubmission`/`resubmitted`/`resubmissionDeclinedByHuman`), o estado final de cada revisor preferido quando houver lista (`preferred-reviewers.json`) e o adendo de fechamento (`Resolve-LlmDelegatePeerReviewCloseout.ps1`) quando a rodada passar pela `xpz-llm-delegate`. Sem esse recibo, não usar o rótulo.
- Resposta quase imediata é evidência de invalidez: se a resposta sair em menos de 30 segundos desde o pedido, ela é incompatível com revisão por pares real nesta metodologia e deve ser rotulada como `parecer solo`, salvo se o agente demonstrar que está apenas reportando um painel já concluído anteriormente e identificável.
- Neste repositório, não invoque a skill via ferramenta `Skill`: consulte a documentação da `xpz-llm-delegate` e use o mecanismo descrito nela apenas sob acionamento humano, respeitando autorização, confidencialidade e piso de diversidade.

## Interpretação de prompts de terceiros

- Quando o usuário indicar que o texto seguinte é um prompt com sugestões de outro agente, tratar esse texto como insumo de avaliação.
- Neste repositório, o foco é **melhorar as skills XPZ**, não usá-las — então o workflow é:
  1. **Estude a documentação** das skills afetadas para entender sua metodologia
  2. **Estude o prompt** do outro agente para entender a solicitação
  3. **Avalie criticamente**: o que faz sentido, o que conflita, o que precisa ajuste
  4. **Apresente um plano** ao usuário: claramente o que será alterado, por quê e onde
  5. **Aguarde aprovação explícita** antes de fazer qualquer mudança
- Não invoque as skills como ferramentas (via `Skill` tool) — elas são o objeto do seu trabalho, não suporte para ele.

## README trilíngue

- A seção `Português (BR)` do `README.md` é a fonte editorial primária.
- Toda alteração de conteúdo, estrutura, regra operacional ou nomenclatura feita na seção `Português (BR)` deve ser refletida também nas seções `Español` e `English`.
- Não concluir edição do `README.md` com traduções parciais, defasadas ou estruturalmente inconsistentes sem apontar a pendência de forma explícita.

## Escopo da raiz

- Esta raiz é a base metodológica e operacional compartilhada das skills de `XPZ`/XML de GeneXus.
- Regras locais desta raiz devem ser tratadas como regras do repositório; não promovê-las automaticamente a regra universal fora desta base sem evidência documental correspondente.

## Trabalho nas skills XPZ

- Esta raiz contém a documentação metodológica de múltiplas skills (xpz-reader, xpz-builder, xpz-sync, xpz-doc-builder, xpz-daemon, xpz-kb-parallel-setup, xpz-kb-parallel-pre-push, xpz-msbuild-import-export, xpz-msbuild-build, xpz-index-triage, xpz-llm-delegate e xpz-skills-setup) e outros artefatos compartilhados.
- Ao trabalhar na melhoria de uma skill, estudar sua documentação de forma crítica e compreender seu propósito antes de propor mudanças.
- Quando receber um prompt de outro agente solicitando mudança em uma skill, não invoque essa skill como ferramenta — consulte sua documentação, analise o impacto e apresente um plano.
- Neste repositório (desenvolvimento das skills XPZ; conversa setada **fora** de qualquer pasta paralela), consultar uma pasta paralela de KB real (ex.: `Gx_FabricaBrasil/ObjetosDaKbEmXml`) como **corpus de amostras** — estudar a estrutura real de objetos para construir/validar scripts e documentação — é **consulta de fora**: leitura de referência permitida, sem invocar `xpz-kb-parallel-setup` (ver a distinção trabalhar-vs-consultar no `AGENTS.md` global). O setup só seria exigido se a frente passasse a **escrever** na pasta paralela.
- Ao avaliar mudanças em uma skill, verificar o contexto de uso para o qual ela foi projetada. Exemplo: conteúdo embutido em `xpz-skills-setup` pode parecer desatualizado em relação ao ambiente do mantenedor, mas ser correto para quem está configurando um ambiente do zero — os dois contextos coexistem.
- Antes de pesquisar uma task, abordagem ou ideia nova relacionada às skills XPZ, consultar `999-ideias-pendentes.md` e `998-ideias-descartadas-e-porque.md`. O que já foi avaliado está registrado lá — não repetir a pesquisa.

## Edição segura de Markdown

- Em `.md` longos ou estruturados, preferir edições pequenas, locais e ancoradas por seção.
- Após cada gravação, reler o início do arquivo, a seção alterada e a transição para a seção seguinte.
- Se uma edição automática produzir resultado inesperado, parar e voltar para uma estratégia mais localizada.
- Quando precisar inspecionar encoding, EOL, BOM ou whitespace visível antes de uma edição cirúrgica, usar `scripts/Show-FileWhitespace.ps1` (modos `whitespace`, `encoding`, `mixed`; opção `-AsJson`).
- Nunca gravar arquivo de texto com BOM UTF-8 a menos que o formato do arquivo exija. Em PowerShell, `[System.Text.Encoding]::UTF8` emite BOM por padrão; usar `New-Object System.Text.UTF8Encoding($false)` ou a ferramenta `edit` (que preserva o encoding original). Para `.md` e `.ps1` deste repositório, UTF-8 sem BOM é o padrão.

## Alinhamento entre documentos

- Ao alterar nomenclatura, fluxo ou regra operacional, verificar impacto pelo menos em `README.md`, `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md` (índice de ponteiros: ao tocar um script, conferir que o ponteiro de 1 linha aponta o dono normativo correto e que o papel resumido ainda confere — o detalhe de contrato vive no dono), `13-revisao-pre-push.md` (quando a frente alterar a rotina pré-push ou gates associados) e nas skills afetadas.
- Ao alterar a **forma de invocação dos adapters de delegação** (ex.: parâmetro `-MessagePath`, passagem de `argv`, variação de ferramenta), verificar paridade na seção `## Forma canônica de invocação dos adapters` do `xpz-llm-delegate/SKILL.md` e na seção `## Invocação dos adapters de delegação` abaixo.
- Não deixar convenções conflitantes entre a base compartilhada e as skills quando a mudança fizer parte da mesma frente.

## Invocação dos adapters de delegação

Convenção canônica (aplica a **todos** os agentes que atuam neste repo — Claude Code, Codex, Cursor, OpenCode):

- **Comando atômico**, prompt sempre por **`-MessagePath <arquivo>`**, sem aspas embutidas para o prompt.
- **Via Bash (primária):** `pwsh -NoProfile -File scripts/<Adapter>.ps1 -MessagePath <arquivo> [outros]` — casa a entrada `Bash(pwsh -NoProfile -File scripts/*)`.
- **Via PowerShell (fallback):** `& "<abs>\scripts\<Adapter>.ps1" -MessagePath <arquivo> [outros]` — casa a entrada `PowerShell(& "<repo>\scripts\*" *)`.
- NÃO usar `& "scripts\<Adapter>.ps1"` (relativo via PowerShell) — não é coberto pela allowlist.
- Detalhes completos (síncrono/assíncrono, `-Cd`, ressalva ~32KB, exemplo do caso real): ver `xpz-llm-delegate/SKILL.md`, seção `## Forma canônica de invocação dos adapters`.

## Revisão pré-push

- Fonte **autoritativa** da rotina: [13-revisao-pre-push.md](13-revisao-pre-push.md) (passo mecânico, fase semântica, paridade motor↔doc, veredicto).
- Resumo obrigatório antes de push: executar `scripts/Invoke-PrePushMechanicalChecks.ps1` (`-AsJson` para agentes), depois a busca semântica integral descrita no `13` — **não** basta grep de termos em `.md`; validar implementação dos motores citados.
- **Lockstep de motor compartilhado:** se a frente alterar de forma *breaking* o **contrato de consumo** de um motor compartilhado (stdout, shape do retorno, semântica de exit) consumido por wrappers locais (ex.: `Update-*KbFromXpz.ps1` em pastas paralelas), conferir na fase semântica se a skill que **audita os consumidores** (ex.: `xpz-kb-parallel-setup` via `scripts/Test-XpzWrapperInventory.ps1`) ganhou o **check de detecção de drift no mesmo PR** — paridade documental da skill não basta; ver `13` §3.
- Escopo: análise e relatório ao usuário; correções só após aprovação explícita **depois** do relatório pré-push.
- **Gate semântico incondicional:** a fase semântica produz relatório e para. Nenhuma edição de arquivo, commit ou push acontece entre o relatório e a aprovação explícita do usuário — sem exceção, independentemente do tamanho ou obviedade do gap.
- **Tier reforçado (opcional):** revisão por painel multi-modelo diverso e régua de convergência (push-ready só quando o painel inteiro responde "sem gap" sobre o estado final) em [14-revisao-pre-push-reforcada.md](14-revisao-pre-push-reforcada.md).
- **Modo assistido por dossiê (reforçada):** o revisor **semantic-only** (sem shell: opencode `reviewer-ro`, Claude Code, Copilot, Gemini) não roda o passo mecânico; o orquestrador monta um dossiê (`scripts/Build-PrePushReviewDossier.ps1`) e ele roda só a fase semântica. O revisor **git-capable** (Codex-delegate, subagente nativo) é inalterado; painel válido retém ≥1 git-capable, e árvore suja bloqueia o despacho do semantic-only. Detalhe em `13` («Modo assistido por dossiê») / `14`.
- **Metodologia genérica:** a revisão por pares (manuscrito → painel multi-modelo → convergência) é normativa em [15-revisao-por-pares.md](15-revisao-por-pares.md); o `14` é a sua aplicação pré-push.

## Rastreabilidade privada de moldes sanitizados

- Quando uma frente criar, fortalecer, recombinar ou ampliar cobertura de molde sanitizado publicável, o agente deve avaliar explicitamente se existe anotação correspondente a registrar no `GeneXus-XPZ-PrivateMap`.
- Essa avaliação faz parte do fechamento metodológico da frente, mesmo quando nenhuma edição for feita imediatamente no repositório privado.
- Se houver necessidade de atualização no `GeneXus-XPZ-PrivateMap`, tratar isso como outro contexto operacional e sinalizar claramente ao usuário antes de editar fora desta base pública.

## KbIntelligence — ambiente e consultas

- Rebuild do índice SQLite (`scripts/Build-KbIntelligenceIndex.ps1` / `.py`) exige **Python 3.x utilizável** no `PATH`, resolvido por `scripts/GeneXusPythonPrerequisite.ps1` (rejeita stub `WindowsApps` sem executável real).
- Ausência de Python bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE`; a materialização XPZ/XML pode já ter concluído — não tratar como falha do pacote exportado; **rigor**: sync oficial **não** terminou — declarar **fluxo incompleto** (XMLs possivelmente atualizados, índice pendente); não declarar sync OK nem autorizar triagem ampla sem índice; ver `README.md`, `08-guia-para-agente-gpt.md` e `xpz-sync`.
- Wrappers locais `Update-*KbFromXpz` devem chamar o rebuild no **mesmo processo** `pwsh` e propagar a mensagem do motor (não mascarar com só código numérico).
- Antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catálogo efetivo (`scripts/gx-object-type-catalog.json` + override local) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, `Query-KbIntelligenceIndex.py` aplica o mesmo merge (via `GeneXusObjectTypeCatalogCore.py`, `--parallel-kb-root` / `--catalog-override-path`) e devolve exit `11`, `blocked=true` e `reason=QUERY_NOT_SEMANTIC_FOR_TYPE` — **não** tratar como zero dependências; ver `02`, `08` e `scripts/README-kb-intelligence.md`.

## Idioma

- Responder ao usuário em português, salvo pedido explícito em outro idioma.
- Quando citar conteúdo técnico originalmente em inglês, traduzir ao explicar sempre que isso melhorar a compreensão.
- Ao explicar uma decisão ao usuário, traduzir termos conceituais técnicos para português (ex: "gate" → "verificação automática" ou "validação"; "playbook" → "roteiro"; "upstream" → "anterior" ou "que serve de base"; "fingerprint" → "marca de localização"; "manifesto" → "resumo descritivo do pacote"). Manter em inglês apenas nomes próprios — identificadores literais como `xpz-builder`, `who-uses`, `import_file.xml`.
- Misturar conceitos em inglês sem tradução em diálogo pt-BR aumenta o risco de o usuário não entender. Quando em dúvida, traduzir ou definir na primeira aparição.
