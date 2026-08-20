# 13 — Rotina de revisão pré-push

## Papel do documento

Fonte **autoritativa** da rotina pré-push deste repositório. O `AGENTS.md` na raiz apenas aponta para este arquivo; agentes e mantenedores devem seguir o conteúdo integral aqui antes de considerar push liberado.

Para o tier **reforçado e opcional** desta rotina — revisão por **painel multi-modelo diverso** e régua de convergência (push-ready só quando o painel inteiro responde "sem gap" sobre o estado final) — ver [`14-revisao-pre-push-reforcada.md`](14-revisao-pre-push-reforcada.md).

## Escopo

A rotina pré-push é de **análise, busca de coerência e relatório** ao usuário. **Não** inclui alterar arquivos nem criar commits com base no relatório. Em face dos gaps, o agente **apresenta** o diagnóstico e, se fizer sentido, um diff ou lista de alterações sugeridas, e **só grava** no repositório após **aprovação explícita** do usuário **depois** do relatório — mesmo que a intenção inicial da sessão fosse aplicar correções; a pré-push não autoriza aplicar automaticamente com base apenas nessa intenção inicial. Uma única aprovação explícita (ex.: «ok, aplica os gaps do relatório») cobre o **conjunto** de alterações sugeridas, salvo o usuário pedir confirmação item a item.

**Repositório de skills vs pasta paralela de KB.** Esta rotina aplica-se ao **repositório de skills** `GeneXus-XPZ-Skills`. Para a validação pré-push do estado de uma **pasta paralela de KB** GeneXus (com `ObjetosDaKbEmXml/`, `KbIntelligence/` etc.), antes de o usuário fazer push dessa KB, a rotina é outra: a skill [`xpz-kb-parallel-pre-push`](xpz-kb-parallel-pre-push/SKILL.md) (orquestrador `Invoke-XpzKbParallelPrePushPhase1.ps1`, gates G0–G5 + K1–K4/K8/K9/K11). São rotinas distintas, com autoridade documental distinta; não confundir os dois contextos no relatório.

## Passo mecânico inicial

Executar `scripts/Invoke-PrePushMechanicalChecks.ps1` em `pwsh` 7.4+ (`-AsJson` quando o chamador for agente). Por padrão o script compara a branch atual com `origin/main` — ou seja, **tudo que foi commitado localmente e ainda não foi enviado ao remoto** (desde o último push usual em `main`). Contagem de commits, lista de commits, arquivos alterados e `git diff --check` usam **o mesmo** intervalo (`BaseRef..HEAD`, com `BaseRef` default `origin/main`); não altere `-BaseRef` salvo necessidade explícita. O script classifica os arquivos **do diff desse intervalo**, delega parse PowerShell a `scripts/Test-PsScriptsParse.ps1` (inclui `scripts/*.ps1`, `scripts-maintenance/*.ps1` e `*.example.ps1` fora de `historico/`) e parse Python sem bytecode a `scripts/Test-PyScriptsParse.ps1` — **sem** substituir a busca semântica abaixo. O orquestrador **avisa** (sem falhar o gate mecânico) se a branch não for `main` ou se a working tree tiver alterações não commitadas fora desse intervalo.

### Forma canônica de invocação do orquestrador

Usar **uma e apenas uma** destas formas literais:

- Quando `cwd` é a raiz do repositório: `pwsh -NoProfile -File scripts/Invoke-PrePushMechanicalChecks.ps1 -AsJson`
- Quando `cwd` não é a raiz: `pwsh -NoProfile -File "<path-absoluto-com-backslashes>\scripts\Invoke-PrePushMechanicalChecks.ps1" -AsJson`

### Limites do passo mecânico (evitar leituras erradas)

