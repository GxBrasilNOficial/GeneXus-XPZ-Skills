# 01 - Base Empirica Geral

## Papel do documento
empirico

## Nivel de confianca predominante
medio

## Depende de
09-historico-e-inventario-publico.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 08-guia-para-agente-gpt.md

## Objetivo
Concentrar a base factual observada nos XMLs: pesquisa geral, matriz de Part types, campos do no Object e diffs estruturais por tipo.

## Fontes consolidadas
- 01-base-empirica-geral.md
- 10-matriz-part-types-por-tipo.md
- 11-campos-estaveis-vs-variaveis.md
- 12-diffs-estruturais-por-tipo.md

## Origem incorporada - 01-base-empirica-geral.md

## Papel do documento
conceitual

## Nível de confiança predominante
alto

## Depende de
30-inventario-bruto-kb.md

## Usado por
02-genexus-xpz-generation-rules.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Consolidar a leitura estrutural do acervo XML extraído da KB.
Servir como base conceitual para os documentos empíricos e operacionais.

## Fonte usada

- `Evidência direta`: a consolidação abaixo usa o inventário em `C:\Dev\Knowledge\GeneXus\30-inventario-bruto-kb.md`.
- `Evidência direta`: foram lidos XMLs do acervo `C:\SANITIZED\ObjetosDaKbEmXml`.

## Panorama do acervo

- `Evidência direta`: o acervo contém `7219` XMLs distribuídos em `32` diretórios de tipos extraídos.
- `Evidência direta`: os maiores conjuntos por diretório são `Procedure` (`2281`), `WebPanel` (`1196`), `SubTypeGroup` (`709`), `SDT` (`594`), `Domain` (`592`), `ThemeClass` (`501`), `Module` (`279`), `Image` (`250`), `Index` (`228`), `Transaction` (`183`) e `WorkWithForWeb` (`183`).
- `Evidência direta`: o inventário bruto registrou `0` arquivos problemáticos na leitura XML.

## Estrutura XML recorrente

- `Evidência direta`: os objetos extraídos seguem o formato geral `<Object ...>` com atributos como `guid`, `name`, `type`, `parent`, `parentGuid`, `moduleGuid` e `fullyQualifiedName`.
- `Evidência direta`: quando há conteúdo interno, ele aparece em blocos `<Part type="...">...</Part>`.
- `Inferência forte`: para este acervo, o GUID em `Object/@type` é um identificador estável do tipo extraído do objeto.
- `Hipótese`: o mesmo catálogo de `Object/@type` e `Part/@type` pode se repetir em outros exports GeneXus 18, mas isso não foi provado aqui.

## Catálogo observado de tipos extraídos

| Diretório extraído | Contagem | GUID observado em `Object/@type` | Classificação |
| --- | ---: | --- | --- |
| `API` | 1 | `36e32e2d-023e-4188-95df-d13573bac2e0` | `Evidência direta` |
| `ColorPalette` | 1 | `3affc0b3-494b-4d84-9ec1-3a6ab8349cda` | `Evidência direta` |
| `Dashboard` | 1 | `526aba9f-a725-4bc7-b1db-0b9f92ac9550` | `Evidência direta` |
| `DataProvider` | 24 | `2a9e9aba-d2de-4801-ae7f-5e3819222daf` | `Evidência direta` |
| `DataSelector` | 2 | `ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af` | `Evidência direta` |
| `DataStore` | 2 | `dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0` | `Evidência direta` |
| `DeploymentUnit` | 1 | `bf08dfb1-361c-4e7e-ad54-391e56e60b49` | `Evidência direta` |
| `DesignSystem` | 2 | `78b3fa0e-174c-4b2b-8716-718167a428b5` | `Evidência direta` |
| `Document` | 3 | `faeb588c-dcce-4dad-9af3-cdd11b961a32` | `Evidência direta` |
| `Domain` | 592 | `00972a17-9975-449e-aab1-d26165d51393` | `Evidência direta` |
| `ExternalObject` | 18 | `c163e562-42c6-4158-ad83-5b21a14cf30e` | `Evidência direta` |
| `File` | 81 | `1132ac08-290f-4fd1-bd18-64777b7329d1` | `Evidência direta` |
| `Folder` | 7 | `00000000-0000-0000-0000-000000000006` | `Evidência direta` |
| `Generator` | 5 | `ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0` | `Evidência direta` |
| `Image` | 250 | `9fb193d9-64a4-4d30-b129-ff7c76830f7e` | `Evidência direta` |
| `Index` | 228 | `857ca50e-7905-0000-0007-c5d9ff2975ec` | `Evidência direta` |
| `Language` | 1 | `88313f43-5eb2-0000-0028-e8d9f5bf9588` | `Evidência direta` |
| `Module` | 279 | `00000000-0000-0000-0000-000000000008` | `Evidência direta` |
| `PackagedModule` | 16 | `c88fffcd-b6f8-0000-8fec-00b5497e2117` | `Evidência direta` |
| `Panel` | 7 | `d82625fd-5892-40b0-99c9-5c8559c197fc` | `Evidência direta` |
| `PatternSettings` | 2 | `83476c1e-fa72-4229-9930-f51b954fca2d` | `Evidência direta` |
| `Procedure` | 2281 | `84a12160-f59b-4ad7-a683-ea4481ac23e9` | `Evidência direta` |
| `SDT` | 594 | `447527b5-9210-4523-898b-5dccb17be60a` | `Evidência direta` |
| `Stencil` | 11 | `624a8b31-36f0-4292-adba-2d270d1e3537` | `Evidência direta` |
| `SubTypeGroup` | 709 | `87313f43-5eb2-41d7-9b8c-e8d9f5bf9588` | `Evidência direta` |
| `Theme` | 7 | `c804fdbd-7c0b-440d-8527-4316c92649a6` | `Evidência direta` |
| `ThemeClass` | 501 | `d4876646-98dd-419b-8c1c-896f83c48368` | `Evidência direta` |
| `ThemeColor` | 24 | `5592de59-d30a-499d-9100-a7006d3674f2` | `Evidência direta` |
| `Transaction` | 183 | `1db606f2-af09-4cf9-a3b5-b481519d28f6` | `Evidência direta` |
| `UserControl` | 7 | `562f4793-aabe-449f-8821-fc77e550698e` | `Evidência direta` |
| `WebPanel` | 1196 | `c9584656-94b6-4ccd-890f-332d11fc2c25` | `Evidência direta` |
| `WorkWithForWeb` | 183 | `78cecefe-be7d-4980-86ce-8d6e91fba04b` | `Evidência direta` |

