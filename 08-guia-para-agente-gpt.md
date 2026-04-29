# 08 - Guia para Agente GPT

## Papel do documento
operacional

## Nivel de confianca predominante
medio

## Depende de
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 04-webpanel-familias-e-templates.md, 05-transaction-familias-e-templates.md, 05b-procedure-relatorio-familias-e-templates.md

## Usado por
qualquer GPT que precise consumir esta base consolidada

## Objetivo
Explicar como outro agente GPT deve consultar esta base, classificar evidencias e decidir entre gerar, exigir molde proximo ou abortar.

## Fontes consolidadas
- 26-guia-para-agente-gpt.md

## Origem incorporada - 26-guia-para-agente-gpt.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
qualquer agente GPT que precise responder perguntas ou tomar decisão operacional usando esta base

## Objetivo
Explicar como um agente GPT deve consultar esta base documental e como responder com prudência.
Padronizar quando avançar, quando exigir molde bruto comparável e quando abortar.

## Ordem de consulta recomendada

1. ler `00-indice-da-base-genexus-xpz-xml.md`
2. ler `02-regras-operacionais-e-runtime.md`
3. identificar o tipo alvo e checar `03-risco-e-decisao-por-tipo.md`
4. usar `01-base-empirica-geral.md` como indice mestre da serie `01` e abrir o filho empirico mais aderente (`01a` a `01h`)
5. para `WebPanel`, ler `04-webpanel-familias-e-templates.md`
6. para `Transaction`, ler `05-transaction-familias-e-templates.md`
7. para `Procedure` de relatorio (nome com prefixo de relatorio no acervo), ler `05b-procedure-relatorio-familias-e-templates.md`
8. ler `07-open-points-e-checklist.md` quando a resposta depender de limites conhecidos, pendencias metodologicas ou frentes ainda abertas
9. usar `09-inventario-e-rastreabilidade-publica.md` para sustentar rastreabilidade

`06-padroes-de-objeto-e-nomenclatura.md`: leitura suplementar — indicado quando a duvida envolver nomenclatura de objetos, prefixos de tipo ou comportamento de `Folder` vs `Module` no `fullyQualifiedName`.

### Fluxo curto para `Procedure` de relatorio simples

