# 03 - Risco e Decisao por Tipo

## Papel do documento
operacional e heuristico

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md

## Usado por
08-guia-para-agente-gpt.md

## Objetivo
Reunir obrigatoriedade heuristica, prontidao relativa e mapa de risco por tipo para orientar decisao operacional conservadora.

## Fontes consolidadas
- 21-indicios-de-obrigatoriedade.md
- 22-tipos-prontos-para-geracao-conservadora.md
- 23-mapa-de-risco-por-tipo.md

## Origem incorporada - 21-indicios-de-obrigatoriedade.md

## Papel do documento
empírico

## Nível de confiança predominante
baixo

## Depende de
10-matriz-part-types-por-tipo.md, 12-diffs-estruturais-por-tipo.md

## Usado por
22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Registrar indícios comparativos de obrigatoriedade, opcionalidade e vazio estrutural de `Part type`.
Preservar explicitamente o caráter heurístico dessas leituras.

- Evidência direta: percentuais abaixo saem da frequencia de Part type por tipo extraído.
- Inferência forte: aparentemente obrigatorio significa presenca em ~100% das amostras do tipo nesta KB.
- Hipótese: so teste real de importacao pode transformar isso em obrigatoriedade comprovada.

## API

- Evidência direta: total de objetos analisados: 1.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## DataProvider

- Evidência direta: total de objetos analisados: 24.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## DesignSystem

- Evidência direta: total de objetos analisados: 2.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## PackagedModule

- Evidência direta: total de objetos analisados: 16.
- Evidência direta: Part type com forte indicio de obrigatoriedade: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: a5e6a251-2df0-44d8-adab-1da237574326.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## Panel

- Evidência direta: total de objetos analisados: 7.
- Evidência direta: Part type com forte indicio de obrigatoriedade: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## Procedure

- Evidência direta: total de objetos analisados: 2281.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## SDT

- Evidência direta: total de objetos analisados: 594.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## Theme

- Evidência direta: total de objetos analisados: 7.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## Transaction

- Evidência direta: total de objetos analisados: 183.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## WebPanel

- Evidência direta: total de objetos analisados: 1196.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.

## WorkWithForWeb

- Evidência direta: total de objetos analisados: 183.
- Evidência direta: Part type com forte indicio de obrigatoriedade: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.



## Origem incorporada - 22-tipos-prontos-para-geracao-conservadora.md

## Papel do documento
operacional

## Nível de confiança predominante
baixo

## Depende de
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md, 04-genexus-open-points.md

## Objetivo
Classificar os tipos prioritários sob uma leitura estritamente conservadora de prontidão relativa.
Evitar que “melhor candidato” seja confundido com “tipo comprovadamente seguro”.

- Evidência direta: a classificacao abaixo considera quantidade de objetos, media de Part, dependencia de parent/module e presenca de pattern no acervo extraído.
- Inferência forte: "pronto" aqui significa apenas "melhor candidato relativo para experimentacao controlada por clonagem", nao tipo comprovadamente importavel.
- Evidência direta: a trilha ja contem bateria controlada de importacao real a partir de `.xpz` montados com base nos `.md` locais e no skill `nexa`.
- Inferência forte: isso nao transforma nenhum tipo em "definitivamente seguro", mas ja separa tipos com envelope comprovado dos tipos que ainda dependem de contexto real da KB.

