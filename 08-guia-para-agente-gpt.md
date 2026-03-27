# 08 - Guia para Agente GPT

## Papel do documento
operacional

## Nivel de confianca predominante
medio

## Depende de
00-readme-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 04-webpanel-familias-e-templates.md, 05-transaction-familias-e-templates.md

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
00-readme-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
qualquer agente GPT que precise responder perguntas ou tomar decisão operacional usando esta base

## Objetivo
Explicar como um agente GPT deve consultar esta base documental e como responder com prudência.
Padronizar quando avançar, quando exigir molde bruto comparável e quando abortar.

## Ordem de consulta recomendada

1. ler `00-readme-genexus-xpz-xml.md`
2. identificar o tipo alvo e checar `03-risco-e-decisao-por-tipo.md`
3. ler `02-regras-operacionais-e-runtime.md`
4. para `WebPanel`, ler `04-webpanel-familias-e-templates.md`
5. para `Transaction`, ler `05-transaction-familias-e-templates.md`
6. usar `01-base-empirica-geral.md` e `09-historico-e-inventario-publico.md` para sustentar detalhe empírico e rastreabilidade

## Regra de leitura para runtime

- quando a pergunta envolver `Base Table`, `Extended Table`, navegacao, `For each`, `Load`, `Refresh`, `Refresh Grid` ou risco de performance, consultar primeiro `02-regras-operacionais-e-runtime.md`
- quando a pergunta envolver apenas estrutura XML observada, priorizar `01-base-empirica-geral.md`
- quando a pergunta misturar estrutura e comportamento provavel, responder separando explicitamente `Evidência direta`, `Regra documentada`, `Inferência forte` e `Hipótese`

## Regra de leitura para XPZ

- quando a tarefa envolver montar ou serializar `XPZ`, consultar primeiro a secao `Envelope XPZ observado em export real` de `02-regras-operacionais-e-runtime.md`
- nao presumir `Objects.xml` isolado nem manifesto externo separado se isso nao estiver documentado no `02`
- usar o envelope sanitizado documentado na base como referencia estrutural antes de pedir XML externo adicional

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

## Quando recusar geração de XPZ

- quando faltar molde XML completo suficientemente próximo
- quando o tipo estiver em risco `alto` ou `muito alto` sem contexto equivalente, exceto nos fluxos ja destravados de `Transaction` e `WebPanel`
- quando houver `pattern`, `parent` ou bloco raro ainda não compreendido
- quando a pergunta exigir afirmar sucesso de importação/build sem evidência externa

## Regra de decisão entre gerar, exigir molde ou abortar

### Gerar por clonagem conservadora

- apenas em cenário muito controlado
- apenas com molde do mesmo tipo e contexto estrutural comparável
- apenas preservando `Object/@type`, `parent*`, `moduleGuid` e `Part type` recorrentes
- para `Transaction`, usar familia estrutural inferida da propria base
- para `WebPanel`, usar familia estrutural inferida e molde interno muito proximo

### Exigir molde bruto comparável

- quando o tipo estiver em cautela alta
- quando a amostra for pequena
- quando o objeto depender de contexto estrutural explícito
- `Transaction` nao deve mais exigir molde externo
- `WebPanel` deve operar por familia estrutural e molde interno proximo

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
- Inferência forte: para `WebPanel`, os anexos completos de `04-webpanel-familias-e-templates.md` ja podem servir como molde sanitizado documentado
- Inferência forte: para `Transaction`, `05-transaction-familias-e-templates.md` ja contem moldes sanitizados completos para as familias `F1`, `F2`, `F5` e `F6`
- Inferência forte: para `Procedure`, `DataProvider`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem` e `ColorPalette`, `01-base-empirica-geral.md` ja contem moldes sanitizados completos representativos
- Hipótese: para `Transaction` das familias `F3` e `F4`, continua prudente buscar molde bruto comparavel adicional se a densidade estrutural real do alvo ultrapassar o que os anexos atuais sustentam

### Transaction

- localizar um molde XML completo do mesmo `Object/@type` e da familia estrutural mais proxima
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, `Part type` e ordem das `Part`
- editar somente nomes, descricoes e trechos internos sustentados pelo molde usado
- abortar se a mudanca exigir criar atributo novo no `<Object>` ou bloco novo sem paralelo claro

### WebPanel

- identificar primeiro a familia estrutural usando `04-webpanel-familias-e-templates.md`
- selecionar um molde interno da mesma familia; quando houver anexo sanitizado completo, ele pode ser a fonte final do prototipo
- preservar `layout`, `events`, `variables`, `Part type`, controles e bindings do molde-base
- abortar se a familia nao estiver clara ou se o alvo exigir `grid`, `tab`, componente customizado ou contexto de `parent` ausente no molde escolhido

## Regras de serializacao XPZ

- o objeto clonado deve continuar como XML bem-formado com raiz unica `<Object>`
- blocos `Source` e `InnerHtml` que vierem em `CDATA` devem permanecer em `CDATA`
- o agente deve incluir o objeto em `<Objects>` seguindo o envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- antes de empacotar, validar parse XML, presenca de todos os `Part type` recorrentes e coerencia entre objeto clonado e molde-base
- o agente nao deve afirmar “sem erro de importacao”; deve afirmar apenas que seguiu a especificacao mais conservadora disponivel

## Regras de fonte

- Fonte valida: XML bruto de objeto
- Fonte valida: envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- Fonte valida: exemplos sanitizados completos de `04-webpanel-familias-e-templates.md`, quando usados como molde de `WebPanel`
- Fonte invalida: markdown apenas descritivo desta base
- Fonte invalida: reconstrucoes livres baseadas em tabelas, frequencias ou descricoes
- Inferência forte: esta base documental ja explica o envelope XPZ observado e ja contem moldes sanitizados completos para `WebPanel`
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Transaction` em familias representativas
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Procedure`, `DataProvider`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem` e `ColorPalette` em perfis representativos
- Hipótese: no caso de `WorkWithForWeb`, os anexos ajudam a prototipar, mas ainda nao eliminam a necessidade de cautela extra quando o caso concreto depender fortemente de `pattern` gerado e contexto do objeto pai
- Hipótese: nem todos os tipos da base chegaram nesse mesmo nivel de cobertura; para varios deles ainda prevalece a orientacao por familia + molde bruto comparavel