1. classificar primeiro se o caso cabe em familia simples `F2` ou `F3`
2. se couber, partir de `05b-procedure-relatorio-familias-e-templates.md` como molde sanitizado canonico primario
3. separar explicitamente `Source`, `Rules` e layout antes de editar ou diagnosticar
4. tentar no maximo um corretivo estrutural curto se a primeira montagem falhar
5. escalar para XML real comparavel apenas se o caso fugir da cobertura simples, se a tentativa inicial mais esse unico corretivo curto falharem, ou se aparecer sinal de dialeto/localismo da KB
6. registrar no handoff qual base esta sustentando a resposta: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB` ou `hipotese`

## Regra de precedencia sobre skills gerais

- quando a tarefa for de `XML`/`XPZ` nesta base, os `.md` locais da pasta do projeto tem precedencia sobre heuristicas gerais de skill
- isso nao revoga a postura conservadora do skill `nexa`; apenas define que a evidencia local consolidada nesta base e a fonte mais especifica desta trilha
- se houver tensao entre fluxo GeneXus geral do skill e achado empirico local desta base, o agente deve seguir a base local para decisao de `XPZ`/`XML` e manter do skill apenas a disciplina metodologica
- quando a base compartilhar uma capacidade operacional nova, isso nao autoriza presumir que wrappers locais da pasta paralela da KB ja a exponham; a exposicao local e decisao separada
- se o wrapper local ainda nao expuser um parametro operacional relevante ja disponivel na base compartilhada, o agente deve tratar isso como oportunidade de atualizacao local, mencionar ao usuario e aguardar aprovacao explicita; nao deve executar a mudanca local automaticamente
- exemplos sanitizados `.example.ps1` publicados pelas skills podem servir como referencia metodologica para reconstruir wrappers locais finais, mas nao substituem o wrapper local real nem autorizam fallback automatico de execucao no fluxo normal
- quando wrappers locais precisarem nascer do zero no setup inicial da pasta paralela da KB, preferir adaptar os exemplos sanitizados completos da base como bootstrap tecnico, em vez de improvisar wrappers curtos ou parciais
- quando a sessao ja publicar o caminho de uma skill ou de seus exemplos, usar esse caminho publicado como referencia autoritativa; nao inferir caminho alternativo por heuristica

## Regra de leitura para runtime

- quando a pergunta envolver `Base Table`, `Extended Table`, navegacao, `For each`, `Load`, `Refresh`, `Refresh Grid` ou risco de performance, consultar primeiro `02-regras-operacionais-e-runtime.md`
- quando a pergunta envolver apenas estrutura XML observada, priorizar `01-base-empirica-geral.md` como indice e descer ao arquivo empirico mais aderente da serie `01`
- quando a pergunta misturar estrutura e comportamento provavel, responder separando explicitamente `Evidência direta`, `Regra documentada`, `Inferência forte` e `Hipótese`
- quando a pergunta envolver `sync` ou wrappers locais da pasta paralela da KB, distinguir explicitamente:
  - capacidade ja disponivel na base compartilhada
  - exposicao dessa capacidade no wrapper local
  - decisao local do usuario/equipe sobre atualizar ou nao o wrapper

## Regra de leitura para campos derivados

- nome de atributo calculado ou derivado nao prova semantica funcional
- quando filtro, regra de negocio ou interpretacao depender de campo derivado, a formula e a cadeia imediata de chamadas prevalecem sobre nome, caption ou intuicao
- filtro de negocio sobre campo derivado exige validar a formula antes da proposta
- se a formula chamar `Procedure`, a leitura deve seguir pelo menos a cadeia imediata necessaria para justificar o significado funcional do campo

## Regra de uso do KB Intelligence

- quando o objetivo principal for triagem por indice derivado para decidir por onde comecar na KB, preferir a skill `xpz-index-triage`
- quando uma pasta paralela de KB expuser `KbIntelligence\kb-intelligence.sqlite`, o agente deve usar o indice para triagem tecnica antes de alterar objetos GeneXus cobertos pelo contrato da Fase 3
- antes de confiar no indice, comparar `last_index_build_run_at` na tabela `metadata` do SQLite com `last_xpz_materialization_run_at` lido nominalmente em `kb-source-metadata.md`
- quando o wrapper local expuser `index-metadata`, usar essa consulta para obter `last_index_build_run_at`; se ela falhar, retornar vazio ou nao trouxer timestamp, tratar o indice como sem metadado valido e oferecer regeneracao/validacao antes de seguir
- se `kb-source-metadata.md` estiver ausente ou nao expuser literalmente `last_xpz_materialization_run_at`, tratar a pasta paralela como defasada/incompatível e oferecer atualizacao via `xpz-kb-parallel-setup`; nao inferir esse horario por data do arquivo, `updated`, `generated_at`, `source_xpz` ou outro campo aproximado
- se `last_index_build_run_at` for igual ou posterior a `last_xpz_materialization_run_at`, o indice esta apto para triagem inicial
- se `AGENTS.md` ou `README.md` locais declararem timestamps, estado operacional ou observacoes de frescor, comparar esses campos com `kb-source-metadata.md`, com `index-metadata` e com o gate efetivo; se houver drift, tratar isso como memoria local desatualizada da pasta paralela e nao como detalhe irrelevante
- quando a validacao de frescor/compatibilidade tiver sido relevante para liberar ou bloquear a resposta, declarar brevemente no handoff se o gate foi liberado (`last_index_build_run_at >= last_xpz_materialization_run_at`) ou qual campo/capacidade bloqueou
- todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize XMLs oficiais em `ObjetosDaKbEmXml` deve chamar a regeneracao/validacao do indice derivado logo depois
- antes de sugerir ou executar `sync` normal em pasta que adota `KbIntelligence`, o agente deve ter evidencia clara, na documentacao local ou no proprio wrapper local, de que o wrapper de materializacao encadeia esse refresh compulsorio do indice
- na ausencia dessa evidencia clara, tratar a pasta paralela como compatibilidade pendente e oferecer atualizacao via `xpz-kb-parallel-setup` antes do `sync`
- se o wrapper local de materializacao ainda nao encadear esse refresh, nao usar esse wrapper antigo para reparar metadado e regenerar indice manualmente; bloquear e oferecer atualizacao via `xpz-kb-parallel-setup`
- nao descrever `sync` seguido de rebuild manual separado do indice como fluxo normal quando a pasta paralela adotar `KbIntelligence`
- se o indice estiver ausente, sem metadado, mais antigo que a ultima materializacao XPZ/XML, ou se `kb-source-metadata.md` estiver ausente, o agente nao deve consultar o acervo oficial de objetos para responder negocio, nem por varredura ampla nem por caminho pontual deduzido, nem gerar objetos para importacao na KB pela IDE; deve tratar isso como excecao operacional e oferecer ao usuario a regeneracao/validacao do indice antes de seguir
- com gate de indice bloqueado, leitura pontual so e aceitavel para diagnostico minimo da incompatibilidade em documentacao local, estrutura, wrappers e metadados operacionais; nao montar, testar existencia, listar ou abrir caminho de XML oficial de objeto como fallback para responder a pergunta
- o gate do indice deve ser sequencial e atomico; nao testar caminho filho antes da camada pai, por exemplo `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- se o wrapper local documentado de consulta do indice estiver ausente, nao listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup
- a triagem operacional deve consultar `object-info`, `who-uses`, `what-uses` e `show-evidence`, ou `impact-basic` quando esse comando estiver disponivel
- `impact-basic` e a triagem equivalente representam impacto tecnico direto baseado no indice; nao provam impacto runtime completo
- `functional-trace-basic`, quando disponivel, pode empacotar a coleta inicial de triagem funcional, mas nao abre XML automaticamente, nao interpreta regra de negocio e nao substitui a resposta classificada do agente
- o indice nao substitui `ObjetosDaKbEmXml`, que continua sendo a fonte normativa e somente leitura
- se a mudanca exigir semantica GeneXus, o agente deve abrir o XML oficial e revisar o trecho relevante antes de concluir
- quando a pergunta for funcional e a trilha estiver na Fase 6, o agente deve usar o indice apenas para orientar a ordem de leitura, separando explicitamente `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- ao validar artefatos do KB Intelligence, escolher o executor pelo formato do caso, nao pelo nome da fase:
  - casos com `source`, `target` e `expected_rule` pertencem a validacao de extracao/geracao e devem rodar com `Build-KbIntelligenceIndex.ps1 -ValidationCasesPath`
  - casos com `query` pertencem a validacao de consulta e devem rodar com `Test-KbIntelligenceQueries.ps1 -ValidationCasesPath`
- se um caso de relacao com `expected_rule` for enviado ao validador de consultas, tratar o erro como uso de executor incompatível antes de concluir regressao real

## Regra de triagem exploratoria

- quando a frente exigir decidir se existe massa suficiente para abrir novo incremento, priorizar triagem exploratoria curta e auditavel antes de propor alteracao metodologica ou de codigo
- em Windows, preferir consultas pequenas e separadas no PowerShell, em vez de one-liner longo com muitas interpolacoes, regexes e transformacoes na mesma linha
- a ordem recomendada e: contagem bruta, agrupamento por sinal relevante, amostra curta de casos reais positivos e negativos
- nao propor novo incremento apenas por ocorrencia textual bruta; confirmar antes se o padrao observado tem resolucao estrutural segura no acervo
- quando a consulta falhar por sintaxe ou ficar ruidosa demais para leitura direta, simplificar a abordagem e refazer em etapas menores
- quando a hipotese depender de fechar regra nova, contrato novo ou ampliacao metodologica, extrair antes casos reais positivos e negativos do acervo; contagem sozinha nao basta para sustentar decisao
- quando busca, agrupamento ou regex retornarem zero de forma inesperada, validar primeiro uma ocorrencia real do XML no acervo antes de concluir ausencia de sinal ou trocar a hipotese

## Regra de leitura para compatibilidade de `Source`

- `Source` que parece GeneXus valido nao prova compatibilidade operacional
- operador, funcao, conversao ou padrao string/numerico novo so pode ser aceito como pronto quando a propria trilha XPZ o sustentar por regra explicita, exemplo sanitizado ou molde documentado
- corpus local da KB ajuda a confirmar e desempatar, mas nao substitui a base metodologica
- se um trecho essencial do `Source` continuar sustentado apenas por plausibilidade, o agente deve reescrever para padrao documentado ou abortar a consolidacao
- antes de empacotar, separar explicitamente duas decisoes: `XML bem-formado` e `objeto provavelmente importavel`
- `XML bem-formado` nao dispensa gate de sanidade do `Source` quando o objeto depende de `Source` para importar com seguranca conservadora
- o gate minimo de sanidade do `Source` deve revisar os pares estruturais realmente tocados pela mudanca, como `Sub/EndSub`, `For each/EndFor`, `Do Case/EndCase` e `If/EndIf`
- se a mudanca inserir novo `Case` em um `Do Case` de `Source` que dependa materialmente de `parm(...)`, revisar os `Case` irmaos do mesmo bloco antes de concluir a compatibilidade
- nessa revisao de `Do Case`, conferir se os parametros de entrada relevantes, esperados pelo padrao local do bloco, aparecem de forma coerente no novo ramo; ausencia de parametro comparavelmente esperado exige justificativa explicita
- se o novo `Case` divergir do padrao local dos ramos irmaos sem justificativa explicita, bloquear a consolidacao em vez de aceitar branch hardcoded ou sustentado apenas por analogia fraca
- se o trecho novo introduzir `elseif`, `iif(...)`, condicao excessivamente densa ou chamada em condicao destoando do estilo local, tratar isso como alerta consultivo e preferir reescrita para forma conservadora documentada
- quando houver cheque automatizado leve de `Source`, interpretar o resultado de forma conservadora:
- `xmlWellFormed=false` bloqueia qualquer conversa de empacotamento ate correcao do XML
- `sourceSanityStatus=fail` bloqueia empacotamento ate corrigir balanceamento estrutural e fechamentos
- `sourceSanityStatus=warn` com `probablyImportable=true` ainda exige revisao dos warnings; nao tratar como liberacao automatica
- `sourceSanityStatus=pass` com `xmlWellFormed=true` libera apenas o proximo gate metodologico; nao prova importacao, especificacao nem build
- ao revisar `Source` grande, a leitura deve considerar o contorno visual do bloco afetado, e comentarios estruturais humanos ja existentes podem ser preservados quando ajudam a navegacao do trecho
- em `Procedure Source`, pares como `count/then-copy`, `exists/then-load`, `validate/then-apply` e `select-candidate/then-materialize` devem ser revisados como unidade logica quando compartilham a mesma tabela/base e identidade candidata
- se a mudanca altera filtros de identidade, unicidade ou ambiguidade em um `for each`, buscar queries irmas no mesmo `Source` e reconciliar os criterios ou justificar explicitamente a divergencia
- ao citar uma linha de XML GeneXus, classificar o trecho como `Source efetivo`, `Rules/parm`, `metadado XML`, `chamada no chamador` ou `assinatura no chamado`
- para afirmar que uma `Procedure` A chama uma `Procedure` B, a evidencia deve estar no `Source` efetivo de A, na linha da chamada a B; o `parm(...)` de B prova assinatura do chamado, nao ponto de chamada
- em cadeia de chamadas, separar sempre arquivo/linha do chamador e arquivo/linha da assinatura do chamado

### Regra adicional para `Procedure` de relatorio

- em relatorio simples, `Source` deve ser validado junto com a camada onde cada sintoma nasceu: `Source`, `Rules` ou layout
- `Output_file`, `Header`, `Footer`, `For each` e `print printBlock...` pertencem ao `Source`
- `parm(...)` pertence a `Rules`
- `Bands`, `PrintBlock`, `ReportLabel` e `ReportAttribute` pertencem ao layout `Part c414ed00-8cc4-4f44-8820-4baf93547173`
- se o erro mencionar `;` em regra, revisar `Rules` antes de reabrir layout
- se o erro mencionar controle invalido, `printBlock` ou shape de relatorio, revisar layout antes de inferir defeito de envelope
- se a solucao continuar sustentada so por plausibilidade depois de uma rodada corretiva, parar e escalar para XML real comparavel

### Protocolo geral de revisao por blocos

- em tipos heterogeneos cobertos por esta base, declarar o `bloco primario` antes da analise fina
- `bloco adjacente` e apenas o bloco adicional aberto por dependencia funcional explicita com o `bloco primario`
- nomear toda `transicao justificada` no raciocinio e no handoff
- usar como `criterio de parada` o ponto em que a hipotese ja estiver sustentada; nao reabrir o objeto inteiro por reflexo
- declarar o `escopo da conclusao` no menor nivel funcional que a evidencia sustenta; quando houver mais de um contexto de execucao relevante, explicitar tambem esse contexto

### Regra adicional para revisao de `Procedure`

- em `Procedure`, revisar por blocos funcionais; nao presumir `Source` como bloco inicial universal
- os blocos canonicos sao `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container` e, quando aplicavel, `Report layout`
- antes da analise fina, declarar qual e o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Rules/parm -> Variables` para validar contrato de parametros
- parar a expansao quando a hipotese ja estiver sustentada; nao reabrir a `Procedure` inteira por reflexo
- usar `Source` como bloco inicial para filtros, fluxo procedural, navegacao, atribuicoes, condicoes e chamadas feitas no corpo
- usar `Rules/parm` como bloco inicial para assinatura, parametros, direcao do contrato e erro claramente ligado a regra
- usar `Variables` como bloco inicial para existencia, tipo, helper novo, coerencia de nome e colecao vs simples
- usar `Calls and dependencies` como bloco inicial para cadeia de chamadas, objeto chamado, dependencia externa e prova de call site
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem
- usar `Report layout` como bloco inicial apenas em `Procedure` de relatorio quando o sintoma falar de `PrintBlock`, `ReportLabel`, `ReportAttribute`, `Bands` ou shape de layout

