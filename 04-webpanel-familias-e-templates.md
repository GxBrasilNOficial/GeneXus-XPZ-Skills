# 04 - WebPanel Familias e Templates

## Papel do documento
empirico e operacional

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md

## Usado por
08-guia-para-agente-gpt.md

## Objetivo
Concentrar familias estruturais de WebPanel, templates representativos sanitizados e regras especificas de selecao e clonagem.

## Fontes consolidadas
- 27-familias-estruturais-de-webpanel.md

## Origem incorporada - 27-familias-estruturais-de-webpanel.md

## Papel do documento
empirico e operacional

## Nivel de confianca predominante
medio

## Depende de
10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 30-inventario-bruto-kb.md

## Usado por
02-regras-operacionais-e-runtime.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Identificar familias estruturais reais de `WebPanel` a partir do acervo XML da KB `KBBase18`.
Permitir escolha automatizavel de template interno real, reduzindo dependencia de selecao manual caso a caso.

## Metodo

- Evidencia direta: foram analisados 1196 XMLs de `WebPanel` em `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel`.
- Evidencia direta: o agrupamento abaixo nao usa nome do objeto como criterio principal; usa assinatura estrutural baseada em inventario de `Part`, presenca de `events`, `grid`, `table`, `action`, `textblock`, `image`, `tab`, uso de variaveis e tamanho do XML.
- Inferencia forte: as familias foram consolidadas para uso pratico; em alguns casos uma familia junta assinaturas raras vizinhas quando isso reduz ruido sem esconder variabilidade.
- Hipotese: a selecao automatica de template deve primeiro casar a familia estrutural e so depois refinar por `parent`, `module` e blocos internos.

## Visao geral

- Evidencia direta: em praticamente todo o acervo de `WebPanel`, repetem-se 7 `Part type`: `d24a58ad-57ba-41b7-9e6e-eaca3543c778`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `c44bd5ff-f918-415b-98e6-aca44fed84fa`, `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c`, `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- Evidencia direta: os sinais estruturais mais discriminantes neste recorte foram `grid`, `action`, `textblock`, `image`, `tab`, presenca real de codigo em eventos e uso de layout tabular.
- Evidencia direta: contagens agregadas no universo de 1196 `WebPanel`: `variables` em 1196, `events` em 463, `action` em 323, `textblock` em 227, `image` em 77, `grid` em 25, `tab` em 14.
- Inferencia forte: para geracao pratica, a familia estrutural e um pre-filtro melhor do que o nome do objeto.

## Familia 1 - Casca minima sem eventos

- Evidencia direta: 3 objetos com assinatura estrutural minima `table;variables`.
- Evidencia direta: tamanho medio aproximado de 2986 bytes; minimo 2193; maximo 3920.
- Inferencia forte: variabilidade interna baixa.
- Template base: `WP0001`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0001.xml`.
- Justificativa da escolha: menor exemplar observado e layout praticamente vazio, bom como referencia de casca minima.

### Part types recorrentes

- Evidencia direta: recorrencia da familia observada sobre os 7 `Part type` fixos do tipo.
- Obrigatorios (~100% nesta familia): `d24a58ad-57ba-41b7-9e6e-eaca3543c778`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `c44bd5ff-f918-415b-98e6-aca44fed84fa`, `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c`, `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- Comuns: nenhum sinal adicional recorrente alem da casca.
- Raros: nao ha `grid`, `action`, `image`, `tab` ou eventos relevantes.

### Edicao e preservacao

- Evidencia direta: `Source` do layout e minimo e composto por uma unica `table`.
- Inferencia forte: blocos mais seguros para edicao controlada sao nome do objeto, descricao e texto/layout minimo dentro do `Source`.
- Inferencia forte: devem ser preservados o inventario de `Part`, a existencia da `table` raiz e a relacao de `parent` do template escolhido.
- Hipotese: esta familia serve como ponto de partida para tela muito simples ou casca de navegacao basica.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para `home/menu` muito simples, pagina em branco ou redirecionamento minimo.
- Inferencia forte: clonar preservando todos os `Part type` e alterando o minimo possivel no layout.
- Hipotese: abortar se o alvo precisar `grid`, acoes clicaveis, controles customizados ou regras/eventos nao presentes no template.

## Familia 2 - Casca gerada por defaults ou pattern

- Evidencia direta: 726 objetos com assinatura estrutural dominada por `variables`, sem sinais fortes de `grid`, `action`, `textblock`, `image` ou `tab`.
- Evidencia direta: tamanho medio aproximado de 3534 bytes; minimo 3242; maximo 3839.
- Evidencia direta: exemplos inspecionados exibem `Defaults=WorkWith:Templates...`, `WEB_COMP=Yes`, `IsGeneratedObject=True` e `parent` ligado a objetos `WorkWith`.
- Inferencia forte: variabilidade interna baixa na casca, mas dependencia contextual alta.
- Template base: `WP0003`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0003.xml`.
- Justificativa da escolha: representa de forma clara a familia gerada, com marcas estruturais explicitas de origem em template/pattern.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` fixos se repetem nesta familia.
- Obrigatorios (~100% nesta familia): os mesmos 7 `Part type` base do tipo.
- Comuns: propriedades internas de geracao em `layout`, `events` e `variables`.
- Raros: controles visuais ricos; nao ha indicio forte de `grid`, `image` ou `tab`.

### Edicao e preservacao

- Evidencia direta: parte relevante do conteudo aparece em propriedades e defaults, nao em layout funcional rico.
- Inferencia forte: nomes textuais e alguns valores de propriedades recorrentes parecem mais editaveis do que o esqueleto interno.
- Inferencia forte: devem ser preservados `parent`, `parentGuid`, marcadores de geracao e inventario completo de `Part`.
- Hipotese: alterar esta familia longe do contexto `WorkWith` pode introduzir risco estrutural alto.
- Evidencia direta (WWP): objetos WW panels gerados pelo padrao WorkWithPlus seguem a convencao `WW` + nome da Transaction (ex.: `WWCliente`); o campo `MasterPage` aponta tipicamente para `WWMasterPage`.
- Inferencia forte (WWP): `WWPBaseObjects` e infraestrutura de suporte compartilhada do ecossistema WWP -- nao deve ser clonado nem modificado diretamente; sua presenca no `parent` ou nas dependencias e sinal de que o objeto e parte da familia gerada e de alto acoplamento.

### Uso pratico e clonagem

- Inferencia forte: uso ideal quando o alvo tambem for casca gerada ou fortemente dependente de objeto pai.
- Inferencia forte: clonar apenas com template interno de mesma familia e `parent` estruturalmente proximo.
- Hipotese: abortar quando o objetivo for um `WebPanel` autoral ou quando o clone exigir retirar propriedades opacas de geracao.

## Familia 3 - Navegacional com eventos

- Evidencia direta: 94 objetos com assinatura `table;events;variables`.
- Evidencia direta: tamanho medio aproximado de 14152 bytes; minimo 3853; maximo 75534.
- Evidencia direta: exemplos inspecionados trazem `table` responsiva, controles `ucw` e codigo explicito em eventos.
- Inferencia forte: variabilidade interna media.
- Template base: `WP0004`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0004.xml`.
- Justificativa da escolha: combina layout navegacional, controles customizados e eventos reais, sem ainda entrar em grids ou abas.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): `layout`, `rules`, `events`, `conditions`, `variables`, `help`, `inner html` nos GUIDs recorrentes do tipo.
- Comuns: `table`, eventos nomeados, variaveis de apoio e controles `ucw`.
- Raros: `grid`, `tab`, imagem e blocos de lista mais densos.

