# 05 - Transaction Familias e Templates

## Papel do documento
empirico e operacional

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md

## Usado por
08-guia-para-agente-gpt.md

## Objetivo
Concentrar familias estruturais de Transaction, regras por familia e validacoes de consistencia interna para clonagem controlada.

## Fontes consolidadas
- 28-familias-estruturais-de-transaction.md

## Origem incorporada - 28-familias-estruturais-de-transaction.md

## Papel do documento
empirico e operacional

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Identificar familias estruturais reais de `Transaction` a partir do acervo XML analisado.
Permitir escolha repetivel de template interno real, reduzindo risco de vazamento estrutural do template original.

## Sanitizacao deste documento

- Evidencia direta: os nomes reais dos objetos usados como representantes nao aparecem aqui.
- Evidencia direta: cada template representativo recebeu um alias publico, como `TRNExemploF1`, `TRNExemploF2` e assim por diante.
- Inferencia forte: para uso interno, o template correspondente pode ser reencontrado pelo criterio estrutural indicado em cada familia.
- Hipotese: essa estrategia preserva utilidade operacional sem expor nomes de negocio da KB.

## Metodo

- Evidencia direta: foram analisados 183 XMLs de `Transaction`.
- Evidencia direta: todos os 183 objetos usam o mesmo `Object/@type` (`1db606f2-af09-4cf9-a3b5-b481519d28f6`) e o mesmo inventario de 8 `Part type` recorrentes.
- Evidencia direta: os 8 `Part type` presentes em 100% do acervo observado sao `264be5fb-1b28-4b25-a598-6ca900dd059f`, `d24a58ad-57ba-41b7-9e6e-eaca3543c778`, `4c28dfb9-f83b-46f0-9cf3-f7e090b525d5`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `c44bd5ff-f918-415b-98e6-aca44fed84fa`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c` e `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- Evidencia direta: todos os 183 objetos observados possuem `parent` preenchido.
- Evidencia direta: 169 dos 183 objetos possuem pelo menos um bloco `DescriptionAttribute`.
- Evidencia direta: o agrupamento abaixo usa quantidade de `Level`, densidade de `AttributeProperties`, presenca de subniveis e tamanho do XML.
- Inferencia forte: para `Transaction`, a familia estrutural e mais discriminante do que o nome do objeto.

## Visao geral

- Evidencia direta: 162 das 183 `Transaction` observadas possuem exatamente 1 `Level`.
- Evidencia direta: 12 das 183 `Transaction` observadas possuem exatamente 2 `Level`.
- Evidencia direta: 9 das 183 `Transaction` observadas possuem 3 ou mais `Level`.
- Evidencia direta: a media geral de `Part` por objeto e 8; a media geral de `AttributeProperties` no recorte e aproximadamente 18.
- Inferencia forte: a separacao mais util para geracao pratica nao e por semantica de negocio, e sim por complexidade do `Level` principal e pela presenca de estrutura filha.
- Inferencia forte: o principal erro a evitar em `Transaction` e misturar familias diferentes durante a clonagem.

## Familia 1 - Um nivel enxuto

- Evidencia direta: 59 objetos com `1 Level` e ate 6 blocos `AttributeProperties`.
- Evidencia direta: tamanho medio aproximado de 16990 bytes; minimo 7222; maximo 38961.
- Inferencia forte: variabilidade interna baixa.
- Template base publico: `TRNExemploF1`.
- Criterio privado de selecao: menor XML observado dentro da faixa `1 Level` + `0..6 AttributeProperties`.
- Justificativa da escolha: representa a casca mais simples de `Transaction` de um nivel.

### Assinatura estrutural

- 1 `Level` principal
- sem subnivel
- poucos `AttributeProperties`
- `DescriptionAttribute` pode existir ou nao, mas quando existe aponta para atributo do mesmo nivel

### Edicao e preservacao

