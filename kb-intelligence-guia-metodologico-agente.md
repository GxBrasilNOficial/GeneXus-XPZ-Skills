# KB Intelligence - Guia Metodologico para Agentes

## Papel do documento
guia operacional

## Nível de confianca predominante
medio

## Depende de
scripts/README-kb-intelligence.md, 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md

## Usado por
agentes que precisem responder perguntas funcionais curtas ou de impacto técnico usando o KB Intelligence como trilha de triagem, sem substituir a leitura do XML oficial

---

## Principio metodologico

O índice orienta a ordem de leitura. O XML oficial fecha a conclusao quando a pergunta depender de semantica GeneXus.

O KB Intelligence pode reduzir custo de busca, orientar a trilha de leitura e organizar evidencias, mas a resposta final depende de:

- evidencia direta do índice, quando existir
- leitura adicional do XML oficial, quando a pergunta exigir semantica GeneXus
- classificação explicita do que e inferencia forte, inferencia fraca ou hipotese

---

## Checklist antes de responder

- confirmar a pasta paralela da KB em uso
- ler `README.md` e `AGENTS.md` locais quando entrar em uma pasta de KB diferente da raiz metodologica
- confirmar o objeto sempre por `tipo + nome`
- localizar `KbIntelligence\kb-intelligence.sqlite`
- tratar `KbIntelligence\kb-intelligence.sqlite` como artefato canonico derivado da pasta paralela da KB
- tratar o SQLite como índice derivado, não como fonte normativa
- se a triagem funcional sugerir que o canonico está defasado em relacao ao comportamento esperado, não regenerar durante a própria investigacao
- tratar regeneracao do canonico como ação operacional separada, explicita e validada
- usar `ObjetosDaKbEmXml` como fonte normativa quando a pergunta depender de semantica GeneXus
- não usar `ArquivoMorto`, salvo pedido explicito de análise histórica
- não tocar em `logs/` locais, salvo pedido explicito

---

## Ordem mínima de triagem

1. executar `object-info` para confirmar existência e caminho do objeto
2. se o nome ou tipo ainda estiver incerto, executar `search-objects`
3. antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catalogo efetivo (`scripts/gx-object-type-catalog.json` + override local da pasta paralela) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, o `Query-KbIntelligenceIndex` devolve exit `11` e `blocked=true` — **não** tratar como zero dependencias; usar `object-info`, `search-objects`, `list-by-type` ou XML pontual
4. executar `impact-basic` (ou `who-uses` / `what-uses`) **somente** quando o tipo for `queryableByKbIntelligence=true`, para obter dependentes e dependencias diretas; para grafo assimétrico esperado (`API`, `DataSelector`, `WorkWith`, `WorkWithForWeb`, `ExternalObject`), ver `scripts/README-kb-intelligence.md`; entre os dois Work With, usar o GUID como identidade, nunca o nome histórico
5. escolher apenas as relacoes que mudam a trilha de leitura
6. executar `show-evidence` nessas relacoes
7. abrir o XML oficial somente nos pontos necessários
8. responder separando evidencia direta, leitura adicional, inferencia forte e hipotese

Para perguntas funcionais curtas, `functional-trace-basic` pode substituir os passos 1 a 6, respeitando o mesmo gate de `queryableByKbIntelligence` no passo 3; a resposta final continua exigindo separacao explicita de evidencia e limite.

### Ramo: atributo ou gravabilidade de Transaction (triagem via índice)

Use este ramo somente quando a pergunta for **triagem técnica** sobre atributos ou gravabilidade — não quando o objetivo for **gerar ou empacotar** XML/XPZ.

1. escolher a consulta mínima conforme `xpz-index-triage` (**QUERY PARAMETER REFERENCE**):
   - `attribute-info` — um atributo; sinais **leves** (`Formula`, `idBasedOn`, etc.)
   - `transaction-attributes` ou `transaction-writable-attributes` — uma Transaction; classificação **materializada** no índice (`schema_version>=2`), com paridade contra `Test-GeneXusTransactionWritability.ps1`
2. registrar o comando, o objeto e os sinais retornados como **evidencia direta**
3. declarar explicitamente o **tipo de consulta**:
   - `attribute-info`: leve; **não** substitui classificação completa de gravabilidade
   - `transaction-writable-attributes`: classificação completa materializada; **não** substitui empacote nem blocos `New` em `Procedure` (`Test-GeneXusNewWritableTargets.ps1`)
4. se a pergunta evoluir para geração de atribuicao em `Rules`, `Events`, `New` ou empacotamento, **parar a triagem** e encaminhar para `xpz-builder` com `Test-GeneXusTransactionWritability.ps1` ou `Test-GeneXusNewWritableTargets.ps1` (fachadas sobre `GeneXusTransactionWritabilityCore.py`)

### Ramo: objetos gerados por Pattern × autorais (triagem via índice)

