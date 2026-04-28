# 00 - Indice da Base GeneXus XPZ XML

## Papel do documento
indice

## Nivel de confianca predominante
alto

## Depende de
09-inventario-e-rastreabilidade-publica.md

## Usado por
toda a base consolidada

## Objetivo
Ser o ponto de entrada principal da base consolidada, com ordem de leitura, limites metodologicos e regras absolutas para uso por outro agente GPT.

## Fontes consolidadas
- 26-guia-para-agente-gpt.md

## Origem incorporada - 00-indice-da-base-genexus-xpz-xml.md

## Papel do documento
indice

## Nível de confiança predominante
alto

## Depende de
00-inventario-da-base-documental.md

## Usado por
toda a base; em especial 26-guia-para-agente-gpt.md

## Objetivo
Ser o ponto de entrada principal da base GeneXus/XPZ consolidada.
Explicar escopo, ordem de leitura e regras absolutas para qualquer agente GPT usar esta documentação com segurança.

## Objetivo da base documental

Organizar conhecimento operacional e empírico sobre XMLs extraídos de `XPZ` GeneXus 18, com foco em análise estrutural, clonagem conservadora de objetos e tomada de decisão prudente sobre geração ou aborto de tentativa.

## Escopo

- leitura de XMLs internos extraídos de `XPZ`
- análise estrutural de objetos GeneXus
- catálogos de `Object/@type` e `Part/@type` observados
- avaliação conservadora de risco, clonagem e necessidade de molde estrutural comparável
- envelope XPZ observado em export real da KB

## Camadas da base

### Conceitual

- `00-indice-da-base-genexus-xpz-xml.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `09-inventario-e-rastreabilidade-publica.md`

### Empírica

- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md`
- `01b-matriz-part-types-por-tipo.md`
- `01c-campos-estaveis-vs-variaveis.md`
- `01d-diffs-estruturais-por-tipo.md`
- `01e-moldes-sanitizados-core.md`
- `01f-moldes-sanitizados-dados-e-design.md`
- `01g-moldes-sanitizados-componentes-e-fisico.md`
- `01h-moldes-sanitizados-metadados-e-artefatos.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`

### Operacional

- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`

## Ordem recomendada de leitura

1. `00-indice-da-base-genexus-xpz-xml.md`
2. `01-base-empirica-geral.md`
3. abrir o filho mais aderente da serie `01` (`01a` a `01h`)
4. `02-regras-operacionais-e-runtime.md`
5. `03-risco-e-decisao-por-tipo.md`
6. `04-webpanel-familias-e-templates.md`
7. `05-transaction-familias-e-templates.md`
8. `05b-procedure-relatorio-familias-e-templates.md`
9. `07-open-points-e-checklist.md`
10. `08-guia-para-agente-gpt.md`
11. `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: leitura suplementar — indicado quando a duvida envolver nomenclatura de objetos, prefixos de tipo ou comportamento de `Folder` vs `Module` no `fullyQualifiedName`.

## Regras absolutas para qualquer agente GPT

- nunca inventar `Part type`
- nunca assumir importação ou build sem teste externo
- sempre preferir clonagem conservadora
- abortar quando faltar molde estrutural comparável ou contexto estrutural
- não promover `Hipótese` a `Inferência forte`
- não promover `Inferência forte` a `Evidência direta`

## Fluxo operacional resumido

1. identificar o tipo do objeto
2. consultar risco em `03-risco-e-decisao-por-tipo.md`
3. consultar indícios de obrigatoriedade em `03-risco-e-decisao-por-tipo.md`
4. consultar regras operacionais e runtime em `02-regras-operacionais-e-runtime.md`
5. aplicar clonagem conservadora apenas se o contexto estrutural combinar
6. validar antes de qualquer empacotamento

## Sobre o XPZ observado