- Evidencia direta: a estrutura central fica concentrada no primeiro `Part` com `Level` e `Attribute`
- Inferencia forte: os pontos mais seguros de alteracao sao nome do objeto, descricao, nomes de atributos do nivel e `DescriptionAttribute`
- Inferencia forte: devem ser preservados a quantidade de `Part`, a ordem dos blocos, `parent*`, `moduleGuid` e a forma geral do `Level`
- Hipotese: esta e a familia mais segura para primeiras geracoes de `Transaction`

### Uso pratico e clonagem

- Inferencia forte: uso ideal para entidade simples e cadastro basico sem detalhe
- Inferencia forte: clonar preservando a forma do `Level` e substituindo apenas atributos que tenham paralelo bruto claro
- Hipotese: abortar se o alvo exigir subnivel, agrupamento de itens ou grande quantidade de atributos derivados

## Familia 2 - Um nivel com apoio estrutural moderado

- Evidencia direta: 41 objetos com `1 Level` e entre 7 e 11 blocos `AttributeProperties`.
- Evidencia direta: tamanho medio aproximado de 33051 bytes; minimo 19543; maximo 55508.
- Inferencia forte: variabilidade interna baixa para media.
- Template base publico: `TRNExemploF2`.
- Criterio privado de selecao: menor XML observado dentro da faixa `1 Level` + `7..11 AttributeProperties`.
- Justificativa da escolha: preserva o mesmo desenho simples de um nivel, mas com mais atributos controlados por propriedades.

### Assinatura estrutural

- 1 `Level` principal
- sem subnivel
- numero intermediario de `AttributeProperties`
- maior presenca de atributos de apoio, auditoria ou exibicao controlada

### Edicao e preservacao

- Inferencia forte: nomes de atributos, descricao e `DescriptionAttribute` continuam sendo editaveis, mas sempre junto das `AttributeProperties` relacionadas
- Inferencia forte: toda alteracao em atributo do `Level` deve ser refletida nos blocos `AttributeProperties` correspondentes
- Hipotese: erros nesta familia costumam surgir quando o clone remove ou renomeia atributo sem atualizar propriedades ligadas a ele

### Uso pratico e clonagem

- Inferencia forte: uso ideal para entidade simples com controles adicionais de formulario
- Inferencia forte: escolher template da propria faixa, em vez de rebaixar para a Familia 1
- Hipotese: abortar se o alvo exigir 2 niveis ou densidade de propriedades muito acima da faixa observada

## Familia 3 - Um nivel denso

- Evidencia direta: 42 objetos com `1 Level` e entre 12 e 30 blocos `AttributeProperties`.
- Evidencia direta: tamanho medio aproximado de 53395 bytes; minimo 24510; maximo 149206.
- Inferencia forte: variabilidade interna media.
- Template base publico: `TRNExemploF3`.
- Criterio privado de selecao: menor XML observado dentro da faixa `1 Level` + `12..30 AttributeProperties`.
- Justificativa da escolha: mostra `Transaction` ainda de um nivel, mas ja com numero alto de atributos e propriedades relacionadas.

### Assinatura estrutural

- 1 `Level` principal
- sem subnivel
- muitos `AttributeProperties`
- forte acoplamento entre atributos declarados e propriedades internas

### Edicao e preservacao

- Inferencia forte: a maior fonte de erro aqui e inconsistir `Attribute`, `AttributeProperties` e `DescriptionAttribute`
- Inferencia forte: antes de remover ou trocar atributo, verificar todas as ocorrencias no `Level`, nas propriedades e nas regras do objeto
- Hipotese: esta familia e apropriada para `Transaction` sem detalhe, mas com varias colunas auxiliares ou campos controlados

### Uso pratico e clonagem

- Inferencia forte: usar esta familia quando a simples enxuta ficar pequena demais e a estrutura continuar de um nivel
- Inferencia forte: clonar com diff estrutural curto, conferindo que nenhum nome residual do template-base permaneceu
- Hipotese: abortar se o alvo puder ser representado por familia menor ou se a troca de atributos exigir reordenar macicamente o `Level`

