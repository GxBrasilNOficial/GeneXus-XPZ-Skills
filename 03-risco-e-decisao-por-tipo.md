# 03 - Risco e Decisão por Tipo

## Papel do documento
operacional e heuristico

## Nível de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md

## Usado por
08-guia-para-agente-gpt.md

## Objetivo
Reunir obrigatoriedade heuristica, prontidao relativa e mapa de risco por tipo para orientar decisão operacional conservadora.

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

- Evidência direta: percentuais abaixo saem da frequência de Part type por tipo extraído.
- Inferência forte: aparentemente obrigatório significa presenca em ~100% das amostras do tipo nesta KB.
- Hipótese: só teste real de importação pode transformar isso em obrigatoriedade comprovada.

## API

- Evidência direta: total de objetos analisados: 1.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.
- `Calibração (from-spec, 2026-07-01)`: os indícios de Part type acima vêm do único objeto real clonado (perfil cadeia-grande). O perfil **autocontido from-spec** (tríade `API`->`Procedure`->`SDT`) segue caminho distinto — construção direta em XML validada por importação real, não clonagem — e não depende desses part-types herdados de amostra. Ver `xpz-builder/responsibilities-by-type/api.md`.

## DataProvider

- Evidência direta: total de objetos analisados: 24.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## DataView

- Evidência direta: total de objetos analisados: 1 (KB `FabricaBrasil18`, GX 18 U13, frente GamAuditoria, 2026-08-15/17; validado por import + build com `-FailIfReorg true` nos environments PostgreSQL e SQL Server com `reorgDetected: None`).
- Evidência direta: o tipo não constava do snapshot original da Fase 0; a linha da tabela resumo é recalibração empírica posterior, não contagem amostral do snapshot.
- Evidência direta: GUIDs de part types e propriedades observados: objeto `DataView` `19abc6ff-2cd2-0000-0006-6d172bc2333b`, part estrutura `19abc6ff-2cd2-1000-0006-6d172bc2333b`, part índices `7706bd3b-212a-1000-0006-8aaeb59068b9`, objeto índice `fc1b76c4-95c5-0000-0101-44f9543121bd`, part membros do índice `fe47b55c-ea2a-1000-0101-5b38901e24f7`; propriedades `DVDataStore` e `DVAssocTable` (referencia atributos por `<GUID-do-tipo-Attribute>-<Nome>`, separados por `;`, na ordem da chave primária).
- Evidência direta: DataView exige as quatro peças obrigatórias (`Attribute` com prefixo exclusivo, `Transaction` estrutural sem tela/regras, `DataView` com `<DataViewStructurePlatform Dbms="NN">` + `NAME`/`SCHEMA`, `DVDataStore` + `DVAssocTable`); sem `DVAssocTable` a especificação falha com `spc0031: No relationship found among attributes`.
- Evidência direta: sem `<DataViewStructurePlatform>` para **todos** os DBMS dos environments, a `Transaction` volta a ser tabela comum do modelo e a análise de impacto pede `CREATE TABLE` — inclusive em instalação de cliente, em produção. Com um bloco por DBMS (PostgreSQL `15`, SQL Server `12`, Oracle `7`), os dois environments fecharam com `reorgDetected: None` e zero `CREATE`/`ALTER TABLE`.
- Inferência forte: o risco estrutural alto vem da dependência multi-DBMS (omissão de plataforma) e da delimitação assimétrica de identificador (`NAME` com aspas no PostgreSQL, puro no SQL Server), não da complexidade do XML em si.
- Inferência forte: índices físicos (`<DataViewIndexesPlatform>`) devem ser declarados só onde o nome é estável entre instalações (PostgreSQL `_pkey`); no SQL Server o sufixo gerado do PK muda por instalação.
- `Nota de recalibração (DataView, 2026-08-17)`: linha da tabela resumo qualifica (não rebaixa) o risco do tipo; ver reconciliação com `998:1331-1339` na nota editorial da tabela.

## DesignSystem

- Evidência direta: total de objetos analisados: 2.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## PackagedModule

- Evidência direta: total de objetos analisados: 16.
- Evidência direta: Part type com forte indicio de obrigatoriedade: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: a5e6a251-2df0-44d8-adab-1da237574326.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## Panel