### Edicao e preservacao

- Inferencia forte: textos, captions e trechos pequenos de `Event` sao candidatos mais seguros para edicao incremental.
- Inferencia forte: layout responsivo, controles `ucw`, bindings e nomes de eventos ja referenciados devem ser preservados.
- Hipotese: a retirada de controles customizados tende a quebrar a semelhanca estrutural da familia.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para `home/menu` e navegacao basica com acoes dirigidas por evento.
- Inferencia forte: clonar escolhendo template do mesmo contexto de `parent` e com quantidade parecida de controles.
- Hipotese: abortar quando o alvo pedir grade/listagem, abas ou forte densidade de elementos textuais/imagem.

## Familia 4 - Formulario com acao

- Evidencia direta: 121 objetos com assinatura `table;action;events;variables`.
- Evidencia direta: tamanho medio aproximado de 18099 bytes; minimo 4000; maximo 96196.
- Evidencia direta: exemplos inspecionados mostram campos de dados, pelo menos uma `action` e eventos de inicializacao/acao.
- Inferencia forte: variabilidade interna media.
- Template base: `WP0854`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0854.xml`.
- Justificativa da escolha: objeto relativamente enxuto, com `action`, dados e eventos reais sem mistura com `grid` ou `tab`.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base de `Part` do tipo.
- Comuns: `action`, `table`, codigo em `events`, variaveis e elementos `data`.
- Raros: `grid`, `tab`, imagem e blocos informativos ricos.

### Edicao e preservacao

- Inferencia forte: textos de botao, descricao, nomes e trechos pequenos do `Source` visual sao os pontos menos agressivos para mudanca.
- Inferencia forte: devem ser preservados o esqueleto da `table`, os bindings de `data`, `action` e a presenca dos eventos ja conectados.
- Hipotese: a remocao de uma `action` existente pode mudar a familia alvo e deve ser evitada sem template melhor.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para `cadastro simples`, acao unica ou formulario curto com confirmacao.
- Inferencia forte: clonar mantendo o mesmo numero basico de acoes e a distribuicao geral dos controles.
- Hipotese: abortar quando houver necessidade de grade, abas, imagem forte ou grande volume de navegacao cruzada.

## Familia 5 - Formulario textual com acao

- Evidencia direta: 106 objetos com assinatura `table;action;textblock;events;variables`.
- Evidencia direta: tamanho medio aproximado de 24550 bytes; minimo 7056; maximo 107986.
- Evidencia direta: a familia acrescenta densidade de `textblock` sobre a familia anterior.
- Inferencia forte: variabilidade interna media para alta.
- Template base: `WP0181`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0181.xml`.
- Justificativa da escolha: menor exemplar observado da assinatura central desta familia, com `textblock`, `action`, eventos e layout ainda compacto.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `textblock`, `table`, eventos reais, variaveis e pelo menos uma area de acao em grande parte da familia.
- Raros: `grid`, `tab` e uso de imagem.

### Edicao e preservacao

- Inferencia forte: textos, captions e blocos claramente rotulados sao os candidatos mais seguros de edicao.
- Inferencia forte: devem ser preservados estrutura do layout, ordem geral das secoes, controles customizados e nomes de bindings.
- Hipotese: se o alvo exigir forte acoplamento com componente especifico, convem template ainda mais proximo do que o representante desta familia.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para painel textual, formulario guiado ou pagina explicativa com uma ou mais acoes.
- Inferencia forte: clonar preservando hierarquia das tabelas internas e a distribuicao entre texto e acao.
- Hipotese: abortar quando o alvo exigir grade/lista ou quando a semelhanÃ§a textual esconder dependencias de componentes opacos.

## Familia 6 - Painel textual sem acao dominante

- Evidencia direta: 33 objetos com assinatura `table;textblock;events;variables`.
- Evidencia direta: tamanho medio aproximado de 17310 bytes; minimo 3945; maximo 72722.
- Inferencia forte: variabilidade interna media.
- Template base: `WP0189`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0189.xml`.
- Justificativa da escolha: ha `textblock`, evento real, variaveis e um componente central, com pouca enfase em `action`.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `textblock`, `table`, eventos, variaveis e controle central informativo.
- Raros: `action` relevante, `grid`, `tab` e imagem.

### Edicao e preservacao

- Inferencia forte: captions, titulos e textos explicativos sao os trechos mais seguros.
- Inferencia forte: devem ser preservados layout principal, componente central e variaveis associadas.
- Hipotese: alterar o componente central tende a mover o objeto para outra familia pratica.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para `home/menu` informativo, painel de resumo ou navegacao basica sem grade.
- Inferencia forte: clonar quando o alvo for centrado em exibicao de informacao e eventos simples.
- Hipotese: abortar se o objetivo real depender de operacoes CRUD ou lista tabular.

## Familia 7 - Painel informativo com imagem

- Evidencia direta: 39 objetos com assinatura `table;action;textblock;image;events;variables`.
- Evidencia direta: tamanho medio aproximado de 57176 bytes; minimo 5109; maximo 530462.
- Inferencia forte: variabilidade interna alta.
- Template base: `WP0172`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0172.xml`.
- Justificativa da escolha: combina imagem, texto, acao e eventos em um painel rico, sem ainda exigir grade.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `textblock`, `image`, `action`, `table`, eventos e variaveis.
- Raros: `grid` e `tab`.

### Edicao e preservacao