Use este ramo somente quando a pergunta for **triagem** sobre separar objetos GERADOS por Pattern (WorkWith For Web) de AUTORAIS — tipicamente **auditoria** (ex.: de segurança) — não quando o objetivo for **gerar ou empacotar** XML/XPZ.

1. escolher a consulta mínima conforme `xpz-index-triage` (**QUERY PARAMETER REFERENCE**):
   - `object-info` — um objeto; retorna `is_generated_object` (0/1), `pattern_object_id` e `instance_key`
   - `search-objects` ou `list-by-type` com `--generated` / `--authored` (mutuamente exclusivos) — um conjunto por tipo, filtrado deterministicamente
2. registrar o comando, o objeto e o valor de `is_generated_object`/`pattern_object_id`/`instance_key` como **evidencia direta**
3. declarar explicitamente que é **sinal determinístico** materializado no índice (propriedade `IsGeneratedObject` de nível-objeto), **não** heurística de nome (`ww*`/`*WC`/`*General`/`*Selection`); o marcador é a prova **após rebuild fresco** do índice
4. se a pergunta evoluir para **empacotar ou corrigir** um derivado gerado, **parar a triagem** e encaminhar para `xpz-builder` (que aponta o mesmo sinal em `wwp-packaging.md`: não empacotar correção contra derivado gerado; trabalhar na fonte declarativa)

Para sintaxe, parâmetros e validação operacional das consultas, preferir `scripts/README-kb-intelligence.md`; este guia não duplica esse catalogo.

---

## Quando parar no índice

Parar no índice quando a pergunta pedir apenas:

- onde revisar primeiro
- quais objetos cercam tecnicamente um objeto
- qual relacao técnica justifica abrir determinado XML
- qual trilha mínima de leitura deve ser seguida
- quais atributos de uma Transaction merecem leitura primeiro, quais sinais leves (`attribute-info`) ou quais classificacoes materializadas de gravabilidade (`transaction-writable-attributes`) o índice expoe (sem fechar ainda regra de negocio nem autorizar geração)

Nesses casos, declarar que se trata de triagem técnica direta, não de prova funcional completa.

## Quando abrir o XML oficial

Abrir o XML oficial quando a pergunta depender de:

- `Source` efetivo
- `Rules`
- `parm(...)`
- eventos
- formulas
- propriedades com efeito semantico
- cadeia imediata de chamadas
- tipo de variável, `ATTCUSTOMTYPE`, BC, `SDT`, `Domain` ou `ExternalObject`
- interpretacao de efeito funcional, validação, persistencia, navegacao ou regra de negocio
- empacotamento ou blocos `New` em `Procedure` que exijam gate dedicado (`Test-GeneXusNewWritableTargets.ps1`), mesmo quando `transaction-writable-attributes` já trouxe classificação materializada no índice

---

## Estrutura obrigatória da resposta funcional

### Evidencia direta

Registrar somente o que veio do índice ou da evidencia armazenada:

- comando usado
- objeto origem e destino com `tipo + nome`
- arquivo relativo
- linha registrada
- regra de extracao
- trecho técnico curto

### Leitura adicional do XML

Registrar o que foi confirmado no XML oficial:

- arquivo oficial lido
- trecho ou bloco consultado
- papel do trecho na investigacao
- limite do que a leitura confirmou

### Inferencia forte

Usar somente quando houver sinais convergentes:

- relacao técnica direta no índice
- evidencia ancorada em linha
- XML oficial confirmando o contexto do trecho
- tipo ou variável resolvida com seguranca

Mesmo nesses casos, não transformar a inferencia em garantia runtime.

### Hipotese

Usar para o que ainda depende de leitura adicional, teste externo, build, execução ou conhecimento funcional fora do recorte lido.

---

## Frases a evitar

- "o sistema certamente faz"
- "isso prova a regra de negocio"
- "o impacto funcional completo e"
- "basta olhar o índice"
- "não precisa abrir o XML"
- "a procedure salva sempre"
- "o SDT e o payload completo"
- "a tela depende sempre dessa procedure"

## Frases preferidas

- "o índice mostra evidencia técnica direta"
- "o XML oficial confirma este trecho"
- "a inferencia forte e"
- "permanece como hipotese"
- "para fechar a regra funcional completa, a leitura precisa seguir para"
- "isto é triagem técnica, não prova runtime completa"

---

## Exemplos sanitizados

Os exemplos abaixo usam nomes genéricos de objetos GeneXus, sem referencia a KBs reais. Correspondencias com nomes reais de KB estao registradas em `GeneXus-XPZ-PrivateMap`.

### Exemplo 1 - Triagem de impacto técnico antes de alterar uma Procedure

**Cenário:** o agente precisa avaliar o impacto de alterar `Procedure:procCalculaMovimentoEstoque` antes de modificar sua lógica interna.

**Trilha mínima:**

