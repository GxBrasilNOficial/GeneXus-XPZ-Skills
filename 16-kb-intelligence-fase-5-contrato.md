# 16 - KB Intelligence Fase 5 - Contrato

## Papel do documento
contrato operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
11-plano-kb-intelligence-incremental.md, 15-kb-intelligence-fase-4-contrato.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem ampliar relacoes semanticas do KB Intelligence depois do inventario completo de tipos

## Objetivo
Definir a Fase 5 do KB Intelligence como ampliacao incremental de relacoes semanticas no SQLite.

A Fase 5 deve evoluir a camada de relacoes sem misturar inventario, inferencia runtime e suporte funcional. Cada nova familia de relacao deve entrar por incremento pequeno, com regra nomeada, evidencia rastreavel, casos positivos, casos negativos e teste de regressao.

## Principio da Fase 5

Inventario ampliado nao implica relacao semantica. Um objeto estar presente na tabela `objects` permite resolver existencia, nome canonico e arquivo, mas nao autoriza inferir dependencia funcional.

Toda relacao nova precisa responder:

- qual e a origem
- qual e o destino
- qual e o papel da evidencia
- qual regra extraiu a evidencia
- qual confianca deve ser atribuida
- quais falsos positivos devem continuar bloqueados

## Incremento 1 proposto - resolver `CustomType:<valor>`

### Escopo aceito

- origem: objetos ja cobertos por `ATTCUSTOMTYPE` na Fase 2
- alvo atual: `CustomType:<valor>`
- novos destinos resolvidos quando existirem no inventario:
  - `SDT`
  - `Domain`
- regra proposta:
  - `attcustomtype_resolved_object`
- evidencia:
  - `Property ATTCUSTOMTYPE`
- confianca:
  - `direct`

### Comportamento esperado

Quando `ATTCUSTOMTYPE` apontar para valor resolvivel no inventario como `SDT` ou `Domain`, o indice deve preservar rastreabilidade e produzir relacao resolvida para o tipo real.

Exemplos conceituais:

- `CustomType:sdt:Context` pode resolver para `SDT:Context` quando existir `SDT/Context.xml`
- `CustomType:bas:Boolean` nao deve ser forçado para `Domain` se nao houver regra segura e objeto correspondente

### Fora do incremento 1

- interpretar estrutura interna do `SDT`
- inferir uso runtime do tipo
- resolver nomes por heuristica agressiva
- criar relacao quando houver colisao case-insensitive
- resolver prefixos sem regra documentada
- remover a relacao literal `CustomType:<valor>` sem decisao explicita

## Incremento 2 aprovado - resolver `Attribute` -> `Domain` por `idBasedOn`

### Escopo aceito

- origem: objetos `Attribute`
- evidencia:
  - `Property idBasedOn`
- destino resolvido:
  - `Domain`, somente quando o valor tiver prefixo `Domain:` e o objeto existir no inventario local
- regra proposta:
  - `attribute_idbasedon_domain`
- confianca:
  - `direct`

### Comportamento esperado

Quando um `Attribute` declarar `idBasedOn` para um `Domain` existente no inventario, o indice deve criar uma relacao direta do atributo para o dominio.

Exemplos conceituais:

- `Attribute:AbateOrdemData` com `idBasedOn` `Domain:Data` pode resolver para `Domain:Data`
- `Domain:Geolocation, GeneXus` nao deve resolver se nao houver objeto correspondente no inventario local

### Fora do incremento 2

- criar dominio inexistente
- resolver dominios externos ou built-in do GeneXus sem objeto local
- inferir semantica de atributo por nome
- inferir uso em `Transaction`, `Table` ou `Source`
- resolver valores sem prefixo `Domain:`

## Incremento 3 aprovado - resolver `Transaction` -> `Attribute` por `Level`

### Escopo aceito

- origem: objetos `Transaction`
- evidencia:
  - elementos estruturais `<Level>/<Attribute>`
- destino resolvido:
  - `Attribute`, somente quando o atributo existir no inventario local
- regra proposta:
  - `transaction_level_attribute`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma `Transaction` declarar atributos em seus niveis estruturais, o indice deve criar relacoes diretas da transacao para esses atributos.

Exemplos conceituais:

- `Transaction:AbateOrdem` pode resolver para `Attribute:AbateOrdemEmpresaId`
- `Transaction:AbateOrdem` pode resolver para `Attribute:AbateOrdemData`

### Fora do incremento 3