- Inferencia forte: textos, captions e algumas referencias visuais aparentes sao editaveis com risco menor do que o esqueleto.
- Inferencia forte: devem ser preservados layout das secoes, posicoes de imagem, bindings e quaisquer blocos visuais raros.
- Hipotese: trocar imagem por controle nao equivalente pode exigir familia mais adequada.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para tela informativa, mensagem orientada ao usuario, confirmacao ou passo guiado com apoio visual.
- Inferencia forte: clonar com template de densidade visual parecida.
- Hipotese: abortar quando o alvo exigir grade, tabs ou navegacao pesada entre componentes.

## Familia 8 - Tabulado com abas

- Evidencia direta: 14 objetos com assinatura `table;action;textblock;tab;events;variables`.
- Evidencia direta: tamanho medio aproximado de 91334 bytes; minimo 33256; maximo 294996.
- Evidencia direta: exemplar inspecionado possui `tab`, acoes, blocos internos aninhados, `embeddedpage` e eventos longos.
- Inferencia forte: variabilidade interna alta.
- Template base: `WP0981`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0981.xml`.
- Justificativa da escolha: evidencia de forma clara o custo estrutural adicional introduzido por `tab` e componentes embutidos.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `tab`, `action`, `textblock`, `table`, eventos, variaveis e tabelas internas aninhadas.
- Raros: `grid`; a combinacao com imagem nao foi dominante nesta subfamilia.

### Edicao e preservacao

- Inferencia forte: textos, nomes e conteudo local de abas sao mais seguros do que alteracoes no container de abas.
- Inferencia forte: devem ser preservados a estrutura do `tab`, ordem das paginas, controles embutidos e nomes ligados aos eventos.
- Hipotese: remover abas ou mover controles entre paginas tende a elevar muito o risco estrutural.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para consulta/edicao com multiplas secoes visuais ou navegacao basica por abas.
- Inferencia forte: clonar apenas quando o alvo realmente precisar abas e houver template interno muito proximo.
- Hipotese: abortar se nao houver familia tabulada identificavel ou se o alvo pedir simplificacao radical da estrutura.

## Familia 9 - Lista com grid

- Evidencia direta: 21 objetos nas assinaturas dominadas por `grid`, consolidadas aqui como familia unica de lista com grade.
- Evidencia direta: tamanho medio aproximado de 67625 bytes; minimo 10626; maximo 240342.
- Evidencia direta: exemplos inspecionados mostram `grid` interna combinada com `action`, `textblock` e eventos.
- Inferencia forte: variabilidade interna alta.
- Template base: `WP0195`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0195.xml`.
- Justificativa da escolha: traz `grid` explicita, acoes, texto e eventos, servindo como referencia concreta para familia de lista.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `grid`, `table`, `events`, `variables`; em parte relevante tambem `action` e `textblock`.
- Raros: `tab`; imagem aparece so em subgrupos menores.

### Edicao e preservacao

- Inferencia forte: textos, titulos, captions de acoes e alguns trechos de evento sao mais seguros do que a grade em si.
- Inferencia forte: devem ser preservados a estrutura do `grid`, tabela interna da grade, bindings das colunas e eventos ligados a carga ou selecao.
- Hipotese: mudar a forma da grade, remover linhas de layout ou alterar bindings sem template muito proximo tende a falhar.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para `consulta/lista` e navegacao basica baseada em itens.
- Inferencia forte: clonar sempre a partir de template que ja tenha `grid` e complexidade semelhante.
- Hipotese: abortar quando o alvo exigir tela puramente formular sem grade ou quando nao houver equivalencia clara de bindings.

## Familia 10 - Residual misto de baixa repeticao

- Evidencia direta: 26 objetos distribuidos em assinaturas raras vizinhas, incluindo combinacoes com `image` sem `textblock` dominante e outras misturas pouco frequentes.
- Evidencia direta: tamanho medio aproximado de 43354 bytes; minimo 2762; maximo 114888.
- Inferencia forte: variabilidade interna muito alta.
- Template base: `WP0978`.
- XML original: `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WP0978.xml`.
- Justificativa da escolha: objeto real pequeno e compreensivel, util como representante de painel informativo misto fora das familias maiores.

### Part types recorrentes

- Evidencia direta: os 7 `Part type` base se repetem.
- Obrigatorios (~100% nesta familia): inventario base do tipo.
- Comuns: `table`, eventos, variaveis e algum elemento visual adicional.
- Raros: qualquer combinacao especifica desta familia residual deve ser tratada como pouco padronizada.

### Edicao e preservacao

- Inferencia forte: so convem editar textos, nomes e ajustes visuais localizados.
- Inferencia forte: devem ser preservados o layout completo e todos os controles nao triviais.
- Hipotese: esta familia funciona melhor como fallback quando nenhuma familia principal casa bem.

### Uso pratico e clonagem

- Inferencia forte: uso ideal para tela informativa simples ou caso isolado visualmente diferente.
- Inferencia forte: clonar apenas com semelhanca muito clara ao template.
- Hipotese: abortar se o alvo puder ser encaixado em familia principal mais padronizada.

## Regras operacionais por familia

- Evidencia direta: todas as familias aqui descritas foram observadas no mesmo `Object/@type` de `WebPanel`.
- Inferencia forte: o algoritmo pratico mais seguro e `identificar familia -> escolher template interno da mesma familia -> preservar inventario de Part e esqueleto -> editar blocos textuais/Source local -> validar diff estrutural`.
- Inferencia forte: nunca remover `Part type` recorrente do template.
- Inferencia forte: nunca generalizar `WebPanel` como tipo homogeneo; a familia estrutural deve ser decidida antes da clonagem.
- Hipotese: se dois templates possiveis parecerem proximos, preferir o de menor complexidade que ainda contenha todos os sinais necessarios do alvo.

## Quando abortar

- Inferencia forte: abortar quando nao houver familia claramente identificavel.
- Inferencia forte: abortar quando o alvo exigir `grid`, `tab`, imagem forte ou componente customizado ausente na familia escolhida.
- Inferencia forte: abortar quando o `parent` observado no template parecer parte estrutural do objeto e nao houver equivalente interno proximo.
- Hipotese: abortar tambem quando a mudanca pretendida exigir eliminar bindings ou controles opacos ainda nao entendidos.

## Tabela resumo

