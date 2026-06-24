# 05b - Procedure Relatório Familias e Templates

## Papel do documento
empirico e operacional

## Nível de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md

## Usado por
08-guia-para-agente-gpt.md, 09-inventario-e-rastreabilidade-publica.md

## Objetivo
Concentrar familias estruturais de `Procedure` de relatório observadas no acervo, regras por familia e validacoes de consistencia interna para clonagem controlada.

---

## Sanitizacao deste documento

- Evidencia direta: os nomes reais dos objetos usados como representantes não aparecem aqui.
- Evidencia direta: cada template representativo recebeu um alias publico, como `PRCRelatorioExemploF1`, `PRCRelatorioExemploF2` e assim por diante.
- Inferencia forte: para uso interno, o template correspondente pode ser reencontrado pelo critério estrutural indicado em cada familia.
- Hipotese: essa estrategia preserva utilidade operacional sem expor nomes de negocio da KB.

---

## Método

- Evidencia direta: foram analisados 77 XMLs de `Procedure` com nome comecanado com o prefixo de relatório observado no acervo da KB.
- Evidencia direta: todos os 77 objetos usam o mesmo `Object/@type` (`84a12160-f59b-4ad7-a683-ea4481ac23e9`) e o mesmo inventario de 7 `Part` recorrentes.
- Evidencia direta: o `Part` de codigo-fonte usa `type="528d1c06-a9c2-420d-bd35-21dca83f12ff"`.
- Evidencia direta: o `Part` de layout usa `type="c414ed00-8cc4-4f44-8820-4baf93547173"`, sempre com estrutura de `<Bands><PrintBlock>`.
- Evidencia direta: nenhum dos 77 objetos apresentou subroutine interna (`Sub`) no `Source` observado.
- Evidencia direta: o agrupamento abaixo usa contagem de `PrintBlock` no `Part` de layout, presenca de `Header`/`Footer` no `Part` de fonte e contagem de `For each` no `Source`.
- Evidencia direta: os tamanhos de arquivo variam de 7.161 bytes ate 1.115.994 bytes no acervo observado.
- Inferencia forte: para `Procedure` de relatório, a familia estrutural e mais discriminante do que o nome do objeto.
- Regra editorial: este documento trata do `Procedure` de relatório **moderno** (`Object/@type` `84a12160-...`). O objeto `Report` do **GeneXus 9 legado** (elemento por nome, sem GUID de tipo) foi **absorvido** pela Procedure e é rastreado à parte como `orphan` no registro `scripts/gx-legacy-export-element-registry.json` (`modernSuccessor: Procedure`, doc-dono `01k-registro-elementos-legados.md`) — não confundir com as familias de Procedure-relatório descritas aqui.

---

## Visao geral

- Evidencia direta: 3 dos 77 objetos não apresentam `Header` nem `Footer` no `Source` e nenhum `For each` — familia embrionaria.
- Evidencia direta: 6 dos 77 objetos não apresentam `For each` mas possuem `Header` e/ou `Footer` — familia de molde base.
- Evidencia direta: aproximadamente 29 dos 77 objetos possuem 1 ou 2 `For each` — familia de listagem linear simples.
- Evidencia direta: aproximadamente 22 dos 77 objetos possuem 3 a 6 `For each` com ate 24 `PrintBlock` — familia de agrupamento e totalizacao.
- Evidencia direta: aproximadamente 17 dos 77 objetos possuem 7 ou mais `For each` ou 25 ou mais `PrintBlock` — familia de alto volume e complexidade.
- Inferencia forte: a separacao mais útil para geração prática não é por semantica de negocio, mas por presenca de iteracao, complexidade de agrupamento e tamanho do layout.
- Inferencia forte: o principal erro a evitar em `Procedure` de relatório e misturar familias diferentes durante a clonagem — em especial substituir um F4/F5 por um F1/F2 sem ajustar o `Source` e o inventario de `PrintBlock`.