- **Parse PowerShell:** `Test-PsScriptsParse.ps1` varre **todo** o repositório ativo (`scripts/*.ps1`, `scripts-maintenance/*.ps1` e `*.example.ps1` fora de `historico/`) — gate de saúde do repo, **não** limitado ao diff do intervalo. Pode falhar o mecânico com `commitsAhead=0` se houver script quebrado fora do que mudou.
- **Parse Python:** `Test-PyScriptsParse.ps1` varre `scripts/*.py` e usa `ast.parse`, sem `py_compile` e sem gerar `__pycache__/*.pyc`; falha de escrita em bytecode não deve bloquear validação de sintaxe.
- **Working tree:** com `commitsAhead=0` não há diff nem `git diff --check` no intervalo («nada commitado pendente de push»). A pré-push **não** substitui revisão de alterações **só** na working tree; o orquestrador avisa contagens, mas não analisa esses arquivos no intervalo.
- **`exit 0` vs push:** `exit 0` do orquestrador **não** significa «pode dar push» nem pré-push concluída. Ler `PUSH_READINESS` (e `pushReadiness` no JSON): com `blocked`, push fica proibido até integrar o remoto, mesmo com parse/whitespace limpos.
- **`pushReadiness=blocked`:** bloqueia **push** e torna diff/arquivos do intervalo apenas diagnósticos; **não** dispensa a fase semântica sobre os commits locais ainda pendentes — continuar o relatório de coerência cruzada.
- **Gates consultivos:** os gates consultivos do orquestrador (ver a tabela «Scripts do orquestrador» ao final — fonte única; não reenumerar nomes aqui) apontam riscos objetivos; **não** substituem a fase semântica nem autorizam concluir a pré-push sozinhos.

### Referência remota fresca

Quando a intenção for comparar contra o **remoto real atual**, garantir `origin/main` atualizada com `git fetch origin` **antes** do passo mecânico. Ref inexistente (o script falha com mensagem clara) e ref existente porém desatualizada são casos distintos — a segunda pode superestimar commits «à frente» ou mascarar divergência com o remoto.

### Remoto à frente (`commitsBehind`)

Quando `commitsBehind > 0`, o intervalo `BaseRef..HEAD` deixa de representar limpidamente «só o que falta enviar» — compara árvores divergentes; lista de arquivos e `git diff --check` nesse intervalo são **apenas diagnósticos**. O orquestrador emite `pushReadiness=blocked` (sem falhar parse/whitespace). A pré-push **não** deve ser considerada liberada para push até integrar o remoto: se ainda não houve fetch, `git fetch origin`; se `commitsBehind` persistir, integrar com o usuário (ex.: `git pull --rebase origin main` ou merge) — não fazer push automático.

### Modo assistido por dossiê (revisor semantic-only)

No tier **reforçado** ([`14`](14-revisao-pre-push-reforcada.md)), nem todo revisor consegue **executar** este passo mecânico: os adapters de LLM rodam os backends em modo restrito, e há uma classe **semantic-only** que **não tem shell** (não roda git nem `pwsh`) — o opencode `reviewer-ro` (nega `bash`) e, por configuração de adapter, Claude Code, Copilot, Gemini e Antigravity. A classe **git-capable** (roda git) é o Codex-delegate (sandbox read-only) e o subagente nativo (Bash). Duas capacidades, provadas empiricamente por probe, não inferidas.

Para o revisor **semantic-only**, o orquestrador — que tem git — roda o passo mecânico **uma vez** e monta um **dossiê** com [`scripts/Build-PrePushReviewDossier.ps1`](scripts/Build-PrePushReviewDossier.ps1), entregue **inline no prompt** (o transporte por adapter — stdin vs argv — está no «Eixo do transporte» abaixo):

- **Seção A — git BRUTO (fato):** `rev-parse HEAD`, `log origin/main..HEAD`, `diff origin/main..HEAD`, `status --porcelain`.
- **Seção B — diagnóstico mecânico (NÃO verdade):** o container inteiro do `Invoke-PrePushMechanicalChecks.ps1 -AsJson`, sob cabeçalho literal único rotulado «candidatas a verificar, NÃO verdade». O mecânico é a **fonte de verdade** de `commitsBehind`/`pushReadiness`; o builder **referencia** (lê do `-AsJson`), não reencena a **política push-ready** do motor. Se o mecânico falhar ou lançar (JSON imparseável), o dossiê continua **pronto** com `mechanicalStatus=failed`; nesse modo degradado o builder reafirma **apenas o fato bruto `commitsBehind`** por git, deixando `pushReadiness`/`intervalDiffDiagnosticOnly` **indeterminados** (`unknown`/`null`) — não fabrica um veredito de push paralelo à fonte de verdade.
- **Sentinelas** ao fim (`HEAD:` + `END_DOSSIER sha256=`), **anti-truncamento**: o revisor as ecoa; o hash cobre o **corpo** (bytes UTF-8 sem BOM, EOL=LF, excluindo as sentinelas). Eco ausente **mas parecer on-task** = `responded`+`noEchoSentinel` no recibo (não `noResponse`). É anti-truncamento, **não** anti-dossiê-errado — contra isso vale o invariante git-capable (`14`).

