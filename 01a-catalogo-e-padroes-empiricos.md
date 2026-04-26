# 01a - Catalogo e Padroes Empiricos

## Papel do documento
empirico

## Objetivo
Concentrar panorama do acervo, catalogo observado de tipos, padroes recorrentes e limites gerais de leitura estrutural.

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
| `Domain` | 593 | `00972a17-9975-449e-aab1-d26165d51393` | `Evidência direta` |
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

### Persistencia real de propriedades em `WebPanel`

- `Evidência direta`: numa releitura operacional posterior de `1197` `WebPanel`, os `7` `Part type` recorrentes do tipo continuaram presentes em `100%` dos casos.
- `Evidência direta`: o `Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778"` concentrou o layout declarativo e a quase totalidade das propriedades estruturais de controle observadas nesta frente.
- `Evidência direta`: `PATTERN_ELEMENT_CUSTOM_PROPERTIES` apareceu em `411/1197` `WebPanel`, sempre no `Source` do `Part` de layout.
- `Evidência direta`: `WebUserControlProperties` apareceu em `172/1197` `WebPanel`, sempre no `Source` do `Part` de layout.
- `Evidência direta`: `ControlWhere` apareceu em `101/1197` casos; `100` deles vieram do `Part` de layout, serializados dentro de propriedades de controle, e `1` caso apareceu em `Part` de variáveis.
- `Evidência direta`: `ControlBaseTable` apareceu em `23/1197`, `ControlOrder` em `86/1197` e `ControlUnique` em `13/1197`; nesses casos, a persistência observada ficou concentrada no `Source` do `Part` de layout, dentro de metadado serializado de controles.
- `Evidência direta`: o `Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9"` apareceu em `1197/1197` `WebPanel`, mas só `141` casos tinham `Source` nao vazio nesse `Part`.
- `Evidência direta`: `Conditions` como filtro materializado apareceu nesses `141` casos via `Source` do `Part` `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`, e nao como atributo do layout.
- `Evidência direta`: a busca textual por `Conditions` supercontou casos de template, porque `183` objetos usavam `ViewConditions.dkt` e `179` usavam `TabGridConditions.dkt` apenas em metadado de `Defaults`.
- `Evidência direta`: em `Prompt`/`Selection List`, a materializacao de filtro no `Part` de `Conditions` foi forte: `92/100` `prompt*` tinham `Source` nao vazio nesse `Part`, e os `30` casos com `Selection List` pertenciam a essa familia.
- `Evidência direta`: em `FreeStyleGrid`, houve `10` casos; todos tinham `ControlWhere` no layout, `8/10` tinham `ControlOrder` e `9/10` tinham `WebUserControlProperties`.
- `Evidência direta`: em grids tradicionais com tag `<grid`, houve `26` casos; `16` com `ControlWhere`, `9` com `ControlBaseTable`, `14` com `ControlOrder` e `5` com `ControlUnique`.
- `Evidência direta`: em controles com `Dynamic Combo Box`, houve `58` casos; `56` deles coexistiam com `ControlWhere` no layout e `50` com `WebUserControlProperties`.
- `Exemplo sanitizado`: `WPExemploSelectionPromptA` mostra `Selection List` com filtro materializado no `Part` de `Conditions`, enquanto `ControlOrder` e `WebUserControlProperties` permanecem no layout.
- `Exemplo sanitizado`: `WPExemploGridEstruturalA` mostra grid tradicional com `ControlBaseTable`, `ControlOrder`, `ControlWhere` e `ControlUnique` serializados no layout.
- `Exemplo sanitizado`: `WPExemploComboDinamicoA` mostra `Dynamic Combo Box` com `ControlWhere` persistido no layout e configuracao adicional em `WebUserControlProperties`.
- `Exemplo sanitizado`: `WPExemploGridLivreA` mostra `FreeStyleGrid` com filtro persistido no layout via `ControlWhere`, junto com metadado adicional de controle no mesmo `Part`.
- `Exemplo sanitizado`: `WPExemploConditionsTemplateA` mostra caso em que o termo `Conditions` aparece so por `Defaults` de template, sem filtro materializado no `Source` do `Part` de condicoes.
- `Inferência forte`: para `WebPanel`, "a propriedade existe no XML" e "a propriedade persiste no mesmo lugar em todas as familias" sao afirmacoes diferentes; o ponto de persistencia varia por familia e por tipo de controle.
- `Inferência forte`: para trilha `xpz-*`, a leitura segura e distinguir pelo menos `Conditions` materializado em `Part` proprio, metadado de layout serializado e defaults de template antes de decidir clonagem, comparacao ou documentacao.

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
- `Evidência direta`: arquivos como `KBExemplo18selectAttributes.Filters` se mostraram apenas configuracoes auxiliares de filtro/interface, nao export de objeto `Attribute`.
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
- `Evidência direta`: a distribuicao observada foi `2282` `Procedure`, `594` `SDT`, `593` `Domain`, `228` `Table`, `183` `Transaction`, `24` `DataProvider` e `1` `API`.
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