---

## Familia 1 — Embriao sem layout ativo

- Evidencia direta: 3 objetos sem `For each`, sem `Header` e sem `Footer` no `Source`.
- Evidencia direta: tamanho medio aproximado de 26.759 bytes; mínimo 7.161; máximo 65.924.
- Evidencia direta: contagem de `PrintBlock` varia de 1 a 5 nos representantes observados.
- Inferencia forte: esses objetos são cascas pre-inicializadas ou stubs sem corpo de impressao ativo ainda definido.
- Template base publico: `PRCRelatorioExemploF1`.
- Critério privado de selecao: menor XML observado dentro da faixa sem `For each` + sem `Header` + sem `Footer`.
- Justificativa da escolha: representa a casca mais enxuta de `Procedure` de relatório sem iteracao nem cabecalho de pagina.

### Assinatura estrutural

- 0 `For each` no `Source`
- sem `Header` e sem `Footer` no `Source`
- 1 a 5 `PrintBlock` no layout
- `Part` de fonte e de layout presentes (7 `Part` total, uniforme)
- XML compacto, abaixo de 70.000 bytes

---

## Familia 2 — Molde base com cabecalho de pagina

- Evidencia direta: 6 objetos sem `For each` mas com pelo menos um dos blocos `Header` ou `Footer` no `Source`.
- Evidencia direta: tamanho medio aproximado de 50.000 bytes; mínimo 15.148; máximo 90.389.
- Evidencia direta: contagem de `PrintBlock` varia de 4 a 8.
- Evidencia direta: dois representantes observados indicam explicitamente orientacao no nome ou no conteúdo do layout (retrato e paisagem); os demais são neutros.
- Inferencia forte: essa familia e o ponto de partida para novos relatórios que precisam de cabecalho e rodape de pagina mas ainda não iteraram sobre dados.
- Template base publico: `PRCRelatorioExemploF2`.
- Critério privado de selecao: menor XML observado dentro da faixa sem `For each` + com pelo menos um dos blocos `Header`/`Footer`.
- Justificativa da escolha: representa o molde mais simples com estrutura de pagina funcional, sem iteracao ainda.

### Assinatura estrutural

- 0 `For each` no `Source`
- `Header` e/ou `Footer` presentes no `Source`
- 4 a 8 `PrintBlock` no layout
- `Part` de fonte e de layout presentes (7 `Part` total)
- Tamanho entre 15.000 e 90.000 bytes
- Não confundir com F1: a presenca de `Header`/`Footer` distingue as duas familias

---

## Familia 3 — Listagem linear simples

- Evidencia direta: aproximadamente 29 objetos com 1 ou 2 `For each` no `Source`.
- Evidencia direta: tamanho medio aproximado de 200.000 bytes; mínimo 30.819; máximo 580.000.
- Evidencia direta: contagem de `PrintBlock` varia tipicamente de 2 a 16.
- Evidencia direta: a maioria possui `Header` e `Footer` de pagina; uma minoria nessa faixa carece de um ou dos dois blocos.
- Inferencia forte: o `For each` principal itera sobre a tabela de dados sem grupos secundarios ou subtotais estruturais relevantes.
- Template base publico: `PRCRelatorioExemploF3`.
- Critério privado de selecao: menor XML observado dentro da faixa 1 a 2 `For each`.
- Justificativa da escolha: representa a listagem mais enxuta com iteracao simples, servindo de base para relatórios de lista sem agrupamento.

### Assinatura estrutural

- 1 ou 2 `For each` no `Source`
- Tipicamente `Header` e `Footer` presentes no `Source`
- 2 a 16 `PrintBlock` no layout
- `Part` de fonte e de layout presentes (7 `Part` total)
- Sem blocos de subtotal estrutural aparente (inferencia a confirmar por inspeção do representante)
- Tamanho variável; representante está abaixo de 35.000 bytes

---

## Familia 4 — Relatório com agrupamento e totalizacao