## Familia 4 - Um nivel muito denso

- Evidencia direta: 20 objetos com `1 Level` e 31 ou mais blocos `AttributeProperties`.
- Evidencia direta: tamanho medio aproximado de 160126 bytes; minimo 52433; maximo 521796.
- Inferencia forte: variabilidade interna alta.
- Template base publico: `TRNExemploF4`.
- Criterio privado de selecao: menor XML observado dentro da faixa `1 Level` + `31+ AttributeProperties`.
- Justificativa da escolha: representa o teto da complexidade observada ainda sem subnivel.

### Assinatura estrutural

- 1 `Level` principal
- sem subnivel
- altissima densidade de `AttributeProperties`
- blocos extensos de regras e eventos costumam acompanhar a estrutura

### Edicao e preservacao

- Inferencia forte: esta familia so deve ser usada quando a forma de um nivel muito denso for realmente necessaria
- Inferencia forte: preservar integralmente o esqueleto do `Level`, a ordem dos atributos e o inventario de propriedades relacionadas
- Hipotese: tentativas de simplificar demais um template desta familia costumam levar a vazamento de atributos e metadados do template original

### Uso pratico e clonagem

- Inferencia forte: uso ideal quando o alvo exigir muitos atributos auxiliares, calculados ou controlados, mas ainda sem detalhe filho
- Inferencia forte: clonar a partir do menor template possivel dentro desta familia
- Hipotese: abortar se o objetivo real puder ser resolvido com as Familias 2 ou 3

## Familia 5 - Pai-filho com dois niveis

- Evidencia direta: 12 objetos com exatamente `2 Level`.
- Evidencia direta: tamanho medio aproximado de 23236 bytes; minimo 8400; maximo 63405.
- Inferencia forte: variabilidade interna media para alta.
- Template base publico: `TRNExemploF5`.
- Criterio privado de selecao: menor XML observado entre os objetos com exatamente `2 Level`.
- Justificativa da escolha: e a menor forma observada de cabecalho + detalhe ou pai + item.

### Assinatura estrutural

- 1 `Level` pai
- 1 `Level` filho
- atributos distribuidos entre cabecalho e detalhe
- `DescriptionAttribute` pode aparecer no nivel pai, no filho ou em ambos

### Edicao e preservacao

- Evidencia direta: o nivel filho aparece aninhado dentro do nivel pai no primeiro `Part`
- Inferencia forte: devem ser preservados a hierarquia de niveis, a ordem do aninhamento e a relacao entre chaves do pai e do filho
- Inferencia forte: mover atributo de um nivel para outro sem paralelo bruto comparavel e motivo para abortar
- Hipotese: esta familia ja exige cautela alta na escolha do template

### Uso pratico e clonagem

- Inferencia forte: uso ideal para cabecalho + itens simples
- Inferencia forte: clonar somente quando o alvo realmente exigir detalhe filho
- Hipotese: se o alvo couber em 1 nivel, nao usar esta familia

## Familia 6 - Multinivel

- Evidencia direta: 9 objetos com `3` ou mais `Level`.
- Evidencia direta: tamanho medio aproximado de 55436 bytes; minimo 14768; maximo 137656.
- Evidencia direta: o maximo observado no recorte foi de 14 `Level`.
- Inferencia forte: variabilidade interna muito alta.
- Template base publico: `TRNExemploF6`.
- Criterio privado de selecao: menor XML observado entre os objetos com `3+ Level`.
- Justificativa da escolha: representa a menor forma observada de `Transaction` multinivel, evitando escolher como referencia um caso extremo.

### Assinatura estrutural

- 3 ou mais `Level`
- combinacao de pai e multiplos filhos
- maior densidade de atributos, regras e eventos ligados a contexto transacional

### Edicao e preservacao

- Inferencia forte: esta e a familia menos indicada para primeiras geracoes
- Inferencia forte: devem ser preservados integralmente numero de niveis, ordem, nesting e distribuicao de atributos entre niveis
- Inferencia forte: se a mudanca exigir criar, remover ou fundir niveis, abortar
- Hipotese: o custo de erro aqui e muito maior do que nas familias de um nivel

