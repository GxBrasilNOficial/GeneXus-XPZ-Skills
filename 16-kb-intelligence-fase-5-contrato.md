# 16 - KB Intelligence Fase 5 - Contrato

## Papel do documento
contrato operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
11-plano-kb-intelligence-incremental.md, historico/kb-intelligence/15-kb-intelligence-fase-4-contrato.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem ampliar relacoes semanticas do KB Intelligence depois do inventario completo de tipos

## Objetivo
Definir a Fase 5 do KB Intelligence como ampliacao incremental de relacoes semanticas no SQLite.

A Fase 5 deve evoluir a camada de relacoes sem misturar inventario, inferencia runtime e suporte funcional. Cada nova familia de relacao deve entrar por incremento pequeno, com regra nomeada, evidencia rastreavel, casos positivos, casos negativos e teste de regressao.

Para abrir incremento novo, nao basta contagem bruta de ocorrencias ou plausibilidade por nome. A proposta deve trazer casos reais positivos e negativos extraidos do acervo, em amostra curta e auditavel, suficientes para sustentar o contrato antes de qualquer alteracao de codigo.

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

## Incremento 12 aprovado - resolver `.Delete()` de Business Component para `Transaction`

### Escopo aceito

- origem: objetos `Procedure`, `WebPanel` e `DataProvider`
- evidencia:
  - linha de `Source` efetivo contendo `&Variavel.Delete()`
  - declaracao da variavel com `ATTCUSTOMTYPE` resolvido como `bc:<Transaction>`
- destino resolvido:
  - `Transaction`, somente quando a transacao existir no inventario local
- regra proposta:
  - `source_bc_delete_transaction`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo chamar `.Delete()` em uma variavel cujo `ATTCUSTOMTYPE` seja `bc:<Nome>` e `<Nome>` exista como `Transaction`, o indice deve criar relacao direta da origem para a `Transaction`.

Essa relacao representa evidencia estrutural de exclusao via Business Component no `Source`. Ela nao prova sucesso da exclusao, commit, rollback, validacoes disparadas, mensagens de erro ou comportamento runtime completo.

Exemplos conceituais:

- `Procedure:procApagaEstoqueMovimentoDiarioSemControle` com `&EstoqueMovimentoDiario.Delete()` e variavel `bc:EstoqueMovimentoDiario` pode resolver para `Transaction:EstoqueMovimentoDiario`
- `Procedure:procCrudMsforn` com `&pessoaemail.Delete()` e variavel `bc:PessoaE_Mails` pode resolver para `Transaction:PessoaE_Mails`
- `Procedure:procApagaArquivoFisico` com `&File.Delete()` nao deve criar relacao para `Transaction:File`

### Fora do incremento 12

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Delete()` de `File`, `Directory`, `ExternalObject`, documentos, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Save()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da exclusao ou comportamento runtime

## Incremento 13 aprovado - resolver `.Check()` de Business Component para `Transaction`

### Escopo aceito

- origem: objetos `Procedure`, `WebPanel` e `DataProvider`
- evidencia:
  - linha de `Source` efetivo contendo `&Variavel.Check()`
  - declaracao da variavel com `ATTCUSTOMTYPE` resolvido como `bc:<Transaction>`
- destino resolvido:
  - `Transaction`, somente quando a transacao existir no inventario local
- regra proposta:
  - `source_bc_check_transaction`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo chamar `.Check()` em uma variavel cujo `ATTCUSTOMTYPE` seja `bc:<Nome>` e `<Nome>` exista como `Transaction`, o indice deve criar relacao direta da origem para a `Transaction`.

Essa relacao representa evidencia estrutural de validacao/verificacao via Business Component no `Source`. Ela nao prova sucesso da validacao, persistencia, commit, rollback, mensagens de erro ou comportamento runtime completo.

Exemplos conceituais:

- `WebPanel:wpTitulo3` com `&alteracaoLancamento.Check()` e variavel `bc:Lancamento` pode resolver para `Transaction:Lancamento`
- `Procedure:procAtualizaDuplicatasDoDocumentoFiscal` com `&documentofiscalduplicata.Check()` e variavel `bc:DocumentoFiscalDuplicata` pode resolver para `Transaction:DocumentoFiscalDuplicata`
- `WebPanel:GAMExampleApplicationEntry` com `&GAMApplication.Check()` nao deve criar relacao para `Transaction:GAMApplication`

### Fora do incremento 13

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Check()` de `ExternalObject`, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Save()`, `.Delete()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da validacao ou comportamento runtime