<!-- backend-parity: ignore -->
**Eixo do transporte.** Adapters `stdin-dossier-capable` (opencode, Claude Code) recebem o dossiê por stdin, sem teto prático. Adapters `argv-limited` (Copilot, Gemini, Antigravity) passam o prompt por argv, com guard fail-closed (~30000 chars): dossiê acima do teto ⇒ o orquestrador **omite** o revisor (`unavailable`+`dossier-too-large`), sem truncar nem degradar em silêncio.

O revisor semantic-only roda **só a fase semântica** read-only sobre o dossiê; **não** roda o passo mecânico (não pode). O revisor git-capable é **inalterado**: roda a rotina inteira e reproduz a Seção A por conta própria. Um painel reforçado válido retém **≥1 git-capable** que reproduz a Seção A (ver [`14`](14-revisao-pre-push-reforcada.md)).

**Gate de árvore limpa (pré-condição adicional do modo dossiê).** O semantic-only lê a árvore **viva** por `read`/`grep`/`glob`, e a Seção A cobre só o commitado — conteúdo não-commitado contaminaria a leitura dele **sem que ele possa distinguir** committed de working-tree (não tem git). Por isso, com `workingTreeDirty=true`, o orquestrador **não despacha** os revisores semantic-only: para, reporta a **lista de paths sujos** (`git status --porcelain`) e pede **commit ou stash**. Só gateia o semantic-only — o git-capable **pode distinguir** committed de working-tree e segue normal. É pré-condição **adicional** do modo dossiê, coerente com o item «Working tree» dos limites acima (que trata do passo mecânico apenas **avisar**): aqui a leitura da árvore viva pelo próprio revisor exige a garantia.

A **política de painel** (invariante git-capable, piso de diversidade, serial por custo, dossiê regenerado a cada novo HEAD) é normativa no [`14`](14-revisao-pre-push-reforcada.md).

## Fase semântica — por frente alterada

### 1. Inventário da frente

Identificar termos, scripts, wrappers, parâmetros, estados, caminhos e regras operacionais introduzidos ou modificados.

### 2. Busca no repositório

Buscar esses mesmos termos no repositório inteiro (não parar no primeiro arquivo que contém o termo).

Quando a frente altera motor com versão, assinatura, código de evidência, regra de extração ou nome de estado, buscar também os **termos antigos** que ficaram para trás. Exemplo: se `Build-KbIntelligenceIndex.py` muda `EXTRACTOR_SIGNATURE_VERSION` de `N` para `N+1`, procurar referências à versão textual anterior (`extrator N`, `extractor N`, `extrator atual N`, `signature_version N` e variações equivalentes) nos Markdown operacionais; ocorrência residual em documento normativo é gap, salvo justificativa explícita de histórico.

Simetricamente, quando a frente **adiciona** parâmetro, alias, flag, estado ou opção a um contrato, buscar o **termo novo** em todas as menções da mesma operação e confirmar propagação completa — não basta confirmar que o termo antigo não ficou para trás. Exemplo: se um wrapper passa a aceitar `-ObjectList` ao lado de `-ObjectNames`/`-ObjectGuids`, procurar todas as descrições dessa operação (`README.md`, `02`, `08`, `09`, skills, checklists e exemplos `*.example.ps1`) e confirmar que cada menção pré-existente equivalente recebeu o termo novo; menção que ficou só com o conjunto antigo é gap, salvo justificativa explícita.

Suporte mecânico (consultivo): `scripts/Test-PrePushNewTokenPropagation.ps1`, chamado pelo orquestrador, detecta no diff o termo introduzido por **transição co-localizada** (`- ...-ObjectNames`/`-ObjectGuids` → `+ ...-ObjectList, -ObjectNames`/`-ObjectGuids`), filtra pares por morfema comum e ignora variável `$Token` de código e declaração do próprio parâmetro, listando as menções do repositório que ficaram com o termo antigo sem o novo como candidatas em `agentWarnings`. É apoio, não substituto: só dispara quando há transição co-localizada no mesmo hunk (alias adicionado sem enumeração pré-existente não gera par) e devolve candidatas a confrontar, não veredito — a varredura desta seção continua obrigatória.