## Padrões internos observados por grupos

### `Procedure`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Procedure\PRCExemplo0001.xml` aparecem `Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff"`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c` e `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- `Evidência direta`: nesse mesmo XML há um trecho `parm(...)` dentro de um bloco `Part`, o que mostra que parâmetros podem estar armazenados separadamente do código principal.
- `Inferência forte`: objetos em `Procedure` usam um conjunto recorrente de `Part type` para código, parâmetros, variáveis e propriedades, mas esta documentação não nomeia semanticamente cada `Part type` além do que foi visto.

### `WebPanel`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WPExemplo0001.xml` há um `Source` com `GxMultiForm`.
- `Evidência direta`: no mesmo arquivo há outro `Source` com blocos `Event`.
- `Inferência forte`: em `WebPanel`, layout declarativo e código de eventos tendem a aparecer em partes distintas do XML.

### `Transaction`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Transaction\TRNExemplo0001.xml` e `TRNExemplo0002.xml` aparecem nós `<Level ...>` e vários `<AttributeProperties Attribute="...">`.
- `Inferência forte`: objetos em `Transaction` carregam estrutura hierárquica e configuração de atributos dentro de `Part type` próprios.

### `SDT`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SDT\SDTExemplo0001.xml` aparecem `<Level>`, `<LevelInfo>` e `<Item>`.
- `Inferência forte`: no acervo observado, `SDT` representa estrutura hierárquica declarada, distinta do padrão de `Transaction`.

### `SubTypeGroup`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SubTypeGroup\STGExemplo0001.xml` aparecem vários nós `<Subtype guid="...">`.
- `Inferência forte`: `SubTypeGroup` registra vínculos de subtype/supertype por GUID e nome, não regras procedurais.

### `ThemeClass`

- `Evidência direta`: arquivos como `ActionAttribute.xml` e `ActionButtons.xml` contêm propriedades `ThemeElementThemeTypes` e `ThemeElementInternalType`.
- `Inferência forte`: essas propriedades são marcadores estáveis para reconhecer objetos do diretório `ThemeClass` neste acervo.

### `WorkWithForWeb`

- `Evidência direta`: arquivos como `WorkWithWebTRNExemplo0001.xml` exibem `Object/@name` iniciando com `WorkWithWeb`.
- `Evidência direta`: nesses mesmos arquivos aparece `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">`.
- `Inferência forte`: os XMLs em `WorkWithForWeb` guardam configuração de artefatos gerados por padrão web associada ao objeto pai.

## Relações aparentes observadas

- `Evidência direta`: muitos objetos trazem `parent`, `parentGuid` e `parentType` no próprio nó `<Object>`.
- `Evidência direta`: objetos em `WorkWithForWeb` usam `parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6"` quando ligados a `Transaction`, como em `WorkWithWebTRNExemplo0001.xml`.
- `Evidência direta`: `WebPanel\WPExemplo0001.xml` referencia outros objetos no código de eventos, como `WPExemploA`, `WWExemploA`, `WWExemploB` e `WPExemploB`.
- `Inferência forte`: dependências entre objetos podem ser detectadas combinando `parent*`, referências em propriedades e chamadas nominais em blocos de código.
- `Hipótese`: uma etapa futura pode transformar essas relações aparentes em um grafo de dependências mais confiável, desde que haja validação adicional por tipo de objeto.

