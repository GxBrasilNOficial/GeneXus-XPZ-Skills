# 19 - KB Intelligence Fase 6 - Exemplos de Investigacao Funcional

## Papel do documento
exemplos operacionais

## Nivel de confianca predominante
baixo a medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md, historico/kb-intelligence/2026-04-kb-intelligence-fase-1-validacao-kbexemplo.md, historico/kb-intelligence/2026-04-kb-intelligence-fase-2-dataprovider-validacao-kbexemplo.md

## Usado por
agentes que precisem ver exemplos curtos de resposta funcional assistida com base em evidencias reais ja validadas

## Objetivo
Mostrar como a Fase 6 deve usar o indice para orientar a leitura e como a resposta deve declarar seus limites.

## Exemplo 1 - por onde revisar primeiro ao alterar um `WebPanel`

### Pergunta

"Se eu alterar `WebPanel:wpRelatoriosDeMovimentosDeVolumes`, onde devo revisar primeiro?"

### Trilha minima

- `object-info` localiza `WebPanel/wpRelatoriosDeMovimentosDeVolumes.xml`
- `what-uses` retorna dependencias diretas do `WebPanel`
- `show-evidence` confirma relacao direta para `Procedure:procPlanilhaVolumeMovimento`

### Evidencia direta

- existe relacao direta `WebPanel:wpRelatoriosDeMovimentosDeVolumes` -> `Procedure:procPlanilhaVolumeMovimento`
- a evidencia registrada fica em `WebPanel/wpRelatoriosDeMovimentosDeVolumes.xml`, linha `131`
- a regra registrada e `procedure_dot_call`
- o trecho registrado e `procPlanilhaVolumeMovimento.Call(...)`

### Leitura adicional do XML

- a leitura do XML oficial do `WebPanel` deve confirmar em que bloco do `Source` a chamada ocorre
- a leitura do XML oficial da `Procedure` chamada deve ser aberta apenas se a alteracao depender do contrato funcional dessa rotina

### Inferencia forte

- `procPlanilhaVolumeMovimento` e um candidato forte a primeiro ponto de revisao porque o indice ja prova chamada direta saindo do `WebPanel`

### Hipotese

- o indice sozinho nao prova se essa `Procedure` concentra toda a regra funcional do fluxo ou apenas parte dela

## Exemplo 2 - validar se um `WorkWithForWeb` parece participar de uma regra

### Pergunta

"Ha indicio tecnico de que `WorkWithForWeb:WorkWithWebAbateOrdem` participa de regras que dependem de procedures auxiliares?"

### Trilha minima

- `object-info` localiza `WorkWithForWeb/WorkWithWebAbateOrdem.xml`
- `what-uses` mostra saidas diretas relevantes
- `show-evidence` confirma pelo menos uma procedure ligada por condicao

### Evidencia direta

- existe relacao direta `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procLeEmpresaSessao`
- a evidencia registrada fica em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linha `172`
- a regra registrada e `workwith_condition_procedure`

### Leitura adicional do XML

- a leitura do XML oficial do `WorkWithForWeb` deve abrir a condicao que chama a procedure
- a leitura do XML oficial de `procLeEmpresaSessao` so e necessaria se a pergunta passar de "ha indicio tecnico?" para "qual regra de negocio esta sendo aplicada?"

### Inferencia forte

- ha indicio tecnico forte de participacao funcional porque a procedure aparece ligada ao `WorkWithForWeb` por evidencia de condicao, nao apenas por coincidencia nominal

### Hipotese

- o indice nao prova sozinho se a procedure e obrigatoria em todos os cenarios da tela nem qual impacto funcional completo ela produz

## Exemplo 3 - usar o indice para reduzir busca, sem fechar a regra de negocio

### Pergunta

"O fluxo de `WorkWithWebAbateOrdem` certamente depende da `Transaction:AbateOrdem`?"

### Trilha minima

- `show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Transaction:AbateOrdem`
- abrir depois o XML oficial do `WorkWithForWeb`

### Evidencia direta

- existe relacao direta `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Transaction:AbateOrdem`
- a regra registrada e `workwith_transaction_binding`
- a evidencia esta ancorada no proprio XML `WorkWithForWeb/WorkWithWebAbateOrdem.xml`

### Leitura adicional do XML

- o XML oficial deve ser aberto para confirmar como a vinculacao da transacao participa da tela, da selecao ou das actions relevantes

### Inferencia forte

