# 01 - Base Empirica Geral

## Papel do documento
índice empirico

## Nível de confianca predominante
medio

## Depende de
09-inventario-e-rastreabilidade-publica.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 08-guia-para-agente-gpt.md

## Objetivo
Servir como porta de entrada curta para a serie `01`, agora desdobrada em arquivos menores por função de consulta, para reduzir custo de leitura e melhorar o roteamento das skills `xpz`.

## Motivo da divisao

- `Evidência direta`: o antigo `01-base-empirica-geral.md` concentrou em um único arquivo o catalogo estrutural, a matriz de `Part type`, a variabilidade de campos, os diffs estruturais e os moldes sanitizados completos.
- `Inferência forte`: esse formato monolitico aumentava custo de contexto para consultas simples e empurrava o agente a abrir um arquivo muito maior do que o necessário.
- `Regra editorial`: a serie `01` passa a ser consultada por camada, e não mais como monobloco obrigatório.

## Mapa da serie `01`

| Arquivo | Papel principal | Carregar quando |
|---|---|---|
| `01-base-empirica-geral.md` | índice mestre da serie | primeiro passo para consulta empirica geral |
| `01a-catalogo-e-padroes-empiricos.md` | panorama do acervo, catalogo de tipos, padrões e limites | identificar tipo, ler panorama estrutural, validar escopo empirico |
| `01b-matriz-part-types-por-tipo.md` | frequência de `Part type` por tipo | confirmar inventario recorrente, suspeitar obrigatoriedade estrutural |
| `01c-campos-estaveis-vs-variaveis.md` | campos mais estaveis e mais variáveis por tipo | decidir o que tende a ser preservado ou editavel |
| `01d-diffs-estruturais-por-tipo.md` | contrastes estruturais por tipo | comparar perfis, avaliar densidade e risco de clonagem |
| `01e-moldes-sanitizados-core.md` | moldes centrais de `Procedure`, `DataProvider`, `Panel`, `API`, `WorkWithForWeb`, pacote misto e `SDT` | materialização controlada de tipos core e contratos frequentes |
| `01f-moldes-sanitizados-dados-e-design.md` | moldes de `Domain`, `Theme`, `PackagedModule`, `DesignSystem` e `ColorPalette` | casos de dados declarativos e design system |
| `01g-moldes-sanitizados-componentes-e-fisico.md` | moldes de `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `ThemeClass`, `Image` e `Table` | componentes, camada física e estrutura visual/material |
| `01h-moldes-sanitizados-metadados-e-artefatos.md` | moldes de `ThemeColor`, `Document`, `DataSelector`, `Generator`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Language`, `Folder`, exemplos de identidade/`Source`, `Stencil` e `File` | metadados, artefatos auxiliares e exemplos de identidade estrutural |

> `01k` (registro de elementos legados) é doc de **governança**, não molde empírico: compartilha o prefixo `01` mas fica fora deste mapa empírico, indexado na camada Operacional do `00-indice-da-base-genexus-xpz-xml.md`.

## Ordem recomendada de consulta

1. ler este índice
2. abrir `01a-catalogo-e-padroes-empiricos.md` quando a duvida ainda for "o que existe e como esse tipo se parece"
3. abrir `01b-matriz-part-types-por-tipo.md` quando a duvida envolver `Part type`
4. abrir `01c-campos-estaveis-vs-variaveis.md` quando a duvida envolver preservacao, ruido ou editabilidade
5. abrir `01d-diffs-estruturais-por-tipo.md` quando a duvida envolver comparacao ou densidade estrutural
6. abrir apenas o bloco de moldes sanitizados mais aderente ao tipo real do caso

## Roteamento rápido por pergunta

- "qual é o `Object/@type` ou o catalogo observado?" -> `01a-catalogo-e-padroes-empiricos.md`
- "quais `Part type` são recorrentes nesse tipo?" -> `01b-matriz-part-types-por-tipo.md`
- "o que tende a ficar estavel e o que varia?" -> `01c-campos-estaveis-vs-variaveis.md`
- "qual perfil estrutural e mais próximo?" -> `01d-diffs-estruturais-por-tipo.md`
- "preciso de molde sanitizado para materialização controlada" -> `01e` ate `01h`, conforme a familia do tipo

## Regras de uso

- `Regra operacional`: não abrir `01e` ate `01h` por padrão quando a pergunta puder ser resolvida por `01a` ate `01d`.
- `Regra operacional`: quando a resposta citar base empirica, preferir mencionar o arquivo mais específico da serie `01`, e não apenas este índice.
- `Regra operacional`: quando um tipo novo ganhar molde sanitizado ou recorte metodologico relevante, encaixa-lo no arquivo da familia mais aderente em vez de reexpandir este índice.
- `Regra editorial`: este arquivo não substitui o conteúdo detalhado dos filhos; ele só organiza a entrada e o roteamento.

## Rastreabilidade da divisao

- `Evidência direta`: o conteúdo desta serie veio do antigo monobloco `01-base-empirica-geral.md`, que incorporava também `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` e `12-diffs-estruturais-por-tipo.md`.
- `Evidência direta`: a divisao atual preserva o conteúdo empirico, mas redistribui a leitura por função operacional.
- `Regra editorial`: referencias antigas a `01-base-empirica-geral.md` continuam validas como ponto de entrada, mas o consumo eficiente deve descer para o arquivo filho adequado.