## Leitura cautelosa dos GUIDs de `Part type`

- `Evidência direta`: o inventário bruto catalogou GUIDs de `Part type` por ocorrência.
- `Inferência forte`: alguns `Part type` aparecem recorrentemente dentro do mesmo grupo de objetos e podem ser usados como assinatura estrutural.
- `Hipótese`: o significado funcional exato de cada `Part type` ainda precisa ser rotulado com validação mais fina, objeto a objeto.

## Limites desta consolidação

- `Evidência direta`: o acervo foi analisado já decomposto em XMLs por objeto, não como o `XPZ` binário/original completo.
- `Inferência forte`: a documentação atual descreve bem a organização dos XMLs extraídos desta KB.
- `Hipótese`: ainda não é seguro generalizar todos os padrões acima para qualquer KB GeneXus 18 sem nova amostragem.





## Origem incorporada - 10-matriz-part-types-por-tipo.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 01-base-empirica-geral.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Catalogar os `Part type` observados por tipo de objeto, com frequência e exemplos.
Separar observação direta de leitura heurística preliminar.

- Evidência direta: frequências calculadas a partir dos XMLs extraídos em C:\SANITIZED\ObjetosDaKbEmXml.
- Inferência forte: a classificação preliminar abaixo usa presença e vazios recorrentes como heurística do acervo, não teste de importação.

## API

- Evidência direta: Object/@type = 36e32e2d-023e-4188-95df-d13573bac2e0 em 1 objetos.
- Evidência direta: média de Part por objeto: 5.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## ColorPalette

- Evidência direta: Object/@type = 3affc0b3-494b-4d84-9ec1-3a6ab8349cda em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 5d481862-64bc-4e88-8af2-e21c276dab77 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Dashboard

- Evidência direta: Object/@type = 526aba9f-a725-4bc7-b1db-0b9f92ac9550 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a51ced48-7bee-0001-ab12-04e9e32123d1 | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DataProvider

- Evidência direta: Object/@type = 2a9e9aba-d2de-4801-ae7f-5e3819222daf em 24 objetos.
- Evidência direta: média de Part por objeto: 5.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 1d8aeb5a-6e98-45a7-92d2-d8de7384e432 | 24 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 24 | 100 | 8.3 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 24 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 24 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 24 | 100 | 4.2 | aparentemente obrigatorio | exemplos sanitizados |

## DataSelector

- Evidência direta: Object/@type = ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af em 2 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a2bc65a1-999f-4e9b-b837-72285cc9bb16 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2 | 100 | 50 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DeploymentUnit

- Evidência direta: Object/@type = bf08dfb1-361c-4e7e-ad54-391e56e60b49 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 122ea32d-7ffa-4c47-9cbf-0829c2f060fe | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 100 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## DesignSystem

- Evidência direta: Object/@type = 78b3fa0e-174c-4b2b-8716-718167a428b5 em 2 objetos.
- Evidência direta: média de Part por objeto: 4.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 36982745-cb77-47a3-bc04-9d0d764ff532 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2 | 100 | 50 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c6b14574-4f5f-4e35-aaa7-e322e88a9a10 | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Document

- Evidência direta: Object/@type = faeb588c-dcce-4dad-9af3-cdd11b961a32 em 3 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 3 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Domain

- Evidência direta: Object/@type = 00972a17-9975-449e-aab1-d26165d51393 em 592 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 592 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 592 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## ExternalObject

- Evidência direta: Object/@type = c163e562-42c6-4158-ad83-5b21a14cf30e em 18 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 00000000-0000-0000-0002-000000000005 | 18 | 100 | 5.6 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 18 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 18 | 100 | 77.8 | aparentemente obrigatorio | exemplos sanitizados |

## File

- Evidência direta: Object/@type = 1132ac08-290f-4fd1-bd18-64777b7329d1 em 81 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 9b6155f9-f286-4ed5-bd15-67672e8ea320 | 81 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 81 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## Folder

- Evidência direta: Object/@type = 00000000-0000-0000-0000-000000000006 em 7 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## Image

- Evidência direta: Object/@type = 9fb193d9-64a4-4d30-b129-ff7c76830f7e em 250 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 36f350de-f768-425f-ac20-773749f331bf | 250 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 250 | 100 | 79.2 | aparentemente obrigatorio | exemplos sanitizados |

## Index

- Evidência direta: Object/@type = 857ca50e-7905-0000-0007-c5d9ff2975ec em 228 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 00000000-0000-0000-0002-000000000004 | 228 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| a5c0e770-560d-0001-0001-7fe71c260de3 | 228 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Language

- Evidência direta: Object/@type = 88313f43-5eb2-0000-0028-e8d9f5bf9588 em 1 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |
| c23f3bb5-1e43-4c6b-b219-4717979df76a | 1 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## PackagedModule

