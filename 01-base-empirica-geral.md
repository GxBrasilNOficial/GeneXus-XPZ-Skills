# 01 - Base Empirica Geral

## Papel do documento
empirico

## Nivel de confianca predominante
medio

## Depende de
09-historico-e-inventario-publico.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 08-guia-para-agente-gpt.md

## Objetivo
Concentrar a base factual observada nos XMLs: pesquisa geral, matriz de Part types, campos do no Object e diffs estruturais por tipo.

## Fontes consolidadas
- 01-base-empirica-geral.md
- 10-matriz-part-types-por-tipo.md
- 11-campos-estaveis-vs-variaveis.md
- 12-diffs-estruturais-por-tipo.md

## Origem incorporada - 01-base-empirica-geral.md

## Papel do documento
conceitual

## Nível de confiança predominante
alto

## Depende de
30-inventario-bruto-kb.md

## Usado por
02-genexus-xpz-generation-rules.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Consolidar a leitura estrutural do acervo XML extraído da KB.
Servir como base conceitual para os documentos empíricos e operacionais.

## Fonte usada

- `Evidência direta`: a consolidação abaixo usa o inventário em `C:\Dev\Knowledge\GeneXus\30-inventario-bruto-kb.md`.
- `Evidência direta`: foram lidos XMLs do acervo `C:\SANITIZED\ObjetosDaKbEmXml`.

## Panorama do acervo

- `Evidência direta`: o acervo contém `7219` XMLs distribuídos em `32` diretórios de tipos extraídos.
- `Evidência direta`: os maiores conjuntos por diretório são `Procedure` (`2281`), `WebPanel` (`1196`), `SubTypeGroup` (`709`), `SDT` (`594`), `Domain` (`592`), `ThemeClass` (`501`), `Module` (`279`), `Image` (`250`), `Index` (`228`), `Transaction` (`183`) e `WorkWithForWeb` (`183`).
- `Evidência direta`: o inventário bruto registrou `0` arquivos problemáticos na leitura XML.

## Estrutura XML recorrente

- `Evidência direta`: os objetos extraídos seguem o formato geral `<Object ...>` com atributos como `guid`, `name`, `type`, `parent`, `parentGuid`, `moduleGuid` e `fullyQualifiedName`.
- `Evidência direta`: quando há conteúdo interno, ele aparece em blocos `<Part type="...">...</Part>`.
- `Inferência forte`: para este acervo, o GUID em `Object/@type` é um identificador estável do tipo extraído do objeto.
- `Hipótese`: o mesmo catálogo de `Object/@type` e `Part/@type` pode se repetir em outros exports GeneXus 18, mas isso não foi provado aqui.

## Catálogo observado de tipos extraídos

| Diretório extraído | Contagem | GUID observado em `Object/@type` | Classificação |
| --- | ---: | --- | --- |
| `API` | 1 | `36e32e2d-023e-4188-95df-d13573bac2e0` | `Evidência direta` |
| `ColorPalette` | 1 | `3affc0b3-494b-4d84-9ec1-3a6ab8349cda` | `Evidência direta` |
| `Dashboard` | 1 | `526aba9f-a725-4bc7-b1db-0b9f92ac9550` | `Evidência direta` |
| `DataProvider` | 24 | `2a9e9aba-d2de-4801-ae7f-5e3819222daf` | `Evidência direta` |
| `DataSelector` | 2 | `ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af` | `Evidência direta` |
| `DataStore` | 2 | `dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0` | `Evidência direta` |
| `DeploymentUnit` | 1 | `bf08dfb1-361c-4e7e-ad54-391e56e60b49` | `Evidência direta` |
| `DesignSystem` | 2 | `78b3fa0e-174c-4b2b-8716-718167a428b5` | `Evidência direta` |
| `Document` | 3 | `faeb588c-dcce-4dad-9af3-cdd11b961a32` | `Evidência direta` |
| `Domain` | 592 | `00972a17-9975-449e-aab1-d26165d51393` | `Evidência direta` |
| `ExternalObject` | 18 | `c163e562-42c6-4158-ad83-5b21a14cf30e` | `Evidência direta` |
| `File` | 81 | `1132ac08-290f-4fd1-bd18-64777b7329d1` | `Evidência direta` |
| `Folder` | 7 | `00000000-0000-0000-0000-000000000006` | `Evidência direta` |
| `Generator` | 5 | `ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0` | `Evidência direta` |
| `Image` | 250 | `9fb193d9-64a4-4d30-b129-ff7c76830f7e` | `Evidência direta` |
| `Table` | 228 | `857ca50e-7905-0000-0007-c5d9ff2975ec` | `Evidência direta` |
| `Language` | 1 | `88313f43-5eb2-0000-0028-e8d9f5bf9588` | `Evidência direta` |
| `Module` | 279 | `00000000-0000-0000-0000-000000000008` | `Evidência direta` |
| `PackagedModule` | 16 | `c88fffcd-b6f8-0000-8fec-00b5497e2117` | `Evidência direta` |
| `Panel` | 7 | `d82625fd-5892-40b0-99c9-5c8559c197fc` | `Evidência direta` |
| `PatternSettings` | 2 | `83476c1e-fa72-4229-9930-f51b954fca2d` | `Evidência direta` |
| `Procedure` | 2281 | `84a12160-f59b-4ad7-a683-ea4481ac23e9` | `Evidência direta` |
| `SDT` | 594 | `447527b5-9210-4523-898b-5dccb17be60a` | `Evidência direta` |
| `Stencil` | 11 | `624a8b31-36f0-4292-adba-2d270d1e3537` | `Evidência direta` |
| `SubTypeGroup` | 709 | `87313f43-5eb2-41d7-9b8c-e8d9f5bf9588` | `Evidência direta` |
| `Theme` | 7 | `c804fdbd-7c0b-440d-8527-4316c92649a6` | `Evidência direta` |
| `ThemeClass` | 501 | `d4876646-98dd-419b-8c1c-896f83c48368` | `Evidência direta` |
| `ThemeColor` | 24 | `5592de59-d30a-499d-9100-a7006d3674f2` | `Evidência direta` |
| `Transaction` | 183 | `1db606f2-af09-4cf9-a3b5-b481519d28f6` | `Evidência direta` |
| `UserControl` | 7 | `562f4793-aabe-449f-8821-fc77e550698e` | `Evidência direta` |
| `WebPanel` | 1196 | `c9584656-94b6-4ccd-890f-332d11fc2c25` | `Evidência direta` |
| `WorkWithForWeb` | 183 | `78cecefe-be7d-4980-86ce-8d6e91fba04b` | `Evidência direta` |

## Padrões internos observados por grupos

### `Procedure`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Procedure\PRCExemplo0001.xml` aparecem `Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff"`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c` e `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- `Evidência direta`: nesse mesmo XML há um trecho `parm(...)` dentro de um bloco `Part`, o que mostra que parâmetros podem estar armazenados separadamente do código principal.
- `Inferência forte`: objetos em `Procedure` usam um conjunto recorrente de `Part type` para código, parâmetros, variáveis e propriedades, mas esta documentação não nomeia semanticamente cada `Part type` além do que foi visto.

### `WebPanel`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WPExemplo0001.xml` há um `Source` com `GxMultiForm`.
- `Evidência direta`: no mesmo arquivo há outro `Source` com blocos `Event`.
- `Inferência forte`: em `WebPanel`, layout declarativo e código de eventos tendem a aparecer em partes distintas do XML.

### `Transaction`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Transaction\TRNExemplo0001.xml` e `TRNExemplo0002.xml` aparecem nós `<Level ...>` e vários `<AttributeProperties Attribute="...">`.
- `Inferência forte`: objetos em `Transaction` carregam estrutura hierárquica e configuração de atributos dentro de `Part type` próprios.

### `SDT`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SDT\SDTExemplo0001.xml` aparecem `<Level>`, `<LevelInfo>` e `<Item>`.
- `Inferência forte`: no acervo observado, `SDT` representa estrutura hierárquica declarada, distinta do padrão de `Transaction`.

### `SubTypeGroup`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SubTypeGroup\STGExemplo0001.xml` aparecem vários nós `<Subtype guid="...">`.
- `Inferência forte`: `SubTypeGroup` registra vínculos de subtype/supertype por GUID e nome, não regras procedurais.

### `ThemeClass`

- `Evidência direta`: arquivos como `ActionAttribute.xml` e `ActionButtons.xml` contêm propriedades `ThemeElementThemeTypes` e `ThemeElementInternalType`.
- `Inferência forte`: essas propriedades são marcadores estáveis para reconhecer objetos do diretório `ThemeClass` neste acervo.

### `WorkWithForWeb`

- `Evidência direta`: arquivos como `WorkWithWebTRNExemplo0001.xml` exibem `Object/@name` iniciando com `WorkWithWeb`.
- `Evidência direta`: nesses mesmos arquivos aparece `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">`.
- `Inferência forte`: os XMLs em `WorkWithForWeb` guardam configuração de artefatos gerados por padrão web associada ao objeto pai.

## Relações aparentes observadas

- `Evidência direta`: muitos objetos trazem `parent`, `parentGuid` e `parentType` no próprio nó `<Object>`.
- `Evidência direta`: objetos em `WorkWithForWeb` usam `parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6"` quando ligados a `Transaction`, como em `WorkWithWebTRNExemplo0001.xml`.
- `Evidência direta`: `WebPanel\WPExemplo0001.xml` referencia outros objetos no código de eventos, como `WPExemploA`, `WWExemploA`, `WWExemploB` e `WPExemploB`.
- `Inferência forte`: dependências entre objetos podem ser detectadas combinando `parent*`, referências em propriedades e chamadas nominais em blocos de código.
- `Hipótese`: uma etapa futura pode transformar essas relações aparentes em um grafo de dependências mais confiável, desde que haja validação adicional por tipo de objeto.

## Leitura cautelosa dos GUIDs de `Part type`

- `Evidência direta`: o inventário bruto catalogou GUIDs de `Part type` por ocorrência.
- `Inferência forte`: alguns `Part type` aparecem recorrentemente dentro do mesmo grupo de objetos e podem ser usados como assinatura estrutural.
- `Hipótese`: o significado funcional exato de cada `Part type` ainda precisa ser rotulado com validação mais fina, objeto a objeto.

## Limites desta consolidação

- `Evidência direta`: o acervo foi analisado já decomposto em XMLs por objeto, não como o `XPZ` binário/original completo.
- `Inferência forte`: a documentação atual descreve bem a organização dos XMLs extraídos desta KB.
- `Hipótese`: ainda não é seguro generalizar todos os padrões acima para qualquer KB GeneXus 18 sem nova amostragem.

## Evidencia complementar - consulta ao acervo real apos a bateria de importacao

## Papel do complemento
empirico complementar

## Objetivo
Registrar o que a leitura direta do acervo real em `C:\SANITIZED\ObjetosDaKbEmXml` acrescentou aos resultados da bateria controlada de importacao.
Separar com mais precisao o que e falta de shape, o que e dependencia semantica da KB e o que e apenas diferenca de nomenclatura reconhecida pela IDE.

- `Evidência direta`: a consulta real foi direcionada aos tipos que ficaram problemáticos ou ambíguos na bateria: `Folder`, `PatternSettings`, `Theme`, `API`, `Transaction` e depois tambem `Attribute`.
- `Evidência direta`: numa primeira passada em `C:\SANITIZED\ObjetosDaKbEmXml`, `Attribute` nao apareceu como diretório proprio e os atributos observados surgiam principalmente embutidos em `Transaction`.
- `Evidência direta`: depois foi consultado um XML extraido de export full da KB em caminho privado sanitizado, onde apareceram objetos `Attribute` top-level com raiz `<Attribute ... name="...">`.
- `Evidência direta`: esses `Attribute` top-level foram extraidos para `C:\SANITIZED\ObjetosDaKbEmXml\Attribute` e a pasta foi saneada para manter apenas os atributos reais, removendo referencias inline.
- `Inferência forte`: `Attribute` deixou de estar sem evidencia top-level; o risco atual passa a ser distinguir definicao real de atributo contra ocorrencia contextual dentro de outros objetos.

### `Folder`

- `Evidência direta`: exemplos reais em `C:\SANITIZED\ObjetosDaKbEmXml\Folder\EXEMPLO-SANITIZADO.xml` usam `Object/@type="00000000-0000-0000-0000-000000000006"`.
- `Evidência direta`: esses exemplos sao extremamente curtos, com `Part type="babf62c5-0111-49e9-a1c3-cc004d90900a"` vazio e propriedades como `Name` e `IsDefault`.
- `Evidência direta`: exemplos reais como `Main Programs.xml` e `ToBeDefined.xml` mostram o mesmo `Object/@type` de `Folder` com pequenas variacoes de propriedades, reforcando o mesmo tipo estrutural para pastas organizacionais da KB.
- `Evidência direta`: as capturas da janela `New Object` da IDE mostram que `Category` e o nome do agrupador visual da lista de tipos, com grupos como `Data Management`, `User Interface`, `BPM`, `Resources`, `Documentation`, `Extensibility`, `Deploy`, `Super App`, `Reporting`, `Test` e `ALL`.
- `Evidência direta`: nessas mesmas capturas, um mesmo tipo pode aparecer em mais de uma `Category` da UI, como `Web Theme` em `User Interface` e `Resources`, e `User Control` em `User Interface` e `Extensibility`.
- `Inferência forte`: o shape XML de `Folder` nesta KB e minimo e estavel.
- `Inferência forte`: isso reforca que `Category`, no contexto da IDE, funciona como rotulo de agrupamento visual de tipos de objeto, nao como tipo XML equivalente a `Folder`.
- `Inferência forte`: como a IDE reconheceu o teste importado como `Category`, a divergencia atual parece ligada ao vocabulario de exibicao da interface/importador para agrupadores organizacionais, e nao a um envelope XML complexo ou a um segundo tipo estrutural concorrente.

### `PatternSettings`

- `Evidência direta`: os exemplos reais `WorkWith.xml` e `WorkWithDevices.xml` guardam configuracao dentro de `<Data Pattern="..."> <![CDATA[ ... ]]> </Data>`.
- `Evidência direta`: o XML interno referencia IDs de `Pattern`, `ContextVariable`, `LoadProcedure`, `Security` e outros artefatos associados ao pattern registrado.
- `Inferência forte`: `PatternSettings` nao deve ser tratado como objeto declarativo autocontido; ele depende fortemente do pattern correspondente estar registrado no ambiente de destino.
- `Evidência direta`: num teste posterior isolado com o objeto real `WorkWith`, `Pattern Settings 'WorkWith'` importou com sucesso no ambiente de teste.
- `Inferência forte`: `PatternSettings` deixa de ser uma pendencia estrutural aberta nesta trilha; o ponto operacional passa a ser usar caso real compativel com pattern efetivamente reconhecido no alvo.

### `Theme`

- `Evidência direta`: o exemplo real `ThemeExemploMobileA.xml` contem `PredefinedTypes` e classes visuais concretas como `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: essas classes aparecem referenciadas por outras classes no proprio tema, por exemplo `Group` referencia `TextBlockGroupCaption` e `TableSection` referencia `HorizontalLine`.
- `Inferência forte`: um tema simples mas valido precisa preservar nao apenas classes isoladas, e sim o grafo minimo de classes referenciadas internamente.
- `Evidência direta`: num consolidado revisado posterior, o proprio `ThemeExemploMobileA` real foi importado no ambiente de teste e ainda assim falhou com `Theme class 'TableDetail' does not exist`, `Theme class 'TableSection' does not exist` e `Theme class 'TextBlockGroupCaption' does not exist`.
- `Evidência direta`: a pasta real `C:\SANITIZED\ObjetosDaKbEmXml\ThemeClass` contem objetos `ThemeClass` top-level separados para `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: num teste isolado posterior, esses tres `ThemeClass` reais foram importados com sucesso e, logo em seguida, o `Theme 'ThemeExemploMobileA'` tambem importou com sucesso.
- `Inferência forte`: nesta trilha, `Theme` deixa de parecer um problema de serializacao pura; o requisito operacional observado e materializar tambem as `ThemeClass` auxiliares referenciadas pelo tema.

### `API`

- `Evidência direta`: nesta trilha, a KB observada traz apenas `1` objeto `API` real.
- `Evidência direta`: esse unico caso real corresponde a uma construcao manual/local da KB, e nao a uma familia ampla observada com multiplos exemplos comparaveis.
- `Evidência direta`: nesta trilha documental, nao ha evidencia de ferramenta complementar de automacao de `API` atuando sobre esse caso.
- `Evidência direta`: o exemplo real `APIExemploIntegracaoA.xml` usa varios `ATTCUSTOMTYPE` validos, incluindo `exo:GAMSession, GeneXusSecurity`, `exo:GAMError, GeneXusSecurity`, `exo:GAMUser, GeneXusSecurity`, `sdt:Messages, GeneXus.Common`, `sdt:SDTExemploProdutoBasicoA` e `sdt:SDTExemploTribSelecaoA`.
- `Evidência direta`: o mesmo exemplo tambem depende de `Procedure` e eventos reais no codigo fonte.
- `Inferência forte`: por haver apenas um caso real na KB, `API` deve ser lida aqui como estudo de caso operacional da KB analisada, e nao como familia GeneXus ja generalizavel nesta base.
- `Inferência forte`: em `API`, o envelope XML e relativamente bem definido, mas os tipos customizados e procedimentos referenciados precisam existir de fato na KB de destino.
- `Inferência forte`: nao e seguro inventar `ATTCUSTOMTYPE`; ele deve copiar um valor comprovado ou apontar para tipo efetivamente existente no alvo.
- `Evidência direta`: num teste isolado posterior, os SDTs reais `SDTExemploProdutoBasicoA`, `SDTExemploProdutoBasicoB`, `SDTExemploProdutoBasicoC`, `SDTExemploProdutoBasicoD`, `SDTExemploTribA` e `SDTExemploTribSelecaoA` importaram com sucesso antes da tentativa da `API`.
- `Evidência direta`: nesse mesmo teste, `API 'APIExemploIntegracaoA'` deixou de falhar por `ATTCUSTOMTYPE` e passou a falhar por `Object Reference PRCExemploListaA not found`, `Invalid attribute 'DomainExemploTipoA'` e `'TRNExemploProdutoA' invalid property`.
- `Inferência forte`: o gargalo atual de `API` nesta trilha ja nao e mais tipagem `SDT`; ele ficou reduzido a `Procedure` e contexto de negocio realmente existentes na KB de destino.
- `Evidência direta`: numa rodada posterior, `Domain 'DomainExemploTipoA'` importou com sucesso e a `Procedure 'PRCExemploListaA'` foi localizada no acervo real.
- `Evidência direta`: ao tentar incluir essa `Procedure`, ela falhou por depender de uma cadeia grande de transacoes e atributos da entidade principal e de satelites relacionados, alem de dominios auxiliares como `SimOuNao`, `DomainExemploGrupoA` e `DomainExemploLocalA`.
- `Evidência direta`: na mesma tentativa, a `API` avancou mais um passo e passou a falhar por outra `Procedure` faltante: `PRCExemploTribSelecaoA`.
- `Evidência direta`: essa segunda `Procedure` tambem existe no acervo real e, ao ser inspecionada, mostrou dependencia adicional de `Data Provider` (`DPExemploTribSelecaoA`), `Domain 'DomainExemploRomaneioA'` e atributos tributarios adicionais da cadeia funcional.
- `Inferência forte`: `API` entra definitivamente na zona de dependencia de negocio pesada; para este caso, fechar a importacao deixou de ser tarefa de empacotar poucos objetos auxiliares e passou a exigir uma subarvore funcional relevante da KB.

### `Transaction`

- `Evidência direta`: exemplos reais como `TRNExemploComplexaA.xml` trazem `<Level ...>` com muitos `<Attribute ... guid="...">NomeDoAtributo</Attribute>` e varios blocos `<AttributeProperties Attribute="...">`.
- `Evidência direta`: no mesmo tipo aparecem variaveis nomeadas `Context`, `TrnContext` e `TrnContextAtt`, com `ATTCUSTOMTYPE` como `sdt:Context`, `sdt:TransactionContext` e `sdt:TransactionContext.Attribute`.
- `Inferência forte`: em `Transaction`, o shape estrutural pode ser inferido por familia, mas o objeto final continua dependente da existencia real dos atributos e SDTs de contexto na KB.
- `Inferência forte`: a falha observada na bateria foi coerente com o acervo real; nao faltava apenas envelope, faltavam atributos reais e tipos de contexto validos.
- `Evidência direta`: num teste isolado posterior, os `Attribute` reais de `TRNExemploMinBancoA`, o `SDT 'Context'` e o `SDT 'TransactionContext'` importaram com sucesso antes da tentativa da `Transaction`.
- `Evidência direta`: nesse mesmo teste, `Transaction 'TRNExemploMinBancoA'` importou com sucesso e ainda disparou geracao de pattern bem-sucedida para `WWExemploMinBancoA`.
- `Evidência direta`: em outro teste pratico controlado, uma `Transaction` minima so foi importada com sucesso apos a inclusao explicita dos `Attribute` top-level correspondentes no mesmo pacote.
- `Evidência direta`: nesse caso, os nos `<Attribute>` dentro de `<Level>` nao bastaram para definir os atributos; eles funcionaram apenas como referencia contextual do `Level`.
- `Evidência direta`: numa bateria posterior de importacao real, uma `Transaction` minima tambem foi validada com `DescriptionAttribute` e `AttributeProperties`, desde que os `Attribute` top-level correspondentes estivessem presentes no pacote e o `Part` principal preservasse o shape esperado da familia.
- `Evidência direta`: nessa mesma bateria, `AttributeProperties` funcionou tanto isoladamente quanto combinado com `DescriptionAttribute`.
- `Evidência direta`: `DescriptionAttribute` foi aceito no caso minimo expandido quando apontava para atributo existente no mesmo `Level`.
- `Inferência forte`: a distincao entre `Attribute` top-level e `Attribute` inline em `Level` continua essencial nos casos validados de montagem de pacote minimo de `Transaction`.
- `Inferência forte`: `Transaction` fica destravada nesta trilha quando o pacote inclui os atributos top-level reais do `Level` e os SDTs de contexto exigidos pelo caso.

### `Attribute`

- `Evidência direta`: o XML extraido de export full da KB, mantido em caminho privado sanitizado, contem objetos `Attribute` top-level com raiz `<Attribute ...>`, e nao `<Object ...>`.
- `Evidência direta`: um atributo real completo, como `AtributoExemploComplexoA`, traz atributos XML como `guid`, `name`, `fullyQualifiedName`, `description`, `moduleGuid`, `parentGuid`, alem de `Part` e `Properties`.
- `Evidência direta`: no mesmo export tambem aparecem nos curtos `<Attribute key="True|False" guid="...">NomeDoAtributo</Attribute>` dentro de `<Level>` de `Transaction`.
- `Evidência direta`: os nos curtos compartilham o mesmo `guid` do atributo real top-level correspondente; eles funcionam como referencia contextual do atributo no nivel da `Transaction`, nao como definicao top-level.
- `Evidência direta`: na saneacao da pasta `C:\SANITIZED\ObjetosDaKbEmXml\Attribute`, permaneceram `7646` atributos reais top-level e foram removidas `8539` referencias inline `Attribute_*.xml`.
- `Evidência direta`: na ampliacao da busca para um diretório privado sanitizado do modelo GeneXus, nomes sugestivos como `GAMExampleUserCustomAttributes.xml` nao se revelaram objeto `Attribute`; esse arquivo se apresentou como `Web Panel`.
- `Evidência direta`: arquivos como `FabricaBrasil18selectAttributes.Filters` se mostraram apenas configuracoes auxiliares de filtro/interface, nao export de objeto `Attribute`.
- `Inferência forte`: `Attribute` top-level ja esta empiricamente provado nesta trilha, mas exige cuidado extra porque o mesmo nome de elemento XML tambem aparece como referencia inline em `Transaction`.
- `Inferência forte`: para montar ou extrair corpus de `Attribute`, o filtro correto nao e “todo no chamado Attribute”, e sim apenas o no raiz completo com `name` e estrutura de `Part` e `Properties`.
- `Evidência direta`: no teste combinado posterior, `Attribute 'AtributoExemploTesteA'` ja nao falhou por shape; falhou em propriedade semantica, com `ControlItemDescription='AtributoExemploDescricaoRelacionada'` apontando para atributo desconhecido no destino.
- `Inferência forte`: `Attribute` saiu da zona “shape insuficiente” e entrou na mesma classe metodologica de dependencia contextual de KB em propriedades como `ControlItemDescription`, `idBasedOn` e outras referencias nominais a atributos reais.
- `Evidência direta`: num consolidado revisado posterior, o `Attribute 'AtributoExemploFechadoA'`, extraido do acervo real e sem `ControlItemDescription`, importou com sucesso.
- `Inferência forte`: `Attribute` passa a ser considerado estruturalmente destravado nesta trilha, desde que o caso escolhido seja top-level real e semanticamente fechado no ambiente de destino.

### `Table`

- `Evidência direta`: leitura direta de `228` objetos `Table` em `C:\SANITIZED\ObjetosDaKbEmXml\Table` confirma exatamente `2` `Part type` em `100%` dos casos — sem variação entre os exemplares.
- `Evidência direta`: `Part type="00000000-0000-0000-0002-000000000004"` contém `<Key>` com lista de `<Item guid="...">NomeDoAtributo</Item>`, representando a chave primária da tabela.
- `Evidência direta`: `Part type="a5c0e770-560d-0001-0001-7fe71c260de3"` contém `<Indexes>` com um ou mais `<TableIndex><Index ... type="9e750647-3679-0000-0100-2529de263960">`, representando os índices da tabela.
- `Evidência direta`: nenhum terceiro `Part type` foi encontrado em nível de `Object` nos 228 exemplares.
- `Evidência direta`: o nó `<Object>` de `Table` NÃO possui atributo `parent` por nome; possui apenas `parentGuid` e `moduleGuid`. Esse comportamento difere de `Transaction`, `Procedure` e outros tipos que carregam `parent` nominal — `Table` é a única família de tamanho relevante observada sem `parent` nomeado.
- `Evidência direta`: cardinalidade da chave primária nos 228 objetos: 1 campo (34 tabelas, 15%), 2 campos (106, 46%), 3 campos (59, 26%), 4 campos (15, 7%), 5 campos (9, 4%), 6 campos (5, 2%). Chaves compostas representam 85% do corpus.
- `Evidência direta`: número de índices por `Table`: mínimo 2, máximo 59, média 6,5 — observado nos 228 exemplares.
- `Evidência direta`: todos os `1480` objetos `Index` embutidos usam `type="9e750647-3679-0000-0100-2529de263960"` e contêm exatamente `1` `Part type` interno: `62cfa789-c127-0001-0100-77676175e433` (lista de `<Members>`).
- `Evidência direta`: dos 1480 índices, `1036` têm `Source="Automatic"` (gerados pelo GeneXus) e `444` têm `Source="User"` (definidos manualmente). Todo `Table` tem ao menos `1` índice `Type="Unique" Source="Automatic"` correspondente à chave primária.
- `Inferência forte`: `Table` não carrega referência explícita à `Transaction` correspondente no XML; a associação é feita por convenção nominal — mesmo nome de objeto.
- `Inferência forte`: o risco residual de `Table` está na reassociação correta com a `Transaction` no destino, não no envelope ou Part types — ambos são estruturalmente simples, fixos e sem variação entre famílias.

## Complemento posterior - IDE exportando `Table`, `Index` e `WorkWithForWeb`

- `Evidência direta`: o export isolado `XPZExemploTabelaA.xpz` contem `228` objetos top-level no tipo `857ca50e-7905-0000-0007-c5d9ff2975ec`.
- `Evidência direta`: esses objetos top-level de `Table` usam nomes iguais aos das `Transaction` correspondentes, e nao uma convenção paralela exclusiva da camada fisica.
- `Evidência direta`: dentro de cada `Table` exportada aparecem blocos `<Indexes>` com filhos `<Index ... type="9e750647-3679-0000-0100-2529de263960">`.
- `Evidência direta`: o export isolado `XPZExemploIndiceVazioA.xpz` veio vazio, sem `Objects` nem `Attributes`.
- `Inferência forte`: nesta trilha da IDE, `Table` existe como familia top-level propria, enquanto `Index` aparece subordinado a `Table`, e nao como conjunto top-level isolado.
- `Evidência direta`: o export `XPZExemploTabelaIndiceA.xpz` repetiu exatamente o mesmo comportamento de `Table`: `228` objetos top-level do tipo `857ca50e-7905-0000-0007-c5d9ff2975ec` e nenhum objeto top-level adicional para `Index`.
- `Inferência forte`: pedir `Table + Index` explicitamente na IDE nao muda a forma de serializacao observada; `Index` continua consolidado dentro de `Table`.
- `Evidência direta`: em `WorkWithForWeb` real, as referencias de atributo dentro do `CDATA` do pattern usam o prefixo estrutural fixo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Inferência forte`: para `WorkWithForWeb`, esse formato deve ser tratado como convenio estrutural do pattern, e nao como reflexo do GUID do `Attribute` top-level nem do GUID inline do `Level` da `Transaction`.
- `Evidência direta`: o export `XPZExemploTabelaTRNWWPatternA.xpz` veio com `596` objetos: `228` `Table`, `183` `Transaction`, `183` `WorkWithForWeb` e `2` `PatternSettings`, sem `Attributes`.
- `Evidência direta`: o export `XPZExemploTabelaTRNDataSelectorA.xpz` veio com `413` objetos: `228` `Table`, `183` `Transaction` e `2` `DataSelector`, tambem sem `Attributes`.
- `Evidência direta`: no export combinado com `WorkWithForWeb`, a `Transaction` mantem a propriedade `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b=True`.
- `Evidência direta`: no mesmo export, `PatternSettings 'WorkWith'` materializa `ContextVariable`, `LoadProcedure`, `Security Check` e `NotAuthorized` no XML interno.
- `Inferência forte`: a ponte operacional real do pattern web observado fica distribuida entre `Transaction` (aplicacao do pattern), `WorkWithForWeb` (instancia por objeto), `PatternSettings` (configuracao global do pattern) e `Table` (camada fisica com indices internos).
- `Evidência direta`: o par de exports `XPZExemploTRNWWComparacaoSemWW.xpz` e `XPZExemploTRNWWComparacaoComWW.xpz` forneceu um recorte minimo comparavel da mesma `Transaction 'TRNExemploMinPaisA'`.
- `Evidência direta`: `XPZExemploTRNWWComparacaoSemWW` veio com `7` objetos, `10` atributos top-level e `25` identidades; `XPZExemploTRNWWComparacaoComWW` veio com `8` objetos, os mesmos `10` atributos e `49` identidades.
- `Evidência direta`: a unica diferenca de objeto entre os dois recortes foi a entrada de `WWExemploMinPaisA`.
- `Evidência direta`: apesar disso, a entrada de `WWExemploMinPaisA` quase dobrou o total de identidades de contexto em `ObjectsIdentityMapping`, incluindo referencias adicionais a `DomainExemploUfA`, `WPExemploRelacionamentoA`, `WPExemploAtualizacaoServidorA` e atributos relacionados.
- `Inferência forte`: num caso minimo real, incluir `WorkWithForWeb` acrescenta pouco no bloco `<Objects>`, mas pode expandir bastante o grafo de contexto que o pacote precisa descrever em `ObjectsIdentityMapping`.

## Complemento posterior - export combinado de `API` e da pilha visual

### `Table + Domain + Transaction + SDT + API + Procedure + DataProvider`

- `Evidência direta`: o export `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos e `0` atributos top-level.
- `Evidência direta`: a distribuicao observada foi `2282` `Procedure`, `594` `SDT`, `592` `Domain`, `228` `Table`, `183` `Transaction`, `24` `DataProvider` e `1` `API`.
- `Evidência direta`: o `API` exportado nesse pacote e `APIExemploIntegracaoA`.
- `Evidência direta`: o mesmo pacote prova que a trilha real de export da IDE para `API` relevante de negocio ja puxa junto uma massa grande de `Procedure`, `SDT`, `Domain`, `Table`, `Transaction` e `DataProvider`.
- `Evidência direta`: no pacote, ha `Domain` enumerado como `DomainExemploTipoA`, com valores de negocio distintos no mesmo conjunto exportado.
- `Evidência direta`: no mesmo recorte, `SDT` como `SDTExemploProdutoBasicoA` e `Procedure` como `PRCExemploListaA` aparecem no mesmo conjunto exportado.
- `Inferência forte`: para `API`, o melhor recorte de engenharia reversa deixa de ser o objeto isolado e passa a ser essa combinacao funcional mais ampla.
- `Inferência forte`: isso reforca a leitura anterior de que a pendencia remanescente de `API` nao e serializacao do envelope, e sim dependencia de subarvore funcional de negocio.

### `Table + Transaction + ColorPalette + DesignSystem + Theme + WebTheme + Category + ThemeClass + ThemeColor`

- `Evidência direta`: o export `XPZExemploTemaA.xpz` veio com `947` objetos e `0` atributos top-level.
- `Evidência direta`: a distribuicao observada foi `501` `ThemeClass`, `228` `Table`, `183` `Transaction`, `24` `ThemeColor`, `7` `Theme`, `2` `DesignSystem`, `1` `Folder` e `1` `ColorPalette`.
- `Evidência direta`: o pacote contem uma pasta organizacional `GAM_Samples-web`, reforcando que a familia visual tambem pode carregar o agrupador estrutural junto.
- `Evidência direta`: o mesmo pacote mostrou `ThemeClass` como `ActionAttribute`, `ActionButtons` e `ActionButtonsHovered`, alem de varios `ThemeColor` e `Theme` reais.
- `Evidência direta`: nesse export, `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` aparecem juntos no mesmo recorte exportado pela IDE.
- `Inferência forte`: a pilha visual completa pode e deve ser estudada como familia combinada, e nao como tipos totalmente independentes.
- `Inferência forte`: esse recorte reduz o risco de interpretar `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` fora do contexto visual em que a IDE os serializa de fato.

### `Attribute + Domain + Transaction + SubtypeGroup`

- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades em `ObjectsIdentityMapping`.
- `Evidência direta`: o contêiner desse pacote usou `KMW`, `Source`, `Objects`, `Attributes`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: a presenca simultanea de `Objects` e `Attributes` top-level no mesmo `.xpz` confirma que a trilha normal da IDE tambem pode exportar familia mista de objetos e atributos reais, e nao apenas pacotes com `Objects` sem bloco `Attributes`.
- `Inferência forte`: para engenharia reversa de `Attribute` top-level e de sua relacao com `Transaction`, `Domain` e `SubtypeGroup`, esse recorte e mais informativo do que os pacotes sem `Attributes`.

### `Attribute + Domain + Transaction + SubtypeGroup + Table + Index`

- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Evidência direta`: esse pacote tambem usou o contêiner `KMW`, `Source`, `Objects`, `Attributes`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: a diferenca de `1117` para `1712` objetos entre os dois pacotes coincide com a entrada da camada fisica `Table`, enquanto o bloco de `Attributes` permaneceu estavel em `7646`.
- `Inferência forte`: isso reforca que `Table/Index` entram como ampliacao da familia logica anterior, sem deslocar `Attribute` top-level para dentro de `Objects` nem eliminar o bloco `Attributes`.

### Sintese operacional provisoria de `Table/Index`

- `Evidência direta`: na trilha observada, `Table` aparece como objeto top-level exportavel, enquanto `Index` aparece embutido dentro de `Table`.
- `Evidência direta`: pedir `Table + Index` na IDE nao criou objetos top-level adicionais de `Index`; a serializacao observada permaneceu centrada em `Table`.
- `Evidência direta`: os nomes top-level de `Table` acompanham os nomes das `Transaction` correspondentes.
- `Evidência direta`: em comparacao privada posterior de pares reais simples e densos da KB de origem, essa correspondencia nominal `Transaction` -> `Table` tambem se repetiu fora dos pacotes ja resumidos na base.
- `Evidência direta`: na mesma comparacao privada, os `Index` seguiram aparecendo apenas no bloco interno `<Indexes>` do objeto fisico, e nao como objeto top-level separado.
- `Evidência direta`: nessa mesma amostra privada, a lista de atributos-chave do primeiro `Level` da `Transaction` coincidiu com a lista do bloco `<Key>` da `Table`, tanto em chave simples quanto em chave composta.
- `Evidência direta`: na amostra privada comparada, cada `Table` observada trouxe exatamente `1` indice `Unique` automatico para a chave e um conjunto variavel de indices `Duplicate`, misturando casos `Automatic` e `User`.
- `Evidência direta`: nos mesmos pares privados comparados, todos os membros de indices `Automatic` observados ja estavam presentes no primeiro `Level` da `Transaction` correspondente.
- `Evidência direta`: na KB analisada, prefixo `I` identifica indice automaticamente criado pelo GeneXus a partir de PK ou FK definidas pelo modelador.
- `Evidência direta`: na mesma KB, prefixo `U` identifica indice criado manualmente pelo operador humano.
- `Evidência direta`: quando um indice automatico `I...` recebe nome mais descritivo nesta KB, a mudanca e apenas editorial; os campos e sua ordem permanecem exatamente os mesmos do indice criado pelo GeneXus.
- `Evidência direta`: o naming default do GeneXus para esses indices automaticos e pouco descritivo, normalmente centrado no nome da `Table` com numeracao incremental nos casos seguintes.
- `Evidência direta`: nos indices automaticos de FK, os campos seguem a mesma ordem definida pelo modelador na relacao da `Transaction` e refletida na `Table`.
- `Evidência direta`: na mesma amostra privada, os indices `Automatic` `Duplicate` apareceram principalmente em dois formatos recorrentes: atributo unico `...Id` e pares `...EmpresaId + ...Id|...Codigo`.
- `Evidência direta`: nessa mesma investigacao privada, muitos atributos `...Id` e `...Codigo` presentes no primeiro `Level` nao reapareceram em indices `Automatic`, inclusive em objetos mais densos.
- `Evidência direta`: os nomes amigaveis observados para varios indices `Duplicate` refletem convencao editorial/local da KB analisada, e nao devem ser tratados como padrao default do GeneXus.
- `Evidência direta`: os nomes mais amigaveis, abreviacoes e formas descritivas observadas em varios indices desta KB surgem da renomeacao humana para facilitar manutencao, leitura de erro e leitura de log; nao devem ser lidos como naming automatico do GeneXus nem como resposta normal a limite de 63 caracteres.
- `Evidência direta`: numa ampliacao posterior da amostra privada para todo o conjunto local de `Table`, os formatos mais recorrentes de indice `Automatic` `Duplicate` foram `...EmpresaId + ...Id|...Codigo`, depois atributos unicos de auditoria de usuario (`...InclusaoUsuarioId`, `...UltimaAtualizacaoUsuarioId`), depois `...EmpresaId` isolado, e so depois outros `...Id` unicos menos frequentes.
- `Evidência direta`: nessa mesma ampliacao, `101/228` `Table` locais combinavam ao mesmo tempo algum par `...EmpresaId + ...Id|...Codigo` e algum indice automatico de auditoria de usuario; `41/228` nao mostraram nenhum desses dois sinais na leitura aplicada.
- `Evidência direta`: numa releitura posterior do conjunto local completo com parse direto do bloco `<Indexes>`, `143/228` `Table` apresentaram pelo menos um indice `User`, enquanto `85/228` nao apresentaram nenhum `User`.
- `Evidência direta`: nesse mesmo recorte, entre as `Table` sem `User`, `69/85` ficaram com apenas `1` ou `2` indices `Automatic` `Duplicate`, e apenas `16/85` passaram de `2` indices `Automatic` `Duplicate`.
- `Evidência direta`: no recorte complementar, entre as `Table` com `User`, `124/143` ficaram na faixa de `1` a `3` indices `User`, e apenas `19/143` passaram de `3` indices `User`.
- `Evidência direta`: a releitura ampla encontrou apenas `3` `Table` sem qualquer indice `Automatic` `Duplicate`: `OperacaoFiscal`, `Pais` e `TipoDocumento`; nas tres, ainda assim havia pelo menos um indice `User`.
- `Evidência direta`: nesses tres casos excepcionais, o indice `User` observado cobria ordenacao ou busca por atributo simples de negocio, como `Descricao`, `Nome` ou `Id Descendente`.
- `Inferência forte`: esses tres casos devem ser lidos como excecao local da KB e possivel alvo de revisao de modelagem, nao como perfil representativo para materializacao conservadora de `Table`.
- `Evidência direta`: no mesmo recorte amplo, o acervo totalizou `429` indices `User`; `239/429` continham pelo menos um `Member` em `Descending`, e `229/429` terminavam com o ultimo `Member` em `Descending`.
- `Evidência direta`: no mesmo recorte, `190/429` indices `User` ficaram totalmente em `Ascending`, mostrando que nem todo indice manual desta KB existe para ordenacao descendente; parte deles cobre navegacao/consulta por combinacoes especificas de negocio.
- `Inferência forte`: dentro dessa amostra, os indices `Automatic` aparecem como recombinacoes de atributos ja materializados na propria `Transaction`, e nao como introducao de atributos fisicos alheios ao primeiro `Level`.
- `Inferência forte`: dentro dessa amostra, o padrao `...EmpresaId + ...Id|...Codigo` parece um dos sinais mais fortes de indice automatico adicional na camada fisica.
- `Inferência forte`: ao mesmo tempo, esse padrao por nome nao e suficiente sozinho para prever indice automatico; ele funciona como pista estrutural, nao como regra deterministica.
- `Inferência forte`: na KB analisada, a combinacao entre relacionamento principal (`...EmpresaId + ...Id|...Codigo`) e trilha de auditoria de usuario parece formar o nucleo mais recorrente dos indices `Automatic` adicionais.
- `Inferência forte`: os indices automaticos de auditoria observados na amostra devem ser lidos como mais um caso de FK automatica renomeada de forma amigavel, e nao como familia especial criada por regra separada.
- `Inferência forte`: a presenca de indice `User` (`U...`) deve ser lida como tuning manual e empirico por volume e ordenacao real, e nao como desdobramento estrutural obrigatorio da `Transaction`.
- `Inferência forte`: na KB analisada, um indice `User` tende a surgir quando a ordenacao real de grid, relatorio ou procedure diverge dos indices automaticos disponiveis e a massa de registros ja justifica um indice dedicado.
- `Inferência forte`: um caso recorrente de indice `User` e reaproveitar quase a mesma base de um indice automatico, mas ajustando direcao de ordenacao, especialmente com o ultimo campo em `Descending` para buscar o registro mais recente.
- `Inferência forte`: a ausencia de indice `User` em varias `Table` deve ser lida como decisao valida e consciente do modelador, quando o volume esperado e pequeno e o custo de manutencao do indice nao compensa.
- `Inferência forte`: fora do nucleo mais carregado de `User`, a familia residual mais comum nao e ausencia total de indices, e sim `Table` resolvida apenas com PK e poucos `Automatic` `Duplicate`, sem necessidade de tuning manual adicional.
- `Inferência forte`: os raros casos sem `Automatic` `Duplicate` formam excecao de tabela muito simples, onde um unico `User` pode cumprir papel de busca ou ordenacao sem haver malha de FK automatica relevante.
- `Inferência forte`: para geracao conservadora de `XPZ`, o erro mais provavel do agente passa a ser excesso de `User` inventado; a distribuicao observada recomenda preferir ausencia de `User` ou poucos `User` antes de extrapolar tuning pesado.
- `Inferência forte`: para ler a camada fisica desta base, o eixo primario de correlacao deve ser `Transaction -> Table`, tratando os `Index` como estrutura interna da `Table`.
- `Inferência forte`: para evolucao metodologica da base, o pacote mais informativo nao e `Index` isolado, e sim combinacoes como `Transaction + Table`, `Transaction + Table + WorkWithForWeb + PatternSettings` e `Attribute + Domain + Transaction + SubtypeGroup + Table`.





## Origem incorporada - 10-matriz-part-types-por-tipo.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 01-base-empirica-geral.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Catalogar os `Part type` observados por tipo de objeto, com frequência e exemplos.
Separar observação direta de leitura heurística preliminar.

- Evidência direta: frequências calculadas a partir dos XMLs extraídos em C:\SANITIZED\ObjetosDaKbEmXml.
- Inferência forte: a classificação preliminar abaixo usa presença e vazios recorrentes como heurística do acervo, não teste de importação.

## API

- Evidência direta: Object/@type = 36e32e2d-023e-4188-95df-d13573bac2e0 em 1 objetos.
- Evidência direta: média de Part por objeto: 5.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## ColorPalette

- Evidência direta: Object/@type = 3affc0b3-494b-4d84-9ec1-3a6ab8349cda em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 5d481862-64bc-4e88-8af2-e21c276dab77 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Dashboard

- Evidência direta: Object/@type = 526aba9f-a725-4bc7-b1db-0b9f92ac9550 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a51ced48-7bee-0001-ab12-04e9e32123d1 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DataProvider

- Evidência direta: Object/@type = 2a9e9aba-d2de-4801-ae7f-5e3819222daf em 24 objetos.
- Evidência direta: média de Part por objeto: 5.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 1d8aeb5a-6e98-45a7-92d2-d8de7384e432 | 24 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 24 | 100 | 8.3 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 24 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 24 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 24 | 100 | 4.2 | aparentemente obrigatorio | exemplos sanitizados |

## DataSelector

- Evidência direta: Object/@type = ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af em 2 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a2bc65a1-999f-4e9b-b837-72285cc9bb16 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2 | 100 | 50 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DeploymentUnit

- Evidência direta: Object/@type = bf08dfb1-361c-4e7e-ad54-391e56e60b49 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 122ea32d-7ffa-4c47-9cbf-0829c2f060fe | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DesignSystem

- Evidência direta: Object/@type = 78b3fa0e-174c-4b2b-8716-718167a428b5 em 2 objetos.
- Evidência direta: média de Part por objeto: 4.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 36982745-cb77-47a3-bc04-9d0d764ff532 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2 | 100 | 50 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c6b14574-4f5f-4e35-aaa7-e322e88a9a10 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Document

- Evidência direta: Object/@type = faeb588c-dcce-4dad-9af3-cdd11b961a32 em 3 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 3 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Domain

- Evidência direta: Object/@type = 00972a17-9975-449e-aab1-d26165d51393 em 592 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 592 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 592 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## ExternalObject

- Evidência direta: Object/@type = c163e562-42c6-4158-ad83-5b21a14cf30e em 18 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 00000000-0000-0000-0002-000000000005 | 18 | 100 | 5.6 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 18 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 18 | 100 | 77.8 | aparentemente obrigatorio | exemplos sanitizados |

## File

- Evidência direta: Object/@type = 1132ac08-290f-4fd1-bd18-64777b7329d1 em 81 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 9b6155f9-f286-4ed5-bd15-67672e8ea320 | 81 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 81 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## Folder

- Evidência direta: Object/@type = 00000000-0000-0000-0000-000000000006 em 7 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## Image

- Evidência direta: Object/@type = 9fb193d9-64a4-4d30-b129-ff7c76830f7e em 250 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 36f350de-f768-425f-ac20-773749f331bf | 250 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 250 | 100 | 79.2 | aparentemente obrigatorio | exemplos sanitizados |

## Table

- Evidência direta: Object/@type = 857ca50e-7905-0000-0007-c5d9ff2975ec em 228 objetos top-level de `Table`.
- Evidência direta: média de Part por objeto: 2.
- Evidência direta: nesses objetos, `Index` aparece embutido no bloco estrutural da `Table`, e nao como objeto top-level separado.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 00000000-0000-0000-0002-000000000004 | 228 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| a5c0e770-560d-0001-0001-7fe71c260de3 | 228 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Language

- Evidência direta: Object/@type = 88313f43-5eb2-0000-0028-e8d9f5bf9588 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c23f3bb5-1e43-4c6b-b219-4717979df76a | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## PackagedModule

- Evidência direta: Object/@type = c88fffcd-b6f8-0000-8fec-00b5497e2117 em 16 objetos.
- Evidência direta: média de Part por objeto: 2.38.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a5e6a251-2df0-44d8-adab-1da237574326 | 6 | 37.5 | 100 | aparentemente vazio/estrutural | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 16 | 100 | 37.5 | aparentemente obrigatorio | exemplos sanitizados |
| ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc | 16 | 100 | 37.5 | aparentemente obrigatorio | exemplos sanitizados |

## Panel

- Evidência direta: Object/@type = d82625fd-5892-40b0-99c9-5c8559c197fc em 7 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| b4378a97-f9b2-4e05-b2f8-c610de258402 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## PatternSettings

- Evidência direta: Object/@type = 83476c1e-fa72-4229-9930-f51b954fca2d em 2 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3c89746e-54b1-441a-8f3f-97cc81be06bd | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Procedure

- Evidência direta: Object/@type = 84a12160-f59b-4ad7-a683-ea4481ac23e9 em 2281 objetos.
- Evidência direta: média de Part por objeto: 7.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 528d1c06-a9c2-420d-bd35-21dca83f12ff | 2281 | 100 | 0.4 | aparentemente obrigatorio | exemplos sanitizados |
| 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9 | 2281 | 100 | 52.5 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 2281 | 100 | 0.1 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 2281 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2281 | 100 | 93 | aparentemente obrigatorio | exemplos sanitizados |
| c414ed00-8cc4-4f44-8820-4baf93547173 | 2281 | 100 | 95.7 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 2281 | 100 | 0.1 | aparentemente obrigatorio | exemplos sanitizados |

## SDT

- Evidência direta: Object/@type = 447527b5-9210-4523-898b-5dccb17be60a em 594 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a | 594 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 594 | 100 | 98.3 | aparentemente obrigatorio | exemplos sanitizados |

## Stencil

- Evidência direta: Object/@type = 624a8b31-36f0-4292-adba-2d270d1e3537 em 11 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3dd92fe7-b095-44d3-9fa0-8488fa3f0c68 | 11 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 11 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## SubTypeGroup

- Evidência direta: Object/@type = 87313f43-5eb2-41d7-9b8c-e8d9f5bf9588 em 709 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 74203da2-41b1-402c-0001-d8d564a2c2fa | 709 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Theme

- Evidência direta: Object/@type = c804fdbd-7c0b-440d-8527-4316c92649a6 em 7 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 43b86e51-163f-44af-ac5a-e101541b1a71 | 7 | 100 | 14.3 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 71.4 | aparentemente obrigatorio | exemplos sanitizados |
| c31007a6-01d3-4788-95b3-425921d47758 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Transaction

- Evidência direta: Object/@type = 1db606f2-af09-4cf9-a3b5-b481519d28f6 em 183 objetos.
- Evidência direta: média de Part por objeto: 8.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 264be5fb-1b28-4b25-a598-6ca900dd059f | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 183 | 100 | 56.8 | aparentemente obrigatorio | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| d24a58ad-57ba-41b7-9e6e-eaca3543c778 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## UserControl

- Evidência direta: Object/@type = 562f4793-aabe-449f-8821-fc77e550698e em 7 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3dd92fe7-b095-44d3-9fa0-8488fa3f0c67 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 8e9e4a7c-a4d3-4c36-8e8e-fb6702402f63 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 85.7 | aparentemente obrigatorio | exemplos sanitizados |

## WebPanel

- Evidência direta: Object/@type = c9584656-94b6-4ccd-890f-332d11fc2c25 em 1196 objetos.
- Evidência direta: média de Part por objeto: 7.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9 | 1196 | 100 | 13.1 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 1196 | 100 | 0.8 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 1196 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1196 | 100 | 95.7 | aparentemente obrigatorio | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 1196 | 100 | 0.2 | aparentemente obrigatorio | exemplos sanitizados |
| d24a58ad-57ba-41b7-9e6e-eaca3543c778 | 1196 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 1196 | 100 | 0.4 | aparentemente obrigatorio | exemplos sanitizados |

## WorkWithForWeb

- Evidência direta: Object/@type = 78cecefe-be7d-4980-86ce-8d6e91fba04b em 183 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a51ced48-7bee-0001-ab12-04e9e32123d1 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 183 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |





## Origem incorporada - 11-campos-estaveis-vs-variaveis.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 01-base-empirica-geral.md

## Usado por
02-regras-operacionais-e-runtime.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Comparar a estabilidade dos atributos do nó `Object` entre tipos extraídos.
Dar base empírica para cautela em clonagem e preservação de contexto.

- Evidência direta: presença por atributo calculada por tipo extraído.
- Inferência forte: leituras como forte indicio de criticidade estrutural continuam heurísticas e não prova de importação.

## API

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em API\\EXEMPLO-SANITIZADO.xml.

## ColorPalette

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em ColorPalette\\EXEMPLO-SANITIZADO.xml.

## Dashboard

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Dashboard\\EXEMPLO-SANITIZADO.xml.

## DataProvider

- Evidência direta: 24 objetos analisados.
- Evidência direta: objetos com parent: 24; com moduleGuid: 24.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 24 | 100 | quase sempre | papel ainda nao fechado |
| description | 24 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 24 | 100 | quase sempre | papel ainda nao fechado |
| guid | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 24 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 24 | 100 | quase sempre | ligado a parent/module |
| name | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 24 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 24 | 100 | quase sempre | ligado a parent/module |
| parentType | 24 | 100 | quase sempre | ligado a parent/module |
| type | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 24 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 24 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.

## DataSelector

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 2; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 2 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| parentType | 2 | 100 | quase sempre | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DataSelector\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataSelector\\EXEMPLO-SANITIZADO.xml.

## DeploymentUnit

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DeploymentUnit\\EXEMPLO-SANITIZADO.xml.

## DesignSystem

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 50 | as vezes | ligado a parent/module |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 50 | as vezes | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DesignSystem\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DesignSystem\\EXEMPLO-SANITIZADO.xml.

## Document

- Evidência direta: 3 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 3.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 3 | 100 | quase sempre | papel ainda nao fechado |
| description | 3 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 3 | 100 | quase sempre | papel ainda nao fechado |
| guid | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 3 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 3 | 100 | quase sempre | ligado a parent/module |
| name | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 3 | 100 | quase sempre | ligado a parent/module |
| type | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 3 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 3 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.

## Domain

- Evidência direta: 592 objetos analisados.
- Evidência direta: objetos com parent: 3; com moduleGuid: 592.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 592 | 100 | quase sempre | papel ainda nao fechado |
| description | 592 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 592 | 100 | quase sempre | papel ainda nao fechado |
| guid | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 592 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 592 | 100 | quase sempre | ligado a parent/module |
| name | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 3 | 0.5 | raro | ligado a parent/module |
| parentGuid | 592 | 100 | quase sempre | ligado a parent/module |
| parentType | 3 | 0.5 | raro | ligado a parent/module |
| type | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 592 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 592 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.

## ExternalObject

- Evidência direta: 18 objetos analisados.
- Evidência direta: objetos com parent: 18; com moduleGuid: 18.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 18 | 100 | quase sempre | papel ainda nao fechado |
| description | 18 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 18 | 100 | quase sempre | papel ainda nao fechado |
| guid | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 18 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 18 | 100 | quase sempre | ligado a parent/module |
| name | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 18 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 18 | 100 | quase sempre | ligado a parent/module |
| parentType | 18 | 100 | quase sempre | ligado a parent/module |
| type | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 18 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 18 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.

## File

- Evidência direta: 81 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 81.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 81 | 100 | quase sempre | papel ainda nao fechado |
| description | 81 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 81 | 100 | quase sempre | papel ainda nao fechado |
| guid | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 81 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 81 | 100 | quase sempre | ligado a parent/module |
| name | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 81 | 100 | quase sempre | ligado a parent/module |
| type | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 81 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 81 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.

## Folder

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: Main Programs em Folder\Main Programs.xml.
- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.

## Image

- Evidência direta: 250 objetos analisados.
- Evidência direta: objetos com parent: 16; com moduleGuid: 250.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 250 | 100 | quase sempre | papel ainda nao fechado |
| description | 250 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 250 | 100 | quase sempre | papel ainda nao fechado |
| guid | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 250 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 250 | 100 | quase sempre | ligado a parent/module |
| name | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 16 | 6.4 | raro | ligado a parent/module |
| parentGuid | 250 | 100 | quase sempre | ligado a parent/module |
| parentType | 16 | 6.4 | raro | ligado a parent/module |
| type | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 250 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 250 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.

## Table

- Evidência direta: 228 objetos top-level de `Table` analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 228.
- Evidência direta: os indices reais observados nesta trilha aparecem embutidos dentro desses objetos de `Table`.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 228 | 100 | quase sempre | papel ainda nao fechado |
| description | 228 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 228 | 100 | quase sempre | papel ainda nao fechado |
| guid | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 228 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 228 | 100 | quase sempre | ligado a parent/module |
| name | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 228 | 100 | quase sempre | ligado a parent/module |
| type | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 228 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 228 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Table\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Table\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Table\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Table\\EXEMPLO-SANITIZADO.xml.

## Language

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Language\\EXEMPLO-SANITIZADO.xml.

## PackagedModule

- Evidência direta: 16 objetos analisados.
- Evidência direta: objetos com parent: 2; com moduleGuid: 16.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| author | 10 | 62.5 | as vezes | papel ainda nao fechado |
| checksum | 16 | 100 | quase sempre | papel ainda nao fechado |
| description | 16 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 16 | 100 | quase sempre | papel ainda nao fechado |
| guid | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 16 | 100 | quase sempre | papel ainda nao fechado |
| licenseUrl | 3 | 18.8 | raro | papel ainda nao fechado |
| moduleDescription | 10 | 62.5 | as vezes | papel ainda nao fechado |
| moduleGuid | 16 | 100 | quase sempre | ligado a parent/module |
| moduleVersion | 10 | 62.5 | as vezes | papel ainda nao fechado |
| name | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| Owner | 10 | 62.5 | as vezes | papel ainda nao fechado |
| PackagedModuleName | 10 | 62.5 | as vezes | papel ainda nao fechado |
| parent | 2 | 12.5 | raro | ligado a parent/module |
| parentGuid | 16 | 100 | quase sempre | ligado a parent/module |
| parentType | 2 | 12.5 | raro | ligado a parent/module |
| projectUrl | 4 | 25 | as vezes | papel ainda nao fechado |
| serverUrl | 3 | 18.8 | raro | papel ainda nao fechado |
| tags | 3 | 18.8 | raro | papel ainda nao fechado |
| type | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 16 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 16 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.

## Panel

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 7; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 7 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| parentType | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.

## PatternSettings

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em PatternSettings\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PatternSettings\\EXEMPLO-SANITIZADO.xml.

## Procedure

- Evidência direta: 2281 objetos analisados.
- Evidência direta: objetos com parent: 2281; com moduleGuid: 2281.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2281 | 100 | quase sempre | papel ainda nao fechado |
| description | 2281 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2281 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2281 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2281 | 100 | quase sempre | ligado a parent/module |
| name | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 2281 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 2281 | 100 | quase sempre | ligado a parent/module |
| parentType | 2281 | 100 | quase sempre | ligado a parent/module |
| type | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2281 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2281 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.

## SDT

- Evidência direta: 594 objetos analisados.
- Evidência direta: objetos com parent: 591; com moduleGuid: 594.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 594 | 100 | quase sempre | papel ainda nao fechado |
| description | 594 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 594 | 100 | quase sempre | papel ainda nao fechado |
| guid | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 594 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 594 | 100 | quase sempre | ligado a parent/module |
| name | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 591 | 99.5 | quase sempre | ligado a parent/module |
| parentGuid | 594 | 100 | quase sempre | ligado a parent/module |
| parentType | 591 | 99.5 | quase sempre | ligado a parent/module |
| type | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 594 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 594 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.

## Stencil

- Evidência direta: 11 objetos analisados.
- Evidência direta: objetos com parent: 11; com moduleGuid: 11.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 11 | 100 | quase sempre | papel ainda nao fechado |
| description | 11 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 11 | 100 | quase sempre | papel ainda nao fechado |
| guid | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 11 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 11 | 100 | quase sempre | ligado a parent/module |
| name | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 11 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 11 | 100 | quase sempre | ligado a parent/module |
| parentType | 11 | 100 | quase sempre | ligado a parent/module |
| type | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 11 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 11 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.

## SubTypeGroup

- Evidência direta: 709 objetos analisados.
- Evidência direta: objetos com parent: 709; com moduleGuid: 709.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 709 | 100 | quase sempre | papel ainda nao fechado |
| description | 709 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 709 | 100 | quase sempre | papel ainda nao fechado |
| guid | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 709 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 709 | 100 | quase sempre | ligado a parent/module |
| name | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 709 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 709 | 100 | quase sempre | ligado a parent/module |
| parentType | 709 | 100 | quase sempre | ligado a parent/module |
| type | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 709 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 709 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.

## Theme

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.

## Transaction

- Evidência direta: 183 objetos analisados.
- Evidência direta: objetos com parent: 183; com moduleGuid: 183.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 183 | 100 | quase sempre | papel ainda nao fechado |
| description | 183 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 183 | 100 | quase sempre | papel ainda nao fechado |
| guid | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 183 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 183 | 100 | quase sempre | ligado a parent/module |
| name | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 183 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 183 | 100 | quase sempre | ligado a parent/module |
| parentType | 183 | 100 | quase sempre | ligado a parent/module |
| type | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 183 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 183 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.

## UserControl

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 7; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 7 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| parentType | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.

## WebPanel

- Evidência direta: 1196 objetos analisados.
- Evidência direta: objetos com parent: 1195; com moduleGuid: 1196.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1196 | 100 | quase sempre | papel ainda nao fechado |
| description | 1196 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1196 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1196 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1196 | 100 | quase sempre | ligado a parent/module |
| name | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1195 | 99.9 | quase sempre | ligado a parent/module |
| parentGuid | 1196 | 100 | quase sempre | ligado a parent/module |
| parentType | 1195 | 99.9 | quase sempre | ligado a parent/module |
| type | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1196 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1196 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.

## WorkWithForWeb

- Evidência direta: 183 objetos analisados.
- Evidência direta: objetos com parent: 183; com moduleGuid: 183.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 183 | 100 | quase sempre | papel ainda nao fechado |
| description | 183 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 183 | 100 | quase sempre | papel ainda nao fechado |
| guid | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 183 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 183 | 100 | quase sempre | ligado a parent/module |
| name | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 183 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 183 | 100 | quase sempre | ligado a parent/module |
| parentType | 183 | 100 | quase sempre | ligado a parent/module |
| type | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 183 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 183 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.





## Origem incorporada - 12-diffs-estruturais-por-tipo.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Comparar amostras simples e complexas por tipo prioritário.
Destacar estabilidade estrutural relativa e pontos de maior risco para clonagem.

- Evidência direta: amostras simples/complexas foram escolhidas por menor/maior combinação de PartCount e tamanho de arquivo.
- Inferência forte: simples e complexo aqui significam complexidade estrutural no XML extraído, não complexidade funcional garantida.

## API

- Evidência direta: caso real observado: alias sanitizado `APIExemploIntegracaoA.xml` com 5 `Part` e tamanho de 25844 bytes.
- Evidência direta: o alias sanitizado `APIExemploMinA.xml` deve ser lido apenas como recorte editorial simplificado do mesmo perfil estrutural, e nao como segunda `API` real observada na KB.
- Evidência direta: Part type nas amostras simples: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## DataProvider

- Evidência direta: amostra simples: alias sanitizado `DPExemploLista.xml` com 5 `Part` e 3 `Part` nao vazias.
- Evidência direta: amostra simples: alias sanitizado `DPExemploParm.xml` com 5 `Part` e 4 `Part` nao vazias.
- Evidência direta: amostra complexa: alias sanitizado `DPExemploTribSelecaoA.xml` com 5 `Part` e tamanho de 12558 bytes.
- Evidência direta: amostra complexa: alias sanitizado `DPExemploSidebarA.xml` com 5 `Part` e tamanho de 10713 bytes.
- Evidência direta: Part type nas amostras simples: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## DesignSystem

- Evidência direta: amostra simples: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e 3 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e 4 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e tamanho de 31240 bytes.
- Evidência direta: amostra complexa: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e tamanho de 2255 bytes.
- Evidência direta: Part type nas amostras simples: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type nas amostras complexas: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## PackagedModule

- Evidência direta: amostra simples: alias sanitizado `PackagedModuleExemploExtensoesA.xml` com 2 `Part` e 2 `Part` nao vazias.
- Evidência direta: amostra simples: alias sanitizado `PackagedModuleExemploSegurancaA.xml` com 2 `Part` e 2 `Part` nao vazias.
- Evidência direta: amostra complexa: alias sanitizado `PackagedModuleExemploUIA.xml` com 3 `Part` e tamanho de 998 bytes.
- Evidência direta: amostra complexa: alias sanitizado `PackagedModuleExemploServicesA.xml` com 3 `Part` e tamanho de 990 bytes.
- Evidência direta: Part type nas amostras simples: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type nas amostras complexas: a5e6a251-2df0-44d8-adab-1da237574326; babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type apenas nas amostras complexas: a5e6a251-2df0-44d8-adab-1da237574326.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Panel

- Evidência direta: amostra simples: alias sanitizado `PanelExemploNaoAutorizadoA.xml` com 2 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra simples: alias sanitizado `PanelExemploLoginA.xml` com 2 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra complexa: alias sanitizado `PanelExemploTrocaSenhaA.xml` com 2 `Part` e tamanho de 16930 bytes.
- Evidência direta: amostra complexa: alias sanitizado `PanelExemploAtualizacaoUsuarioA.xml` com 2 `Part` e tamanho de 15516 bytes.
- Evidência direta: Part type nas amostras simples: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Procedure

- Evidência direta: amostra simples: alias sanitizado `PRCExemploMinimo.xml` com 7 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra simples: alias sanitizado `PRCExemploParm.xml` com 7 `Part` e 3 `Part` nao vazias.
- Evidência direta: amostra complexa: alias sanitizado `PRCExemploRelatorioA.xml` com 7 `Part` e tamanho de 1114792 bytes.
- Evidência direta: amostra complexa: alias sanitizado `PRCExemploRelatorioB.xml` com 7 `Part` e tamanho de 1060772 bytes.
- Evidência direta: Part type nas amostras simples: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## SDT

- Evidência direta: amostra simples: alias sanitizado `SDTExemploEstadoTelaA.xml` com 2 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra simples: alias sanitizado `SDTExemploEstoqueA.xml` com 2 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra complexa: alias sanitizado `SDTExemploDocumentoA.xml` com 2 `Part` e tamanho de 1101872 bytes.
- Evidência direta: amostra complexa: alias sanitizado `SDTExemploDocumentoB.xml` com 2 `Part` e tamanho de 1054406 bytes.
- Evidência direta: Part type nas amostras simples: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Theme

- Evidência direta: amostra simples: alias sanitizado `ThemeExemploMobileB.xml` com 3 `Part` e 2 `Part` nao vazias.
- Evidência direta: amostra simples: alias sanitizado `ThemeExemploMobileC.xml` com 3 `Part` e 2 `Part` nao vazias.
- Evidência direta: amostra complexa: alias sanitizado `ThemeExemploPrincipalA.xml` com 3 `Part` e tamanho de 323724 bytes.
- Evidência direta: amostra complexa: alias sanitizado `ThemeExemploSegurancaA.xml` com 3 `Part` e tamanho de 304258 bytes.
- Evidência direta: Part type nas amostras simples: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type nas amostras complexas: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Transaction

- Evidência direta: amostra simples: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e 7 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e 7 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e tamanho de 521796 bytes.
- Evidência direta: amostra complexa: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e tamanho de 294785 bytes.
- Evidência direta: Part type nas amostras simples: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## WebPanel

- Evidência direta: amostra simples: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e 2 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e 2 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e tamanho de 530462 bytes.
- Evidência direta: amostra complexa: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e tamanho de 403121 bytes.
- Evidência direta: Part type nas amostras simples: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## WorkWithForWeb

- Evidência direta: amostra simples: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e 1 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e 1 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e tamanho de 188770 bytes.
- Evidência direta: amostra complexa: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e tamanho de 151944 bytes.
- Evidência direta: Part type nas amostras simples: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Moldes sanitizados completos de Procedure e DataProvider

- Evidencia direta: esta base agora contem 2 moldes XML sanitizados completos de `Procedure` e 2 de `DataProvider`.
- Inferencia forte: esse conjunto complementa os moldes ja existentes de `WebPanel` e `Transaction`, reduzindo a necessidade de consulta adicional ao acervo bruto para prototipos controlados desses dois tipos.
- Hipotese: para `Procedure` muito densa ou `DataProvider` com saida muito especializada, ainda pode ser necessario buscar molde bruto comparavel adicional.

### Molde sanitizado de Procedure 1 - `PRCExemploMinimo`

- Perfil: `Procedure` minima, com inventario recorrente de `Part` e quase nenhum conteudo interno.
- Uso operacional: boa casca para testes de serializacao, stub server-side e verificacao do envelope estrutural do tipo.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="624fa1ae-7a20-4d68-bc8a-b54254fa3ce7" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-03-27T22:31:45.0000000Z" checksum="ac868db7f602aeb0f9d9f1c51a919527" fullyQualifiedName="PRCExemploMinimo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="d6ecd738-8c9a-4361-9a4e-f638fbd98067" name="PRCExemploMinimo" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Minima" parent="PastaExemploProcedure" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Properties />
  </Part>
  <Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
    <Properties />
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Properties />
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Properties />
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Properties />
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PRCExemploMinimo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

### Molde sanitizado de Procedure 2 - `PRCExemploParm`

- Perfil: `Procedure` curta com `parm(out:...)` e variavel baseada em dominio.
- Uso operacional: boa referencia para clonagem controlada quando o alvo tiver parametro simples e variavel associada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="988004e2-6090-42c3-9603-c073172b75a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2017-11-30T13:14:40.0000000Z" checksum="f03125659ba83a8972206dfeb9b0dfc8" fullyQualifiedName="PRCExemploParm" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="96caabbb-924a-4d2b-83f9-62e5e192608a" name="PRCExemploParm" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Parm" parent="PastaExemploProcedure" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Properties />
  </Part>
  <Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
    <Properties />
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[parm(out:&DomainExemploTipoOperacaoA);
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Properties />
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="DomainExemploTipoOperacaoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DomainExemploTipoOperacaoA</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:DomainExemploTipoOperacaoA</Value>
        </Property>
      </Properties>
    </Variable>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PRCExemploParm</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataProvider 1 - `DPExemploLista`

- Perfil: `DataProvider` simples com saida de colecao declarada no proprio `Source`.
- Uso operacional: boa referencia para saida pequena baseada em estrutura repetida.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fbf65a0f-f5fe-40b5-9328-ac966656d448" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2009-07-22T19:06:02.0000000Z" checksum="2c78d22a9661e372b2cefb9d31d6018c" fullyQualifiedName="DPExemploLista" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="9fed987b-56be-4e31-9e9f-09f7c9b959c3" name="DPExemploLista" type="2a9e9aba-d2de-4801-ae7f-5e3819222daf" description="DPExemploLista" parent="PastaExemploDP" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="1d8aeb5a-6e98-45a7-92d2-d8de7384e432">
    <Source><![CDATA[SdtExemploLista
{
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoA'
		RCountry = 'PaisA'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoB'
		RCountry = 'PaisB'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoC'
		RCountry = 'PaisC'
	}
	SdtExemploListaItem
	{
		RValnum =4
		RValtext = 'RegiaoD'
		RCountry = 'PaisD'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoE'
		RCountry = 'PaisE'
	}
	SdtExemploListaItem
	{
		RValnum =2
		RValtext = 'RegiaoF'
		RCountry = 'PaisF'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoG'
		RCountry = 'PaisG'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoH'
		RCountry = 'PaisH'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoI'
		RCountry = 'PaisI'
	}
}
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Properties />
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DPExemploLista</Value>
    </Property>
    <Property>
      <Name>OutputSDT</Name>
      <Value>447527b5-9210-4523-898b-5dccb17be60a-SdtExemploLista</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataProvider 2 - `DPExemploParm`

- Perfil: `DataProvider` com `parm(in:...)`, `OutputCollection=True` e composicao textual mais rica no `Source`.
- Uso operacional: boa referencia para `DataProvider` orientado por parametros e saida em colecao.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="79a956f5-e947-44fb-9165-5914625207c6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-18T18:35:14.0000000Z" checksum="d7d87280290ffc92084066e33abd7c51" fullyQualifiedName="DPExemploParm" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="1ee0e754-a66a-47bf-a7aa-3af9a0da28c0" name="DPExemploParm" type="2a9e9aba-d2de-4801-ae7f-5e3819222daf" description="DataProvider Exemplo Parm" parent="PastaExemploDP" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="1d8aeb5a-6e98-45a7-92d2-d8de7384e432">
    <Source><![CDATA[SdtExemploChaveValor order ContextoAId, ContextoBId, SequenciaExemplo, RegistroId
{
	Chave = RegistroId.ToString()
	
	Valor = "CtxA:" + RegistroEmpresaId.ToString().Trim() + 
	" Chave: " + RegistroId.ToFormattedString() +
	"| Seq:" + SequenciaExemplo.ToString() + 
	" | A:" + procLeftExemplo(PessoaAId.ToString()," ",10) +
	" | B:" + procRightExemplo(PessoaBId.ToString()," ",10) +
	"-" + PessoaBNome.Trim() + " (" + TipoRegistro.EnumerationDescription() + ")"
	
}
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[parm(in:ContextoAId, in:ContextoBId);
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DPExemploParm</Value>
    </Property>
    <Property>
      <Name>OutputSDT</Name>
      <Value>447527b5-9210-4523-898b-5dccb17be60a-SdtExemploChaveValor</Value>
    </Property>
    <Property>
      <Name>OutputCollection</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Panel e API

- Evidência direta: o acervo usado nesta base contem 7 objetos Panel e 1 objeto API.
- Inferência forte: pela baixa cardinalidade, faz mais sentido documentar moldes completos representativos do que tentar abrir muitas familias finas.
- Inferência forte: os anexos abaixo servem como referencia estrutural documentada para prototipos conservadores, sempre preservando Object/@type, inventario de Part e hierarquia interna.

### Molde sanitizado de Panel 1 - `PanelExemploNaoAutorizado`

- Perfil: Panel mobile enxuto, com PatternPart, layout simples e poucos eventos.
- Uso operacional: boa referencia para Panel de mensagem/entrada curta com estrutura gerada por pattern.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="d8c5213a-038e-4c3d-8cad-c4f38c6c10ff" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-08-03T13:19:24.0000000Z" checksum="05f72ad114b0959c3b1154503e4e7ada" fullyQualifiedName="PanelExemploNaoAutorizado" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="0492a00a-5a72-44bb-8fe5-6468b143a1db" name="PanelExemploNaoAutorizado" type="d82625fd-5892-40b0-99c9-5c8559c197fc" description="Nao Autorizado" parent="PastaExemploPanel" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="b4378a97-f9b2-4e05-b2f8-c610de258402">
    <PatternPart type="a51ced48-7bee-0001-ab12-04e9e32123d1">
      <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="17.11.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance>
  <notifications />
  <level id="9c3fa622-c8e3-419b-be3f-659de559bbd2" name="Level">
    <detail variables="&lt;Variables&gt;&lt;Variable Id=&quot;9&quot; Name=&quot;Password&quot; Description=&quot;Password&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Description&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthPassword, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;10&quot; Name=&quot;UserName&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;UserName&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthUserIdentification, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;11&quot; Name=&quot;AuthRepository&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;AuthRepository&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;exo:AuthRepository, SANITIZEDSecurity&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;StandardVariable Id=&quot;4&quot; Name=&quot;Pgmdesc&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmdesc&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;3&quot; Name=&quot;Pgmname&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmname&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;2&quot; Name=&quot;Time&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Time&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;1&quot; Name=&quot;Today&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Today&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Date&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;/Variables&gt;" events="Event Start&#xA;&#x9;&amp;AuthRepository = AuthRepository.Get()&#xA;&#x9;Do Case&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.Name&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.Name)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.EMail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.EMail)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.NameEmail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.NameEmail)&#xA;&#x9;EndCase&#xA;Endevent&#xA;&#xA;&#xA;Event 'BtnEntrar'&#xA;&#x9;Composite&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.ShowWithTitle(&quot;Conectando...&quot;)&#xA;&#x9;&#x9;SANITIZED.SD.Actions.Entrar(&amp;UserName, &amp;Password)&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.Hide()&#xA;&#x9;&#x9;Return&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;Event 'Back'&#xA;&#x9;Return&#xA;Endevent&#xA;">
      <layout id="78852907-2ff5-5ed0-aaf2-079ff7de3e65" Type="View">
        <table id="b32d02f2-0dd3-4ff1-ab64-a3e660c6d75e" controlName="MainTable" columnsStyle="10dip;100%;10dip" responsiveSizes="[]">
          <row id="9c151a94-80d2-46f8-96c6-9116c7daabd3" rowHeight="50dip">
            <cell id="4ca3501c-1d5f-44c0-9a2f-d35dc46d120b" />
            <cell id="a6049a5b-7a80-4dbf-be0e-823046c2135b" hAlign="Center" vAlign="Middle">
              <textblock controlName="TBMsg" caption="Nao autorizado: acesso negado." enabled="False" />
            </cell>
            <cell id="4eb8110b-d034-4ff5-b1e6-52437c4e7d96" />
          </row>
          <row id="d752f865-4ff5-421f-86be-611fe83c74cb" rowHeight="15dip" />
          <row id="fe634880-d9ac-4961-925d-b5af54956e19" rowHeight="pd">
            <cell id="8852d807-ce19-43b1-b14b-9d87331132d6" />
            <cell id="6b999592-fc89-46e3-8f85-e51d86bfb41f">
              <data attribute="&amp;UserName" labelCaption="Name" inviteMessage="" />
            </cell>
          </row>
          <row id="761dbdcc-a547-4dae-9d08-a1cfd3f46eaf" rowHeight="pd">
            <cell id="43d045c0-a1e1-4ddb-ae47-10dbaf4bb4b3" />
            <cell id="32839ce6-9945-47b0-a77f-06af61e9d68b">
              <data attribute="&amp;Password" inviteMessage="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;idEnableShowPasswordHint&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
            </cell>
          </row>
          <row id="f65f348a-0497-412e-8a47-c406ced202cc" rowHeight="15dip" />
          <row id="cd2a293a-0b52-46a4-933a-74e67e355b2e" rowHeight="pd">
            <cell id="9d22a783-969c-4a9a-8254-a92485853853" />
            <cell id="af4ba31d-e944-4544-a51c-ac5f43a4c47d" hAlign="Center" vAlign="Middle">
              <action controlName="BtnEntrar" onClickEvent="'BtnEntrar'" caption="ENTRAR" class="button-primary" />
            </cell>
          </row>
        </table>
      </layout>
    </detail>
  </level>
</instance>]]></Data>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </PatternPart>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PanelExemploNaoAutorizado</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Nao Autorizado</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>AndroidBaseStyle</Name>
      <Value>AndroidBaseStyleDark</Value>
    </Property>
    <Property>
      <Name>CacheEnabled</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityNone</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>PanelExemploNaoAutorizado</Value>
    </Property>
  </Properties>
  <Categories>Panel_Samples-sd</Categories>
</Object>

` 

