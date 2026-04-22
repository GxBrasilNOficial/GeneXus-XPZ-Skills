# 22 - KB Intelligence Fase 6 - Contrato de Consulta `functional-trace-basic`

## Papel do documento
contrato operacional de consulta

## Nivel de confianca predominante
baixo a medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md, 20-kb-intelligence-fase-6-piloto-investigacao-funcional.md, 21-kb-intelligence-fase-6-checklist-operacional-agente.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem avaliar ou implementar uma consulta auxiliar para montar trilha funcional basica sem produzir conclusao funcional automatica

## Objetivo
Definir a consulta auxiliar `functional-trace-basic`, para empacotar a coleta inicial de trilha funcional assistida:

- localizar objeto principal
- listar dependentes diretos relevantes
- listar dependencias diretas relevantes
- trazer evidencias tecnicas selecionadas
- indicar XMLs oficiais que devem ser abertos
- declarar limite metodologico da resposta

A consulta nao deve interpretar regra de negocio, nao deve inferir comportamento runtime e nao deve substituir a leitura do XML oficial.

## Estado

Implementada em 2026-04-22 nos scripts de consulta do KB Intelligence, sem alterar schema do SQLite e sem ampliar extracao.

## Problema que a consulta resolve

Na Fase 6, o agente frequentemente repete a mesma sequencia:

1. `object-info`
2. `impact-basic`
3. selecao manual de relacoes relevantes
4. `show-evidence`
5. abertura pontual do XML oficial

`functional-trace-basic` pode reduzir custo operacional dessa coleta, mas deve continuar sendo uma ferramenta de triagem, nao uma ferramenta de conclusao funcional.

## Entrada proposta

Campos minimos:

- `ObjectType`
- `ObjectName`
- `Limit`
- `Format`

Campos opcionais futuros:

- `RelationKind`
- `TargetType`
- `IncludeIncoming`
- `IncludeOutgoing`
- `EvidenceLimit`

## Saida proposta

### `object`

Dados do objeto principal:

- `type`
- `name`
- `file_path`
- `last_update`
- `found`

### `technical_trace`

Lista curta de relacoes tecnicas:

- direcao: `incoming` ou `outgoing`
- origem com `tipo + nome`
- destino com `tipo + nome`
- `relation_kind`
- `confidence`
- `extractor_rule`
- `evidence_role`
- `source_file`
- `line`
- `snippet`

### `xml_reading_plan`

Lista de XMLs que o agente deve abrir antes de concluir funcionalmente:

- arquivo relativo
- motivo da abertura
- relacao que motivou a leitura
- limite do que o indice ja provou

### `response_contract`

Bloco fixo lembrando que a resposta final deve separar:

- `Evidencia direta`
- `Leitura adicional do XML`
- `Inferencia forte`
- `Hipotese`

### `notice`

Mensagem obrigatoria:

`Triagem funcional basica baseada em indice tecnico derivado. Nao representa prova funcional completa nem substitui leitura do XML oficial.`

## Regras de selecao inicial

A primeira implementacao, se aprovada, deve ser conservadora:

- usar somente dados ja disponiveis no indice
- nao ampliar extracao
- nao abrir XML automaticamente
- nao classificar regra de negocio
- limitar quantidade de relacoes por `Limit`
- preservar `impact-basic` e `show-evidence` como comandos independentes

## Fora do escopo

- sintetizar regra funcional completa
- gerar resumo narrativo de modulo
- navegar cadeia profunda automaticamente
- inferir fluxo runtime
- afirmar obrigatoriedade de chamada
- substituir `Source`, `Rules`, eventos ou propriedades do XML oficial
- alterar schema sem necessidade explicita
- alterar o indice canonico durante consulta

## Gate minimo de validacao

Antes de considerar a consulta operacional, confirmar:

- `impact-basic` continua funcionando sem regressao
- `show-evidence` continua funcionando sem regressao
- a consulta nova pode ser testada por casos pequenos reais
- a saida deixa claro que e triagem tecnica
- a saida nao usa linguagem de prova funcional
- os exemplos da Fase 6 continuam coerentes com o novo comando

## Casos reais minimos para teste

### Caso 1

- entrada: `WorkWithForWeb:WorkWithWebAbateOrdem`
- deve indicar leitura de `WorkWithForWeb/WorkWithWebAbateOrdem.xml`
- deve trazer pelo menos relacao para `Transaction:AbateOrdem` ou `Procedure:procLeEmpresaSessao`

### Caso 2

- entrada: `Procedure:procAjustaCompraGadoIdDeAnimais`
- deve indicar leitura de `Procedure/procAjustaCompraGadoIdDeAnimais.xml`
- deve trazer relacao para `Transaction:Animal` por BC `.Load(...)` ou `.Save()`

### Caso 3

- entrada: `API:apiPDV_Integracao`
- deve indicar leitura de `API/apiPDV_Integracao.xml`
- deve trazer relacao para `SDT:sdtProdutoDadosBasicos`

## Decisao operacional

Usar `functional-trace-basic` somente quando o objetivo for reduzir repeticao operacional de consulta. Se o objetivo for responder uma unica pergunta funcional simples, o checklist da Fase 6 continua suficiente.

Mesmo implementada, a consulta deve continuar sendo auxiliar de agente. A conclusao funcional final permanece fora do script e deve ser escrita pelo agente apos leitura do XML oficial.