### Regra adicional para revisao de `Transaction`

- em `Transaction`, revisar por blocos funcionais; nao tratar a transacao inteira como bloco unico de leitura
- os blocos canonicos sao `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context` e `Identity and container`
- antes da analise fina, declarar qual e o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Rules -> Execution context` para separar efeito via edicao web de efeito via BC
- parar a expansao quando a hipotese ja estiver sustentada; nao reabrir a `Transaction` inteira por reflexo
- usar `Transaction structure` como bloco inicial para `Level`, chave, `DescriptionAttribute`, shape estrutural e composicao transacional
- usar `Attributes and attribute properties` como bloco inicial para atributos, `AttributeProperties`, subtipo e contrato de dados
- usar `Rules` como bloco inicial para regra declarativa, obrigatoriedade e efeito normativo da transacao
- usar `Events` como bloco inicial para comportamento via interface, acao do usuario e fluxo via edicao web
- usar `Execution context` como bloco inicial quando a duvida central for a diferenca entre via edicao web e via BC
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem

### Regra adicional para revisao de `WebPanel`

- em `WebPanel`, revisar por blocos funcionais; nao abrir o XML inteiro como massa unica quando a pergunta for de comportamento, filtro, evento ou diagnostico fino
- os blocos canonicos sao `layout`, `events`, `variables`, `metadado funcional serializado`, `identidade e contêiner` e `dependencias`
- antes da analise fina, declarar qual e o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `events -> variables` para validar contrato local
- parar a expansao quando a hipotese ja estiver sustentada; nao reabrir o objeto inteiro por reflexo
- tratar `metadado funcional serializado` como camada propria; ele pode viver perto do layout, mas nao deve ser lido como decoracao visual
- usar `events` como bloco inicial para acoes do usuario, refresh, start, load, chamadas e validacao procedural
- usar `layout` como bloco inicial para composicao visual, estrutura de grid/tab/controle e bindings visiveis
- usar `variables` como bloco inicial para tipo, declaracao, coerencia de uso e colecao vs simples
- usar `metadado funcional serializado` como bloco inicial para `Conditions`, `ControlWhere`, `ControlBaseTable`, `ControlOrder`, `ControlUnique`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, `WebUserControlProperties` e marcas de pattern
- usar `identidade e contêiner` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, risco de clonagem e classificacao estrutural
- usar `dependencias` como bloco inicial quando o sintoma nascer de `MasterPage`, pattern, user control, objeto chamado ou vinculo externo ausente

## Regra de leitura para XPZ

- antes de usar `xpz-sync`, `xpz-builder` ou `xpz-doc-builder` em fluxo dependente de repositorio, confirmar que a pasta paralela da KB esta montada e validada; se nao estiver, usar `xpz-kb-parallel-setup` primeiro
- quando a tarefa envolver montar ou serializar `XPZ`, consultar primeiro a secao `Envelope XPZ observado em export real` de `02-regras-operacionais-e-runtime.md`
- distinguir sempre a pasta nativa da KB da pasta paralela da KB; nesta trilha, os `XPZ`, os XMLs materializados e os artefatos de importacao vivem na pasta paralela da KB, nao dentro da pasta nativa da KB
- tratar a pasta nativa da KB como area proibida para gravacao por agentes; leitura e permitida apenas quando o fluxo operacional explicito realmente exigir
- em setup inicial padrao de pasta paralela da KB, com pasta nativa ja informada, sem nomes alternativos e sem conflito estrutural visivel, evitar exploracao ampla do motor compartilhado e dos exemplos antes de criar a estrutura base; aprofundar exploracao so se surgir bloqueio concreto
- quando a inspecao local da pasta contradisser contexto indireto do ambiente, da sessao ou de hooks, confiar primeiro na inspecao local e seguir com verificacao curta e objetiva; nao gastar o handoff especulando longamente sobre o conflito
- quando a tarefa envolver gerar, ajustar, preservar ou empacotar XMLs, distinguir explicitamente as tres areas operacionais do repositorio: `ObjetosDaKbEmXml`, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus`
- na carga inicial, considerar tambem `XpzExportadosPelaIDE` como pasta de entrada padrão, `scripts` como pasta de wrappers, `Temp` como destino preferencial de artefatos efemeros de execucao, `KbIntelligence` como pasta do indice derivado, e as demais pastas como estrutura funcional padrão quando o usuario nao informar nomes alternativos
- se alguma dessas pastas ainda nao existir, criar nesta ordem: `scripts`, `Temp`, `XpzExportadosPelaIDE`, `ObjetosDaKbEmXml`, `KbIntelligence`, `ObjetosGeradosParaImportacaoNaKbNoGenexus`, `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando a pasta paralela ja estiver versionada em Git e o setup inicial estiver criando a estrutura do zero, tratar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte esperada do bootstrap
- quando a pasta paralela ainda nao estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional; nao deve executar `git init` sem aprovacao explicita do usuario
- se o usuario aceitar versionamento Git local e o Git nao estiver funcional no ambiente, o agente pode oferecer instalar ou orientar a instalacao antes do bootstrap Git
- mudar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisao de politica do repositorio; o agente pode diagnosticar e propor opcoes, mas nao deve alterar essa politica automaticamente so para concluir o fechamento
- se o setup inicial da pasta paralela da KB estiver sendo preparado e o caminho da pasta nativa da KB nao vier no prompt, pedir esse caminho ao usuario antes de concluir o setup
- no setup inicial, gerar `kb-source-metadata.md` inicial em formato compativel com o motor compartilhado, preservando o campo nominal `last_xpz_materialization_run_at`
- no setup inicial, nao salvar memoria operacional fora da propria pasta paralela da KB sem autorizacao explicita do usuario; `AGENTS.md`, `README.md` e arquivos operacionais locais sao a camada preferencial de memoria
- no setup inicial da pasta paralela da KB, nao declarar `setup concluido`, `estrutura pronta` ou equivalente final antes de a camada minima de wrappers locais esperados em `scripts` existir para o fluxo oficial adotado
- se a estrutura de pastas e documentos estiver pronta, mas a camada minima de wrappers locais ainda nao existir, o status correto e `estrutura parcial` ou `bootstrap incompleto`, nao `setup concluido`
- `Test-*KbSourceSanity.ps1` e wrapper recomendado quando a pasta tambem adotar fluxo local de geracao e empacotamento; sua ausencia isolada nao impede, por si so, reconhecer a camada minima do fluxo oficial de materializacao ou de `KbIntelligence`
- se o setup inicial registrar memoria local provisoria como `ObjetosDaKbEmXml ainda nao materializada`, `aguardando primeiro XPZ` ou equivalente, esse estado precisa ser atualizado ou neutralizado depois da primeira materializacao oficial bem-sucedida
- se `XpzExportadosPelaIDE` ainda nao existir, perguntar onde o usuario quer salvar os `.xpz`
- se `ObjetosDaKbEmXml` ainda nao existir, tratar a KB como ainda nao materializada e parar antes de assumir snapshot
- se `KbIntelligence` ainda nao existir, tratar isso como ausencia da camada derivada de triagem, nao como ausencia do snapshot oficial; preparar a pasta e os wrappers locais antes de depender de `xpz-index-triage`
- nesta trilha, `ObjetosDaKbEmXml` e snapshot oficial e somente leitura para agentes
- nesta trilha, `KbIntelligence\kb-intelligence.sqlite` e indice derivado e regeneravel a partir de `ObjetosDaKbEmXml`
- nesta trilha, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e a area de trabalho para XMLs a importar manualmente na IDE
- nesta trilha, cada frente ativa deve usar sua propria subpasta `NomeCurto_GUID_YYYYMMDD` dentro de `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- nesta trilha, os arquivos ativos do lote devem ficar dentro da subpasta ativa da frente, e nao soltos na raiz da area de trabalho
- nesta trilha, `PacotesGeradosParaImportacaoNaKbNoGenexus` e a area de saida para pacotes gerados localmente
- por padrao, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` nao precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteudo, tratar isso como decisao de politica do repositorio e pedir aprovacao explicita
- nesta trilha, a promocao para snapshot oficial ocorre apenas pelo script `.ps1` alimentado por `XPZ` exportado pela IDE
- ao concluir o setup inicial da pasta paralela da KB, deixar explicito que a estrutura esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
- se `Test-*KbSourceSanity.ps1` for criado ou atualizado durante a frente, valida-lo diretamente antes do fechamento; `STRUCTURE_OK` e `GATE_OK` nao bastam como prova desse wrapper, porque o checklist estrutural canonico nao o trata como minimo universal
- ao concluir o setup inicial, oferecer dois proximos passos: `A)` o usuario exporta o `.xpz` full pela IDE para `XpzExportadosPelaIDE`; `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava o arquivo em `XpzExportadosPelaIDE` e depois materializa os XMLs
- ao oferecer `A)` e `B)`, declarar que `A)` e o caminho preferencial e normalmente mais rapido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
- ao orientar o caminho `A)`, preferir descricao funcional estavel como `export full da KB pela IDE` em vez de depender de rotulos exatos de menu, tela ou botao do GeneXus como se fossem universais; se citar caminho de menu, apresentá-lo depois da instrucao principal e marcado explicitamente como exemplo opcional de navegacao, nunca como passo normativo principal
- se o usuario escolher `B)`, usar a skill `xpz-msbuild-import-export` e nao improvisar exportacao fora dessa trilha
- quando a skill de `MSBuild` for publicada por symlink, junction ou outro reparse point, resolver referencias `../` pela pasta real da skill, nao pelo caminho launcher publicado
- ao concluir a exportacao headless do caminho `B)`, declarar explicitamente o marco `XPZ gerado` antes de prosseguir para materializacao em `ObjetosDaKbEmXml`
- se o pedido do usuario for apenas gerar o `.xpz`, parar no artefato gerado; so prosseguir para materializacao quando o pedido for seguir com o setup ou com a materializacao
- em handoff de pasta paralela da KB, declarar marcos operacionais separados, sem colapsar um no outro:
  - `setup de estrutura`: pastas e memoria local basica foram criadas ou validadas
  - `bootstrap de wrappers`: wrappers locais minimos existem e sao compativeis com o fluxo oficial adotado
  - `XPZ gerado`: artefato `.xpz` existe em `XpzExportadosPelaIDE` ou no destino aprovado, mas ainda nao implica materializacao
  - `materializacao em ObjetosDaKbEmXml`: XMLs oficiais foram criados/atualizados pelo fluxo oficial a partir do `XPZ`
  - `refresh/validacao do indice`: `KbIntelligence` foi regenerado/validado e tem `last_index_build_run_at >= last_xpz_materialization_run_at`
  - `conferencia full`: verificacao posterior do acervo, que nao substitui nem deve sobrescrever o relatorio da materializacao principal