- Evidência direta: total de objetos analisados: 7.
- Evidência direta: Part type com forte indicio de obrigatoriedade: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Evidência operacional adicional: em Panel SD, warning `Layout com identificador incorreto` pode persistir quando apenas o `layout id` e trocado, e desaparecer quando o par `level id` + `layout id` vem de Panel SD exportado pela IDE.
- Regra conservadora: não gerar `level id` e `layout id` de Panel SD como GUIDs independentes; preservar par coerente do template real ou usar par vindo de Panel SD exportado pela IDE da mesma KB quando a regra de derivacao não estiver provada.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## Procedure

- Evidência direta: total de objetos analisados: 2281.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## SDT

- Evidência direta: total de objetos analisados: 594.
- `Regra editorial`: este bloco de `SDT` preserva o snapshot original usado nesta seção; para total atual do inventario agregado, consultar `09-inventario-e-rastreabilidade-publica.md` sem recalcular automaticamente a leitura metodologica daqui.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## Theme

- Evidência direta: total de objetos analisados: 7.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## Transaction

- Evidência direta: total de objetos analisados: 183.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: nenhum.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## WebPanel

- Evidência direta: total de objetos analisados: 1196.
- Evidência direta: Part type com forte indicio de obrigatoriedade: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.

## WorkWithForWeb

- Evidência direta: total de objetos analisados: 183.
- Evidência direta: Part type com forte indicio de obrigatoriedade: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type com indicio de opcionalidade: nenhum.
- Evidência direta: Part type com indicio de vazio/estrutural: babf62c5-0111-49e9-a1c3-cc004d90900a.
- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.
- Hipótese: blocos quase sempre vazios podem continuar sendo necessários mesmo sem carregar conteúdo útil.



## Origem incorporada - 22-tipos-prontos-para-geracao-conservadora.md

## Papel do documento
operacional

## Nível de confiança predominante
baixo

## Depende de
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md, 04-genexus-open-points.md

## Objetivo
Classificar os tipos prioritários sob uma leitura estritamente conservadora de prontidão relativa.
Evitar que “melhor candidato” seja confundido com “tipo comprovadamente seguro”.

- `Regra editorial`: as contagens desta seção refletem o snapshot original de incorporacao deste documento; o inventario atual e mais recente está em `09-inventario-e-rastreabilidade-publica.md`. As analises de prontidao relativa abaixo foram feitas com o snapshot original e não devem ser recalculadas com os totais atuais sem revisao metodologica correspondente.
- Evidência direta: a classificação abaixo considera quantidade de objetos, media de Part, dependencia de parent/module e presenca de pattern no acervo extraído.
- Inferência forte: "pronto" aqui significa apenas "melhor candidato relativo para experimentacao controlada por clonagem", não tipo comprovadamente importavel.
- Evidência direta: a trilha já contem bateria controlada de importação real a partir de `.xpz` montados com base nos `.md` locais e no skill `nexa`.
- Inferência forte: isso não transforma nenhum tipo em "definitivamente seguro", mas já separa tipos com envelope comprovado dos tipos que ainda dependem de contexto real da KB.
- `Nota de recalibração (2026-07-01)`: as linhas `API (cadeia)` e `API (from-spec)` refletem recalibração empírica posterior (Fase 0, KMW 4.0.187794 + GAM 3.15.78), fora do escopo do snapshot original de contagens — **não** recalculam as médias amostrais de `Part`/`parent`/`pattern` protegidas pela nota acima. Para `API`, a coluna `FolderType` traz **perfis operacionais qualificados**; o tipo GeneXus continua sendo `API`.