| FolderType | Classification | Evidence | Reading |
| --- | --- | --- | --- |
| API | apto somente por clonagem muito controlada | 1 objeto; media de Part = 5; parent = 1; pattern = 0 | amostra pequena demais e dependencia contextual presente |
| DataProvider | apto somente por clonagem muito controlada | 24 objetos; media de Part = 5; parent = 24; pattern = 0 | parent aparece em 100% dos casos observados |
| DesignSystem | apto somente por clonagem muito controlada | 2 objetos; media de Part = 4; parent = 1; pattern = 0 | amostra pequena demais para liberar geracao conservadora |
| PackagedModule | apto somente por clonagem muito controlada | 16 objetos; media de Part = 2.38; parent = 2; pattern = 0 | e o melhor candidato relativo do recorte, mas ainda sem teste externo |
| Panel | apto somente por clonagem muito controlada | 7 objetos; media de Part = 2; parent = 7; pattern = 7 | dependencia simultanea de parent e pattern em 100% das amostras |
| Procedure | apto somente por clonagem muito controlada | 2281 objetos; media de Part = 7; parent = 2281; pattern = 0 | estrutura recorrente forte, mas parent em 100% e alta fragmentacao interna |
| SDT | apto somente por clonagem muito controlada | 594 objetos; media de Part = 2; parent = 591; pattern = 0 | baixa contagem de Part nao elimina dependencia estrutural de parent |
| Theme | apto somente por clonagem muito controlada | 7 objetos; media de Part = 3; parent = 0; pattern = 0 | sem muita dependencia contextual aparente, mas a amostra ainda e pequena |
| Transaction | apto por clonagem baseada em padrao estrutural inferido (decisao operacional) | 183 objetos; media de Part = 8; parent = 183; pattern = 0 | ha massa critica suficiente para trabalhar por familia estrutural interna, com erro tratado incrementalmente |
| WebPanel | apto por clonagem baseada em familia estrutural (alta variabilidade; requer molde interno proximo) | 1196 objetos; media de Part = 7; parent = 1195; pattern = 0 | ha massa critica suficiente para escolher molde interno proximo, sem tratar WebPanel como estrutura unica |
| WorkWithForWeb | apto somente com contexto completo de pattern e `Transaction` comparável | 183 objetos; media de Part = 2; parent = 183; pattern = 183 | o risco continua alto, mas a trilha posterior mostrou importacao bem-sucedida quando o XML usa o convenio estrutural real do pattern |

## Leitura conservadora

- Evidência direta: a trilha ja contem evidência de importacao real bem-sucedida para varios tipos, usando somente os `.md` locais como base documental combinados com o skill `nexa`.
- Inferência forte: `PackagedModule` deixou de ser apenas candidato relativo e passou a ter importacao bem-sucedida como `Module` em caso controlado.
- Inferência forte: `Transaction` continua desbloqueada para execucao controlada, mas o teste real mostrou dependencia de atributos e tipos de contexto existentes na KB.
- Evidência direta: `Transaction` com atributos inexistentes na KB falhou na validacao mesmo quando o shape do `Level` estava no caminho correto.
- Inferência forte: o risco de `Transaction` nao esta apenas no envelope ou no shape, mas tambem na existencia previa ou inclusao explicita de `Attribute` top-level.
- Regra operacional: tratar ausencia de `Attribute` top-level correspondente como bloqueio operacional do pacote, e nao apenas como dependencia semantica secundaria.
- Inferência forte: `WorkWithForWeb` permanece na zona de maior cautela por depender de `Transaction` pai real.

## Decisao operacional provisoria

- Evidência direta: `Transaction` possui 183 exemplos no acervo e `WebPanel` possui 1196.
- Inferência forte: esse volume e suficiente para parar de bloquear execucao apenas por falta de evidencia amostral.
- Inferência forte: para `Transaction`, a estrategia preferida passa a ser clonagem por familia estrutural inferida.
- Inferência forte: para `WebPanel`, a estrategia preferida passa a ser clonagem por familia estrutural interna, com selecao cuidadosa de template proximo.
- Hipótese: os erros de importacao que surgirem devem ser tratados como feedback para refinar estes documentos, e nao como prova de inviabilidade geral do tipo.

## Evidencia complementar - bateria controlada de importacao

## Papel da bateria
empirico complementar

## Objetivo
Registrar o que foi efetivamente reconhecido pela IDE em importacoes reais de `.xpz` de teste montados a partir desta base documental e do skill `nexa`.
Separar falha de envelope/shape de falha por dependencia semantica da KB.

- Evidência direta: o criterio de classificacao abaixo considera o texto retornado pela propria importacao, confirmando nome e tipo reconhecidos quando isso apareceu no log.
- Evidência direta: os testes desta bateria usaram somente os `.md` desta pasta em conjunto com o skill `nexa`; nao usaram `C:\Dropbox\Backups\Gx_Kbs` nem outras bases externas.
- Inferência forte: quando a importacao falha por objeto pai, atributo, `ATTCUSTOMTYPE`, package ou pattern inexistente, o envelope XML esta mais forte do que o contexto semantico do caso.

## Tipos com importacao bem-sucedida e tipo coerente

- `Procedure`
- `Domain`
- `SDT`
- `Data Provider`
- `Subtype Group`
- `Module`
- `External Object`
- `Data Store`
- `Generator`
- `Panel`
- `Image`
- `Theme Color`
- `Document`
- `File`
- `Language`
- `Color Palette`
- `Dashboard`
- `User Control`
- `Stencil`

