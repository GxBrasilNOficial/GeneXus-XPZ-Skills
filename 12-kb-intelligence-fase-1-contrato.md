# 12 - KB Intelligence Fase 1 - Contrato

## Papel do documento
contrato operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
11-plano-kb-intelligence-incremental.md, 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md, xpz-doc-builder/SKILL.md

## Usado por
agentes que forem implementar, revisar ou validar a primeira fase do indice tecnico reutilizavel para pastas paralelas de KB GeneXus

## Objetivo
Definir o contrato minimo da Fase 1 do KB Intelligence antes da implementacao de scripts, garantindo que a primeira entrega seja pequena, auditavel e validada por casos reais.

Este documento nao implementa o indice. Ele define o que a implementacao futura deve cumprir.

## Escopo da Fase 1

### Origens indexadas

- `Procedure`
- `WebPanel`

### Destinos reconhecidos

- `Procedure`
- `WebPanel`

### Relacoes reconhecidas

- chamada direta de `Procedure`
- navegacao/chamada direta de `WebPanel`

### Fora do escopo inicial

- `Transaction`
- `WorkWithForWeb`
- `DataProvider`
- `SDT`
- `Domain`
- `for each`
- `.Load(...)`
- actions estruturadas de `WorkWithForWeb`
- RAG
- chat
- documentacao funcional para humanos

Esses itens podem entrar em fases posteriores, sempre com exemplos positivos, exemplos negativos e teste de regressao.

## Fonte normativa

A fonte normativa e a pasta `ObjetosDaKbEmXml` da pasta paralela da KB, alimentada por export oficial da IDE do GeneXus e pelo fluxo de sincronizacao local.

O indice tecnico e artefato derivado e reconstruivel. Ele nao substitui os XMLs oficiais.

## Parametros obrigatorios da implementacao

Qualquer script futuro desta fase deve receber caminhos por parametro explicito.

Parametros minimos esperados:

- `-SourceRoot`: raiz do acervo XML, normalmente `...\ObjetosDaKbEmXml`
- `-OutputPath`: caminho do SQLite gerado
- `-ValidationReportPath`: caminho opcional para relatorio pequeno de validacao
- `-ValidationCasesPath`: caminho opcional para casos de validacao da KB atual
- `-FailOnValidationFailure`: falhar com exit code diferente de zero quando algum caso de validacao falhar

O script nao deve depender de caminho absoluto privado como valor fixo.

## Implementacao inicial

A primeira implementacao operacional da Fase 1 fica em:

- `scripts/New-KbIntelligenceIndex.ps1`
- `scripts/New-KbIntelligenceIndex.py`
- `scripts/Query-KbIntelligenceIndex.ps1`
- `scripts/Query-KbIntelligenceIndex.py`
- `scripts/kb-intelligence-fabricabrasil.phase1.validation-cases.json`
- `scripts/README-kb-intelligence.md`

Os wrappers PowerShell preservam o padrao operacional atual do repositorio. Os motores Python usam `sqlite3` da biblioteca padrao para gravar e consultar o banco tecnico.

Os casos de validacao ficam fora do motor generico. O arquivo de casos de `FabricaBrasil` existe como laboratorio explicito da Fase 1, nao como requisito universal para outras KBs.

## Artefato principal

O artefato principal da Fase 1 deve ser um banco SQLite.

O SQLite deve ser tratado como derivado e regeneravel. Por padrao, ele nao deve ser versionado em Git.

## Schema minimo

### Tabela `objects`

Campos obrigatorios:

- `object_id`
- `type`
- `name`
- `file_path`
- `last_update`
- `file_hash`

Restricoes esperadas:

- `type` + `name` deve identificar o objeto dentro do acervo indexado
- `file_path` deve ser relativo ao `SourceRoot` quando possivel
- `file_hash` deve permitir detectar mudanca de conteudo entre execucoes
- nomes que colidam apenas por maiusculas/minusculas devem bloquear a resolucao case-insensitive ate decisao explicita

### Tabela `relations`

Campos obrigatorios:

- `relation_id`
- `source_object_id`
- `target_type`
- `target_name`
- `relation_kind`
- `evidence_id`
- `confidence`

Valores iniciais de `relation_kind`:

- `calls_procedure`
- `calls_webpanel`

Valores iniciais de `confidence`:

- `direct`
- `candidate`

Na Fase 1, o esperado e gravar apenas relacoes `direct`. `candidate` fica reservado para testes controlados e nao deve alimentar respostas operacionais sem aviso explicito.

### Tabela `evidence`

Campos obrigatorios:

- `evidence_id`
- `source_file`
- `line`
- `column`
- `snippet`
- `evidence_role`
- `extractor_rule`

Valores iniciais de `evidence_role`:

- `Source efetivo`

Valores iniciais de `extractor_rule`:

- `procedure_direct_call`
- `procedure_dot_call`
- `webpanel_dot_link`

## Regras de evidencia

Toda relacao gravada deve ter evidencia associada.

A evidencia deve apontar para o arquivo XML de origem e para a linha calculada a partir do arquivo salvo.

A linha deve ser exata quando a chamada aparecer textualmente no XML salvo. Se a linha vier de trecho extraido e normalizado, a implementacao deve registrar isso explicitamente no relatorio de validacao antes de ser aceita como pronta.

O trecho em `snippet` deve ser curto e suficiente para auditoria. Nao deve copiar blocos grandes de `Source`.

## Padroes aceitos na Fase 1

### `procedure_direct_call`

Captura chamadas como:

```text
procNome(...)
```

Regras:

- deve ocorrer em `Source` efetivo
- deve ignorar linha inteiramente comentada por `//`
- deve ignorar trecho comentado inline depois de `//`
- deve ignorar texto dentro de layout visual que nao seja `Source` efetivo