| FolderType | Classification | Evidence | Reading |
| --- | --- | --- | --- |
| API (cadeia) | apto somente por clonagem muito controlada | 1 API real no snapshot (media de Part = 5; parent = 1; pattern = 0); export real `XPZExemploCadeiaAPIA.xpz` = 3904 objetos (subárvore funcional) | clonar arrasta subárvore de negócio (`Procedure`, `DataProvider`, `Domain`, `Transaction`, `Table`, `SDT`); risco alto |
| API (from-spec) | apto por construção from-spec validada por importação real | tríade `API`->`Procedure`->`SDT`; a importação real valida gramática/refs (KMW 4.0.187794 + GAM 3.15.78); subcaso de listagem funcional comprovado em OnlineShopSS (2026-07-23) | única referência `ATTCUSTOMTYPE` externa ao objeto `API` = `sdt:` próprios; risco estrutural menor que o perfil cadeia, mas condicionado a Procedure/SDT no lote ou na KB e à importação real; se a Procedure usa `For each` sobre Transaction real, o caso deixa de ser autocontido e herda dependências de atributos/base table; segurança GAM é pré-condição de runtime à parte (ver `xpz-builder/responsibilities-by-type/api-gam-runtime.md`) |
| DataProvider | apto somente por clonagem muito controlada | 24 objetos; media de Part = 5; parent = 24; pattern = 0 | parent aparece em 100% dos casos observados |
| DesignSystem | apto somente por clonagem muito controlada | 2 objetos; media de Part = 4; parent = 1; pattern = 0 | amostra pequena demais para liberar geração conservadora |
| PackagedModule | apto somente por clonagem muito controlada | 16 objetos; media de Part = 2.38; parent = 2; pattern = 0 | e o melhor candidato relativo do recorte, mas ainda sem teste externo |
| Panel | apto somente por clonagem muito controlada | 7 objetos; media de Part = 2; parent = 7; pattern = 7 | dependencia simultanea de parent e pattern em 100% das amostras |
| Procedure | apto somente por clonagem muito controlada | 2281 objetos; media de Part = 7; parent = 2281; pattern = 0 | estrutura recorrente forte, mas parent em 100% e alta fragmentacao interna |
| SDT | apto somente por clonagem muito controlada | 594 objetos; media de Part = 2; parent = 591; pattern = 0 | baixa contagem de Part não elimina dependencia estrutural de parent |
| Theme | apto somente por clonagem muito controlada | 7 objetos; media de Part = 3; parent = 0; pattern = 0 | sem muita dependencia contextual aparente, mas a amostra ainda e pequena |
| Transaction | apto por clonagem baseada em padrão estrutural inferido (decisão operacional) | 183 objetos; media de Part = 8; parent = 183; pattern = 0 | ha massa critica suficiente para trabalhar por familia estrutural interna, com erro tratado incrementalmente |
| WebPanel | apto por clonagem baseada em familia estrutural (alta variabilidade; requer molde interno próximo) | 1196 objetos; media de Part = 7; parent = 1195; pattern = 0 | ha massa critica suficiente para escolher molde interno próximo, sem tratar WebPanel como estrutura única |
| WorkWithForWeb | apto somente com contexto completo de pattern e `Transaction` comparável | 183 objetos; media de Part = 2; parent = 183; pattern = 183 | o risco continua alto, mas a trilha posterior mostrou importação bem-sucedida quando o XML usa o convenio estrutural real do pattern |

## Leitura conservadora

- Evidência direta: a trilha já contem evidência de importação real bem-sucedida para varios tipos, usando somente os `.md` locais como base documental combinados com o skill `nexa`.
- Inferência forte: `PackagedModule` deixou de ser apenas candidato relativo e passou a ter importação bem-sucedida como `Module` em caso controlado.
- Inferência forte: `Transaction` continua desbloqueada para execução controlada, mas o teste real mostrou dependencia de atributos e tipos de contexto existentes na KB.
- Evidência direta: `Transaction` com atributos inexistentes na KB falhou na validação mesmo quando o shape do `Level` estava no caminho correto.
- Inferência forte: o risco de `Transaction` não está apenas no envelope ou no shape, mas também na existência previa ou inclusao explicita de `Attribute` top-level.
- Regra operacional: tratar ausencia de `Attribute` top-level correspondente como bloqueio operacional do pacote, e não apenas como dependencia semantica secundaria.
- Inferência forte: `WorkWithForWeb` permanece na zona de maior cautela por depender de `Transaction` pai real.

## Decisão operacional provisoria

