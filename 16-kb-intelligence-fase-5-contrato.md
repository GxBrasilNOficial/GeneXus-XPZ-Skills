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

- `Table` -> `Attribute` por membros de indice, com regra separada de chave primaria
- `SDT` -> membros ou tipos internos
- relacoes por `for each`, com classificacao separada e cautela runtime
- relacoes por `.Load(...)`, com classificacao separada e cautela runtime

Cada um desses itens deve ter contrato incremental proprio antes de implementacao.

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