| Familia | Quando usar | Risco | Template base |
| --- | --- | --- | --- |
| Casca minima sem eventos | casca simples, pagina em branco, navegacao minima | medio | `WP0001` |
| Casca gerada por defaults ou pattern | clone de objeto gerado ou dependente de `WorkWith` | alto | `WP0003` |
| Navegacional com eventos | menu, home navegacional, acoes por evento | medio-alto | `WP0004` |
| Formulario com acao | cadastro simples, acao unica, formulario curto | medio-alto | `WP0854` |
| Formulario textual com acao | painel guiado, formulario com explicacao textual | alto | `WP0181` |
| Painel textual sem acao dominante | resumo informativo, painel simples | medio-alto | `WP0189` |
| Painel informativo com imagem | telas orientadas ao usuario com apoio visual | alto | `WP0172` |
| Tabulado com abas | multiplas secoes visuais, navegacao por abas | muito alto | `WP0981` |
| Lista com grid | consulta/lista baseada em grade | muito alto | `WP0195` |
| Residual misto de baixa repeticao | fallback somente quando nenhuma familia principal encaixa | muito alto | `WP0978` |

## Sintese final

- Evidencia direta: o acervo de `WebPanel` nao e homogeneo; a distribuicao estrutural observada forma familias recorrentes e uma cauda residual rara.
- Inferencia forte: a geracao pratica de `XPZ` para `WebPanel` deve partir de selecao automatica de familia estrutural antes da escolha do template.
- Inferencia forte: `Casca minima`, `Navegacional com eventos` e `Formulario com acao` sao os pontos de entrada mais previsiveis para clonagem interna.
- Inferencia forte: `Grid`, `Tab` e familias residuais exigem selecao de template muito mais cuidadosa.
- Hipotese: este mapa ja reduz a necessidade de escolha manual de template, mas ainda depende de validacao por tentativa real de importacao para refinar fronteiras entre familias proximas.
## Anexos - Templates sanitizados
- Evidencia direta: os quatro anexos abaixo preservam a quantidade de Part, a ordem dos blocos, Object/@type, parent*, moduleGuid e a hierarquia XML dos templates originais.
- Inferencia forte: eles podem servir como base de clonagem rapida por familia, desde que o agente continue respeitando o mapa estrutural deste documento.
- Hipotese: os anexos sao mais uteis como molde estrutural do que como objeto pronto para importacao, pois alguns nomes e textos foram anonimizados de forma deliberada.
### Template 1 - Menu/Home
- Familia associada: Navegacional com eventos
- Origem estrutural: WP0004.xml
- Objetivo do anexo: oferecer um menu/home com botoes acionados por eventos nomeados.
```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="7695ebec-b3d5-4467-acf3-87c5cbe764f3" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-10-30T00:15:33.0000000Z" checksum="7aa6a08a0f601d3c5ec1f665893bdf94" fullyQualifiedName="WPExemploMenu" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="9a7d819d-5964-440f-9bfc-6661bbf1d096" name="WPExemploMenu" type="c9584656-94b6-4ccd-890f-332d11fc2c25" description="Menu Principal" parent="Almoxarifado" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778">
    <Source><![CDATA[<GxMultiForm rootId="2" version="html:15.0.0;layout:17.11.0"><Form id="2" type="layout"><detail><layout><table controlName="MainTable" tableType="Responsive" responsiveSizes="[]"><row><cell><table controlName="TableGeral" tableType="Flex" responsiveSizes="[]" flexWrap="Wrap"><row><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;ButtonOpcaoA&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Enabled&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'AbrirOpcaoA'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opcao A&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Class&lt;/Name&gt;&lt;Value&gt;button-tertiary Altura_100px&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;ButtonOpcoes&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Enabled&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'AbrirOpcoes'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opcoes&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Class&lt;/Name&gt;&lt;Value&gt;button-tertiary Altura_100px&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;ButtonOpcaoB&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Enabled&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'AbrirOpcaoB'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opcao B&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Class&lt;/Name&gt;&lt;Value&gt;button-tertiary Altura_100px&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;ButtonOpcaoC&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Enabled&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'AbrirOpcaoC'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opcao C&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Class&lt;/Name&gt;&lt;Value&gt;button-tertiary Altura_100px&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event Start
	
	&url = procLogotipoSistemaPadraoUrl()

	if GAMRepository.CheckPermission(lower("WWExemploOpcaoB")+ "_Execute")
		ButtonOpcaoB.Icon = Link(&url)
	else
		ButtonOpcaoB.Visible = false
	endif

	if GAMRepository.CheckPermission(lower("WWExemploOpcaoA")+ "_Execute")
		ButtonOpcaoA.Icon = Link(&url)
	else
		ButtonOpcaoA.Visible = false
	endif

	if GAMRepository.CheckPermission(lower("WWExemploLista")+ "_Execute")
		ButtonOpcoes.Icon = Link(&url)
	else
		ButtonOpcoes.Visible = false
	endif

	if GAMRepository.CheckPermission(lower("WWExemploOpcaoC")+ "_Execute")
		ButtonOpcaoC.Icon = Link(&url)
	else
		ButtonOpcaoC.Visible = false
	endif

Endevent

Event 'AbrirOpcaoB'
	
	WWExemploOpcaoB()
	
Endevent

Event 'AbrirOpcaoA'
	
	WWExemploOpcaoA()
	
Endevent

Event 'AbrirOpcoes'
	
	WWExemploLista()
	
Endevent

Event 'AbrirOpcaoC'
	
	WWExemploOpcaoC()
	
Endevent
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="url">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>url</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Url, GeneXus</Value>
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
      <Value>WPExemploMenu</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Menu Principal</Value>
    </Property>
    <Property>
      <Name>MasterPage</Name>
      <Value>MasterPageDS</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```