- Evidência direta: `Transaction` possui 183 exemplos no acervo e `WebPanel` possui 1196.
- Inferência forte: esse volume e suficiente para parar de bloquear execução apenas por falta de evidencia amostral.
- Inferência forte: para `Transaction`, a estrategia preferida passa a ser clonagem por familia estrutural inferida.
- Inferência forte: para `WebPanel`, a estrategia preferida passa a ser clonagem por familia estrutural interna, com selecao cuidadosa de template próximo.
- Hipótese: os erros de importação que surgirem devem ser tratados como feedback para refinar estes documentos, e não como prova de inviabilidade geral do tipo.

## Evidencia complementar - bateria controlada de importação

## Papel da bateria
empirico complementar

## Objetivo
Registrar o que foi efetivamente reconhecido pela IDE em importacoes reais de `.xpz` de teste montados a partir desta base documental e do skill `nexa`.
Separar falha de envelope/shape de falha por dependencia semantica da KB.

- Evidência direta: o critério de classificação abaixo considera o texto retornado pela própria importação, confirmando nome e tipo reconhecidos quando isso apareceu no log.
- Evidência direta: os testes desta bateria usaram somente os `.md` desta pasta em conjunto com o skill `nexa`; não usaram `C:\Dropbox\Backups\Gx_Kbs` nem outras bases externas.
- Inferência forte: quando a importação falha por objeto pai, atributo, `ATTCUSTOMTYPE`, package ou pattern inexistente, o envelope XML está mais forte do que o contexto semantico do caso.

## Tipos com importação bem-sucedida e tipo coerente

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

- `API`: o risco atual está concentrado numa subarvore funcional grande, envolvendo `Procedure`, `Data Provider`, `Domain`, `Transaction`, `Table`, `SDT` e atributos de negocio reais.
- `Transaction`: o tipo está destravado, mas depende de atributos reais do `Level` e dos SDTs de contexto corretos, como `Context` e `TransactionContext`.
- `Data Selector`: o tipo pode importar em caso controlado, mas continua sensivel a atributos, filtros e funções realmente existentes na KB.
- `Index`: a evidência consolidada mostra `Index` como estrutura embutida em `Table`, não como familia top-level independente nesta trilha de export.
- `Deployment Unit`: o tipo depende da lista completa de `Member` existir e ser coerente no destino.
- `Theme Class`: o tipo depende da hierarquia visual correta e do contexto de tema/classe pai quando houver heranca ou derivacao.
- `Design System`: o tipo pode importar em caso controlado, mas continua sensivel a imports, pacotes e contexto visual do ambiente.
- `Work With for Web`: o tipo está destravado quando usa o convenio estrutural real do pattern e `Transaction` comparavel, mas continua exigindo contexto completo de pattern.

## Tipos com leitura consolidada especial

- `Folder`: tratar como tipo XML estruturalmente valido; `Category` e apenas o rotulo exibido pela IDE/importador.
- `Pattern Settings`: o tipo está destravado em caso real compativel; o risco residual passa a ser compatibilidade do pattern no ambiente.
- `Attribute`: o shape top-level está provado; o risco residual está em propriedades semanticas como `ControlItemDescription`, `idBasedOn` e outras referencias nominais a atributos reais.
- `Theme`: o tipo está destravado quando acompanhado pelas `ThemeClass` exigidas pelo próprio grafo visual.

## Leitura operacional após a bateria

