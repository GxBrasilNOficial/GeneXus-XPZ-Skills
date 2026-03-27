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
- Hipótese: sem teste real de importacao, build e abertura na IDE, nenhum tipo deve ser tratado como definitivamente seguro.

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
| WebPanel | apto por clonagem baseada em familia estrutural (alta variabilidade; requer template interno proximo) | 1196 objetos; media de Part = 7; parent = 1195; pattern = 0 | ha massa critica suficiente para escolher template interno proximo, sem tratar WebPanel como estrutura unica |
| WorkWithForWeb | ainda nao apto sem template real | 183 objetos; media de Part = 2; parent = 183; pattern = 183 | pattern e parent aparecem em 100% dos casos observados |

## Leitura conservadora

- Evidência direta: nenhum dos tipos prioritarios ficou sustentado por evidencia de importacao real nesta trilha.
- Inferência forte: `PackagedModule` e `Theme` parecem menos agressivos do que os tipos com pattern ou muitos blocos internos, mas ainda merecem template real proximo e validacao humana.
- Inferência forte: `Transaction` e `WebPanel` passam a ficar desbloqueados para execucao controlada por clonagem interna da propria base, sem prometer importacao bem-sucedida.
- Inferência forte: `WorkWithForWeb` deve permanecer na zona de maior cautela.

## Decisao operacional provisoria

- Evidência direta: `Transaction` possui 183 exemplos no acervo e `WebPanel` possui 1196.
- Inferência forte: esse volume e suficiente para parar de bloquear execucao apenas por falta de evidencia amostral.
- Inferência forte: para `Transaction`, a estrategia preferida passa a ser clonagem por familia estrutural inferida.
- Inferência forte: para `WebPanel`, a estrategia preferida passa a ser clonagem por familia estrutural interna, com selecao cuidadosa de template proximo.
- Hipótese: os erros de importacao que surgirem devem ser tratados como feedback para refinar estes documentos, e nao como prova de inviabilidade geral do tipo.


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
| API | alto | 1/1 | 0/1 | baixa | exigir template real muito proximo do caso alvo |
| DataProvider | alto | 24/24 | 0/24 | baixa | exigir template real muito proximo do caso alvo |
| DesignSystem | alto | 1/2 | 0/2 | baixa | exigir template real e evitar extrapolacao com amostra pequena |
| PackagedModule | medio | 2/16 | 0/16 | media-baixa | clonar so com diff estrutural e revisao manual forte |
| Panel | alto | 7/7 | 7/7 | baixa | exigir template real muito proximo do caso alvo |
| Procedure | alto | 2281/2281 | 0/2281 | baixa | exigir template real muito proximo e preservar todos os blocos recorrentes |
| SDT | medio | 591/594 | 0/594 | media-baixa | clonar so com template do mesmo subtipo estrutural e checagem de parent |
| Theme | medio | 0/7 | 0/7 | media-baixa | usar apenas para experimentos muito controlados e com diff manual |
| Transaction | muito alto | 183/183 | 0/183 | media | permitir geracao por padrao estrutural inferido; preservar estrutura e tratar erros incrementalmente |
| WebPanel | muito alto | 1195/1196 | 0/1196 | media-baixa | permitir geracao por familia estrutural; usar template interno proximo; nao generalizar estrutura |
| WorkWithForWeb | muito alto | 183/183 | 183/183 | baixa | nao tentar sem template real e contexto completo de pattern |

## Notas de leitura

- Evidência direta: `Transaction`, `WebPanel` e `WorkWithForWeb` combinam alta dependencia contextual com estrutura relativamente rica ou pattern explicito.
- Inferência forte: `Transaction` e `WebPanel` continuam em risco alto/muito alto, mas deixam de ser bloqueados por falta de base amostral.
- Inferência forte: `PackagedModule`, `Theme` e parte de `SDT` seguem entre os candidatos menos agressivos do recorte, mas ainda nao devem ser tratados como baixos riscos absolutos.