- a `Transaction:AbateOrdem` e parte estrutural forte do contexto desse `WorkWithForWeb`

### Hipotese

- "certamente depende" ainda e forte demais sem abrir o XML e sem revisar o trecho funcional alvo; o indice mostra vinculacao tecnica direta, nao prova comportamento funcional completo

## Exemplo 4 - triangulacao curta com `DataProvider`

### Pergunta

"Se eu suspeito que um menu ou sidebar passa por `DataProvider:dpFixoSidebarItems`, qual e a menor trilha tecnica inicial?"

### Trilha minima

- `object-info` localiza `DataProvider/dpFixoSidebarItems.xml`
- `who-uses` mostra quem chama o `DataProvider`
- `show-evidence` confirma uma chamada direta vinda de `Procedure:procMenuItens`

### Evidencia direta

- existe relacao direta `Procedure:procMenuItens` -> `DataProvider:dpFixoSidebarItems`
- a evidencia registrada fica em `Procedure/procMenuItens.xml`, linha `5`
- a regra registrada e `dataprovider_direct_call`

### Leitura adicional do XML

- o XML oficial de `procMenuItens` deve ser aberto para entender em que contexto o `DataProvider` e montado
- o XML oficial de `dpFixoSidebarItems` deve ser aberto apenas se a pergunta passar para "o que ele devolve" ou "qual item de interface ele alimenta"

### Inferencia forte

- `procMenuItens` e um ponto forte de entrada para investigar o uso funcional do `DataProvider`

### Hipotese

- o indice nao prova sozinho se esse `DataProvider` atende so menu, sidebar ou outros cenarios de UI sem abrir o XML correspondente

## Exemplo 5 - BC `.Load(...)` como atalho para a trilha de leitura

### Pergunta

"Ha indicio tecnico de que `Procedure:procAjustaCompraGadoIdDeAnimais` trabalha diretamente com a `Transaction:Animal`?"

### Trilha minima

- consultar `show-evidence` para `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal`
- se a pergunta evoluir, abrir o XML oficial da `Procedure`

### Evidencia direta

- existe relacao direta `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal`
- a regra registrada e `source_bc_load_transaction`
- a expectativa validada na bateria da Fase 5 e `&animal.Load(...)` com `ATTCUSTOMTYPE` `bc:Animal`

### Leitura adicional do XML

- o XML oficial da `Procedure` deve confirmar se o `Load` aparece em fluxo de leitura, validacao, ajuste ou persistencia
- se a pergunta for sobre efeito funcional completo, a leitura precisa seguir tambem para os blocos subsequentes ao `Load`

### Inferencia forte

- ha sinal tecnico forte de manipulacao direta de `Animal` via BC, porque o indice nao depende apenas do nome da variavel: ele resolve o `bc:*` para `Transaction`

### Hipotese

- o indice nao fecha sozinho se a procedure apenas consulta, altera ou persiste efetivamente o objeto apos o `Load`

## Exemplo 6 - tipo resolvido ajuda a abrir o XML certo, nao a concluir o contrato funcional

### Pergunta

"Se eu quero entender rapidamente o contrato tecnico de `API:apiPDV_Integracao`, qual tipo devo abrir primeiro?"

### Trilha minima

- consultar a relacao resolvida de `API:apiPDV_Integracao` para `SDT:sdtProdutoDadosBasicos`
- usar isso para escolher o XML de tipo a abrir antes da leitura completa da `API`

### Evidencia direta

- existe relacao resolvida `API:apiPDV_Integracao` -> `SDT:sdtProdutoDadosBasicos`
- a regra registrada e `attcustomtype_resolved_object`
- a bateria da Fase 5 validou esse caso como resolucao segura de `ATTCUSTOMTYPE`

### Leitura adicional do XML

- o XML oficial da `API` deve ser aberto para confirmar se o `SDT` aparece como entrada, saida ou outro papel estrutural
- o XML oficial do `SDT` deve ser aberto para entender a forma do contrato tecnico envolvido

### Inferencia forte

- `sdtProdutoDadosBasicos` e um dos primeiros XMLs corretos para abrir quando o objetivo e entender o shape tecnico dessa `API`

### Hipotese

- o indice nao prova sozinho se esse `SDT` representa entrada, saida principal, payload parcial ou apenas um tipo auxiliar da `API`

## Exemplo 7 - `for each` explicito aponta leitura imediata de tabela

### Pergunta

"Se eu mexer em `Procedure:procAnimaisContagemDeUmPeriodo`, qual tabela eu devo revisar primeiro?"

