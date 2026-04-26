# KB Intelligence Scripts

## Papel do documento
guia operacional

## Escopo atual

Estes scripts implementam a base do KB Intelligence e os incrementos aprovados ao longo das Fases 1 a 5, alem da camada de suporte funcional aberta na Fase 6.

As fases continuam relevantes como marco historico e contrato documental, mas nao devem ser tratadas como identidade operacional unica do SQLite. O metadata operacional do indice deve refletir capacidades e frescor atuais, nao um numero de fase.

A Fase 3 foi aberta por contrato em `..\14-kb-intelligence-fase-3-contrato.md` para formalizar o uso operacional por agentes e o comando `impact-basic`.

A Fase 5 foi aberta por contrato em `..\16-kb-intelligence-fase-5-contrato.md` para ampliar relacoes semanticas por incrementos pequenos.

A Fase 6 foi aberta por contrato em `..\17-kb-intelligence-fase-6-contrato.md` para suporte funcional assistido por agentes. O comando `functional-trace-basic` empacota a triagem inicial, mas nao produz conclusao funcional automatica.

Escopo de inventario atual:

- todos os tipos com XML em subpastas imediatas de `ObjetosDaKbEmXml`

Escopo de extracao de relacoes atual:

- origens por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- destinos por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- origem por action: `WorkWithForWeb`
- destino por action: `Procedure` ou `WebPanel`
- vinculacao explicita: `WorkWithForWeb` para `Transaction`
- link explicito: `WorkWithForWeb` para `WebPanel`
- prompt explicito: `WorkWithForWeb` para `WebPanel`
- condicao explicita: `WorkWithForWeb` para `Procedure`
- atributo de condicao: `WorkWithForWeb` para `Procedure`
- alvo literal por propriedade: `CustomType:<valor>` a partir de `ATTCUSTOMTYPE`
- alvo resolvido por propriedade: `SDT`, `Domain` ou `ExternalObject` a partir de `ATTCUSTOMTYPE`, quando o objeto existir no inventario e a regra aprovada resolver o prefixo com seguranca
- origem atual de `ATTCUSTOMTYPE` indexado: `Procedure`, `WebPanel`, `DataProvider`, `API`, `DataSelector`, `Domain`, `SDT`, `WorkWithForWeb` e `Transaction`
- dominio base de atributo: `Attribute` para `Domain` a partir de `idBasedOn`, quando o dominio existir no inventario local
- atributo estrutural de transacao: `Transaction` para `Attribute` a partir de `<Level>/<Attribute>`, quando o atributo existir no inventario local
- tabela estrutural de transacao: `Transaction` para `Table` a partir de `Type` em `<Level>`, quando a tabela existir no inventario local
- atributo chave de tabela: `Table` para `Attribute` a partir de `<Key>/<Item>`, quando o atributo existir no inventario local
- atributo membro de indice de tabela: `Table` para `Attribute` a partir de `<Index>/<Part>/<Members>/<Member>`, quando o atributo existir no inventario local
- tipo de item de SDT: `SDT` para `SDT` a partir de `ATTCUSTOMTYPE` em `<Item>`, quando o valor tiver prefixo `sdt:` e o SDT existir no inventario local
- tabela navegada explicitamente: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>` em `Source` efetivo, quando a tabela existir no inventario local
- prefixo de tabela em navegacao qualificada: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>.<Membro>` em `Source` efetivo, quando `<Nome>` existir como tabela no inventario local
- carga de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Load(...)` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- persistencia de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Save()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- exclusao de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Delete()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- validacao de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Check()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- insercao/atualizacao de Business Component simples: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Insert()` ou `&Variavel.Update()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local e nao tiver `AttCollection=True`
- relacoes: chamadas diretas em `Source efetivo`, actions `gxobject` resolvidas, vinculacoes explicitas de `Transaction`, links e prompts explicitos de `WebPanel` em `WorkWithForWeb`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, propriedades `ATTCUSTOMTYPE`, `idBasedOn` de `Attribute`, atributos e tabelas estruturais de `Transaction`, atributos chave e membros de indice de `Table`, tipos internos resolvidos de `SDT`, tabelas declaradas em `for each` explicito, prefixos de tabela em `for each` qualificado e chamadas `.Load(...)`/`.Save()`/`.Delete()`/`.Check()`/`.Insert()`/`.Update()` de BC resolvidas para `Transaction`
- artefato principal: SQLite derivado

A Fase 2 consolidada cobre `DataProvider` como origem e como destino de chamada direta, actions de `WorkWithForWeb` com `gxobject` resolvido para `Procedure` ou `WebPanel`, vinculacao explicita de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e `ATTCUSTOMTYPE` como `CustomType` literal. Ela nao cobre semantica completa de `Transaction`, semantica de `WorkWithForWeb` alem dos recortes ja cobertos, `for each`, `.Load(...)` nem resolucao semantica de `CustomType` para `SDT` ou `Domain`; o recorte aprovado de `for each` entrou posteriormente na Fase 5.

Eles nao substituem o acervo XML em `ObjetosDaKbEmXml` e nao provam comportamento runtime.

## Gerar indice

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Para outra KB, troque `-SourceRoot`, `-OutputPath` e, se aplicavel, `-ValidationCasesPath`.

Para validar os incrementos aprovados da Fase 2 em `KBExemplo`, use:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase2.validation-cases.json" `
  -FailOnValidationFailure