### `procedure_dot_call`

Captura chamadas como:

```text
procNome.Call(...)
```

Regras:

- deve ocorrer em `Source` efetivo
- deve reconhecer o nome completo da procedure antes de `.Call`
- deve produzir relacao `calls_procedure`
- deve guardar linha e snippet da chamada

### `webpanel_dot_link`

Captura navegacao/chamada como:

```text
WWNome.Link(...)
WebPanelNome.Link(...)
```

Regras:

- deve ocorrer em `Source` efetivo
- deve produzir relacao `calls_webpanel`
- deve confirmar que o destino existe como `WebPanel` no acervo antes de gravar como `direct`

## Padroes bloqueados na Fase 1

Os seguintes padroes nao devem alimentar relacoes operacionais nesta fase:

- chamada por variavel
- chamada dinamica
- inferencia por nome parecido
- chamada encontrada apenas em comentario
- chamada encontrada apenas em layout HTML/XML visual
- chamada de `WebPanelNome(...)` sem validacao posterior especifica
- `for each` e `.Load(...)`

Se forem detectados durante desenvolvimento, devem ir para relatorio como candidatos ou pendencias, nao para relacoes diretas.

## Consultas minimas

A implementacao futura deve expor pelo menos estas consultas:

### `search-objects`

Entrada:

- `ObjectName`: nome, trecho de nome ou padrao com `*`
- `ObjectType` opcional
- `Limit` opcional
- `Format` opcional: `json` ou `text`

Saida minima:

- tipo e nome do objeto
- arquivo XML relativo
- `last_update`

### `object-info`

Entrada:

- `ObjectType`
- `ObjectName`
- `Format` opcional: `json` ou `text`

Saida minima:

- objeto consultado
- se foi encontrado
- arquivo XML relativo
- `last_update`
- quantidade de relacoes de entrada
- quantidade de relacoes de saida

### `who-uses`

Entrada:

- `ObjectType`
- `ObjectName`
- `Limit` opcional
- `Format` opcional: `json` ou `text`

Saida minima:

- objeto consultado
- lista de origens que referenciam o objeto
- tipo da relacao
- linha
- snippet
- regra de extracao
- confianca

### `what-uses`

Entrada:

- `ObjectType`
- `ObjectName`
- `Limit` opcional
- `Format` opcional: `json` ou `text`

Saida minima:

- objeto consultado
- lista de destinos referenciados pelo objeto
- tipo da relacao
- linha
- snippet
- regra de extracao
- confianca

### `show-evidence`

Entrada:

- identificador da relacao ou par origem/destino
- `Limit` opcional
- `Format` opcional: `json` ou `text`

Saida minima:

- arquivo de origem
- linha
- snippet
- papel da evidencia
- regra de extracao

## Bateria minima de validacao

A Fase 1 deve ter uma bateria pequena de casos reais antes de ser considerada pronta.

### Caso obrigatorio 1

Origem:

- `WebPanel:wpRelatoriosDeMovimentosDeVolumes`

Destino:

- `Procedure:procPlanilhaVolumeMovimento`

Evidencia esperada:

- `procPlanilhaVolumeMovimento.Call(...)`
- papel: `Source efetivo`
- relacao: `calls_procedure`
- regra: `procedure_dot_call`

Objetivo do teste:

- provar que chamadas `.Call(...)` em `WebPanel` sao capturadas
- evitar repetir falso negativo observado no experimento `Mapeamento`

### Caso obrigatorio 2

Escolher uma `Procedure` real que chame outra `Procedure` por `procNome(...)`.

Objetivo do teste:

- provar captura de chamada direta simples
- validar `what-uses` e `who-uses`

### Caso obrigatorio 3

Escolher um XML com comentario contendo nome de procedure.

Objetivo do teste:

- provar que comentario nao vira relacao direta

### Caso obrigatorio 4

Escolher um `WebPanel` com layout visual contendo texto parecido com chamada.

Objetivo do teste:

- provar que layout visual nao vira relacao direta

## Criterio de pronto

A Fase 1 so pode ser marcada como pronta quando:

- o SQLite for gerado a partir de uma pasta paralela real
- as tabelas minimas existirem
- as consultas `who-uses`, `what-uses` e `show-evidence` funcionarem
- os casos obrigatorios forem executados e documentados
- o caso `procPlanilhaVolumeMovimento.Call(...)` for capturado corretamente
- comentarios e layout visual nao gerarem relacoes diretas falsas
- o relatorio de validacao registrar sucesso, falha ou pendencia de cada caso
- a rodada oficial com casos de validacao usar `-FailOnValidationFailure`

## Relatorio de validacao

O relatorio de validacao deve ser pequeno e versionavel quando fizer parte de uma rodada oficial.

Campos recomendados:

- data/hora da rodada
- `SourceRoot`
- quantidade de XMLs lidos por tipo
- quantidade de objetos gravados
- quantidade de relacoes gravadas
- casos obrigatorios executados
- resultado por caso
- pendencias e falsos negativos conhecidos

## Relacao com `xpz-doc-builder`

Esta frente pode futuramente alimentar `xpz-doc-builder`, mas nao deve ser absorvida por ele automaticamente.

Na Fase 1, o foco e produzir banco tecnico reutilizavel e consulta operacional para agentes.

Se a saida do indice for usada para gerar Markdown, essa sera uma etapa posterior e deve preservar a distincao entre:

- evidencia direta
- inferencia
- resumo para consumo humano ou agente

## Decisoes ainda abertas

- local padrao para o SQLite gerado em cada pasta paralela de KB
- estrategia exata para linha e coluna em `CDATA`
- formato do relatorio pequeno de validacao
- politica de criacao de uma skill futura especifica para KB Intelligence