### Trilha minima

- consultar `show-evidence` para `Procedure:procAnimaisContagemDeUmPeriodo` -> `Table:Animal`
- abrir o XML oficial da `Procedure` apenas no trecho do `Source`

### Evidencia direta

- existe relacao direta `Procedure:procAnimaisContagemDeUmPeriodo` -> `Table:Animal`
- a evidencia registrada fica em `Procedure/procAnimaisContagemDeUmPeriodo.xml`, linha `9`
- a regra registrada e `source_for_each_explicit_table`
- o trecho registrado e `for each Animal`

### Leitura adicional do XML

- o XML oficial da `Procedure` deve ser aberto para confirmar o recorte do `for each`, filtros e comandos executados dentro do loop
- o XML da `Table:Animal` so precisa ser aberto se a duvida evoluir para chave, indice ou estrutura persistente envolvida

### Inferencia forte

- `Animal` e o primeiro ponto tecnico de revisao porque o `for each` explicito prova acesso direto a essa tabela

### Hipotese

- o indice nao prova sozinho se a procedure depende apenas dessa tabela ou se o comportamento funcional real se apoia mais em chamadas internas feitas dentro do loop

## Exemplo 8 - `for each` qualificado reduz ambiguidade do alvo

### Pergunta

"Quando eu vejo `Procedure:procAnimalValorPelaCompra`, qual tabela devo abrir primeiro para entender o `for each` qualificado?"

### Trilha minima

- consultar `show-evidence` para `Procedure:procAnimalValorPelaCompra` -> `Table:CompraGadoItens`
- abrir o `Source` da `Procedure` no ponto ancorado

### Evidencia direta

- existe relacao direta `Procedure:procAnimalValorPelaCompra` -> `Table:CompraGadoItens`
- a evidencia registrada fica em `Procedure/procAnimalValorPelaCompra.xml`, linha `11`
- a regra registrada e `source_for_each_qualified_table_prefix`
- o trecho registrado e `for each CompraGadoItens.Faixas`

### Leitura adicional do XML

- o XML oficial da `Procedure` deve ser aberto para entender o papel do membro qualificado apos o ponto
- a leitura da tabela serve para revisar a estrutura persistente de `CompraGadoItens`, nao para assumir que `Faixas` e tabela propria

### Inferencia forte

- a trilha tecnica deve partir de `CompraGadoItens`, porque o prefixo do `for each` qualificado e o alvo estrutural resolvido

### Hipotese

- o indice nao fecha sozinho se o membro `Faixas` representa subestrutura relevante para a regra ou apenas detalhe de navegacao da linguagem

## Exemplo 9 - `ExternalObject` resolvido ajuda a distinguir dependencia local de runtime generico

### Pergunta

"Se eu investigar `Procedure:procExtraiArquivosDoZip`, qual dependencia externa local vale abrir primeiro?"

### Trilha minima

- consultar a relacao resolvida para `Procedure:procExtraiArquivosDoZip` -> `ExternalObject:ZipFile`
- abrir depois o XML oficial da `Procedure`

### Evidencia direta

- existe relacao resolvida `Procedure:procExtraiArquivosDoZip` -> `ExternalObject:ZipFile`
- a evidencia literal de tipo fica em `Procedure/procExtraiArquivosDoZip.xml`, linha `448`
- o valor registrado no XML e `exo:ZipFile`
- a regra resolvida usada pelo indice e `attcustomtype_resolved_object`

### Leitura adicional do XML

- o XML oficial da `Procedure` deve ser aberto para confirmar como a variavel tipada participa do fluxo
- o XML do `ExternalObject` ajuda a entender quais membros do objeto externo sao candidatos de leitura, mas nao substitui o `Source` da procedure

### Inferencia forte

- `ZipFile` e um alvo melhor que built-ins genericos quando o objetivo e entender a dependencia externa local realmente inventariada

### Hipotese

- o indice nao prova sozinho se o `ExternalObject` e central na regra funcional ou apenas um detalhe instrumental do processamento

## Exemplo 10 - `Domain` tipado com `SDT` aponta contrato tecnico reaproveitado

### Pergunta

"Se eu achar um `Domain` com cara de colecao externa, qual XML de tipo devo abrir primeiro?"

### Trilha minima

- consultar a relacao resolvida `Domain:CountryInfoServiceArrayOftContinent` -> `SDT:CountryInfoServicetContinent`
- abrir o XML do `Domain` e depois o do `SDT`