## Incremento 14 aprovado - resolver `.Insert()` e `.Update()` de Business Component simples para `Transaction`

### Escopo aceito

- origem: objetos `Procedure`, `WebPanel` e `DataProvider`
- evidencia:
  - linha de `Source` efetivo contendo `&Variavel.Insert()` ou `&Variavel.Update()`
  - declaracao da variavel com `ATTCUSTOMTYPE` resolvido como `bc:<Transaction>`
  - variavel sem `AttCollection=True`
- destino resolvido:
  - `Transaction`, somente quando a transacao existir no inventario local
- regras propostas:
  - `source_simple_bc_insert_transaction`
  - `source_simple_bc_update_transaction`
- confianca:
  - `direct`

### Comportamento esperado

Quando uma linha de `Source` efetivo chamar `.Insert()` ou `.Update()` em uma variavel simples cujo `ATTCUSTOMTYPE` seja `bc:<Nome>` e `<Nome>` exista como `Transaction`, o indice deve criar relacao direta da origem para a `Transaction`.

Essa relacao representa evidencia estrutural de insercao ou atualizacao via Business Component simples no `Source`. Ela nao prova sucesso da operacao, commit, rollback, mensagens de erro ou comportamento runtime completo.

Exemplos conceituais:

- `Procedure:procCancelaVolumeMovimento` com `&VolumeMovimento.Update()` e variavel `bc:VolumeMovimento` pode resolver para `Transaction:VolumeMovimento`
- `Procedure:procGeraVendaPedidoDoQueNaoFoiCarregado` com `&novovendapedido.Insert()` e variavel `bc:VendaPedido` pode resolver para `Transaction:VendaPedido`
- `Procedure:procCarregaBandeiraDeCartao` com `&listaBandeiraDeCartao.Insert()` e variavel `AttCollection=True` nao deve entrar neste incremento

### Fora do incremento 14