- usar `AttributeProperties` como fonte de relacao
- inferir atributo por variaveis, `idBasedOn` interno ou nome no `Source`
- inferir `Transaction` -> `Table`
- inferir participacao em indice, chave estrangeira ou regra runtime
- criar relacao para atributo ausente do inventario local

## Incremento 4 aprovado - resolver `Table` -> `Attribute` por `Key`

### Escopo aceito

- origem: objetos `Table`
- evidencia:
  - elementos estruturais `<Key>/<Item>`
- destino resolvido:
  - `Attribute`, somente quando o atributo existir no inventario local
- regra proposta:
  - `table_key_attribute`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma `Table` declarar atributos em sua chave primaria, o indice deve criar relacoes diretas da tabela para esses atributos.

Exemplos conceituais:

- `Table:AbateOrdem` pode resolver para `Attribute:AbateOrdemEmpresaId`
- `Table:AbateOrdem` pode resolver para `Attribute:AbateOrdemId`

### Fora do incremento 4

- usar membros de indice como composicao completa da tabela
- inferir atributos nao chave
- inferir chave estrangeira ou relacao runtime
- criar relacao para atributo ausente do inventario local
- tratar `<Members>/<Member>` como `table_key_attribute`

## Incremento 5 aprovado - resolver `Transaction` -> `Table` por `Level`

### Escopo aceito

- origem: objetos `Transaction`
- evidencia:
  - atributo `Type` de elementos estruturais `<Level>`
- destino resolvido:
  - `Table`, somente quando o valor de `Type` existir como tabela no inventario local
- regra proposta:
  - `transaction_level_table`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma `Transaction` declarar um `Level` cujo `Type` corresponda a uma `Table` existente, o indice deve criar relacao direta da transacao para a tabela.

Exemplos conceituais:

- `Transaction:AbateOrdem` com `Level Type="AbateOrdem"` pode resolver para `Table:AbateOrdem`
- `Transaction:AnimalParaAbate` nao deve resolver para `Table:AnimalParaAbate` se a tabela nao existir no inventario local

### Fora do incremento 5

- inferir tabela por nome da transacao
- criar relacao para subnivel sem tabela local correspondente
- inferir chave estrangeira, indice, navegacao ou comportamento runtime
- inferir composicao fisica completa de tabela
- criar relacao para tabela ausente do inventario local

## Incrementos futuros possiveis

No momento, manter novos itens como propostas explicitas antes de implementacao.

Cada um desses itens deve ter contrato incremental proprio antes de implementacao.

## Incremento 6 aprovado - resolver `Table` -> `Attribute` por membros de indice

### Escopo aceito

- origem: objetos `Table`
- evidencia:
  - elementos `<Member>` dentro de `Indexes`/`Index`
- destino resolvido:
  - `Attribute`, somente quando o membro existir como atributo no inventario local
- regra proposta:
  - `table_index_member_attribute`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma `Table` declarar um membro de indice cujo texto corresponda a um `Attribute` existente, o indice deve criar relacao direta da tabela para o atributo. A regra deve permanecer separada de `table_key_attribute`, pois chave primaria e participacao em indice sao evidencias estruturais diferentes.

Exemplos conceituais:

- `Table:AbateOrdem` com membro de indice `AbateOrdemData` pode resolver para `Attribute:AbateOrdemData`
- `Table:AbateOrdem` com membro de indice `AbateOrdemId` tambem pode resolver por esta regra, alem da relacao de chave primaria ja existente por `table_key_attribute`
- `Table:AbateOrdem` nao deve resolver para `Attribute:VolumeMovimentoId` se o atributo nao estiver declarado como membro de indice da tabela

### Fora do incremento 6

- criar objeto `Index` proprio
- inferir chave estrangeira, navegacao, cardinalidade ou plano SQL
- substituir ou remover a regra `table_key_attribute`
- prometer semantica funcional alem de participacao estrutural em indice

## Incremento 7 aprovado - resolver `SDT` -> `SDT` por `ATTCUSTOMTYPE` de item

### Escopo aceito

- origem: objetos `SDT`
- evidencia:
  - propriedade `ATTCUSTOMTYPE` dentro de elementos internos `<Item>`
- destino resolvido:
  - `SDT`, somente quando o valor tiver prefixo `sdt:` e o SDT existir no inventario local
- regra proposta:
  - `sdt_item_attcustomtype_resolved_sdt`
- confianca:
  - `direct`

### Comportamento esperado

Quando um item interno de `SDT` declarar `ATTCUSTOMTYPE` apontando para outro `SDT` existente, o indice deve criar relacao direta do `SDT` de origem para o `SDT` usado como tipo do item.