- Evidência direta: Object/@type = c88fffcd-b6f8-0000-8fec-00b5497e2117 em 16 objetos.
- Evidência direta: média de Part por objeto: 2.38.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a5e6a251-2df0-44d8-adab-1da237574326 | 6 | 37.5 | 100 | aparentemente vazio/estrutural | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 16 | 100 | 37.5 | aparentemente obrigatorio | exemplos sanitizados |
| ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc | 16 | 100 | 37.5 | aparentemente obrigatorio | exemplos sanitizados |

## Panel

- Evidência direta: Object/@type = d82625fd-5892-40b0-99c9-5c8559c197fc em 7 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| b4378a97-f9b2-4e05-b2f8-c610de258402 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## PatternSettings

- Evidência direta: Object/@type = 83476c1e-fa72-4229-9930-f51b954fca2d em 2 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.
- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3c89746e-54b1-441a-8f3f-97cc81be06bd | 2 | 100 | 0 | aparentemente obrigatorio (amostra muito pequena) | exemplos sanitizados |

## Procedure

- Evidência direta: Object/@type = 84a12160-f59b-4ad7-a683-ea4481ac23e9 em 2281 objetos.
- Evidência direta: média de Part por objeto: 7.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 528d1c06-a9c2-420d-bd35-21dca83f12ff | 2281 | 100 | 0.4 | aparentemente obrigatorio | exemplos sanitizados |
| 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9 | 2281 | 100 | 52.5 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 2281 | 100 | 0.1 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 2281 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 2281 | 100 | 93 | aparentemente obrigatorio | exemplos sanitizados |
| c414ed00-8cc4-4f44-8820-4baf93547173 | 2281 | 100 | 95.7 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 2281 | 100 | 0.1 | aparentemente obrigatorio | exemplos sanitizados |

## SDT

- Evidência direta: Object/@type = 447527b5-9210-4523-898b-5dccb17be60a em 594 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a | 594 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 594 | 100 | 98.3 | aparentemente obrigatorio | exemplos sanitizados |

## Stencil

- Evidência direta: Object/@type = 624a8b31-36f0-4292-adba-2d270d1e3537 em 11 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3dd92fe7-b095-44d3-9fa0-8488fa3f0c68 | 11 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 11 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |

## SubTypeGroup

- Evidência direta: Object/@type = 87313f43-5eb2-41d7-9b8c-e8d9f5bf9588 em 709 objetos.
- Evidência direta: média de Part por objeto: 1.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 74203da2-41b1-402c-0001-d8d564a2c2fa | 709 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Theme

- Evidência direta: Object/@type = c804fdbd-7c0b-440d-8527-4316c92649a6 em 7 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 43b86e51-163f-44af-ac5a-e101541b1a71 | 7 | 100 | 14.3 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 71.4 | aparentemente obrigatorio | exemplos sanitizados |
| c31007a6-01d3-4788-95b3-425921d47758 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## Transaction

- Evidência direta: Object/@type = 1db606f2-af09-4cf9-a3b5-b481519d28f6 em 183 objetos.
- Evidência direta: média de Part por objeto: 8.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 264be5fb-1b28-4b25-a598-6ca900dd059f | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 183 | 100 | 56.8 | aparentemente obrigatorio | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| d24a58ad-57ba-41b7-9e6e-eaca3543c778 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |

## UserControl

- Evidência direta: Object/@type = 562f4793-aabe-449f-8821-fc77e550698e em 7 objetos.
- Evidência direta: média de Part por objeto: 3.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 3dd92fe7-b095-44d3-9fa0-8488fa3f0c67 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| 8e9e4a7c-a4d3-4c36-8e8e-fb6702402f63 | 7 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 7 | 100 | 85.7 | aparentemente obrigatorio | exemplos sanitizados |

## WebPanel

- Evidência direta: Object/@type = c9584656-94b6-4ccd-890f-332d11fc2c25 em 1196 objetos.
- Evidência direta: média de Part por objeto: 7.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9 | 1196 | 100 | 13.1 | aparentemente obrigatorio | exemplos sanitizados |
| 9b0a32a3-de6d-4be1-a4dd-1b85d3741534 | 1196 | 100 | 0.8 | aparentemente obrigatorio | exemplos sanitizados |
| ad3ca970-19d0-44e1-a7b7-db05556e820c | 1196 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 1196 | 100 | 95.7 | aparentemente obrigatorio | exemplos sanitizados |
| c44bd5ff-f918-415b-98e6-aca44fed84fa | 1196 | 100 | 0.2 | aparentemente obrigatorio | exemplos sanitizados |
| d24a58ad-57ba-41b7-9e6e-eaca3543c778 | 1196 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| e4c4ade7-53f0-4a56-bdfd-843735b66f47 | 1196 | 100 | 0.4 | aparentemente obrigatorio | exemplos sanitizados |

## WorkWithForWeb

- Evidência direta: Object/@type = 78cecefe-be7d-4980-86ce-8d6e91fba04b em 183 objetos.
- Evidência direta: média de Part por objeto: 2.
- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.

