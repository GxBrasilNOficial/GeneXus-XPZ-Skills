# 20 - KB Intelligence Fase 6 - Piloto de Investigacao Funcional

## Papel do documento
piloto operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md, 19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md, scripts/README-kb-intelligence.md, 08-guia-para-agente-gpt.md

## Usado por
agentes que precisem validar o uso pratico da Fase 6 em perguntas funcionais curtas, sem transformar o indice tecnico em fonte normativa

## Objetivo
Executar um piloto pequeno da Fase 6 usando a KB real `KBExemplo`, demonstrando como o indice tecnico reduz a trilha de leitura e como o XML oficial fecha ou limita a resposta funcional.

## Ambiente do piloto

- KB paralela: `C:\KB\KBExemplo`
- Fonte normativa lida: `C:\KB\KBExemplo\ObjetosDaKbEmXml`
- Indice canonico consultado sem alteracao: `C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite`
- Indice temporario usado para o piloto atualizado: `C:\KB\KBExemplo\Temp\kb-intelligence-fase6-piloto.sqlite`
- Relatorio temporario de validacao: `C:\KB\KBExemplo\Temp\kb-intelligence-fase6-piloto-validation.json`

Na execucao inicial do piloto, o indice canonico operacional nao foi sobrescrito. A geracao temporaria foi necessaria porque a consulta ao canonico localizou bem relacoes de `WorkWithForWeb`, mas nao retornou relacoes dos incrementos finais da Fase 5, como BC `.Load(...)` resolvido para `Transaction` e `API` para `SDT` resolvido por `ATTCUSTOMTYPE`.

O indice temporario foi gerado a partir do XML oficial e validou a bateria da Fase 5 com 64 casos aprovados.

Depois do piloto, por decisao explicita do usuario, o indice canonico foi regenerado pela rotina oficial com a mesma bateria da Fase 5. O canonico passou a refletir os incrementos finais da Fase 5 e as consultas pontuais que antes exigiram o indice temporario passaram a responder no proprio `KbIntelligence\kb-intelligence.sqlite`.

## Comando de preparacao usado

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\Temp\kb-intelligence-fase6-piloto.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\Temp\kb-intelligence-fase6-piloto-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase5.validation-cases.json" `
  -FailOnValidationFailure
```

## Caso 1 - `WorkWithForWeb` como ponto de triagem de fluxo

### Pergunta funcional curta

`WorkWithForWeb:WorkWithWebAbateOrdem` e um bom ponto inicial para investigar regras ligadas a ordem de abate?

### Trilha executada

- `impact-basic` em `WorkWithForWeb:WorkWithWebAbateOrdem`
- `show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Transaction:AbateOrdem`
- `show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procLeEmpresaSessao`
- leitura direta de `ObjetosDaKbEmXml\WorkWithForWeb\WorkWithWebAbateOrdem.xml`

### Evidencia direta

- o indice aponta `WorkWithForWeb:WorkWithWebAbateOrdem` em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`
- existe relacao direta para `Transaction:AbateOrdem`
- regra: `workwith_transaction_binding`
- linha registrada: `6`
- trecho tecnico: `<transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-AbateOrdem" />`
- existe relacao direta para `Procedure:procLeEmpresaSessao`
- regra: `workwith_condition_procedure`
- linha registrada: `172`
- trecho tecnico: `<condition value="AbateOrdemEmpresaId = procLeEmpresaSessao()" />`

### Leitura adicional do XML

- o XML oficial confirma que o `WorkWithForWeb` esta vinculado a `AbateOrdem` no inicio da definicao do pattern
- o XML oficial confirma uma condicao de selecao que compara `AbateOrdemEmpresaId` com `procLeEmpresaSessao()`
- o XML tambem mostra action `ZeraCompraGadoIdDeAnimais` apontando para `Procedure:procAjustaCompraGadoIdDeAnimais`, linha `843`

### Inferencia forte

`WorkWithForWeb:WorkWithWebAbateOrdem` e um primeiro ponto tecnico forte para investigar fluxo funcional de ordem de abate, porque combina vinculacao estrutural com `Transaction:AbateOrdem`, condicao por empresa da sessao e actions que chamam procedures auxiliares.

### Hipotese

O indice e a leitura curta do XML nao provam o fluxo funcional completo da tela nem todos os cenarios runtime. Para responder impacto funcional completo, a investigacao precisa seguir para as actions e procedures especificas envolvidas.

## Caso 2 - BC como atalho para identificar manipulacao de `Transaction`

### Pergunta funcional curta

Ha indicio tecnico de que `Procedure:procAjustaCompraGadoIdDeAnimais` trabalha diretamente com `Transaction:Animal`?

### Trilha executada

- `impact-basic` em `Procedure:procAjustaCompraGadoIdDeAnimais`
- `show-evidence` para `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal`
- leitura direta de `ObjetosDaKbEmXml\Procedure\procAjustaCompraGadoIdDeAnimais.xml`

### Evidencia direta

- existe dependente direto: `WorkWithForWeb:WorkWithWebAbateOrdem` chama `Procedure:procAjustaCompraGadoIdDeAnimais`
- regra do dependente: `workwith_action_gxobject`
- linha registrada no `WorkWithForWeb`: `843`
- existem relacoes diretas da procedure para `Transaction:Animal`
- regras: `source_bc_load_transaction` e `source_bc_save_transaction`
- linhas registradas: `66`, `83`, `122` e `138`
- trechos tecnicos: `&animal.Load(AnimalEmpresaId, AnimalId)` e `&animal.Save()`