- Evidência direta: os `.md` locais, combinados com o skill `nexa`, sustentam uma faixa relevante de tipos autocontidos e estruturais com importação real.
- Inferência forte: a principal fronteira atual não é mais o contêiner `.xpz`, e sim a dependencia de contexto real da KB em tipos que exigem pai, atributos, pattern, package, `EXO`, `SDT` ou membros existentes.
- Inferência forte: os tipos em sucesso coerente passam a ter prioridade maior como fonte segura para agente/GPT nesta base.
- Inferência forte: os tipos com falha contextual pedem complemento por exemplos reais ou regra documental mais específica, e não simples extrapolacao a partir do envelope mínimo.
- `Inferência forte`: `Transaction`, `Theme` e `PatternSettings` deixaram de ser pendencias estruturais abertas nesta trilha; agora já possuem receita empirica de sucesso sob dependencias explicitas conhecidas.
- `Evidência direta`: em bateria posterior, uma variante mínima de `Transaction` com `DescriptionAttribute` e `AttributeProperties` também importou com sucesso quando os `Attribute` top-level correspondentes estavam presentes no pacote.
- `Evidência direta`: nessa mesma bateria, o erro `Level is empty` reapareceu em tentativa com atributos presentes quando o `Part` principal não seguia o shape estrutural esperado.
- `Inferência forte`: o risco residual de `Transaction` nesta trilha não está apenas no envelope mínimo; ele também depende da existência real de `Attribute` top-level e da preservacao do shape correto do `Part` principal.
- Regra operacional: tratar ausencia de `Attribute` top-level necessário como bloqueio operacional do pacote mínimo, e não apenas como dependencia semantica secundaria.
- `Evidência direta`: um pacote composto posterior reuniu `ThemeClass`, `Theme`, `Attribute`, `SDT`, `Transaction` e `Pattern Settings` no mesmo `.xpz` e importou com sucesso, incluindo geração de pattern para `WWExemploMinBancoA`.
- `Inferência forte`: a base já não prova apenas sucessos isolados por tipo; ela também sustenta composicao entre tipos resolvidos quando as dependencias explicitas entram juntas no pacote.
- `Inferência forte`: `API` deixa de ser frente aberta de generalizacao nesta trilha e passa a ficar encerrada, por ora, como estudo de caso único manual/local da KB; seu risco residual observado já não está em `ATTCUSTOMTYPE`, e sim numa subarvore funcional de negocio envolvendo `Procedure`, `Data Provider`, `Domain`, `Transaction` e atributos reais da KB.
- `Evidência direta`: o export real `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos, sendo `2282` `Procedure`, `594` `SDT`, `592` `Domain`, `228` `Table`, `183` `Transaction`, `24` `DataProvider` e `1` `API`.
- `Inferência forte`: isso confirma que, para `API`, o recorte de risco correto e uma familia funcional grande; tentar trata-la como tipo quase isolado tende a subestimar a dependencia real.
- `Calibração (from-spec, 2026-07-01)`: o encerramento de `API` como "estudo de caso único" (bullets acima) vale para o perfil **cadeia-grande** (clonagem da subárvore) e segue válido para clonagem; NÃO se aplica ao perfil from-spec. A Fase 0 empírica reabriu `API` por outro caminho: a **tríade autocontida** (`API`->`Procedure`->`SDT`) é montável from-spec e validada por **importação real** (que resolve `API => Proc` intra-lote ou contra a KB; preview NÃO valida). Nesse perfil o risco estrutural é menor que o do perfil cadeia, mas condicionado a Procedure/SDT no lote ou na KB e à importação real; o risco que resta é de **runtime/segurança GAM**, tratado como pré-condição em `xpz-builder/responsibilities-by-type/api-gam-runtime.md`, não como risco de envelope.
- `Evidência direta`: o export real `XPZExemploTemaA.xpz` veio com `947` objetos, incluindo `501` `ThemeClass`, `7` `Theme`, `24` `ThemeColor`, `2` `DesignSystem`, `1` `ColorPalette`, `228` `Table`, `183` `Transaction` e `1` `Folder`.
- `Inferência forte`: para a pilha visual, o risco melhora quando a análise e feita por familia combinada (`Theme` + `ThemeClass` + `DesignSystem` + `ColorPalette` + `ThemeColor`), e não por objeto visual totalmente isolado.
- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades.
- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Inferência forte`: isso mostra que a familia `Attribute` + `Transaction` + `Domain` + `SubtypeGroup` também existe como recorte combinado relevante da IDE, com `Attributes` top-level preservados no mesmo `.xpz`.
- `Inferência forte`: para `Attribute`, o risco residual continua semanticamente contextual, mas o formato multiobjeto observado com bloco `Attributes` deixa de ser lacuna relevante nesta trilha.

## Hierarquia de ataque das pendencias contextuais