### Sanitizacao aplicada
- nomes de objeto e de chamadas semanticamente identificaveis foram anonimizados
- captions e textos visiveis foram trocados por equivalentes genericos
- parent*, moduleGuid, Part type e hierarquia XML foram preservados
### Template 2 - Formulario
- Familia associada: Formulario com acao
- Origem estrutural: WP0854.xml
- Objetivo do anexo: oferecer um formulario minimo com parametros, acao e evento de inicializacao.
```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="ce54ed93-ebec-4ed1-b829-873e61f7f6d5" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-04T00:44:11.0000000Z" checksum="e5b302b839ff70d5d68c7d908ca2d8a6" fullyQualifiedName="WPExemploFormulario" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="7c374c60-a2fe-4e23-9d2e-49a89b28695e" name="WPExemploFormulario" type="c9584656-94b6-4ccd-890f-332d11fc2c25" description="WP Exemplo Formulario" parent="Arquivo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778">
    <Source><![CDATA[<GxMultiForm rootId="1" version="html:15.0.0;layout:17.11.0"><Form id="1" type="layout"><detail><layout><table controlName="MainTable" tableType="Responsive" responsiveSizes="[]"><row><cell><data attribute="&amp;ArquivoEmpresaId" labelCaption="Item Empresa Id:" /></cell></row><row><cell><data attribute="&amp;ArquivoId" labelCaption="Item Id:" /></cell></row><row><cell><action controlName="Cancel" onClickEvent="Cancel" /></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[parm(in:&ItemEmpresaId, in:&ItemId);
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event Start
	
	procExecutaAcao(&ItemEmpresaId, &ItemId)
	
Endevent
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
    <Variable Name="ArquivoId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ArquivoId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ArquivoEmpresaId">
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
          <Value>Attribute:ArquivoEmpresaId</Value>
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
      <Value>WPExemploFormulario</Value>
    </Property>
    <Property>
      <Name>MasterPage</Name>
      <Value>(none)</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityLow</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```