### Leitura adicional do XML

- o XML oficial confirma `&animal.Load(...)` antes de atribuicoes em `AnimalCompraGadoId`
- o XML oficial confirma `&animal.Save()` apos comparacoes e atribuicoes na variavel BC
- o XML oficial confirma a tipagem da variavel por `ATTCUSTOMTYPE` com valor `bc:Animal`, linha `285`

### Inferencia forte

Ha indicio tecnico forte de manipulacao direta de `Animal` via BC, porque a relacao nao depende apenas do nome da variavel. A regra resolvida combina `ATTCUSTOMTYPE` `bc:Animal` com chamadas efetivas `.Load(...)` e `.Save()` no `Source`.

### Hipotese

A leitura curta ainda nao fecha a regra funcional completa de ajuste de compra de gado. Para afirmar todos os efeitos, seria necessario ler o bloco completo da procedure, seus filtros, mensagens, chamadas auxiliares e condicoes de sucesso.

## Caso 3 - `API` com tipo resolvido para orientar contrato tecnico

### Pergunta funcional curta

Se o objetivo for entender rapidamente o contrato tecnico de `API:apiPDV_Integracao`, qual tipo deve ser aberto primeiro?

### Trilha executada

- `impact-basic` em `API:apiPDV_Integracao`
- `show-evidence` para `API:apiPDV_Integracao` -> `SDT:sdtProdutoDadosBasicos`
- leitura direta de `ObjetosDaKbEmXml\API\apiPDV_Integracao.xml`
- verificacao de existencia de `ObjetosDaKbEmXml\SDT\sdtProdutoDadosBasicos.xml`

### Evidencia direta

- existe relacao resolvida de `API:apiPDV_Integracao` para `SDT:sdtProdutoDadosBasicos`
- regra: `attcustomtype_resolved_object`
- linha registrada: `529`
- trecho tecnico: `<Value>sdt:sdtProdutoDadosBasicos</Value>`
- o objeto `SDT:sdtProdutoDadosBasicos` existe no acervo oficial

### Leitura adicional do XML

- o XML oficial da `API` mostra `out:&ListaSdtProdutoDadosBasicos` no contrato inicial
- o XML oficial da `API` mostra chamada a `procListaSdtProdutoDadosBasicosConformeParametros(...)`
- o XML oficial da `API` confirma a variavel `ListaSdtProdutoDadosBasicos` com `ATTCUSTOMTYPE` `sdt:sdtProdutoDadosBasicos`

### Inferencia forte

`SDT:sdtProdutoDadosBasicos` e um dos primeiros XMLs corretos para abrir ao investigar o contrato tecnico dessa `API`, especialmente para entender o formato da saida relacionada a produtos.

### Hipotese

O indice nao prova sozinho se esse `SDT` e o payload principal completo da API, um retorno parcial ou apenas uma estrutura auxiliar. A leitura funcional completa deve seguir para o XML da `API`, o XML do `SDT` e, se necessario, a procedure chamada.

## Resultado do piloto

O roteiro da Fase 6 se mostrou operacionalmente util:

- o indice reduziu a busca inicial para objetos e linhas especificas
- `show-evidence` funcionou como ponte entre triagem tecnica e abertura do XML oficial
- a resposta funcional precisou separar evidencia direta, leitura adicional, inferencia forte e hipotese
- o XML oficial continuou sendo a fonte normativa para interpretar o papel do trecho

## Achado operacional adicional

O piloto tambem revelou uma diferenca pratica entre o indice canonico atual e o indice gerado temporariamente com os scripts atuais. O canonico consultado nao retornou algumas relacoes dos incrementos finais da Fase 5, enquanto o indice temporario validado retornou.

Isso nao deveria ser corrigido automaticamente durante a Fase 6. A atualizacao do canonico deveria ser uma acao separada, explicita e validada, porque `KbIntelligence\kb-intelligence.sqlite` e o artefato operacional estavel da pasta paralela da KB.

## Atualizacao posterior do canonico

Por decisao explicita do usuario, a rotina oficial de geracao do indice canonico foi executada depois do piloto:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase5.validation-cases.json" `
  -FailOnValidationFailure
```

Resultado registrado:

- objetos escritos: `14928`
- relacoes escritas: `60494`
- validacao da Fase 5: `64` casos aprovados
- arquivo canonico atualizado: `C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite`
- relatorio atualizado: `C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json`

Consultas pontuais confirmaram no canonico:

- `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal` por `source_bc_load_transaction` e `source_bc_save_transaction`
- `API:apiPDV_Integracao` -> `SDT:sdtProdutoDadosBasicos` por `attcustomtype_resolved_object`

## Proxima decisao recomendada

Antes de automatizar qualquer camada funcional nova, decidir explicitamente se:

- a Fase 6 deve ganhar apenas um checklist operacional para agentes
- a Fase 6 deve ganhar uma consulta auxiliar futura que empacote a trilha `impact-basic` + `show-evidence`, sem produzir conclusao funcional automatica