- Evidência direta: `Transaction` e o caso único real de `API` concentraram erros semanticos claros, apesar de o envelope ter passado da fase principal de parse/importacao.
- Inferência forte: a ordem mais útil de ataque, entre pendencias contextuais ainda ativas, e `Transaction -> Theme -> Pattern Settings -> Folder`; `API` fica como estudo de caso fechado nesta fase e só deve reabrir se entrarem novos exemplos reais ou automacao externa.
- `Calibração (from-spec, 2026-07-01)`: o "estudo de caso fechado... só deve reabrir se entrarem novos exemplos reais ou automação externa" do bullet acima refere-se ao perfil **cadeia-grande**; a Fase 0 empírica é justamente o novo exemplo real que reabriu o perfil **from-spec** (ver a calibração from-spec na seção de inferência acima e as linhas `API (from-spec)` das Tabelas 1 e 2).
- Inferência forte: no único caso real observado, `API` compartilha com `Transaction` a mesma fragilidade principal: dependencia de tipos e referencias reais da KB.
- Inferência forte: em `API`, a hierarquia correta de decisão e `ATTCUSTOMTYPE` valido -> `EXO` e `SDT` existentes -> `Procedure` chamada -> `Data Provider`/`Domain` auxiliares -> atributos e contexto de negocio -> eventos/codigo.
- Inferência forte: qualquer tentativa de corrigir `API` pelo fim, mexendo primeiro em código ou serializacao, tende a mascarar a causa real do erro.
- Inferência forte: `Theme` vem em seguida porque seu problema principal já está isolado e não depende tanto de semantica de negocio da KB, mas sim de preservar o grafo mínimo de classes visuais.
- Inferência forte: em `Theme`, a hierarquia correta de decisão e `PredefinedTypes e Styles -> classes base existentes -> referencias internas entre classes -> simplificacao visual`.
- Inferência forte: qualquer tentativa de reduzir `Theme` sem mapear antes as referencias entre classes tende a repetir o erro de `TableDetail`, `TableSection` e `TextBlockGroupCaption` ausentes.
- `Inferência forte`: o teste isolado mostrou que esse requisito de ambiente pode ser satisfeito materializando as `ThemeClass` auxiliares necessárias.
- Inferência forte: `Pattern Settings` vem depois porque o erro principal já foi isolado em `pattern` registrado e contexto do ambiente, não no envelope XML.
- Inferência forte: em `Pattern Settings`, a hierarquia correta de decisão e `Pattern registrado -> ContextVariable e LoadProcedure -> Security e referencias auxiliares -> detalhe declarativo interno`.
- Inferência forte: qualquer tentativa de tratar `Pattern Settings` como objeto autocontido tende a repetir o sintoma de `was not changed` com pattern não registrado, mas o caso real `WorkWith` já mostrou caminho de sucesso.
- Inferência forte: `Attribute` já não pertence mais ao grupo de shape desconhecido; ele deve ser lido como tipo estruturalmente provado, mas dependente de propriedades que referenciam atributos reais da KB.
- `Inferência forte`: quando o `Attribute` escolhido evita referencias nominais problematicas, como `ControlItemDescription`, o tipo já demonstrou importação bem-sucedida nesta trilha.
- Inferência forte: `Folder` fica por último porque o shape mínimo já parece estavel e o problema restante e mais de reconhecimento semantico da IDE do que de XML ou contexto pesado da KB.
- Inferência forte: em `Folder`, a hierarquia correta de decisão e `shape minimo correto -> contexto pai/modulo -> tipo exibido pela IDE`.
- Inferência forte: a diferenca `Folder` x `Category` já ficou suficientemente esclarecida nesta trilha; novas tentativas devem tratar `Folder` como tipo XML estrutural e `Category` como rotulo de UI/importador, e não como tipos rivais de envelope.


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
- Inferência forte: o mapa e operacional para priorizacao de clonagem, não uma escala formal de chance de sucesso em importação.