```

O local operacional padrao dentro da pasta paralela da KB e `KbIntelligence\kb-intelligence.sqlite`. Este banco e derivado e regeneravel; a fonte normativa continua sendo `ObjetosDaKbEmXml`.

## Frescor operacional do indice

O indice so deve ser usado para triagem ampla quando estiver em dia com a ultima materializacao XPZ/XML do acervo oficial.

- `last_xpz_materialization_run_at` fica no `kb-source-metadata.md` da raiz da pasta paralela da KB
- `last_index_build_run_at` fica na tabela `metadata` de `KbIntelligence\kb-intelligence.sqlite`
- `last_index_build_run_at` tambem e espelhado em `KbIntelligence\kb-intelligence-validation.json` quando o relatorio de validacao e gerado
- `generated_at` nao faz mais parte do contrato operacional do indice; se aparecer em artefato antigo, trate esse indice como legado/incompativel e regenere
- todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize ou atualize XMLs em `ObjetosDaKbEmXml` deve chamar a regeneracao/validacao do indice logo depois
- se `last_index_build_run_at >= last_xpz_materialization_run_at`, o indice esta apto para triagem inicial
- se o indice estiver ausente, sem metadado, mais antigo que a ultima materializacao ou se `kb-source-metadata.md` nao expuser literalmente `last_xpz_materialization_run_at`, o agente nao deve consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, e tambem nao deve gerar objetos para importacao na KB pela IDE
- nesse estado defasado, o agente deve tratar a situacao como excecao operacional, oferecer regeneracao/validacao do indice ao usuario e nao seguir para varredura ampla, triagem substantiva, caminho pontual deduzido, leitura de XML oficial de objeto ou geracao
- leitura pontual com gate bloqueado so deve ocorrer para diagnostico minimo da incompatibilidade em documentacao local, estrutura, wrappers e metadados operacionais; nao montar, testar existencia, listar ou abrir caminho de XML oficial de objeto como fallback para responder pergunta de negocio
- o gate deve ser sequencial e atomico; nao testar caminho filho antes da camada pai, por exemplo `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- se o wrapper local documentado de consulta do indice estiver ausente, nao listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup
- nao substituir `last_xpz_materialization_run_at` por data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatorio ou outro metadado aproximado

Para ler os metadados do indice pelo wrapper:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query index-metadata `
  -Format text
```

Se `index-metadata` falhar, retornar vazio ou nao expor `last_index_build_run_at`, trate o indice como legado/incompativel ou sem metadado valido. Nao siga para triagem substantiva, pesquisa ampla, caminho pontual deduzido em `ObjetosDaKbEmXml`, leitura de XML oficial de objeto ou geracao de objetos; ofereca regeneracao/validacao do indice ao usuario.

Quando a validacao de frescor for parte relevante da resposta ou handoff, registre a decisao de forma curta. Em caso apto, informe `last_index_build_run_at >= last_xpz_materialization_run_at`; em caso bloqueado, informe o campo/capacidade ausente ou qual timestamp ficou defasado.

## Triagem exploratoria no PowerShell

Use consultas curtas e auditaveis quando precisar medir massa de padrao antes de propor novo incremento. Em Windows, prefira etapas pequenas a um one-liner longo.

Ordem sugerida de triagem:

1. contar ocorrencias brutas
2. agrupar por valor ou prefixo relevante
3. abrir amostra curta de casos reais positivos e negativos
4. medir quantos casos realmente resolvem contra o inventario local

Se um agrupamento ou regex retornar zero de forma inesperada, nao concluir ausencia de sinal de imediato. Primeiro abra uma ocorrencia real no XML da KB para conferir o formato efetivo da propriedade e so depois ajuste o extrator.

Depois de separar por prefixo, nao tratar prefixo promissor como relacao resolvida. Antes de propor incremento, medir quantos casos daquele prefixo realmente apontam para objeto existente no inventario local. Prefixos textual ou semanticamente proximos, como `exo:` e `ext:`, podem ter comportamentos metodologicos diferentes e nao devem ser fundidos por intuicao.

Contar ocorrencias textuais de `ATTCUSTOMTYPE` no acervo:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE' |
  Measure-Object
```

Agrupar valores de `ATTCUSTOMTYPE` por prefixo observavel:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { ($_.Groups[1].Value -split ':', 2)[0].ToLower() } |
  Group-Object |
  Sort-Object Count -Descending
```

Abrir amostra curta de valores reais antes de decidir contrato:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { $_.Groups[1].Value } |
  Select-Object -First 30
```

Evitar:

- one-liner longo com muitas interpolacoes, `:` e subexpressoes na mesma linha
- decidir incremento novo apenas por ocorrencia textual bruta
- pular da contagem direta para alteracao de contrato sem amostra real

## Buscar objetos por nome

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query search-objects `
  -ObjectName "*PlanilhaVolume*" `
  -Limit 10 `
  -Format text