**Disciplina de confronto por classe (anti-descarte-em-lote).** O gate anota em cada candidata uma `mentionClass` (`prose`, `param-list-item`, `param-table-cell`, `command-example`), também no sufixo `[classe=...]` da mensagem em `agentWarnings`. Candidatas `prose` — que apenas citam o nome canônico em texto corrido — admitem justificativa coletiva (ex.: «o nome canônico está correto; o alias/contrato vive na seção canônica do `02`; repetir em cada menção seria ruído»). Candidatas `param-list-item`, `param-table-cell` e `command-example` **não** admitem justificativa coletiva: cada uma exige veredito próprio, confrontado contra a lista/tabela/exemplo **gêmeo** que documenta o mesmo contrato em outro documento. Uma lista de parâmetros que descreve o mesmo parâmetro em dois lugares deve refletir o alias/tipo novo em ambos; divergência só é aceitável se declarada item a item com justificativa. Motivação empírica: o modo de falha real foi descartar todas as candidatas de uma vez sob uma justificativa de prosa, varrendo junto uma lista de parâmetros gêmea que de fato divergira — um parâmetro enriquecido com alias e tipo numa lista de parâmetros e deixado cru na lista-gêmea de outro documento. Para que esse confronto seja possível, o gate **não trunca** candidatas não-prosa: o teto `-MaxFindings` aplica-se só à `prose` (com `truncatedProseCount` informando quantas foram descartadas), de modo que o conjunto `param-list-item`/`param-table-cell`/`command-example` chega **completo** ao revisor mesmo numa frente que toca muitos documentos e inunda a raiz com prosa. O orquestrador segrega essas candidatas no campo `nonProseVerdictRequired` e injeta no `agentSemanticChecklist` a exigência de um **livro-razão item a item**: listar cada candidata não-prosa com arquivo:linha, a lista/tabela/exemplo gêmeo no outro documento e o veredito (`gap` ou `justificado`), sem agregação. Produzir esse livro-razão é parte obrigatória da fase semântica sempre que houver candidatas não-prosa — não basta apontar um gap e parar nos itens salientes.

**Salvaguarda de diversidade de modelo (recomendada acima de limiar).** Quando as candidatas não-prosa do gate de propagação excederem o limiar (hoje **> 5**), o orquestrador recomenda no `agentSemanticChecklist` uma segunda passada da fase semântica por um **modelo distinto** antes de fechar o veredito. Passadas do mesmo modelo tendem a repetir o mesmo ponto cego — e o sinal mecânico completo **não basta**: em incidente real, mesmo com todas as candidatas não-prosa surgidas (sem truncamento) e a disciplina de classe em vigor, uma passada de um modelo confrontou um `param-list-item` (gap) e deixou **outro, igualmente sinalizado**, passar; só um modelo distinto pegou o segundo. Antes disso, três passadas do mesmo modelo já haviam descartado em lote uma candidata legítima que um modelo diferente confirmou. É mitigante probabilístico, não garantia; abaixo do limiar continua sendo julgamento do revisor, acima dele deixa de ser opcional silencioso.

A regra acima vale para qualquer **conjunto enumerado**, não só parâmetros: quando a frente adiciona um membro a um conjunto que o repositório descreve em mais de um lugar (gates da pré-push, backends de delegação, scripts, estados, exit codes), **toda** enumeração desse conjunto — inclusive afirmações fechadas do tipo «os X são A e B» — precisa refletir o membro novo. Atenção ao **furo de direção**: buscar só o termo *novo* é cego a enumerações que descrevem o conjunto sem nomeá-lo (a frase defasada cita os membros *antigos*, não o novo). Por isso, ao adicionar um membro, buscar **também a co-ocorrência dos termos antigos** e conferir se aquela enumeração recebeu o novo.
Para o conjunto de **gates da pré-push**, há suporte mecânico em `scripts/Test-PrePushGateEnumerationParity.ps1`.
Para o conjunto de **backends de delegação**, há suporte em `scripts/Test-PrePushBackendEnumerationParity.ps1`. Ambos derivam do código a verdade e sinalizam enumerações na doc que ficaram como subconjunto próprio.

### 3. Comparação documental

Comparar a documentação afetada com:

- skills relacionadas — incluindo **skills transversais** que documentam o contrato, parâmetros ou checklist de um script compartilhado alterado, mesmo que essa skill não esteja no diff; não interpretar "relacionadas" como apenas "skills da mesma frente". Suporte mecânico (consultivo): `scripts/Test-PrePushSharedScriptSkillCoverage.ps1`, chamado pelo orquestrador, lista os `SKILL.md`/`quality-checklist.md` que citam um script alterado e não foram tocados, como candidatas em `agentWarnings` — apoio, não substituto da comparação
- `README.md`
- `02-regras-operacionais-e-runtime.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`, quando a frente alterar script compartilhado, contrato metodológico, skill, checklist, nomenclatura operacional, estado, parâmetro, wrapper ou evidência pública rastreável — o `09` é um **índice de ponteiros** (1 linha por script: papel + dono normativo + validação; o detalhe de contrato vive no dono), então a comparação verifica se o ponteiro aponta o dono certo e se o papel resumido ainda confere, não se o detalhe bate
- exemplos canônicos `*.example.ps1` nas skills afetadas (hoje principalmente `xpz-kb-parallel-setup/examples/`; não há `examples/` na raiz)
- scripts compartilhados em `scripts/`

Quando a mudança afetar regra operacional compartilhada, `02-regras-operacionais-e-runtime.md` é documento obrigatório de paridade: a regra deve existir ali ou a ausência deve ser descartada com justificativa explícita no relatório. Cobertura apenas em `08`, `09`, skill ou README técnico não basta para concluir alinhamento.

**Lockstep de contrato de consumo de motor compartilhado.** Quando a frente altera de forma *breaking* o **contrato de saída/consumo** de um motor compartilhado (formato do stdout, shape do objeto de retorno, semântica de exit) consumido por **wrappers locais** (ex.: clones `Update-*KbFromXpz.ps1` em pastas paralelas) ou outros consumidores, conferir explicitamente que a skill que **audita/policia esses consumidores** (ex.: `xpz-kb-parallel-setup`, via `scripts/Test-XpzWrapperInventory.ps1` e os sinais `INVENTORY_*`) ganhou o **check de detecção de drift correspondente na MESMA frente** — não basta a doc da skill estar alinhada. Parquear a migração do consumidor só no `CHANGELOG`/`999` é insuficiente: o gate que existe para pegar consumidor defasado continua cego. Precedente: o motivo `consumes_legacy_text_stdout` de `INVENTORY_CUSTOMIZED` (para `Update-*KbFromXpz.ps1` que ainda consome o stdout textual do `Sync-GeneXusXpzToXml.ps1`).

Antes de declarar que um termo, self-test, script, regra ou evidência está ausente de um documento, confrontar a alegação com o conjunto completo de resultados de busca e leituras já coletados na fase semântica — não só com a busca mais recente ou mais estreita. Uma ausência só vira gap confirmado se nenhuma busca anterior, diff, leitura de seção ou trecho aberto contradisser a alegação; se houver conflito entre resultados, reler o arquivo-alvo no ponto citado antes de reportar.

### 4. Avaliação de `CHANGELOG.md`

Para cada frente alterada, avaliar se houve mudança de comportamento público, contrato operacional, script público, skill, governança, segurança, fluxo de contribuição, remoção, rename ou incompatibilidade relevante para quem usa ou acompanha o repositório.

Quando houver impacto público, `CHANGELOG.md` deve receber entrada em `Unreleased` antes da publicação. Se o changelog não for atualizado, o relatório pré-push deve registrar uma flag descartada com justificativa explícita (ex.: correção textual interna, refatoração sem mudança de contrato, ajuste de histórico sem efeito operacional).

`CHANGELOG.md` é alvo de comparação documental quando a frente tiver impacto público. Ele não substitui `historico/IdeiasImplementadas_YYYYMM.md`: o histórico mensal explica a frente; o changelog resume o impacto público.

### 5. Paridade motor ↔ promessa documental (obrigatório)

Quando a frente introduzir ou alterar regra que cite **motor por nome** (ex.: «`Query-KbIntelligenceIndex` usa catálogo efetivo», «exit `11`», «`-ParallelKbRoot`»):