| FolderType | StructuralRisk | ParentModuleDependency | PatternDependency | CurrentConfidence | PracticalRecommendation |
| --- | --- | --- | --- | --- | --- |
| Nota editorial | snapshot original | Procedure = 2281; SDT = 594 | ver `09` para totais agregados atuais | não recalcular esta tabela sem revisao metodologica | manter leitura relativa desta seção |
| Nota de recalibração (2026-07-01) | `medio-contextual` da linha from-spec qualifica (não rebaixa) o nível base; recalibração operacional, não novo nível do snapshot | a linha from-spec NÃO é `0/n` amostral nem ausência de parent: os objetos da tríade têm `parent="PastaExemploApi"` (pasta, GUIDs neutralizados no molde `01e`); "autocontido" = sem dep. funcional/`ATTCUSTOMTYPE` externa (única = `sdt:` próprios), não ausência de parent | — | evidência posterior à Fase 0 (KMW 4.0.187794 + GAM 3.15.78); não recalcula contagens do snapshot | `API (cadeia)`/`API (from-spec)` = perfis operacionais qualificados; o tipo GeneXus continua `API` |
| Nota de recalibração (DataView, 2026-08-17) | `alto` da linha DataView é recalibração empírica posterior ao snapshot original da Fase 0 (o tipo não estava na amostra de contagens); `0/0` não é "zero dependência" nem ausência de amostra — é ausência de contagens do snapshot, e **não** recalcula médias amostrais de Part/parent/pattern | evidência de uma KB real (`FabricaBrasil18`, GX 18 U13) com import + build `-FailIfReorg true` nos environments PostgreSQL e SQL Server → `reorgDetected: None`, zero `CREATE`/`ALTER TABLE`; risco alto vem da omissão de `<DataViewStructurePlatform>` por DBMS (pede `CREATE TABLE` em cliente/produção) e da delimitação assimétrica de `NAME` | 0/0 — sem indício de pattern | media (amostra pequena: 1 DataView real; validada por build nos dois environments) | exigir molde comparável com as quatro peças obrigatórias (`Attribute` + `Transaction` estrutural + `DataView` + `DVAssocTable`/`DVDataStore`) e um bloco de plataforma por DBMS dos environments; **reconciliação `998:1331-1339`:** o GUID do objeto (`19abc6ff-2cd2-0000-0006-6d172bc2333b`) é o mesmo tipo estável descoberto na KB Evo1 e registrado no catálogo upstream (commit `1866c52`), e reapareceu em **segunda KB independente** (FabricaBrasil18) como tipo a gerar — o gatilho de reavaliação previsto no `998` foi atingido, mas a forma Evo1-fixture (self-test com fixture acoplada a KB cliente) **continua descartada**; a promoção feita aqui é documental (03, 01b, 01e, satélite `xpz-builder/responsibilities-by-type/dataview.md`), sem replay de pacote de KB específica em self-test |
| API (cadeia) | alto | 1/1 | 0/1 | baixa | exigir molde bruto comparável muito próximo; clonar arrasta a subárvore funcional inteira |
| API (from-spec) | medio-contextual | parent nomeado presente (pasta `PastaExemploApi`, neutralizada no molde) — ver nota | 0 | media (importação real 2026-07-01; listagem funcional pública comprovada em OnlineShopSS em 2026-07-23 como subcaso datado) | montar from-spec da tríade `API`->`Procedure`->`SDT`; validar por importação real (nunca preview); se a implementação listar `For each` sobre Transaction real, declarar essa dependência; segurança GAM = pré-condição de runtime à parte (ver `api-gam-runtime.md`) |
| DataProvider | alto | 24/24 | 0/24 | baixa | exigir molde bruto comparável muito próximo do caso alvo |
| DataView | alto | 0/0 | 0/0 | media | exigir molde com as quatro peças obrigatórias (`Attribute` + `Transaction` estrutural + `DataView` + `DVAssocTable`/`DVDataStore`) e plataforma de estrutura por DBMS dos environments; conferir delimitação de `NAME` por SGBD; ver nota de recalibração 2026-08-17 |
| DesignSystem | alto | 1/2 | 0/2 | baixa | exigir molde bruto comparável e evitar extrapolacao com amostra pequena |
| PackagedModule | medio | 2/16 | 0/16 | media-baixa | clonar só com diff estrutural e revisao manual forte |
| Panel | alto | 7/7 | 7/7 | baixa | exigir molde bruto comparável muito próximo do caso alvo |
| Procedure | alto | 2281/2281 | 0/2281 | baixa | exigir molde bruto comparável muito próximo e preservar todos os blocos recorrentes |
| SDT | medio | 591/594 | 0/594 | media-baixa | clonar só com template do mesmo subtipo estrutural e checagem de parent |
| Table | baixo-contextual | 0/228 | 0/228 | alta | incluir sempre junto com a `Transaction` de mesmo nome; Part types fixos e confirmados em 228 objetos; risco residual e de reassociacao física no destino, não estrutural |
| Theme | medio | 0/7 | 0/7 | media-baixa | usar apenas para experimentos muito controlados e com diff manual |
| Transaction | muito alto | 183/183 | 0/183 | media | permitir geração por padrão estrutural inferido; preservar estrutura e tratar erros incrementalmente |
| WebPanel | muito alto | 1195/1196 | 0/1196 | media-baixa | permitir geração por familia estrutural; usar molde interno próximo; não generalizar estrutura |
| WorkWithForWeb | muito alto | 183/183 | 183/183 | media | tentar apenas com contexto completo de pattern, `Transaction` comparavel e convenio estrutural real de atributo |

