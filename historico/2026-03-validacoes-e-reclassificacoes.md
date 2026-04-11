# 2026-03 - Validacoes e Reclassificacoes

## Papel do documento
historico detalhado

## Objetivo
Preservar a trilha das rodadas de teste, reclassificacoes e descobertas incrementais feitas em 2026-03, sem misturar esse historico ao conjunto operacional da raiz.

## Marcos principais

- A bateria inicial de `.xpz` gerados com base nos `.md` locais e no skill `nexa` comprovou importacao bem-sucedida para uma faixa ampla de tipos autocontidos e estruturais.
- `Attribute` saiu da zona de `shape` incerto quando o export full revelou o formato top-level real `<Attribute ... name=\"...\">`; depois, o risco remanescente ficou concentrado em propriedades semanticas como `ControlItemDescription`.
- `Transaction` foi destravada quando o pacote passou a incluir atributos reais do `Level`, `Context` e `TransactionContext`.
- `Theme` foi destravado quando o pacote passou a incluir tambem as `ThemeClass` exigidas pelo proprio grafo visual, como `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- `Pattern Settings 'WorkWith'` importou com sucesso em caso real compativel.
- `Work With for Web` foi destravado quando o pattern passou a usar o convenio estrutural real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Folder` foi reclassificado como tipo XML estrutural valido, enquanto `Category` ficou entendido como rotulo de UI/importador.
- `Table` foi confirmado como familia top-level propria, enquanto `Index` apareceu apenas embutido dentro de `Table` nesta trilha da IDE.
- `API` permaneceu como a pendencia funcional mais pesada, porque o recorte real mostrou dependencia de uma subarvore grande de `Procedure`, `SDT`, `Domain`, `Transaction`, `Table` e `DataProvider`.

## Pacotes especialmente informativos

- `XPZExemploTabelaTRNWWPatternA`
- `XPZExemploTabelaTRNDataSelectorA`
- `XPZExemploCadeiaAPIA`
- `XPZExemploTemaA`
- `XPZExemploTabelaA`
- `XPZExemploIndiceVazioA`
- `XPZExemploTabelaIndiceA`

## Resultado documental

- A raiz da base deve refletir apenas estado atual consolidado e regras operacionais.
- O historico detalhado de como cada pendencia foi sendo destravada deve permanecer aqui, fora do conjunto principal de `.md` de trabalho.