- Evidencia direta: aproximadamente 22 objetos com 3 a 6 `For each` e ate 24 `PrintBlock`.
- Evidencia direta: tamanho medio aproximado de 310.000 bytes; mínimo 84.489; máximo 872.615.
- Inferencia forte: a presenca de múltiplos `For each` indica agrupamento com níveis distintos ou iteracoes paralelas de dados relacionados.
- Evidencia direta: `Header` e `Footer` estao presentes na quase totalidade dos objetos desta familia.
- Evidencia direta: alguns representantes indicam orientacao paisagem no nome ou conteúdo; a maioria e neutra ou retrato.
- Template base publico: `PRCRelatorioExemploF4`.
- Critério privado de selecao: menor XML observado dentro da faixa 3 a 6 `For each` com ate 24 `PrintBlock`.
- Justificativa da escolha: representa o caso mais enxuto de agrupamento com múltiplas iteracoes, preservando H+F e orientacao paisagem explicita.

### Assinatura estrutural

- 3 a 6 `For each` no `Source`
- `Header` e `Footer` presentes no `Source`
- 5 a 24 `PrintBlock` no layout
- `Part` de fonte e de layout presentes (7 `Part` total)
- Tamanho tipicamente acima de 84.000 bytes

---

## Familia 5 — Relatório complexo de alto volume

- Evidencia direta: aproximadamente 17 objetos com 7 ou mais `For each` ou 25 ou mais `PrintBlock`.
- Evidencia direta: tamanho medio estimado acima de 400.000 bytes; máximo observado 1.115.994 bytes.
- Evidencia direta: `PrintBlock` varia de 5 ate 51; alguns representantes de alto `For each` possuem layout surpreendentemente compacto (5 a 13 `PrintBlock`), indicando reutilizacao intensa de blocos de impressao.
- Inferencia forte: a densidade de `For each` nessa faixa sugere níveis múltiplos de agrupamento, iteracoes cruzadas ou acumuladores não triviais que exigem análise do `Source` antes de qualquer clonagem.
- Template base publico: `PRCRelatorioExemploF5`.
- Critério privado de selecao: menor XML observado com pelo menos 10 `For each` e pelo menos 20 `PrintBlock`, priorizando o representante mais compacto ainda coberto pelos dois critérios simultaneamente.
- Justificativa da escolha: representa a faixa de alta complexidade sem ser o maior do acervo, permitindo análise do `Source` sem custo proibitivo de leitura.

### Assinatura estrutural

- 7 ou mais `For each` no `Source`, OU 25 ou mais `PrintBlock` no layout
- `Header` e `Footer` presentes na quase totalidade
- `PrintBlock` de 5 a 51 (alta variabilidade interna)
- `Part` de fonte e de layout presentes (7 `Part` total)
- Tamanho acima de 100.000 bytes; tipicamente acima de 250.000 bytes

---

## Como escolher a familia

| Critério primario | Familia recomendada |
|---|---|
| Nenhum `For each`, sem `Header`/`Footer` | F1 |
| Nenhum `For each`, com `Header`/`Footer` | F2 |
| 1 ou 2 `For each` | F3 |
| 3 a 6 `For each`, ate 24 `PrintBlock` | F4 |
| 7+ `For each` ou 25+ `PrintBlock` | F5 |

- Se o objeto alvo não existir ainda no acervo, preferir clonar o representante da familia mais próxima ao critério estrutural.
- Se o objeto alvo já existir no acervo, usar primeiro o molde sanitizado canonico da familia mais próxima quando o caso couber no perfil simples documentado desta base.
- Escalar para XML real comparavel apenas quando o pedido fugir da familia simples coberta pelos moldes, quando houver falha estrutural repetida de importação, ou quando surgir sinal claro de dialeto/localismo da KB.
- Nunca assumir que um objeto de nome simples pertence a F1 ou F2 sem verificar `For each` e `Header`/`Footer` no `Source`.