- `XPZ` full define o insumo exportado; `FullSnapshot` define modo adicional de verificacao do acervo
- na materializacao normal do `XPZ` em `ObjetosDaKbEmXml`, inclusive na primeira carga por `XPZ` full vindo da IDE ou por export headless via `MSBuild`, nao presumir `-FullSnapshot` como padrao implicito nem como atalho ergonomico
- usar `-FullSnapshot` apenas quando houver pedido explicito do usuario por conferencia full, quando o wrapper especifico de conferencia full for o caminho escolhido ou quando a documentacao local exigir isso nominalmente
- quando o resumo do sync expuser `MaterializationInterpretation`, preferir esse campo para explicar o resultado da materializacao; nao reinventar a leitura a partir de `Created`, `Updated` e `Unchanged`
- nao afirmar `primeira carga`, `primeira materializacao` ou equivalente quando `Created = 0` e `Unchanged > 0`; sem evidencia previa adicional, isso indica apenas confirmacao de snapshot ja existente contra o insumo atual
- se houver relatorio da primeira materializacao e outro de reprocessamento confirmatorio ou conferencia full, nao misturar os papeis no handoff; identificar explicitamente qual arquivo representa a materializacao que criou/atualizou o acervo e qual arquivo representa apenas verificacao posterior
- se a execucao tiver primeira materializacao seguida de reprocessamento confirmatorio ou conferencia full, preferir caminhos ou nomes de relatorio separados; nao sobrescrever silenciosamente o relatorio principal da primeira materializacao com o da segunda passagem
- so afirmar metadado especifico de `kb-source-metadata.md`, como versao do GeneXus, build, GUID da KB, usuario ou caminho `Source`, quando esse metadado tiver aparecido explicitamente na saida real do wrapper ou quando o proprio `kb-source-metadata.md` tiver sido aberto e lido nominalmente na rodada atual
- nao presumir `Objects.xml` isolado nem manifesto externo separado se isso nao estiver documentado no `02`
- usar o envelope sanitizado documentado na base como referencia estrutural antes de pedir XML externo adicional
- depois da bateria de importacao e da consulta ao acervo real, separar explicitamente `problema de envelope`, `problema de shape minimo` e `problema de dependencia da KB`
- se existir export real comparavel da IDE para a mesma composicao de objetos, esse export deve prevalecer sobre envelope leve hipotetico
- em pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir pacote embutido comparavel antes de tentar envelope por `FilePath`
- se houver mais de um lote plausivel no workspace, o agente deve parar antes de empacotar e sinalizar contaminacao de workspace
- o agente nao deve fechar pacote por inferencia, por recencia presumida ou por mistura implícita de frentes
- o agente deve distinguir explicitamente `mesmo objeto` de `mesma frente`
- reusar precedente estrutural de pacote nao autoriza herdar automaticamente a identidade nominal da frente anterior
- quando a continuidade da frente nao estiver fechada por evidencia direta ou confirmacao explicita do usuario, o agente deve explicitar a ambiguidade antes de nomear pasta ou pacote
- se um `XPZ` oficial vindo da KB trouxer objetos adicionais alem do foco imediato da frente, o agente deve informar o inesperado sem presumir erro; isso pode ser mudanca paralela legitima feita diretamente na IDE do GeneXus
- o agente deve distinguir explicitamente `artefato da frente atual`, `mudanca paralela legitima vinda da KB/IDE` e `mudanca lateral indevida do proprio agente fora do escopo`
- quando houver contexto esperado da frente, o agente pode comparar opcionalmente `foco esperado` versus `retorno oficial`, classificando `esperados que voltaram`, `esperados que nao voltaram` e `retorno oficial adicional da KB`, sem transformar a ausencia desse contexto em erro
- frente validada tecnicamente nao implica publicacao Git; a conclusao tecnica e apenas `validado_tecnicamente` ate o usuario autorizar o fechamento
- enquanto nao houver autorizacao explicita, o agente pode sugerir os proximos passos de Git e publicacao, mas nao pode executar `git add`, `commit` ou `push`
- a ordem obrigatoria e: isolar lote, classificar raizes, validar `lastUpdate`, validar BOM, validar manifesto, validar `XML bem-formado`, validar sanidade minima do `Source` quando aplicavel, e so entao empacotar
- manifesto nao implica automaticamente arquivo fisico; por padrao, ele deve ser apresentado na propria conversa
- para `WorkWithWeb` com ruído comprovado de `Load Code` em `Selection` e/ou tabs de `View`, registrar isso como nao funcional no manifesto e nao generalizar para todo caso de `WorkWithWeb`
- ao gerar pacote local para importacao na IDE, preferir nome no formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- nesse formato, `NomeCurto` identifica a frente, `GUID` e `YYYYMMDD` identificam a abertura da frente, e `nn` representa apenas a rodada curta daquela frente
- antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar se ja existe pacote com o mesmo prefixo `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn` em `PacotesGeradosParaImportacaoNaKbNoGenexus`
- se o mesmo prefixo e o mesmo `nn` ja existirem, abortar a gravacao; nao sobrescrever silenciosamente a rodada
- quando houver colisao de `nn`, retornar erro explicito com sugestao do proximo `nn` livre para aquela frente, sem autoincrementar nem gravar automaticamente com o valor sugerido
- `OBSOLETO_` nao e convencao principal de nome; usar so como contencao de risco quando dois pacotes da mesma frente puderem ser confundidos