### Sanitizacao aplicada
- nomes de objeto e variaveis semanticas foram generalizados
- labels e descricoes textuais foram trocadas por termos neutros
- bindings estruturais, Part type e ordem dos blocos foram preservados
### Template 3 - Lista/Grid
- Familia associada: Lista com grid
- Origem estrutural: WP0195.xml
- Objetivo do anexo: oferecer um template rico com grid, acoes, eventos e variaveis suficientes para clonagem por familia de lista.
```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="2896f7a3-4874-40c9-ac7e-f57685983b0f" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-09-06T18:59:50.0000000Z" checksum="c08b667bb1c14f04fd07448ce5c20b4c" fullyQualifiedName="WPExemploLista" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="891f84b2-0377-4aa3-b0b8-60cb3d882caf" name="WPExemploLista" type="c9584656-94b6-4ccd-890f-332d11fc2c25" description="Acesso ao Sistema" parent="GAM_Frontend" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778">
    <Source><![CDATA[<GxMultiForm rootId="2" version="html:15.0.0;layout:17.11.0"><Form id="2" type="layout"><detail><layout><table controlName="MainTable" class="table-login stack-top-xxl" tableType="Responsive" responsiveSizes="[]"><row><cell cellClass="stack-bottom-xl" hAlign="Center"><textblock controlName="TBTitle" caption="Acesso ao Sistema" class="Title" /></cell></row><row><cell cellClass="stack-bottom-l" hAlign="Center"><textblock controlName="TBRepositorioAtual" /></cell></row><row><cell cellClass="stack-bottom-l" hAlign="Center"><table controlName="TblCriarAcesso" class="Table w-100" tableType="Responsive" responsiveSizes="[{&quot;scale&quot;:&quot;sm&quot;,&quot;rows&quot;:[[{&quot;width&quot;:75}]]}]"><row><cell cellClass="" hAlign="Right"><textblock controlName="TBPossuiCadastro" caption="Nao possui cadastro?" /></cell><cell cellClass="" hAlign="Left" vAlign="Default"><textblock controlName="TBCriarAcesso" caption="Criar acesso" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'Register'&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row><row><cell><data attribute="&amp;PerfilAcesso" labelPosition="Top" labelCaption="Entrar em" class="Attribute w-100" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlType&lt;/Name&gt;&lt;Value&gt;Combo Box&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass=""><data attribute="&amp;NomeUsuario" labelPosition="Top" labelCaption="Usuario" class="Attribute w-100" inviteMessage="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;AutoResize&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass=""><data attribute="&amp;SenhaUsuario" labelPosition="Top" labelCaption="Senha" class="Attribute w-100" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;idEnableShowPasswordHint&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass="stack-bottom-l" hAlign="Right"><textblock controlName="TBEsqueceuSenha" caption="Esqueceu a senha" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'ForgotPassword'&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass="stack-bottom-l"><data attribute="&amp;LembrarAcesso" labelCaption="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlTitle&lt;/Name&gt;&lt;Value&gt;Lembrar acesso&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass="" hAlign="Center" vAlign="Default"><errorviewer controlName="ErrorViewer1" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;DisplayMode&lt;/Name&gt;&lt;Value&gt;Bullet List&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row><row><cell cellClass="stack-bottom-l"><table controlName="TblBotaoEntrar" tableType="Responsive" responsiveSizes="[{&quot;scale&quot;:&quot;sm&quot;,&quot;rows&quot;:[[{&quot;width&quot;:50,&quot;label&quot;:100}]]}]"><row><cell cellClass=""><data attribute="&amp;ManterConectado" labelCaption="" class="Attribute inline-left-xl" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlTitle&lt;/Name&gt;&lt;Value&gt;Manter conectado&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell cellClass=""><action controlName="Login" onClickEvent="Enter" caption="Entrar" class="button button-primary w-100" /></cell></row></table></cell></row><row><cell cellClass="stack-top-l" hAlign="Center"><table controlName="TblAutenticacaoExterna" tableType="Responsive" responsiveSizes="[]"><row><cell cellClass="stack-bottom-l"><textblock controlName="TBAutenticacaoExterna" caption="Ou entrar com" class="text-line-separator" /></cell></row><row><cell hAlign="Center"><grid controlName="GridTiposAcessoExterno"><table controlName="TblGridTiposAcessoExterno" tableType="Responsive" responsiveSizes="[{&quot;scale&quot;:&quot;xs&quot;,&quot;rows&quot;:[[{},{&quot;visible&quot;:false}]]},{&quot;scale&quot;:&quot;sm&quot;,&quot;rows&quot;:[[{&quot;width&quot;:100},{&quot;visible&quot;:false}]]}]"><row rowClass=""><cell cellClass="stack-bottom-l"><action controlName="AutenticacaoExterna" onClickEvent="'SelectTipoAutenticacao'" caption="Autenticacao externa" class="button button-tertiary w-100" /></cell><cell><data attribute="&amp;NomeTipoAcesso" labelPosition="None" readonly="True" /></cell></row></table></grid></cell></row></table></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event Start
	TBRepositorioAtual.Visible	= False
	TblAutenticacaoExterna.Visible	= False
	TblCriarAcesso.Visible	= False
	TBEsqueceuSenha.Visible			= False
	&ManterConectado.Visible		= False
	&LembrarAcesso.Visible			= False
		
	//Valid current connection
	&conexaoOk = SANITIZED\\USERSecurity.GAM.CheckConnection()
	If SANITIZED\\USERSecurity.GAM.isMultitenant()
		Do "isMultitenantInstallation"
	Else
		If &conexaoOk
			TblCriarAcesso.Visible	= True
		Else
			If SANITIZED\\USERSecurity.GAM.GetDefaultRepository(&RepositorioGuid)
				&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnectionByRepositorioGuid(&RepositorioGuid, &GAMErrorCollection)
			Else
				&ColecaoInfoConexao = SANITIZED\\USERSecurity.GAM.GetConnections()
				If &ColecaoInfoConexao.Count > 0
					//The first connection found is established by default
					&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnection(&ColecaoInfoConexao.Item(1).Name, &GAMErrorCollection)
				EndIf
			Endif
		Endif
		If GAMRepository.IsGAMAdministrator(&GAMErrorCollection)
			&GAMRepository = SANITIZED\\USERSecurity.GAMRepository.Get()
			TBRepositorioAtual.Caption = Format(!"%1: %2", "Repositorio", &GAMRepository.Name)
			TBRepositorioAtual.Visible = True
   		Endif
	Endif
EndEvent


Event Refresh
	GridTiposAcessoExterno.Visible 	= False

	&GAMRepository = GAMRepository.Get()
	Do Case
	Case &GAMRepository.UserIdentification = GAMRepositoryUserIdentifications.Name
		&NomeUsuario.InviteMessage = GAMRepositoryUserIdentifications.EnumerationDescription(GAMRepositoryUserIdentifications.Name)
	Case &GAMRepository.UserIdentification = GAMRepositoryUserIdentifications.EMail
		&NomeUsuario.InviteMessage = GAMRepositoryUserIdentifications.EnumerationDescription(GAMRepositoryUserIdentifications.EMail)
	Case &GAMRepository.UserIdentification = GAMRepositoryUserIdentifications.NameEmail
		&NomeUsuario.InviteMessage = GAMRepositoryUserIdentifications.EnumerationDescription(GAMRepositoryUserIdentifications.NameEmail)
	EndCase

	&temErros = False
	//Get the latest errors in GAM
	&GAMErrorCollection = GAMRepository.GetLastErrors()
	If &GAMErrorCollection.Count > 0
		Do Case
		Case &GAMErrorCollection.Item(1).Code = GAMErrorMessages.SessionExpired  OR  &GAMErrorCollection.Item(1).Code = GAMErrorMessages.ConnectionNotSpecified  OR  &GAMErrorCollection.Item(1).Code = GAMErrorMessages.UserMustBeAuthenticated
			//DO NOT display these messages
		Case &GAMErrorCollection.Item(1).Code = GAMErrorMessages.UserMissingRequiredData
			//Webpanel to Complete User data
			WPCompletaCadastroExemplo(&EstadoAutenticacao)
			&temErros = True
		Otherwise
			&temErros = True
			&SenhaUsuario.SetEmpty()
			Do "DisplayMessages"
		EndCase
	Endif

	If not &temErros
		&sessaoValida = GAMSession.IsValid(&GAMSession, &GAMErrorDelete)
	Endif
	If &sessaoValida  AND  not &GAMSession.IsAnonymous  AND  not &temErros
		If not &temErros
			//Session ok, user authenticated
			&UrlDestino = GAMRepository.GetLastErrorsUrlDestino()
			If &UrlDestino.IsEmpty()
				WPInicialExemplo()
			Else
				Link(&UrlDestino)
			Endif
		Endif
	Else
		//Authentication type list
		&PerfilAcesso.Clear()
		&Idioma = getIdiomaProperty(!"culture")
		&TiposAutenticacao = GAMRepository.GetEnabledTiposAutenticacao(&Idioma, &GAMErrorCollection)
		For &TipoAutenticacao in &TiposAutenticacao
			If &TipoAutenticacao.NeedNomeUsuario //Authentication types you must enter the NomeUsuario in this web panel
				&PerfilAcesso.AddItem(&TipoAutenticacao.Name, &TipoAutenticacao.Description)
			Else
				GridTiposAcessoExterno.Visible = True
			EndIf
		EndFor
		If &PerfilAcesso.Count 	<= 1
			&PerfilAcesso.Visible = False
		Else
			&PerfilAcesso = &TiposAutenticacao.Item(1).Name
		Endif

		//Initialize variables if the user chooses to keep that information 
		&operacaoOk = GAMRepository.GetRememberLogin(&PerfilAcesso, &AuxNomeUsuario, &UserLembrarAcesso, &GAMErrorCollection)
		If not &AuxNomeUsuario.IsEmpty()
			&NomeUsuario = &AuxNomeUsuario
		Endif
		If &UserLembrarAcesso = GAMRememberUserTypes.Login
			&LembrarAcesso = True
		Endif

		//Select Default Authentication Type, Display Remember User if it is enabled on Repository
		If &PerfilAcesso.Count > 1
			&PerfilAcesso = &GAMRepository.DefaultTipoAutenticacaoName
		Endif
		Do "DisplayCheckBox"
		For &TipoAutenticacao in &TiposAutenticacao
			If &TipoAutenticacao.Name = &PerfilAcesso
				Do "ValidPerfilAcessoOTP"
				Exit
			Endif
		EndFor
	Endif
EndEvent


Event GridTiposAcessoExterno.Load
	For &TipoAutenticacao in &TiposAutenticacao
		If &TipoAutenticacao.RedirToAuthenticate
			&NomeTipoAcesso 						= UrlDestinoEncode(&TipoAutenticacao.Name.Trim())
			AutenticacaoExterna.Caption 		= &TipoAutenticacao.Description.Trim()
			AutenticacaoExterna.TooltipText 	= Format("Entrarwith1", &TipoAutenticacao.Description.Trim() )
			If TblAutenticacaoExterna.Visible = False
				TblAutenticacaoExterna.Visible		= True
			EndIf
			Load
		Endif
	EndFor
EndEvent


Event &PerfilAcesso.Click
	&TiposAutenticacao 	= GAMRepository.GetEnabledTiposAutenticacao(&Idioma, &GAMErrorCollection)
	&modoValidacao 				= False
	For &TipoAutenticacao in &TiposAutenticacao
		If &TipoAutenticacao.Name = &PerfilAcesso
			Do "ValidPerfilAcessoOTP"
			Exit
		Endif
	EndFor
	If &modoValidacao = False
		&SenhaUsuario.Visible 		= True
		&SenhaUsuario.InviteMessage	= "Senha"
		Login.Caption				= "Entrar"
		TBEsqueceuSenha.Visible			= True
	Endif
EndEvent


Event Enter
	//Set Remember User type
	Do Case
	Case &ManterConectado
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.Authentication
	Case &LembrarAcesso
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.Login
	Otherwise
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.None
	EndCase

	////////////////////////////////////////////////////////////
	//Send Custom Properties (optional) ////////////////////////
	//&GAMProperty = new()
	//&GAMProperty.Id		= "Company"
	//&GAMProperty.Value	= "SANITIZED\\USER"
	//&GAMLoginAdditionalParameters.Properties.Add(&GAMProperty)
	//These properties are saved in the session when the user authenticates
	////////////////////////////////////////////////////////////

	&GAMLoginAdditionalParameters.TipoAutenticacaoName = &PerfilAcesso
	&GAMLoginAdditionalParameters.OTPStep				= 1
	&loginEfetuado = GAMRepository.Login(&NomeUsuario, &SenhaUsuario, &GAMLoginAdditionalParameters, &GAMErrorCollection )
	If &loginEfetuado
		GAMRepository.ClearLastErrors()
		&UrlDestino = GAMRepository.GetLastErrorsUrlDestino()
		If &UrlDestino.IsEmpty()
			WPInicialExemplo()
		Else
			Link(&UrlDestino)
		Endif
	Else
		If &GAMErrorCollection.Count > 0
			Do Case
			Case (&GAMErrorCollection.Item(1).Code = GAMErrorMessages.SenhaUsuarioExpired  OR  &GAMErrorCollection.Item(1).Code = GAMErrorMessages.SenhaUsuarioMustBeChanged)
				//Webpanel to Change Password
				WPAlteraSenhaExemplo(&EstadoAutenticacao)
			Case &GAMErrorCollection.Item(1).Code = GAMErrorMessages.UserMissingRequiredData
				//Webpanel to Complete User data
				WPCompletaCadastroExemplo(&EstadoAutenticacao)
			Case &GAMErrorCollection.Item(1).Code = GAMErrorMessages.UserAccessCodeSent  OR  &GAMErrorCollection.Item(1).Code = GAMErrorMessages.UserMustValidateSecondFactorToFinishAuthentication
				&GAMErrorDelete = GAMRepository.GetLastErrors()
				//Webpanel to validate access code
				WPValidaCodigoExemplo(&EstadoAutenticacao)
			Otherwise
				&SenhaUsuario.SetEmpty()
				Do "DisplayMessages"
			EndCase
		Endif
	Endif
EndEvent


Event 'ForgotPassword'
	WPRecuperaSenhaExemplo(&EstadoAutenticacao)
EndEvent


Event 'Register'
	WPCadastroExemplo()
EndEvent


Event 'SelectTipoAutenticacao'
	//Set Remember User type
	Do Case
	Case &ManterConectado
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.Authentication
	Case &LembrarAcesso
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.Login
	Otherwise
		&GAMLoginAdditionalParameters.RememberUserType = GAMRememberUserTypes.None
	EndCase

	////////////////////////////////////////////////////////////
	//Send properties to GAM Identity Provider (optional) //////
	//&GAMProperty = new()
	//&GAMProperty.Id		= "Idioma"
	//&GAMProperty.Value	= "es-ES"
	//&GAMLoginAdditionalParameters.Properties.Add(&GAMProperty)
	//These properties are saved in the session when the user authenticates on the IDP
	////////////////////////////////////////////////////////////
		
	&GAMLoginAdditionalParameters.TipoAutenticacaoName = &NomeTipoAcesso
	&loginEfetuado = GAMRepository.Login(&NomeUsuario, &SenhaUsuario, &GAMLoginAdditionalParameters, &GAMErrorCollection )
	If &loginEfetuado
		GAMRepository.ClearLastErrors()
	Endif
EndEvent


Sub "isMultitenantInstallation"
	//Read Curent Repository
	&GAMRepository = SANITIZED\\USERSecurity.GAMRepository.Get()
	//Check if the current repository uses an authentication master repository
	If not &GAMRepository.AuthenticationMasterRepositoryId.IsEmpty()
		&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnectionByRepositoryId(&GAMRepository.AuthenticationMasterRepositoryId, &GAMErrorCollection)
	Endif
	If not &conexaoOk
		If SANITIZED\\USERSecurity.GAM.GetDefaultRepository(&RepositorioGuid)
			&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnectionByRepositorioGuid(&RepositorioGuid, &GAMErrorCollection)
		Else
			&ColecaoInfoConexao = SANITIZED\\USERSecurity.GAM.GetConnections()
			If &ColecaoInfoConexao.Count > 0
				//The first connection found is established by default
				&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnection(&ColecaoInfoConexao.Item(1).Name, &GAMErrorCollection)
			EndIf
		Endif
	Endif

	If &conexaoOk
		&GAMRepository = SANITIZED\\USERSecurity.GAMRepository.Get()
		//Check if the current repository uses an authentication master repository
		If not &GAMRepository.AuthenticationMasterRepositoryId.IsEmpty()
			&conexaoOk = SANITIZED\\USERSecurity.GAM.SetConnectionByRepositoryId(&GAMRepository.AuthenticationMasterRepositoryId, &GAMErrorCollection)
			&GAMRepository 	= SANITIZED\\USERSecurity.GAMRepository.Get()
		Endif
		TBRepositorioAtual.Caption = Format(!"%1: %2", "Repositorio", &GAMRepository.Name)
		TBRepositorioAtual.Visible = True
		TblCriarAcesso.Visible	= True
	Endif
EndSub


Sub "DisplayCheckBox"
	Do Case
	Case &GAMRepository.UserLembrarAcessoType = GAMRepositoryRememberUserTypes.Login
		&ManterConectado.Visible	= False
		&LembrarAcesso.Visible 	= True
	Case &GAMRepository.UserLembrarAcessoType = GAMRepositoryRememberUserTypes.Authentication
		&ManterConectado.Visible	= True
		&LembrarAcesso.Visible		= False
	Case &GAMRepository.UserLembrarAcessoType = GAMRepositoryRememberUserTypes.Both
		&ManterConectado.Visible	= True
		&LembrarAcesso.Visible		= True
	Otherwise
		&LembrarAcesso.Visible		= False
		&ManterConectado.Visible	= False
	EndCase
EndSub


Sub "ValidPerfilAcessoOTP"
	If &TipoAutenticacao.NeedNomeUsuario  AND  not &TipoAutenticacao.NeedSenhaUsuario
		&modoValidacao 					= True
		&SenhaUsuario.Visible 		= False
		If &TipoAutenticacao.IsTOTP
			Login.Caption			= "Avancar"
		Else
			Login.Caption			= "Enviar codigo"
		Endif
		TBEsqueceuSenha.Visible			= False
		TblCriarAcesso.Visible	= False
	EndIf
EndSub


Sub "DisplayMessages"
	For &GAMError in &GAMErrorCollection
		Msg(&GAMError.Message)
	EndFor
EndSub
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="TipoAutenticacao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>TipoAutenticacao</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMTiposAutenticacaoimple, SANITIZED\\USERSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="TiposAutenticacao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>TiposAutenticacao</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMTiposAutenticacaoimple, SANITIZED\\USERSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuxNomeUsuario">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuxNomeUsuario</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMUserIdentification, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ColecaoInfoConexao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ColecaoInfoConexao</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMConnectionInfo, SANITIZED\\USERSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMError">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMError</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMError, SANITIZED\\USERSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMErrorCollection">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMErrorCollection</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMError, SANITIZED\\USERSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMErrorDelete">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMErrorDelete</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMError, SANITIZED\\USERSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMLoginAdditionalParameters">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMLoginAdditionalParameters</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMLoginAdditionalParameters, SANITIZED\\USERSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMRepository">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMRepository</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMRepository, SANITIZED\\USERSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GAMSession">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GAMSession</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:GAMSession, SANITIZED\\USERSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="temErros">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>temErros</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="EstadoAutenticacao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>EstadoAutenticacao</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMState, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="conexaoOk">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>conexaoOk</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMBoolean, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="modoValidacao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>modoValidacao</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="operacaoOk">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>operacaoOk</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="sessaoValida">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>sessaoValida</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ManterConectado">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ManterConectado</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="Idioma">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>Idioma</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMIdiomaCulture, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="loginEfetuado">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>loginEfetuado</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="PerfilAcesso">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>PerfilAcesso</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Log on to</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMDescriptionShort, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeTipoAcesso">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeTipoAcesso</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMTipoAutenticacaoName, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="LembrarAcesso">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>LembrarAcesso</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="RepositorioGuid">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>RepositorioGuid</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMGUID, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UrlDestino">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UrlDestino</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMUrlDestino, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeUsuario">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeUsuario</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMUserIdentification, SANITIZED\\USERSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SenhaUsuario">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SenhaUsuario</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMPassword, SANITIZED\\USERSecurityCommon</Value>
        </Property>
        <Property>
          <Name>IsPassword</Name>
          <Value>True</Value>
        </Property>
        <Property>
          <Name>AutoResize</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UserLembrarAcesso">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UserLembrarAcesso</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GAMRememberUserTypes, SANITIZED\\USERSecurityCommon</Value>
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
        <Idioma>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Idioma>
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
    <InnerHtml><![CDATA[]]></InnerHtml>
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
      <Value>WPExemploLista</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Acesso ao Sistema</Value>
    </Property>
    <Property>
      <Name>MasterPage</Name>
      <Value>(none)</Value>
    </Property>
    <Property>
      <Name>AUTO_REFRESH</Name>
      <Value>NO</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityNone</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>WPExemploLista</Value>
    </Property>
    <Property>
      <Name>SPC_WARNINGS_DISABLED</Name>
      <Value>spc0096 spc0107 spc0142 src0294</Value>
    </Property>
    <Property>
      <Name>STD_FUNC_OBJECT</Name>
      <Value>No</Value>
    </Property>
    <Property>
      <Name>WebUX</Name>
      <Value>SMOOTH</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>Exemplos-web,Frontend-web</Categories>
</Object>
```
### Sanitizacao aplicada
- nome do objeto, nomes visiveis e varios identificadores semanticos foram anonimizados
- chamadas de objetos auxiliares foram substituidas por nomes genericos preservando o padrao sintatico
- parent*, moduleGuid, Part type, grid, eventos e hierarquia XML foram preservados
### Template 4 - Eventos
- Familia associada: Painel textual sem acao dominante
- Origem estrutural: WP0189.xml
- Objetivo do anexo: oferecer um painel enxuto com evento Start, variaveis e componente central.
```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-19T14:42:31.0000000Z" checksum="506b2b1a2139bb6343200fccce10bd23" fullyQualifiedName="WPExemploEventos" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="1cbbba77-a1f2-4bf5-af50-b58237e01eb9" name="WPExemploEventos" type="c9584656-94b6-4ccd-890f-332d11fc2c25" description="Painel de Eventos" parent="GAM_General" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778">
    <Source><![CDATA[<GxMultiForm rootId="2" version="html:15.0.0;layout:17.11.0"><Form id="2" type="layout"><detail><layout><table controlName="MainTable" tableType="Responsive" responsiveSizes="[]"><row><cell><textblock controlName="TblTitle" caption="Resumo de Indicadores" class="Title" /></cell></row><row><cell><ucw gxControlType="1458464781" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;PainelViewer&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CliqueItemData&lt;/Name&gt;&lt;Value&gt;&amp;amp;CliqueItemData&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;FiltroAlteradoData&lt;/Name&gt;&lt;Value&gt;&amp;amp;FiltroAlteradoData&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ValoresDestacadosData&lt;/Name&gt;&lt;Value&gt;&amp;amp;ValoresDestacadosData&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event Start
	&From = &Today - 10
	&To = now()
	PainelViewer.Object = PainelIndicadoresExemplo(&From, &To)
Endevent

]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="FiltroAlteradoData">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>FiltroAlteradoData</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:PainelViewerFiltroAlteradoData, GeneXusReporting</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="From">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>From</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Date</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="CliqueItemData">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>CliqueItemData</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:PainelViewerCliqueItemData, GeneXusReporting</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="To">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>To</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Date</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ValoresDestacadosData">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ValoresDestacadosData</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:PainelViewerValoresDestacadosData, GeneXusReporting</Value>
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
    <InnerHtml><![CDATA[]]></InnerHtml>
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
      <Value>WPExemploEventos</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Painel de Eventos</Value>
    </Property>
    <Property>
      <Name>MasterPage</Name>
      <Value>MasterPageExemplo</Value>
    </Property>
    <Property>
      <Name>IsMain</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>WPExemploEventos</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>Exemplos-web</Categories>
</Object>
```
### Sanitizacao aplicada
- nome do objeto, captions e nomes semanticamente explicitos foram trocados por equivalentes genericos
- referencia ao painel interno foi anonimizada sem alterar a estrutura do bloco de eventos
- parent*, moduleGuid, Part type e a sequencia dos blocos foram preservados