---

## Moldes canonicos para relatório simples

- Regra operacional: para `Procedure` de relatório simples, o caminho primario desta trilha passa a ser molde sanitizado canonico forte, não leitura obrigatória imediata do acervo real.
- Regra operacional: esse caminho barato e rápido vale apenas para familias simples já cobertas por XML completo e sanitizado suficiente para materialização controlada.
- Regra operacional: todo handoff deve rotular explicitamente a base usada em uma destas quatro categorias: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB` ou `hipotese`.
- Evidencia direta: a familia `F2` já representa o menor perfil com pagina funcional sem iteracao.
- Evidencia direta: a familia `F3` já representa a menor listagem linear com iteracao simples.
- Inferencia forte: esses dois perfis cobrem o caso comum pedido pelo outro agente para relatório simples.

### Separacao obrigatória entre explicacao e molde pronto

- Bloco descritivo: tabelas de familia, sintese textual, frequencias e alertas de risco ajudam a classificar o caso, mas não bastam para materialização.
- Molde pronto para uso controlado: XML sanitizado completo por `Part`, com shape comprovado e suficiente para clonagem conservadora dentro da trilha.
- Regra operacional: nesta seção, tudo que estiver marcado como `molde pronto` passa a ser fonte valida para materialização controlada de `Procedure` de relatório simples.
- Regra operacional: nada fora dos blocos `molde pronto` deve ser promovido a XML final por analogia livre.

### Shape mínimo por camada

- `Source`: declarar fluxo de impressao, blocos `Header`/`Footer` quando existirem, comandos `print printBlock...`, `for each` quando a familia exigir, e chamada `Output_file` quando o caso pedir saida em arquivo.
- `Rules`: declarar `parm(...)` e apenas regras sintaticamente próprias dessa camada.
- layout `Part c414ed00-8cc4-4f44-8820-4baf93547173`: materializar `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute` e metadado estrutural do relatório.
- Regra operacional: o layout não deve ser inventado como `GXML` livre, lista arbitraria de controles ou shape textual plausivel; ele precisa seguir shape comprovado de `Bands` e `PrintBlock`.
- Regra operacional: `RPT_INTERNAL_NAME`, nomes de `PrintBlock` e referencias usadas em `print printBlock...` devem permanecer coerentes entre as tres camadas.

### Gramatica explicita por `Part`

- `Source`: aceita comandos procedurais de relatório e impressao; não deve receber declaracao de `parm(...)` nem shape de layout serializado.
- `Rules`: aceita `parm(...)` e regras da camada; não deve receber `Output_file`, `print`, `Header`, `Footer`, `For each` nem desenho de banda.
- layout: aceita `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute` e metadado visual; não deve receber pseudo-source procedural.
- Regra operacional: `;` em `Rules` continua marcador sensivel de fechamento quando a gramatica da regra exigir; erro dessa camada deve ser lido como problema de `Rules`, não de `Source`.
- Regra operacional: `;` rejeitado em `Source` de relatório deve ser tratado como problema de dialeto/sintaxe do `Source`, não como defeito do layout.
- Regra operacional: fica proibido misturar `GXML` inventado, controles não comprovados e shapes não observados no corpus como tentativa de "completar" relatório.

### Casca canonica de `Part` para `Procedure` de relatório

- Evidencia direta: os representantes reais comparaveis observados nesta trilha repetem a mesma ordem mínima de `Part`: `528d1c06...` (`Source`), `c414ed00...` (layout), `9b0a32a3...` (`Rules`), `763f0d8b...` (fonte auxiliar vazia), `e4c4ade7...` (variáveis), `ad3ca970...` (help) e `babf62c5...` (propriedades finais).
- Regra operacional: os moldes abaixo foram desenhados para clonagem conservadora sobre essa casca, não para geração arbitraria de um objeto do zero sem identidade, módulo e parent coerentes.

```xml
<Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">...</Part>
<Part type="c414ed00-8cc4-4f44-8820-4baf93547173">...</Part>
<Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">...</Part>
<Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9"><Source><![CDATA[]]></Source></Part>
<Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">...</Part>
<Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c"><Help>...</Help></Part>
<Part type="babf62c5-0111-49e9-a1c3-cc004d90900a"><Properties /></Part>
```

### Variantes minimas que a base passa a sustentar

- `F2-retrato`: sem `For each`, com `Header` e/ou `Footer`, orientacao retrato, `Output_file` opcional.
- `F2-paisagem`: sem `For each`, com `Header` e/ou `Footer`, orientacao paisagem, mesmo shape estrutural mínimo.
- `F3-atributos-diretos`: `For each` simples, `ReportAttribute` apontando para atributos diretos do cursor principal.
- `F3-variaveis`: `For each` simples ou pre-processamento curto, `ReportAttribute` apontando para variáveis previamente carregadas.

### Molde pronto 1 - `F2-retrato`

- Base empirica comparavel: `procRelatorioModeloBasicoInicial.xml` + `procRelatorioModeloRetrato.xml`.
- Uso esperado: pagina simples sem iteracao, com cabecalho/rodape e bloco de mensagem ou resumo.

```xml
<Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
  <Source><![CDATA[Header
    print printBlockCabecalho
End

Footer
    print printBlockRodape
End

&arquivodesaidanome = 'RelatorioSimples_' + &EmpresaId.ToString();
Output_file(&arquivodesaidanome, 'PDF');

print printBlockMensagem
]]></Source>
  <Properties>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Part>
<Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
  <Layout>
    <Bands>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelTitulo</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>Titulo do relatorio</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockCabecalho</Value></Property>
          <Property><Name>RPT_ID</Name><Value>1</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>90</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>Mensagem</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>&amp;Mensagem</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>760</Value></Property>
            </Properties>
          </ReportAttribute>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockMensagem</Value></Property>
          <Property><Name>RPT_ID</Name><Value>2</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>25</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelPagina</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>{{Pages}}</Value></Property>
              <Property><Name>RPT_X</Name><Value>740</Value></Property>
              <Property><Name>RPT_Y</Name><Value>5</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockRodape</Value></Property>
          <Property><Name>RPT_ID</Name><Value>3</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>20</Value></Property>
        </Properties>
      </PrintBlock>
    </Bands>
    <Properties>
      <Property><Name>RPT_PAPER_SIZE</Name><Value>A4</Value></Property>
      <Property><Name>RPT_RIGHT_MARGIN</Name><Value>20</Value></Property>
    </Properties>
  </Layout>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
  <Source><![CDATA[parm(in:&EmpresaId, in:&DataInicial);]]></Source>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
  <Variable Name="arquivodesaidanome">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>arquivodesaidanome</Value></Property>
      <Property><Name>ATTCUSTOMTYPE</Name><Value>bas:VarChar</Value></Property>
      <Property><Name>Length</Name><Value>255</Value></Property>
      <Property><Name>AttMaxLen</Name><Value>255</Value></Property>
    </Properties>
  </Variable>
  <Variable Name="EmpresaId">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>EmpresaId</Value></Property>
      <Property><Name>idBasedOn</Name><Value>Attribute:EmpresaId</Value></Property>
    </Properties>
  </Variable>
  <Variable Name="DataInicial">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>DataInicial</Value></Property>
      <Property><Name>ATTCUSTOMTYPE</Name><Value>bas:Date</Value></Property>
    </Properties>
  </Variable>
  <Variable Name="Mensagem">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>Mensagem</Value></Property>
      <Property><Name>ATTCUSTOMTYPE</Name><Value>bas:VarChar</Value></Property>
      <Property><Name>Length</Name><Value>255</Value></Property>
      <Property><Name>AttMaxLen</Name><Value>255</Value></Property>
    </Properties>
  </Variable>