```

## Localizar um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Format text
```

## Consultar quem usa um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query who-uses `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

## Consultar o que um objeto usa

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query what-uses `
  -ObjectType WebPanel `
  -ObjectName wpRelatoriosDeMovimentosDeVolumes `
  -Limit 10 `
  -Format text
```

## Consultar evidencia

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento `
  -Format text
```

## Triagem de impacto basico

O comando `impact-basic` resume dependentes diretos e dependencias diretas do objeto, ainda sem alterar o escopo de extracao.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

Para auditar uma relacao especifica retornada por `impact-basic`, use `show-evidence`.

Essa consulta representa impacto tecnico direto baseado no indice. Ela nao prova impacto runtime completo.

## Triagem funcional basica

O comando `functional-trace-basic` monta uma trilha inicial para perguntas funcionais curtas:

- localiza o objeto principal
- combina dependentes e dependencias diretas
- prioriza objetos resolvidos e locais antes de literais `CustomType`
- oculta literais `CustomType` redundantes quando houver relacao resolvida equivalente na mesma linha
- indica XMLs oficiais que o agente deve abrir
- devolve o contrato de resposta da Fase 6

Ele nao abre XML automaticamente, nao interpreta regra de negocio e nao substitui a leitura do XML oficial.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType Procedure `
  -ObjectName procAjustaCompraGadoIdDeAnimais `
  -Limit 20 `
  -Format text
```

## Validar consultas da Fase 3

Depois de gerar ou localizar um indice SQLite, valide o comportamento operacional de `impact-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase3.validation-cases.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-phase3-validation.json" `
  -FailOnValidationFailure
```

Os casos de validacao da Fase 3 conferem comportamento de consulta. Eles nao regeneram o indice nem substituem a bateria de extracao da Fase 2.

Escolha o executor pelo formato do caso, nao pelo numero da fase. Casos com campo `query` pertencem a validacao de consultas; casos com `source`, `target` e `expected_rule` pertencem a validacao de extracao/geracao.

## Cuidado com validacoes SQLite no Windows

Depois de gerar um SQLite temporario novo, prefira executar validacoes em sequencia contra esse arquivo. Evite rodar validacoes paralelas contra o mesmo banco recem-gerado.

Se houver necessidade real de paralelizar, use copias temporarias independentes do SQLite para cada validacao.

Falhas transitorias de acesso, lock ou tabela ainda nao visivel no Windows devem ser reexecutadas primeiro em sequencia antes de serem tratadas como falha real de contrato ou regressao do indice.

## Validar inventario ampliado da Fase 4

Depois de regenerar o indice, valide a presenca de tipos ampliados com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase4.validation-cases.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-phase4-validation.json" `
  -FailOnValidationFailure
```

Os casos da Fase 4 conferem inventario de objetos e comportamento conservador de `impact-basic` para tipos sem relacoes extraidas.

## Validar relacoes semanticas da Fase 5

Depois de regenerar o indice, valide a resolucao semantica aprovada com:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase5.validation-cases.json" `
  -FailOnValidationFailure
```

Os casos da Fase 5 conferem relacoes semanticas novas. Eles devem ser executados junto com as baterias anteriores quando houver rodada oficial.

Esses casos usam `source`, `target` e `expected_rule`, entao devem rodar no gerador/indexador. Se forem enviados por engano para `Test-KbIntelligenceQueries.ps1`, o resultado deve ser tratado primeiro como executor incompatível, nao como regressao real da regra.

## Validar consulta da Fase 6

Depois de localizar ou regenerar o indice canonico, valide `functional-trace-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase6.validation-cases.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-phase6-validation.json" `
  -FailOnValidationFailure
```

Os casos da Fase 6 conferem apenas a montagem da trilha funcional basica. Eles nao provam comportamento runtime nem substituem leitura do XML oficial.

Como os casos da Fase 6 validam consultas e trazem `query`, eles pertencem ao executor `Test-KbIntelligenceQueries.ps1`, nao ao fluxo de regeneracao via `New-KbIntelligenceIndex.ps1`.

## Saidas

- `json`: formato padrao para consumo por agentes e automacoes
- `text`: formato curto para leitura rapida em conversa ou terminal

## Regras de uso por agente

- consultar por `tipo + nome`, nunca apenas nome
- procurar primeiro por `KbIntelligence\kb-intelligence.sqlite` na pasta paralela da KB
- ignorar pastas `ArquivoMorto`, salvo pedido explicito do usuario para analise historica
- tratar o SQLite como derivado e regeneravel
- manter o XML oficial como fonte normativa
- antes de alterar objeto GeneXus coberto pelo indice, executar `impact-basic`
- tratar `impact-basic` como impacto tecnico direto, nao como prova funcional completa
- para perguntas funcionais curtas, `functional-trace-basic` pode reduzir a coleta inicial, mas a resposta final ainda deve separar `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- usar a linha e o `snippet` apenas como evidencia tecnica, nao como prova funcional completa
- quando a mudanca exigir semantica GeneXus, abrir o XML e revisar o `Source` efetivo