| PartType | ObjectsWithPart | PresencePct | EmptyPct | PreliminaryClass | exemplos sanitizados |
| --- | --- | --- | --- | --- | --- |
| a51ced48-7bee-0001-ab12-04e9e32123d1 | 183 | 100 | 0 | aparentemente obrigatorio | exemplos sanitizados |
| babf62c5-0111-49e9-a1c3-cc004d90900a | 183 | 100 | 100 | aparentemente obrigatorio | exemplos sanitizados |





## Origem incorporada - 11-campos-estaveis-vs-variaveis.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 01-base-empirica-geral.md

## Usado por
02-regras-operacionais-e-runtime.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Comparar a estabilidade dos atributos do nó `Object` entre tipos extraídos.
Dar base empírica para cautela em clonagem e preservação de contexto.

- Evidência direta: presença por atributo calculada por tipo extraído.
- Inferência forte: leituras como forte indicio de criticidade estrutural continuam heurísticas e não prova de importação.

## API

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em API\\EXEMPLO-SANITIZADO.xml.

## ColorPalette

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em ColorPalette\\EXEMPLO-SANITIZADO.xml.

## Dashboard

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Dashboard\\EXEMPLO-SANITIZADO.xml.

## DataProvider

- Evidência direta: 24 objetos analisados.
- Evidência direta: objetos com parent: 24; com moduleGuid: 24.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 24 | 100 | quase sempre | papel ainda nao fechado |
| description | 24 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 24 | 100 | quase sempre | papel ainda nao fechado |
| guid | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 24 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 24 | 100 | quase sempre | ligado a parent/module |
| name | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 24 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 24 | 100 | quase sempre | ligado a parent/module |
| parentType | 24 | 100 | quase sempre | ligado a parent/module |
| type | 24 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 24 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 24 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xml.

## DataSelector

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 2; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 2 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| parentType | 2 | 100 | quase sempre | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DataSelector\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DataSelector\\EXEMPLO-SANITIZADO.xml.

## DeploymentUnit

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DeploymentUnit\\EXEMPLO-SANITIZADO.xml.

## DesignSystem

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 1; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1 | 50 | as vezes | ligado a parent/module |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| parentType | 1 | 50 | as vezes | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em DesignSystem\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em DesignSystem\\EXEMPLO-SANITIZADO.xml.

## Document

- Evidência direta: 3 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 3.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 3 | 100 | quase sempre | papel ainda nao fechado |
| description | 3 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 3 | 100 | quase sempre | papel ainda nao fechado |
| guid | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 3 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 3 | 100 | quase sempre | ligado a parent/module |
| name | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 3 | 100 | quase sempre | ligado a parent/module |
| type | 3 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 3 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 3 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Document\\EXEMPLO-SANITIZADO.xml.

## Domain

- Evidência direta: 592 objetos analisados.
- Evidência direta: objetos com parent: 3; com moduleGuid: 592.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 592 | 100 | quase sempre | papel ainda nao fechado |
| description | 592 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 592 | 100 | quase sempre | papel ainda nao fechado |
| guid | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 592 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 592 | 100 | quase sempre | ligado a parent/module |
| name | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 3 | 0.5 | raro | ligado a parent/module |
| parentGuid | 592 | 100 | quase sempre | ligado a parent/module |
| parentType | 3 | 0.5 | raro | ligado a parent/module |
| type | 592 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 592 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 592 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Domain\\EXEMPLO-SANITIZADO.xml.

## ExternalObject

- Evidência direta: 18 objetos analisados.
- Evidência direta: objetos com parent: 18; com moduleGuid: 18.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 18 | 100 | quase sempre | papel ainda nao fechado |
| description | 18 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 18 | 100 | quase sempre | papel ainda nao fechado |
| guid | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 18 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 18 | 100 | quase sempre | ligado a parent/module |
| name | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 18 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 18 | 100 | quase sempre | ligado a parent/module |
| parentType | 18 | 100 | quase sempre | ligado a parent/module |
| type | 18 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 18 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 18 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em ExternalObject\\EXEMPLO-SANITIZADO.xml.

## File

- Evidência direta: 81 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 81.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 81 | 100 | quase sempre | papel ainda nao fechado |
| description | 81 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 81 | 100 | quase sempre | papel ainda nao fechado |
| guid | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 81 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 81 | 100 | quase sempre | ligado a parent/module |
| name | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 81 | 100 | quase sempre | ligado a parent/module |
| type | 81 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 81 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 81 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em File\\EXEMPLO-SANITIZADO.xml.

## Folder

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: Main Programs em Folder\Main Programs.xml.
- Evidência direta: exemplo citado: alias sanitizado em Folder\\EXEMPLO-SANITIZADO.xml.

## Image

- Evidência direta: 250 objetos analisados.
- Evidência direta: objetos com parent: 16; com moduleGuid: 250.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 250 | 100 | quase sempre | papel ainda nao fechado |
| description | 250 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 250 | 100 | quase sempre | papel ainda nao fechado |
| guid | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 250 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 250 | 100 | quase sempre | ligado a parent/module |
| name | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 16 | 6.4 | raro | ligado a parent/module |
| parentGuid | 250 | 100 | quase sempre | ligado a parent/module |
| parentType | 16 | 6.4 | raro | ligado a parent/module |
| type | 250 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 250 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 250 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Image\\EXEMPLO-SANITIZADO.xml.

