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

## Regra de precedencia sobre skills gerais

- quando a tarefa for de `XML`/`XPZ` nesta base, os `.md` locais da pasta do projeto tem precedencia sobre heuristicas gerais de skill
- isso nao revoga a postura conservadora do skill `nexa`; apenas define que a evidencia local consolidada nesta base e a fonte mais especifica desta trilha
- se houver tensao entre fluxo GeneXus geral do skill e achado empirico local desta base, o agente deve seguir a base local para decisao de `XPZ`/`XML` e manter do skill apenas a disciplina metodologica

## Regra de leitura para runtime

- quando a pergunta envolver `Base Table`, `Extended Table`, navegacao, `For each`, `Load`, `Refresh`, `Refresh Grid` ou risco de performance, consultar primeiro `02-regras-operacionais-e-runtime.md`
- quando a pergunta envolver apenas estrutura XML observada, priorizar `01-base-empirica-geral.md`
- quando a pergunta misturar estrutura e comportamento provavel, responder separando explicitamente `Evidência direta`, `Regra documentada`, `Inferência forte` e `Hipótese`

## Regra de leitura para XPZ

- quando a tarefa envolver montar ou serializar `XPZ`, consultar primeiro a secao `Envelope XPZ observado em export real` de `02-regras-operacionais-e-runtime.md`
- nao presumir `Objects.xml` isolado nem manifesto externo separado se isso nao estiver documentado no `02`
- usar o envelope sanitizado documentado na base como referencia estrutural antes de pedir XML externo adicional
- depois da bateria de importacao e da consulta ao acervo real, separar explicitamente `problema de envelope`, `problema de shape minimo` e `problema de dependencia da KB`
- se existir export real comparavel da IDE para a mesma composicao de objetos, esse export deve prevalecer sobre envelope leve hipotetico
- em pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir pacote embutido comparavel antes de tentar envelope por `FilePath`

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
- Inferência forte: para `WebPanel`, os anexos completos de `04-webpanel-familias-e-templates.md` ja podem servir como molde sanitizado documentado
- Inferência forte: para `Transaction`, `05-transaction-familias-e-templates.md` ja contem moldes sanitizados completos para as familias `F1`, `F2`, `F5` e `F6`
- Inferência forte: para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File`, `01-base-empirica-geral.md` ja contem moldes sanitizados completos representativos
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
- se houver export real comparavel da IDE para a mesma composicao, preferir repetir o shape desse export em vez de improvisar `Dependencies` ou `ObjectsIdentityMapping`
- para pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir objetos embutidos em `<Objects>` quando esse for o formato validado pelo molde real
- quando o formato exigir UTC com `Z`, converter corretamente a partir do horario local real; nao reaproveitar timestamp antigo nem de rodada anterior
- o agente deve tratar `ObjectsIdentityMapping` como mapeamento de contexto; nao repetir ali cada objeto exportado nem inventar pares `Object` -> `ObjectIdentity` 1:1
- quando o objeto depender de `parentGuid` ou `moduleGuid` externos relevantes, o agente deve preferir manter no `ObjectsIdentityMapping` a identidade correspondente com o mesmo `Guid`
- o agente deve preservar sempre preenchidos, no formato normal, `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name`
- o agente deve garantir tambem que `Source/@kb` e `Source/Version/@guid` sejam GUIDs sintaticamente validos; placeholders textuais ja falharam em parse real nesta trilha
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
- Fonte invalida: markdown apenas descritivo desta base
- Fonte invalida: reconstrucoes livres baseadas em tabelas, frequencias ou descricoes
- Inferência forte: esta base documental ja explica o envelope XPZ observado e ja contem moldes sanitizados completos para `WebPanel`
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Transaction` em familias representativas
- Inferência forte: esta base documental ja contem moldes sanitizados completos tambem para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em perfis representativos
- Hipótese: no caso de `WorkWithForWeb`, os anexos ajudam a prototipar, mas ainda nao eliminam a necessidade de cautela extra quando o caso concreto depender fortemente de `pattern` gerado e contexto do objeto pai
- Hipótese: nem todos os tipos da base chegaram nesse mesmo nivel de cobertura; para varios deles ainda prevalece a orientacao por familia + molde bruto comparavel