## Regra de leitura para XPZ via MSBuild

- quando a frente envolver `MSBuild` headless, consultar primeiro o plano e a skill experimental correspondente antes de presumir suporte de parametros da task `Import`
- tratar `UpdateFile` e `ImportKBInformation` como capacidades dependentes da assinatura real da task carregada, nao apenas da documentacao offline
- se a instalacao expuser `PreviewMode`, `IncludeItems` e `ExcludeItems`, priorizar esses caminhos para inspecao controlada antes de qualquer importacao real
- quando `IncludeItems` ou `ExcludeItems` vierem com multiplos recortes, normalizar a entrada como lista e serializar em formato de lista aceito pela task carregada; nao presumir que uma string unica separada por virgulas sera aceita como um unico item
- se o wrapper devolver diagnostico estruturado, manter `importedItems` sempre como lista, inclusive com item unico
- em resposta ao usuario, separar explicitamente `sucesso operacional da chamada MSBuild`, `preview sem alteracao real da KB` e `confirmacao funcional pendente na IDE oficial`

## Regra de leitura para logs de importacao

- log de importacao deve ser lido por etapa e por categoria de falha
- erro lateral da IDE nao prova falha de pacote
- pacote aceito com falha posterior de `Source` ou `Specification` nao deve ser descrito como falha de envelope
- se houver sucesso parcial, o agente deve dizer explicitamente que o resultado foi parcial
- quando houver pacote corretivo apos falha parcial, relatar pacote original, objetos importados, objetos falhos e pacote corretivo minimo contendo apenas o delta necessario
- a conclusao final deve seguir a etapa terminal relevante do log, nao a linha mais alarmante
- quando recortes sucessivos reduzirem o ruido e o log passar a destacar referencia nao resolvida em objeto importado, tratar o caso como frente de conteudo da KB/`XPZ`, nao como defeito residual do wrapper, salvo evidencia contraria

## Regra de identificação de objetos por tipo

- ao mencionar, localizar ou operar sobre qualquer objeto GeneXus, sempre informar tipo e nome em conjunto — nunca so o nome
- o tipo determina a pasta física no repositório; referenciar apenas o nome implica risco de busca na pasta errada
- o mesmo nome pode existir em tipos distintos ao mesmo tempo na mesma KB; coincidência de nome nao prova unicidade nem identidade do objeto
- antes de qualquer operação sobre um objeto (leitura, edição, empacotamento, referência em manifesto, sincronização XPZ), confirmar explicitamente a pasta onde o arquivo existe no repositório
- nao inferir tipo, pasta ou identidade do objeto apenas pelo contexto da conversa, por hábito ou por analogia
- se o tipo não for conhecido com certeza, inspecionar o repositório antes de assumir qualquer pasta

## Precedencia das heuristicas

- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar cautela runtime, o agente nao pode responder com linguagem otimista
- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar `exigir molde`, isso prevalece sobre entusiasmo estrutural, frequencia amostral ou similaridade superficial
- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar `abortar`, o agente deve abortar de forma clara, explicando o sinal estrutural e o limite metodologico
- quando houver choque entre “parece estruturalmente simples” e “runtime sensivel”, prevalece a leitura mais conservadora

## Quando responder com mais confiança

- quando a pergunta for descritiva e estiver diretamente sustentada pelos XMLs ou tabelas empíricas
- quando a resposta puder ser classificada como `Evidência direta`
- quando o tipo alvo já estiver bem mapeado por frequência e exemplos comparáveis

## Quando responder com cautela

- quando a conclusão depender de frequência recorrente, mas sem teste externo
- quando a amostra do tipo for pequena
- quando a resposta tocar em edição segura, obrigatoriedade real, importação ou build
- quando o tipo depender de `ATTCUSTOMTYPE`, `pattern` registrado, classe visual pai, package importado, atributo real ou objeto pai existente
- quando a conclusao depender da semantica de atributo calculado, formula, status derivado ou procedure compartilhada ainda nao revisada

## Quando recusar geração de XPZ