## Notas de leitura

- `Evidência direta`: `Table` é o único tipo de volume relevante (228 objetos) onde `ParentModuleDependency = 0/228` não significa ausência de dependência contextual, mas ausência do atributo `parent` nomeado — `Table` usa apenas `parentGuid` e `moduleGuid`. A dependência real de `Table` está na `Transaction` de mesmo nome existir no destino.
- `Evidência direta`: `Table` tem exatamente 2 `Part type` em 100% dos 228 objetos: `00000000-0000-0000-0002-000000000004` (chave) e `a5c0e770-560d-0001-0001-7fe71c260de3` (índices). Índices embutidos usam `type="9e750647-3679-0000-0100-2529de263960"` com `Part type` interno `62cfa789-c127-0001-0100-77676175e433`.
- Evidência direta: `Transaction`, `WebPanel` e `WorkWithForWeb` combinam alta dependencia contextual com estrutura relativamente rica ou pattern explicito.
- Inferência forte: `Transaction` e `WebPanel` continuam em risco alto/muito alto, mas deixam de ser bloqueados por falta de base amostral.
- Inferência forte: `PackagedModule`, `Theme` e parte de `SDT` seguem entre os candidatos menos agressivos do recorte, mas ainda não devem ser tratados como baixos riscos absolutos.

## Estado atual consolidado - pattern web e camada física

- `Evidência direta`: `Work With for Web` importa com sucesso quando o XML do pattern usa o convenio estrutural real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Evidência direta`: no recorte comparavel `XPZExemploTRNWWComparacaoSemWW` vs `XPZExemploTRNWWComparacaoComWW`, a entrada de um único `WWExemploMinPaisA` elevou `ObjectsIdentityMapping` de `25` para `49` identidades.
- `Inferência forte`: isso reforca que o risco de `WorkWithForWeb` continua alto mesmo em casos pequenos, porque o objeto puxa contexto adicional além do seu próprio XML.
- `Evidência direta`: `Table` aparece como familia top-level própria (`857ca50e-7905-0000-0007-c5d9ff2975ec`) e `Index` aparece embutido dentro de `Table` nesta trilha de export.
- `Inferência forte`: a pendencia residual de camada física se concentra em como `Table` e `Index` se reassociam corretamente a partir da `Transaction`.
- `Evidência direta`: os exports `XPZExemploTabelaTRNWWPatternA.xpz` e `XPZExemploTabelaTRNDataSelectorA.xpz` mostraram que essas familias convivem no mesmo `.xpz` sem exigir `Attributes` top-level no contêiner.
- `Inferência forte`: para engenharia reversa do pattern web, a unidade mais informativa e a combinacao `Transaction + Table + WorkWithForWeb + PatternSettings`.

## Nota leve de risco runtime relativo

- `Inferência forte`: sem substituir o risco estrutural acima, o risco runtime relativo tende a ser `baixo a medio` em cascas simples e isoladas, `medio` em objetos com código mas baixa dependencia contextual, e `alto` quando se acumulam `grid`, `events`, múltiplos `Level`, `parent` forte ou `pattern`.
- `Hipótese`: essa leitura runtime relativa serve apenas como desempate operacional e deve ser confirmada no `02-regras-operacionais-e-runtime.md` antes de orientar clonagem ou resposta do agente.