## Index

- Evidência direta: 228 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 228.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 228 | 100 | quase sempre | papel ainda nao fechado |
| description | 228 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 228 | 100 | quase sempre | papel ainda nao fechado |
| guid | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 228 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 228 | 100 | quase sempre | ligado a parent/module |
| name | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 228 | 100 | quase sempre | ligado a parent/module |
| type | 228 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 228 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 228 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Index\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Index\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Index\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Index\\EXEMPLO-SANITIZADO.xml.

## Language

- Evidência direta: 1 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 1.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1 | 100 | quase sempre | papel ainda nao fechado |
| description | 1 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1 | 100 | quase sempre | ligado a parent/module |
| name | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 1 | 100 | quase sempre | ligado a parent/module |
| type | 1 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Language\\EXEMPLO-SANITIZADO.xml.

## PackagedModule

- Evidência direta: 16 objetos analisados.
- Evidência direta: objetos com parent: 2; com moduleGuid: 16.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| author | 10 | 62.5 | as vezes | papel ainda nao fechado |
| checksum | 16 | 100 | quase sempre | papel ainda nao fechado |
| description | 16 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 16 | 100 | quase sempre | papel ainda nao fechado |
| guid | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 16 | 100 | quase sempre | papel ainda nao fechado |
| licenseUrl | 3 | 18.8 | raro | papel ainda nao fechado |
| moduleDescription | 10 | 62.5 | as vezes | papel ainda nao fechado |
| moduleGuid | 16 | 100 | quase sempre | ligado a parent/module |
| moduleVersion | 10 | 62.5 | as vezes | papel ainda nao fechado |
| name | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| Owner | 10 | 62.5 | as vezes | papel ainda nao fechado |
| PackagedModuleName | 10 | 62.5 | as vezes | papel ainda nao fechado |
| parent | 2 | 12.5 | raro | ligado a parent/module |
| parentGuid | 16 | 100 | quase sempre | ligado a parent/module |
| parentType | 2 | 12.5 | raro | ligado a parent/module |
| projectUrl | 4 | 25 | as vezes | papel ainda nao fechado |
| serverUrl | 3 | 18.8 | raro | papel ainda nao fechado |
| tags | 3 | 18.8 | raro | papel ainda nao fechado |
| type | 16 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 16 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 16 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xml.

## Panel

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 7; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 7 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| parentType | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xml.

## PatternSettings

- Evidência direta: 2 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 2.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2 | 100 | quase sempre | papel ainda nao fechado |
| description | 2 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2 | 100 | quase sempre | ligado a parent/module |
| name | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 2 | 100 | quase sempre | ligado a parent/module |
| type | 2 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em PatternSettings\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em PatternSettings\\EXEMPLO-SANITIZADO.xml.

## Procedure

- Evidência direta: 2281 objetos analisados.
- Evidência direta: objetos com parent: 2281; com moduleGuid: 2281.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 2281 | 100 | quase sempre | papel ainda nao fechado |
| description | 2281 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 2281 | 100 | quase sempre | papel ainda nao fechado |
| guid | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 2281 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 2281 | 100 | quase sempre | ligado a parent/module |
| name | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 2281 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 2281 | 100 | quase sempre | ligado a parent/module |
| parentType | 2281 | 100 | quase sempre | ligado a parent/module |
| type | 2281 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 2281 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 2281 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xml.

## SDT

- Evidência direta: 594 objetos analisados.
- Evidência direta: objetos com parent: 591; com moduleGuid: 594.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 594 | 100 | quase sempre | papel ainda nao fechado |
| description | 594 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 594 | 100 | quase sempre | papel ainda nao fechado |
| guid | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 594 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 594 | 100 | quase sempre | ligado a parent/module |
| name | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 591 | 99.5 | quase sempre | ligado a parent/module |
| parentGuid | 594 | 100 | quase sempre | ligado a parent/module |
| parentType | 591 | 99.5 | quase sempre | ligado a parent/module |
| type | 594 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 594 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 594 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xml.

## Stencil

- Evidência direta: 11 objetos analisados.
- Evidência direta: objetos com parent: 11; com moduleGuid: 11.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 11 | 100 | quase sempre | papel ainda nao fechado |
| description | 11 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 11 | 100 | quase sempre | papel ainda nao fechado |
| guid | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 11 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 11 | 100 | quase sempre | ligado a parent/module |
| name | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 11 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 11 | 100 | quase sempre | ligado a parent/module |
| parentType | 11 | 100 | quase sempre | ligado a parent/module |
| type | 11 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 11 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 11 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Stencil\\EXEMPLO-SANITIZADO.xml.

## SubTypeGroup