## Tipos que exigem contexto real da KB ou familia funcional ampliada

- `API`: o risco atual esta concentrado numa subarvore funcional grande, envolvendo `Procedure`, `Data Provider`, `Domain`, `Transaction`, `Table`, `SDT` e atributos de negocio reais.
- `Transaction`: o tipo esta destravado, mas depende de atributos reais do `Level` e dos SDTs de contexto corretos, como `Context` e `TransactionContext`.
- `Data Selector`: o tipo pode importar em caso controlado, mas continua sensivel a atributos, filtros e funcoes realmente existentes na KB.
- `Index`: a evidência consolidada mostra `Index` como estrutura embutida em `Table`, nao como familia top-level independente nesta trilha de export.
- `Deployment Unit`: o tipo depende da lista completa de `Member` existir e ser coerente no destino.
- `Theme Class`: o tipo depende da hierarquia visual correta e do contexto de tema/classe pai quando houver heranca ou derivacao.
- `Design System`: o tipo pode importar em caso controlado, mas continua sensivel a imports, pacotes e contexto visual do ambiente.
- `Work With for Web`: o tipo esta destravado quando usa o convenio estrutural real do pattern e `Transaction` comparavel, mas continua exigindo contexto completo de pattern.

## Tipos com leitura consolidada especial

- `Folder`: tratar como tipo XML estruturalmente valido; `Category` e apenas o rotulo exibido pela IDE/importador.
- `Pattern Settings`: o tipo esta destravado em caso real compativel; o risco residual passa a ser compatibilidade do pattern no ambiente.
- `Attribute`: o shape top-level esta provado; o risco residual esta em propriedades semanticas como `ControlItemDescription`, `idBasedOn` e outras referencias nominais a atributos reais.
- `Theme`: o tipo esta destravado quando acompanhado pelas `ThemeClass` exigidas pelo proprio grafo visual.

## Leitura operacional apos a bateria

- Evidência direta: os `.md` locais, combinados com o skill `nexa`, sustentam uma faixa relevante de tipos autocontidos e estruturais com importacao real.
- Inferência forte: a principal fronteira atual nao e mais o contêiner `.xpz`, e sim a dependencia de contexto real da KB em tipos que exigem pai, atributos, pattern, package, `EXO`, `SDT` ou membros existentes.
- Inferência forte: os tipos em sucesso coerente passam a ter prioridade maior como fonte segura para agente/GPT nesta base.
- Inferência forte: os tipos com falha contextual pedem complemento por exemplos reais ou regra documental mais especifica, e nao simples extrapolacao a partir do envelope minimo.
- `Inferência forte`: `Transaction`, `Theme` e `PatternSettings` deixaram de ser pendencias estruturais abertas nesta trilha; agora ja possuem receita empirica de sucesso sob dependencias explicitas conhecidas.
- `Evidência direta`: um pacote composto posterior reuniu `ThemeClass`, `Theme`, `Attribute`, `SDT`, `Transaction` e `Pattern Settings` no mesmo `.xpz` e importou com sucesso, incluindo geracao de pattern para `WWExemploMinBancoA`.
- `Inferência forte`: a base ja nao prova apenas sucessos isolados por tipo; ela tambem sustenta composicao entre tipos resolvidos quando as dependencias explicitas entram juntas no pacote.
- `Inferência forte`: `API` permanece como pendencia principal, mas seu risco residual ja nao esta em `ATTCUSTOMTYPE`; ele foi deslocado para uma subarvore funcional de negocio, envolvendo `Procedure`, `Data Provider`, `Domain`, `Transaction` e atributos reais da KB.
- `Evidência direta`: o export real `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos, sendo `2282` `Procedure`, `594` `SDT`, `592` `Domain`, `228` `Table`, `183` `Transaction`, `24` `DataProvider` e `1` `API`.
- `Inferência forte`: isso confirma que, para `API`, o recorte de risco correto e uma familia funcional grande; tentar trata-la como tipo quase isolado tende a subestimar a dependencia real.
- `Evidência direta`: o export real `XPZExemploTemaA.xpz` veio com `947` objetos, incluindo `501` `ThemeClass`, `7` `Theme`, `24` `ThemeColor`, `2` `DesignSystem`, `1` `ColorPalette`, `228` `Table`, `183` `Transaction` e `1` `Folder`.
- `Inferência forte`: para a pilha visual, o risco melhora quando a analise e feita por familia combinada (`Theme` + `ThemeClass` + `DesignSystem` + `ColorPalette` + `ThemeColor`), e nao por objeto visual totalmente isolado.
- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades.
- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Inferência forte`: isso mostra que a familia `Attribute` + `Transaction` + `Domain` + `SubtypeGroup` tambem existe como recorte combinado relevante da IDE, com `Attributes` top-level preservados no mesmo `.xpz`.
- `Inferência forte`: para `Attribute`, o risco residual continua semanticamente contextual, mas o formato multiobjeto observado com bloco `Attributes` deixa de ser lacuna relevante nesta trilha.

