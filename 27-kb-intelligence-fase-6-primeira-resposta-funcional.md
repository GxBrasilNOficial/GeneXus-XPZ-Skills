# 27 - KB Intelligence Fase 6 - Primeira Resposta Funcional

## Papel do documento
exemplo operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
21-kb-intelligence-fase-6-checklist-operacional-agente.md, 22-kb-intelligence-fase-6-contrato-functional-trace-basic.md, 26-kb-intelligence-fase-6-verificacao-pos-filtro.md

## Usado por
agentes que forem responder perguntas funcionais reais usando a Fase 6

## Objetivo
Registrar o primeiro exemplo controlado de resposta funcional usando:

- indice tecnico apenas como triagem
- XML oficial como fonte normativa
- separacao explicita entre evidencia direta, leitura adicional do XML, inferencia forte e hipotese

## Pergunta funcional ensaiada
O que faz a API `apiPDV_Integracao`?

## Triagem pelo indice tecnico

Consulta executada:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType API `
  -ObjectName apiPDV_Integracao `
  -Limit 25
```

Resultado operacional:

- objeto principal encontrado em `API/apiPDV_Integracao.xml`
- `technical_trace_shown`: 18
- `suppressed_redundant_custom_type_relations`: 2
- relacoes resolvidas mantidas para:
  - `SDT:sdtProdutoDadosBasicos`
  - `SDT:sdtTributacaoDadosBasicosSelecao`

Limite da triagem:

- o indice localiza relacoes tecnicas diretas
- o indice nao prova sozinho o comportamento funcional completo
- a resposta abaixo foi escrita depois da leitura do XML oficial

## Resposta funcional

### Evidencia direta

No XML oficial `C:\KB\KBExemplo\ObjetosDaKbEmXml\API\apiPDV_Integracao.xml`, o `Service` declara tres metodos `POST`:

- `ObterProdutos`, descrito como obtencao de lista de produtos conforme parametros
- `ObterTributacoes`, descrito como obtencao de lista de tributacoes conforme parametros
- `EnviarDFE`, descrito como envio de Documento Fiscal Eletronico em XML ou PDF Base64 para importacao

Cada metodo delega para uma procedure:

- `ObterProdutos` chama `procListaSdtProdutoDadosBasicosConformeParametros`
- `ObterTributacoes` chama `procSdtTributacaoDadosBasicosSelecaoConformeParametros`
- `EnviarDFE` chama `procImportaDFeDeBase64`

O XML da API tambem declara variaveis de saida ligadas a SDTs:

- `ListaSdtProdutoDadosBasicos` usa `sdt:sdtProdutoDadosBasicos`
- `sdtTributacaoDadosBasicosSelecao` usa `sdt:sdtTributacaoDadosBasicosSelecao`

Nos eventos:

- `ObterProdutos.Before` define `&ProdutoTipoProd = TipoProd.Produto`
- `ObterProdutos.After` chama `CompletaRetornoMessages`
- `ObterTributacoes.Before` calcula `&ParaLoginEmpresaId` e chama `CompletaLogin`
- `EnviarDFE.Before` calcula `&ParaLoginEmpresaId` e chama `CompletaLogin`
- `EnviarDFE.After` trata mensagens de retorno e chama `CompletaRetornoMessages`

O sub-bloco `CompletaLogin`:

- consulta `GAMSession`
- valida a sessao com `GAMSession.IsValid`
- em erro ou sessao invalida, agrega mensagens e define `&RestCode = 403`
- identifica usuario pelo login com `procUsuarioPeloLogin`
- tambem pode retornar erro quando usuario ou permissao de empresa nao sao identificados

### Leitura adicional do XML

Foram abertos tambem os XMLs oficiais das procedures chamadas diretamente:

- `C:\KB\KBExemplo\ObjetosDaKbEmXml\Procedure\procListaSdtProdutoDadosBasicosConformeParametros.xml`
- `C:\KB\KBExemplo\ObjetosDaKbEmXml\Procedure\procSdtTributacaoDadosBasicosSelecaoConformeParametros.xml`
- `C:\KB\KBExemplo\ObjetosDaKbEmXml\Procedure\procImportaDFeDeBase64.xml`

Nessa leitura adicional:

- a procedure de produtos valida parametros, percorre dados de produto e preenche a lista `sdtProdutoDadosBasicos`
- a procedure de tributacoes valida parametros de tributacao, documento fiscal e romaneio antes de preencher o SDT de selecao
- a procedure de DFe valida nome do arquivo, conteudo Base64 e empresa do documento fiscal antes de importar
- `procImportaDFeDeBase64` define `&Sucesso = true` somente no caminho final sem falha observada no trecho lido

Tambem foram confirmados os XMLs dos SDTs:

- `C:\KB\KBExemplo\ObjetosDaKbEmXml\SDT\sdtProdutoDadosBasicos.xml`
- `C:\KB\KBExemplo\ObjetosDaKbEmXml\SDT\sdtTributacaoDadosBasicosSelecao.xml`

### Inferencia forte

A API `apiPDV_Integracao` funciona como uma interface REST de integracao do PDV com a KB para tres familias de operacao:

- consulta de produtos em formato estruturado por SDT
- consulta de tributacoes em formato estruturado por SDT
- envio/importacao de DFe em Base64

A API nao concentra a regra de negocio principal no corpo do `Service`; ela atua como camada de exposicao e orquestracao, delegando o processamento para procedures especializadas.

Para `ObterTributacoes` e `EnviarDFE`, ha evidencia direta de controle de login/sessao/permissao via `CompletaLogin` antes da execucao funcional principal.

Para `ObterProdutos`, a evidencia direta lida mostra apenas a definicao de `ProdutoTipoProd` no `Before` e a composicao de mensagens no `After`; nao foi encontrada chamada explicita a `CompletaLogin` nesse evento.

### Hipotese

Ha duas hipoteses plausiveis para `ObterProdutos` nao chamar `CompletaLogin` no trecho lido:

- o endpoint de produtos pode ser intencionalmente menos restritivo que os endpoints de tributacao e DFe
- a validacao pode ocorrer dentro da procedure chamada ou por mecanismo externo ao trecho lido

Essa diferenca nao deve ser tratada como bug apenas com esta leitura. Para concluir, seria necessario investigar a regra de seguranca esperada para o endpoint de produtos e ler a procedure de produtos com foco especifico em permissao e empresa de login.

## Resultado metodologico

O exemplo confirmou o fluxo da Fase 6:

- a consulta `functional-trace-basic` reduziu o custo de entrada
- o XML oficial continuou sendo a fonte normativa
- a resposta funcional nao misturou fato direto com inferencia
- uma diferenca relevante foi mantida como hipotese, nao como conclusao

## Proximo gate

Repetir o mesmo formato com uma pergunta funcional que envolva `Transaction` e `WorkWithWeb`, para validar a terminologia local:

- via edicao web
- via BC