- quando faltar molde XML completo suficientemente próximo
- quando o tipo estiver em risco `alto` ou `muito alto` sem contexto equivalente, exceto nos fluxos ja destravados de `Transaction` e `WebPanel`
- quando houver `pattern`, `parent` ou bloco raro ainda não compreendido
- quando a pergunta exigir afirmar sucesso de importação/build sem evidência externa
- quando a montagem depender de gerar bloco especial de KB (`KnowledgeBase`, `Settings` ou elemento top-level com nome da KB)

## Regra de decisão entre gerar, exigir molde ou abortar

### Gerar por clonagem conservadora

- apenas em cenário muito controlado
- apenas com molde do mesmo tipo e contexto estrutural comparável
- apenas preservando `Object/@type`, `parent*`, `moduleGuid` e `Part type` recorrentes
- para `Transaction`, usar familia estrutural inferida da propria base
- para `WebPanel`, usar familia estrutural inferida e molde interno muito proximo
- para `Theme`, preservar tambem o conjunto minimo de classes visuais efetivamente referenciadas entre si
- para `API`, copiar apenas `ATTCUSTOMTYPE` comprovado e somente quando o tipo correspondente existir no alvo
- para `WorkWithForWeb`, usar o convenio estrutural real de atributo do pattern `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`

### Exigir molde bruto comparável

- quando o tipo estiver em cautela alta
- quando a amostra for pequena
- quando o objeto depender de contexto estrutural explícito
- `Transaction` nao deve mais exigir molde externo
- `WebPanel` deve operar por familia estrutural e molde interno proximo
- `Attribute` ja tem shape top-level provado, mas ainda deve exigir filtro cuidadoso para nao confundir definicao real com referencia inline de `Transaction`
- `PatternSettings` deve exigir pattern registrado e contexto equivalente; o XML sozinho nao fecha o comportamento
- `API` deve exigir, como regra preferencial, um recorte funcional comparavel contendo tambem `Procedure`, `SDT`, `Domain` e, quando o caso pedir, `Transaction`, `Table` e `DataProvider`

### Abortar

- quando o molde não for comparável
- quando a mudança exigir mexer em blocos opacos ou raros
- quando a solicitação pressuponha algo que a base não prova

## Frases que um agente deve evitar

- “isso certamente importa”
- “isso é obrigatório” sem base comparativa explícita
- “pode gerar tranquilo”
- “vai buildar”
- “é seguro editar” sem qualificação de risco e nível de evidência
- “o nome do campo deixa claro” quando o campo for calculado ou derivado
- “o XML esta valido, entao a regra esta certa”
- “parece GeneXus valido, entao deve importar”
- “o corpus local tem algo parecido, entao basta”
- “o Source esta plausivel”

## Tipos em maior cautela

- `Transaction`
- `WebPanel`
- `WorkWithForWeb`
- `Procedure`
- `Panel`
- `DataProvider`

## Tipos que ainda pedem molde bruto muito próximo

- todos os tipos em risco `alto` ou `muito alto`, exceto os fluxos operacionais ja destravados para `Transaction` e `WebPanel`
- `DesignSystem`, por amostra pequena
- `SDT`, quando a estrutura pai for relevante
- `Theme` e `PackagedModule`, mesmo sendo candidatos relativamente menos agressivos
- `Attribute`, quando houver duvida entre definicao top-level e referencia inline dentro de `Transaction`
- `API`, quando o caso concreto depender de `EXO`, `SDT` ou `Procedure` que nao existam comprovadamente no alvo
- `PatternSettings`, quando o pattern correspondente nao estiver registrado no ambiente

## Decisao operacional atual para Transaction e WebPanel

- Evidência direta: a base contem 183 `Transaction` e 1196 `WebPanel`.
- Inferência forte: esse volume e suficiente para que um agente GPT tente execucao controlada em vez de apenas bloquear por falta de evidencia.
- Inferência forte: `Transaction` pode seguir por padrao estrutural inferido e molde interno da propria base.
- Inferência forte: `WebPanel` pode seguir por familia estrutural, desde que o molde interno seja cuidadosamente escolhido.
- Inferência forte: nao pedir mais exemplos para esses tipos deixa de ser regra geral; so faz sentido pedir novos exemplos quando o caso concreto continuar estruturalmente ambiguo.
- Hipótese: se a importacao falhar, o caso deve voltar como insumo para evoluir a propria base documental.

## Fórmula de resposta recomendada

1. classificar a afirmação como `Evidência direta`, `Inferência forte` ou `Hipótese`
2. citar o arquivo-base usado
3. declarar a limitação
4. recomendar próximo passo conservador

## Regras de materializacao

- Evidência direta: ao gerar `Transaction` ou `WebPanel`, o agente deve partir de um molde XML completo
- Evidência direta: o agente nao deve materializar objeto final a partir de resumo textual sem XML completo
- Regra operacional: antes de empacotar, classificar cada XML ativo como `alterado na rodada` ou `reenviado sem mudanca por dependencia obrigatoria`
- Regra operacional: se o objeto foi realmente alterado na rodada, o `lastUpdate` deve refletir o instante real da ultima gravacao
- Regra operacional: se o objeto entrou apenas por dependencia obrigatoria ou composicao minima do pacote, o `lastUpdate` oficial anterior deve ser preservado
- Regra operacional: o agente deve abortar o empacotamento quando houver divergencia entre a classificacao do item e o `lastUpdate` materializado
- Regra operacional: antes de serializar o pacote, classificar as raizes top-level em `Object`, `Attribute` ou `outro tipo`
- Regra operacional: `Object` top-level entra em `<Objects>` e `Attribute` top-level entra em `<Attributes>`
- Regra operacional: em pacote de `Transaction` nova, os atributos referenciados no `Level` devem entrar em `<Attributes>` quando o pacote precisar cria-los ou fornece-los ao destino; nao serializar esses atributos como `Domain` ou outro objeto em `<Objects>`
- Regra operacional: raiz top-level nao suportada deve bloquear o empacotamento ate tratamento explicito
- Regra operacional: XML gerado localmente deve ser salvo em UTF-8 sem BOM; se houver BOM, remover e registrar a correcao
- Regra operacional: antes de gerar `import_file.xml` ou `.xpz`, produzir ou validar manifesto do lote, por padrao na propria conversa, com frente ou descricao curta do lote, origem do lote, quantidade total de XMLs, quantidade de `Objects`, quantidade de `Attributes`, lista ou resumo dos arquivos incluidos, `lastUpdate` aplicado ou preservado, pacote gerado, pacote anterior substituido quando houver e observacoes de risco ou pendencia
- Regra operacional: salvar manifesto em arquivo e comportamento excepcional e contextual; so fazer isso em incidente de processo envolvendo `ObjetosDaKbEmXml`, substituicao de pacote com rastreabilidade local util, pedido explicito do usuario ou necessidade real de retomada futura fora da conversa imediata
- Regra operacional: ao nomear o pacote local, preferir `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, evitando nome so com assunto, nome so com data/hora, descricao longa de conversa ou sobrescrita recorrente do mesmo nome
- Regra operacional: antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar colisao do mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` com o mesmo `nn` em `PacotesGeradosParaImportacaoNaKbNoGenexus`
- Regra operacional: se houver colisao do mesmo prefixo de frente com o mesmo `nn`, abortar a gravacao; nao sobrescrever silenciosamente a rodada
- Regra operacional: em caso de colisao, retornar erro explicito com sugestao do proximo `nn` livre para aquela frente, sem autoincrementar nem gravar automaticamente com o valor sugerido
- Evidência direta: identidade estrutural de objeto sob `Folder` ou `Module` deve ser decidida por exemplar comparavel da mesma KB, conferindo em conjunto `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid`
- Regra operacional: nome de `Folder` nao deve ser promovido para `fullyQualifiedName` por analogia; primeiro classificar o conteiner por `parentType`, depois seguir o padrao do exemplar comparavel
- Evidência direta: compatibilidade de `Source` deve ser decidida primeiro pela propria trilha XPZ, usando regra explicita, exemplo sanitizado ou molde documentado, mesmo quando a KB ainda tiver corpus pequeno
- Regra operacional: corpus local da KB pode confirmar ou desempatar um trecho de `Source`, mas nao substitui a base metodologica nem autoriza consolidar sintaxe apenas plausivel
- Inferência forte: para `WebPanel`, os anexos completos de `04-webpanel-familias-e-templates.md` ja podem servir como molde sanitizado documentado
- Inferência forte: para `Transaction`, `05-transaction-familias-e-templates.md` ja contem moldes sanitizados completos para as familias `F1`, `F2`, `F5` e `F6`
- Inferência forte: para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File`, a serie `01` agora distribui moldes sanitizados completos representativos em `01e` ate `01h`
- Inferência forte: para `Procedure` de relatorio simples, `05b-procedure-relatorio-familias-e-templates.md` passa a ser a referencia primaria de molde sanitizado canonico para familias `F2` e `F3`, mas somente nos blocos marcados como `molde pronto`
- Regra operacional: em `Procedure` de relatorio simples, nao exigir XML real da KB como primeiro passo quando o molde sanitizado canonico desta trilha ja cobrir o shape necessario
- Regra operacional: depois de uma tentativa inicial e no maximo um corretivo estrutural curto, bloquear nova iteracao por analogia e escalar para XML real comparavel
- Hipótese: para `Transaction` das familias `F3` e `F4`, continua prudente buscar molde bruto comparavel adicional se a densidade estrutural real do alvo ultrapassar o que os anexos atuais sustentam
- Evidência direta: a consulta ao acervo real mostrou que `Transaction` materializa atributos dentro do proprio `<Level>` e usa variaveis de contexto como `sdt:Context`, `sdt:TransactionContext` e `sdt:TransactionContext.Attribute`
- Evidência direta: a consulta ao acervo real mostrou que `Theme` simples valido preserva classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption`, alem de suas referencias internas
- Evidência direta: a consulta ao acervo real mostrou que `PatternSettings` embute configuracao em `CDATA` com `Pattern="..."` e referencias a procedures e contextos do pattern
- Evidência direta: a consulta ao export full trouxe exemplo real de `Attribute` top-level com raiz `<Attribute ... name="...">`, e tambem revelou referencias inline `<Attribute key="...">Nome</Attribute>` dentro de `Transaction`