## Hierarquia de ataque das pendencias contextuais

- Evidência direta: `Transaction` e `API` concentraram erros semanticos claros, apesar de o envelope ter passado da fase principal de parse/importacao.
- Inferência forte: a ordem mais util de ataque e `Transaction -> API -> Theme -> Pattern Settings -> Folder`.
- Inferência forte: `API` vem logo depois de `Transaction` porque compartilha o mesmo tipo de fragilidade principal: dependencia de tipos e referencias reais da KB.
- Inferência forte: em `API`, a hierarquia correta de decisao e `ATTCUSTOMTYPE` valido -> `EXO` e `SDT` existentes -> `Procedure` chamada -> `Data Provider`/`Domain` auxiliares -> atributos e contexto de negocio -> eventos/codigo.
- Inferência forte: qualquer tentativa de corrigir `API` pelo fim, mexendo primeiro em codigo ou serializacao, tende a mascarar a causa real do erro.
- Inferência forte: `Theme` vem em seguida porque seu problema principal ja esta isolado e nao depende tanto de semantica de negocio da KB, mas sim de preservar o grafo minimo de classes visuais.
- Inferência forte: em `Theme`, a hierarquia correta de decisao e `PredefinedTypes e Styles -> classes base existentes -> referencias internas entre classes -> simplificacao visual`.
- Inferência forte: qualquer tentativa de reduzir `Theme` sem mapear antes as referencias entre classes tende a repetir o erro de `TableDetail`, `TableSection` e `TextBlockGroupCaption` ausentes.
- `Inferência forte`: o teste isolado mostrou que esse requisito de ambiente pode ser satisfeito materializando as `ThemeClass` auxiliares necessarias.
- Inferência forte: `Pattern Settings` vem depois porque o erro principal ja foi isolado em `pattern` registrado e contexto do ambiente, nao no envelope XML.
- Inferência forte: em `Pattern Settings`, a hierarquia correta de decisao e `Pattern registrado -> ContextVariable e LoadProcedure -> Security e referencias auxiliares -> detalhe declarativo interno`.
- Inferência forte: qualquer tentativa de tratar `Pattern Settings` como objeto autocontido tende a repetir o sintoma de `was not changed` com pattern nao registrado, mas o caso real `WorkWith` ja mostrou caminho de sucesso.
- Inferência forte: `Attribute` ja nao pertence mais ao grupo de shape desconhecido; ele deve ser lido como tipo estruturalmente provado, mas dependente de propriedades que referenciam atributos reais da KB.
- `Inferência forte`: quando o `Attribute` escolhido evita referencias nominais problematicas, como `ControlItemDescription`, o tipo ja demonstrou importacao bem-sucedida nesta trilha.
- Inferência forte: `Folder` fica por ultimo porque o shape minimo ja parece estavel e o problema restante e mais de reconhecimento semantico da IDE do que de XML ou contexto pesado da KB.
- Inferência forte: em `Folder`, a hierarquia correta de decisao e `shape minimo correto -> contexto pai/modulo -> tipo exibido pela IDE`.
- Inferência forte: a diferenca `Folder` x `Category` ja ficou suficientemente esclarecida nesta trilha; novas tentativas devem tratar `Folder` como tipo XML estrutural e `Category` como rotulo de UI/importador, e nao como tipos rivais de envelope.


## Origem incorporada - 23-mapa-de-risco-por-tipo.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-regras-operacionais-e-runtime.md, 22-tipos-prontos-para-geracao-conservadora.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Sintetizar o risco estrutural relativo por tipo com base em dependência contextual, pattern e fragmentação interna.
Servir como primeira triagem operacional antes de qualquer tentativa de clonagem.

- Evidência direta: o risco abaixo combina volume de `Part`, dependencia de `parent/module`, presenca de `pattern` e tamanho da amostra observada.
- Inferência forte: o mapa e operacional para priorizacao de clonagem, nao uma escala formal de chance de sucesso em importacao.