1. Ler o trecho do motor citado (`.py` / `.ps1`), não só a documentação.
2. Se a doc citar **dois artefatos** na mesma regra (base + override, parâmetro, exit code), ambos devem existir no motor ou no wrapper que a doc manda usar.
3. Se existir motor **par** na mesma frente (ex.: `Build-KbIntelligenceIndex` já aceita `-ParallelKbRoot` / `--catalog-override-path`), outro motor que aplique a **mesma decisão** (gate, bloqueio, classificação) deve expor o mesmo contrato, salvo justificativa explícita no relatório.

**Red flags objetivas (grep / leitura de arquivo):**

- Doc diz «catálogo efetivo» (base + `gx-object-type-catalog.override.json`), mas o motor usa só `gx-object-type-catalog.json` fixo ao lado do script.
- `Build-KbIntelligenceIndex.ps1` expõe `-ParallelKbRoot` e `Query-KbIntelligenceIndex.ps1` não.
- Selftest da frente não exercita override quando a doc promete catálogo efetivo no query.
- `Build-KbIntelligenceIndex.py` incrementa `EXTRACTOR_SIGNATURE_VERSION`, mas documento operacional ainda menciona a versão antiga do extrator.
- Tipo `queryableByKbIntelligence=true` ganha nova aresta ou regra de extração, mas `02-regras-operacionais-e-runtime.md` não explica o que o índice materializa e o que ainda exige leitura XML.

### 6. Regra em camadas para skills longas

Ao alinhar nomenclatura ou contrato (ex.: `lastUpdate`, `-AcervoPath`, `executionEvidence`, `pathEnrichment`, `queryableByKbIntelligence`), varrer o `SKILL.md` **e os satélites que ele manda carregar** antes de considerar a frente fechada — não basta o `SKILL.md` estar alinhado. Exemplos em `xpz-builder`: [quality-checklist.md](xpz-builder/quality-checklist.md), [wwp-packaging.md](xpz-builder/wwp-packaging.md), `responsibilities-by-type/*.md`. Três cortes: (1) checklist final ou gates de fechamento; (2) fluxo operacional e captura de resultado; (3) inventário de scripts e contratos por script.

### 7. Checklist de gaps

Confirmar se há:

- documentação antiga que contradiz a nova
- exemplos canônicos desatualizados
- scripts cujo contrato não bate com a descrição
- checklist que promete validação que o script não executa
- checklist em **satélite** do `SKILL.md` desatualizado frente ao `SKILL.md`, `02` ou scripts da mesma frente
- nova ferramenta documentada em uma skill, mas ausente nas skills correlatas
- rastreabilidade pública desatualizada em `09-inventario-e-rastreabilidade-publica.md` (presença do termo não basta — comparar abrangência)
- rastreabilidade agregada demais no `09` (motor vs bateria com papéis distintos)
- selftest que não cobre contrato novo documentado (reportar como área não coberta ou gap de teste)
- mudança com impacto público sem entrada correspondente em `CHANGELOG.md` nem justificativa explícita de omissão
- campo de rastreabilidade em `historico/` (`Commit:`/`PR:`) com placeholder genérico (`este commit`, `este PR`, `TODO`, `TBD`, vazio ou `<...>`) em vez do hash real — salvo quando o commit ainda não existe e o campo será preenchido no commit seguinte (reportar como "a preencher"). Suporte mecânico (consultivo): `scripts/Test-PrePushHistoryCommitPlaceholder.ps1`, sobre os `historico/*.md` no diff

### 8. Relatório

Reportar separadamente:

- gaps confirmados
- flags descartados, com justificativa
- áreas não cobertas pela busca

Categoria adicional de relato (**não** conta no `VEREDICTO`): **lacuna candidata**. Quando a busca encontrar motor, self-test ou evidência **tocado ou criado pela frente** mas ausente do `09` (ou de outro documento de rastreabilidade), reportá-lo separando explicitamente **atribuição** (ausência pré-existente não bloqueia a push) de **mérito** (cobertura que pode valer registrar). Não tratar «não é desta frente» como motivo automático de descarte: corrigir lacuna pré-existente adjacente é decisão do usuário, e deve ser apresentada de forma neutra, sem enviesar para o descarte.

### Gate semântico: relatório antes de qualquer edição

A fase semântica produz um **relatório**. Esse relatório é o produto da pré-push — não as edições.

Entre o relatório e qualquer edição de arquivo, commit ou push, existe uma **validação obrigatória**: o agente deve parar, apresentar o relatório completo e aguardar aprovação explícita do usuário (`sim`, `aprova`, `pode aplicar`, etc.).