### Transaction

- localizar um molde XML completo do mesmo `Object/@type` e da familia estrutural mais proxima
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, `Part type` e ordem das `Part`
- editar somente nomes, descricoes e trechos internos sustentados pelo molde usado
- preservar tambem os `<Attribute ...>` dentro de `<Level>` com nome interno preenchido, `guid`, `key` e `isNullable` quando existirem
- antes de empacotar `Transaction` nova, validar coerencia cruzada obrigatoria entre `Level` e `<Attributes>`
- cada `Level/Attribute@guid` deve existir em `<Attributes>/Attribute@guid`
- cada `Level/Attribute` por nome deve existir em `<Attributes>/Attribute@name`
- `DescriptionAttribute`, quando presente, deve apontar para atributo existente no mesmo `Level` e tambem presente em `<Attributes>`
- se qualquer item acima falhar, abortar antes do pacote final com mensagem objetiva
- pacote minimo canonico para `Transaction` nova:
  - `<Objects>` = `Transaction`
  - `<Attributes>` = atributos da `Transaction`, no minimo PK e atributo de descricao/exibicao quando usados pelo shape escolhido
  - `<Dependencies>` = apenas o que o shape realmente exigir
- `TransactionOrObject`, quando aparecer em export comparavel, pode coexistir como auxiliar em `<Objects>`, mas nao substitui a obrigatoriedade de `<Attributes>`
- erros como `Cannot convert Domain to Attribute`, `Attribute 'X' in 'Transaction Y' does not exist` e `DescriptionAttribute ... could not be found in level attributes` devem ser tratados como falha de construcao do pacote, nao como detalhe a validar depois
- verificar explicitamente se existe `WorkWithForWeb` associado e se a mudanca impacta atributos exibidos, filtros, abas ou navegacao do pattern web
- abortar se a mudanca exigir inventar atributo inexistente na KB ou tipo de contexto nao existente

### API

- copiar somente um molde XML completo do mesmo tipo e com contexto comparavel
- tratar `API` nesta base como caso unico real observado na KB, e nao como familia ampla ja generalizavel
- validar antes se cada `ATTCUSTOMTYPE` apontado no molde existe no alvo como `EXO`, `SDT` ou tipo base suportado
- preferir ler e gerar `API` dentro de uma familia funcional combinada, e nao como objeto solto, quando o caso real ja vier acoplado a `Procedure`, `SDT`, `Domain`, `Transaction`, `Table` ou `DataProvider`
- abortar se a API depender de procedures, `EXO` ou `SDT` inexistentes no destino

### Theme