### Evidencia direta

- existe relacao resolvida `Domain:CountryInfoServiceArrayOftContinent` -> `SDT:CountryInfoServicetContinent`
- a evidencia literal do tipo fica em `Domain/CountryInfoServiceArrayOftContinent.xml`, linha `27`
- o valor registrado no XML e `sdt:CountryInfoServicetContinent`
- a regra resolvida usada pelo indice e `attcustomtype_resolved_object`

### Leitura adicional do XML

- o XML oficial do `Domain` deve confirmar o ponto em que o tipo customizado e declarado
- o XML oficial do `SDT` deve ser aberto para entender o shape tecnico da estrutura reaproveitada

### Inferencia forte

- o `SDT` resolvido e um primeiro XML correto para abrir quando a pergunta e "que estrutura esse `Domain` esta empacotando?"

### Hipotese

- o indice nao prova sozinho se o `Domain` e usado como lista serializavel, wrapper de interoperabilidade ou outra abstracao local

## Exemplo 11 - `DataSelector` com `SDT` ajuda a escolher o parametro certo

### Pergunta

"Se eu quiser entender rapidamente o parametro tecnico de `DataSelector:dsRelatoriosDeTitulosViaLancamentos`, qual tipo devo abrir antes?"

### Trilha minima

- consultar a relacao resolvida `DataSelector:dsRelatoriosDeTitulosViaLancamentos` -> `SDT:sdtTituloParametros`
- abrir primeiro o XML do `DataSelector` na area das variaveis

### Evidencia direta

- existe relacao resolvida `DataSelector:dsRelatoriosDeTitulosViaLancamentos` -> `SDT:sdtTituloParametros`
- a evidencia literal do tipo fica em `DataSelector/dsRelatoriosDeTitulosViaLancamentos.xml`, linha `240`
- o valor registrado no XML e `sdt:sdtTituloParametros`
- a regra resolvida usada pelo indice e `attcustomtype_resolved_object`

### Leitura adicional do XML

- o XML oficial do `DataSelector` deve ser aberto para confirmar se o `SDT` participa como parametro principal de filtro
- o XML do `SDT` deve ser aberto para entender os campos do contrato tecnico usados no seletor

### Inferencia forte

- `sdtTituloParametros` e um dos primeiros XMLs corretos para abrir quando a duvida e sobre o filtro tecnico desse `DataSelector`

### Hipotese

- o indice nao prova sozinho se esse `SDT` concentra todo o criterio do seletor ou se parte relevante da regra esta espalhada em chamadas auxiliares

## Exemplo 12 - distinguir `via edicao web` de `via BC` no ajuste de `Animal`

### Pergunta

"No fluxo de `WorkWithForWeb:WorkWithWebAbateOrdem`, a acao `ZeraCompraGadoIdDeAnimais` atua sobre `Transaction:Animal` via edicao web ou via BC?"

### Trilha minima