</Part>
```

### Molde pronto 2 - `F2-paisagem`

- Base empirica comparavel: `procRelatorioModeloPaisagem.xml`.
- Uso esperado: mesma familia simples de `F2`, mas com papel e largura de layout orientados para paisagem.
- Regra operacional: a diferenca principal em relacao ao retrato está nas propriedades do layout e nas larguras/coordenadas dos controles.

```xml
<Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
  <Layout>
    <Bands>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelTitulo</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>Titulo do relatorio</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockCabecalho</Value></Property>
          <Property><Name>RPT_ID</Name><Value>1</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>90</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>Mensagem</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>&amp;Mensagem</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>1160</Value></Property>
            </Properties>
          </ReportAttribute>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockMensagem</Value></Property>
          <Property><Name>RPT_ID</Name><Value>2</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>25</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelPagina</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>{{Pages}}</Value></Property>
              <Property><Name>RPT_X</Name><Value>1140</Value></Property>
              <Property><Name>RPT_Y</Name><Value>5</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockRodape</Value></Property>
          <Property><Name>RPT_ID</Name><Value>3</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>20</Value></Property>
        </Properties>
      </PrintBlock>
    </Bands>
    <Properties>
      <Property><Name>RPT_PAPER_SIZE</Name><Value>Custom</Value></Property>
      <Property><Name>RPT_PAPER_ORIENTATION</Name><Value>Landscape</Value></Property>
      <Property><Name>RPT_PAPER_WIDTH</Name><Value>1229</Value></Property>
      <Property><Name>RPT_PAPER_HEIGHT</Name><Value>827</Value></Property>
      <Property><Name>RPT_RIGHT_MARGIN</Name><Value>0</Value></Property>
    </Properties>
  </Layout>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
```

### Molde pronto 3 - `F3-atributos-diretos`

- Base empirica comparavel: `procRelatorioVolumesRomaneioPorCorte.xml`.
- Uso esperado: listagem linear curta, `For each` simples e `ReportAttribute` ligados ao cursor principal.

```xml
<Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
  <Source><![CDATA[Header
    print printBlockCabecalho
End

&arquivodesaidanome = 'RelatorioDireto_' + &EmpresaId.ToString();
Output_file(&arquivodesaidanome, 'PDF');

For each
    where EmpresaId = &EmpresaId
    order ClienteNome
    print printBlockDetalhe
Endfor

Footer
    print printBlockRodape
End
]]></Source>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
  <Layout>
    <Bands>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelCabecalho</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>Clientes por empresa</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockCabecalho</Value></Property>
          <Property><Name>RPT_ID</Name><Value>1</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>35</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>ClienteNome</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>ClienteNome</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>420</Value></Property>
            </Properties>
          </ReportAttribute>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>ClienteSaldo</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>ClienteSaldo</Value></Property>
              <Property><Name>RPT_X</Name><Value>460</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>120</Value></Property>
            </Properties>
          </ReportAttribute>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockDetalhe</Value></Property>
          <Property><Name>RPT_ID</Name><Value>2</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>18</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelRodape</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>{{Pages}}</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockRodape</Value></Property>
          <Property><Name>RPT_ID</Name><Value>3</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>18</Value></Property>
        </Properties>
      </PrintBlock>
    </Bands>
    <Properties>
      <Property><Name>RPT_PAPER_SIZE</Name><Value>A4</Value></Property>
      <Property><Name>RPT_RIGHT_MARGIN</Name><Value>20</Value></Property>
    </Properties>
  </Layout>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
  <Source><![CDATA[parm(in:&EmpresaId);]]></Source>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