- preservar `PredefinedTypes`, `Styles`, classes visuais base e referencias internas entre classes
- nao podar classes so porque parecem "sobrando"; classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption` podem ser exigidas por outras referencias do proprio tema
- tratar `Theme` preferencialmente em conjunto com `ThemeClass`; para analise mais completa da camada visual, considerar junto tambem `DesignSystem`, `ColorPalette` e `ThemeColor`
- abortar se a edicao quebrar o grafo minimo de classes referenciadas

### PatternSettings

- tratar o objeto como configuracao de pattern, nao como objeto autocontido
- validar se o pattern citado por GUID esta registrado no ambiente de destino
- abortar se o caso exigir inferir ou inventar contexto de pattern, procedures de suporte ou variaveis de contexto

### Attribute

- distinguir sempre dois formatos diferentes: `Attribute` top-level real e referencia inline de `Transaction`
- ao extrair ou usar corpus de `Attribute`, aceitar apenas raiz `<Attribute ... name="...">` com `Part` e `Properties`
- nao reutilizar nos curtos `<Attribute key="True|False" guid="...">Nome</Attribute>` como se fossem objeto `Attribute` completo
- ao gerar `Attribute` isolado, partir apenas de molde real top-level comparavel
- validar propriedades nominais que apontem para atributos reais da KB, como `ControlItemDescription`
- se `ControlItemDescription`, `idBasedOn` ou referencia equivalente apontarem para atributo inexistente no destino, abortar em vez de tratar isso como problema de envelope
- se houver opcao, preferir `Attribute` real semanticamente fechado, sem `ControlItemDescription`, porque esse perfil ja demonstrou importacao bem-sucedida

### WorkWithForWeb

- tratar o objeto como instancia de pattern por `Transaction`, nao como XML independente simples
- usar referencias de atributo no formato estrutural real `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`
- nao substituir esse prefixo por GUID de `Attribute` top-level nem por GUID inline do `Level` da `Transaction`
- se a frente introduzir atributos novos usados em `selection`, filtros, abas ou navegacao, tratar o pacote como caso misto `Transaction + WorkWithForWeb + Attribute`
- ao inserir ou alterar action, localizar estruturalmente a `Selection` alvo no XML interno antes de editar `<actions>`; nao usar substituicao textual ampla em tags repetidas
- validar que a action nova ficou exatamente uma vez no `Selection` correto; duplicidade ou action em escopo ambiguo bloqueia o pacote ate reinspecao
- se o objetivo incluir a camada fisica, lembrar que `Table` e `Index` seguem outra trilha: `Table` e top-level proprio e `Index` aparece embutido em `Table`

### Table e Index

- tratar `Table` como objeto top-level da camada fisica e `Index` como estrutura interna da `Table`
- quando a pergunta envolver `Index`, consultar primeiro um molde comparavel de `Table`, nao um suposto corpus de `Index` isolado
- preservar bloco de chave, `<Indexes>`, `Index/@Type`, `Index/@Source` e ordem dos `Member`
- nesta KB, tratar prefixo `I` como indice automatico do GeneXus e prefixo `U` como indice manual criado por humano
- se um indice `I...` tiver nome descritivo, assumir primeiro que houve apenas renomeacao editorial do nome, sem mudanca de campos ou ordem
- ler indices automaticos de auditoria como casos de FK automatica renomeada, nao como familia especial separada
- tratar indice `User` como tuning manual empirico para ordenacao/performance, especialmente quando a ordenacao real divergir dos indices automaticos disponiveis
- nao supor que toda `Table` precise de indice `User`; a ausencia de `U...` pode ser a decisao correta quando o volume esperado nao compensa custo extra
- fora de evidencia comparavel forte, preferir a hipotese conservadora `PK + poucos Automatic Duplicate` antes de inventar `User` adicional
- nao usar casos excepcionais locais sem `Automatic Duplicate`, como `OperacaoFiscal`, `Pais` e `TipoDocumento`, como molde preferencial para novas inferencias
- preferir pacotes comparaveis com `Transaction` junto quando a pergunta depender da ponte logica -> fisica
- abortar se o caso exigir inventar indice novo, chave fisica nova ou tratar `Index` como top-level sem evidencia externa adicional

### WebPanel

- identificar primeiro a familia estrutural usando `04-webpanel-familias-e-templates.md`
- selecionar um molde interno da mesma familia; quando houver anexo sanitizado completo, ele pode ser a fonte final do prototipo
- preservar `layout`, `events`, `variables`, `Part type`, controles e bindings do molde-base
- abortar se a familia nao estiver clara ou se o alvo exigir `grid`, `tab`, componente customizado ou contexto de `parent` ausente no molde escolhido

## Regras de serializacao XPZ

- o objeto clonado deve continuar como XML bem-formado com raiz unica `<Object>`
- blocos `Source` e `InnerHtml` que vierem em `CDATA` devem permanecer em `CDATA`
- o agente deve incluir o objeto em `<Objects>` seguindo o envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- em pacote misto com `Transaction`, `WorkWithForWeb` e atributos novos, `Transaction` e `WorkWithForWeb` ficam em `<Objects>` e os atributos top-level ficam em `<Attributes>`
- se houver `WorkWithForWeb` no pacote misto, preservar tambem a referencia de `Pattern` no bloco `Dependencies`
- ao gerar ou alterar XML de objeto GeneXus, obter o horario local no momento da gravacao e preencher `lastUpdate` com o instante real correspondente
- `lastUpdate` nao e detalhe cosmetico; ele deve ser conferido no arquivo salvo depois de cada gravacao local
- se o objeto mudou, `lastUpdate` deve ser regravado com o instante real da ultima escrita
- se o objeto nao mudou e entrou apenas para dependencia, preservar o `lastUpdate` oficial
- nao concluir XML ou pacote enquanto o `lastUpdate` do arquivo final nao tiver sido relido e confirmado
- nao concluir XML GeneXus grande apenas porque a escrita terminou; reler cabecalho, cauda e trecho funcional afetado, validar XML bem-formado, fechamento da raiz e `CDATA` antes de empacotar
- se heredoc, here-string ou mecanismo equivalente terminar por EOF antes do delimitador esperado, tratar o arquivo como truncado/corrompido e regenerar por metodo controlado
- se houver export real comparavel da IDE para a mesma composicao, preferir repetir o shape desse export em vez de improvisar `Dependencies` ou `ObjectsIdentityMapping`
- para pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir objetos embutidos em `<Objects>` quando esse for o formato validado pelo molde real
- quando o formato exigir UTC com `Z`, converter corretamente a partir do horario local real; nao reaproveitar timestamp antigo nem de rodada anterior
- o agente deve tratar `ObjectsIdentityMapping` como mapeamento de contexto; nao repetir ali cada objeto exportado nem inventar pares `Object` -> `ObjectIdentity` 1:1
- quando o objeto depender de `parentGuid` ou `moduleGuid` externos relevantes, o agente deve preferir manter no `ObjectsIdentityMapping` a identidade correspondente com o mesmo `Guid`
- o agente deve preservar sempre preenchidos, no formato normal, `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name`
- o agente deve garantir tambem que `Source/@kb` e `Source/Version/@guid` sejam GUIDs sintaticamente validos; placeholders textuais ja falharam em parse real nesta trilha
- ao clonar/criar objeto a partir de XML existente, procurar residuos do objeto molde em `Object/@name`, `fullyQualifiedName`, `guid`, propriedade `Name`, `Description`, `Source`, `Rules/parm`, chamadas internas, dependencias e `ObjectsIdentityMapping`
- cada residuo do objeto molde deve ser classificado como intencional, dependencia necessaria ou erro de clonagem; ocorrencia sem classificacao bloqueia o pacote
- o agente nao deve gerar `KnowledgeBase`, `Settings` nem elemento top-level com nome da KB ao montar `.xpz` normal de objetos
- se a serializacao depender de bloco especial de KB, o agente deve tratar isso como export especial e recusar a montagem normal de objetos
- o agente pode usar a pasta local `from-anywhere-to-GeneXus` apenas como confirmacao secundaria de envelope minimo; nao deve copiar dela valores hardcoded como `Build=0`, `SampleKB`, `BusinessLogic`, `root`, `parentGuid` fixo ou `moduleGuid` fixo
- antes de empacotar, validar parse XML, presenca de todos os `Part type` recorrentes e coerencia entre objeto clonado e molde-base
- o agente nao deve afirmar “sem erro de importacao”; deve afirmar apenas que seguiu a especificacao mais conservadora disponivel
- ha evidência direta de importacao bem-sucedida para um caso minimo de `Procedure`; isso ajuda a validar o envelope normal, mas nao autoriza generalizacao irrestrita para todos os tipos

## Regras de fonte

- Fonte valida: XML bruto de objeto
- Fonte valida: envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- Fonte valida: exemplos sanitizados completos de `04-webpanel-familias-e-templates.md`, quando usados como molde de `WebPanel`
- Fonte valida: molde sanitizado canonico completo de `05b-procedure-relatorio-familias-e-templates.md`, quando o caso for `Procedure` de relatorio simples dentro da cobertura `F2` ou `F3` e o bloco usado estiver marcado como `molde pronto`
- Fonte invalida: markdown apenas descritivo desta base, inclusive alias, tabelas e sinteses sem bloco `molde pronto`
- Fonte invalida: reconstrucoes livres baseadas em tabelas, frequencias ou descricoes
- Inferência forte: esta base documental ja explica o envelope XPZ observado e ja contem moldes sanitizados completos para `WebPanel`
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Transaction` em familias representativas
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em perfis representativos
- Regra operacional: quando `Procedure` de relatorio simples estiver coberta por molde canonico da trilha, rotular a resposta como baseada em `molde sanitizado`; quando houver escalada, rotular explicitamente `XML real da KB atual`, `XML real de outra KB` ou `hipotese`
- Hipótese: no caso de `WorkWithForWeb`, os anexos ajudam a prototipar, mas ainda nao eliminam a necessidade de cautela extra quando o caso concreto depender fortemente de `pattern` gerado e contexto do objeto pai
- Hipótese: nem todos os tipos da base chegaram nesse mesmo nivel de cobertura; para varios deles ainda prevalece a orientacao por familia + molde bruto comparavel