- consultar `functional-trace-basic` para `Procedure:procAjustaCompraGadoIdDeAnimais`
- confirmar no indice a relacao de entrada `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procAjustaCompraGadoIdDeAnimais`
- confirmar no indice as relacoes `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal` por `Load` e `Save`
- abrir os XMLs oficiais de `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, `Procedure/procAjustaCompraGadoIdDeAnimais.xml` e `Transaction/Animal.xml`

### Evidencia direta

- existe relacao direta `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procAjustaCompraGadoIdDeAnimais`
- a evidencia registrada fica em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linha `843`
- a regra registrada e `workwith_action_gxobject`
- o trecho registrado e a action `ZeraCompraGadoIdDeAnimais`
- existem relacoes diretas `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal`
- as evidencias registradas ficam em `Procedure/procAjustaCompraGadoIdDeAnimais.xml`, linhas `66`, `83`, `122` e `138`
- as regras registradas sao `source_bc_load_transaction` e `source_bc_save_transaction`

### Leitura adicional do XML

- no XML oficial de `WorkWithForWeb:WorkWithWebAbateOrdem`, a action `ZeraCompraGadoIdDeAnimais` chama a procedure `procAjustaCompraGadoIdDeAnimais` com parametros como `AbateOrdemData`, `AbateOrdemEmpresaId` e `AbateOrdemId`
- no XML oficial da procedure, o `parm(...)` confirma esse contrato de entrada e o `Source` filtra `Animal` por `AnimalAbateOrdemId = &AbateOrdemId`
- ainda na procedure, os trechos `&animal.Load(AnimalEmpresaId, AnimalId)`, `&animal.AnimalCompraGadoId.SetEmpty()` ou `&animal.AnimalCompraGadoId = &CompraGadoId`, seguidos de `&animal.Save()`, confirmam manipulacao da `Transaction:Animal` via Business Component
- no XML oficial de `Transaction:Animal`, ha blocos separados marcados com `[web]` e `[bc]`, reforcando a terminologia local: regras e eventos de tela ficam em `via edicao web`, enquanto manipulacao por `Load/Save` do BC fica em `via BC`

### Inferencia forte

- neste caso, o disparo do fluxo ocorre `via edicao web`, porque parte de uma action do `WorkWithForWeb`
- a alteracao efetiva dos registros de `Animal` ocorre `via BC`, porque a procedure chamada carrega e salva a transacao com `&animal.Load(...)` e `&animal.Save()`
- portanto, a forma mais precisa de descrever o caso e: a tela inicia o fluxo `via edicao web`, mas a atualizacao de `Animal` e executada `via BC`

### Hipotese

- esse recorte nao prova sozinho se toda atualizacao de `Animal` a partir de `WorkWithWebAbateOrdem` passa por essa mesma procedure
- tambem nao prova que a action sempre zera `AnimalCompraGadoId`; em parte do `Source`, a mesma procedure tambem pode preencher `AnimalCompraGadoId = &CompraGadoId`, conforme os parametros recebidos

## Exemplo 13 - suspeita curta de reprocessamento em `AbateOrdem`

### Pergunta

"Ha indicio tecnico forte de que `WorkWithForWeb:WorkWithWebAbateOrdem` oferece um fluxo de reprocessamento de `Transaction:AbateOrdem`?"

### Trilha minima

- consultar `functional-trace-basic` para `Procedure:procReprocessaAbateOrdem`
- confirmar no indice a relacao de entrada `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procReprocessaAbateOrdem`
- confirmar no indice as relacoes `Procedure:procReprocessaAbateOrdem` -> `Transaction:AbateOrdem` por `Load` e `Save`
- abrir os XMLs oficiais de `WorkWithForWeb/WorkWithWebAbateOrdem.xml` e `Procedure/procReprocessaAbateOrdem.xml`

### Evidencia direta

- existem relacoes diretas `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procReprocessaAbateOrdem`
- as evidencias registradas ficam em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linhas `324` e `834`
- a regra registrada e `workwith_action_gxobject`
- existem relacoes diretas `Procedure:procReprocessaAbateOrdem` -> `Transaction:AbateOrdem`
- as evidencias registradas ficam em `Procedure/procReprocessaAbateOrdem.xml`, linhas `28` e `30`
- as regras registradas sao `source_bc_load_transaction` e `source_bc_save_transaction`

### Leitura adicional do XML

- no XML oficial de `WorkWithForWeb:WorkWithWebAbateOrdem`, as actions `ReprocessaAbateOrdens` e `ReprocessaAbateOrdem` chamam a procedure `procReprocessaAbateOrdem`
- no XML oficial da procedure, o `parm(...)` recebe `EmpresaId`, intervalo de datas, `TerceiroId` e `AbateOrdemId`
- ainda na procedure, o `for each` filtra `AbateOrdem` por empresa, data, terceiro e id quando os parametros estao preenchidos
- dentro desse recorte, os trechos `&abateordem.Load(AbateOrdemEmpresaId, AbateOrdemId)` e `&abateordem.Save()` confirmam manipulacao `via BC` da `Transaction:AbateOrdem`

### Inferencia forte

- ha indicio tecnico forte de que a tela oferece um fluxo de reprocessamento de `AbateOrdem`, porque o `WorkWithForWeb` expoe actions nomeadas para reprocessar e a procedure correspondente reler e salvar a transacao por BC
- o indice e o XML juntos sustentam bem a suspeita de fluxo, mesmo sem afirmar o efeito funcional completo do reprocessamento

### Hipotese

- esse recorte nao prova sozinho o que exatamente e recalculado ou refeito durante o reprocessamento
- para fechar a regra funcional completa, ainda seria necessario seguir a leitura da `Transaction:AbateOrdem` e de qualquer logica disparada indiretamente no `Save()`

## Padrao comum dos exemplos

- o indice decide a ordem de leitura
- `show-evidence` reduz a area de busca
- o XML oficial fecha a parte semantica
- a resposta precisa declarar limite de confianca em vez de inflar certeza
