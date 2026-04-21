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

## Incrementos futuros possiveis

- `Attribute` -> `Domain`
- `Transaction` -> `Attribute`
- `Transaction` -> `Table`
- `Table` -> `Attribute`
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
