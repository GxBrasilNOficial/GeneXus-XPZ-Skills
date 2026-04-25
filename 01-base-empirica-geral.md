# 01 - Base Empirica Geral

## Papel do documento
indice empirico

## Nivel de confianca predominante
medio

## Depende de
09-inventario-e-rastreabilidade-publica.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 08-guia-para-agente-gpt.md

## Objetivo
Servir como porta de entrada curta para a serie `01`, agora desdobrada em arquivos menores por funcao de consulta, para reduzir custo de leitura e melhorar o roteamento das skills `xpz`.

## Motivo da divisao

- `Evidência direta`: o antigo `01-base-empirica-geral.md` concentrou em um unico arquivo o catalogo estrutural, a matriz de `Part type`, a variabilidade de campos, os diffs estruturais e os moldes sanitizados completos.
- `Inferência forte`: esse formato monolitico aumentava custo de contexto para consultas simples e empurrava o agente a abrir um arquivo muito maior do que o necessario.
- `Regra editorial`: a serie `01` passa a ser consultada por camada, e nao mais como monobloco obrigatorio.

## Mapa da serie `01`

| Arquivo | Papel principal | Carregar quando |
|---|---|---|
| `01-base-empirica-geral.md` | indice mestre da serie | primeiro passo para consulta empirica geral |
| `01a-catalogo-e-padroes-empiricos.md` | panorama do acervo, catalogo de tipos, padroes e limites | identificar tipo, ler panorama estrutural, validar escopo empirico |
| `01b-matriz-part-types-por-tipo.md` | frequencia de `Part type` por tipo | confirmar inventario recorrente, suspeitar obrigatoriedade estrutural |
| `01c-campos-estaveis-vs-variaveis.md` | campos mais estaveis e mais variaveis por tipo | decidir o que tende a ser preservado ou editavel |
| `01d-diffs-estruturais-por-tipo.md` | contrastes estruturais por tipo | comparar perfis, avaliar densidade e risco de clonagem |
| `01e-moldes-sanitizados-core.md` | moldes centrais de `Procedure`, `DataProvider`, `Panel`, `API`, `WorkWithForWeb`, pacote misto e `SDT` | materializacao controlada de tipos core e contratos frequentes |
| `01f-moldes-sanitizados-dados-e-design.md` | moldes de `Domain`, `Theme`, `PackagedModule`, `DesignSystem` e `ColorPalette` | casos de dados declarativos e design system |
| `01g-moldes-sanitizados-componentes-e-fisico.md` | moldes de `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `ThemeClass`, `Image` e `Table` | componentes, camada fisica e estrutura visual/material |
| `01h-moldes-sanitizados-metadados-e-artefatos.md` | moldes de `ThemeColor`, `Document`, `DataSelector`, `Generator`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Language`, `Folder`, exemplos de identidade/`Source`, `Stencil` e `File` | metadados, artefatos auxiliares e exemplos de identidade estrutural |

## Ordem recomendada de consulta

1. ler este indice
2. abrir `01a-catalogo-e-padroes-empiricos.md` quando a duvida ainda for "o que existe e como esse tipo se parece"
3. abrir `01b-matriz-part-types-por-tipo.md` quando a duvida envolver `Part type`
4. abrir `01c-campos-estaveis-vs-variaveis.md` quando a duvida envolver preservacao, ruido ou editabilidade
5. abrir `01d-diffs-estruturais-por-tipo.md` quando a duvida envolver comparacao ou densidade estrutural
6. abrir apenas o bloco de moldes sanitizados mais aderente ao tipo real do caso

## Roteamento rapido por pergunta

- "qual e o `Object/@type` ou o catalogo observado?" -> `01a-catalogo-e-padroes-empiricos.md`
- "quais `Part type` sao recorrentes nesse tipo?" -> `01b-matriz-part-types-por-tipo.md`
- "o que tende a ficar estavel e o que varia?" -> `01c-campos-estaveis-vs-variaveis.md`
- "qual perfil estrutural e mais proximo?" -> `01d-diffs-estruturais-por-tipo.md`
- "preciso de molde sanitizado para materializacao controlada" -> `01e` ate `01h`, conforme a familia do tipo

## Regras de uso

- `Regra operacional`: nao abrir `01e` ate `01h` por padrao quando a pergunta puder ser resolvida por `01a` ate `01d`.
- `Regra operacional`: quando a resposta citar base empirica, preferir mencionar o arquivo mais especifico da serie `01`, e nao apenas este indice.
- `Regra operacional`: quando um tipo novo ganhar molde sanitizado ou recorte metodologico relevante, encaixa-lo no arquivo da familia mais aderente em vez de reexpandir este indice.
- `Regra editorial`: este arquivo nao substitui o conteudo detalhado dos filhos; ele so organiza a entrada e o roteamento.

## Rastreabilidade da divisao

- `Evidência direta`: o conteudo desta serie veio do antigo monobloco `01-base-empirica-geral.md`, que incorporava tambem `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` e `12-diffs-estruturais-por-tipo.md`.
- `Evidência direta`: a divisao atual preserva o conteudo empirico, mas redistribui a leitura por funcao operacional.
- `Regra editorial`: referencias antigas a `01-base-empirica-geral.md` continuam validas como ponto de entrada, mas o consumo eficiente deve descer para o arquivo filho adequado.