| FolderType | StructuralRisk | ParentModuleDependency | PatternDependency | CurrentConfidence | PracticalRecommendation |
| --- | --- | --- | --- | --- | --- |
| API | alto | 1/1 | 0/1 | baixa | exigir molde bruto comparável muito proximo do caso alvo |
| DataProvider | alto | 24/24 | 0/24 | baixa | exigir molde bruto comparável muito proximo do caso alvo |
| DesignSystem | alto | 1/2 | 0/2 | baixa | exigir molde bruto comparável e evitar extrapolacao com amostra pequena |
| PackagedModule | medio | 2/16 | 0/16 | media-baixa | clonar so com diff estrutural e revisao manual forte |
| Panel | alto | 7/7 | 7/7 | baixa | exigir molde bruto comparável muito proximo do caso alvo |
| Procedure | alto | 2281/2281 | 0/2281 | baixa | exigir molde bruto comparável muito proximo e preservar todos os blocos recorrentes |
| SDT | medio | 591/594 | 0/594 | media-baixa | clonar so com template do mesmo subtipo estrutural e checagem de parent |
| Theme | medio | 0/7 | 0/7 | media-baixa | usar apenas para experimentos muito controlados e com diff manual |
| Transaction | muito alto | 183/183 | 0/183 | media | permitir geracao por padrao estrutural inferido; preservar estrutura e tratar erros incrementalmente |
| WebPanel | muito alto | 1195/1196 | 0/1196 | media-baixa | permitir geracao por familia estrutural; usar molde interno proximo; nao generalizar estrutura |
| WorkWithForWeb | muito alto | 183/183 | 183/183 | media | tentar apenas com contexto completo de pattern, `Transaction` comparavel e convenio estrutural real de atributo |

## Notas de leitura

- Evidência direta: `Transaction`, `WebPanel` e `WorkWithForWeb` combinam alta dependencia contextual com estrutura relativamente rica ou pattern explicito.
- Inferência forte: `Transaction` e `WebPanel` continuam em risco alto/muito alto, mas deixam de ser bloqueados por falta de base amostral.
- Inferência forte: `PackagedModule`, `Theme` e parte de `SDT` seguem entre os candidatos menos agressivos do recorte, mas ainda nao devem ser tratados como baixos riscos absolutos.

## Estado atual consolidado - pattern web e camada fisica

- `Evidência direta`: `Work With for Web` importa com sucesso quando o XML do pattern usa o convenio estrutural real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Evidência direta`: no recorte comparavel `XPZExemploTRNWWComparacaoSemWW` vs `XPZExemploTRNWWComparacaoComWW`, a entrada de um unico `WWExemploMinPaisA` elevou `ObjectsIdentityMapping` de `25` para `49` identidades.
- `Inferência forte`: isso reforca que o risco de `WorkWithForWeb` continua alto mesmo em casos pequenos, porque o objeto puxa contexto adicional alem do seu proprio XML.
- `Evidência direta`: `Table` aparece como familia top-level propria (`857ca50e-7905-0000-0007-c5d9ff2975ec`) e `Index` aparece embutido dentro de `Table` nesta trilha de export.
- `Inferência forte`: a pendencia residual de camada fisica se concentra em como `Table` e `Index` se reassociam corretamente a partir da `Transaction`.
- `Evidência direta`: os exports `XPZExemploTabelaTRNWWPatternA.xpz` e `XPZExemploTabelaTRNDataSelectorA.xpz` mostraram que essas familias convivem no mesmo `.xpz` sem exigir `Attributes` top-level no contêiner.
- `Inferência forte`: para engenharia reversa do pattern web, a unidade mais informativa e a combinacao `Transaction + Table + WorkWithForWeb + PatternSettings`.

## Nota leve de risco runtime relativo

- `Inferência forte`: sem substituir o risco estrutural acima, o risco runtime relativo tende a ser `baixo a medio` em cascas simples e isoladas, `medio` em objetos com codigo mas baixa dependencia contextual, e `alto` quando se acumulam `grid`, `events`, multiplos `Level`, `parent` forte ou `pattern`.
- `Hipótese`: essa leitura runtime relativa serve apenas como desempate operacional e deve ser confirmada no `02-regras-operacionais-e-runtime.md` antes de orientar clonagem ou resposta do agente.