- Evidência direta: 709 objetos analisados.
- Evidência direta: objetos com parent: 709; com moduleGuid: 709.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 709 | 100 | quase sempre | papel ainda nao fechado |
| description | 709 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 709 | 100 | quase sempre | papel ainda nao fechado |
| guid | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 709 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 709 | 100 | quase sempre | ligado a parent/module |
| name | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 709 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 709 | 100 | quase sempre | ligado a parent/module |
| parentType | 709 | 100 | quase sempre | ligado a parent/module |
| type | 709 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 709 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 709 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em SubTypeGroup\\EXEMPLO-SANITIZADO.xml.

## Theme

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 0; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xml.

## Transaction

- Evidência direta: 183 objetos analisados.
- Evidência direta: objetos com parent: 183; com moduleGuid: 183.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 183 | 100 | quase sempre | papel ainda nao fechado |
| description | 183 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 183 | 100 | quase sempre | papel ainda nao fechado |
| guid | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 183 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 183 | 100 | quase sempre | ligado a parent/module |
| name | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 183 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 183 | 100 | quase sempre | ligado a parent/module |
| parentType | 183 | 100 | quase sempre | ligado a parent/module |
| type | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 183 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 183 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em Transaction\\EXEMPLO-SANITIZADO.xml.

## UserControl

- Evidência direta: 7 objetos analisados.
- Evidência direta: objetos com parent: 7; com moduleGuid: 7.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 7 | 100 | quase sempre | papel ainda nao fechado |
| description | 7 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 7 | 100 | quase sempre | papel ainda nao fechado |
| guid | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 7 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 7 | 100 | quase sempre | ligado a parent/module |
| name | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 7 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 7 | 100 | quase sempre | ligado a parent/module |
| parentType | 7 | 100 | quase sempre | ligado a parent/module |
| type | 7 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 7 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 7 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em UserControl\\EXEMPLO-SANITIZADO.xml.

## WebPanel

- Evidência direta: 1196 objetos analisados.
- Evidência direta: objetos com parent: 1195; com moduleGuid: 1196.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 1196 | 100 | quase sempre | papel ainda nao fechado |
| description | 1196 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 1196 | 100 | quase sempre | papel ainda nao fechado |
| guid | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 1196 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 1196 | 100 | quase sempre | ligado a parent/module |
| name | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 1195 | 99.9 | quase sempre | ligado a parent/module |
| parentGuid | 1196 | 100 | quase sempre | ligado a parent/module |
| parentType | 1195 | 99.9 | quase sempre | ligado a parent/module |
| type | 1196 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 1196 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 1196 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WebPanel\\EXEMPLO-SANITIZADO.xml.

## WorkWithForWeb

- Evidência direta: 183 objetos analisados.
- Evidência direta: objetos com parent: 183; com moduleGuid: 183.
- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.

| Attribute | ObjectsWithAttribute | PresencePct | PresenceBucket | Reading |
| --- | --- | --- | --- | --- |
| checksum | 183 | 100 | quase sempre | papel ainda nao fechado |
| description | 183 | 100 | quase sempre | papel ainda nao fechado |
| fullyQualifiedName | 183 | 100 | quase sempre | papel ainda nao fechado |
| guid | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| lastUpdate | 183 | 100 | quase sempre | papel ainda nao fechado |
| moduleGuid | 183 | 100 | quase sempre | ligado a parent/module |
| name | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| parent | 183 | 100 | quase sempre | ligado a parent/module |
| parentGuid | 183 | 100 | quase sempre | ligado a parent/module |
| parentType | 183 | 100 | quase sempre | ligado a parent/module |
| type | 183 | 100 | quase sempre | forte indicio de criticidade estrutural |
| user | 183 | 100 | quase sempre | papel ainda nao fechado |
| versionDate | 183 | 100 | quase sempre | papel ainda nao fechado |

- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.
- Evidência direta: exemplo citado: alias sanitizado em WorkWithForWeb\\EXEMPLO-SANITIZADO.xml.





## Origem incorporada - 12-diffs-estruturais-por-tipo.md

## Papel do documento
empírico

## Nível de confiança predominante
médio

## Depende de
30-inventario-bruto-kb.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md

## Usado por
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Comparar amostras simples e complexas por tipo prioritário.
Destacar estabilidade estrutural relativa e pontos de maior risco para clonagem.

- Evidência direta: amostras simples/complexas foram escolhidas por menor/maior combinação de PartCount e tamanho de arquivo.
- Inferência forte: simples e complexo aqui significam complexidade estrutural no XML extraído, não complexidade funcional garantida.

## API

- Evidência direta: amostra simples: alias sanitizado em API\\EXEMPLO-SANITIZADO.xmlapiPDV_Integracao.xml5 Part e 4 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em API\\EXEMPLO-SANITIZADO.xmlapiPDV_Integracao.xml5 Part e tamanho de 25844 bytes.
- Evidência direta: Part type nas amostras simples: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## DataProvider