Esta validação é **incondicional** — vale para gaps grandes e pequenos, para correções óbvias e não óbvias. Não existe categoria de gap "pequeno o suficiente para corrigir sem perguntar".

Se o agente encontrar gaps durante a busca semântica:

1. Apresentar o relatório com gaps confirmados, flags descartados e áreas não cobertas.
2. Parar. Não editar nenhum arquivo.
3. Aguardar aprovação explícita do usuário para cada alteração proposta.
4. Só após aprovação, executar as correções.

### 9. Veredicto

Encerrar com linha fixa:

`VEREDICTO: nenhum gap confirmado`

ou

`VEREDICTO: N gap(s) confirmado(s)`

(`N` = contagem de gaps confirmados). Avisos descartados e áreas não cobertas **não** contam como gap. A linha é obrigatória mesmo quando o mecânico passou; ausência significa pré-push não concluída.

## Conclusão

A rotina pré-push não está concluída enquanto a busca semântica acima não tiver sido executada e reportada, mesmo que `git diff --check`, parse e testes locais estejam limpos. **Não** tratar `exit 0` do passo mecânico como pré-push concluída **nem** como autorização de push quando `PUSH_READINESS=blocked`.

## Padrões de busca por tipo de frente

### Catálogo efetivo / KbIntelligence

- Positivo nos motores citados: `merge`, `override`, `ParallelKbRoot`, `catalog-override-path`, `GeneXusObjectTypeCatalogCore`, `resolve_effective`.
- Negativo: `CATALOG_PATH = Path(__file__).with_name("gx-object-type-catalog.json")` sem merge no mesmo fluxo que aplica `queryableByKbIntelligence` ou bloqueio semântico.

### MSBuild headless

Ver `10-base-operacional-msbuild-headless.md` e gate `Test-PrePushMsBuildProbeDocParity.ps1` quando o intervalo tocar motores MSBuild.

## Scripts do orquestrador

| Script | Papel |
| --- | --- |
| `scripts/Invoke-PrePushMechanicalChecks.ps1` | Orquestrador mecânico (git, parse, avisos) |
| `scripts/Build-PrePushReviewDossier.ps1` | Monta o dossiê (Seção A git bruto + Seção B `-AsJson`) para o revisor **semantic-only** da reforçada (ver «Modo assistido por dossiê»); dono normativo do modo = este `13`, política de painel = `14` |
| `scripts/Test-PyScriptsParse.ps1` | Parse AST de `scripts/*.py` sem gerar bytecode |
| `scripts/Test-PrePushTraceabilityCoverage.ps1` | Rastreabilidade editorial + paridade motor/doc; trava `PUBLIC_TRACEABILITY_VERBOSE_LINE` do índice de ponteiros do `09` (consultivo) |
| `scripts/Test-PrePushMsBuildProbeDocParity.ps1` | Paridade MSBuild probe (quando aplicável) |
| `scripts/Test-GeneXusUnexpectedCharacter.ps1` | Caracteres Unicode inesperados em .md/.ps1 (consultivo) |
| `scripts/Test-PrePushNewTokenPropagation.ps1` | Propagação de termo novo introduzido no diff por transição co-localizada (consultivo) |
| `scripts/Test-PrePushSharedScriptSkillCoverage.ps1` | Script compartilhado alterado documentado em SKILL.md/quality-checklist.md fora do diff (consultivo) |
| `scripts/Test-PrePushHistoryCommitPlaceholder.ps1` | Placeholder genérico em campo `Commit:`/`PR:` de `historico/` no diff (consultivo) |
| `scripts/Test-PrePushGateEnumerationParity.ps1` | Enumeração de gates na doc que ficou subconjunto próprio do que o orquestrador executa (consultivo) |
| `scripts/Test-PrePushBackendEnumerationParity.ps1` | Enumeração de backends de delegação na doc que ficou subconjunto próprio de `$AdapterScript` no dispatcher (consultivo) |

## Espelho em outros documentos

- `08-guia-para-agente-gpt.md`: resumo operacional para agentes GPT; em divergência, **este arquivo (`13`) prevalece** para a rotina pré-push completa.
- `09-inventario-e-rastreabilidade-publica.md`: evidência dos scripts listados acima.