```

### Molde pronto 4 - `F3-variaveis`

- Base empirica comparavel: `procRelatorioVolumesRomaneioPorCorte.xml` no padrão de pre-processamento curto antes do `print`.
- Uso esperado: a linha impressa depende de variáveis carregadas dentro do fluxo, e não diretamente do `AttID` do cursor.

```xml
<Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
  <Source><![CDATA[Header
    print printBlockCabecalho
End

&arquivodesaidanome = 'RelatorioVariaveis_' + &EmpresaId.ToString();
Output_file(&arquivodesaidanome, 'PDF');

For each
    where EmpresaId = &EmpresaId
    &NomeCliente = ClienteNome
    &TotalLiquido = PedidoValorLiquido
    print printBlockDetalhe
Endfor

Footer
    print printBlockRodape
End
]]></Source>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
  <Layout>
    <Bands>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelCabecalho</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>Resumo por variaveis</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockCabecalho</Value></Property>
          <Property><Name>RPT_ID</Name><Value>1</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>35</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>NomeCliente</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>&amp;NomeCliente</Value></Property>
              <Property><Name>RPT_X</Name><Value>20</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>420</Value></Property>
            </Properties>
          </ReportAttribute>
          <ReportAttribute>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>TotalLiquido</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>AttID</Name><Value>&amp;TotalLiquido</Value></Property>
              <Property><Name>RPT_X</Name><Value>460</Value></Property>
              <Property><Name>RPT_Y</Name><Value>0</Value></Property>
              <Property><Name>RPT_WIDTH</Name><Value>120</Value></Property>
            </Properties>
          </ReportAttribute>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockDetalhe</Value></Property>
          <Property><Name>RPT_ID</Name><Value>2</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>18</Value></Property>
        </Properties>
      </PrintBlock>
      <PrintBlock>
        <Controls>
          <ReportLabel>
            <Properties>
              <Property><Name>RPT_INTERNAL_NAME</Name><Value>gxReportLabelRodape</Value></Property>
              <Property><Name>RPT_VISIBLE</Name><Value>True</Value></Property>
              <Property><Name>RPT_TEXT</Name><Value>{{Pages}}</Value></Property>
            </Properties>
          </ReportLabel>
        </Controls>
        <Properties>
          <Property><Name>RPT_INTERNAL_NAME</Name><Value>printBlockRodape</Value></Property>
          <Property><Name>RPT_ID</Name><Value>3</Value></Property>
          <Property><Name>RPT_HEIGHT</Name><Value>18</Value></Property>
        </Properties>
      </PrintBlock>
    </Bands>
    <Properties>
      <Property><Name>RPT_PAPER_SIZE</Name><Value>A4</Value></Property>
      <Property><Name>RPT_RIGHT_MARGIN</Name><Value>20</Value></Property>
    </Properties>
  </Layout>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
  <Source><![CDATA[parm(in:&EmpresaId);]]></Source>
  <Properties>
    <Property><Name>IsDefault</Name><Value>False</Value></Property>
  </Properties>
</Part>
<Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
  <Variable Name="NomeCliente">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>NomeCliente</Value></Property>
      <Property><Name>ATTCUSTOMTYPE</Name><Value>bas:VarChar</Value></Property>
      <Property><Name>Length</Name><Value>120</Value></Property>
    </Properties>
  </Variable>
  <Variable Name="TotalLiquido">
    <Documentation />
    <Properties>
      <Property><Name>Name</Name><Value>TotalLiquido</Value></Property>
      <Property><Name>ATTCUSTOMTYPE</Name><Value>bas:Numeric</Value></Property>
      <Property><Name>Decimals</Name><Value>2</Value></Property>
    </Properties>
  </Variable>