### Uso pratico e clonagem

- Inferencia forte: uso ideal apenas quando houver detalhe real em varios blocos ou subestruturas paralelas
- Inferencia forte: clonar a partir do menor template interno estruturalmente equivalente
- Hipotese: sem template muito proximo, esta familia nao deve ser usada para geracao inicial

## Regras operacionais por familia

- Evidencia direta: `Transaction` deve ser materializada a partir de XML bruto real do mesmo `Object/@type`
- Inferencia forte: a regra pratica mais segura e `identificar familia -> escolher template bruto da mesma familia -> preservar Part, ordem e metadata -> editar apenas o que tem paralelo claro`
- Inferencia forte: para `Transaction` nova, comecar sempre testando encaixe nas Familias 1, 2 ou 3 antes de considerar 5 ou 6
- Inferencia forte: o erro de materializacao mais comum neste tipo e vazamento do template-base em `Level`, `Attribute`, `AttributeProperties` e `DescriptionAttribute`

## Validacoes obrigatorias de consistencia interna

### Para qualquer Transaction clonada

- o XML deve permanecer bem-formado
- o objeto deve continuar com raiz unica `<Object>`
- os 8 `Part type` recorrentes devem permanecer presentes
- o nome de cada `Level` deve estar coerente com a estrutura final
- todo `DescriptionAttribute` deve apontar para atributo existente no mesmo nivel
- todo atributo citado em `AttributeProperties` deve existir de fato no XML da estrutura
- nao pode sobrar nome residual do template original

### Sinais classicos de erro

- `DescriptionAttribute` aponta para atributo inexistente
- atributo aparece no `Level`, mas nao tem correspondencia esperada nas propriedades internas
- `AttributeProperties` referencia atributo ausente
- sobra nome residual do template-base em `Level`, `Attribute`, regras ou eventos

## Regras de serializacao XPZ para Transaction

- usar objeto bruto real como fonte
- usar envelope XPZ bruto real como contêiner
- manter ordem das `Part`
- nao converter `CDATA` em texto escapado se o template bruto usar `CDATA`
- incluir o objeto no bloco `<Objects>` apenas por clonagem do envelope bruto comparavel
- validar parse XML antes de empacotar
- validar coerencia interna entre `Level`, `Attribute`, `AttributeProperties` e `DescriptionAttribute`

## Tabela resumo

| Familia | Quando usar | Risco | Template publico |
| --- | --- | --- | --- |
| Um nivel enxuto | entidade simples e cadastro basico | medio-alto | `TRNExemploF1` |
| Um nivel com apoio estrutural moderado | entidade simples com propriedades extras | alto | `TRNExemploF2` |
| Um nivel denso | entidade simples com muitos atributos e controles | alto | `TRNExemploF3` |
| Um nivel muito denso | caso de um nivel com alta carga estrutural | muito alto | `TRNExemploF4` |
| Pai-filho com dois niveis | cabecalho + detalhe simples | muito alto | `TRNExemploF5` |
| Multinivel | detalhe real em varios blocos | muito alto | `TRNExemploF6` |

## Sintese final

- Evidencia direta: o acervo de `Transaction` e dominado por objetos de um nivel, mas nao e homogeneo o bastante para tratar tudo como um unico molde.
- Evidencia direta: a segmentacao por numero de `Level` e densidade de `AttributeProperties` separa o tipo em grupos operacionais bem mais estaveis.
- Inferencia forte: a maior parte das novas `Transaction` deve ser tentada primeiro nas Familias 1, 2 ou 3.
- Inferencia forte: Familias 5 e 6 devem ser tratadas como casos de alta cautela, com template interno muito proximo.
- Hipotese: este catalogo reduz risco de vazamento estrutural do template-base, desde que a materializacao continue presa a XML bruto comparavel e nunca a markdown.