- `Evidência direta`: no export real inspecionado nesta trilha, o arquivo `.xpz` continha um unico XML principal com raiz `<ExportFile>`.
- `Evidência direta`: no export full/especial observado, os blocos de primeiro nivel foram `KMW`, `Source`, um bloco especial de KB, `Objects`, `Attributes` e `Dependencies`.
- `Evidência direta`: no formato normal mais frequente de export de objetos, a base passou a tratar esse bloco especial de KB como excepcional, e nao como parte obrigatoria do contêiner.
- `Evidência direta`: o bloco `KMW` trouxe `MajorVersion`, `MinorVersion` e `Build`.
- `Inferência forte`: para geracao orientada por esta base, o agente deve pensar primeiro em `objeto <Object>` e depois em `envelope XPZ observado`, e nao em um suposto `Objects.xml` isolado sem prova local.
- `Inferência forte`: os detalhes executaveis desse envelope ficam centralizados em `02-regras-operacionais-e-runtime.md`.

## Limites atuais da base

- `Evidência direta`: a base deriva principalmente de XMLs extraidos de `XPZ`, mas esta trilha ja incorporou tambem testes documentados de importacao de `XPZ` montado fora da IDE do GeneXus.
- `Inferência forte`: ela reduz bastante tentativa e erro de serializacao e empacotamento, mas ainda nao substitui validacao completa de comportamento de IDE, build ou runtime.
- `Hipótese`: alguns padrões podem se repetir em outras KBs GeneXus 18, mas isso ainda precisa de validação externa.

## Dependencias entre documentos

- `01` e `02` fundamentam a leitura conceitual.
- `04` e `05` sustentam as familias estruturais mais detalhadas.
- `06` e `09` ajudam com nomenclatura, rastreabilidade e contexto historico separado.
- `08` diz como um agente GPT deve consumir o conjunto atual.


## Regra de encaminhamento

- `Evidência direta`: as orientacoes detalhadas de consumo por agente GPT ficam centralizadas em `08-guia-para-agente-gpt.md`.
- `Inferência forte`: este `00` deve funcionar como porta de entrada curta e estavel, evitando duplicar regras operacionais que ja estao mantidas e atualizadas no `08`.

- `Evidência direta`: em teste real de `Import File Load`, um XML isolado de objeto com raiz `<Object>` falhou com erro `Invalid format, MajorVersion not found`.
- `Evidência direta`: o mesmo conteudo, encapsulado em `import_file.xml` com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, carregou e importou com sucesso.
- `Evidência direta`: em teste real de renomeacao de `Procedure`, a IDE preservou historico do mesmo objeto quando o pacote manteve o mesmo `Object/@guid` e alterou apenas `name`, `fullyQualifiedName`, `description` e conteudo.
- `Regra operacional`: para qualquer alteracao de objeto existente, inclusive renomeacao, preservar o mesmo `guid`; `guid` novo faz a IDE tratar como objeto novo.

## Regras minimas adicionais

- o agente deve manter `Source/@kb` e `Source/Version/@guid` em formato GUID valido; placeholders textuais ja causaram falha real de parse nesta trilha
- antes de empacotar, validar parse XML, presenca de todos os `Part type` recorrentes e coerencia entre objeto clonado e molde-base
- o agente nao deve afirmar “sem erro de importacao”; deve afirmar apenas que seguiu a especificacao mais conservadora disponivel
- ao revisar `Source` grande com fechamento de bloco ou aninhamento relevante, releia o trecho salvo e preserve comentarios estruturais humanos que ajudam a leitura, sem tentar "limpar" apoio visual util

## Regras de fonte

- Fonte valida: XML bruto de objeto
- Fonte valida: envelope XPZ observado documentado nesta base
- Fonte valida: molde sanitizado completo documentado nesta base, quando houver XML suficiente para o tipo alvo
- Fonte invalida: markdown desta base
- Fonte invalida: exemplos sanitizados incompletos ou meramente ilustrativos
- Fonte invalida: reconstrucoes livres baseadas em tabelas, frequencias ou descricoes
- Inferência forte: esta base documental decide, classifica e orienta; a materializacao final deve usar XML bruto comparavel ou molde sanitizado completo documentado nesta propria base