### Molde sanitizado de Panel 2 - `PanelExemploAcesso`

- Perfil: Panel mobile com PatternPart, acoes de autenticacao, ctionBar e fluxo de entrada mais rico.
- Uso operacional: boa referencia para Panel com eventos, acoes e dependencias de pattern mais evidentes.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="d8c5213a-038e-4c3d-8cad-c4f38c6c10ff" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-08-04T13:50:26.0000000Z" checksum="7bff8a381959f9267b8a4be2f92c03d5" fullyQualifiedName="PanelExemploAcesso" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="865ab616-d866-4c90-9110-d352975022b5" name="PanelExemploAcesso" type="d82625fd-5892-40b0-99c9-5c8559c197fc" description="Acesso" parent="PastaExemploPanel" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="b4378a97-f9b2-4e05-b2f8-c610de258402">
    <PatternPart type="a51ced48-7bee-0001-ab12-04e9e32123d1">
      <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="17.11.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance>
  <notifications />
  <level id="45969122-dc02-4641-8055-f127e24fef52" name="Level">
    <detail variables="&lt;Variables&gt;&lt;Variable Id=&quot;13&quot; Name=&quot;AuthRepository&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;AuthRepository&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;exo:AuthRepository, SANITIZEDSecurity&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;12&quot; Name=&quot;Password&quot; Description=&quot;Password&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Description&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthPassword, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;10&quot; Name=&quot;UserName&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;UserName&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthUserIdentification, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;StandardVariable Id=&quot;4&quot; Name=&quot;Pgmdesc&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmdesc&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;3&quot; Name=&quot;Pgmname&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmname&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;2&quot; Name=&quot;Time&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Time&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;1&quot; Name=&quot;Today&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Today&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Date&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;/Variables&gt;" events="Event Start&#xA;&#x9;&amp;AuthRepository = AuthRepository.Get()&#xA;&#x9;Do Case&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.Name&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.Name)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.EMail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.EMail)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.NameEmail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.NameEmail)&#xA;&#x9;EndCase&#xA;Endevent&#xA;&#xA;Event 'BtnAcesso'&#xA;&#x9;Composite&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.ShowWithTitle(&quot;Conectando...&quot;)&#xA;&#x9;&#x9;SANITIZED.SD.Actions.Autenticar(&amp;UserName, &amp;Password)&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.Hide()&#xA;&#x9;&#x9;Return&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;//Event 'Facebook'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//      &amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;facebook&quot;  //Use only when more than one Facebook authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Facebook, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//      Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'Google'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//      &amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;google&quot;  //Use only when more than one Google authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Google, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'Twitter'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Twitter, &amp;UserName, &amp;Password)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'AuthRemote'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters.Repository&#x9;&#x9;&#x9;&#x9;= &amp;RepositoryGUID&#x9;//Use only when more than one Repository is defined in the Identity Provider (multi-tenant)&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;idp_name&quot;  &#x9;&#x9;//Use only when more than one AuthRemote authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.AuthRemote, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//Endevent&#xA;&#xA;&#xA;&#xA;Event 'Register'&#xA;&#x9;Composite&#xA;&#x9;&#x9;PanelExemploRegistrar()&#xA;&#x9;&#x9;Return&#xA;&#x9;&#x9;If 1=0&#xA;&#x9;&#x9;&#x9;Do 'Dummy'&#xA;&#x9;&#x9;Endif&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;Sub 'Dummy'&#xA;&#x9;//To include in build references&#xA;&#x9;PanelExemploAtualizar()&#xA;&#x9;PanelExemploAlterarSenha()&#xA;&#x9;PanelExemploNaoAutorizado()&#xA;Endsub&#xA;&#xA;&#xA;" rules="&#xD;&#xA;">
      <layout id="3448c091-227a-50bb-a80a-dfbc08086458" Type="View">
        <table id="ab58fa72-dc00-4426-b898-f29b04c920a8" controlName="MainTable" columnsStyle="10dip;100%;10dip" responsiveSizes="[]">
          <row id="f906596b-4aad-4521-8da4-80aafbabdfbb" rowHeight="50dip" />
          <row id="b020ea6f-2c5c-4a01-9474-913934e181b0" rowHeight="pd">
            <cell id="365aba11-c77f-4c3d-a0a6-eacb08e3dc44" />
            <cell id="2b8f0168-0df7-4de1-bbf8-ffb295d36429">
              <data attribute="&amp;UserName" labelCaption="Name" readonly="False" inviteMessage="" />
            </cell>
            <cell id="da5e96b9-3aff-4aab-b89e-39d7be52ad7a" />
          </row>
          <row id="b99ef45d-712d-4945-85c3-7c017cf00d05" rowHeight="pd">
            <cell id="7b01445f-554a-482d-9363-f71b40761bf4" />
            <cell id="2a9b93b9-c15b-426a-b3e2-3372642b075d">
              <data attribute="&amp;Password" labelCaption="Password" readonly="False" inviteMessage="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;idEnableShowPasswordHint&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
            </cell>
          </row>
          <row id="91340143-cf76-4a5a-9536-2328d1d7c7e4" rowHeight="15dip" />
          <row id="f36e98c0-93a9-4fc7-8b6f-99a81f196b01" rowHeight="pd">
            <cell id="c4da8518-eb92-45c4-8c5f-6169048318a7" />
            <cell id="de0e3236-6940-41b2-9b10-c01b64bb2dbf" hAlign="Center" vAlign="Middle">
              <action controlName="BtnAcesso" onClickEvent="'BtnAcesso'" caption="Acesso" class="button-primary" />
            </cell>
          </row>
        </table>
        <actionBar>
          <item priority="High">
            <action controlName="BtnRegister" onClickEvent="'Register'" />
          </item>
        </actionBar>
      </layout>
    </detail>
  </level>
</instance>]]></Data>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </PatternPart>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PanelExemploAcesso</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Acesso</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>idConnectivitySupport</Name>
      <Value>idOnline</Value>
    </Property>
    <Property>
      <Name>AndroidBaseStyle</Name>
      <Value>AndroidBaseStyleDark</Value>
    </Property>
    <Property>
      <Name>CacheEnabled</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityNone</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>PanelExemploAcesso</Value>
    </Property>
  </Properties>
  <Categories>Panel_Samples-sd</Categories>
</Object>

` 

### Molde sanitizado de API 1 - `APIExemploIntegracao`

- Perfil: API com bloco Service, multiplos RestMethod, eventos .Before/.After e conjunto denso de variaveis.
- Uso operacional: boa referencia para o unico caso real de API observado nesta KB, construido de forma manual/local e com servicos REST coordenados por eventos e logica auxiliar interna.
- Evidência direta: a validacao posterior no acervo real confirmou que `API` usa `ATTCUSTOMTYPE` concretos para `EXO` e `SDT`, como `exo:GAMSession, GeneXusSecurity` e `sdt:Messages, GeneXus.Common`.
- Inferência forte: este molde so deve ser materializado quando os `Procedure`, `EXO` e `SDT` referenciados existirem de fato na KB de destino.
- Inferência forte: trocar nomes e codigo sem revisar os `ATTCUSTOMTYPE` e as dependencias chamadas em `Source` tende a produzir falha semantica, nao falha de envelope.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="74e9b5f3-f6b7-4421-b895-d960d6b1078b" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-03-12T15:02:57.0000000Z" checksum="2ca44baa29aabb01a13db31a19ad40b3" fullyQualifiedName="APIExemploIntegracao" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="854bf450-73b9-4472-bbcc-24ddcb983022" name="APIExemploIntegracao" type="36e32e2d-023e-4188-95df-d13573bac2e0" description="API Exemplo Integracao" parent="PastaExemploAPI" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5">
    <Source><![CDATA[Service
{	
	[RestMethod(POST)]
	[Description("Obter a lista de itens conforme parametros.")]
	ObterItens(
		in:&ItemEmpresaId, 
		in:&ItemCodigo, 
		in:&UltimaAlteracaoInicio, 
		in:&ComDFouPedidoOuVmEmpresaId, 
		in:&ComDFouPedidoOuVmDesde, 
		in:&SemDadosFiscaisAdicionais, 
		in:&ItemMarcaId, 
		in:&GrupoDeItemId, 
		out:&ListaSDTExemploItemBasicoA, 
		out:&MensagensRetorno
	)
	=> PRCExemploListaItensA(
		"", 
		&ItemEmpresaId, 
		&ItemTipoExemploA, 
		&ItemCodigo, 
		&UltimaAlteracaoInicio, 
		&ComDFouPedidoOuVmEmpresaId, 
		&ComDFouPedidoOuVmDesde, 
		&SemDadosFiscaisAdicionais, 
		&SemDadosOpcionaisPorEmpresa, 
		&SemIdiomas, 
		&DomainExemploGrupoA, 
		&ItemMarcaId, 
		&ComMarca, 
		&DomainExemploCorteA, 
		&DomainExemploLocalA, 
		&GrupoDeItemId, 
		&ListaSDTExemploItemBasicoA, 
		&MensagensRetorno
	);

	[RestMethod(POST)]
	[Description("Obter a lista de regras conforme parametros.")]
	ObterRegras(
		in:&RegraExemploEmpresaId, 
		in:&RegraExemploId,
		in:&DocumentoExemploEmpresaId,
		in:&DomainExemploTipoOperacaoA,
		in:&UltimaAlteracaoInicio, 
		out:&SDTExemploRegraSelecaoA, 
		out:&MensagensRetorno
	)
	=> PRCExemploRegraSelecaoA(
		&RegraExemploEmpresaId, 
		&RegraExemploId,
		&DocumentoExemploEmpresaId,
		&DomainExemploTipoOperacaoA,
		&UltimaAlteracaoInicio, 
		&SDTExemploRegraSelecaoA, 
		&MensagensRetorno
	);
	
	[RestMethod(POST)]
	[Description("enviar um documento em Base64 para processamento.")]
	EnviarDocumento(
		in:&NomeArquivoExemploA, 
		in:&ConteudoBase64ExemploA,
		in:&DocumentoExemploEmpresaId,
		out:&OperacaoExemploSucessoA, 
		out:&MensagensRetorno
	)
	=> PRCExemploImportaDocumentoBase64A(
		&NomeArquivoExemploA, 
		&ConteudoBase64ExemploA,
		&DocumentoExemploEmpresaId,
		&OperacaoExemploSucessoA, 
		&MensagensRetorno
	);
	
}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event ObterItens.Before
	
	&ItemTipoExemploA = DomainExemploTipoA.Item
	
Endevent
Event ObterItens.After
	
	do 'CompletaMensagensRetorno'	
	
Endevent	

Event ObterRegras.Before
	
	&ContextoLoginId = procEmpresaContextoId(&DocumentoExemploEmpresaId)		
	if &ContextoLoginId.IsEmpty()
	
		&ContextoLoginId = &DocumentoExemploEmpresaId
			
	endif	
	
	do 'CompletaLogin'
	
Endevent
Event ObterRegras.After
	
	do 'CompletaMensagensRetorno'	
	
Endevent	


Event EnviarDocumento.Before

	&ContextoLoginId = procEmpresaContextoId(&DocumentoExemploEmpresaId)		
	if &ContextoLoginId.IsEmpty()
	
		&ContextoLoginId = &DocumentoExemploEmpresaId
			
	endif	
	
	do 'CompletaLogin'

Endevent
Event EnviarDocumento.After
	
	if &OperacaoExemploSucessoA
		
		&MensagensRetorno =
		procRemoveUmTipoDeMensagem(&MensagensRetorno, TiposMensagemExemplo.Warning, -1)
		
	endif

	&MensagensRetorno =
	procRemoveUmTipoDeMensagem(&MensagensRetorno, TiposMensagemExemplo.Info, 0)

	do 'CompletaMensagensRetorno'
	
Endevent	
	
	
//Sub 'CompletaMensagensRetorno'
Sub 'CompletaMensagensRetorno'
	
	PRCExemploAgregaMensagensA(&MensagensRetorno, &MensagensInicio)
	
Endsub	

	
//Sub 'CompletaLogin'
Sub 'CompletaLogin'

	&AbortarInicio = false
	
	&AuthSession = AuthSession.Get(&AuthErrors)
	
	&SessionValid = AuthSession.IsValid(&AuthSession, &AuthErrors)
	
	Do Case
		Case &AuthErrors.Count > 0
			
			procAgregaMensagensDeErrosAuth(&MensagensInicio, &AuthErrors)
			
			//procAgregaNovaMensagem(&MensagensInicio, "", TiposMensagemExemplo.Error,
			//"Erro: (Falha na autenticacao) " + &AuthErrors.ToJson())
			//"Erro: Falha na autenticacao. Com " + &AuthErrors.Count.ToString().Trim() + " erros.")
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
			
		Case not &SessionValid
			
			procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
			'Erro: sessao de autenticacao invalida.')
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
			
		Case &ContextoLoginId.IsEmpty()

			procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
			'Erro: contexto de login nao definido.')
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
		
		Otherwise

			&AuthUser    = &AuthSession.User
			&UserName  = &AuthUser.GetName()
			
			&loginUsuarioId = procUsuarioPorLogin(&UserName.ToString().Trim())
			
			//if &loginUsuarioId.IsEmpty()
			if &loginUsuarioId.IsEmpty()
				
				procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
				'Erro: usuario nao identificado para o login ' + &UserName + ".")
	
				&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
				&AbortarInicio = true
				
			else
				
				procCriaSessaoUsuario(&loginUsuarioId,"")
				
				//if procEmpresaLiberadaProUsuarioExemplo(&ContextoLoginId)
				if procEmpresaLiberadaProUsuarioExemplo(&ContextoLoginId)
					
					procCriaSessaoEmpresa(&ContextoLoginId, "")
					
				else
					
					procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
					'Erro: Usuário Id ' + &loginUsuarioId.ToString().Trim() + 
					' sem permissao para a empresa id ' + &ContextoLoginId.ToString().Trim() +
					".")
		
					&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
					&AbortarInicio = true
					
				endif
				
			endif
		
	Endcase

	//if &AbortarInicio
	if &AbortarInicio
		
		do 'CompletaMensagensRetorno'
		Return
		
	endif

Endsub
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="AbortarInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AbortarInicio</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComDFouPedidoOuVmDesde">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComDFouPedidoOuVmDesde</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Data</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComDFouPedidoOuVmEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComDFouPedidoOuVmEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:EmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComMarca">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComMarca</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:SimOuNao</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ConteudoBase64ExemploA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ConteudoBase64ExemploA</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:LongVarChar</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DomainExemploCorteA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DomainExemploCorteA</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Corte Tipo</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:DomainExemploCorteA</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DocumentoExemploEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DocumentoExemploEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Documento Fiscal Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:DocumentoExemploEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="loginUsuarioId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>loginUsuarioId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Usuario Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:UsuarioId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="emptyAuthSession">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>emptyAuthSession</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthSession, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthError">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthError</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthError, SanitizedSecurity</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>4</Value>
        </Property>
        <Property>
          <Name>Decimals</Name>
          <Value>0</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>4</Value>
        </Property>
        <Property>
          <Name>AttAvgLen</Name>
          <Value>0</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthErrors">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthErrors</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthError, SanitizedSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthLoginAdditionalParameters">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthLoginAdditionalParameters</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthLoginAdditionalParameters, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthSession">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthSession</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthSession, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthUser">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthUser</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthUser, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GrupoDeItemId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GrupoDeItemId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Grupo De Item Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:GrupoDeItemId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DomainExemploGrupoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DomainExemploGrupoA</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:DomainExemploGrupoA</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="MensagensInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>MensagensInicio</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:Messages, Sanitized.Common</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ListaSDTExemploItemBasicoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ListaSDTExemploItemBasicoA</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:sdtItemDadosBasicos</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
        <Property>
          <Name>idVarServiceExtName</Name>
          <Value>ListaItemDadosBasicos</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeArquivo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeArquivo</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>512</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>512</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeArquivoExemploA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeArquivoExemploA</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>256</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>256</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ContextoLoginId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ContextoLoginId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:EmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemCodigo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemCodigo</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Código</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemCodigo</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemMarcaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemMarcaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Marca Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemMarcaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemTipoExemploA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemTipoExemploA</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Tipo</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemTipoExemploA</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ProgressIndicator_Title">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ProgressIndicator_Title</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>256</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>256</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="MensagensRetorno">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>MensagensRetorno</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:Messages, Sanitized.Common</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SDTExemploRegraSelecaoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SDTExemploRegraSelecaoA</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:SDTExemploRegraSelecaoA</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemDadosFiscaisAdicionais">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemDadosFiscaisAdicionais</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemDadosOpcionaisPorEmpresa">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemDadosOpcionaisPorEmpresa</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemIdiomas">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemIdiomas</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SessionValid">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SessionValid</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="OperacaoExemploSucessoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>OperacaoExemploSucessoA</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="tipodeconteudo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>tipodeconteudo</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DomainExemploLocalA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DomainExemploLocalA</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:DomainExemploLocalA</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="RegraExemploEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>RegraExemploEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Regra Empresa Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:RegraExemploEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="RegraExemploId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>RegraExemploId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Regra Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:RegraExemploId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UltimaAlteracaoInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UltimaAlteracaoInicio</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Data</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UserLogin">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UserLogin</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UserName">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UserName</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:AuthUserIdentification, SanitizedSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DomainExemploTipoOperacaoA">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DomainExemploTipoOperacaoA</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:DomainExemploTipoOperacaoA</Value>
        </Property>
      </Properties>
    </Variable>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>APIExemploIntegracao</Value>
    </Property>
    <Property>
      <Name>GENERATE_OPEN_API</Name>
      <Value>Yes</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

## Moldes sanitizados completos de WorkWithForWeb

- Evidência direta: o acervo usado nesta base contem 183 objetos WorkWithForWeb.
- Inferência forte: o tipo mostra forte dependência de Pattern, parent transacional e estrutura declarativa do bloco <Data Pattern=...>.
- Inferência forte: faz sentido documentar pelo menos um molde enxuto e um molde denso para cobrir extremos de uso real sem inventar estrutura.

### Molde sanitizado de WorkWithForWeb 1 - `WorkWithWebGrupoExemplo`

- Perfil: WorkWithForWeb enxuto com uma selecao simples, poucos atributos e uma aba tabular basica.
- Uso operacional: boa referencia para pattern web ligado a transaction simples, com leitura facil da selecao, filtro e view.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="098e2fb8-c338-4e2d-901b-061d18a3ee68" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-08-06T11:20:21.0000000Z" checksum="2453cba7e236b417113f4c8a3a1e97d3" fullyQualifiedName="WorkWithWebGrupoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="7140e146-7d45-07ad-16d5-8b7389584e23" name="WorkWithWebGrupoExemplo" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" description="Work With Web Grupo Exemplo" parent="GrupoExemplo" parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6">
  <Part type="a51ced48-7bee-0001-ab12-04e9e32123d1">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="1.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance webFormDefaults="Responsive Web Design" updateTransaction="Apply WW Style">
  <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-GrupoExemplo" />
  <level id="098e2fb8-c338-4e2d-901b-061d18a3ee68:1" name="GrupoExemplo">
    <descriptionAttribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" />
    <selection description="Grupos de Exemplo" page="&lt;unlimited&gt;">
      <modes />
      <attributes>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploEmpresaId" description="Empresa Id" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploId" description="Id" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
      </attributes>
      <filter>
        <attributes>
          <filterAttribute name="GrupoExemploDescricao" description="Descricao" default="" />
        </attributes>
        <conditions>
          <condition value="GrupoExemploEmpresaId = procEmpresaGrupoExemplo() or GrupoExemploEmpresaId = procLeContextoSessao()" />
          <condition value="GrupoExemploDescricao.IndexOf(&amp;GrupoExemploDescricao) &gt; 0 when not &amp;GrupoExemploDescricao.IsEmpty()" />
        </conditions>
      </filter>
    </selection>
    <view caption="GrupoExemploDescricao.ToString()" description="Grupo de Exemplo" backToSelection="True" masterPage="&lt;default&gt;">
      <parameters>
        <parameter name="GrupoExemploEmpresaId" null="True" />
        <parameter name="GrupoExemploId" null="True" />
      </parameters>
      <fixedData>
        <attributes>
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
        </attributes>
      </fixedData>
      <tabs>
        <tab name="Geral" code="General" description="Grupo de Exemplo" type="Tabular" wcname="GrupoExemploGeneral">
          <attributes>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploEmpresaId" description="Emp.Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploId" description="GrupoExemplo Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
          </attributes>
          <actions>
            <action name="Update" />
            <action name="Delete" />
          </actions>
        </tab>
      </tabs>
    </view>
  </level>
</instance>]]></Data>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>WorkWithWebGrupoExemplo</Value>
    </Property>
    <Property>
      <Name>KBObject</Name>
      <Value>1db606f2-af09-4cf9-a3b5-b481519d28f6-GrupoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

` 

### Molde sanitizado de WorkWithForWeb 2 - `WWExemploOperacionalDensoA`

Observação editorial:
- este caso representa uma família densa de `WorkWithForWeb`, com forte contexto transacional e alto volume de nomes de negócio no XML bruto
- a versão pública foi reduzida para um esqueleto estrutural, preservando o que interessa para leitura técnica e geração assistida de XPZ
- o valor técnico do caso está na coexistência de `selection`, `attributes`, `orders`, `filters`, `conditions`, `actions` e propriedades como `Apply` e `Transaction` no pattern

Esqueleto estrutural público:

```xml
<Object guid="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        id="00000000-0000-0000-0000-000000000000"
        moduleGuid="00000000-0000-0000-0000-000000000000"
        name="WWExemploOperacionalDensoA"
        type="78cecefe-be7d-4980-86ce-8d6e91fba04b"
        parent="TRNExemploOperacionalDensoA"
        parentId="00000000-0000-0000-0000-000000000000"
        parentType="d109e56e-cf2a-11d5-b200-000629b4905c"
        description="WWExemploOperacionalDensoA"
        isMain="false"
        folderName="WWExemploOperacionalDensoA">
  <source><![CDATA[]]></source>
  <Part type="a51f55f2-248f-4d9e-b6bd-170c23cbf498">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">
      <instance name="WorkWith">
        <web>
          <transaction transaction="00000000-0000-0000-0000-000000000000-TRNExemploOperacionalDensoA" />
          <level name="TRNExemploOperacionalDensoA"
                 description="TRNExemploOperacionalDensoA"
                 order="1"
                 baseTable="TRNExemploOperacionalDensoA"
                 title="TRNExemploOperacionalDensoA">
            <descriptionAttribute>AtributoExemploDescricaoA</descriptionAttribute>
            <selection>
              <levels>
                <level name="TRNExemploOperacionalDensoA">
                  <modes>
                    <mode name="Insert" enabled="True" />
                    <mode name="Update" enabled="True" />
                    <mode name="Delete" enabled="True" />
                    <mode name="Display" enabled="True" />
                  </modes>
                  <attributes>
                    <attribute>AtributoExemploEmpresaId</attribute>
                    <attribute>AtributoExemploSituacao</attribute>
                    <attribute>AtributoExemploDescricaoA</attribute>
                  </attributes>
                  <orders>
                    <order orderType="Ascending">AtributoExemploDescricaoA</order>
                  </orders>
                  <filters>
                    <filterAttribute>Integer(4)</filterAttribute>
                    <filterAttribute>Character(80)</filterAttribute>
                  </filters>
                  <conditions>
                    <condition enabled="True">AtributoExemploEmpresaId = &amp;EmpresaId</condition>
                  </conditions>
                  <actions>
                    <action objectName="PRCExemploAcaoA"
                            type="UserDefined"
                            enabled="True"
                            onlyselected="False" />
                  </actions>
                </level>
              </levels>
            </selection>
          </level>
        </web>
      </instance>
    </Data>
  </Part>
  <Part type="babfa2b2-19a0-4ef1-b5f4-81b7c7be79dc">
    <Source>
      <Properties>
        <Property>
          <Name>Apply</Name>
          <Value>True</Value>
        </Property>
        <Property>
          <Name>Name</Name>
          <Value>WorkWith</Value>
        </Property>
        <Property>
          <Name>Transaction</Name>
          <Value>TRNExemploOperacionalDensoA</Value>
        </Property>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Source>
  </Part>
</Object>
```

## Moldes sanitizados de pacote misto de importacao

- Evidência direta: esta trilha validou pelo menos dois perfis de pacote misto com importacao bem-sucedida na IDE do GeneXus.
- Evidência direta: um caso misto com `Attribute` top-level, `Transaction` e `WorkWithForWeb` foi aceito com coexistencia valida entre `Objects`, `Attributes`, `Dependencies` e `ObjectsIdentityMapping`.
- Evidência direta: um caso posterior com `4` `Transaction`, `4` `WorkWithForWeb` e `3` `Procedure` foi aceito com sucesso em `Import File Load`, `Import`, `Updating table information` e `Pattern generation`.
- Inferência forte: pacote misto nao deve ser tratado como um unico shape universal; o formato efetivamente validado depende da composicao de objetos e do molde comparavel exportado pela IDE.
- Referencia privada: os casos completos ficam mapeados em `C:\Dev\Knowledge\GeneXus-XPZ-PrivateMap`, com destaque para um caso embutido comparavel do perfil `Transaction + WorkWithForWeb + Procedure`.

### Molde sanitizado de pacote misto 1 - `XPZExemploTRNWWAtributosA`

- Perfil: pacote de importacao com `Transaction`, `WorkWithForWeb` e `Attribute` top-level no mesmo envelope.
- Uso operacional: boa referencia para frentes em que novos atributos precisam entrar junto da transacao e do pattern web associado.
- Limite metodologico: este caso nao deve ser promovido a molde universal de pacote misto; ele representa apenas um perfil especifico validado nesta trilha.

Leitura tecnica do caso:
- Evidência direta: `Transaction` e `WorkWithForWeb` coexistiram em `<Objects>`.
- Evidência direta: os atributos novos coexistiram em `<Attributes>`.
- Evidência direta: a referencia de `Pattern` do `WorkWithForWeb` esteve presente no bloco `Dependencies`.
- Evidência direta: o pacote passou por `Load`, `Import` e `Pattern generation` com sucesso.

### Molde sanitizado de pacote misto 2 - `XPZExemploTRNWWPRCEmbutidoA`

- Perfil: pacote de importacao embutido com `Transaction`, `WorkWithForWeb` e `Procedure`, sem `Attribute` top-level novo no mesmo envelope.
- Uso operacional: referencia principal para frente mista em que varios objetos existentes sao alterados em paralelo e a IDE aceita o pacote com os objetos completos embutidos em `<Objects>`.

Observacao editorial:
- o caso completo foi exportado e reimportado a partir de composicao real comparavel da IDE
- a versao publica preserva apenas o aprendizado estrutural do envelope
- nomes de negocio, GUIDs reais e mapeamentos privados completos permanecem fora desta base publica

Esqueleto estrutural publico:

```xml
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>...</MajorVersion>
    <MinorVersion>...</MinorVersion>
    <Build>...</Build>
  </KMW>
  <Source kb="GUID_VALIDO" username="USUARIO" UNCPath="\\SERVIDOR\KB">
    <Version guid="GUID_VALIDO" name="KB" />
  </Source>
  <Objects>
    <Object name="TRNExemploA" type="1db606f2-af09-4cf9-a3b5-b481519d28f6" ...>
      <Part ... />
    </Object>
    <Object name="TRNExemploB" type="1db606f2-af09-4cf9-a3b5-b481519d28f6" ...>
      <Part ... />
    </Object>
    <Object name="WorkWithWebTRNExemploA" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" ...>
      <Part ... />
    </Object>
    <Object name="WorkWithWebTRNExemploB" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" ...>
      <Part ... />
    </Object>
    <Object name="procPlanilhaExemploA" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" ...>
      <Part ... />
    </Object>
  </Objects>
  <Dependencies>
    <Reference Package="..." Type="..." Id="..." />
  </Dependencies>
  <ObjectsIdentityMapping>
    <ObjectIdentity Type="..." Name="..." parent="...">
      <Guid>...</Guid>
    </ObjectIdentity>
  </ObjectsIdentityMapping>
</ExportFile>
```