```powershell
# Passo 1: confirmar existencia
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "...\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procCalculaMovimentoEstoque `
  -Format text

# Passo 2: mapear impacto tecnico direto
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "...\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName procCalculaMovimentoEstoque `
  -Limit 20 `
  -Format text
```

**Resultado esperado do `impact-basic`:**

- dependentes diretos: `WebPanel:wpConsultaMovimentos`, `DataProvider:dpResumoMovimentos`
- dependencias diretas: `Procedure:procRegistraLogOperacao`, `Transaction:TrnMovimento`

**Passo 3 (opcional): auditar relacao específica**

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "...\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpConsultaMovimentos `
  -TargetType Procedure `
  -TargetName procCalculaMovimentoEstoque `
  -Format text
```

**Resposta estruturada esperada:**

- Evidencia direta: chamada `procCalculaMovimentoEstoque.Call(...)` em `WebPanel/wpConsultaMovimentos.xml`, linha N, regra `procedure_dot_call`, confianca `direct`
- Leitura adicional do XML: abrir `Procedure/procCalculaMovimentoEstoque.xml` para revisar parâmetros e `Source` efetivo antes de alterar
- Inferencia forte: a alteracao pode afetar `wpConsultaMovimentos` e `dpResumoMovimentos`
- Hipotese: efeito em runtime depende da lógica interna da procedure; não confirmavel apenas pelo índice

---

### Exemplo 2 - Triagem funcional básica com `functional-trace-basic`

**Cenário:** o agente recebe pergunta funcional curta sobre `API:apiIntegracaoExterna` e precisa montar trilha inicial antes de abrir XML.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "...\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType API `
  -ObjectName apiIntegracaoExterna `
  -Limit 20 `
  -Format text
```

**Resultado esperado:**

- objeto localizado: `API/apiIntegracaoExterna.xml`
- dependencias diretas resolvidas: `Procedure:procProcessaEntradaItem`, `SDT:sdtItemDadosBasicos`
- literais `CustomType` redundantes suprimidos quando ha relacao resolvida equivalente
- XMLs indicados para leitura: `API/apiIntegracaoExterna.xml`, `Procedure/procProcessaEntradaItem.xml`

**Resposta estruturada esperada:**

- Evidencia direta: relacoes tecnicas diretas retornadas pelo índice para `apiIntegracaoExterna`
- Leitura adicional do XML: abrir `API/apiIntegracaoExterna.xml` para revisar contrato da API e parâmetros; abrir `Procedure/procProcessaEntradaItem.xml` para verificar o que a procedure faz com os dados recebidos
- Inferencia forte: a API recebe entrada e delega processamento a `procProcessaEntradaItem`; o SDT `sdtItemDadosBasicos` e o tipo de dados trafegado
- Hipotese: persistencia, validacoes e regras de negocio dependem de leitura do `Source` efetivo das procedures; não confirmavel apenas pelo índice

---

### Exemplo 3 - Objeto não encontrado

**Cenário:** o agente consulta um objeto que não existe no índice.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "...\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procNaoExisteNaKb `
  -Format text
```

**Resultado esperado:** falha clara com indicacao de que o objeto não foi encontrado. Não tentar localizar por heuristica fora do índice, não buscar por nome parecido, não varrer `ObjetosDaKbEmXml`.

**Resposta estruturada esperada:**

- Evidencia direta: objeto não encontrado no índice
- Próximos passos: confirmar nome e tipo com o usuário; se o índice puder estar defasado, oferecer regeneracao

---

### Exemplo 4 - Terminologia: via edicao web versus via BC

Este exemplo registra a terminologia correta para descrever as duas formas de interacao com uma `Transaction` GeneXus.

**Via edicao web:** fluxo pelo formulario da transacao na IDE ou no runtime web. As `Rules` e `Events` com tag `[web]` se aplicam. O usuário (ou um WebPanel de entrada) salva, cancela ou edita o registro pela interface da própria transacao.

**Via BC (Business Component):** a `Transaction` e instanciada como Business Component por uma procedure ou outro objeto GeneXus. As chamadas `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()` e `.Update()` são feitas programaticamente. As `Rules` com tag `[bc]` se aplicam.

**Quando usar cada termo na resposta:**

- ao descrever ações do usuário (salvar formulario, cancelar registro, editar campo): usar "via edicao web"
- ao descrever chamadas feitas por procedures ou automacoes: usar "via BC"
- não misturar os dois contextos na mesma afirmacao sem declarar explicitamente a qual contexto cada parte se refere

---

## Gate de qualidade da resposta

Antes de responder, confirmar:

- o objeto foi tratado por `tipo + nome`
- a evidencia direta não foi misturada com inferencia
- a leitura do XML foi citada separadamente quando ocorreu
- toda conclusao funcional tem limite declarado
- hipoteses não foram escritas como fatos
- o índice não foi descrito como fonte normativa
- o XML oficial prevalece quando houver tensao interpretativa