</Part>
```

### Regra operacional de uso dos moldes acima

- Regra operacional: `F2-retrato` e `F2-paisagem` já contam como molde sanitizado canonico forte para pagina simples sem iteracao.
- Regra operacional: `F3-atributos-diretos` e `F3-variaveis` já contam como molde sanitizado canonico forte para listagem linear simples com um único `For each` de impressao.
- Regra operacional: se o caso exigir agrupamento real, subtotal estrutural, múltiplos `For each` de impressao, shape de controle não coberto ou dialeto próprio da KB, esses moldes deixam de ser fonte suficiente.
- Regra operacional: toda frente que criar, fortalecer ou recombinar estes `moldes prontos` deve avaliar se a rastreabilidade privada correspondente precisa ser atualizada no `GeneXus-XPZ-PrivateMap`.

### Fallback estruturado

- Passo 1: tentar o molde sanitizado canonico mais próximo da familia simples.
- Passo 2: se o pedido sair do perfil simples coberto, marcar a diferenca estrutural e escalar para XML real comparavel.
- Passo 3: se a importação falhar com erro estrutural de shape, layout ou sintaxe de camada, revisar apenas a camada suspeita uma vez e tentar pacote corretivo mínimo.
- Passo 4: se ainda falhar depois desse único corretivo curto, parar de inventar e buscar XML real comparavel, registrando a escalada explicitamente.
- Passo 5: se aparecer sinal de dialeto/localismo da KB, abandonar o molde canonico como fonte suficiente e escalar para XML real comparavel da KB alvo.

### Sinais tipicos de dialeto/localismo

- assinatura de `parm(...)` ou regra de relatório fora do padrão simples documentado
- convencao interna de nomes, bandas ou `PrintBlock` não coberta pelos moldes canonicos
- uso de recurso de layout, propriedade ou shape ausente nos representantes sanitizados desta base
- erro de importação que sugira incompatibilidade local e não apenas shape mínimo incompleto

### Playbook curto de depuracao

- `src0212 invalid control`: suspeitar primeiro do layout e do shape do `Part c414...`; revisar `Bands`, `PrintBlock`, tipo de controle e coerência entre bloco impresso e bloco materializado.
- `src0201 output_file invalid type`: revisar se `Output_file` ficou na camada correta e com assinatura coerente com o dialeto aceito no `Source`.
- `src0119 ';' not longer supported`: revisar `Source`; remover sintaxe herdada ou transplante indevido de `Rules`.
- `src0056 Missed ';' at the end of the rule`: revisar `Rules`; tratar como fechamento faltante de regra, não como defeito do `Source`.
- erro que mencione `printBlock`, `ReportLabel`, `ReportAttribute` ou controle invalido: revisar o layout antes de mexer em envelope.
- erro que mencione `parm`, regra ou fechamento de regra: revisar `Rules` antes de mexer no layout.
- erro que mencione `For each`, `Header`, `Footer`, `Output_file` ou função procedural: revisar `Source` antes de mexer no layout.

### Regra editorial de uso

- Regra editorial: nunca usar resumo textual deste documento como única fonte para materialização de XML.
- Regra editorial: os blocos marcados como `molde pronto` nesta seção já são fonte valida para materialização controlada de `Procedure` de relatório simples.
- Regra editorial: aliases publicos, tabelas de familia e descrição textual continuam sendo fonte de classificação, não fonte materializavel por si só.
- Regra editorial: para familias simples cobertas nesta base, o agente pode materializar a partir de molde sanitizado canonico completo sem exigir leitura inicial do XML real da KB.
- Regra editorial: quando o caso sair da cobertura simples documentada, o próximo passo obrigatório e XML real comparavel, não improvisacao adicional.

---

## Erros a evitar em clonagem

- Inferencia forte: clonar um F2 como base para um F4 sem ajustar o `Source` e o inventario de `PrintBlock` resultara em estrutura incompleta que não imprimira corretamente.
- Inferencia forte: copiar um F5 para gerar um F3 carrega blocos e iteracoes desnecessarios que podem causar erros de compilacao por referencias ausentes.
- Hipotese: a maioria dos relatórios de producao desta KB pertence a F3 ou F4, o que torna esses moldes os mais frequentemente necessários em novas frentes.
- Regra operacional: não insistir em nova tentativa estrutural por analogia depois da tentativa inicial mais um único corretivo estrutural curto; a partir dai, escalar para XML real comparavel.