Leitura tecnica do caso:
- Evidência direta: o `Import File Load` falhou com `Value cannot be null. Parameter name: g` enquanto a frente ainda usava envelope leve por `FilePath`.
- Evidência direta: a mesma frente passou quando foi remontada como pacote embutido, com os objetos completos dentro de `<Objects>`.
- Evidência direta: o caso bem-sucedido reuniu `4` `Transaction`, `4` `WorkWithForWeb` e `3` `Procedure`.
- Evidência direta: o pacote passou por `Load`, `Import`, `Updating table information` e `Pattern generation` dos `WorkWithForWeb`.
- Inferência forte: para este perfil misto, o molde estrutural correto veio do export real comparavel da IDE, e nao de envelope leve hipotetico com `FilePath`.

### Molde sanitizado de SDT 1 - `sdtPeriodoExemplo`

- Perfil: SDT enxuto com um nivel unico e dois itens simples baseados em dominio.
- Uso operacional: boa referencia para SDT pequeno de entrada/saida com campos escalares.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="aca52e78-bfbb-4177-8884-c10d48d1fff1" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-05-19T17:55:24.0000000Z" checksum="1c526a33a1f679abfc3a2746ccdeb52b" fullyQualifiedName="sdtPeriodoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f50cac7f-5ce6-42e9-af89-7f4a9ebb7fdf" name="sdtPeriodoExemplo" type="447527b5-9210-4523-898b-5dccb17be60a" description="sdt Periodo Exemplo" parent="PastaExemploSDT" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a">
    <Level Name="sdtPeriodoExemplo">
      <LevelInfo guid="d288f3d0-3834-46af-a65f-5b3fb5308060" name="sdtPeriodoExemplo" type="a76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="sdt Periodo Exemplo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtPeriodoExemplo</Value>
          </Property>
        </Properties>
      </LevelInfo>
      <Item guid="4cedcb11-83cc-4f9b-8367-d93215f5ce1c" name="DataInicial" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Inicial Data" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>DataInicial</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Data</Value>
          </Property>
        </Properties>
      </Item>
      <Item guid="093d4eb3-5f4a-44d5-b0c3-2953dae0d8ab" name="DataFinal" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Final Data" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>DataFinal</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Data</Value>
          </Property>
        </Properties>
      </Item>
    </Level>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>sdtPeriodoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de SDT 2 - `sdtAgrupamentoExemplo`

- Perfil: SDT com item composto, colecao e metadata de serializacao externa (ExternalName, ExternalNamespace, idXmlNamespace, soaptype).
- Uso operacional: boa referencia para SDT mais sensivel a integracao, namespace e estrutura hierarquica declarada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="5ea9cdc4-1809-4bae-adfa-8e4183dab2f7" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-10-07T11:36:33.0000000Z" checksum="8da196d5696215a0956129a0223fc22a" fullyQualifiedName="sdtAgrupamentoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="da01d928-4061-4b6a-b92f-bc76dddd7397" name="sdtAgrupamentoExemplo" type="447527b5-9210-4523-898b-5dccb17be60a" description="sdt Agrupamento Exemplo" parent="PastaExemploSDT" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a">
    <Level Name="sdtAgrupamentoExemplo">
      <LevelInfo guid="ae2f592a-c84e-4081-b9f0-558ab1a49369" name="sdtAgrupamentoExemplo" type="a76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="sdt Agrupamento Exemplo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtAgrupamentoExemplo</Value>
          </Property>
        </Properties>
      </LevelInfo>
      <Item guid="a8f1c0e4-c0b4-4f7c-afb9-6a120e5cdbe9" name="Grupo" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Grupo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>Grupo</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:PastaExemploSDTServicetGrupo</Value>
          </Property>
          <Property>
            <Name>idXmlName</Name>
            <Value>Grupo</Value>
          </Property>
          <Property>
            <Name>idXmlNamespace</Name>
            <Value>http://example.org/sdt</Value>
          </Property>
          <Property>
            <Name>soaptype</Name>
            <Value>http://example.org/sdt.tGrupo</Value>
          </Property>
        </Properties>
      </Item>
      <Item guid="0d086759-eb3c-47e4-820b-e1665e63d1f4" name="Itens" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Country Code And Names" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>Itens</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:PastaExemploSDTServiceItemExemplo</Value>
          </Property>
          <Property>
            <Name>AttCollection</Name>
            <Value>True</Value>
          </Property>
          <Property>
            <Name>idCollectionItemName</Name>
            <Value>ItemExemplo</Value>
          </Property>
          <Property>
            <Name>idXmlName</Name>
            <Value>Itens</Value>
          </Property>
          <Property>
            <Name>idXmlNamespace</Name>
            <Value>http://example.org/sdt</Value>
          </Property>
          <Property>
            <Name>soaptype</Name>
            <Value>http://example.org/sdt.ItemExemplo</Value>
          </Property>
        </Properties>
      </Item>
    </Level>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>sdtAgrupamentoExemplo</Value>
    </Property>
    <Property>
      <Name>ExternalName</Name>
      <Value>ItemExemploGroupedByGrupo</Value>
    </Property>
    <Property>
      <Name>ExternalNamespace</Name>
      <Value>http://example.org/sdt</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Domain

- Evidência direta: o acervo usado nesta base contem 592 objetos Domain.
- Inferência forte: o tipo se divide bem entre dominios escalares simples e dominios enumerados com IDEnumDefinedValues, o que justifica documentar um molde de cada perfil.

### Molde sanitizado de Domain 1 - `NumeroExemplo`

- Perfil: Domain escalar simples baseado em as:Numeric.
- Uso operacional: boa referencia para dominios pequenos sem enum e sem metadata adicional relevante.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:42.0000000Z" checksum="e69ba129cdc6aa72ddcef4b634ca05bb" fullyQualifiedName="NumeroExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="cab4dbf1-394a-4e5c-bb72-3abf1987f5ea" name="NumeroExemplo" type="00972a17-9975-449e-aab1-d26165d51393" description="NumeroExemplo">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>NumeroExemplo</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:Numeric</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de Domain 2 - `TipoFluxoExemplo`

- Perfil: Domain enumerado baseado em as:VarChar, com IDEnumDefinedValues e AddEmptyItem.
- Uso operacional: boa referencia para dominios de selecao controlada e listas de valores declaradas no proprio objeto.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-08-03T13:19:15.0000000Z" checksum="4687298b6e435629a409b96cbb475799" fullyQualifiedName="TipoFluxoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ddeec0aa-63a3-450d-bd91-cb44da9360c5" name="TipoFluxoExemplo" type="00972a17-9975-449e-aab1-d26165d51393" description="Tipo Fluxo Exemplo">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>TipoFluxoExemplo</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:VarChar</Value>
    </Property>
    <Property>
      <Name>Length</Name>
      <Value>40</Value>
    </Property>
    <Property>
      <Name>AttMaxLen</Name>
      <Value>40</Value>
    </Property>
    <Property>
      <Name>IDEnumDefinedValues</Name>
      <Value>EntradaSimples, EntradaSimples, Entrada Simples; SaidaSimples, SaidaSimples, Saida Simples; AjusteInterno, AjusteInterno, Ajuste Interno; MovimentoAuxiliar, MovimentoAuxiliar, Movimento Auxiliar; ProducaoInterna, ProducaoInterna, Producao Interna; TransferenciaSaida, TransferenciaSaida, Transferencia de Saida; TransferenciaEntrada, TransferenciaEntrada, Transferencia de Entrada; ConsumoInterno, ConsumoInterno, Consumo Interno; Inventario, Inventario, Inventario; Reprocessamento, Reprocessamento, Reprocessamento</Value>
    </Property>
    <Property>
      <Name>AddEmptyItem</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Theme, PackagedModule, DesignSystem e ColorPalette

- Evidência direta: o acervo usado nesta base contem 7 objetos Theme, 16 PackagedModule, 2 DesignSystem e 1 ColorPalette.
- Inferência forte: nesses tipos pequenos vale mais registrar moldes completos representativos do que tentar classificacoes muito finas por familia.

### Molde sanitizado de Theme - `ThemeExemploMobile`

- Perfil: Theme mobile com PredefinedTypes, KmwSchemaVersion e conjunto grande de classes visuais.
- Uso operacional: boa referencia para temas de plataforma e estilos visuais baseados em classes internas.
- Evidência direta: a validacao posterior no acervo real mostrou que classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption` fazem parte do conjunto minimo usado por temas simples validos.
- Inferência forte: ao reduzir este molde, o agente nao deve podar classes apenas por parecerem acessorias; referencias internas entre classes podem quebrar o import mesmo quando o envelope estiver correto.
- Inferência forte: para clonagem segura, preservar `PredefinedTypes`, `Styles` e o grafo minimo de referencias de classe e mais importante do que simplificar agressivamente o XML.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T16:08:29.0000000Z" checksum="4f94c975e75fa53cc0a01dceeefd6fb8" fullyQualifiedName="ThemeExemploMobile" moduleGuid="00000000-0000-0000-0000-000000000000" guid="62516c42-4e89-428c-87ef-2a006971b9b4" name="ThemeExemploMobile" type="c804fdbd-7c0b-440d-8527-4316c92649a6" description="Theme Exemplo Mobile">
  <BaseImagePath />
  <TemplateName />
  <Part type="c31007a6-01d3-4788-95b3-425921d47758">
    <KmwSchemaVersion>3</KmwSchemaVersion>
    <PredefinedTypes>
      <Type ID="Application">
        <Default>Application</Default>
      </Type>
      <Type ID="ApplicationBars">
        <Default>ApplicationBars</Default>
      </Type>
      <Type ID="Animation">
        <Default>Animation</Default>
      </Type>
      <Type ID="Form">
        <Default>Form</Default>
      </Type>
      <Type ID="Attribute">
        <Default>Attribute</Default>
      </Type>
      <Type ID="Button">
        <Default>Button</Default>
      </Type>
      <Type ID="Menu">
        <Default>Menu</Default>
      </Type>
      <Type ID="MenuItem">
        <Default>MenuItem</Default>
      </Type>
      <Type ID="Grid">
        <Default>Grid</Default>
      </Type>
      <Type ID="GridRow">
        <Default>GridRow</Default>
      </Type>
      <Type ID="Group">
        <Default>Group</Default>
      </Type>
      <Type ID="GroupSeparator">
        <Default>GroupSeparator</Default>
      </Type>
      <Type ID="HorizontalLine">
        <Default>HorizontalLine</Default>
      </Type>
      <Type ID="Image">
        <Default>Image</Default>
      </Type>
      <Type ID="Multimedia">
        <Default>Multimedia</Default>
      </Type>
      <Type ID="Progress">
        <Default>Progress</Default>
      </Type>
      <Type ID="Tab">
        <Default>Tab</Default>
      </Type>
      <Type ID="TabPage">
        <Default>TabPage</Default>
      </Type>
      <Type ID="Table">
        <Default>Table</Default>
      </Type>
      <Type ID="TextBlock">
        <Default>TextBlock</Default>
      </Type>
      <Type ID="AudioController">
        <Default>AudioController</Default>
      </Type>
      <Type ID="Matrix">
        <Default>Matrix</Default>
      </Type>
      <Type ID="MatrixAxisLabel">
        <Default>MatrixAxisLabel</Default>
      </Type>
      <Type ID="Rating">
        <Default>Rating</Default>
      </Type>
      <Type ID="Calendar">
        <Default>Calendar</Default>
      </Type>
      <Type ID="PageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="Slider">
        <Default>Slider</Default>
      </Type>
      <Type ID="MapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="MapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="MapPolygon">
        <Default>MapPolygon</Default>
      </Type>
      <Type ID="Switch">
        <Default>Switch</Default>
      </Type>
      <Type ID="ToggleButtonGroup">
        <Default>ToggleButtonGroup</Default>
      </Type>
      <Type ID="SDPageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="SDSlider">
        <Default>Slider</Default>
      </Type>
      <Type ID="SDMapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="SDMapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="Dashboard">
        <Default>Dashboard</Default>
      </Type>
      <Type ID="DashboardOption">
        <Default>DashboardOption</Default>
      </Type>
    </PredefinedTypes>
    <Styles>
      <GxClass Name="AttributeTitle" Description="Attribute Title" Guid="8a58438a-f492-5f73-99cf-55a2841b213b">
        <Properties>
          <sd_font_size>18dip</sd_font_size>
          <sd_font_style />
        </Properties>
      </GxClass>
      <GxClass Name="AttributeSubtitle" Description="Attribute Subtitle" Guid="9cc07d44-616e-5dfa-8772-15c59fa18c2e">
        <Properties>
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="Button" Description="Button" Guid="abd2de3e-1c96-5681-b52b-bbe33c0dca49">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>#9E9E9E</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>12dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>12dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>12dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>12dip</sd_border_bottom_right_radius>
          <background_color>White</background_color>
          <highlighted_background_color>#0070ED</highlighted_background_color>
          <color>Black</color>
          <highlighted_color>White</highlighted_color>
          <sd_font_size>14dip</sd_font_size>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
      <GxClass Name="Grid" Description="Grid" Guid="e4351147-2c00-5e86-a86c-1b1683dce3d8">
        <Properties>
          <ThemeGridOddRowClassReference>GridRowOdd</ThemeGridOddRowClassReference>
          <ThemeGridEvenRowClassReference>GridRowEven</ThemeGridEvenRowClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="Group" Description="Group" Guid="5b6cae15-fc08-5644-a800-3bafa192ec88">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>8dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>8dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>8dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>8dip</sd_border_bottom_right_radius>
          <ThemeCaptionClassReference>TextBlockGroupCaption</ThemeCaptionClassReference>
          <ThemeGroupSeparatorClassReference />
          <background_color>white</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="HorizontalLine" Description="Horizontal Line" Guid="1fd49dd6-9a67-5da8-9cec-86596e45e98e">
        <Properties>
          <background_color>Silver</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="Tab" Description="Tab" Guid="41ccdaf1-69f2-55ac-aebd-c82c6cb8c06e">
        <Properties>
          <ThemeSelectedTabPageClassReference>TabPageSelected</ThemeSelectedTabPageClassReference>
          <ThemeUnselectedTabPageClassReference>TabPageUnselected</ThemeUnselectedTabPageClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TableDetail" Description="Table Detail" Guid="f29ce968-0c51-5789-b72a-b00938eb43b7">
        <Properties>
          <background_color>#E0E0E0</background_color>
          <sd_padding_bottom>10dip</sd_padding_bottom>
          <sd_padding_left>10dip</sd_padding_left>
          <sd_padding_right>10dip</sd_padding_right>
          <sd_padding_top>10dip</sd_padding_top>
        </Properties>
      </GxClass>
      <GxClass Name="TableSection" Description="Table Section" Guid="d97cfb58-0788-504c-8882-0413e104c009">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_radius>12dip</sd_border_radius>
          <background_color>White</background_color>
          <sd_row_horizontal_line_separator_table>True</sd_row_horizontal_line_separator_table>
          <ThemeHorizontalLineClassReference>HorizontalLine</ThemeHorizontalLineClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlock" Description="Text Block" Guid="27607de1-bd65-5b1b-99b8-9db711c42fc6">
        <Properties>
          <color />
        </Properties>
      </GxClass>
      <GxClass Name="CalendarLabel" Description="Calendar Label" Guid="b4e3175c-0c31-5e1d-9195-4b737ad6ff2d">
        <Properties>
          <sd_font_size>34dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockTitle" Description="Text Block Title" Guid="abae902b-d82f-59c6-a3f8-52de01a4a9f2">
        <Properties>
          <color />
          <sd_font_size>18dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockSubtitle" Description="Text Block Subtitle" Guid="ae4cb8a2-9d3d-5a1c-b8b1-427ef274d83f">
        <Properties>
          <color />
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockGroupCaption" Description="Text Block Group Caption" Guid="a7187aa1-d84c-57b0-a3cb-d2942a7818c9">
        <Properties>
          <color>White</color>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
    </Styles>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="43b86e51-163f-44af-ac5a-e101541b1a71">
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ThemeExemploMobile</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Theme Exemplo Mobile</Value>
    </Property>
    <Property>
      <Name>ThemeType</Name>
      <Value>idSD</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de PackagedModule - `PacoteExemplo.Servicos`

- Perfil: PackagedModule enxuto, organizado como modulo filho com poucos Part type estruturais.
- Uso operacional: boa referencia para empacotamento modular simples sem conteudo interno complexo.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T21:48:25.0000000Z" checksum="" fullyQualifiedName="PacoteExemplo.Servicos" moduleGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" guid="4b14738c-7611-4134-ab88-db7d218c8353" name="Servicos" type="c88fffcd-b6f8-0000-8fec-00b5497e2117" description="Servicos" parent="PacoteExemplo" parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117">
  <Part type="ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc">
    <Properties />
  </Part>
  <Part type="a5e6a251-2df0-44d8-adab-1da237574326">
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>Servicos</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de DesignSystem 1 - `DesignSystemExemploAuth`

- Perfil: DesignSystem enxuto com Styles e imports externos basicos.
- Uso operacional: boa referencia para design system pequeno e focado em overrides localizados.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="GeneXus" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-09-09T13:56:53.0000000Z" checksum="5d6c8e1c33b0aec4d2e8aa9471ab0656" fullyQualifiedName="DesignSystemExemploAuth" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="3050c016-2f23-456f-875c-afc6c6c52aa1" name="DesignSystemExemploAuth" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="Design System Exemplo Auth" parent="PastaExemploDesignSystem" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles DesignSystemExemploAuth
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    .table-login{
        width: 380px;
        padding: 40px 35px 40px 35px;
    }
    .cell-padding-top-label{
        padding-top: 8px;
    }
    .button-add-grid{
        @include Button;
        margin-bottom: -30px !important;
        z-index: 1 !important;
    } 

    .cell-ispassword{
        max-height: 1.5em;
        overflow: hidden;
    }
}

]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DesignSystemExemploAuth</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Design System Exemplo Auth</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>DesignSystem_Samples-web</Categories>
</Object>
` 

### Molde sanitizado de DesignSystem 2 - `dsExemploBase`