Exemplos conceituais:

- `SDT:CTe_cteProc` com item `sdt:CTe_TCTe` pode resolver para `SDT:CTe_TCTe`
- `SDT:CountryInfoServicetCountryCodeAndNameGroupedByContinent` com item `sdt:CountryInfoServicetContinent` pode resolver para `SDT:CountryInfoServicetContinent`
- `SDT:Context` com itens `bas:*` nao deve gerar relacao `SDT` -> `SDT`

### Fora do incremento 7

- criar objeto proprio para membro de `SDT`
- resolver tipos `bas:*`
- resolver `Domain` a partir de item de `SDT` sem evidencia real aprovada
- inferir uso runtime, serializacao ou contrato de API
- expandir estrutura interna completa do `SDT`

## Incremento 8 aprovado - resolver `Procedure`/`WebPanel` -> `Table` por `for each` explicito

### Escopo aceito

- origem: objetos `Procedure` e `WebPanel`
- evidencia:
  - linha de `Source` efetivo contendo `for each <Nome>` explicito
- destino resolvido:
  - `Table`, somente quando `<Nome>` existir como tabela no inventario local
- regra proposta:
  - `source_for_each_explicit_table`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo declarar `for each <Nome>` e `<Nome>` existir como `Table`, o indice deve criar relacao direta da origem para a tabela. Essa relacao representa evidencia estrutural de navegacao declarada no `Source`; ela nao promete comportamento runtime completo, plano SQL, joins, indice usado ou tabela base inferida pelo especificador GeneXus.

Exemplos conceituais:

- `Procedure:procAnimaisContagemDeUmPeriodo` com `for each Animal` pode resolver para `Table:Animal`
- `WebPanel:wcVolumeMovimentosComReferenciaAoRomaneio` com `for each VolumeMovimento` pode resolver para `Table:VolumeMovimento`
- `Procedure:procImportaPedidosDaCarga` com `for each RetornoPedido` nao deve resolver para `Table:RetornoPedido` se a tabela nao existir no inventario local

### Fora do incremento 8

- `for each` sem alvo explicito
- alvo qualificado ou subnivelado como `for each CompraGadoItens.Faixas`
- resolver tabela por atributos em `where`
- inferir tabela base escolhida pelo especificador GeneXus
- inferir join, navegacao completa, indice usado ou plano SQL
- resolver nomes que parecam `Transaction` mas nao tenham `Table` local, como `RetornoPedido`, `RetornoPedidoItens` e `AnimalParaAbate`

## Incremento 9 aprovado - resolver prefixo de `for each` qualificado

### Escopo aceito

- origem: objetos `Procedure` e `WebPanel`
- evidencia:
  - linha de `Source` efetivo contendo `for each <Nome>.<Membro>`
- destino resolvido:
  - `Table`, somente quando `<Nome>` existir como tabela no inventario local
- regra proposta:
  - `source_for_each_qualified_table_prefix`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo declarar `for each <Nome>.<Membro>` e `<Nome>` existir como `Table`, o indice deve criar relacao direta da origem para a tabela do prefixo. O alvo qualificado completo permanece no `snippet` da evidencia.

Essa relacao representa evidencia estrutural de navegacao qualificada declarada no `Source`. Ela nao transforma `<Membro>` em tabela propria, nao resolve subnivel como objeto independente e nao promete comportamento runtime completo.

Exemplos conceituais:

- `Procedure:procAnimalValorPelaCompra` com `for each CompraGadoItens.Faixas` pode resolver para `Table:CompraGadoItens`
- `Procedure:procCondicaoPagamentoPrazoMedio` com `for each CondicaoPagamento.Parcelas` pode resolver para `Table:CondicaoPagamento`
- `for each CompraGadoItens.Faixas` nao deve criar relacao para `Table:Faixas`

### Fora do incremento 9

- criar objeto proprio para `<Membro>`
- resolver `<Membro>` como tabela, atributo, subnivel ou indice
- inferir tabela fisica do subnivel qualificado
- inferir join, navegacao completa, indice usado ou plano SQL
- resolver prefixo que nao exista como `Table` local

## Incremento 10 aprovado - resolver `.Load(...)` de Business Component para `Transaction`

### Escopo aceito

- origem: objetos `Procedure`, `WebPanel` e `DataProvider`
- evidencia:
  - linha de `Source` efetivo contendo `&Variavel.Load(...)`
  - declaracao da variavel com `ATTCUSTOMTYPE` resolvido como `bc:<Transaction>`