- Evidência direta: amostra simples: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xmlDPRegions.xml5 Part e 3 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xmldpCargaPedidos.xml5 Part e 4 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xmldpSdtTributacaoDadosBasicosSelecaoConformeParametros.xml5 Part e tamanho de 12558 bytes.
- Evidência direta: amostra complexa: alias sanitizado em DataProvider\\EXEMPLO-SANITIZADO.xmldpFixoSidebarItems.xml5 Part e tamanho de 10713 bytes.
- Evidência direta: Part type nas amostras simples: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## DesignSystem

- Evidência direta: amostra simples: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e 3 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e 4 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e tamanho de 31240 bytes.
- Evidência direta: amostra complexa: alias sanitizado em DesignSystem\EXEMPLO-SANITIZADO.xml com 4 Part e tamanho de 2255 bytes.
- Evidência direta: Part type nas amostras simples: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type nas amostras complexas: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## PackagedModule

- Evidência direta: amostra simples: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xmlExtensions.xml2 Part e 2 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xmlGeneXusSecurityCommon.xml2 Part e 2 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xmlUI.xml3 Part e tamanho de 998 bytes.
- Evidência direta: amostra complexa: alias sanitizado em PackagedModule\\EXEMPLO-SANITIZADO.xmlServices.xml3 Part e tamanho de 990 bytes.
- Evidência direta: Part type nas amostras simples: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type nas amostras complexas: a5e6a251-2df0-44d8-adab-1da237574326; babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc.
- Evidência direta: Part type apenas nas amostras complexas: a5e6a251-2df0-44d8-adab-1da237574326.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Panel

- Evidência direta: amostra simples: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xmlGAMSDNotAuthorized.xml2 Part e 1 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xmlsdLogin.xml2 Part e 1 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xmlGAMSDChangePassword.xml2 Part e tamanho de 16930 bytes.
- Evidência direta: amostra complexa: alias sanitizado em Panel\\EXEMPLO-SANITIZADO.xmlGAMSDUpdateUser.xml2 Part e tamanho de 15516 bytes.
- Evidência direta: Part type nas amostras simples: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Procedure

- Evidência direta: amostra simples: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xmlprocFingePrecisarExecutarAlgoNoServidor.xml7 Part e 1 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xmlprocTipoTituloNulo.xml7 Part e 3 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xmlprocRelatorioVolumesNumRomaneioEPedido.xml7 Part e tamanho de 1114792 bytes.
- Evidência direta: amostra complexa: alias sanitizado em Procedure\\EXEMPLO-SANITIZADO.xmlprocRelatorioDeProducaoDeVolumesComRendimento.xml7 Part e tamanho de 1060772 bytes.
- Evidência direta: Part type nas amostras simples: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## SDT

- Evidência direta: amostra simples: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xmlsdtWpState.xml2 Part e 1 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xmlsdtTerceiroComEstoque.xml2 Part e 1 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xmlNFe_v4_00_TNFe.xml2 Part e tamanho de 1101872 bytes.
- Evidência direta: amostra complexa: alias sanitizado em SDT\\EXEMPLO-SANITIZADO.xmlNFe_v4_00_infNFe.xml2 Part e tamanho de 1054406 bytes.
- Evidência direta: Part type nas amostras simples: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Theme

- Evidência direta: amostra simples: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xmlSimpleBlackBerry.xml3 Part e 2 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xmlSimpleAndroid.xml3 Part e 2 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xmlCarmine.xml3 Part e tamanho de 323724 bytes.
- Evidência direta: amostra complexa: alias sanitizado em Theme\\EXEMPLO-SANITIZADO.xmlCarmineGAM.xml3 Part e tamanho de 304258 bytes.
- Evidência direta: Part type nas amostras simples: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type nas amostras complexas: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## Transaction

- Evidência direta: amostra simples: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e 7 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e 7 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e tamanho de 521796 bytes.
- Evidência direta: amostra complexa: alias sanitizado em Transaction\EXEMPLO-SANITIZADO.xml com 8 Part e tamanho de 294785 bytes.
- Evidência direta: Part type nas amostras simples: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## WebPanel

- Evidência direta: amostra simples: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e 2 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e 2 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e tamanho de 530462 bytes.
- Evidência direta: amostra complexa: alias sanitizado em WebPanel\EXEMPLO-SANITIZADO.xml com 7 Part e tamanho de 403121 bytes.
- Evidência direta: Part type nas amostras simples: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type nas amostras complexas: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.

## WorkWithForWeb

- Evidência direta: amostra simples: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e 1 Part nao vazias.
- Evidência direta: amostra simples: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e 1 Part nao vazias.
- Evidência direta: amostra complexa: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e tamanho de 188770 bytes.
- Evidência direta: amostra complexa: alias sanitizado em WorkWithForWeb\EXEMPLO-SANITIZADO.xml com 2 Part e tamanho de 151944 bytes.
- Evidência direta: Part type nas amostras simples: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type nas amostras complexas: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: Part type apenas nas amostras complexas: nenhum.
- Evidência direta: Part type apenas nas amostras simples: nenhum.
- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.
- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.