- Perfil: DesignSystem mais rico, com 	okens, Styles, imports e muito CSS/Sass customizado.
- Uso operacional: boa referencia para design system extenso com ajustes de layout, componentes e comportamento visual.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-19T15:55:10.0000000Z" checksum="06b5dabbb64ab6e177b8a976cdd4d07f" fullyQualifiedName="dsExemploBase" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ebbe998c-b28d-4173-a685-d41208d4ce72" name="dsExemploBase" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="ds Exemplo Base">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[tokens Name {

	#colors
	{
        
        #region Unanimo_Colors
            //primary: #696ef2;
            //secondary: rgba(128 , 0, 6, 1); //#13142c;
        #endregion

        #region Background_Colors
            ///surface: #ffffff;
        #endregion



        //primary-enabled: $colors.primary; 
        //secondary-enabled: $colors.secondary;

        //primary-active: #3015b0;
        //primary-hover: #413cd4;

        //secondary-active: rgba(128 , 0, 6, 1);
        //secondary-hover: rgba(192, 0, 0, 1);

		AzulClaro: #abc;

		//VermelhoEscuro: rgba(173, 8, 8);
        
	}
}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles dsExemploBase
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    //@import PackageExemploReports.QueryViewer;
    //@import PackageExemploReports.DashboardViewer;

    //nao salvou o problema do conteudo do tab nao aparecer sem clicar.
    //.tab-displayblock{
    //    @include Tab;
    //    display: block;
    //}

    //Para resolver a falta do fundo do item clicado num Dynamic List Box no Google Chrome
    select option {
        background-color: white; //gainsboro; //lightgray;
        color: black;
    }
    select option:checked {
        background-color: dodgerblue; //#007bff;
        color: white;
    }

    DIV.gx-mask
    {
            position: absolute;
            background-color: black;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            animation: entermask 1s;
            -webkit-animation: entermask 1s;
            //opacity: $opacity.mask-opacity;

            z-index: 99;

            background-image: gx-image(Loading_Icon_Exemplo); //(LoadingResults);
            background-repeat: no-repeat;
            background-size: 33%;
            -ms-filter: "alpha(opacity=10)";
            opacity: .20;
            display:inline-block;                      
            background-position: top; //0% 0%;
        }
    .form-group {
        margin-bottom: 1px;
    }

    //usado pelo menos em tables de web components como WCExemploVolumesA, tambem em transacoes
    .form-horizontal .form-group {
        margin-inline-start: 15px;
        margin-inline-end: 15px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em transacoes
    .form-horizontal .form-container .form-group {
        margin-inline-start: 0px;
        margin-inline-end: 0px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em webpanels com cad-basico
    .form-horizontal .Card-Basico .form-group {
        margin-inline-start: -5px;
        margin-inline-end: -5px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    // .gx-form-group {
    //     margin-bottom: 1px;
    // }

    // .form-control-static {
    //     padding-block: 0px;
    //     min-height: 15px;
    //     width: auto !important;
    // }

    //resolve o problema de linha vazia gastar espaco, em campos escondidos de transacoes.
    .col-xs-12.form__cell{
        display:contents !important;
        padding-block: 1px;
    }

    //faz quebrar o texto do cabeÃ§alho de grid como a aba de estoque movto diario de produto
    ///.gx-tab-padding-fix-1.GridTitle{    
    ///    white-space: normal !important;
    ///}

     //.gx-tab-spacing-fix-2.Grid.table-responsive{

     //.gx-grid.gx-standard-grid{
     //    text-align: left;
     //}

    //nao resolveu o problema do prompt no filtro do ww
    // .gx-prompt {
        
    //     content: gx-image(PackageExemploUI.prompt_light); 
    //     z-index: 0;
    //     width: 50px;
    //     height: 50px;

    // }

    //nao funcionou pra resolver o popup no ios
    //.gx-responsive-popup {
    //    height: auto;
    //}
        
    //para permitir popup em iOS    
    @media screen and (max-width: 767px) {
        .gx-responsive-popup.gx-popup {
            height: auto;
        }
        .gx-responsive-popup .gx-popup-content > iframe {
            height: auto;
        }
    }

    .gx-freestyle-grid{
        padding-block: 0px;
        min-height: 15px;
    }

    // .gx-grid .gx-standard-grid {


    // }

   .gx-action-group {
        display: flex; //Ativa Flexbox, permitindo organizaÃ§Ã£o dinÃ¢mica de elementos.
        flex-wrap: wrap; //Permite que os elementos quebrem para a prÃ³xima linha quando o espaÃ§o horizontal acabar.
        justify-content: flex-start; /* Alinha os itens Ã  esquerda */
        gap: $spacing.inline-xl; //usado para definir o espaÃ§amento entre os itens dentro de um container flex
    }

    .gx-grid-paging-bar {
        justify-content:center;
    }


    //.FreeStyleGrid{
        //line-height: 1;
    //}

    // .attribute-label {
    //     padding-top: 0px;
    // }

    //no carmime tem para a classe
    //gx-label col-xs-8 col-sm-3 col-md-2 col-lg-12 AttributeLabel control-label
    //text-align: left!important;

    //legenda de atributo em caso mais especifico, mas alem da transacao
    //.gx-label.col-sm-3.AttributeLabel.control-label {
    //      text-align: right;
    //}

    //nao funciona
    //.form-group.gx-form-group > label.gx-label.col-sm-3.AttributeLabel.control-label {
    //    text-align: right;
    //}
    
    //nao Ã© especifico o sufiente, pra funcionar apenas pra crud de transacao
    //.form-group.gx-form-group label.gx-label.col-sm-3.AttributeLabel.control-label {
    //     //text-align: right;
    //     color: red;
    //}

    //legenda dos campos de atributo , em transacao ou webpanel qualquer
    .gx-label.AttributeLabel {
        padding-top: 0px;
    }
    //ajuste da legenda dos campos da transacao
    .form-container .gx-label.AttributeLabel {
        text-align: right;
        padding-right: 0px;
        padding-left: 0px;
    }

    //legenda dos campos das transacoes, da aba geral
    .gx-label.ReadonlyAttributeLabel {
        padding-top: 0px;
        //text-align: right;
    }

    //usado em legenda de atributo de transacao, na aba geral do ww da transacao
    .form__cell .ReadonlyAttributeLabel {
        padding-inline-start: 15px;
        padding-inline-end: 3px;
        padding-block-start: 1px;
        text-align: right;
    }

    //usado em atributo de transacao, na aba geral do ww da transacao
    .form__cell .form-control-static {
        padding-block: 1px;
        min-height: 15px;
    }

    //Usado em transacao, junto aos atributos. Tambem em TransacaoGeneral, junto aos atributos
    .form__cell {
        padding-block: 1px;
    }
    //usado em transacao, junto aos atributos
    .form__cell-advanced {
        padding-block: 1px;
    }


    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //desligado em 13/05/2025 para depender de outro recurso
    //.Attribute[data-gx-readonly] {
    //   overflow-wrap:normal;
    //}

    ///faz quebrar linha por padrao em grid do ww
    ///.Attribute[data-gx-readonly]{
    ///    white-space: normal;
    ///    overflow-wrap:normal !important;
    ///}

    //funciona pra aba cadastros externos nao ficar com largura fixa nas colunas
    ///.gx-tab-spacing-fix-2.ViewGrid.table-responsive{
    ///    table-layout: auto;
    ///    display:table-caption; 
    ///    white-space:normal !important;
    ///}


//     .ActionButtons {
//     height: 25px;
// }
//     .HideFiltersButton{
//         margin-top: 0px;
//     }

//     .ShowFiltersButton {
//         margin-top: 0px;
//     }



    //usado em tables de filtros do work with, principalmente em grids ww de transacao
    .filters-container--visible {
        top:00;
        padding-inline-start: 10px;
        padding-inline-end: 10px;
    }
    @media screen and (max-width: 767px) {
        .filters-container--visible {
            
            top: 140px;
            max-height: 500px;
            min-height: calc(100vh - 220px);
            overflow-y: auto;
            margin-bottom: 80px; 

            //inset-inline-end: 1px;
            //inset-inline-start: 16px;

            //max-width: 100%;
            //box-sizing: border-box;

            //max-width: 90%;
            //width: 519px; //90%;

        }

        //usado nos filtros verticais do ww transacao
        .ww__filters-cell .filters-container--visible .col-xs-12 {

            justify-content: left;

        }

    }

    // //539px de largura no google chrome do Thinkphone.
    // @media screen and (min-width: 539px) and (max-width: 767px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 519px; //90%;

    //     }
    // }
    // //462 no edge do thinkphone
    // @media screen and (min-width: 462px) and (max-width: 538px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 442px; //90%;

    //     }
    // }
    // //390 google chrome no lg g8
    // @media screen and (min-width: 390px) and (max-width: 461px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 370px; //90%;

    //     }
    // }
    // //378 no firefox do thinkphone
    // @media screen and (min-width: 378px) and (max-width: 389px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 358px; //90%;

    //     }
    // }

    
    .TextblockLargeLink {
        @include TextblockLarge;
        color: $colors.AzulClaro;
    }

    .HeaderContainer {
        height: 60px;
    }

    //usado em filtros nos grids ww, como legenda
    .filter-item__label {
        
        //original
        font-family: $fonts.primary-semibold;
        color: $colors.on-background;
        position: relative;
        gx-text-block-link-class: filter-item__link;

        //ajuste
        //color: red;
        height: auto;

    }
    //conteudo
    .filter-item__label strong {
        
        //original
        //font-weight: normal;
        font-family: $fonts.primary-regular;
        padding-inline-start: 5px;

        //ajuste
        font-weight: bold;
        color: blue;
        
        ///nao funciona com padding-inline-start
        ///height: auto;

    }

    //para funcionar prompt em filtros no ww
    .filter-item__cell .input-group span.input-group-btn .btn {
        height: 28px;
        content: gx-image(PackageExemploUI.prompt_light); 
    }

    ///desligado porque parece estar atrapalhando.
    // //para para ww mostrar icone de esconder/mostrar um pouco mais longe do texto
    // .filters-container__item {
    //     padding-right: 11px;
    //     ///height: auto;
    // }
    // .filters-container__item--expanded {
    //     padding-right: 11px;    

    //     //z-index: -1; //nao resolve o problema do prompt no filtro do ww
    //     //position: relative; estraga tudo.
    // }

    // //par para ww esconder e mostrar direito o calendario
    // .filters-container__item .calendar.Calendar {
    //         display:none !important;
    // }
    // .filters-container__item--expanded .calendar.Calendar {
    //         display:block !important;
    // }

    .Grid tr:nth-child(even) {
        background-color: LightGray;
    }

    .Grid th {
        background-color: LightGray;
    }

    // .Grid-Basico {
    //     @include Grid;
    //     //gx-grid-odd-row-class: Grid-Basico-FundoCinza;
    // }
    // .Grid-Basico tr:nth-child(even) {
    //     background-color: Gray;
    // }
    // .Grid-Basico-FundoCinza {
    //     @include Grid;
    //     background-color: Gray;
    // }

    //funciona mudar, mas nao precisou
    // .Title
    // {
     
    //      //original
    //      font-size: $fontSizes.xl;
    //      font-family: $fonts.primary-bold;
    //      display: inline-block;
    //      //color: $colors.on-background;

    //     //ajuste
    //     color: red;

    // }

    .TableTop {
        
        //Original
        margin-bottom: $spacing.stack-l;

       //Ajuste
       //column-gap: $spacing.inline-xl;

    }

    // //table do topo da tela do ww quando ainda usa layout carmine
    .TableTopSearch {
         
        @include TableTop; 
        
        //nao adianta colocar mais nada, pois o form layout carmine usa colunas fixas
        //background-color: red;
        
    }
    //@media screen and (max-width: 767px) {
    //    .TableTopSearch {
    //        ;
    //    }
    //}

    .Card-Basico {
        @include Table;
        //border: 1px solid $colors.gray02;

        background-color: White;
        box-shadow: 1px 1px 1px 0px DarkGray;

        border-style: solid;
        border-width: 1px;
        border-radius: 5px;
        border-color: DarkGrey;

        padding-left: 5px;
        padding-right: 5px;
        padding-top: 2px;
        padding-bottom: 2px;
        
        margin-bottom: 2px;
        margin-top: 2px;

        line-height: 1.14;

    }
    .CardPesando {
        @include Card-Basico;
        background-color: LightGrey;

    }
    .CardErro {
        @include Card-Basico;
        background-color: Thistle;

    }
    .CardNovo {
        @include Card-Basico;
        background-color: AliceBlue;

    }
    .CardCarregado {
        @include Card-Basico;
        background-color: LightYellow;

    }
    .CardSalvo {
        @include Card-Basico;
        background-color: Lavender;

    }


    .Button {
        white-space: normal;
        height: auto; //28px;
        padding-inline-start: $spacing.inset-m;
        padding-inline-end: $spacing.inset-m;
        border-radius: $radius.l;
        min-width: auto; //80px;

        //button primary defaults
        background-color: $colors.primary;
        font-size: $fontSizes.s;
        font-family: $fonts.primary-semibold;
        color: $colors.on-primary;
        text-transform: uppercase;
        border: solid $borders.extra-small;

        gx-button-hovered-class: button-primary--hover;
        gx-button-focused-class: button-primary--focused;
        gx-button-highlighted-class: button-primary--active;
        gx-button-disabled-class: button-primary--disabled;

    }

    //.Button_2xHeight {
    //    @include Button;
    //    height: 56px;
    //}
    .ButtonHtmlExtensao {
        @include Button;
    }

    .Altura_64px {
        height: 64px;
    }

    .Altura_100px {
        height: 100px;
    }

    .Largura_64px {
        width: 64px;
    }

    .Largura_100px {
        width: 100px;
    }
    
    .LarguraMinima_50px {
        min-width: 50px;
    }

    .LarguraMinima_85px {
        min-width: 85px;
    }

    .LarguraMinima_100px {
        min-width: 100px;
    }

    .LarguraMinima_150px {
        min-width: 150px;
    }

    .LarguraMinima_200px {
        min-width: 200px;
    }

    .LarguraMinima_250px {
        min-width: 250px;
    }

    .LarguraMinima_300px {
        min-width: 300px;
    }

    .LarguraMaxima_250px {
        max-width: 250px;
    }

    #region varia pelo tamanho da tela
    
    //padrao pra telas acima de 1600px ( mas testando em 1920 px de largura )
    .LarguraMinima_ConformeTela {
        min-width: 450px;
    }

    //padrao pra telas de 1200 atÃ© 1599 px ( mas testando em 1366 px de largura )
    @media screen and (min-width: 1200px) and (max-width: 1599px) {
        .LarguraMinima_ConformeTela {
            min-width: 300px;
        }
    }

    //padrao pra telas de 992 atÃ© 1199 px ( mas testando em 1024 px de largura )
    @media screen and (min-width: 992px) and (max-width: 1199px) {
        .LarguraMinima_ConformeTela {
            min-width: 150px;
        }
    }

    //padrao pra telas de 768 atÃ© 991 px ( mas testando em 800 px de largura )
    @media screen and (min-width: 768px) and (max-width: 991px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    //@media (max-width: 767px) {
    //padrao pra telas atÃ© 767 px  ( mas testando em 360 px que imita celular em retrato )  
    @media screen and (max-width: 767px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    #endregion

    .Largura_AjustaPeloConteudo {
        width: fit-content;
    }

    // //toda tentativa falhou, nao escondendo o date picker
    // .DatePickerDesligado {
    //     //pointer-events: none;   //evitaria clicar no campo
    //     //appearance: textfield; /* Remove o estilo de datepicker */
    //     gx-hide-date-time-picker: True;
    // }

    #region Classes para Column Class

        .WWColumn {
            @include column;
            overflow: hidden;
        }        
        .WWColumnTamanhoLimitado {
            @include WWColumn;
            max-width: 150px;
        }

        .WWColumnTamanhoLimitado100px {
            @include WWColumn;
            max-width: 100px;
        }

        .WWColumnTamanhoLimitado75px {
            @include WWColumn;
            max-width: 75px;
        }

        .WWOptionalColumnTamanhoLimitado300 {
            
            @include column;
            max-width: 300px;

        }
        @media screen and (max-width: 767px) {

            .WWOptionalColumnTamanhoLimitado300 {
                
                //@include OptionalColumn; //nao deixa incluir
                display: none;

            }

         }

    #endregion

    //funciona pra aba cadastros externos nao ficar fixa
    .gx-tab-spacing-fix-2.ViewGrid.table-responsive{
        table-layout: auto;
        display:table-caption; 
        white-space:normal !important;
    }

    .ww__grid {
       table-layout: auto;
       
       display:table-caption; //tira o espaco extra na primeira coluna e deixa de fora, Ã  direita do grid.
       
       //width: auto; //nao resolveu
    }
    .ww__grid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ww__grid th {
        background-color: LightGray;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab {
       height: 5px;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab .tab-content {
        padding: 0px;
        padding-top: 5px;
        padding-bottom: 5px;
        padding-left: 0px;
        padding-right: 0px;
    }
        
    //usado no tab de abas do view transaction com ww web    
    .ww__view__tab__form-container {
        padding-inline-start: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
        padding-inline-end: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
    }

    // .gx_usercontrol gx-basic-tab ww__view__tab {
    //     //height: 12px;
    //     padding: 0px;
    // }

    // .div.ww__view__tab UL.nav-tabs {
    //     height: 12px;
    // }

    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI A {
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI {
        //height: 12px;
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs {
        //height: 12px;
        margin-top: 0px;
    }

    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table { 
        height: 22px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .heading-01 {
        font-size: 14px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .form-control-static {
        
        height: 14px;
        min-height: 14px;
        max-height: 14px;
        padding-block: 0px;

    }


    // //para os campos de dados fixos das Views das transacoes com Work With Web
    // //tambem serve pra ww de transacacoes, pra mostrar o nome da pagina com o grid
    // //tambem pra paginas de edicao de transacoes
    // .heading-01 {
    //     font-size: 12px;
    // }

    //usado no table top do transacao general com ww web, pra mostrar link pra voltar pro grid
    .ww__actions-container {
        margin-bottom: 0px;
    }

    //container do grid em objetos ww
    // .ww__grid-container {
    //     width: auto;
    // }

    //usado em tables de grid do work with
    .ww__grid-cell--expanded .container-fluid {
        padding-inline-start: 1px;
    }

    .WorkWith,.PromptGrid,.ViewGrid {
        
        //original unanimoweb
        text-align: start;
        //table-layout: fixed;
        border-collapse: collapse;

        //ajustado
        table-layout: auto;
        display:table-caption; 
        width:auto;

    }
    .WorkWith tr:nth-child(even) {
        background-color: LightGray;
    }
    .WorkWith th {
        background-color: LightGray;
    }
    .PromptGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .PromptGrid th {
        background-color: LightGray;
    }
    .ViewGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ViewGrid th {
        background-color: LightGray;
    }

    .DescriptionAttribute a{
        
        //original unanimoweb
        color: $colors.primary-enabled; 
        text-decoration: underline;

        //ajustado
        white-space: nowrap;

    }
    .DescriptionAttribute a:hover {
        
        //original unanimoweb
        color: $colors.border-primary-hover;

        //ajustado
        white-space:normal;

    }

    .Attribute {

        //Original
        // min-height: 28px;
        // max-width: 100%;
        // font-family: $fonts.primary-regular;
        // font-size: $fontSizes.s;
        // padding-inline-start: $spacing.inset-s;
        // padding-inline-end: $spacing.inset-s;
        // border-color: $colors.gray04;
        // color: $colors.on-background;
        // background-color: $colors.attribute-bg;
        // border-radius: $radius.l;
        // gx-attribute-focused-class: AttributeFocusedClass;
        // gx-readonly-class: ROAttribute;
        // gx-label-class: attribute-label;
        // gx-datepicker-image-class: datepicker-image;
        // gx-prompt-image-class: gx-prompt;

        //Ajustes
        white-space: nowrap; //nao quebra em linhas, igual estÃ¡ no carmine
        
        //nao funciona
        //gx-hide-date-time-picker: True;

    }

    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //.AttributeQuebraLinha[data-gx-readonly] {
    //   overflow-wrap:normal !important;
    //}

    
    //resolve o problema de largura 100% em campo de transacao unanimo chamada de pagina do carmine
    .Attribute.form-control{
     
        @include Attribute;
     
        width: auto !important;

        height:auto;

    }
    
    //coluna em wwgrid para atributo marcado como descricao
    .attribute-description {
        white-space: nowrap; //nao quebra em linhas
    }

    .AttributeTextoPreservado {
        white-space: pre;
    }
    
    .AttributeQuebraLinha {
        @include Attribute;
        
        white-space: normal !important;
        
        //overflow-wrap:normal !important; //funciona, mas sobra espaco na linha
        overflow-wrap:break-word !important;
        
        //display: inline-block; //nao ajuda a melhorar a quebra
        //min-width: 300px; //nao funciona aqui

    }

    .AttributeQuebraLinhaApenasAteWidth1199px {
        
        @include Attribute;
        
    }
    @media screen and (max-width: 1199px) {

        .AttributeQuebraLinhaApenasAteWidth1199px {
            
            min-height: 28px;
            max-width: 100%;
            font-family: $fonts.primary-regular;
            font-size: $fontSizes.s;
            //padding-inline-start: $spacing.inset-s;
            //padding-inline-end: $spacing.inset-s;
            //border-color: $colors.gray04;
            //color: $colors.on-background;
            //background-color: $colors.attribute-bg;
            //border-radius: $radius.l;
            //gx-attribute-focused-class: AttributeFocusedClass;
            //gx-readonly-class: ROAttribute;
            //gx-label-class: attribute-label;
            //gx-datepicker-image-class: datepicker-image;
            //gx-prompt-image-class: gx-prompt;
            
            white-space: normal !important;
            overflow-wrap:break-word !important;

        }

    }

    //usada pelo ww com form layout carmine
    .FilterAttribute {
        
        @include Attribute;
        //overflow: hidden;

        //copiado de attribute-filter:
        //gx-label-class: attribute-label;
        width: 100%;
        //font-family: $fonts.primary-regular;
        //font-size: $fontSizes.s;
        padding-inline-start: $spacing.inset-s;
        padding-inline-end: $spacing.inset-s;
        //gx-attribute-focused-class: AttributeFocusedClass;
        //background-color: $colors.attribute-bg;

    }
    //usada pelo ww com form layout carmine
    .FilterComboAttribute {
        
        @include FilterAttribute;

    }

    // .WWAdvancedLabel {
    //     color: red;
    // }
    // .WWFilterLabel {
    //     color: blue;
    // }


    .AttributeSenha {
        @include Attribute;
        -webkit-text-security:disc !important;
    }

    .AttributeAvisos {
        @include Attribute;
        height: auto;
        width: auto;
    }

    .AttributeMessagesNormal{
        //@include Attribute;
        color: ForestGreen !important;
    }

    .AttributeMessagesAlertaExtremo{
        //@include Attribute;
        color: OrangeRed !important;

    }

    .AttributeMessagesAlerta{
        //@include Attribute;
        color: DarkOrange !important;
    }

    .AttributeMessagesErro{
        //@include Attribute;
        color: rgb(210, 4, 45) !important;

    }

    .AttributeMessagesInfo{
        //@include Attribute;
        color: Black !important;

    }

    .AttributeMessagesSeparador{
        //@include Attribute;
        color: Silver !important;
        background-color: Silver !important;

    }


    // .column {
    //     @include column;
    //         width: 100%;  
    //         padding-inline-start: $spacing.inset-s;
    //         padding-inline-end: $spacing.inset-s;
    //         border-bottom-width: 1px;
    //         border-bottom-color: $colors.gray01;
    //         border-bottom-style:solid;
    //         gx-grid-column-header-class: column;
    // } 

    //.GridColuna-Opcional {
    //    overflow: hidden;  //NAO ESCONDE COISA NENHUMA !
    //    color: $colors.on-background;
    //}

    // .blink {
    // animation: blink 1s steps(1, end) infinite;
    // }
    .blink {
    animation: blink 1s infinite;
    }

    @keyframes blink {
        0% {
            opacity: 1;
            }
        50% {
            opacity: 0;
        }
        100% {
            opacity: 1;
        }
    }

}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/design-system-migration]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>dsExemploBase</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

` 

### Molde sanitizado de ColorPalette - `PaletteExemplo`

- Perfil: ColorPalette simples, com conjunto de cores nomeadas em PaletteColors.
- Uso operacional: boa referencia para paletas enxutas baseadas apenas em nomes e cores hexadecimais.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-08-16T16:51:47.0000000Z" checksum="2ccb44e8b9d067e4056a4eae8fa03a75" fullyQualifiedName="PaletteExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7bdd2542-2a09-4884-90d6-e1dafe4a4391" name="PaletteExemplo" type="3affc0b3-494b-4d84-9ec1-3a6ab8349cda" description="PaletteExemplo">
  <Part type="5d481862-64bc-4e88-8af2-e21c276dab77">
    <PaletteColors>
      <PaletteColor name="Text" color="#2A3143" />
      <PaletteColor name="Base" color="#2457A7" />
      <PaletteColor name="DarkBase" color="#163B72" />
      <PaletteColor name="Dominant" color="#9FD3FF" />
      <PaletteColor name="Read Only Text" color="#EAEAEA" />
      <PaletteColor name="Action" color="#0C8C74" />
      <PaletteColor name="SecondaryAction" color="#5B6EF5" />
      <PaletteColor name="Border" color="#EFEFEF" />
      <PaletteColor name="DarkBorder" color="#B7B7B7" />
      <PaletteColor name="Background" color="#F9F9F9" />
      <PaletteColor name="MessageBackground" color="#FFFEBC" />
      <PaletteColor name="LightMessageBackground" color="#FFFFE1" />
      <PaletteColor name="RecentLink" color="#3D434F" />
      <PaletteColor name="WarningColor" color="#FF8000" />
    </PaletteColors>
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PaletteExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de ExternalObject, UserControl e Module

- Evidência direta: o acervo usado nesta base contem 18 ExternalObject, 7 UserControl e 279 Module.
- Inferência forte: nesses tipos vale separar um perfil minimo e outro mais rico quando houver contrato declarativo ou script suficiente para justificar a diferenca.

### Molde sanitizado de ExternalObject 1 - ObjetoExternoGenerico

- Perfil: ExternalObject minimo, sem metodos declarados, apenas metadados de namespace e tipo externo.
- Uso operacional: boa referencia para objetos externos nativos ou wrappers muito pequenos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="620303f9-3859-4530-9c0a-4bd9f092cc07" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-07-18T22:08:38.0000000Z" checksum="b7c4fb30d26f475130a01fd8fb48f2d2" fullyQualifiedName="ObjetoExternoGenerico" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="30e2e748-7c30-434a-b7dc-b32a0224caa2" name="ObjetoExternoGenerico" type="c163e562-42c6-4158-ad83-5b21a14cf30e" description="Objeto Externo Generico" parent="PastaExemploExterno" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="00000000-0000-0000-0002-000000000005">
    <Properties />
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ObjetoExternoGenerico</Value>
    </Property>
    <Property>
      <Name>ExoType</Name>
      <Value>Native Object</Value>
    </Property>
    <Property>
      <Name>ObjNamespace</Name>
      <Value>SANITIZED</Value>
    </Property>
    <Property>
      <Name>ExoName</Name>
      <Value>ObjetoExternoGenerico</Value>
    </Property>
    <Property>
      <Name>ExoNameCSHARP</Name>
      <Value>ObjetoExternoGenerico</Value>
    </Property>
    <Property>
      <Name>AssemblyName</Name>
      <Value />
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de ExternalObject 2 - ServicoEnderecoExemplo

- Perfil: ExternalObject com varios ExternalMethod, parametros, tipos externos e endereco de servico.
- Uso operacional: boa referencia para integracoes SOAP/RPC ou wrappers declarativos mais ricos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="9ae73ae9-0f41-4b5e-9397-1231c481b8f3" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-02-16T18:13:55.0000000Z" checksum="48449c43470858ba4dd744d9a3a260c3" fullyQualifiedName="ServicoEnderecoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="9645286e-74c7-4223-bd68-a5b7d15696d9" name="ServicoEnderecoExemplo" type="c163e562-42c6-4158-ad83-5b21a14cf30e" description="Servico Endereco Exemplo" parent="ServicoEnderecoExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="00000000-0000-0000-0002-000000000005">
    <ExternalMethods>
      <ExternalMethod>
        <Properties>
          <Property>
            <Name>IntName</Name>
            <Value>obterVersaoServico</Value>
          </Property>
          <Property>
            <Name>ExoItemType</Name>
            <Value>bas:Character</Value>
          </Property>
          <Property>
            <Name>ExoItemLength</Name>
            <Value>9999</Value>
          </Property>
          <Property>
            <Name>ExoMethodStyle</Name>
            <Value>idRPC</Value>
          </Property>
          <Property>
            <Name>ExoMethodInputUse</Name>
            <Value>idEncoded</Value>
          </Property>
          <Property>
            <Name>ExoMethodAddress</Name>
            <Value>https://example.org/ws/address</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeName</Name>
            <Value>ServicoEnderecoExemploPort</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeNamespace</Name>
            <Value>urn:ServicoEnderecoExemplo</Value>
          </Property>
          <Property>
            <Name>ExoMethodAction</Name>
            <Value>urn:ServicoEnderecoExemploAction</Value>
          </Property>
          <Property>
            <Name>ExoName</Name>
            <Value>obterVersaoServico</Value>
          </Property>
          <Property>
            <Name>ExoMethodRequestNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseElementName</Name>
            <Value>obterVersaoServicoResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmName</Name>
            <Value>obterVersaoServicoResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmNamespace</Name>
            <Value />
          </Property>
          <Property>
            <Name>ExoItemExtType</Name>
            <Value>http://www.w3.org/2001/XMLSchema.string</Value>
          </Property>
        </Properties>
      </ExternalMethod>
      <ExternalMethod>
        <Parameters>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>codigo</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>codigo</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
        </Parameters>
        <Properties>
          <Property>
            <Name>IntName</Name>
            <Value>obterEndereco</Value>
          </Property>
          <Property>
            <Name>ExoItemType</Name>
            <Value>bas:Character</Value>
          </Property>
          <Property>
            <Name>ExoItemLength</Name>
            <Value>9999</Value>
          </Property>
          <Property>
            <Name>ExoMethodStyle</Name>
            <Value>idRPC</Value>
          </Property>
          <Property>
            <Name>ExoMethodInputUse</Name>
            <Value>idEncoded</Value>
          </Property>
          <Property>
            <Name>ExoMethodAddress</Name>
            <Value>https://example.org/ws/address</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeName</Name>
            <Value>ServicoEnderecoExemploPort</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeNamespace</Name>
            <Value>urn:ServicoEnderecoExemplo</Value>
          </Property>
          <Property>
            <Name>ExoMethodAction</Name>
            <Value>urn:ServicoEnderecoExemploAction</Value>
          </Property>
          <Property>
            <Name>ExoName</Name>
            <Value>obterEndereco</Value>
          </Property>
          <Property>
            <Name>ExoMethodRequestNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseElementName</Name>
            <Value>obterEnderecoResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmName</Name>
            <Value>obterEnderecoResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmNamespace</Name>
            <Value />
          </Property>
          <Property>
            <Name>ExoItemExtType</Name>
            <Value>http://www.w3.org/2001/XMLSchema.string</Value>
          </Property>
        </Properties>
      </ExternalMethod>
      <ExternalMethod>
        <Parameters>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>codigo</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>codigo</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>login</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>login</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>segredo</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>segredo</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
        </Parameters>
        <Properties>
          <Property>
            <Name>IntName</Name>
            <Value>obterEnderecoAuth</Value>
          </Property>
          <Property>
            <Name>ExoItemType</Name>
            <Value>bas:Character</Value>
          </Property>
          <Property>
            <Name>ExoItemLength</Name>
            <Value>9999</Value>
          </Property>
          <Property>
            <Name>ExoMethodStyle</Name>
            <Value>idRPC</Value>
          </Property>
          <Property>
            <Name>ExoMethodInputUse</Name>
            <Value>idEncoded</Value>
          </Property>
          <Property>
            <Name>ExoMethodAddress</Name>
            <Value>https://example.org/ws/address</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeName</Name>
            <Value>ServicoEnderecoExemploPort</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeNamespace</Name>
            <Value>urn:ServicoEnderecoExemplo</Value>
          </Property>
          <Property>
            <Name>ExoMethodAction</Name>
            <Value>urn:ServicoEnderecoExemploAction</Value>
          </Property>
          <Property>
            <Name>ExoName</Name>
            <Value>obterEnderecoAuth</Value>
          </Property>
          <Property>
            <Name>ExoMethodRequestNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseElementName</Name>
            <Value>obterEnderecoAuthResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmName</Name>
            <Value>obterEnderecoAuthResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmNamespace</Name>
            <Value />
          </Property>
          <Property>
            <Name>ExoItemExtType</Name>
            <Value>http://www.w3.org/2001/XMLSchema.string</Value>
          </Property>
        </Properties>
      </ExternalMethod>
      <ExternalMethod>
        <Parameters>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>logradouro</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>logradouro</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>localidade</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>localidade</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>UF</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>UF</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
        </Parameters>
        <Properties>
          <Property>
            <Name>IntName</Name>
            <Value>obterCEP</Value>
          </Property>
          <Property>
            <Name>ExoItemType</Name>
            <Value>bas:Character</Value>
          </Property>
          <Property>
            <Name>ExoItemLength</Name>
            <Value>9999</Value>
          </Property>
          <Property>
            <Name>ExoItemIsCollection</Name>
            <Value>True</Value>
          </Property>
          <Property>
            <Name>ExoMethodStyle</Name>
            <Value>idRPC</Value>
          </Property>
          <Property>
            <Name>ExoMethodInputUse</Name>
            <Value>idEncoded</Value>
          </Property>
          <Property>
            <Name>ExoMethodAddress</Name>
            <Value>https://example.org/ws/address</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeName</Name>
            <Value>ServicoEnderecoExemploPort</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeNamespace</Name>
            <Value>urn:ServicoEnderecoExemplo</Value>
          </Property>
          <Property>
            <Name>ExoMethodAction</Name>
            <Value>urn:ServicoEnderecoExemploAction</Value>
          </Property>
          <Property>
            <Name>ExoName</Name>
            <Value>obterCEP</Value>
          </Property>
          <Property>
            <Name>ExoMethodRequestNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseElementName</Name>
            <Value>obterCEPResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmName</Name>
            <Value>obterCEPResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmNamespace</Name>
            <Value />
          </Property>
          <Property>
            <Name>ExoItemExtType</Name>
            <Value>urn:ServicoEnderecoExemplo.ArrayOfstring</Value>
          </Property>
          <Property>
            <Name>ExoItemWRAPPEDCOLLECTION</Name>
            <Value>idXmlCollectionWrapped</Value>
          </Property>
          <Property>
            <Name>ExoItemCollectionItemName</Name>
            <Value>item</Value>
          </Property>
        </Properties>
      </ExternalMethod>
      <ExternalMethod>
        <Parameters>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>logradouro</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>logradouro</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>localidade</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>localidade</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>UF</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>UF</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>login</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>login</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
          <Parameter>
            <Properties>
              <Property>
                <Name>ExoParamAccessType</Name>
                <Value>in</Value>
              </Property>
              <Property>
                <Name>IntName</Name>
                <Value>segredo</Value>
              </Property>
              <Property>
                <Name>ExoItemType</Name>
                <Value>bas:Character</Value>
              </Property>
              <Property>
                <Name>ExoItemLength</Name>
                <Value>9999</Value>
              </Property>
              <Property>
                <Name>ExoName</Name>
                <Value>segredo</Value>
              </Property>
              <Property>
                <Name>ExoNamespace</Name>
                <Value />
              </Property>
              <Property>
                <Name>ExoItemExtType</Name>
                <Value>http://www.w3.org/2001/XMLSchema.string</Value>
              </Property>
            </Properties>
          </Parameter>
        </Parameters>
        <Properties>
          <Property>
            <Name>IntName</Name>
            <Value>obterCEPAuth</Value>
          </Property>
          <Property>
            <Name>ExoItemType</Name>
            <Value>bas:Character</Value>
          </Property>
          <Property>
            <Name>ExoItemLength</Name>
            <Value>9999</Value>
          </Property>
          <Property>
            <Name>ExoItemIsCollection</Name>
            <Value>True</Value>
          </Property>
          <Property>
            <Name>ExoMethodStyle</Name>
            <Value>idRPC</Value>
          </Property>
          <Property>
            <Name>ExoMethodInputUse</Name>
            <Value>idEncoded</Value>
          </Property>
          <Property>
            <Name>ExoMethodAddress</Name>
            <Value>https://example.org/ws/address</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeName</Name>
            <Value>ServicoEnderecoExemploPort</Value>
          </Property>
          <Property>
            <Name>ExoMethodPortTypeNamespace</Name>
            <Value>urn:ServicoEnderecoExemplo</Value>
          </Property>
          <Property>
            <Name>ExoMethodAction</Name>
            <Value>urn:ServicoEnderecoExemploAction</Value>
          </Property>
          <Property>
            <Name>ExoName</Name>
            <Value>obterCEPAuth</Value>
          </Property>
          <Property>
            <Name>ExoMethodRequestNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseElementName</Name>
            <Value>obterCEPAuthResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodResponseNamespace</Name>
            <Value>urn:https://example.org</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmName</Name>
            <Value>obterCEPAuthResponse</Value>
          </Property>
          <Property>
            <Name>ExoMethodReturnParmNamespace</Name>
            <Value />
          </Property>
          <Property>
            <Name>ExoItemExtType</Name>
            <Value>urn:ServicoEnderecoExemplo.ArrayOfstring</Value>
          </Property>
          <Property>
            <Name>ExoItemWRAPPEDCOLLECTION</Name>
            <Value>idXmlCollectionWrapped</Value>
          </Property>
          <Property>
            <Name>ExoItemCollectionItemName</Name>
            <Value>item</Value>
          </Property>
        </Properties>
      </ExternalMethod>
    </ExternalMethods>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ServicoEnderecoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Servico Endereco Exemplo</Value>
    </Property>
    <Property>
      <Name>ExoType</Name>
      <Value>WSDL</Value>
    </Property>
    <Property>
      <Name>ExoImporterVersion</Name>
      <Value>GX WSDL Tool version 2.0</Value>
    </Property>
    <Property>
      <Name>ExoSourceURI</Name>
      <Value>https://example.org/ws/address?WSDL</Value>
    </Property>
    <Property>
      <Name>ExoName</Name>
      <Value>ServicoEnderecoExemplo</Value>
    </Property>
    <Property>
      <Name>AssemblyName</Name>
      <Value>https://example.org/ws/address?WSDL</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de UserControl 1 - UCNavegacaoExemplo

- Perfil: UserControl pequeno com alguns scripts utilitarios de navegacao/reload.
- Uso operacional: boa referencia para controles simples orientados a JavaScript embutido.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="eabf2595-127f-4740-beee-048c9da4cc9a" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-05-17T14:08:16.0000000Z" checksum="60441b9eb2f8ca3e38d163f099b653b9" fullyQualifiedName="UCNavegacaoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="deb7eb7a-747d-4e58-b6e0-0f6077bc5993" name="UCNavegacaoExemplo" type="562f4793-aabe-449f-8821-fc77e550698e" description="Componente para forÃ§ar refresh da pÃ¡gina. Simula F5." parent="UserControls" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c67">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="8e9e4a7c-a4d3-4c36-8e8e-fb6702402f63">
    <Source><![CDATA[<Definition auto="false">
	<script name="ReloadPage">
		document.location.reload();
	</script>
	<script name="ReloadPageTo" Parameters = "urlString">
		document.location.href = urlString;
	</script>
	<script name="ReloadPageToAfter" Parameters = "urlString,milliseconds">
		setTimeout(function(){document.location.href = urlString;return false;}, milliseconds);
	</script>
</Definition>
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>UCNavegacaoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Componente para forÃ§ar refresh da pÃ¡gina. Simula F5.</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de UserControl 2 - UCDialogoExemplo

- Perfil: UserControl mais rico, com definicoes, propriedades, eventos e scripts extensos.
- Uso operacional: boa referencia para componentes customizados com API declarada e comportamento cliente mais complexo.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="26b65cc7-db83-4347-9d57-5c92b5890620" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2020-06-06T14:29:32.0000000Z" checksum="2af1f45c1583606b8178e4c0c3902137" fullyQualifiedName="UCDialogoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="955e9b8d-b768-4228-9d39-9e137e172746" name="UCDialogoExemplo" type="562f4793-aabe-449f-8821-fc77e550698e" description="UC Dialogo Exemplo" parent="PastaExemploUserControl" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c67">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="8e9e4a7c-a4d3-4c36-8e8e-fb6702402f63">
    <Source><![CDATA[<Definition auto="false">

<Property Name="DismissReason" Type="string" Default="" />
<Property Name="Position" Type="enum" Default="center">
	<Value>top</Value>
    <Value>top-start</Value>
    <Value>top-end</Value>
    <Value>center</Value>
	<Value>center-start</Value>		
	<Value>center-end</Value>			
	<Value>bottom</Value>		
	<Value>bottom-start</Value>		
	<Value>bottom-end</Value>		
</Property>
  
<Property Name="EventName" Type="string" Default="" />
<Property Name="ConvertGxMessages" Type="Boolean" Default="false" />

<Property Name="IconHTML" Type="string" Default="" />

<Property Name="IconMsg" Type="enum" Default="warning">
    <Value>success</Value>
    <Value>error</Value>
    <Value>warning</Value>
    <Value>info</Value>
	<Value>question</Value>
</Property>

<Property Name="IconError" Type="enum" Default="error">
    <Value>success</Value>
    <Value>error</Value>
    <Value>warning</Value>
    <Value>info</Value>
	<Value>question</Value>		
</Property>

<Property Name="TimeoutError" Type="Numeric" Default="3000" />
<Property Name="TimeoutMsg" Type="Numeric" Default="3000" />

<script name="getDialogAPI" when="BeforeShow">
	mythis   = this;
	gx.fx.obs.addObserver('gx.onmessages', this, this._showMessages);
	//cria uma variavel Global mythis para ser acessado em qualquer script
</script>

<script Name="_showMessages" Parameters="messages">

	
		//Precisa habilitar o parametro
		if(!mythis.ConvertGxMessages)
			return;
			
		//process messages	
		for (var key in messages) {
			if (key != undefined) {
				mythis._renderDialogAPI(messages[key]);
			}
		}
</script>
<script Name="_renderDialogAPI" Parameters="messages">

//process messages
var container = messages;
if (messages.msgs) container = messages.msgs;

jQuery.each(container, function (index, msg) {
	
	if (!msg || !msg.text)
	return;
	
	//Conflito com UC da Exemplo
	var _isJson = (msg.text.substr(0, 1) == "{") ? true : false;
	
	if(_isJson)
		return;
		
	if(msg.type == 1)
    	mythis.FireToast2(msg.text,'',mythis.IconError,mythis.TimeoutError);
	else
		mythis.FireToast2(msg.text,'',mythis.IconMsg,mythis.TimeoutMsg);
		
	var errViewers = gx.dom.byClass('gx_ev', 'span')
	$(errViewers).remove();
	
});

</script>
<script Name="Fire" Parameters="Titulo,Texto,DialogAPIIcon,TextoBotaoConfirmar,CorBotaoConfirmar">
DialogAPI.fire({
  title: Titulo,
  text: Texto,
  icon: DialogAPIIcon,
  confirmButtonText: TextoBotaoConfirmar,
  confirmButtonColor: CorBotaoConfirmar,
  position: mythis.Position
})     
</script>

<script Name="FireWithTimer" Parameters="Titulo,Texto,DialogAPIIcon,TextoBotaoConfirmar,CorBotaoConfirmar,Timer">
DialogAPI.fire({
  title: Titulo,
  text: Texto,
  icon: DialogAPIIcon,
  confirmButtonText: TextoBotaoConfirmar,
  confirmButtonColor: CorBotaoConfirmar,
  timer: Timer,
  timerProgressBar: true
})     
</script>

<script Name="FireToast" Parameters="Titulo,Texto,DialogAPIIcon,Timer">
DialogAPI.fire({
  title: Titulo,
  text: Texto,
  icon: DialogAPIIcon,
  position: mythis.Position,
  showConfirmButton: false,  
  timer: Timer,
  timerProgressBar: true,
  toast: true
}).then((result) => {
  /* Read more about handling dismissals below */
  if (result.dismiss === DialogAPI.DismissReason.timer) {
    console.log('I was closed by the timer');
    mythis.DismissReason = result.dismiss;
    
	try {
	mythis.ClosedTimer();	
	}
	catch (e) {
	// declaraÃ§Ãµes para manipular quaisquer exceÃ§Ãµes
	//logMyErrors(e); // passa o objeto de exceÃ§Ã£o para o manipulador de erro
	}	
    	
  }
})     
</script>

<script Name="FireToast2" Parameters="Titulo,Texto,DialogAPIIcon,Timer">
DialogAPI.fire({
  title: Titulo,
  text: Texto,
  icon: DialogAPIIcon,
  iconHtml: mythis.IconHTML,
  position: mythis.Position,
  showConfirmButton: false,  
  timer: Timer,
  timerProgressBar: true
}).then((result) => {
  /* Read more about handling dismissals below */
  if (result.dismiss === DialogAPI.DismissReason.timer) {
    console.log('I was closed by the timer');
    mythis.DismissReason = result.dismiss;
    
	try {
	mythis.ClosedTimer();	
	}
	catch (e) {
	// declaraÃ§Ãµes para manipular quaisquer exceÃ§Ãµes
	//logMyErrors(e); // passa o objeto de exceÃ§Ã£o para o manipulador de erro
	}	
    		
  }
})     
</script>

<script Name="Confirm" Parameters="Titulo,Texto,DialogAPIIcon,TextoBotaoConfirmar">

const swalWithBootstrapButtons = DialogAPI.mixin({
  customClass: {
	    confirmButton: 'btn btn-success',
	    cancelButton: 'btn btn-danger'
  },
  buttonsStyling: false
})

swalWithBootstrapButtons.fire({
  title: Titulo,
  text: Texto,
  icon: DialogAPIIcon,
  confirmButtonText: TextoBotaoConfirmar,
  cancelButtonText: 'Fechar',
  position: mythis.Position,
  showCancelButton: true,
  reverseButtons: false
}).then((result) => {
  if (result.value) {
	  //Responseu Sim	  
	  mythis.Confirmed();
    
  } else {
    mythis.DismissReason = result.dismiss;
    
	try {
	mythis.Cancel();
	}
	catch (e) {
	// declaraÃ§Ãµes para manipular quaisquer exceÃ§Ãµes
	//logMyErrors(e); // passa o objeto de exceÃ§Ã£o para o manipulador de erro
	}	    		
  }
})     
</script>

<Event Name="Confirmed" On="Click"/>
<Event Name="Cancel" On="Click"/>
<Event Name="ClosedTimer" On="Click"/>

</Definition>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>UCDialogoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>UC Dialogo Exemplo</Value>
    </Property>
    <Property>
      <Name>FileReferences</Name>
      <Value />
    </Property>
    <Property>
      <Name>BaseStyle</Name>
      <Value>dialogo-exemplo-base</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Module - IntegracoesExemplo

- Perfil: Module enxuto, sem partes internas complexas, funcionando como unidade organizacional declarativa.
- Uso operacional: boa referencia para modulos simples e hierarquia nominal.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:54.0000000Z" checksum="" fullyQualifiedName="IntegracoesExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="cb061c3d-a2eb-4335-bb1a-feacbc4a9c6f" name="IntegracoesExemplo" type="00000000-0000-0000-0000-000000000008" description="IntegracoesExemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>IntegracoesExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de SubTypeGroup

### Molde sanitizado de SubTypeGroup 1 - `EntidadeProcessoEmpresaExemplo`

- Perfil: SubTypeGroup enxuto com poucos subtypes e foco em equivalencias nominais simples.
- Uso operacional: boa referencia para grupos de subtype pequenos e declarativos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="e058c0a2-a969-478b-9f81-77cf1202d227" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2024-10-07T00:25:35.0000000Z" checksum="b43b48a724160626fffcf54236c09d27" fullyQualifiedName="EntidadeProcessoEmpresaExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ac55b810-d079-4bc2-af29-2625936bb8d0" name="EntidadeProcessoEmpresaExemplo" type="87313f43-5eb2-41d7-9b8c-e8d9f5bf9588" description="Entidade Processo Empresa Exemplo" parent="Processos" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="74203da2-41b1-402c-0001-d8d564a2c2fa">
    <Subtype guid="3a50f42a-458a-4cce-bd6f-40e9cdadf076">
      <Name>EntidadeProcessoEmpresaExemploId</Name>
      <Supertype guid="5668cdba-5e23-4a6c-80b3-ef2a2a97ce24">EntidadeEmpresaId</Supertype>
    </Subtype>
    <Subtype guid="27da01a9-97b6-4873-85d2-cd1863af1429">
      <Name>EntidadeProcessoEmpresaExemploTotalDeAnimaisEmRegistroBaseDeveBaterComTotalDeSuasRegistros</Name>
      <Supertype guid="faecb545-ec39-4194-896a-88becd5abf73">EntidadeEmpresaRegraQuantidade</Supertype>
    </Subtype>
    <Subtype guid="88122744-548c-4148-b52c-206954dc8018">
      <Name>EntidadeProcessoEmpresaExemploRegraDestinoNotaRegistroBase</Name>
      <Supertype guid="7627fe2e-8041-4ee5-892f-024e49efbeef">EntidadeEmpresaRegraDestinatarioNota</Supertype>
    </Subtype>
    <Subtype guid="9af5a4ab-fd5b-414c-b7db-99ee42abdcab">
      <Name>EntidadeProcessoEmpresaExemploRegraDestinoDocumento</Name>
      <Supertype guid="bd5e04ed-c996-4523-8088-110780fe1861">EntidadeEmpresaRegraDestinatarioAbate</Supertype>
    </Subtype>
    <Subtype guid="5da64b87-4aac-4487-8c04-eea8b3ea4fc9">
      <Name>EntidadeProcessoEmpresaExemploSiglaServicoRegulador</Name>
      <Supertype guid="1c047235-db58-46fa-8ede-6687bc121fe6">EntidadeEmpresaSiglaServico</Supertype>
    </Subtype>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>EntidadeProcessoEmpresaExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

### Molde sanitizado de SubTypeGroup 2 - `ProcessoRegistroItemExemplo`

- Perfil: SubTypeGroup mais denso, com varios subtypes encadeando nomes de entidade, parceiro e dados complementares.
- Uso operacional: boa referencia para grupos de subtype maiores, com varias chaves e nomes derivados.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="e058c0a2-a969-478b-9f81-77cf1202d227" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-02-03T09:57:23.0000000Z" checksum="37282ebb9397103f8b7023648fa4ec5b" fullyQualifiedName="ProcessoRegistroItemExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="e595a90f-3320-4292-bb5f-d88f6cebecfb" name="ProcessoRegistroItemExemplo" type="87313f43-5eb2-41d7-9b8c-e8d9f5bf9588" description="Processo Compra Item Exemplo" parent="Processos" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="74203da2-41b1-402c-0001-d8d564a2c2fa">
    <Subtype guid="136730e0-5e9c-42ea-a3a0-40c4c598945c">
      <Name>ProcessoRegistroItemExemploEmpresaId</Name>
      <Supertype guid="e612571c-8abc-49d4-ae77-e34a3dade15d">RegistroItemEmpresaId</Supertype>
    </Subtype>
    <Subtype guid="883cab39-f6a4-48e4-9830-3361cc323dfb">
      <Name>ProcessoRegistroItemExemploId</Name>
      <Supertype guid="813c8384-4a41-48df-a5f3-ce518b1a8882">RegistroItemId</Supertype>
    </Subtype>
    <Subtype guid="51875e8b-0ba0-420e-a91e-0836eb2ed28f">
      <Name>ProcessoRegistroItemExemploDataProcesso</Name>
      <Supertype guid="89587d85-1590-4d2e-b701-3dec2418ea37">RegistroItemDataProcesso</Supertype>
    </Subtype>
    <Subtype guid="7a3c0c3c-c574-4b81-be62-402999ba0219">
      <Name>ProcessoRegistroItemExemploParceiroEmpresaId</Name>
      <Supertype guid="4743ca97-a219-4644-bb2e-44cc660a5f98">RegistroItemParceiroEmpresaId</Supertype>
    </Subtype>
    <Subtype guid="47cc16d4-5bf6-42c0-9c67-866775083a80">
      <Name>ProcessoRegistroItemExemploParceiroId</Name>
      <Supertype guid="e03e95ce-7e88-422e-83b6-b76f20316f8a">RegistroItemParceiroId</Supertype>
    </Subtype>
    <Subtype guid="a4f15a63-5aba-401d-af15-ca0b7499afff">
      <Name>ProcessoRegistroItemExemploParceiroNome</Name>
      <Supertype guid="aa07a9c5-b6eb-4141-9717-2db5b17f656c">RegistroItemParceiroNome</Supertype>
    </Subtype>
    <Subtype guid="d147b60e-4a1c-4567-a05b-1b520b5188b9">
      <Name>ProcessoRegistroItemExemploParceiroRazao</Name>
      <Supertype guid="a9ddfa43-f5f1-4cdc-9272-71bfe99be547">RegistroItemParceiroRazao</Supertype>
    </Subtype>
    <Subtype guid="7fa2112d-69cb-4583-b4b2-2eaf4ab3c868">
      <Name>ProcessoRegistroItemExemploParceiroPrincipalDocumentoId</Name>
      <Supertype guid="a8e2757b-48dd-4dd6-ab63-cf4afaedb190">RegistroItemParceiroDocumentoId</Supertype>
    </Subtype>
    <Subtype guid="75c9f57d-5388-4bce-bc44-844fe532a220">
      <Name>ProcessoRegistroItemExemploParceiroTipoContribuinte</Name>
      <Supertype guid="c9718595-0328-4439-bf54-9ff1c9077a96">RegistroItemParceiroTipoContribuinte</Supertype>
    </Subtype>
    <Subtype guid="d816cafc-0c47-4dc9-8a94-0cf33a71c2a8">
      <Name>ProcessoRegistroItemExemploParceiroPrincipalEnderecosId</Name>
      <Supertype guid="45022f34-f0c7-4151-b5fa-e60eeedf2d1b">RegistroItemParceiroEnderecoId</Supertype>
    </Subtype>
    <Subtype guid="acec979c-7a22-4ba9-b94b-a3839884365b">
      <Name>ProcessoRegistroItemExemploParceiroPrincipalUfId</Name>
      <Supertype guid="5899b6e3-eae9-47bd-911e-b6f0a99bdb46">RegistroItemParceiroUfId</Supertype>
    </Subtype>
    <Subtype guid="38a0a27c-86b6-4f5d-99ce-73371e4eb376">
      <Name>ProcessoRegistroItemExemploParceiroEndereco</Name>
      <Supertype guid="696457e2-160b-40a7-91c1-828a81e5005a">RegistroItemParceiroMapaEndereco</Supertype>
    </Subtype>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ProcessoRegistroItemExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```



## Moldes sanitizados completos de ThemeClass

### Molde sanitizado de ThemeClass 1 - `BotoesAcaoExemplo`

- Perfil: ThemeClass raiz simples, com marcador web e tipo interno de classe visual.
- Uso operacional: boa referencia para classes tematicas base sem cadeia longa de derivacao.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="abd2de3e-1c96-5681-b52b-bbe33c0dca49" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-04-10T14:23:17.0000000Z" checksum="2ef0f3b954ab655aefa1a5f9af5100e0" fullyQualifiedName="BotoesAcaoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2d749abc-7cbe-5cd1-b251-f1b289e851ef" name="BotoesAcaoExemplo" type="d4876646-98dd-419b-8c1c-896f83c48368" description="Botoes Acao Exemplo" parent="BotaoBaseExemplo" parentType="d4876646-98dd-419b-8c1c-896f83c48368">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>BotoesAcaoExemplo</Value>
    </Property>
    <Property>
      <Name>ThemeElementThemeTypes</Name>
      <Value>idWeb</Value>
    </Property>
    <Property>
      <Name>ThemeElementInternalType</Name>
      <Value>GxClass</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de ThemeClass 2 - `BotoesAcaoHoverExemplo`

- Perfil: ThemeClass derivada, herdando de outra classe visual do mesmo tipo.
- Uso operacional: boa referencia para estados visuais ou variantes que preservam a mesma assinatura de propriedades.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="2d749abc-7cbe-5cd1-b251-f1b289e851ef" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-03-05T05:44:22.0000000Z" checksum="b99af3293f67839c80125bcf62ad7c05" fullyQualifiedName="BotoesAcaoHoverExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="ef7af9e8-a021-4745-befb-1edded115e19" name="BotoesAcaoHoverExemplo" type="d4876646-98dd-419b-8c1c-896f83c48368" description="Botoes Acao Hover Exemplo" parent="BotoesAcaoExemplo" parentType="d4876646-98dd-419b-8c1c-896f83c48368">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>BotoesAcaoHoverExemplo</Value>
    </Property>
    <Property>
      <Name>ThemeElementThemeTypes</Name>
      <Value>idWeb</Value>
    </Property>
    <Property>
      <Name>ThemeElementInternalType</Name>
      <Value>GxClass</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de Image

### Molde sanitizado de Image 1 - `AcaoCancelarExemplo`

- Perfil: Image simples com um unico item referenciado a tema e caminho original sanitizado.
- Uso operacional: boa referencia para icones pontuais e imagens pequenas com um unico recurso embutido.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-01-28T23:24:21.0000000Z" checksum="da2989de4847257741d0fecb8cb7d90b" fullyQualifiedName="AcaoCancelarExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ec7bc09c-00fb-486b-9566-4b67fdc76464" name="AcaoCancelarExemplo" type="9fb193d9-64a4-4d30-b129-ff7c76830f7e" description="Acao Cancelar Exemplo">
  <Part type="36f350de-f768-425f-ac20-773749f331bf">
    <Images>
      <ImageItem>
        <Image name="CancelarExemplo.png" description="CancelarExemplo.png">
          <Data>
            <base64Binary>
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMBAMAAACkW0HUAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3Cc
ulE8AAAAGFBMVEW4BUW4BUW4BUW4BUW4BUW4BUW4BUX///+GCYqeAAAAB3RSTlMAqT9C60FAQxIVCgAAAAFiS0dEBxZhiOsAAABFSURBVAjXYxBiAAJFBhMF
BgYmVwZmJwYGlQAGIBfIYQByQRwgF8RhYEhxApFsziEKII4BqxOIw8AA5KYYMDAAucIg+UAAJ4MHj0vqGQkAAAAldEVYdGRhdGU6Y3JlYXRlADIwMTUtMDct
MDlUMTU6MDg6MTgrMDA6MDDKB3HyAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDE1LTA3LTA5VDE1OjA4OjE4KzAwOjAwu1rJTgAAAABJRU5ErkJggg==
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>CancelarExemplo.png</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>CancelarExemplo.png</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>c804fdbd-7c0b-440d-8527-4316c92649a6-7</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>ImageOriginalFullPath</Name>
            <Value>C:\\SANITIZED\\Assets\\ImagemExemplo.png</Value>
          </Property>
        </Properties>
        <ThemeReference>c804fdbd-7c0b-440d-8527-4316c92649a6-TemaExemplo</ThemeReference>
      </ImageItem>
    </Images>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>AcaoCancelarExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Image 2 - `AcaoExcluirExemplo`

- Perfil: Image com varios `ImageItem`, misturando referencias com e sem tema.
- Uso operacional: boa referencia para imagens com multiplas variantes do mesmo ativo visual.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-01-28T23:24:16.0000000Z" checksum="1a5af35131c431e837e5ec7110ab9612" fullyQualifiedName="AcaoExcluirExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="7695fe89-52c9-4b7e-871e-0e11548f823e" name="AcaoExcluirExemplo" type="9fb193d9-64a4-4d30-b129-ff7c76830f7e" description="Acao Excluir Exemplo">
  <Part type="36f350de-f768-425f-ac20-773749f331bf">
    <Images>
      <ImageItem>
        <Image name="AcaoExcluirExemplo.gif" description="Acao Excluir Exemplo.gif">
          <Data>
            <base64Binary>
R0lGODlhEAAQAMQYAMQzM8AyMn4hIXYfH4EiInEeHnMeHnQeHre3t9XV1eTk5MTExLkwMIgkJL29va8uLszMzMg0NHkgIKcrK58pKW8dHZcnJ78yMv///wAA
AAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAABgALAAAAAAQABAAAAVaICaOZGmeaFWVqmlcVzEWsFEelhUM2BDkB5OEQgFIAEQJSjCZNAITAUpEaDAYhCn18Yhk
p8wJgCk9DYvHpAmn4/mApVdsVjO1SHeRIgFZOBCACA4LEAkKWichADs=
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>AcaoExcluirExemplo.gif</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>Acao Excluir Exemplo.gif</Value>
          </Property>
          <Property>
            <Name>IsExternalImage</Name>
            <Value>False</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
        </Properties>
      </ImageItem>
      <ImageItem>
        <Image name="AcaoExcluirExemplo.png" description="Acao Excluir Exemplo.png">
          <Data>
            <base64Binary>
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAK8AAACvABQqw0mAAAABh0RVh0U29mdHdhcmUAQWRv
YmUgRmlyZXdvcmtzT7MfTgAAAjdJREFUOI2lkktsTHEUxn/nf+/M6IjUq4JUyHgsBOl4NEKiRCRExcaCSEREIhZdaMOKVnVJJVZ0x9LCRnRjQS0Qj4QwoR4x
iEZKlYiOeztz57PoDNPBQpzkLP7f+c53Xn+TxP+Yq3y83rBy26umdNffyNmm9MHs+hWHxoGSkMTzTY07Mw0L9WjxPD1ds/RKGS97/7qGzsdL5+vxkpT6m9Ld
utFjkjBJPNmyNpl7NzhSGAkA8OIeiam1vctuPWoGyKxLdwbDX9sLuVJ8QoLYpGRjw53MPZPE1eRES8ycchJnbQAUi7iYT3Ja7UUX9zPfh750jeZCzLly233k
o+amt+9HrHKJVxfM6ZbUaoCKwk/4OM8jzAU45xBg0PcxEd+0+8mrAoBVX+FySaRUCQnMGYwlXxuuqdm8N/MiX+b/JgBwcX79bcTqKvhzcnrdjG13HxQqQVdF
4kKq/nhY1KpQosqnDA99uFTNH9dBT6q+06T2nycukyoShPUeuPmymdkTfgmcWTQPy+ePIzoqk83sisHTonS4UgSj13x/R8uLN4EDiMySgdQRIMoeor6h2uT2
luy7I6PG6e8VsUDaGkTRsp87aH2Wzcnz94UYoSDErrekl2888fB5EeBwdqAtj50KBaEg77xzu1Jz7wOYN9bU5AiiPbPqWic5W3V+8NPRkUJU8CABEEEEfNk/
q+5YzDn/7MBgGzAq6atJwjfzgFhBChibvcYDv3LsCCTpWyke9yAqSNEf/8G/2A9gpCdJVtr5yQAAAABJRU5ErkJggg==
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>AcaoExcluirExemplo.png</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>Acao Excluir Exemplo.png</Value>
          </Property>
          <Property>
            <Name>IsExternalImage</Name>
            <Value>False</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>c804fdbd-7c0b-440d-8527-4316c92649a6-1</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>ImageOriginalFullPath</Name>
            <Value>C:\\SANITIZED\\Assets\\ImagemExemplo.png</Value>
          </Property>
        </Properties>
        <ThemeReference>c804fdbd-7c0b-440d-8527-4316c92649a6-TemaExemplo</ThemeReference>
      </ImageItem>
      <ImageItem>
        <Image name="editdeleteM.png" description="Acao Excluir Exemplo.gif">
          <Data>
            <base64Binary>
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
SUVORK5CYII=
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>editdeleteM.png</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>Acao Excluir Exemplo.gif</Value>
          </Property>
          <Property>
            <Name>IsExternalImage</Name>
            <Value>False</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
        </Properties>
      </ImageItem>
      <ImageItem>
        <Image name="ExcluirExemplo.png" description="ExcluirExemplo.png">
          <Data>
            <base64Binary>
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA2hpVFh0WE1MOmNvbS5hZG9i
ZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6
bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpS
REYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIg
eG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5
cGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRp
ZDoxNDMxREE2MEUwMjE2ODExODIyQUI5QkRBMkI3MTQ0MCIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo0OTdBM0Y3M0E4NzkxMUUzOENFQkM4Qzk2MzBB
MkRBRCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo0OTdBM0Y3MkE4NzkxMUUzOENFQkM4Qzk2MzBBMkRBRCIgeG1wOkNyZWF0b3JUb29sPSJBZG9iZSBQ
aG90b3Nob3AgQ1M2IChNYWNpbnRvc2gpIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6RTYxMzM1RDgxRTIwNjgxMThB
NkRCMUM2QTNGM0FGRDciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6MTQzMURBNjBFMDIxNjgxMTgyMkFCOUJEQTJCNzE0NDAiLz4gPC9yZGY6RGVzY3Jp
cHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz6k7EfoAAAAnklEQVR42sSTMQqAMAxFq4KXceqip3bVzaOoCIIIgjeo
X2wl1MQMDgbe0JD/oA1NnHPmS6XmY1FBB2ZgX+ZLsIDm7pxX8Mzuqg1Y0g+UYPczQ+jTAevDnISGV1BwAklSSWFOwEnEsCSIJWL4RFpjDjJyznzvWYw1vvP2
th0tXCjbMVpYXTEVLMqDUcnICVrQS69NJBOoQy/5/TceAgwAjxchrJKTLJQAAAAASUVORK5CYII=
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>ExcluirExemplo.png</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>ExcluirExemplo.png</Value>
          </Property>
          <Property>
            <Name>IsExternalImage</Name>
            <Value>False</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>ImageOriginalFullPath</Name>
            <Value>C:\\SANITIZED\\Assets\\ImagemExemplo.png</Value>
          </Property>
        </Properties>
      </ImageItem>
      <ImageItem>
        <Image name="RemoverExemplo.png" description="RemoverExemplo.png">
          <Data>
            <base64Binary>
iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAQAAACROWYpAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3Cc
ulE8AAAAAmJLR0QA/4ePzL8AAAJsSURBVDjLjZW9T1NRGMZ/vShBYigECm2iCZAiwZiQqA1Rk8bF1joZBiZdykTQxDhoZKCrwAD/BYSFCRNxcYCQgLAYo6EN
C0s/INciid5Y8zjQlt5zy8dzl3vPeX553/uec97jkzD1l498YpNdfgKt9BLhEXEue5xyy1ZKnYpqSqvKypGjrFY1ragCSsl2m93wvEJKKq16SiupkObrwyWN
qUcbOksb6tGYSiZc0rAeqqDzVFBUwxW8Ar9QTM65qCQ5imu8Fl5Qvw4vhErSL/VroQLbCnn+Na2wKD9hTwk3FJItWcAcCSLGCi6RqLA8Zd6YjfCEOfDJ4Tpr
hKsTUwB85g+PyyMn72+rrgwP2LNYYaAGBZsJDhhkCLv8DDLEARPYNa4wA6z49JJrvHEl1cVXOo1E89wi7xqZZs9im/uGsZ080ITDe97h0ATk6TBc99i22KHP
GA6SA1o4BOCQFiBH0HDdIG1RpK1uZDe8T7vhaqNo4VUXOcBPsQbOeqoAWPhdVQQIsO+JXCBguGz8Fn2kjeEOsh4464F36LO4w7on7UINXMQPFOgyXOvctoix
7CmYN3LOU7APxCxifCNjLJX3n/eNyBl+EEdSSqOuM5NXs+cYNivn+h5VSroEvOImX7hbk3aJ165IOUquHbbFMt/BAlqZ5TlHNcu3RGP1WNjYNLLEyY444hmz
tFJtveNKXLgNJSptyFdu+v8Y4TeLXOVsHTHCFRZpOE7xWA0s0k2ErTPRLSJ0V1Awm35QSWXqpptRUsHTmv6xbE0qoKhmtFa9btY0o6gCmjSvG98pF90Km+xi
A230EiFGjEbT+B+hOOps9fyhsgAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAxNS0wNy0wM1QxNDozODozNCswMDowMP9FGVMAAAAldEVYdGRhdGU6bW9kaWZ5ADIw
MTUtMDctMDNUMTQ6Mzg6MzQrMDA6MDCOGKHvAAAAAElFTkSuQmCC
</base64Binary>
          </Data>
        </Image>
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>RemoverExemplo.png</Value>
          </Property>
          <Property>
            <Name>Description</Name>
            <Value>RemoverExemplo.png</Value>
          </Property>
          <Property>
            <Name>IsExternalImage</Name>
            <Value>False</Value>
          </Property>
          <Property>
            <Name>ThemeReference</Name>
            <Value>c804fdbd-7c0b-440d-8527-4316c92649a6-7</Value>
          </Property>
          <Property>
            <Name>LanguageReference</Name>
            <Value>NULL</Value>
          </Property>
          <Property>
            <Name>ImageOriginalFullPath</Name>
            <Value>C:\\SANITIZED\\Assets\\ImagemExemplo.png</Value>
          </Property>
        </Properties>
        <ThemeReference>c804fdbd-7c0b-440d-8527-4316c92649a6-TemaExemplo</ThemeReference>
      </ImageItem>
    </Images>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>True</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>AcaoExcluirExemplo</Value>
    </Property>
    <Property>
      <Name>DefaultImage</Name>
      <Value>,,</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```



## Moldes sanitizados completos de Table com Indexes embutidos

### Molde sanitizado de Table 1 - `CadastroModeloExemplo`

- Perfil: Table enxuta, com chave simples, um indice unico e poucos indices auxiliares embutidos.
- Uso operacional: boa referencia para tabelas pequenas com ordenacao basica e um indice descendente de apoio.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-09-28T12:19:09.0000000Z" checksum="2584cdc993d184b2df1c342335f093f4" fullyQualifiedName="CadastroModeloExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="a8113c94-a85c-47a7-a55c-798e19e16354" name="CadastroModeloExemplo" type="857ca50e-7905-0000-0007-c5d9ff2975ec" description="Cadastro Modelo Exemplo">
  <Part type="00000000-0000-0000-0002-000000000004">
    <Key>
      <Item guid="25fd8782-c70b-477a-beb3-8f61f15cafac">CadastroModeloExemploId</Item>
    </Key>
    <Properties />
  </Part>
  <Part type="a5c0e770-560d-0001-0001-7fe71c260de3">
    <Indexes>
      <TableIndex>
        <Index Type="Unique" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2021-12-25T04:06:21.0000000Z" checksum="be575917c1e8cc588b26f7399062ab90" fullyQualifiedName="ICadastroModeloExemploPK" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6a639120-0521-48ca-b127-74b2a3d611ff" name="ICadastroModeloExemploPK" type="9e750647-3679-0000-0100-2529de263960" description="ICadastro Modelo Exemplo PK">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">CadastroModeloExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>ICadastroModeloExemploPK</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2021-12-25T04:06:21.0000000Z" checksum="8371bc8d6a80e4970855604882e87a0f" fullyQualifiedName="UCadastroModeloExemploIdDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="a1bb2e2f-22bb-40c6-9c97-1494f3921e9c" name="UCadastroModeloExemploIdDescendente" type="9e750647-3679-0000-0100-2529de263960" description="UCadastro Modelo Exemplo Id Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Descending">CadastroModeloExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>UCadastroModeloExemploIdDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2021-12-25T04:06:21.0000000Z" checksum="51b7e5a2cb9e3a49b1e54bb3f9ef7ac9" fullyQualifiedName="ICadastroModeloExemploUltimaRevisaoUsuario" moduleGuid="00000000-0000-0000-0000-000000000000" guid="4f646fed-c8c4-48d4-ba68-897095940226" name="ICadastroModeloExemploUltimaRevisaoUsuario" type="9e750647-3679-0000-0100-2529de263960" description="ICadastro Modelo Exemplo Ultima Revisao Usuario">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">CadastroModeloExemploUltimaRevisaoUsuarioId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>ICadastroModeloExemploUltimaRevisaoUsuario</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
    </Indexes>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>CadastroModeloExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Cadastro Modelo Exemplo</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Table 2 - `RegistroBaseExemplo`

- Perfil: Index denso, com chave composta e varios `TableIndex` automaticos e de usuario.
- Uso operacional: boa referencia para estruturas com muitos indices derivados e combinacoes de ordem crescente/descendente.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-03-22T12:57:46.0000000Z" checksum="2c02a143c62b21b5d16952bd6d4caaca" fullyQualifiedName="RegistroBaseExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="82d08ad9-d6c9-4bf0-bcaa-65f016c35569" name="RegistroBaseExemplo" type="857ca50e-7905-0000-0007-c5d9ff2975ec" description="RegistroBaseExemplo">
  <Part type="00000000-0000-0000-0002-000000000004">
    <Key>
      <Item guid="2135d656-21ac-49ae-9e5c-6a6dc6d59239">RegistroBaseExemploEmpresaId</Item>
      <Item guid="9a687eb2-9094-4ae2-9b58-aeb873203ed3">RegistroBaseExemploId</Item>
    </Key>
    <Properties />
  </Part>
  <Part type="a5c0e770-560d-0001-0001-7fe71c260de3">
    <Indexes>
      <TableIndex>
        <Index Type="Unique" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="1236216bdc4adaed69f269062be11a6d" fullyQualifiedName="IRegistroBaseExemploPK" moduleGuid="00000000-0000-0000-0000-000000000000" guid="57af3161-b819-4f17-8b4f-871b05f150a1" name="IRegistroBaseExemploPK" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo PK">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploPK</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="f381b5caefe2c1a317247864ef99271a" fullyQualifiedName="IRegistroBaseExemploClassificacaoTipo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="811ded12-9d79-415d-93fd-ed8f31acfe83" name="IRegistroBaseExemploClassificacaoTipo" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Classificacao Tipo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploClassificacaoTipoEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploClassificacaoTipoId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploClassificacaoTipo</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="103e69ca0edee88e341c4890052ff5e8" fullyQualifiedName="IRegistroBaseExemploParceiro" moduleGuid="00000000-0000-0000-0000-000000000000" guid="e66b21f9-c4ab-46c5-b7f6-8ce0a05a5edf" name="IRegistroBaseExemploParceiro" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Parceiro">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploParceiroEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploParceiro</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="d74efbbcba5b464067b8e3338c469536" fullyQualifiedName="IRegistroBaseExemploGrupoA" moduleGuid="00000000-0000-0000-0000-000000000000" guid="8f889307-839f-4525-bc3d-2163dea0328f" name="IRegistroBaseExemploGrupoA" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Grupo A">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploGrupoAEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploGrupoAId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploGrupoA</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="5b4e10ec2ee4889e3e732c779be4c95c" fullyQualifiedName="IRegistroBaseExemploProcessoOrdem" moduleGuid="00000000-0000-0000-0000-000000000000" guid="75a2d805-45fe-4008-ad3d-53b3db5a1eb9" name="IRegistroBaseExemploProcessoOrdem" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Processo Ordem">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploProcessoOrdemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploProcessoOrdemId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploProcessoOrdem</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="6a6b876fc990bec5e147d4560fd10755" fullyQualifiedName="IRegistroBaseExemploEmpresa" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6a3e1e95-d4bc-43e8-b0d9-89c7a5f06eb2" name="IRegistroBaseExemploEmpresa" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Empresa">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploEmpresa</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="6bc7ce7e233b4a2abe65f52765d2bf84" fullyQualifiedName="IRegistroBaseExemploRegistroBaseExemploParaAbate" moduleGuid="00000000-0000-0000-0000-000000000000" guid="0ca977f1-e761-41d8-be32-1485062a9245" name="IRegistroBaseExemploRegistroBaseExemploParaAbate" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo RegistroBaseExemplo Para Processo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploRegistroBaseExemploParaAbate</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="45129fbd516e664245969240a4bfba9b" fullyQualifiedName="IRegistroBaseExemploLocalBase" moduleGuid="00000000-0000-0000-0000-000000000000" guid="19ac6f5d-0149-4e18-8b25-64fe4e001866" name="IRegistroBaseExemploLocalBase" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Local Base">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploLocalBaseEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploLocalBaseId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploLocalBase</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="06dc81be242add07034266c28591542c" fullyQualifiedName="IRegistroBaseExemploCompraItem" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7a71ebff-91fe-44d6-9625-a7ea688943ad" name="IRegistroBaseExemploCompraItem" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Compra Item">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCompraItemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCompraItemId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploCompraItem</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="f54919dfc3f7b3810a8106b0b69c5874" fullyQualifiedName="URegistroBaseExemploDataProcessoDescendenteMaisNumeroControle" moduleGuid="00000000-0000-0000-0000-000000000000" guid="1fe056bf-e620-42be-bd2a-16ea805d0a27" name="URegistroBaseExemploDataProcessoDescendenteMaisNumeroControle" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Data Processo Descendente Mais Numero Serie">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Descending">RegistroBaseExemploDataProcesso</Member>
              <Member Order="Ascending">RegistroBaseExemploNumeroControle</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploDataProcessoDescendenteMaisNumeroControle</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="aa6c9529e6b99d4c47db369dba73d102" fullyQualifiedName="URegistroBaseExemploIdDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="1fc78f59-17b7-48b4-94c7-dbe065c0344a" name="URegistroBaseExemploIdDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Id Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Descending">RegistroBaseExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploIdDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="14e430e335d8e8f947ea6a961d9bfa2a" fullyQualifiedName="URegistroBaseExemploCompraItemRegistroBaseExemploParaAbatePesoDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6cf7590a-bad6-467b-ac31-258bc70dfeba" name="URegistroBaseExemploCompraItemRegistroBaseExemploParaAbatePesoDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Compra Item RegistroBaseExemplo Para Processo Peso Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCompraItemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCompraItemId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
              <Member Order="Descending">RegistroBaseExemploPeso</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploCompraItemRegistroBaseExemploParaAbatePesoDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="73e51bd537287a6c8ebad47e60316b0e" fullyQualifiedName="IRegistroBaseExemploAbatePrestadoValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2584071d-d819-46e8-b91f-87109d50b5e3" name="IRegistroBaseExemploAbatePrestadoValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Servico Prestado Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploAbatePrestadoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploAbatePrestadoValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="28347480611903a30792c32ee2b9853f" fullyQualifiedName="IRegistroBaseExemploFretePrestadoValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="cb23b419-5c73-408f-9fad-e37d877ed44f" name="IRegistroBaseExemploFretePrestadoValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Frete Prestado Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploFretePrestadoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploFretePrestadoValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="8030c82be87003dbf55a22840d17e889" fullyQualifiedName="IRegistroBaseExemploPeleCompradaValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2fffe9c7-9bab-4e8a-a699-ee0e5720d7b2" name="IRegistroBaseExemploPeleCompradaValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Pele Comprada Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploPeleCompradaValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploPeleCompradaValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="4a2722acd92374c36a644ec77f34d53b" fullyQualifiedName="IRegistroBaseExemploConjuntoViscerasComprado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="838be330-4456-446f-9c54-a12a6285def6" name="IRegistroBaseExemploConjuntoViscerasComprado" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Conjunto Visceras Comprado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploConjuntoViscerasCompradoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploConjuntoViscerasComprado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="b1e777f1aaf9ea71c5d674e7582fc016" fullyQualifiedName="URegistroBaseExemploDataProcessoRegistroBaseExemploParaAbateCodigoParceiroId" moduleGuid="00000000-0000-0000-0000-000000000000" guid="c1702177-088e-4482-b1d3-9ec5e35d3a7f" name="URegistroBaseExemploDataProcessoRegistroBaseExemploParaAbateCodigoParceiroId" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Data Processo RegistroBaseExemplo Para Processo Codigo Parceiro Id">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploDataProcesso</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploDataProcessoRegistroBaseExemploParaAbateCodigoParceiroId</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="c7e54afe25a85c7bfd14209f129fe838" fullyQualifiedName="URegistroBaseExemploRegistroBaseExemploParaAbateCodigoParceiroIdDataProcesso" moduleGuid="00000000-0000-0000-0000-000000000000" guid="8cc6c7c1-7c86-48be-8a2b-97575bcc3745" name="URegistroBaseExemploRegistroBaseExemploParaAbateCodigoParceiroIdDataProcesso" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo RegistroBaseExemplo Para Processo Codigo Parceiro Id Data Processo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
              <Member Order="Ascending">RegistroBaseExemploDataProcesso</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploRegistroBaseExemploParaAbateCodigoParceiroIdDataProcesso</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="916b78fa8107336acad48977d096e686" fullyQualifiedName="URegistroBaseExemploCGEmp_CGId_Canc_AACod_AAEmp_AAnaCompra_CGPeso_Tolerado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="59ebd83e-4332-4006-a47f-569b49e68821" name="URegistroBaseExemploCGEmp_CGId_Canc_AACod_AAEmp_AAnaCompra_CGPeso_Tolerado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo CGEmp_CGId_Canc_AACod_AAEmp_AAna Compra_CGPeso_Tolerado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCompraItemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCompraItemId</Member>
              <Member Order="Ascending">RegistroBaseExemploCancelado</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateEmUsoNaCompra</Member>
              <Member Order="Ascending">RegistroBaseExemploClassificacaoTipoId</Member>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploId</Member>
              <Member Order="Ascending">RegistroBaseExemploPeso</Member>
              <Member Order="Ascending">RegistroBaseExemploToleradoNaCompra</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploCGEmp_CGId_Canc_AACod_AAEmp_AAnaCompra_CGPeso_Tolerado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="85b29ea997a09ba19d7ec7467d4b4e7b" fullyQualifiedName="IRegistroBaseExemploSubgrupoA" moduleGuid="00000000-0000-0000-0000-000000000000" guid="851d0268-c94e-40a6-97bf-7e8d3134ec24" name="IRegistroBaseExemploSubgrupoA" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Subgrupo A">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploSubgrupoAValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploSubgrupoA</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="fb76a70438b34401e79f6b6f093f50f2" fullyQualifiedName="URegistroBaseExemploProcessoOrdemMaisRegistroBaseExemploIdDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="67e7d7db-965b-48a4-9d88-afa0c993abae" name="URegistroBaseExemploProcessoOrdemMaisRegistroBaseExemploIdDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Processo Ordem Mais RegistroBaseExemplo Id Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploProcessoOrdemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploProcessoOrdemId</Member>
              <Member Order="Descending">RegistroBaseExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploProcessoOrdemMaisRegistroBaseExemploIdDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="8119957896bd159d829e7afa1877d6bc" fullyQualifiedName="URegistroBaseExemploCodigoOrigemUnicoMaisEmpresaIdMaisNumeroControle" moduleGuid="00000000-0000-0000-0000-000000000000" guid="25318cc8-7f0c-41bf-8757-60da5410bf3a" name="URegistroBaseExemploCodigoOrigemUnicoMaisEmpresaIdMaisNumeroControle" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Codigo Origem Unico Mais Empresa Id Mais Numero Serie">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCodigoOrigemUnico</Member>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploNumeroControle</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploCodigoOrigemUnicoMaisEmpresaIdMaisNumeroControle</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="b21e435a6e63ae0dea69d7b81da36afb" fullyQualifiedName="URegistroBaseExemploEmpresaParceiroDataProcesso" moduleGuid="00000000-0000-0000-0000-000000000000" guid="dedbccd9-fc66-4749-9d72-d1ce8d4d1444" name="URegistroBaseExemploEmpresaParceiroDataProcesso" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Parceiro Data Processo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
              <Member Order="Ascending">RegistroBaseExemploDataProcesso</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaParceiroDataProcesso</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="2c151b7d4662c9737ad6f06cf9cc732f" fullyQualifiedName="URegistroBaseExemploRegistroBaseExemploParaAbateCodidoMaisDataProcesso" moduleGuid="00000000-0000-0000-0000-000000000000" guid="1a91c07f-be02-409b-b155-59b16911ae6d" name="URegistroBaseExemploRegistroBaseExemploParaAbateCodidoMaisDataProcesso" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo RegistroBaseExemplo Para Processo Codido Mais Data Processo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploRegistroBaseExemploParaAbateCodigo</Member>
              <Member Order="Ascending">RegistroBaseExemploDataProcesso</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploRegistroBaseExemploParaAbateCodidoMaisDataProcesso</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="776c51050fc952e7df72bcbfbd304aba" fullyQualifiedName="IRegistroBaseExemploConjuntoViscerasVendido" moduleGuid="00000000-0000-0000-0000-000000000000" guid="b13c3acf-7727-4443-afb1-d0faaaedf85d" name="IRegistroBaseExemploConjuntoViscerasVendido" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Conjunto Visceras Vendido">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploConjuntoViscerasVendidoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploConjuntoViscerasVendido</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="2228d3921c557e6b3db8ae12fc9c5897" fullyQualifiedName="IRegistroBaseExemploCooperado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2ae2bc31-d7bf-4dee-9a5d-ad1ddf65a076" name="IRegistroBaseExemploCooperado" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Cooperado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCooperadoEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCooperadoId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploCooperado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="be01045508d62d99e872bd8aa229fd24" fullyQualifiedName="URegistroBaseExemploEmpresaNumeroControleCancelado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7289e48d-3b98-489e-8e51-06ec0a3d8789" name="URegistroBaseExemploEmpresaNumeroControleCancelado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Numero Serie Cancelado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploNumeroControle</Member>
              <Member Order="Ascending">RegistroBaseExemploCancelado</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaNumeroControleCancelado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="735e790f59ddc5bc92e5062384843bdc" fullyQualifiedName="URegistroBaseExemploEmpresaProcessoOrdemCooperado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2af006ef-8896-4068-9dc3-7c67c6211e19" name="URegistroBaseExemploEmpresaProcessoOrdemCooperado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Processo Ordem Cooperado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploProcessoOrdemId</Member>
              <Member Order="Ascending">RegistroBaseExemploCooperadoId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaProcessoOrdemCooperado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="23a06bfac183f9c34b3f44b90e9673a1" fullyQualifiedName="URegistroBaseExemploEmpresaParceiroCooperado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="584c0cb9-35c6-4b67-962b-2edea20fcaa5" name="URegistroBaseExemploEmpresaParceiroCooperado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Parceiro Cooperado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
              <Member Order="Ascending">RegistroBaseExemploCooperadoId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaParceiroCooperado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="841f30e5f08ddbeba891c533a98422ad" fullyQualifiedName="IRegistroBaseExemploRefrigeracaoPrestadaValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="4b0f36bc-b2f3-4eb0-984b-e66da19a0542" name="IRegistroBaseExemploRefrigeracaoPrestadaValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Refrigeracao Prestada Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploRefrigeracaoPrestadaValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploRefrigeracaoPrestadaValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="fd9a0bb5a7cf17206800143e527d336c" fullyQualifiedName="IRegistroBaseExemploArmazenamentoPrestadoValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="04926593-5c0c-4ddd-b0c8-c5d37c05a7ea" name="IRegistroBaseExemploArmazenamentoPrestadoValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Armazenamento Prestado Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploArmazenamentoPrestadoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploArmazenamentoPrestadoValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="1e1231ed94947dfca5d19a125b3cfc20" fullyQualifiedName="URegistroBaseExemploEmpresaMaisGrupoA" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6e807d28-0a8c-4ce2-8ed2-c5356afbabd1" name="URegistroBaseExemploEmpresaMaisGrupoA" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Mais Grupo A">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploGrupoAId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaMaisGrupoA</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="8427084e89f2eb5926473ded223f2a6b" fullyQualifiedName="URegistroBaseExemploEmpMaisSeqDoDiaDescMaisNrSerieDescMaisIdDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="b64260f5-bdc7-4a56-b319-94864ac24df0" name="URegistroBaseExemploEmpMaisSeqDoDiaDescMaisNrSerieDescMaisIdDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Emp Mais Seq Do Dia Desc Mais Nr Serie Desc Mais Id Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Descending">RegistroBaseExemploSequenciaDoDia</Member>
              <Member Order="Descending">RegistroBaseExemploNumeroControle</Member>
              <Member Order="Descending">RegistroBaseExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpMaisSeqDoDiaDescMaisNrSerieDescMaisIdDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="9e165780556a03ceb19fc7f572369176" fullyQualifiedName="URegistroBaseExemploEmpresaIdMaisParceiroIdMaisCanceladoMaisDataProcesso" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2123feea-503e-4e78-8a70-79500b8cb946" name="URegistroBaseExemploEmpresaIdMaisParceiroIdMaisCanceladoMaisDataProcesso" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Id Mais Parceiro Id Mais Cancelado Mais Data Processo">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploParceiroId</Member>
              <Member Order="Ascending">RegistroBaseExemploCancelado</Member>
              <Member Order="Ascending">RegistroBaseExemploDataProcesso</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaIdMaisParceiroIdMaisCanceladoMaisDataProcesso</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="ec2cc3f4ee7571b788e56264370009b5" fullyQualifiedName="URegistroBaseExemploCompraItemMaisCancelado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="f71f7c15-5e4e-4057-9b34-d1a7e02e8994" name="URegistroBaseExemploCompraItemMaisCancelado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Compra Item Mais Cancelado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploCompraItemEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCompraItemId</Member>
              <Member Order="Ascending">RegistroBaseExemploCancelado</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploCompraItemMaisCancelado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="1a9ca256528b1a074c4c2b2d9ae8ae29" fullyQualifiedName="URegistroBaseExemploEmpresaMaisCancelado" moduleGuid="00000000-0000-0000-0000-000000000000" guid="2ed367f7-c110-43da-8bb7-bc9274214ddf" name="URegistroBaseExemploEmpresaMaisCancelado" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Empresa Mais Cancelado">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploEmpresaId</Member>
              <Member Order="Ascending">RegistroBaseExemploCancelado</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploEmpresaMaisCancelado</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="52f24ab1b7b83cd50ad3983e4eddd85b" fullyQualifiedName="IRegistroBaseExemploRaboCompradoValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="935ca714-9c55-4d11-a16b-05aaf7363ccb" name="IRegistroBaseExemploRaboCompradoValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Rabo Comprado Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploRaboCompradoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploRaboCompradoValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="e888b5ff60e31abbdacfd56b0260752a" fullyQualifiedName="URegistroBaseExemploDataProcessoDescendenteMaisSequenciaDoDiaDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="8ac74c63-7797-425c-94e4-1fcc84ba55a9" name="URegistroBaseExemploDataProcessoDescendenteMaisSequenciaDoDiaDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Data Processo Descendente Mais Sequencia Do Dia Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Descending">RegistroBaseExemploDataProcesso</Member>
              <Member Order="Descending">RegistroBaseExemploSequenciaDoDia</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploDataProcessoDescendenteMaisSequenciaDoDiaDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="User" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="e13990225fed074737612ed50ad1b2b9" fullyQualifiedName="URegistroBaseExemploDataProcessoDescendenteMaisIdDescendente" moduleGuid="00000000-0000-0000-0000-000000000000" guid="8342ff82-2c7d-424e-ab49-6f029fcdc4a8" name="URegistroBaseExemploDataProcessoDescendenteMaisIdDescendente" type="9e750647-3679-0000-0100-2529de263960" description="URegistroBaseExemplo Data Processo Descendente Mais Id Descendente">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Descending">RegistroBaseExemploDataProcesso</Member>
              <Member Order="Descending">RegistroBaseExemploId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>URegistroBaseExemploDataProcessoDescendenteMaisIdDescendente</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="17cc926555649856c4e57304c95621be" fullyQualifiedName="IRegistroBaseExemploConjuntoSubprodutosCompradoValor" moduleGuid="00000000-0000-0000-0000-000000000000" guid="b6533850-36d6-4336-8c98-4206ecb5d3ba" name="IRegistroBaseExemploConjuntoSubprodutosCompradoValor" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Conjunto Subprodutos Comprado Valor">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploConjuntoSubprodutosCompradoValorId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploConjuntoSubprodutosCompradoValor</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="98db97e3f9edab4274813961d406e67b" fullyQualifiedName="IRegistroBaseExemploUltimaRevisaoUsuario" moduleGuid="00000000-0000-0000-0000-000000000000" guid="c771277d-2771-4f15-8d31-fd169dc07f50" name="IRegistroBaseExemploUltimaRevisaoUsuario" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Ultima Revisao Usuario">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploUltimaRevisaoUsuarioId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploUltimaRevisaoUsuario</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="7c3c3460e5f4ace653451b99c63c0912" fullyQualifiedName="IRegistroBaseExemploFaixaEtaria" moduleGuid="00000000-0000-0000-0000-000000000000" guid="f0b4226c-9851-4742-b8c6-c759dc62da2b" name="IRegistroBaseExemploFaixaEtaria" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Faixa Etaria">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploFaixaEtariaId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploFaixaEtaria</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
      <TableIndex>
        <Index Type="Duplicate" Source="Automatic" parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-11-10T17:41:27.0000000Z" checksum="22e6c4b810478f0791a7cdbaad734c5d" fullyQualifiedName="IRegistroBaseExemploSeloDeCertificacao" moduleGuid="00000000-0000-0000-0000-000000000000" guid="aaeae5bc-4d82-44b0-9b4c-db41fd58d27e" name="IRegistroBaseExemploSeloDeCertificacao" type="9e750647-3679-0000-0100-2529de263960" description="IRegistroBaseExemplo Selo De Certificacao">
          <Part type="62cfa789-c127-0001-0100-77676175e433">
            <Members>
              <Member Order="Ascending">RegistroBaseExemploSeloDeCertificacaoId</Member>
            </Members>
            <Properties />
          </Part>
          <Properties>
            <Property>
              <Name>Name</Name>
              <Value>IRegistroBaseExemploSeloDeCertificacao</Value>
            </Property>
          </Properties>
        </Index>
      </TableIndex>
    </Indexes>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>RegistroBaseExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>RegistroBaseExemplo</Value>
    </Property>
  </Properties>
</Object>
```



## Moldes sanitizados completos de ThemeColor

### Molde sanitizado de ThemeColor 1 - `CorAcaoExemplo`

- Perfil: ThemeColor raiz extremamente enxuto, sem `Part` internas adicionais.
- Uso operacional: boa referencia para entradas simples de paleta tematica.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-03-12T17:40:30.0000000Z" checksum="b17ddaa4991114c1378fcb07dc0c2475" fullyQualifiedName="CorAcaoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="ce3a249f-a6aa-4ab3-9a13-9663409d441b" name="CorAcaoExemplo" type="5592de59-d30a-499d-9100-a7006d3674f2" description="CorAcaoExemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>CorAcaoExemplo</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de ThemeColor 2 - `CorAlertaExemplo`

- Perfil: ThemeColor raiz paralela ao primeiro molde, mudando apenas identidade nominal.
- Uso operacional: boa referencia para duplicacao controlada de entradas de cor com mesma assinatura estrutural.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-03-21T15:49:40.0000000Z" checksum="0f7c966ebc90a770da7aaac3a5c86ed3" fullyQualifiedName="CorAlertaExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="08bbf1e9-a441-45a3-abeb-5288e07b0b76" name="CorAlertaExemplo" type="5592de59-d30a-499d-9100-a7006d3674f2" description="CorAlertaExemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>CorAlertaExemplo</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de Document

### Molde sanitizado de Document 1 - `DocumentoReferenciaExemplo`

- Perfil: Document enxuto, com um unico bloco `InnerHtml` curto e referencia textual simples.
- Uso operacional: boa referencia para documentos de anotacao, links ou lembretes tecnicos curtos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:23.0000000Z" checksum="" fullyQualifiedName="DocumentoReferenciaExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="b8f276b6-f342-4740-901a-94eda21fa7c4" name="DocumentoReferenciaExemplo" type="faeb588c-dcce-4dad-9af3-cdd11b961a32" description="Documento Referencia Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/tools/xsd-generator]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DocumentoReferenciaExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Document 2 - `DocumentoNotasExemplo`

- Perfil: Document mais rico, com HTML maior e varias anotacoes internas.
- Uso operacional: boa referencia para documentos de observacoes, instrucoes e listas de itens em HTML embutido.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-03-09T01:02:26.0000000Z" checksum="0895e8d40b56f1d73cabc8531bbfc84e" fullyQualifiedName="DocumentoNotasExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f412243c-32fb-4945-9112-bdd66d0e31d6" name="DocumentoNotasExemplo" type="faeb588c-dcce-4dad-9af3-cdd11b961a32" description="DocumentoNotasExemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[<P>AMBIENTE DE EXEMPLO:</P>
<P>DIRECTORY: SANITIZED-DIRECTORY-ID</P>
<P>USER ID: SANITIZED-USER-ID</P>
<P>repository id: SANITIZED-REPOSITORY-ID</P>
<P>&nbsp;</P>
<P>Bibliotecas externas que exigem revisao na migracao:</P>
<P>BibliotecaA.dll e BibliotecaB.dll</P>
<P>&nbsp;</P>
<P>&nbsp;</P>
<P>Classes e estilos ajustados em uma revisao de tema:<BR>Attribute, ActionButtons, ActiunButtonsHovered, BtnLogin, WorkWith, PromptGrid, ViewGrid, WWColumn, FormCell, WWGridCell, ViewGridCellAdvanced, WWGridCellExpanded, HeaderContainer, WWAdvancedContainer, WWTabPage, WWTabePageHovered, Label, TextBlockHeader, nav, col-sm-8, col-sm-offset-2, col-xs-offset-1, control-label, Rules, ExtraSmall, Small, form-control-static, form-group, form-horizontal, gx-button, P e WWAdvancedContainer.container-fluid.</P>]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DocumentoNotasExemplo</Value>
    </Property>
    <Property>
      <Name>IsDocumentoNotasExemplo</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de DataSelector

### Molde sanitizado de DataSelector 1 - `dsMovimentoAtivoOuCanceladoExemplo`

- Perfil: DataSelector enxuto com duas `Condition`, uma variavel booleana e um `InnerHtml` curto de apoio.
- Uso operacional: boa referencia para filtros binarios simples e seletores com uma unica variavel de entrada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="702d2e19-b267-4c25-ae37-0e2ef9e330a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2020-12-23T03:16:25.0000000Z" checksum="faa11acd91e9338faa49bd9fd6cd07ea" fullyQualifiedName="dsMovimentoAtivoOuCanceladoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="438f9146-d6c2-4427-ab41-bf1ed620b571" name="dsMovimentoAtivoOuCanceladoExemplo" type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af" description="Movimento Ativo ou Cancelado Exemplo" parent="RegistroMovimento" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a2bc65a1-999f-4e9b-b837-72285cc9bb16">
    <Level>
      <Condition>
        <Source><![CDATA[RegistroMovimentoCancelado 		= false or RegistroMovimentoCancelado.IsNull() when not &SomenteCancelados
	
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[RegistroMovimentoCancelado 		= true when &SomenteCancelados
]]></Source>
      </Condition>
    </Level>
    <Variables type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
      <Variable Name="SomenteCancelados">
        <Documentation />
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>SomenteCancelados</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Logico</Value>
          </Property>
        </Properties>
      </Variable>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variables>
    <Parameters>
      <Parameter>
        <Type>Variable</Type>
        <Name>SomenteCancelados</Name>
        <Description>Somente Cancelados</Description>
      </Parameter>
    </Parameters>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/docs/data-selector-note]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>dsMovimentoAtivoOuCanceladoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Movimento Ativo ou Cancelado Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataSelector 2 - `dsRegistrosPorMovimentoExemplo`

- Perfil: DataSelector denso, com muitas `Condition`, `Variables` customizadas e filtro parametrico mais rico.
- Uso operacional: boa referencia para seletores baseados em varias condicoes combinadas e SDT de parametros.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="988004e2-6090-42c3-9603-c073172b75a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-12-23T13:38:47.0000000Z" checksum="70d20e81967466e858649307c9e679f3" fullyQualifiedName="dsRegistrosPorMovimentoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="3e3c9034-b9dd-44cf-9d5a-97b37c606153" name="dsRegistrosPorMovimentoExemplo" type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af" description="ds Registros Por Movimento Exemplo" parent="Registro" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a2bc65a1-999f-4e9b-b837-72285cc9bb16">
    <Level>
      <Condition>
        <Source><![CDATA[MovimentoEmpresaId = &sdtRegistroParametros.EmpresaId when not &sdtRegistroParametros.EmpresaId.IsEmpty() and not &sdtRegistroParametros.FiltrarPelaEntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoEmpresaId in &sdtRegistroParametros.listaEmpresaOrcamentosId when &sdtRegistroParametros.EmpresaId.IsEmpty() and not &sdtRegistroParametros.FiltrarPelaEntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeEmpresaId = &sdtRegistroParametros.EntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeAtivoFaturamentoMunicipioId = &sdtRegistroParametros.MunicipioId when not &sdtRegistroParametros.MunicipioId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoCancelado = false or MovimentoCancelado.IsNull()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCancelado = false or MovimentoRegistroCancelado.IsNull()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipo = &sdtRegistroParametros.TipoRegistro when not &sdtRegistroParametros.TipoRegistro.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoTipo = TipoProcesso.Composicao or MovimentoProcessoTipo = TipoProcesso.Acrescimo or MovimentoProcessoTipo = TipoProcesso.Reducao when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and (&sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Pendente or &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Entrada);
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoTipo = TipoProcesso.Baixa when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Baixado;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCodigoHistoricoExterno = &sdtRegistroParametros.codigoHistoricoExterno when not &sdtRegistroParametros.codigoHistoricoExterno.IsEmpty() and &sdtRegistroParametros.codigoHistoricoExterno > 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCodigoHistoricoExterno.IsEmpty() when not &sdtRegistroParametros.codigoHistoricoExterno.IsEmpty() and &sdtRegistroParametros.codigoHistoricoExterno < 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeId = &sdtRegistroParametros.EntidadeId when not &sdtRegistroParametros.EntidadeId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procInscricaoFederalFormatada(MovimentoRegistroEntidadeInscricaoFederal) = &sdtRegistroParametros.EntidadeInscricaoFederal when not &sdtRegistroParametros.EntidadeInscricaoFederal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaId.IsEmpty() or MovimentoRegistroDocumentoOperacionalSaidaId.IsNull() or MovimentoRegistroTipoDocumentoSaida <> &sdtRegistroParametros.aIgnorarTipoDocumentoSaida when not &sdtRegistroParametros.aIgnorarTipoDocumentoSaida.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoSaida = &sdtRegistroParametros.TipoDocumentoSaida when not &sdtRegistroParametros.TipoDocumentoSaida.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaId = &sdtRegistroParametros.DocumentoSaidaId when &sdtRegistroParametros.DocumentoSaidaId > 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[PRCExemploAgenteDocumentoSaidaA(MovimentoRegistroDocumentoOperacionalSaidaEmpresaId, MovimentoRegistroDocumentoOperacionalSaidaId) = &sdtRegistroParametros.AgenteId when not &sdtRegistroParametros.AgenteId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[(not MovimentoRegistroDocumentoOperacionalId.IsEmpty() and not MovimentoRegistroDocumentoOperacionalId.IsNull() and 
	MovimentoRegistroDocumentoOperacionalResponsavelId = &sdtRegistroParametros.DFResponsavelId
) or
(	(MovimentoRegistroDocumentoOperacionalId.IsEmpty() or MovimentoRegistroDocumentoOperacionalId.IsNull()) and
	not MovimentoRegistroDocumentoOperacionalSaidaTipo.IsEmpty() and not MovimentoRegistroDocumentoOperacionalSaidaTipo.IsNull() and
	not MovimentoRegistroPedidoId.IsEmpty() and not MovimentoRegistroPedidoId.IsNull() and
	PRCExemploResponsavelPedidoA(MovimentoRegistroDocumentoOperacionalSaidaTipo, MovimentoRegistroPedidoEmpresaId, MovimentoRegistroPedidoId, MovimentoRegistroPedidoTipo) = &sdtRegistroParametros.DFResponsavelId
)
when not &sdtRegistroParametros.DFResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeResponsavelId = &sdtRegistroParametros.EntidadeResponsavelId or
(	MovimentoRegistroEntidadeSetorVendedorId = &sdtRegistroParametros.EntidadeResponsavelId and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.EntidadeResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalId > 0 and MovimentoRegistroDocumentoOperacionalResponsavelId in &sdtRegistroParametros.ResponsaveisDoSupervisor when not &sdtRegistroParametros.DFResponsavelSupervisorId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeResponsavelId in &sdtRegistroParametros.ResponsaveisDoSupervisor or
(	MovimentoRegistroEntidadeSetorVendedorId in &sdtRegistroParametros.ResponsaveisDoSupervisor and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.EntidadeResponsavelSupervisorId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoData >= &sdtRegistroParametros.DataInicial when not &sdtRegistroParametros.DataInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoData <= &sdtRegistroParametros.DataFinal when not &sdtRegistroParametros.DataFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroData >= &sdtRegistroParametros.RegistroDataInicial when not &sdtRegistroParametros.RegistroDataInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroData <= &sdtRegistroParametros.RegistroDataFinal when not &sdtRegistroParametros.RegistroDataFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroVencimento >= &sdtRegistroParametros.VencimentoInicial  when not &sdtRegistroParametros.VencimentoInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroVencimento <= &sdtRegistroParametros.VencimentoFinal when not &sdtRegistroParametros.VencimentoFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoId = &sdtRegistroParametros.ProcessoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.ProcessoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[not MovimentoRegistroSaldoValor.IsEmpty() or not MovimentoRegistroDiferencaComposicao.IsEmpty() when &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Pendente;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDiferencaComposicao.IsEmpty() when &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Entrada
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procEntidadeTemUmPapel(MovimentoRegistroEntidadeEmpresaId, MovimentoRegistroEntidadeId, &sdtRegistroParametros.EntidadePapel) when not &sdtRegistroParametros.EntidadePapel.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeSetorId = &sdtRegistroParametros.SetorId when not &sdtRegistroParametros.SetorId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoGrupoId = &sdtRegistroParametros.ProcessoGrupoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.ProcessoGrupoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalResponsavelId in &sdtRegistroParametros.ResponsaveisDoUsuario or
MovimentoRegistroEntidadeResponsavelId in &sdtRegistroParametros.ResponsaveisDoUsuario or
(	MovimentoRegistroEntidadeSetorVendedorId in &sdtRegistroParametros.ResponsaveisDoUsuario and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.UsuarioTodosResponsaveisLiberados and not &sdtRegistroParametros.semControleResponsaveisDoUsuario;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCondicaoOperacional = &sdtRegistroParametros.CondicaoOperacional when not &sdtRegistroParametros.CondicaoOperacional.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalId = &sdtRegistroParametros.TipoDocumentoId when not &sdtRegistroParametros.TipoDocumentoId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaEmpresaId > 0 and MovimentoRegistroDocumentoOperacionalSaidaId > 0 and MovimentoRegistroTipoDocumentoSaida = TipoDocumentoSaida.DocumentoOperacionalA			 
when not &sdtRegistroParametros.AgentePrestouContas.IsEmpty() or not &sdtRegistroParametros.PrestacaoContasComObservacao.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoAgenteId = &sdtRegistroParametros.MovimentoAgenteId when not &sdtRegistroParametros.MovimentoAgenteId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroPrevisaoBaixaContaEmpresaId = &sdtRegistroParametros.RegistroPrevisaoBaixaContaEmpresaId 
when not &sdtRegistroParametros.RegistroPrevisaoBaixaContaEmpresaId.IsEmpty() and not &sdtRegistroParametros.RegistroPrevisaoBaixaContaId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroPrevisaoBaixaContaId = &sdtRegistroParametros.RegistroPrevisaoBaixaContaId 
when not &sdtRegistroParametros.RegistroPrevisaoBaixaContaId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeProprietarioId = &sdtRegistroParametros.EntidadeProprietarioId or MovimentoRegistroEntidadeId = &sdtRegistroParametros.EntidadeProprietarioId
when not &sdtRegistroParametros.EntidadeProprietarioId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroSaiNoRelatorioMutuoTradicional when &sdtRegistroParametros.RegistroSaiNoRelatorioMutuoTradicional
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoSaiNoRelatorioResumoFaturamento when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and &sdtRegistroParametros.SaiNoRelatorioResumoFaturamento;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procProcessoComItemAlgumaContaAlmejada(MovimentoProcessoEmpresaId, MovimentoProcessoId, &sdtRegistroParametros.ProcessoItemContaEmpresaId, &sdtRegistroParametros.ProcessoItemContaId, &sdtRegistroParametros.ProcessoItemContaClassificacao, &sdtRegistroParametros.ProcessoItemContaReduzido) 
when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and (not &sdtRegistroParametros.ProcessoItemContaId.IsEmpty() or not &sdtRegistroParametros.ProcessoItemContaClassificacao.IsEmpty() or not &sdtRegistroParametros.ProcessoItemContaReduzido.IsEmpty());
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalFormularioOperacional = FormularioOperacional.DocumentoCobrancaBancario and procDocumentoCobrancaIdDeUmRegistroId(MovimentoRegistroEmpresaId, MovimentoRegistroId, false, false) > 0 
when &sdtRegistroParametros.ComDocumentoCobranca = SimOuNao.Sim;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalFormularioOperacional <> FormularioOperacional.DocumentoCobrancaBancario or procDocumentoCobrancaIdDeUmRegistroId(MovimentoRegistroEmpresaId, MovimentoRegistroId, false, false) = 0 
when &sdtRegistroParametros.ComDocumentoCobranca = SimOuNao.Nao;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoCentroResultadoId = &sdtRegistroParametros.CentroResultadoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.CentroResultadoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalId.IsEmpty() or MovimentoRegistroDocumentoOperacionalId.IsNull() or MovimentoRegistroDocumentoOperacionalResponsavelId <> &sdtRegistroParametros.aIgnorarDFResponsavelId when not &sdtRegistroParametros.aIgnorarDFResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroAgrupadorOperacional = &sdtRegistroParametros.AgrupadorOperacional when not &sdtRegistroParametros.AgrupadorOperacional.IsEmpty();
]]></Source>
      </Condition>
    </Level>
    <Variables type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
      <Variable Name="sdtRegistroParametros">
        <Documentation />
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtRegistroParametros</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:sdtRegistroParametros</Value>
          </Property>
        </Properties>
      </Variable>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variables>
    <Parameters>
      <Parameter>
        <Type>Variable</Type>
        <Name>sdtRegistroParametros</Name>
        <Description>sdt Registro Parametros</Description>
      </Parameter>
    </Parameters>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>dsRegistrosPorMovimentoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>ds Registros Por Movimento Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Generator

### Molde sanitizado de Generator 1 - `GeneratorPadraoExemplo`

- Perfil: `Generator` minimo com categoria default e sem `DefaultType`.
- Uso operacional: boa referencia para definicoes basicas de gerador padrao.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="4cecd62b7d1aa14890e7e98e0df97a46" fullyQualifiedName="GeneratorPadraoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="5953b12e-71f1-4020-a9b9-254085cb7061" name="GeneratorPadraoExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Padrao Exemplo">
  <Properties>
    <Property>
      <Name>IsReorg</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorPadraoExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Generator 2 - `GeneratorFrontendExemplo`

- Perfil: `Generator` customizado de usuario, sem categoria default.
- Uso operacional: boa referencia para geradores adicionais definidos na KB.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T21:48:48.0000000Z" checksum="bc1ad3de3f7892e3ac7f7afc41a65044" fullyQualifiedName="GeneratorFrontendExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="1082669b-8306-4b74-8964-552d1c688e05" name="GeneratorFrontendExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Frontend Exemplo">
  <Properties>
    <Property>
      <Name>IsUser</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorFrontendExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Generator 3 - `GeneratorMobileExemplo`

- Perfil: `Generator` com `DefaultType`, representando variante orientada a plataforma.
- Uso operacional: boa referencia para casos em que o gerador carrega um tipo default numerico.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="9acc5ae74e2b862e3010bd733afae29e" fullyQualifiedName="GeneratorMobileExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="d8a1a11c-3259-4d3b-8769-76776bb25ec7" name="GeneratorMobileExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Mobile Exemplo">
  <Properties>
    <Property>
      <Name>IsUser</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>DefaultType</Name>
      <Value>28</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorMobileExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de PatternSettings

### Molde sanitizado de PatternSettings 1 - `PatternWebExemplo`

- Perfil: configuracao enxuta de `PatternSettings` para `Work With for Web`, com `StandardActions`, `Context` e `Security`.
- Uso operacional: boa referencia para padroes web centralizados que preservam a hierarquia `<Config>`.
- Evidência direta: a validacao posterior no acervo real confirmou que `PatternSettings` depende de `Pattern="..."`, `ContextVariable`, `LoadProcedure` e referencias de seguranca presentes no ambiente.
- Inferência forte: este molde nao deve ser tratado como objeto autocontido; ele so fecha comportamento quando o pattern correspondente estiver registrado no destino.
- Inferência forte: se o ambiente nao reconhecer o pattern citado, o resultado esperado e importacao sem mudanca util ou aviso de pattern nao registrado.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-10-28T12:27:41.0000000Z" checksum="8fd2b9f45a2b8a0bd391eb086dfb7235" fullyQualifiedName="PatternWebExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="4bb38735-7288-3760-86ce-8d6e91fba04b" name="PatternWebExemplo" type="83476c1e-fa72-4229-9930-f51b954fca2d" description="Pattern Web Exemplo">
  <Part type="3c89746e-54b1-441a-8f3f-97cc81be06bd">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="15.0.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Config>
  <Template />
  <Objects />
  <Theme OptionalColumn="WWOptionalColumn" GridAction="ActionAttribute" />
  <Labels WorkWithTitle="Work With &lt;Object&gt;" ViewDescription="&lt;Object&gt; - Informacao" OrderedBy="Ordenado por" PreviousTab="Tab Anterior" NextTab="Proxima Tab" RecordNotFound="Registro Nao Encontrado" />
  <Grid CellSpacing="1" CellPadding="2" />
  <MasterPages />
  <StandardActions>
    <Insert Caption="GXM_insert" Tooltip="GXM_insert" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionInsert" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisabled" ButtonClass="BtnEnter" />
    <Update Caption="GXM_update" Tooltip="GXM_update" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionUpdate" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionUpdateDisabled" DisabledClass="DisabledActionAttribute" ButtonClass="BtnEnter" InGridClass="UpdateAttribute" />
    <Delete Caption="GX_BtnDelete" Tooltip="GX_BtnDelete" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDelete" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDeleteDisabled" DisabledClass="DisabledActionAttribute" ButtonClass="BtnDelete" InGridClass="DeleteAttribute" />
    <Display Caption="GXM_display" Tooltip="GXM_display" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisplay" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisplayDisabled" DisabledClass="DisabledActionAttribute" InGridClass="DisplayAttribute" />
    <Export Caption="Planilha" Tooltip="Exporta como Planilha" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionExport" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisabled" />
    <Search Caption="GX_BtnSearch" Tooltip="GX_BtnSearch" />
  </StandardActions>
  <Context>
    <ContextVariable Name="Context" Type="447527b5-9210-4523-898b-5dccb17be60a-Context" LoadProcedure="84a12160-f59b-4ad7-a683-ea4481ac23e9-procCarregaContextoExemplo" />
  </Context>
  <Security Check="84a12160-f59b-4ad7-a683-ea4481ac23e9-procAutorizacaoExemplo" NotAuthorized="c9584656-94b6-4ccd-890f-332d11fc2c25-PainelNaoAutorizadoExemplo">
    <Parameters />
  </Security>
</Config>]]></Data>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PatternWebExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Pattern Web Exemplo</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de PatternSettings 2 - `PatternDevicesExemplo`

- Perfil: configuracao de `PatternSettings` voltada a multiplas plataformas, com bloco denso de `Platforms`.
- Uso operacional: boa referencia para padroes mobile/web com segmentacao por dispositivo e tema.
- Evidência direta: o `Pattern` e os `Theme` referenciados no bloco de plataformas importam contexto real do ambiente.
- Inferência forte: editar apenas nomes e plataformas sem validar GUIDs de `Pattern` e referencias de `Theme` pode manter o XML bem-formado e ainda assim torná-lo inutilizavel no destino.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T22:18:24.0000000Z" checksum="567e74ca5f88b8ff29214d2163bea9da" fullyQualifiedName="PatternDevicesExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="d0f701a5-7288-3760-91b5-395d02d79889" name="PatternDevicesExemplo" type="83476c1e-fa72-4229-9930-f51b954fca2d" description="Pattern Devices Exemplo">
  <Part type="3c89746e-54b1-441a-8f3f-97cc81be06bd">
    <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="18.5.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Config>
  <Template />
  <Platforms>
    <Platform Name="Any Platform" OS="Any Platform" Theme="78b3fa0e-174c-4b2b-8716-718167a428b5-TemaUnificadoExemplo" Predefined="True" />
    <Platform Name="Any Phone" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Phone" MaximumShortestBound="599" />
    <Platform Name="Any Tablet 7&quot;" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Medium" Predefined="True" BoundsName="Tablet 7" MinimumShortestBound="600" MaximumShortestBound="719" />
    <Platform Name="Any Tablet 10&quot;" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="Tablet 10" MinimumShortestBound="720" />
    <Platform Name="Any TV" DeviceKind="TV" Size="Large" Predefined="True" />
    <Platform Name="Any Watch" DeviceKind="Watch" Size="Small" Predefined="True" />
    <Platform Name="Any Android Device" OS="Android" Theme="c804fdbd-7c0b-440d-8527-4316c92649a6-TemaAndroidExemplo" NavigationStyle="Slide" Predefined="True" />
    <Platform Name="Android Phone" OS="Android" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Phone" MaximumShortestBound="599" />
    <Platform Name="Android Tablet 7&quot;" OS="Android" DeviceKind="Phone or Tablet" Size="Medium" Predefined="True" BoundsName="Tablet 7" MinimumShortestBound="600" MaximumShortestBound="719" />
    <Platform Name="Android Tablet 10&quot;" OS="Android" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="Tablet 10" MinimumShortestBound="720" />
    <Platform Name="Any Apple Device" OS="Apple" NavigationStyle="Slide" Predefined="True" />
    <Platform Name="iPad" OS="Apple" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="iPad" MinimumShortestBound="768" />
    <Platform Name="iPhone" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone" MaximumShortestBound="767" />
    <Platform Name="iPhone 4&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 4&quot;" MinimumShortestBound="320" MaximumShortestBound="320" MinimumLongestBound="568" MaximumLongestBound="568" />
    <Platform Name="iPhone 3.5&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 3.5&quot;" MinimumShortestBound="320" MaximumShortestBound="320" MinimumLongestBound="480" MaximumLongestBound="480" />
    <Platform Name="iPhone 4.7&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 4.7&quot;" MinimumShortestBound="375" MaximumShortestBound="375" MinimumLongestBound="667" MaximumLongestBound="667" />
    <Platform Name="iPhone 5.5&quot; &amp; 6.1&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 5.5&quot;" MinimumShortestBound="414" MaximumShortestBound="414" MinimumLongestBound="736" MaximumLongestBound="736" />
    <Platform Name="iPhone 5.8&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 5.8&quot;" MinimumShortestBound="375" MaximumShortestBound="375" MinimumLongestBound="812" MaximumLongestBound="812" />
    <Platform Name="iPhone 6.5&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 6.5&quot;" MinimumShortestBound="414" MaximumShortestBound="414" MinimumLongestBound="896" MaximumLongestBound="896" />
    <Platform Name="Apple TV" OS="Apple" DeviceKind="TV" Size="Large" Predefined="True" />
    <Platform Name="Apple Watch" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" />
    <Platform Name="Apple Watch 38mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 38mm" MinimumShortestBound="136" MaximumShortestBound="136" />
    <Platform Name="Apple Watch 42mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 42mm" MinimumShortestBound="156" MaximumShortestBound="156" />
    <Platform Name="Apple Watch 40mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 40mm" MinimumShortestBound="162" MaximumShortestBound="162" />
    <Platform Name="Apple Watch 44mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 44mm" MinimumShortestBound="184" MaximumShortestBound="184" />
    <Platform Name="Any Web Screen" OS="Web" Predefined="True" />
    <Platform Name="Web Phone" OS="Web" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Web Phone" MaximumLongestBound="599" />
    <Platform Name="Web Small" OS="Web" Size="Medium" Predefined="True" BoundsName="Web Small" MinimumLongestBound="600" MaximumLongestBound="719" />
    <Platform Name="Web Desktop" OS="Web" Size="Large" Predefined="True" BoundsName="Web Desktop" MinimumLongestBound="720" MaximumLongestBound="1199" />
    <Platform Name="Web Big Screen" OS="Web" Size="Large" Predefined="True" BoundsName="Web Big Screen" MinimumLongestBound="1200" />
  </Platforms>
  <Labels />
  <StandardActions>
    <Insert Caption="GXM_insert" />
    <Update Caption="GXM_update" />
    <Delete Caption="GX_BtnDelete" />
    <Search Caption="GX_BtnSearch" />
  </StandardActions>
</Config>]]></Data>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PatternDevicesExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Pattern Devices Exemplo</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de DataStore

### Molde sanitizado de DataStore 1 - `DataStorePadraoExemplo`

- Perfil: `DataStore` minimo com propriedades de categoria default.
- Uso operacional: boa referencia para definicoes simples de datastore sem metadados adicionais.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="fc8ae8c25e3951dcd60d9bec160667f5" fullyQualifiedName="DataStorePadraoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="05dfb0e3-dfc1-478d-82cc-8517bebb2485" name="DataStorePadraoExemplo" type="dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0" description="DataStore Padrao Exemplo">
  <Properties>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>DataStorePadraoExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataStore 2 - `DataStoreSegurancaExemplo`

- Perfil: `DataStore` simples sem categoria default, util para variação minima de propriedades.
- Uso operacional: boa referencia para datastores secundarios ou especializados.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-03T11:38:41.0000000Z" checksum="3647285ee867f5d77a3101085168ed18" fullyQualifiedName="DataStoreSegurancaExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="c54239e9-16ff-40e9-ba98-b97cf2ac2ba4" name="DataStoreSegurancaExemplo" type="dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0" description="DataStore Seguranca Exemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DataStoreSegurancaExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Dashboard

### Molde sanitizado de Dashboard 1 - `DashboardAtividadeExemplo`

- Perfil: `Dashboard` com `Parameters`, `Layout`, `Card`, `Chart` e filtro superior.
- Uso operacional: boa referencia para dashboards compostos por indicadores e graficos em tabela principal.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="5fa995f2-62aa-4d92-8aeb-197abdd13e89" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:29:54.0000000Z" checksum="f647498b2bf609c1667f0a415f2fab27" fullyQualifiedName="DashboardAtividadeExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="1d0eb41a-7bcf-447e-91dc-75c207e4c2ff" name="DashboardAtividadeExemplo" type="526aba9f-a725-4bc7-b1db-0b9f92ac9550" description="Dashboard Atividade Exemplo" parent="PainelExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a51ced48-7bee-0001-ab12-04e9e32123d1">
    <Data Pattern="526aba9f-a725-4bc7-b1db-0b9f92ac9550" Version="17.0.1"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Dashboard>
  <Parameters>
    <Parameter Name="From" DataType="Date" />
    <Parameter Name="To" DataType="Date" />
  </Parameters>
  <Layout FiltersPosition="Top">
    <MainTable>
      <Row ElementId="32">
        <Cell ElementId="4">
          <Object ElementId="5" ControlName="NovosRegistros" FrameVisible="True" FrameTitle="CHAVE_NOVOS_REGISTROS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardTotalRegistros" OutputType="Card">
            <ObjectElement Name="CountItems" Type="Datum" Title=" " />
          </Object>
        </Cell>
        <Cell ElementId="53">
          <Object ElementId="54" ControlName="TotalSessoes" FrameVisible="True" FrameTitle="CHAVE_TOTAL_SESSOES" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardTotalSessoes" OutputType="Card">
            <ObjectElement Name="TotalSessions" Type="Datum" Title=" " />
          </Object>
        </Cell>
      </Row>
      <Row ElementId="42">
        <Cell ElementId="47">
          <Object ElementId="48" ControlName="SessoesPorAplicacao" FrameVisible="True" FrameTitle="CHAVE_SESSOES_POR_APLICACAO" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesPorAplicacao" OutputType="Chart">
            <ObjectElement Name="ApplicationId" />
            <ObjectElement Name="Sessions" Type="Datum" />
            <ObjectElement Name="ApplicationName" />
          </Object>
        </Cell>
        <Cell ElementId="43">
          <Object ElementId="44" ControlName="SessoesPorDia" FrameVisible="True" FrameTitle="CHAVE_SESSOES_POR_DIA" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesPorDia" OutputType="Chart" ChartType="Timeline" XAxisTitle="Date" YAxisTitle="Sessions">
            <ObjectElement Name="Date" />
            <ObjectElement Name="Sessions" Type="Datum" />
          </Object>
        </Cell>
      </Row>
      <Row ElementId="49">
        <Cell ElementId="51">
          <Object ElementId="52" ControlName="UsuariosRegistrados" FrameVisible="True" FrameTitle="CHAVE_USUARIOS_REGISTRADOS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardUsuariosRegistrados" OutputType="Card">
            <ObjectElement Name="TotalUsers" Type="Datum" Title=" " />
          </Object>
        </Cell>
        <Cell ElementId="39">
          <Object ElementId="40" ControlName="SessoesAtivas" FrameVisible="True" FrameTitle="CHAVE_SESSOES_ATIVAS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesAtivas" OutputType="Card">
            <ObjectElement Name="ActiveSessions" Type="Datum" Title=" " />
          </Object>
        </Cell>
      </Row>
    </MainTable>
    <FiltersTable>
      <Row ElementId="34">
        <Cell ElementId="35">
          <Filter ElementId="36" ControlName="FiltroPeriodo" FilterType="Range" DataType="Date" Name="From" NameLowerValue="From" NameUpperValue="To" Caption="CHAVE_PERIODO" Modified="True" />
        </Cell>
      </Row>
    </FiltersTable>
  </Layout>
</Dashboard>]]></Data>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DashboardAtividadeExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Dashboard Atividade Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>PainelExemplo-web</Categories>
</Object>
```

## Moldes sanitizados completos de DeploymentUnit

### Molde sanitizado de DeploymentUnit 1 - `DeploymentUnitExemplo`

- Perfil: `DeploymentUnit` com poucos `Member` e um `Part` principal declarativo.
- Uso operacional: boa referencia para unidades de deploy que apenas agregam objetos ja existentes.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-15T14:07:19.0000000Z" checksum="a97c0da3de76a832806f0606ac08aac4" fullyQualifiedName="DeploymentUnitExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7665e34c-f52d-430c-b113-e76e9cbdf635" name="DeploymentUnitExemplo" type="bf08dfb1-361c-4e7e-ad54-391e56e60b49" description="Deployment Unit Exemplo">
  <Part type="122ea32d-7ffa-4c47-9cbf-0829c2f060fe">
    <Definition>
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploA" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploB" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploC" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploD" />
    </Definition>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DeploymentUnitExemplo</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de Language

### Molde sanitizado de Language 1 - `IdiomaExemploPT`

- Perfil: `Language` completo com bloco extenso de `Translations`.
- Uso operacional: boa referencia para objetos de idioma que centralizam mensagens e traducoes de interface.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="0001-01-01T00:00:00.0000000" checksum="cb04c786ee9f23279149b0a430455587" fullyQualifiedName="IdiomaExemploPT" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6cc49ef5-e1eb-459c-aefd-331de0d9fa8c" name="IdiomaExemploPT" type="88313f43-5eb2-0000-0028-e8d9f5bf9588" description="Idioma Exemplo PT">
  <Part type="c23f3bb5-1e43-4c6b-b219-4717979df76a">
    <Translations>
      <Entry>
        <Message>Hide Filters</Message>
        <Type>User</Type>
        <Translation>Esconder Filtros</Translation>
      </Entry>
      <Entry>
        <Message>MORE</Message>
        <Type>User</Type>
        <Translation>MAIS</Translation>
      </Entry>
      <Entry>
        <Message>HIDE FILTERS</Message>
        <Type>User</Type>
        <Translation>Esconder Filtros</Translation>
      </Entry>
      <Entry>
        <Message>Hide</Message>
        <Type>User</Type>
        <Translation>Esconder</Translation>
      </Entry>
      <Entry>
        <Message>Show Filters</Message>
        <Type>User</Type>
        <Translation>Mostrar Filtros</Translation>
      </Entry>
      <Entry>
        <Message>SHOW FILTERS</Message>
        <Type>User</Type>
        <Translation>MOSTRAR FILTROS</Translation>
      </Entry>
      <Entry>
        <Message>ShowHide</Message>
        <Type>User</Type>
        <Translation>MostrarEsconder</Translation>
      </Entry>
      <Entry>
        <Message>Users</Message>
        <Type>User</Type>
        <Translation>Usuários</Translation>
      </Entry>
      <Entry>
        <Message>USERS</Message>
        <Type>User</Type>
        <Translation>USUÁRIOS</Translation>
      </Entry>
      <Entry>
        <Message>Users permissions</Message>
        <Type>User</Type>
        <Translation>Permissões de usuários</Translation>
      </Entry>
      <Entry>
        <Message>User</Message>
        <Type>User</Type>
        <Translation>Usuário</Translation>
      </Entry>
      <Entry>
        <Message>User Name</Message>
        <Type>User</Type>
        <Translation>Nome de Usuário</Translation>
      </Entry>
      <Entry>
        <Message>User name</Message>
        <Type>User</Type>
        <Translation>Nome de usuário</Translation>
      </Entry>
      <Entry>
        <Message>First name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>First Name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>Last name</Message>
        <Type>User</Type>
        <Translation>Sobrenome</Translation>
      </Entry>
      <Entry>
        <Message>Last Name</Message>
        <Type>User</Type>
        <Translation>Sobrenome</Translation>
      </Entry>
      <Entry>
        <Message>Authentication</Message>
        <Type>User</Type>
        <Translation>Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authorization</Message>
        <Type>User</Type>
        <Translation>Autorização</Translation>
      </Entry>
      <Entry>
        <Message>Authorize</Message>
        <Type>User</Type>
        <Translation>Autorize</Translation>
      </Entry>
      <Entry>
        <Message>Role</Message>
        <Type>User</Type>
        <Translation>Papel</Translation>
      </Entry>
      <Entry>
        <Message>Roles</Message>
        <Type>User</Type>
        <Translation>Papéis</Translation>
      </Entry>
      <Entry>
        <Message>ROLES</Message>
        <Type>User</Type>
        <Translation>PAPÉIS</Translation>
      </Entry>
      <Entry>
        <Message>Security Policies</Message>
        <Type>User</Type>
        <Translation>Políticas de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security policies</Message>
        <Type>User</Type>
        <Translation>Políticas de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security policy</Message>
        <Type>User</Type>
        <Translation>Política de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security Policy</Message>
        <Type>User</Type>
        <Translation>Política de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Connection</Message>
        <Type>User</Type>
        <Translation>Conexão</Translation>
      </Entry>
      <Entry>
        <Message>Connections</Message>
        <Type>User</Type>
        <Translation>Conexões</Translation>
      </Entry>
      <Entry>
        <Message>Authentication Types</Message>
        <Type>User</Type>
        <Translation>Tipos de Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authentication types</Message>
        <Type>User</Type>
        <Translation>Tipos de autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Event subscriptions</Message>
        <Type>User</Type>
        <Translation>Subscrição de eventos</Translation>
      </Entry>
      <Entry>
        <Message>Event Subscriptions</Message>
        <Type>User</Type>
        <Translation>Subscrição de Eventos</Translation>
      </Entry>
      <Entry>
        <Message>Repositories</Message>
        <Type>User</Type>
        <Translation>Repositórios</Translation>
      </Entry>
      <Entry>
        <Message>GAM configuration</Message>
        <Type>User</Type>
        <Translation>Configuração do GAM</Translation>
      </Entry>
      <Entry>
        <Message>GAM Configuration</Message>
        <Type>User</Type>
        <Translation>Configuração do GAM</Translation>
      </Entry>
      <Entry>
        <Message>Dashboard</Message>
        <Type>User</Type>
        <Translation>Painel</Translation>
      </Entry>
      <Entry>
        <Message>Role name</Message>
        <Type>User</Type>
        <Translation>Nome do papel</Translation>
      </Entry>
      <Entry>
        <Message>Role Name</Message>
        <Type>User</Type>
        <Translation>Nome do Papel</Translation>
      </Entry>
      <Entry>
        <Message>EDIT</Message>
        <Type>User</Type>
        <Translation>EDITAR</Translation>
      </Entry>
      <Entry>
        <Message>Edit</Message>
        <Type>User</Type>
        <Translation>Editar</Translation>
      </Entry>
      <Entry>
        <Message>Copy</Message>
        <Type>User</Type>
        <Translation>Copia</Translation>
      </Entry>
      <Entry>
        <Message>COPY</Message>
        <Type>User</Type>
        <Translation>COPIA</Translation>
      </Entry>
      <Entry>
        <Message>Active</Message>
        <Type>User</Type>
        <Translation>Ativo</Translation>
      </Entry>
      <Entry>
        <Message>Add</Message>
        <Type>User</Type>
        <Translation>Adicionar</Translation>
      </Entry>
      <Entry>
        <Message>Application Name</Message>
        <Type>User</Type>
        <Translation>Nome do Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>New User</Message>
        <Type>User</Type>
        <Translation>Novo Usuário</Translation>
      </Entry>
      <Entry>
        <Message>New users</Message>
        <Type>User</Type>
        <Translation>Novos usuários</Translation>
      </Entry>
      <Entry>
        <Message>Gender</Message>
        <Type>User</Type>
        <Translation>Gênero</Translation>
      </Entry>
      <Entry>
        <Message>Gender:</Message>
        <Type>User</Type>
        <Translation>Gênero:</Translation>
      </Entry>
      <Entry>
        <Message>Authentication type</Message>
        <Type>User</Type>
        <Translation>Tipo de autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authentication Type</Message>
        <Type>User</Type>
        <Translation>Tipo de Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Rol</Message>
        <Type>User</Type>
        <Translation>Papéls</Translation>
      </Entry>
      <Entry>
        <Message>Show users status</Message>
        <Type>User</Type>
        <Translation>Status dos Usuários</Translation>
      </Entry>
      <Entry>
        <Message>Authenticated date from</Message>
        <Type>User</Type>
        <Translation>Autenticado desde</Translation>
      </Entry>
      <Entry>
        <Message>Authenticated date to</Message>
        <Type>User</Type>
        <Translation>Autenticado até</Translation>
      </Entry>
      <Entry>
        <Message>Register date from</Message>
        <Type>User</Type>
        <Translation>Registro desde</Translation>
      </Entry>
      <Entry>
        <Message>Register date to</Message>
        <Type>User</Type>
        <Translation>Registro até</Translation>
      </Entry>
      <Entry>
        <Message>Clear</Message>
        <Type>User</Type>
        <Translation>Limpar</Translation>
      </Entry>
      <Entry>
        <Message>ClearFilters</Message>
        <Type>User</Type>
        <Translation>LimparFiltros</Translation>
      </Entry>
      <Entry>
        <Message>Apply</Message>
        <Type>User</Type>
        <Translation>Aplicar</Translation>
      </Entry>
      <Entry>
        <Message>Try a Search</Message>
        <Type>User</Type>
        <Translation>Digite Texto a Pesquisar</Translation>
      </Entry>
      <Entry>
        <Message>External Id</Message>
        <Type>User</Type>
        <Translation>Id Externo</Translation>
      </Entry>
      <Entry>
        <Message>External ID</Message>
        <Type>User</Type>
        <Translation>ID Externo</Translation>
      </Entry>
      <Entry>
        <Message>Application GUID</Message>
        <Type>User</Type>
        <Translation>GUID do Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>Company name</Message>
        <Type>User</Type>
        <Translation>Nome da Companhia</Translation>
      </Entry>
      <Entry>
        <Message>description</Message>
        <Type>User</Type>
        <Translation>descrição</Translation>
      </Entry>
      <Entry>
        <Message>Description</Message>
        <Type>User</Type>
        <Translation>Descrição</Translation>
      </Entry>
      <Entry>
        <Message>Client ID</Message>
        <Type>User</Type>
        <Translation>ID da Companhia</Translation>
      </Entry>
      <Entry>
        <Message>Client Id.</Message>
        <Type>User</Type>
        <Translation>Id da Companhia.</Translation>
      </Entry>
      <Entry>
        <Message>Client Id: Tag</Message>
        <Type>User</Type>
        <Translation>Id da Companhia: Marcação</Translation>
      </Entry>
      <Entry>
        <Message>Filters</Message>
        <Type>User</Type>
        <Translation>Filtros</Translation>
      </Entry>
      <Entry>
        <Message>Filter by</Message>
        <Type>User</Type>
        <Translation>Filtrado por</Translation>
      </Entry>
      <Entry>
        <Message>Filter User Gender</Message>
        <Type>User</Type>
        <Translation>Filtro de Gênero do Usuário</Translation>
      </Entry>
      <Entry>
        <Message>Hide filters</Message>
        <Type>User</Type>
        <Translation>Esconder filtros</Translation>
      </Entry>
      <Entry>
        <Message>Applications</Message>
        <Type>User</Type>
        <Translation>Aplicativos</Translation>
      </Entry>
      <Entry>
        <Message>Application</Message>
        <Type>User</Type>
        <Translation>Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>name</Message>
        <Type>User</Type>
        <Translation>nome</Translation>
      </Entry>
      <Entry>
        <Message>Name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>Connection name</Message>
        <Type>User</Type>
        <Translation>Nome da conexão</Translation>
      </Entry>
      <Entry>
        <Message>Connection Name</Message>
        <Type>User</Type>
        <Translation>Nome da Conexão</Translation>
      </Entry>
      <Entry>
        <Message>Keys</Message>
        <Type>User</Type>
        <Translation>Chaves</Translation>
      </Entry>
      <Entry>
        <Message>Enabled?</Message>
        <Type>User</Type>
        <Translation>Habilitado ?</Translation>
      </Entry>
      <Entry>
        <Message>type</Message>
        <Type>User</Type>
        <Translation>tipo</Translation>
      </Entry>
      <Entry>
        <Message>Type</Message>
        <Type>User</Type>
        <Translation>Tipo</Translation>
      </Entry>
      <Entry>
        <Message>Event Description</Message>
        <Type>User</Type>
        <Translation>Descrição do Evento</Translation>
      </Entry>
      <Entry>
        <Message>Event</Message>
        <Type>User</Type>
        <Translation>Evento</Translation>
      </Entry>
      <Entry>
        <Message>File name</Message>
        <Type>User</Type>
        <Translation>Nome do arquivo</Translation>
      </Entry>
      <Entry>
        <Message>File Name</Message>
        <Type>User</Type>
        <Translation>Nome do Arquivo</Translation>
      </Entry>
      <Entry>
        <Message>ClassName</Message>
        <Type>User</Type>
        <Translation>Nome da Classe</Translation>
      </Entry>
      <Entry>
        <Message>Class name</Message>
        <Type>User</Type>
        <Translation>Nome da classe</Translation>
      </Entry>
      <Entry>
        <Message>Class Name</Message>
        <Type>User</Type>
        <Translation>Nome da Classe</Translation>
      </Entry>
      <Entry>
        <Message>Method name</Message>
        <Type>User</Type>
        <Translation>Nome do método</Translation>
      </Entry>
      <Entry>
        <Message>Method Name</Message>
        <Type>User</Type>
        <Translation>Nome do Método</Translation>
      </Entry>
      <Entry>
        <Message>Delete</Message>
        <Type>User</Type>
        <Translation>Apagar</Translation>
      </Entry>
      <Entry>
        <Message>DELETE</Message>
        <Type>User</Type>
        <Translation>APAGAR</Translation>
      </Entry>
      <Entry>
        <Message>Delete permanently</Message>
        <Type>User</Type>
        <Translation>Apagar permanentemente</Translation>
      </Entry>
      <Entry>
        <Message>Deleted</Message>
        <Type>User</Type>
        <Translation>Apagado</Translation>
      </Entry>
      <Entry>
        <Message>Database version</Message>
        <Type>User</Type>
        <Translation>Versão do banco de dados</Translation>
      </Entry>
      <Entry>
        <Message>API version</Message>
        <Type>User</Type>
        <Translation>Versão da API</Translation>
      </Entry>
      <Entry>
        <Message>Default repository</Message>
        <Type>User</Type>
        <Translation>Repositório padrão</Translation>
      </Entry>
      <Entry>
        <Message>Custom email regular expression</Message>
        <Type>User</Type>
        <Translation>Expressão regular personalizada de email</Translation>
      </Entry>
      <Entry>
        <Message>Enable tracing</Message>
        <Type>User</Type>
        <Translation>Ativar rastreamento</Translation>
      </Entry>
      <Entry>
        <Message>confirm</Message>
        <Type>User</Type>
        <Translation>confirmar</Translation>
      </Entry>
      <Entry>
        <Message>Confirm</Message>
        <Type>User</Type>
        <Translation>Confirmar</Translation>
      </Entry>
    </Translations>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[<P>&nbsp;</P>]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>IdiomaExemploPT</Value>
    </Property>
    <Property>
      <Name>ISOLangCode</Name>
      <Value>PT</Value>
    </Property>
    <Property>
      <Name>ISOCountryCode</Name>
      <Value>BR</Value>
    </Property>
    <Property>
      <Name>Codepage</Name>
      <Value>1252</Value>
    </Property>
    <Property>
      <Name>LangDateFormat</Name>
      <Value>POR</Value>
    </Property>
    <Property>
      <Name>LangTimeFormat</Name>
      <Value>24</Value>
    </Property>
    <Property>
      <Name>LangDecimalPoint</Name>
      <Value>,</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Folder

### Molde sanitizado de Folder 1 - `PastaRefinamentoExemplo`

- Perfil: `Folder` minimo com apenas `Name` e propriedades basicas.
- Uso operacional: boa referencia para pastas simples de organizacao sem metadados extras.
- Evidência direta: a validacao posterior no acervo real confirmou que este shape minimo e coerente com exemplos reais de `Folder`.
- Inferência forte: a divergencia observada na bateria, em que a IDE exibiu o objeto como `Category`, nao invalida este molde; por enquanto ela deve ser lida como diferenca de reconhecimento semantico/nomenclatura da IDE.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-03-27T23:17:35.0000000Z" checksum="66a8ea763f94ed342bd2726191bed7a0" fullyQualifiedName="PastaRefinamentoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="91314acb-c530-4e3e-9b94-db33281c99bf" name="PastaRefinamentoExemplo" type="00000000-0000-0000-0000-000000000006" description="Pasta Refinamento Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PastaRefinamentoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Folder 2 - `PastaProgramasPrincipaisExemplo`

- Perfil: `Folder` com propriedades adicionais como `ShowInModelTree`, `Query` e flags textuais.
- Uso operacional: boa referencia para pastas funcionais e de agrupamento visivel na arvore do modelo.
- Evidência direta: esse perfil continua coerente com os exemplos reais da pasta `Folder` consultada depois da bateria.
- Inferência forte: quando o objetivo for apenas criar uma pasta simples, preferir o molde 1; usar este molde 2 apenas quando as propriedades adicionais forem realmente exigidas.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-09-03T20:49:42.0000000Z" checksum="55629d2ccd74c89a2b72536ff9c3b4c2" fullyQualifiedName="PastaProgramasPrincipaisExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="a7ccc3ad-5574-4898-9a1d-c6b74633f3d1" name="PastaProgramasPrincipaisExemplo" type="00000000-0000-0000-0000-000000000006" description="Pasta Programas Principais Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PastaProgramasPrincipaisExemplo</Value>
    </Property>
    <Property>
      <Name>ShowInModelTree</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Query</Name>
      <Value />
    </Property>
    <Property>
      <Name>Properties</Name>
      <Value>main_program=true</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Stencil

### Molde sanitizado de Stencil 1 - `StencilCardResumoExemplo`

- Perfil: `Stencil` com `Source` rico em `Controls`, `Screenshot` embutido e bloco visual de card.
- Uso operacional: boa referencia para stencils declarativos que embutem layout visual completo em `CDATA`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:33:55.0000000Z" checksum="5c96cea3449e70000bfeb99a5623d2fa" fullyQualifiedName="StencilCardResumoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="744d7301-c4c1-46af-afdf-5e55bcb4ae80" name="StencilCardResumoExemplo" type="624a8b31-36f0-4292-adba-2d270d1e3537" description="Stencil Card Resumo Exemplo" parent="ColecaoStencilExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c68">
    <Source><![CDATA[<Root Screenshot="data:image/png;base64,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9dzlmlb3qnou97DSh88O9SMpABL8GQYAKYIBQIpgAJAiGACkCAYAKYIBQIpgAJCSDsbSDetj2OzRAPRAL7a+2uW9v1k6GFMWzopjrz8+Lr13EAA9yCf/+cQY9+y0Lu/9zX6lYJxz51c6/t8qAPQcXx7/VcEA4L0JBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAygcSjKOv+VicO/ZCAHqQjw065v0Nxur2LTH5+zMB6IFWbmzv8t7fLB0MAA5tggFAimAAkCIYAKQIBgApggFAimAAkCIYAKTsC0bf6gEA/DJ9hkT8NxoiJ60zkrHQAAAAAElFTkSuQmCC@data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAYwAAAEsCAYAAADQJYSkAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEOoAABDqAYLTCpgAAAtlSURBVHhe7dxpsFYFGcDxvjSDzbSNLZYOxLQ5U5OogTWVRWMxWTahN3JvVAJL4o4KKomEG0psV5QtF0BBBUlBzQQ1dmQJRKEQFK4oVwRTq4+VPJ2jHs9rXeFpJkbm9vvwg/e57wHu+7znnP+wXN7V8/I9r/YcvmcPAOzNu8pv/vyXCAB4O72uihAMAPZJMABIEQwAUgQDgBTBACBFMABIEQwAUtLBePr5iPmPAdARbdnR/r2/UToYD6yNaBoTcfEMADqSPmMj7lnZ/r2/0X8VjEtvj2h7EYCO5PLZggFAgmAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAygETjA3L74xLTjk5vtPrhPhWof+IObF29552j90v/vhAnDdwXjzW3nMAHCDBKGIx6NyBMWzk3XHbrAVxx5wFMXXo4Ohx5ar2j98f1kyKY77UEsvbew6AAyEYu2PWhefGRRMXxootf4/ndr/+8W0bt8bc1S//27H7kWAA7NU7H4xND0b/k0fE9KU7Y9sbsXiL3a9G66ppcX6fL8YR3Y+Nr/98SsxY/1Isu39qnHvO0BjctymO6HZcHH/2zTHzD8XxrZti7qTmOPG44vheZ8V5U9fGo+tXxjVXtMTA8wfEN48bGuMnXR0/Pf646N6tOKbb6XH+rL9G60rBANibdz4YT/wmTuvTErNX7Y5nynnBuOhx9JHxmc9+Lj5z0vRY9cLWaGnqHcPv3RgLF6+J2dPGxGn9psYdNw2Lb3Q7J4bdsSIWzp0TYy68JAaPejjmzbg5RgwbHTcvKI6fPzsGXTQ5Jt44Kfoff3r8pHlKzJn/VGzc3BZrVj0Zi5YVx9w1Onr1nhZLFl8XPQQD4G0deMF47qVYuXZrrLjn8vjCMS2xZNWk+Eqn98TBh30yunyiaxx6yGHR9fCmGDxuTPQ5c0Ysb/tntG3dFLeOGx3Ng26IawefHId/8MPxsc7F8Z0/Hh/8wJFxcvOg+MEp18b4u/4UW3btee0vuEf07xufP/xz0eWwj8RBR18d8xe1CAbAXrzzwXhhW7SccU5cNffp2LSz4eNrJkT3MhjLxsWX39s3Jm9oi3WveT7Wr98c993WEqf2u/v1f9XUujluHd8SzRe0xJXNl8RZ/W6JeW8evyv+tObeGNCvJabcvzWefvGxuKbXj2PIFXNj0ertse7BsfG1nuPiYcEA2KsD4C+9X43WeVfHj04cGJMe2B3bymisWxznffTgePcXx8bStsdjyDEfioETnom2nX+L1b+dHKeePjFm3t5OMH75m5gxcUg0n9EcMx95Jdo2L48rL50cN0y6Pvr1r4KxOoYec3EMmbotNrZFrJlwWXzkq6P9DgNgHw6AYBR2/SMenXdFfK/LIfG+TgdFpx5nxZBbRsZRPVpixe5/xpaHZkbT0Z2i0/s/HIf2Hh7jlz8fC9oLxvBH4vEtW2L68DOjW5fi+E8dG98f9ft45NH50fxmMF6N1ZNHRu8uh8b7i1/rqCO7x7u7XysYAPtwYAQDgAOeYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQsl+C0TQm4pIZAHQkPxr7Pw7G020R89cB0BFt2dH+vb9ROhgA/H8TDABSBAOAFMEAIEUwAEgRDABSBAOAFMEAIEUwAEh5MxjfLh6cOCriqR0R5ePST2+MWPrHeh4+K2LOinqePD9iwu/qufzS8mF31POjT0b8ZHI9b9sZ8f1rX398/IiIZ3fVz501IWLNU/U8ZEbE/Wvq+br7I256uJ7vXBpx1Zx6Xrgh4uc31/OmZyP6jK3n3a/Uj0+7LuKJZ+r5gmkRD62v55H3RNy2uJ6nLYwYPa+eH1wXMfi2el6/LeKM8fW886X68UnFTsuvoKzmnxU7XdKw0/L/cLlreT3/ekHE9Q/U87xVEUNvr+eVmyP6Nuy0tdjpCW/s9LvFTrc37PTsiRGrt9TzL2ZG3Le6nq/7bbHTh+p51rKIKxt2uqjY6YCGnT5Z7PSHY+p518v149d22lrPF0wvdvpYPY+c+9adTi92Oqr4WDWXX2k66NZ63utORxc7fa6ef3bTW3d6xV0Rs4vXUs2pnU6q59YXIr53zeuPy++fKebquXOK41YVx1fzpcVO723Y6fhipzf++06Lz6eaF2+MOK/4fKt5c/E6morXU80vNLzO04udPt6w0wuLnS5o2Gm5v+mL6vnW4vGvGnZaHlv+mGouf67y56zmxl+rfF/L97eaBxSf46Lic63m8jWUr6Way9dYvtZqLndQ7qKay/OuPP+quTwvv/vGTk8ovi93XD1X7r58D6q5fG/K96iay/eufA+rubxeyuummsv3vjwHqrk8N8pzpJobz53ynCrPrWouz7ny3KvmUcV1Xp6b1Vyes+W5W83lOV2e29Vc3kfKc7+aG6+J/9hpcS2V11Q1l9da407La7G8z1XzfcX9r7xmq7ndnRbXfPm4vAeU94LqufIe0bjTy4r78tzi/lzNNxT37Sn72mlxr6rm8h5W9qHncL/DACDBH0kBkCIYAKQIBgApggFAimAAkCIYAKQIBgAp6WBs2L4jblkyG4AOaH3r9nbv/Y3SwZi+7O7oPLhrNE08E4AOpOvFn47Jv5/R7r2/0X8VjN7XnxptLwYAHcgpU/oKBgD7JhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApOyXYHQe3DWaJp4JQAfS9eJP/2+DsWH7jrhlyWwAOqD1rdvbvfc3SgcDgP9vggFAimAAkCIYAKQIBgApggFAimAAkCIYAKS8GYxvFw8A4O30HB7xL2eOWqnkP1cdAAAAAElFTkSuQmCC"><Controls><table class="card" tableType="Responsive" responsiveSizes="[]" layoutType="SD"><row><cell><table controlName="TableGeneralTitle" class="card-heading" tableType="Responsive"><row><cell><textblock controlName="TBTitleGeneral" caption="Resumo" class="attribute-label" /></cell></row></table></cell></row><row><cell><table controlName="TableDataGeneral" class="card-body" tableType="Responsive" IsSlot="True" /></cell></row></table><table class="card bg-white" tableType="Responsive" responsiveSizes="[]" layoutType="Web"><row><cell><table controlName="TableGeneralTitle" class="card-heading" tableType="Responsive"><row><cell><textblock controlName="TBTitleGeneral" caption="EXEMPLO_General" class="" /></cell></row></table></cell></row><row><cell><table controlName="TableDataGeneral" class="card-body" tableType="Responsive" IsSlot="True" /></cell></row></table></Controls></Root>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>EXEMPLO_DataCard</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>GAM Data  Card</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>ColecaoStencilExemplo-web</Categories>
</Object>
```

### Molde sanitizado de Stencil 2 - `StencilCabecalhoListaExemplo`

- Perfil: `Stencil` de cabecalho com acoes, busca, imagem e variavel declarada.
- Uso operacional: boa referencia para stencils com controles interativos e `Variables` embutidas.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:34:41.0000000Z" checksum="9d5d14b2efafae0b5b00b33d3e8ec0a1" fullyQualifiedName="StencilCabecalhoListaExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="39ae3b48-9e9f-4ae8-ae2c-94a0ac238a4b" name="StencilCabecalhoListaExemplo" type="624a8b31-36f0-4292-adba-2d270d1e3537" description="Stencil Cabecalho Lista Exemplo" parent="ColecaoStencilExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c68">
    <Source><![CDATA[<Root Screenshot="data:image/png;base64,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@data:image/png;base64,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1pkzZyq8ed6N3CuuPTt3XnOd3MGYOy9G8+YvrmIWEYzKhGCgMruYna39qanat3dvaTTu5pWGe2Vx6NCh0j9tXpyVVeH1Am4qgoHKrsSJRu62bdoQF6cVsbF3rbiVK5UcH08scPsQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAcMfbEauFQUEKG79Ipyraf6skztGYt5uo9u9/r6dLNZLnqLU6mlrBsT9E8hLNGRakL6cu0+mK9t9sBAPAHW97jCJdLn0+/GsVVLT/VtkSroHvfKoJY2doZ1yccub4q2Nrf8Wv366LFR3/fSVFaVIfl8aGLNTJivZ/p2wVrRypTq1Ha3+F+w0IBoA71elV0dowZpw2RlWiYLzr0pzZcTrrfpw1S75/+kBzYzfrfPljf4h/Mxjnl7rUuJ6/9rgfp27XwbBABU2ar0PXHXsDBAPAHSd1q5LHD5Fn646aEB6tQ0lXguHtq8D+n6rjGy1U88+P6dl2PeTq0VG1nqyrtgPDtHd7mjS3n7o8Xk2/uv9+PXD/C/p4cpouO3OWrBisj150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"><Controls><table class="Flex" tableType="Responsive" responsiveSizes="[]" layoutType="SD"><row><cell cellClass="stack-bottom-xxl"><table controlName="TableActions" tableType="Flex" justifyContent="Flex End"><row rowHeightWeb="61px"><cell><textblock controlName="Title" caption="Title" class="Title" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0"><action controlName="AddNew" onClickEvent="'AddNew'" caption="Adicionar" class="button" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0"><data attribute="&amp;Search" labelPosition="None" labelCaption="" class="AttributeSearch" inviteMessage="Tente uma busca" controlNameForStencil="&amp;Search" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;AutoResize&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value&gt;30chr&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell hAlign="Right" flexGrow="0" alignSelf="Center"><image controlName="ToggleFilters" image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-PageLast" class="Image-20" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;eventGX&lt;/Name&gt;&lt;Value&gt;'Hide'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;width&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;title&lt;/Name&gt;&lt;Value&gt;GXM_first&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row></table><table class="" tableType="Responsive" responsiveSizes="[]" layoutType="Web"><row><cell cellClass="stack-bottom-xxl"><table controlName="TableActions" tableType="Flex" flexWrap="Wrap" justifyContent="Flex End" alignItems="Center"><row rowHeightWeb="61px"><cell minHeight="30"><textblock controlName="Title" caption="EXEMPLO_Titulo" class="Title" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0" minHeight="30"><action controlName="AddNew" onClickEvent="'AddNew'" caption="EXEMPLO_Adicionar" class="button Primary" /></cell><cell cellControlName="CellSearch" cellClass="" hAlign="Right" flexGrow="0" minHeight="30"><data attribute="&amp;Search" labelPosition="None" labelCaption="" class="AttributeSearch" inviteMessage="EXEMPLO_TenteUmaBusca" controlNameForStencil="&amp;Search" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;AutoResize&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value&gt;30chr&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell cellClass="inline-left-xl" hAlign="Right" flexGrow="0" minHeight="30"><image controlName="ToggleFilters" image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-TemaExemplo.filter" class="Image-20 color-primary" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;eventGX&lt;/Name&gt;&lt;Value&gt;'Hide'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;width&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;title&lt;/Name&gt;&lt;Value&gt;Filters&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row></table></Controls><Variables><Variable Name="Search"><Properties><Property><Name>Name</Name><Value>Search</Value></Property><Property><Name>OBJ_TYPE</Name><Value>id_OTYPE_VAR</Value></Property><Property><Name>idBasedOn</Name><Value>Domain:GAMUserIdentification, SegurancaExemplo</Value></Property></Properties></Variable></Variables></Root>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>EXEMPLO_HeaderWW</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>GAM Header WW</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>ColecaoStencilExemplo-web</Categories>
</Object>
```

## Moldes sanitizados completos de File

### Molde sanitizado de File 1 - `ArquivoImagemExemplo_gif`

- Perfil: `File` curto com `base64Binary` pequeno e propriedades de extracao em `Resources`.
- Uso operacional: boa referencia para assets binarios compactos acoplados ao pacote.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2024-09-28T20:51:45.0000000Z" checksum="b667dcf6150444093ca6130acc038fd1" fullyQualifiedName="ArquivoImagemExemplo_gif" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f33ac53a-282e-491b-b748-79f213e2dbe6" name="ArquivoImagemExemplo_gif" type="1132ac08-290f-4fd1-bd18-64777b7329d1" description="Arquivo Imagem Exemplo">
  <Part type="9b6155f9-f286-4ed5-bd15-67672e8ea320">
    <Data>
      <base64Binary>R0lGODlhCgBQAIAAAAAAAP///yH5BAUUAAEALAAAAAAKAFAAAAIahI+py+0Po5y02ouz3rz7D4biSJbmiabqihUAOw==</base64Binary>
    </Data>
    <Properties>
      <Property>
        <Name>FileName</Name>
        <Value>imagem-exemplo.gif</Value>
      </Property>
      <Property>
        <Name>FileExtension</Name>
        <Value>.gif</Value>
      </Property>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ArquivoImagemExemplo_gif</Value>
    </Property>
    <Property>
      <Name>NetExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetExtractFolder</Name>
      <Value>Resources\\arquivo-exemplo</Value>
    </Property>
    <Property>
      <Name>NetCoreExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetCoreExtractFolder</Name>
      <Value>Resources\\arquivo-exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de File 2 - `ArquivoConfiguracaoExemplo_props`

- Perfil: `File` textual pequeno em `.props`, ainda armazenado via `base64Binary`.
- Uso operacional: boa referencia para arquivos de configuracao e apoio a build com extracao controlada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-05-14T20:38:37.0000000Z" checksum="c60dc61999093d19c1b8571fb805f188" fullyQualifiedName="ArquivoConfiguracaoExemplo_props" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f818bc6d-1bb8-4459-88f4-4c781953252f" name="ArquivoConfiguracaoExemplo_props" type="1132ac08-290f-4fd1-bd18-64777b7329d1" description="ArquivoConfiguracaoExemplo.props">
  <Part type="9b6155f9-f286-4ed5-bd15-67672e8ea320">
    <Data>
      <base64Binary>PFByb2plY3Q+DQoJPEl0ZW1Hcm91cD4NCgkJPFBhY2thZ2VSZWZlcmVuY2UgSW5jbHVkZT0iQm91bmN5Q2FzdGxlLkNyeXB0b2dyYXBoeSIgVmVyc2lvbj0iMi40LjAiLz4NCgkJPFBhY2thZ2VSZWZlcmVuY2UgSW5jbHVkZT0iU3lzdGVtLlNlY3VyaXR5LkNyeXB0b2dyYXBoeS5YbWwiIFZlcnNpb249IjguMC4wIi8+DQoJPC9JdGVtR3JvdXA+DQo8L1Byb2plY3Q+</base64Binary>
    </Data>
    <Properties>
      <Property>
        <Name>FileName</Name>
        <Value>ArquivoConfiguracaoExemplo.props</Value>
      </Property>
      <Property>
        <Name>FileExtension</Name>
        <Value>.props</Value>
      </Property>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ArquivoConfiguracaoExemplo_props</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>SignXml.props</Value>
    </Property>
    <Property>
      <Name>NetCoreExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetCoreExtractFolder</Name>
      <Value>..\\build-exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```