- destino resolvido:
  - `Transaction`, somente quando a transacao existir no inventario local
- regra proposta:
  - `source_bc_load_transaction`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo chamar `.Load(...)` em uma variavel cujo `ATTCUSTOMTYPE` seja `bc:<Nome>` e `<Nome>` exista como `Transaction`, o indice deve criar relacao direta da origem para a `Transaction`.

Essa relacao representa evidencia estrutural de carga de Business Component no `Source`. Ela nao resolve tabela fisica, nao promete sucesso da carga, nao interpreta parametros de chave e nao prova comportamento runtime completo.

Exemplos conceituais:

- `Procedure:procAjustaCompraGadoIdDeAnimais` com `&animal.Load(...)` e variavel `bc:Animal` pode resolver para `Transaction:Animal`
- `WebPanel:WCAbateOrdemAnimal` com `&AbateOrdem.Load(...)` e variavel `bc:AbateOrdem` pode resolver para `Transaction:AbateOrdem`
- `Procedure:procCargaMudaDataDePedidos` com `&RetornoPedido.Load(...)` e variavel `bc:RetornoPedido` pode resolver para `Transaction:RetornoPedido` mesmo sem `Table:RetornoPedido`

### Fora do incremento 10

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Load(...)` de `SDT`, `ExternalObject`, GAM externo ou outro tipo nao `Transaction`
- resolver tabela fisica, chave, sucesso da carga, save posterior ou comportamento runtime
- interpretar `Grid.Load(...)` ou chamadas sem receptor de variavel GeneXus

## Incremento 11 aprovado - resolver `.Save()` de Business Component para `Transaction`

### Escopo aceito

- origem: objetos `Procedure`, `WebPanel` e `DataProvider`
- evidencia:
  - linha de `Source` efetivo contendo `&Variavel.Save()`
  - declaracao da variavel com `ATTCUSTOMTYPE` resolvido como `bc:<Transaction>`
- destino resolvido:
  - `Transaction`, somente quando a transacao existir no inventario local
- regra proposta:
  - `source_bc_save_transaction`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo chamar `.Save()` em uma variavel cujo `ATTCUSTOMTYPE` seja `bc:<Nome>` e `<Nome>` exista como `Transaction`, o indice deve criar relacao direta da origem para a `Transaction`.

Essa relacao representa evidencia estrutural de persistencia via Business Component no `Source`. Ela nao prova sucesso da gravacao, commit, rollback, validacoes disparadas, mensagens de erro ou comportamento runtime completo.

Exemplos conceituais:

- `Procedure:procAjustaCompraGadoIdDeAnimais` com `&animal.Save()` e variavel `bc:Animal` pode resolver para `Transaction:Animal`
- `WebPanel:wpEmbarqueSaida` com `&VendaPedido.Save()` e variavel `bc:VendaPedido` pode resolver para `Transaction:VendaPedido`
- `Procedure:ExportWWOperacaoAjustada` com `&ExcelDocument.Save()` nao deve criar relacao para `Transaction:ExcelDocument`

### Fora do incremento 11

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Save()` de `ExternalObject`, documentos, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Delete()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da gravacao ou comportamento runtime

## Fora do escopo geral da Fase 5

- suporte funcional por agentes
- chat ou RAG
- inferencia funcional sem evidencia direta ou regra aprovada
- prova de comportamento runtime completo
- alterar a fonte normativa `ObjetosDaKbEmXml`

## Gate minimo por incremento

Cada incremento da Fase 5 so deve ser considerado pronto quando:

- a regra de extracao estiver nomeada
- o papel da evidencia estiver definido
- houver casos reais positivos
- houver casos reais negativos
- a bateria da Fase 2 continuar passando
- a bateria da Fase 3 continuar passando
- a bateria da Fase 4 continuar passando
- a nova bateria do incremento passar com `-FailOnValidationFailure`
- a documentacao operacional estiver atualizada

## Artefatos esperados por incremento

- atualizacao de `scripts/New-KbIntelligenceIndex.py`
- casos de validacao pequenos do incremento
- atualizacao de `scripts/README-kb-intelligence.md`
- registro historico de encerramento do incremento ou da fase

## Relacao com Fase 6

A Fase 6 deve tratar suporte funcional por agentes e deve ser aberta preferencialmente em conversa nova. A Fase 5 prepara relacoes tecnicas mais ricas, mas nao deve tentar responder sozinha perguntas funcionais amplas.