- variaveis com `AttCollection=True`
- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Insert()` ou `.Update()` de `ExternalObject`, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da insercao/atualizacao ou comportamento runtime

## Incremento 15 aprovado - resolver `exo:` de `ATTCUSTOMTYPE` para `ExternalObject`

### Escopo aceito

- origem: objetos ja cobertos por `ATTCUSTOMTYPE` na Fase 2
- evidencia:
  - `Property ATTCUSTOMTYPE`
- destino resolvido:
  - `ExternalObject`, somente quando o valor tiver prefixo `exo:` e o nome do objeto existir no inventario local
- regra proposta:
  - `attcustomtype_resolved_object`
- confianca:
  - `direct`

### Comportamento esperado

Quando `ATTCUSTOMTYPE` apontar para valor com prefixo `exo:` e o nome antes de eventual sufixo apos virgula corresponder a um `ExternalObject` existente no inventario local, o indice deve criar relacao resolvida para `ExternalObject`.

Essa relacao representa evidencia estrutural de tipo externo declarado em propriedade. Ela nao prova chamada efetiva de metodo, dependencia runtime completa, carga de modulo externo nem disponibilidade do provider fora do inventario local.

Exemplos conceituais:

- `Procedure:procBuscaCoordenadasDeUmBairro` com `exo:MapLinkAddressFinder` pode resolver para `ExternalObject:MapLinkAddressFinder`
- `Procedure:procExtraiArquivosDoZip` com `exo:ZipFile` pode resolver para `ExternalObject:ZipFile`
- `Procedure:GAM_CheckUserActivationMethod` com `exo:GAMApplication, GeneXusSecurity` nao deve resolver se `ExternalObject:GAMApplication` nao existir no inventario local

### Fora do incremento 15

- inferir `ExternalObject` pelo nome da variavel, receptor ou metodo chamado
- resolver `ext:*` para `ExternalObject`
- criar relacao para nomes `exo:` ausentes do inventario local
- inferir modulo, namespace, provider ou vendor a partir do sufixo apos virgula
- provar uso runtime efetivo do `ExternalObject`

## Incremento 16 aprovado - ampliar `ATTCUSTOMTYPE` resolvido para origem `API` e `DataSelector`

### Escopo aceito

- origem:
  - `API`
  - `DataSelector`
- evidencia:
  - `Property ATTCUSTOMTYPE`
- destino resolvido:
  - `SDT`, somente quando o valor tiver prefixo `sdt:` e o objeto existir no inventario local
- regra proposta:
  - `attcustomtype_resolved_object`
- confianca:
  - `direct`

### Comportamento esperado

Quando um objeto `API` ou `DataSelector` declarar `ATTCUSTOMTYPE` com prefixo `sdt:` apontando para um `SDT` existente no inventario local, o indice deve criar relacao resolvida para esse `SDT`.

Essa relacao representa evidencia estrutural de tipo declarado em propriedade. Ela nao prova serializacao efetiva, contrato runtime completo, uso funcional do tipo nem disponibilidade de tipos externos fora do inventario local.

Exemplos conceituais:

- `API:apiPDV_Integracao` com `sdt:sdtProdutoDadosBasicos` pode resolver para `SDT:sdtProdutoDadosBasicos`
- `API:apiPDV_Integracao` com `sdt:sdtTributacaoDadosBasicosSelecao` pode resolver para `SDT:sdtTributacaoDadosBasicosSelecao`
- `DataSelector:dsRelatoriosDeTitulosViaLancamentos` com `sdt:sdtTituloParametros` pode resolver para `SDT:sdtTituloParametros`
- `API:apiPDV_Integracao` com `sdt:Messages, GeneXus.Common` nao deve resolver se `SDT:Messages, GeneXus.Common` nao existir no inventario local

### Fora do incremento 16

- ampliar a origem para `SDT`, `Domain`, `Attribute`, `PackagedModule` ou outros tipos fora deste recorte
- resolver `bas:*`, `ext:*` ou `exo:*` adicionais por esta ampliacao de origem
- inferir `SDT` pelo nome da variavel, parametro ou metodo
- criar relacao para `SDT` ausente do inventario local
- provar uso runtime efetivo do `SDT`

## Incremento 17 aprovado - ampliar `ATTCUSTOMTYPE` resolvido para origem `Domain`

### Escopo aceito

- origem:
  - `Domain`
- evidencia:
  - `Property ATTCUSTOMTYPE`
- destino resolvido:
  - `SDT`, somente quando o valor tiver prefixo `sdt:` e o objeto existir no inventario local
- regra proposta:
  - `attcustomtype_resolved_object`
- confianca:
  - `direct`

### Comportamento esperado

Quando um objeto `Domain` declarar `ATTCUSTOMTYPE` com prefixo `sdt:` apontando para um `SDT` existente no inventario local, o indice deve criar relacao resolvida para esse `SDT`.

Essa relacao representa evidencia estrutural de tipo declarado em propriedade. Ela nao prova serializacao efetiva, contrato runtime completo, uso funcional do tipo nem disponibilidade de tipos externos fora do inventario local.

Exemplos conceituais:

- `Domain:BCBwscmArrayOffWSSerieVO` com `sdt:sdtBCBwscmWSSerieVO` pode resolver para `SDT:sdtBCBwscmWSSerieVO`
- `Domain:CountryInfoServiceArrayOftContinent` com `sdt:CountryInfoServicetContinent` pode resolver para `SDT:CountryInfoServicetContinent`
- `Domain:CountryInfoServiceArrayOftCountryCodeAndName` com `sdt:CountryInfoServicetCountryCodeAndName` pode resolver para `SDT:CountryInfoServicetCountryCodeAndName`
- `Domain:FB_APIs` com `sdt:Messages, GeneXus.Common` nao deve resolver se `SDT:Messages, GeneXus.Common` nao existir no inventario local

### Fora do incremento 17

- ampliar a origem para `SDT`, `Attribute`, `PackagedModule` ou outros tipos fora deste recorte
- resolver `bas:*`, `ext:*` ou `exo:*` adicionais por esta ampliacao de origem
- inferir `SDT` pelo nome do dominio, variavel, parametro ou metodo
- criar relacao para `SDT` ausente do inventario local
- provar uso runtime efetivo do `SDT`

## Incremento 18 aprovado - ampliar `ATTCUSTOMTYPE` resolvido para origem `SDT` top-level

### Escopo aceito

- origem:
  - `SDT`
- evidencia:
  - `Property ATTCUSTOMTYPE` top-level do objeto
- destino resolvido:
  - `SDT`, somente quando o valor tiver prefixo `sdt:` e o objeto existir no inventario local
- regra proposta:
  - `attcustomtype_resolved_object`
- confianca:
  - `direct`

### Comportamento esperado

Quando um objeto `SDT` declarar `ATTCUSTOMTYPE` top-level com prefixo `sdt:` apontando para um `SDT` existente no inventario local, o indice deve criar relacao resolvida para esse `SDT`.

Essa relacao representa evidencia estrutural de tipo declarado em propriedade no nivel do proprio `SDT`. Ela nao prova serializacao efetiva, uso funcional completo nem substitui a regra separada de item interno de `SDT`.

Exemplos conceituais:

- `SDT:ActionGroupItem` com `sdt:ActionGroupItem` pode resolver para `SDT:ActionGroupItem`
- `SDT:CountryInfoServicetCountryCodeAndNameGroupedByContinent` com `sdt:CountryInfoServicetContinent` pode resolver para `SDT:CountryInfoServicetContinent`
- `SDT:CTe_cteProc` com `sdt:CTe_TCTe` pode resolver para `SDT:CTe_TCTe`
- `SDT:Context` com tipos `bas:*` nao deve resolver para `SDT`

### Fora do incremento 18

- item interno de `SDT`, que continua coberto separadamente por `sdt_item_attcustomtype_resolved_sdt`
- ampliar a origem para `Attribute`, `PackagedModule` ou outros tipos fora deste recorte
- resolver `bas:*`, `ext:*` ou `exo:*` adicionais por esta ampliacao de origem
- inferir `SDT` por nome de variavel, parametro, membro ou metodo
- criar relacao para `SDT` ausente do inventario local
- provar uso runtime efetivo do `SDT`

## Posicao consolidada apos o incremento 18

O eixo incremental de `ATTCUSTOMTYPE` ficou metodologicamente maduro ate o limite de sinal forte encontrado no acervo atual da KB `KBExemplo`.

Depois do incremento 18, a triagem adicional indicou:

- leitura agregada de `ATTCUSTOMTYPE` sem separar prefixos produz ruido excessivo para decisao incremental; a triagem correta deve agrupar primeiro por prefixo real observado no acervo
- prefixos com semanticas diferentes, como `bas:`, `sdt:`, `bc:`, `exo:` e `ext:`, nao devem compartilhar a mesma hipotese de incremento apenas por coexistirem na mesma propriedade
- depois de separar por prefixo, ainda e obrigatorio medir resolucao real contra o inventario local; prefixo com sinal textual promissor nao equivale automaticamente a alvo resolvido
- `Attribute`, `PackagedModule` e `Stencil` ainda possuem ocorrencias brutas de `ATTCUSTOMTYPE`, mas sem novos alvos resolviveis com a mesma regra conservadora hoje usada para `SDT`, `Domain` e `ExternalObject`
- `ext:*` continua relevante como valor literal de propriedade, mas nao como alvo resolvido para objeto local do inventario
- `Success()`, `Fail()` e `GetMessages()` em variavel `bc:*` nao abriram novos pares `origem -> Transaction` fora dos pares ja cobertos por `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()` e `.Update()`

Medicao consolidada da triagem de BC em `Procedure`, `WebPanel` e `DataProvider`:

- `Success()`: `371` ocorrencias, `280` pares unicos resolviveis, `0` pares unicos fora da cobertura forte ja existente
- `Fail()`: `48` ocorrencias, `43` pares unicos resolviveis, `0` pares unicos fora da cobertura forte ja existente
- `GetMessages()`: `419` ocorrencias, `306` pares unicos resolviveis, `0` pares unicos fora da cobertura forte ja existente

Conclusao operacional:

- nao aprovar incremento 19 apenas para `Success()`, `Fail()` ou `GetMessages()`
- nao aprovar novo incremento de `ATTCUSTOMTYPE` apenas por massa bruta agregada; antes disso, separar a amostra por prefixo e confirmar qual prefixo ainda preserva sinal estrutural forte
- nao tratar prefixos proximos, como `exo:` e `ext:`, como candidatos equivalentes sem medir separadamente a resolucao efetiva de cada um no inventario local
- nao ampliar `ATTCUSTOMTYPE` resolvido para novos tipos de origem sem evidencia estrutural nova e casos reais adicionais
- tratar a subtrilha atual como consolidada, e nao como aberta para extensao mecanica

Se houver continuacao da Fase 5 depois deste ponto, ela deve entrar por familia nova de relacao ou por contrato explicito de evidencia mais fraca, com justificativa propria.

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

- atualizacao de `scripts/Build-KbIntelligenceIndex.py`
- casos de validacao pequenos do incremento
- atualizacao de `scripts/README-kb-intelligence.md`
- registro historico de encerramento do incremento ou da fase

## Relacao com Fase 6

A Fase 6 deve tratar suporte funcional por agentes e deve ser aberta preferencialmente em conversa nova. A Fase 5 prepara relacoes tecnicas mais ricas, mas nao deve tentar responder sozinha perguntas funcionais amplas.
