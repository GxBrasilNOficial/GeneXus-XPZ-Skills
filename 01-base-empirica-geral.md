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

- Evidência direta: amostra simples: alias sanitizado `DPExemploLista.xml` com 5 `Part` e 3 `Part` nao vazias.
- Evidência direta: amostra simples: alias sanitizado `DPExemploParm.xml` com 5 `Part` e 4 `Part` nao vazias.
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

- Evidência direta: amostra simples: alias sanitizado `PRCExemploMinimo.xml` com 7 `Part` e 1 `Part` nao vazia.
- Evidência direta: amostra simples: alias sanitizado `PRCExemploParm.xml` com 7 `Part` e 3 `Part` nao vazias.
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

## Moldes sanitizados completos de Procedure e DataProvider

- Evidencia direta: esta base agora contem 2 moldes XML sanitizados completos de `Procedure` e 2 de `DataProvider`.
- Inferencia forte: esse conjunto complementa os moldes ja existentes de `WebPanel` e `Transaction`, reduzindo a necessidade de consulta adicional ao acervo bruto para prototipos controlados desses dois tipos.
- Hipotese: para `Procedure` muito densa ou `DataProvider` com saida muito especializada, ainda pode ser necessario buscar molde bruto comparavel adicional.

### Molde sanitizado de Procedure 1 - `PRCExemploMinimo`

- Perfil: `Procedure` minima, com inventario recorrente de `Part` e quase nenhum conteudo interno.
- Uso operacional: boa casca para testes de serializacao, stub server-side e verificacao do envelope estrutural do tipo.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="624fa1ae-7a20-4d68-bc8a-b54254fa3ce7" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-03-27T22:31:45.0000000Z" checksum="ac868db7f602aeb0f9d9f1c51a919527" fullyQualifiedName="PRCExemploMinimo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="d6ecd738-8c9a-4361-9a4e-f638fbd98067" name="PRCExemploMinimo" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Minima" parent="PastaExemploProcedure" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Properties />
  </Part>
  <Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
    <Properties />
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Properties />
  </Part>
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Properties />
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Properties />
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
      <Value>PRCExemploMinimo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

### Molde sanitizado de Procedure 2 - `PRCExemploParm`

- Perfil: `Procedure` curta com `parm(out:...)` e variavel baseada em dominio.
- Uso operacional: boa referencia para clonagem controlada quando o alvo tiver parametro simples e variavel associada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="988004e2-6090-42c3-9603-c073172b75a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2017-11-30T13:14:40.0000000Z" checksum="f03125659ba83a8972206dfeb9b0dfc8" fullyQualifiedName="PRCExemploParm" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="96caabbb-924a-4d2b-83f9-62e5e192608a" name="PRCExemploParm" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Parm" parent="PastaExemploProcedure" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Properties />
  </Part>
  <Part type="c414ed00-8cc4-4f44-8820-4baf93547173">
    <Properties />
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[parm(out:&TipoExemplo);
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
    <Variable Name="TipoExemplo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>TipoExemplo</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:TipoExemplo</Value>
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
      <Value>PRCExemploParm</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataProvider 1 - `DPExemploLista`

- Perfil: `DataProvider` simples com saida de colecao declarada no proprio `Source`.
- Uso operacional: boa referencia para saida pequena baseada em estrutura repetida.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fbf65a0f-f5fe-40b5-9328-ac966656d448" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2009-07-22T19:06:02.0000000Z" checksum="2c78d22a9661e372b2cefb9d31d6018c" fullyQualifiedName="DPExemploLista" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="9fed987b-56be-4e31-9e9f-09f7c9b959c3" name="DPExemploLista" type="2a9e9aba-d2de-4801-ae7f-5e3819222daf" description="DPExemploLista" parent="PastaExemploDP" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="1d8aeb5a-6e98-45a7-92d2-d8de7384e432">
    <Source><![CDATA[SdtExemploLista
{
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoA'
		RCountry = 'PaisA'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoB'
		RCountry = 'PaisB'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoC'
		RCountry = 'PaisC'
	}
	SdtExemploListaItem
	{
		RValnum =4
		RValtext = 'RegiaoD'
		RCountry = 'PaisD'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoE'
		RCountry = 'PaisE'
	}
	SdtExemploListaItem
	{
		RValnum =2
		RValtext = 'RegiaoF'
		RCountry = 'PaisF'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoG'
		RCountry = 'PaisG'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoH'
		RCountry = 'PaisH'
	}
	SdtExemploListaItem
	{
		RValnum =1
		RValtext = 'RegiaoI'
		RCountry = 'PaisI'
	}
}
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Properties />
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
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
      <Value>DPExemploLista</Value>
    </Property>
    <Property>
      <Name>OutputSDT</Name>
      <Value>447527b5-9210-4523-898b-5dccb17be60a-SdtExemploLista</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataProvider 2 - `DPExemploParm`

- Perfil: `DataProvider` com `parm(in:...)`, `OutputCollection=True` e composicao textual mais rica no `Source`.
- Uso operacional: boa referencia para `DataProvider` orientado por parametros e saida em colecao.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="79a956f5-e947-44fb-9165-5914625207c6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-18T18:35:14.0000000Z" checksum="d7d87280290ffc92084066e33abd7c51" fullyQualifiedName="DPExemploParm" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="1ee0e754-a66a-47bf-a7aa-3af9a0da28c0" name="DPExemploParm" type="2a9e9aba-d2de-4801-ae7f-5e3819222daf" description="DataProvider Exemplo Parm" parent="PastaExemploDP" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="1d8aeb5a-6e98-45a7-92d2-d8de7384e432">
    <Source><![CDATA[SdtExemploChaveValor order ContextoAId, ContextoBId, SequenciaExemplo, RegistroId
{
	Chave = RegistroId.ToString()
	
	Valor = "CtxA:" + RegistroEmpresaId.ToString().Trim() + 
	" Chave: " + RegistroId.ToFormattedString() +
	"| Seq:" + SequenciaExemplo.ToString() + 
	" | A:" + procLeftExemplo(PessoaAId.ToString()," ",10) +
	" | B:" + procRightExemplo(PessoaBId.ToString()," ",10) +
	"-" + PessoaBNome.Trim() + " (" + TipoRegistro.EnumerationDescription() + ")"
	
}
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[parm(in:ContextoAId, in:ContextoBId);
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
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
      <Value>DPExemploParm</Value>
    </Property>
    <Property>
      <Name>OutputSDT</Name>
      <Value>447527b5-9210-4523-898b-5dccb17be60a-SdtExemploChaveValor</Value>
    </Property>
    <Property>
      <Name>OutputCollection</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Panel e API

- Evidência direta: o acervo usado nesta base contem 7 objetos Panel e 1 objeto API.
- Inferência forte: pela baixa cardinalidade, faz mais sentido documentar moldes completos representativos do que tentar abrir muitas familias finas.
- Inferência forte: os anexos abaixo servem como referencia estrutural documentada para prototipos conservadores, sempre preservando Object/@type, inventario de Part e hierarquia interna.

### Molde sanitizado de Panel 1 - `PanelExemploNaoAutorizado`

- Perfil: Panel mobile enxuto, com PatternPart, layout simples e poucos eventos.
- Uso operacional: boa referencia para Panel de mensagem/entrada curta com estrutura gerada por pattern.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="d8c5213a-038e-4c3d-8cad-c4f38c6c10ff" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-08-03T13:19:24.0000000Z" checksum="05f72ad114b0959c3b1154503e4e7ada" fullyQualifiedName="PanelExemploNaoAutorizado" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="0492a00a-5a72-44bb-8fe5-6468b143a1db" name="PanelExemploNaoAutorizado" type="d82625fd-5892-40b0-99c9-5c8559c197fc" description="Nao Autorizado" parent="PastaExemploPanel" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="b4378a97-f9b2-4e05-b2f8-c610de258402">
    <PatternPart type="a51ced48-7bee-0001-ab12-04e9e32123d1">
      <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="17.11.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance>
  <notifications />
  <level id="9c3fa622-c8e3-419b-be3f-659de559bbd2" name="Level">
    <detail variables="&lt;Variables&gt;&lt;Variable Id=&quot;9&quot; Name=&quot;Password&quot; Description=&quot;Password&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Description&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthPassword, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;10&quot; Name=&quot;UserName&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;UserName&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthUserIdentification, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;11&quot; Name=&quot;AuthRepository&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;AuthRepository&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;exo:AuthRepository, SANITIZEDSecurity&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;StandardVariable Id=&quot;4&quot; Name=&quot;Pgmdesc&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmdesc&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;3&quot; Name=&quot;Pgmname&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmname&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;2&quot; Name=&quot;Time&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Time&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;1&quot; Name=&quot;Today&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Today&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Date&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;/Variables&gt;" events="Event Start&#xA;&#x9;&amp;AuthRepository = AuthRepository.Get()&#xA;&#x9;Do Case&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.Name&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.Name)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.EMail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.EMail)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.NameEmail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.NameEmail)&#xA;&#x9;EndCase&#xA;Endevent&#xA;&#xA;&#xA;Event 'BtnEntrar'&#xA;&#x9;Composite&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.ShowWithTitle(&quot;Conectando...&quot;)&#xA;&#x9;&#x9;SANITIZED.SD.Actions.Entrar(&amp;UserName, &amp;Password)&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.Hide()&#xA;&#x9;&#x9;Return&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;Event 'Back'&#xA;&#x9;Return&#xA;Endevent&#xA;">
      <layout id="78852907-2ff5-5ed0-aaf2-079ff7de3e65" Type="View">
        <table id="b32d02f2-0dd3-4ff1-ab64-a3e660c6d75e" controlName="MainTable" columnsStyle="10dip;100%;10dip" responsiveSizes="[]">
          <row id="9c151a94-80d2-46f8-96c6-9116c7daabd3" rowHeight="50dip">
            <cell id="4ca3501c-1d5f-44c0-9a2f-d35dc46d120b" />
            <cell id="a6049a5b-7a80-4dbf-be0e-823046c2135b" hAlign="Center" vAlign="Middle">
              <textblock controlName="TBMsg" caption="Nao autorizado: acesso negado." enabled="False" />
            </cell>
            <cell id="4eb8110b-d034-4ff5-b1e6-52437c4e7d96" />
          </row>
          <row id="d752f865-4ff5-421f-86be-611fe83c74cb" rowHeight="15dip" />
          <row id="fe634880-d9ac-4961-925d-b5af54956e19" rowHeight="pd">
            <cell id="8852d807-ce19-43b1-b14b-9d87331132d6" />
            <cell id="6b999592-fc89-46e3-8f85-e51d86bfb41f">
              <data attribute="&amp;UserName" labelCaption="Name" inviteMessage="" />
            </cell>
          </row>
          <row id="761dbdcc-a547-4dae-9d08-a1cfd3f46eaf" rowHeight="pd">
            <cell id="43d045c0-a1e1-4ddb-ae47-10dbaf4bb4b3" />
            <cell id="32839ce6-9945-47b0-a77f-06af61e9d68b">
              <data attribute="&amp;Password" inviteMessage="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;idEnableShowPasswordHint&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
            </cell>
          </row>
          <row id="f65f348a-0497-412e-8a47-c406ced202cc" rowHeight="15dip" />
          <row id="cd2a293a-0b52-46a4-933a-74e67e355b2e" rowHeight="pd">
            <cell id="9d22a783-969c-4a9a-8254-a92485853853" />
            <cell id="af4ba31d-e944-4544-a51c-ac5f43a4c47d" hAlign="Center" vAlign="Middle">
              <action controlName="BtnEntrar" onClickEvent="'BtnEntrar'" caption="ENTRAR" class="button-primary" />
            </cell>
          </row>
        </table>
      </layout>
    </detail>
  </level>
</instance>]]></Data>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </PatternPart>
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
      <Value>PanelExemploNaoAutorizado</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Nao Autorizado</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>AndroidBaseStyle</Name>
      <Value>AndroidBaseStyleDark</Value>
    </Property>
    <Property>
      <Name>CacheEnabled</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityNone</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>PanelExemploNaoAutorizado</Value>
    </Property>
  </Properties>
  <Categories>Panel_Samples-sd</Categories>
</Object>

` 

### Molde sanitizado de Panel 2 - `PanelExemploAcesso`

- Perfil: Panel mobile com PatternPart, acoes de autenticacao, ctionBar e fluxo de entrada mais rico.
- Uso operacional: boa referencia para Panel com eventos, acoes e dependencias de pattern mais evidentes.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="d8c5213a-038e-4c3d-8cad-c4f38c6c10ff" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-08-04T13:50:26.0000000Z" checksum="7bff8a381959f9267b8a4be2f92c03d5" fullyQualifiedName="PanelExemploAcesso" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="865ab616-d866-4c90-9110-d352975022b5" name="PanelExemploAcesso" type="d82625fd-5892-40b0-99c9-5c8559c197fc" description="Acesso" parent="PastaExemploPanel" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="b4378a97-f9b2-4e05-b2f8-c610de258402">
    <PatternPart type="a51ced48-7bee-0001-ab12-04e9e32123d1">
      <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="17.11.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance>
  <notifications />
  <level id="45969122-dc02-4641-8055-f127e24fef52" name="Level">
    <detail variables="&lt;Variables&gt;&lt;Variable Id=&quot;13&quot; Name=&quot;AuthRepository&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;AuthRepository&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;exo:AuthRepository, SANITIZEDSecurity&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;12&quot; Name=&quot;Password&quot; Description=&quot;Password&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Description&lt;/Name&gt;&lt;Value&gt;Password&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthPassword, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;Variable Id=&quot;10&quot; Name=&quot;UserName&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;UserName&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;idBasedOn&lt;/Name&gt;&lt;Value&gt;Domain:AuthUserIdentification, SANITIZEDSecurityCommon&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/Variable&gt;&lt;StandardVariable Id=&quot;4&quot; Name=&quot;Pgmdesc&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmdesc&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;256&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;3&quot; Name=&quot;Pgmname&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Pgmname&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;128&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;2&quot; Name=&quot;Time&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Time&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Character&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Length&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AttMaxLen&lt;/Name&gt;&lt;Value&gt;8&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;StandardVariable Id=&quot;1&quot; Name=&quot;Today&quot;&gt;&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;Name&lt;/Name&gt;&lt;Value&gt;Today&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;OBJ_TYPE&lt;/Name&gt;&lt;Value&gt;id_OTYPE_VAR&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;IsStandardVariable&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;ATTCUSTOMTYPE&lt;/Name&gt;&lt;Value&gt;bas:Date&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;&lt;Documentation&gt;&amp;lt;WikiPage&amp;gt;&amp;lt;Modified&amp;gt;0001-01-01T00:00:00&amp;lt;/Modified&amp;gt;&amp;lt;Revision&amp;gt;0&amp;lt;/Revision&amp;gt;&amp;lt;/WikiPage&amp;gt;&lt;/Documentation&gt;&lt;/StandardVariable&gt;&lt;/Variables&gt;" events="Event Start&#xA;&#x9;&amp;AuthRepository = AuthRepository.Get()&#xA;&#x9;Do Case&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.Name&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.Name)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.EMail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.EMail)&#xA;&#x9;Case &amp;AuthRepository.UserIdentification = AuthRepositoryUserIdentifications.NameEmail&#xA;&#x9;&#x9;&amp;UserName.Caption = AuthRepositoryUserIdentifications.EnumerationDescription(AuthRepositoryUserIdentifications.NameEmail)&#xA;&#x9;EndCase&#xA;Endevent&#xA;&#xA;Event 'BtnAcesso'&#xA;&#x9;Composite&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.ShowWithTitle(&quot;Conectando...&quot;)&#xA;&#x9;&#x9;SANITIZED.SD.Actions.Autenticar(&amp;UserName, &amp;Password)&#xA;&#x9;&#x9;SANITIZED.Common.UI.Progress.Hide()&#xA;&#x9;&#x9;Return&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;//Event 'Facebook'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//      &amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;facebook&quot;  //Use only when more than one Facebook authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Facebook, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//      Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'Google'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//      &amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;google&quot;  //Use only when more than one Google authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Google, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'Twitter'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.Twitter, &amp;UserName, &amp;Password)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//EndEvent&#xA;&#xA;//Event 'AuthRemote'&#xA;//&#x9;Composite&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters = new()&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters.Repository&#x9;&#x9;&#x9;&#x9;= &amp;RepositoryGUID&#x9;//Use only when more than one Repository is defined in the Identity Provider (multi-tenant)&#xA;//&#x9;&#x9;&amp;AcessoExternalAdditionalParameters.AuthenticationTypeName&#x9;= !&quot;idp_name&quot;  &#x9;&#x9;//Use only when more than one AuthRemote authentication type is defined&#xA;//      SANITIZED.SD.Actions.AutenticarExternal(AuthAuthenticationTypes.AuthRemote, &amp;UserName, &amp;Password, &amp;AcessoExternalAdditionalParameters)&#xA;//&#x9;&#x9;Return&#xA;//&#x9;EndComposite&#xA;//Endevent&#xA;&#xA;&#xA;&#xA;Event 'Register'&#xA;&#x9;Composite&#xA;&#x9;&#x9;PanelExemploRegistrar()&#xA;&#x9;&#x9;Return&#xA;&#x9;&#x9;If 1=0&#xA;&#x9;&#x9;&#x9;Do 'Dummy'&#xA;&#x9;&#x9;Endif&#xA;&#x9;EndComposite&#xA;EndEvent&#xA;&#xA;&#xA;Sub 'Dummy'&#xA;&#x9;//To include in build references&#xA;&#x9;PanelExemploAtualizar()&#xA;&#x9;PanelExemploAlterarSenha()&#xA;&#x9;PanelExemploNaoAutorizado()&#xA;Endsub&#xA;&#xA;&#xA;" rules="&#xD;&#xA;">
      <layout id="3448c091-227a-50bb-a80a-dfbc08086458" Type="View">
        <table id="ab58fa72-dc00-4426-b898-f29b04c920a8" controlName="MainTable" columnsStyle="10dip;100%;10dip" responsiveSizes="[]">
          <row id="f906596b-4aad-4521-8da4-80aafbabdfbb" rowHeight="50dip" />
          <row id="b020ea6f-2c5c-4a01-9474-913934e181b0" rowHeight="pd">
            <cell id="365aba11-c77f-4c3d-a0a6-eacb08e3dc44" />
            <cell id="2b8f0168-0df7-4de1-bbf8-ffb295d36429">
              <data attribute="&amp;UserName" labelCaption="Name" readonly="False" inviteMessage="" />
            </cell>
            <cell id="da5e96b9-3aff-4aab-b89e-39d7be52ad7a" />
          </row>
          <row id="b99ef45d-712d-4945-85c3-7c017cf00d05" rowHeight="pd">
            <cell id="7b01445f-554a-482d-9363-f71b40761bf4" />
            <cell id="2a9b93b9-c15b-426a-b3e2-3372642b075d">
              <data attribute="&amp;Password" labelCaption="Password" readonly="False" inviteMessage="" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;idEnableShowPasswordHint&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
            </cell>
          </row>
          <row id="91340143-cf76-4a5a-9536-2328d1d7c7e4" rowHeight="15dip" />
          <row id="f36e98c0-93a9-4fc7-8b6f-99a81f196b01" rowHeight="pd">
            <cell id="c4da8518-eb92-45c4-8c5f-6169048318a7" />
            <cell id="de0e3236-6940-41b2-9b10-c01b64bb2dbf" hAlign="Center" vAlign="Middle">
              <action controlName="BtnAcesso" onClickEvent="'BtnAcesso'" caption="Acesso" class="button-primary" />
            </cell>
          </row>
        </table>
        <actionBar>
          <item priority="High">
            <action controlName="BtnRegister" onClickEvent="'Register'" />
          </item>
        </actionBar>
      </layout>
    </detail>
  </level>
</instance>]]></Data>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </PatternPart>
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
      <Value>PanelExemploAcesso</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Acesso</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>idConnectivitySupport</Name>
      <Value>idOnline</Value>
    </Property>
    <Property>
      <Name>AndroidBaseStyle</Name>
      <Value>AndroidBaseStyleDark</Value>
    </Property>
    <Property>
      <Name>CacheEnabled</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityLevel</Name>
      <Value>SecurityNone</Value>
    </Property>
    <Property>
      <Name>IntegratedSecurityPermissionPrefix</Name>
      <Value>PanelExemploAcesso</Value>
    </Property>
  </Properties>
  <Categories>Panel_Samples-sd</Categories>
</Object>

` 

### Molde sanitizado de API 1 - `APIExemploIntegracao`

- Perfil: API com bloco Service, multiplos RestMethod, eventos .Before/.After e conjunto denso de variaveis.
- Uso operacional: boa referencia para API com servicos REST coordenados por eventos e logica auxiliar interna.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="74e9b5f3-f6b7-4421-b895-d960d6b1078b" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-03-12T15:02:57.0000000Z" checksum="2ca44baa29aabb01a13db31a19ad40b3" fullyQualifiedName="APIExemploIntegracao" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="854bf450-73b9-4472-bbcc-24ddcb983022" name="APIExemploIntegracao" type="36e32e2d-023e-4188-95df-d13573bac2e0" description="API Exemplo Integracao" parent="PastaExemploAPI" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5">
    <Source><![CDATA[Service
{	
	[RestMethod(POST)]
	[Description("Obter a lista de itens conforme parametros.")]
	ObterItens(
		in:&ItemEmpresaId, 
		in:&ItemCodigo, 
		in:&UltimaAlteracaoInicio, 
		in:&ComDFouPedidoOuVmEmpresaId, 
		in:&ComDFouPedidoOuVmDesde, 
		in:&SemDadosFiscaisAdicionais, 
		in:&ItemMarcaId, 
		in:&GrupoDeItemId, 
		out:&ListaSdtItemDadosBasicos, 
		out:&MensagensRetorno
	)
	=> procListaSdtItemDadosBasicosConformeParametros(
		"", 
		&ItemEmpresaId, 
		&ItemTipoProd, 
		&ItemCodigo, 
		&UltimaAlteracaoInicio, 
		&ComDFouPedidoOuVmEmpresaId, 
		&ComDFouPedidoOuVmDesde, 
		&SemDadosFiscaisAdicionais, 
		&SemDadosOpcionaisPorEmpresa, 
		&SemIdiomas, 
		&GrupoEspecie, 
		&ItemMarcaId, 
		&ComMarca, 
		&CorteTipo, 
		&TipoLocalEstoque, 
		&GrupoDeItemId, 
		&ListaSdtItemDadosBasicos, 
		&MensagensRetorno
	);

	[RestMethod(POST)]
	[Description("Obter a lista de regras conforme parametros.")]
	ObterRegras(
		in:&RegraEmpresaId, 
		in:&RegraId,
		in:&DocumentoEmpresaId,
		in:&TipoExemplo,
		in:&UltimaAlteracaoInicio, 
		out:&sdtRegraDadosBasicosSelecao, 
		out:&MensagensRetorno
	)
	=> procSdtRegraDadosBasicosSelecaoConformeParametros(
		&RegraEmpresaId, 
		&RegraId,
		&DocumentoEmpresaId,
		&TipoExemplo,
		&UltimaAlteracaoInicio, 
		&sdtRegraDadosBasicosSelecao, 
		&MensagensRetorno
	);
	
	[RestMethod(POST)]
	[Description("enviar um documento em Base64 para processamento.")]
	EnviarDocumento(
		in:&NomeDoArquivo, 
		in:&ConteudoEmBase64,
		in:&DocumentoEmpresaId,
		out:&OperacaoSucesso, 
		out:&MensagensRetorno
	)
	=> procImportaDocumentoDeBase64(
		&NomeDoArquivo, 
		&ConteudoEmBase64,
		&DocumentoEmpresaId,
		&OperacaoSucesso, 
		&MensagensRetorno
	);
	
}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[Event ObterItens.Before
	
	&ItemTipoProd = TipoProd.Item
	
Endevent
Event ObterItens.After
	
	do 'CompletaMensagensRetorno'	
	
Endevent	

Event ObterRegras.Before
	
	&ContextoLoginId = procEmpresaContextoId(&DocumentoEmpresaId)		
	if &ContextoLoginId.IsEmpty()
			
		&ContextoLoginId = &DocumentoEmpresaId
			
	endif	
	
	do 'CompletaLogin'
	
Endevent
Event ObterRegras.After
	
	do 'CompletaMensagensRetorno'	
	
Endevent	


Event EnviarDocumento.Before

	&ContextoLoginId = procEmpresaContextoId(&DocumentoEmpresaId)		
	if &ContextoLoginId.IsEmpty()
			
		&ContextoLoginId = &DocumentoEmpresaId
			
	endif	
	
	do 'CompletaLogin'

Endevent
Event EnviarDocumento.After
	
	if &OperacaoSucesso
		
		&MensagensRetorno =
		procRemoveUmTipoDeMensagem(&MensagensRetorno, TiposMensagemExemplo.Warning, -1)
		
	endif

	&MensagensRetorno =
	procRemoveUmTipoDeMensagem(&MensagensRetorno, TiposMensagemExemplo.Info, 0)

	do 'CompletaMensagensRetorno'
	
Endevent	
	
	
//Sub 'CompletaMensagensRetorno'
Sub 'CompletaMensagensRetorno'
	
	procAgregaMessages(&MensagensRetorno, &MensagensInicio)
	
Endsub	

	
//Sub 'CompletaLogin'
Sub 'CompletaLogin'

	&AbortarInicio = false
	
	&AuthSession = AuthSession.Get(&AuthErrors)
	
	&SessionValid = AuthSession.IsValid(&AuthSession, &AuthErrors)
	
	Do Case
		Case &AuthErrors.Count > 0
			
			procAgregaMensagensDeErrosAuth(&MensagensInicio, &AuthErrors)
			
			//procAgregaNovaMensagem(&MensagensInicio, "", TiposMensagemExemplo.Error,
			//"Erro: (Falha na autenticacao) " + &AuthErrors.ToJson())
			//"Erro: Falha na autenticacao. Com " + &AuthErrors.Count.ToString().Trim() + " erros.")
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
			
		Case not &SessionValid
			
			procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
			'Erro: sessao de autenticacao invalida.')
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
			
		Case &ContextoLoginId.IsEmpty()

			procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
			'Erro: contexto de login nao definido.')
			
			&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
			&AbortarInicio = true
		
		Otherwise

			&AuthUser    = &AuthSession.User
			&UserName  = &AuthUser.GetName()
			
			&loginUsuarioId = procUsuarioPorLogin(&UserName.ToString().Trim())
			
			//if &loginUsuarioId.IsEmpty()
			if &loginUsuarioId.IsEmpty()
				
				procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
				'Erro: usuario nao identificado para o login ' + &UserName + ".")
	
				&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
				&AbortarInicio = true
				
			else
				
				procCriaSessaoUsuario(&loginUsuarioId,"")
				
				//if procEmpresaLiberadaProUsuarioExemplo(&ContextoLoginId)
				if procEmpresaLiberadaProUsuarioExemplo(&ContextoLoginId)
					
					procCriaSessaoEmpresa(&ContextoLoginId, "")
					
				else
					
					procAgregaNovaMensagem(&MensagensInicio,"", TiposMensagemExemplo.Error, 
					'Erro: Usuário Id ' + &loginUsuarioId.ToString().Trim() + 
					' sem permissao para a empresa id ' + &ContextoLoginId.ToString().Trim() +
					".")
		
					&RestCode = 403  // Forbidden (ou 401 se for "não autenticado")
					&AbortarInicio = true
					
				endif
				
			endif
		
	Endcase

	//if &AbortarInicio
	if &AbortarInicio
		
		do 'CompletaMensagensRetorno'
		Return
		
	endif

Endsub
]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="AbortarInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AbortarInicio</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComDFouPedidoOuVmDesde">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComDFouPedidoOuVmDesde</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Data</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComDFouPedidoOuVmEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComDFouPedidoOuVmEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:EmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ComMarca">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ComMarca</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:SimOuNao</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ConteudoEmBase64">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ConteudoEmBase64</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:LongVarChar</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="CorteTipo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>CorteTipo</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Corte Tipo</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:CorteTipo</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="DocumentoEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>DocumentoEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Documento Fiscal Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:DocumentoEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="loginUsuarioId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>loginUsuarioId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Usuario Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:UsuarioId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="emptyAuthSession">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>emptyAuthSession</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthSession, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthError">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthError</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthError, SanitizedSecurity</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>4</Value>
        </Property>
        <Property>
          <Name>Decimals</Name>
          <Value>0</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>4</Value>
        </Property>
        <Property>
          <Name>AttAvgLen</Name>
          <Value>0</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthErrors">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthErrors</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthError, SanitizedSecurity</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthLoginAdditionalParameters">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthLoginAdditionalParameters</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthLoginAdditionalParameters, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthSession">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthSession</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthSession, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="AuthUser">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>AuthUser</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>exo:AuthUser, SanitizedSecurity</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GrupoDeItemId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GrupoDeItemId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Grupo De Item Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:GrupoDeItemId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="GrupoEspecie">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>GrupoEspecie</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:GrupoEspecie</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="MensagensInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>MensagensInicio</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:Messages, Sanitized.Common</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ListaSdtItemDadosBasicos">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ListaSdtItemDadosBasicos</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:sdtItemDadosBasicos</Value>
        </Property>
        <Property>
          <Name>AttCollection</Name>
          <Value>True</Value>
        </Property>
        <Property>
          <Name>idVarServiceExtName</Name>
          <Value>ListaItemDadosBasicos</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeArquivo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeArquivo</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>512</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>512</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="NomeDoArquivo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>NomeDoArquivo</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>256</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>256</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ContextoLoginId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ContextoLoginId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Empresa Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:EmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemCodigo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemCodigo</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Código</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemCodigo</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemEmpresaId">
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
          <Value>Attribute:ItemEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemMarcaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemMarcaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Marca Id</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemMarcaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ItemTipoProd">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ItemTipoProd</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Item Tipo</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:ItemTipoProd</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="ProgressIndicator_Title">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>ProgressIndicator_Title</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
        <Property>
          <Name>Length</Name>
          <Value>256</Value>
        </Property>
        <Property>
          <Name>AttMaxLen</Name>
          <Value>256</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="MensagensRetorno">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>MensagensRetorno</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:Messages, Sanitized.Common</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="sdtRegraDadosBasicosSelecao">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>sdtRegraDadosBasicosSelecao</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>sdt:sdtRegraDadosBasicosSelecao</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemDadosFiscaisAdicionais">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemDadosFiscaisAdicionais</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemDadosOpcionaisPorEmpresa">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemDadosOpcionaisPorEmpresa</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SemIdiomas">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SemIdiomas</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Logico</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="SessionValid">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>SessionValid</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="OperacaoSucesso">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>OperacaoSucesso</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:Boolean</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="tipodeconteudo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>tipodeconteudo</Value>
        </Property>
        <Property>
          <Name>ATTCUSTOMTYPE</Name>
          <Value>bas:VarChar</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="TipoLocalEstoque">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>TipoLocalEstoque</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:TipoLocalEstoque</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="RegraEmpresaId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>RegraEmpresaId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Regra Empresa Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:RegraEmpresaId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="RegraId">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>RegraId</Value>
        </Property>
        <Property>
          <Name>Description</Name>
          <Value>Regra Id</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Attribute:RegraId</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UltimaAlteracaoInicio">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UltimaAlteracaoInicio</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:Data</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UserLogin">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UserLogin</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="UserName">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>UserName</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:AuthUserIdentification, SanitizedSecurityCommon</Value>
        </Property>
      </Properties>
    </Variable>
    <Variable Name="TipoExemplo">
      <Documentation />
      <Properties>
        <Property>
          <Name>Name</Name>
          <Value>TipoExemplo</Value>
        </Property>
        <Property>
          <Name>idIsAutoDefinedVariable</Name>
          <Value>False</Value>
        </Property>
        <Property>
          <Name>idBasedOn</Name>
          <Value>Domain:TipoExemplo</Value>
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
      <Value>APIExemploIntegracao</Value>
    </Property>
    <Property>
      <Name>GENERATE_OPEN_API</Name>
      <Value>Yes</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

## Moldes sanitizados completos de WorkWithForWeb

- Evidência direta: o acervo usado nesta base contem 183 objetos WorkWithForWeb.
- Inferência forte: o tipo mostra forte dependência de Pattern, parent transacional e estrutura declarativa do bloco <Data Pattern=...>.
- Inferência forte: faz sentido documentar pelo menos um molde enxuto e um molde denso para cobrir extremos de uso real sem inventar estrutura.

### Molde sanitizado de WorkWithForWeb 1 - `WorkWithWebGrupoExemplo`

- Perfil: WorkWithForWeb enxuto com uma selecao simples, poucos atributos e uma aba tabular basica.
- Uso operacional: boa referencia para pattern web ligado a transaction simples, com leitura facil da selecao, filtro e view.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="098e2fb8-c338-4e2d-901b-061d18a3ee68" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-08-06T11:20:21.0000000Z" checksum="2453cba7e236b417113f4c8a3a1e97d3" fullyQualifiedName="WorkWithWebGrupoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="7140e146-7d45-07ad-16d5-8b7389584e23" name="WorkWithWebGrupoExemplo" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" description="Work With Web Grupo Exemplo" parent="GrupoExemplo" parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6">
  <Part type="a51ced48-7bee-0001-ab12-04e9e32123d1">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="1.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance webFormDefaults="Responsive Web Design" updateTransaction="Apply WW Style">
  <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-GrupoExemplo" />
  <level id="098e2fb8-c338-4e2d-901b-061d18a3ee68:1" name="GrupoExemplo">
    <descriptionAttribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" />
    <selection description="Grupos de Exemplo" page="&lt;unlimited&gt;">
      <modes />
      <attributes>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploEmpresaId" description="Empresa Id" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploId" description="Id" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
      </attributes>
      <filter>
        <attributes>
          <filterAttribute name="GrupoExemploDescricao" description="Descricao" default="" />
        </attributes>
        <conditions>
          <condition value="GrupoExemploEmpresaId = procEmpresaGrupoExemplo() or GrupoExemploEmpresaId = procLeContextoSessao()" />
          <condition value="GrupoExemploDescricao.IndexOf(&amp;GrupoExemploDescricao) &gt; 0 when not &amp;GrupoExemploDescricao.IsEmpty()" />
        </conditions>
      </filter>
    </selection>
    <view caption="GrupoExemploDescricao.ToString()" description="Grupo de Exemplo" backToSelection="True" masterPage="&lt;default&gt;">
      <parameters>
        <parameter name="GrupoExemploEmpresaId" null="True" />
        <parameter name="GrupoExemploId" null="True" />
      </parameters>
      <fixedData>
        <attributes>
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
        </attributes>
      </fixedData>
      <tabs>
        <tab name="Geral" code="General" description="Grupo de Exemplo" type="Tabular" wcname="GrupoExemploGeneral">
          <attributes>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploEmpresaId" description="Emp.Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploId" description="GrupoExemplo Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-GrupoExemploDescricao" description="Descricao" autolink="True" visible="True" />
          </attributes>
          <actions>
            <action name="Update" />
            <action name="Delete" />
          </actions>
        </tab>
      </tabs>
    </view>
  </level>
</instance>]]></Data>
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
      <Value>WorkWithWebGrupoExemplo</Value>
    </Property>
    <Property>
      <Name>KBObject</Name>
      <Value>1db606f2-af09-4cf9-a3b5-b481519d28f6-GrupoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

` 

### Molde sanitizado de WorkWithForWeb 2 - `WorkWithWebRegistroOperacional`

- Perfil: WorkWithForWeb denso, com muitas colunas, filtros, ordens, links e trechos declarativos extensos dentro do pattern.
- Uso operacional: boa referencia para casos de alta variabilidade estrutural e forte dependencia de contexto transacional gerado.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="08ffef65-e03b-4dbc-b000-f25630a03b42" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-03-21T03:06:09.0000000Z" checksum="54e9df9374f921a2db25c2dc26d225a1" fullyQualifiedName="WorkWithWebRegistroOperacional" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="7031219b-5e46-043c-36ce-7f38a15b9b09" name="WorkWithWebRegistroOperacional" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" description="Work With Web Registro Operacional" parent="RegistroOperacional" parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6">
  <Part type="a51ced48-7bee-0001-ab12-04e9e32123d1">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="1.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<instance webFormDefaults="Responsive Web Design" updateTransaction="Apply WW Style">
  <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-RegistroOperacional" />
  <level id="08ffef65-e03b-4dbc-b000-f25630a03b42:1" name="RegistroOperacional">
    <descriptionAttribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Registro Operacional Id" />
    <selection description="Registros Operacionais" page="&lt;custom&gt;" customRows="20" PagingMode="One page at a time">
      <modes Update="false" Display="false" Export="false" UpdateCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalEmissaoForaDoBaseExemplo" DeleteCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty()" />
      <attributes>
        <variable name="Escondido" domain="00972a17-9975-449e-aab1-d26165d51393-Id"><![CDATA[//&IconeUpdate.FromImage(ActionUpdate)
//&IconeUpdate.link = RegistroOperacional.Link(trnmode.Update, RegistroOperacionalEmpresaId, RegistroOperacionalId)
//&IconeUpdate.TooltipText = "GXM_update"

//isso da erro ao gravar. nao adianta.
//RegistroOperacionalModelo.Caption = dfModeloSigla.convert(RegistroOperacionalModelo)

RegistroOperacionalSituacao.Visible = RegistroOperacionalSituacao <> ExSituacaoRegistro.Autorizado

RegistroOperacionalTipoMovimento.FontSize = 7
RegistroOperacionalModelo.FontSize = 7
RegistroOperacionalAmbiente.Visible = RegistroOperacionalAmbiente <> ExAmbienteRegistro.Producao

RegistroOperacionalTipoMovimento.Visible = not RegistroOperacionalTipoMovimento.IsEmpty() and not RegistroOperacionalTipoMovimento.IsNull()
RegistroOperacionalMovimentoEmpresaId.Visible = not RegistroOperacionalMovimentoEmpresaId.IsEmpty() and not RegistroOperacionalMovimentoEmpresaId.IsNull() and
		RegistroOperacionalMovimentoEmpresaId <> RegistroOperacionalEmpresaId
RegistroOperacionalMovimentoId.Visible = not RegistroOperacionalMovimentoId.IsEmpty() and not RegistroOperacionalMovimentoId.IsNull()
RegistroOperacionalDocumentoId.Visible = not RegistroOperacionalDocumentoId.IsEmpty() and not RegistroOperacionalDocumentoId.IsNull()

RegistroOperacionalTipoOperacao.Visible = RegistroOperacionalTipoMovimento.IsEmpty() or RegistroOperacionalTipoMovimento.IsNull()

//RegistroOperacionalAdicionalDeOutroDF.Visible = RegistroOperacionalAdicionalDeOutroDF

RegistroOperacionalOrigemDadosFiscaisAdicionaisRazao.Visible = RegistroOperacionalOrigemId <> RegistroOperacionalEmpresaPessoaId
RegistroOperacionalDestinoDadosFiscaisAdicionaisRazao.Visible = 
	RegistroOperacionalDestinoId <> RegistroOperacionalEmpresaPessoaId and
	not RegistroOperacionalDestinoDadosFiscaisAdicionaisId.IsEmpty() and
	not RegistroOperacionalDestinoDadosFiscaisAdicionaisId.IsNull()

RegistroOperacionalRemessaOrigemId.Visible = not RegistroOperacionalRemessaOrigemId.IsEmpty() and not RegistroOperacionalRemessaOrigemId.IsNull()
RegistroOperacionalRemessaOrigemRazao.Visible = not RegistroOperacionalRemessaOrigemId.IsEmpty() and not RegistroOperacionalRemessaOrigemId.IsNull()

RegistroOperacionalTransportadoraId.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull()

RegistroOperacionalExpedicaoId.Visible = not RegistroOperacionalExpedicaoId.IsEmpty() and not RegistroOperacionalExpedicaoId.IsNull()

RegistroOperacionalRecebimentoId.Visible = not RegistroOperacionalRecebimentoId.IsEmpty() and not RegistroOperacionalRecebimentoId.IsNull()

RegistroOperacionalControleExternoDoMovimento.Visible = not RegistroOperacionalControleExternoDoMovimento.IsEmpty() and not RegistroOperacionalControleExternoDoMovimento.IsNull()
RegistroOperacionalControleExternoDoDocumento.Visible = not RegistroOperacionalControleExternoDoDocumento.IsEmpty() and not RegistroOperacionalControleExternoDoDocumento.IsNull()
RegistroOperacionalTipoDocumento.Visible = not RegistroOperacionalTipoDocumento.IsEmpty() and not RegistroOperacionalTipoDocumento.IsNull()

RegistroOperacionalData.Visible = RegistroOperacionalData <> RegistroOperacionalEmissao.ToDate()
RegistroOperacionalEmissao.FontBold = true

//RegistroOperacionalDestinoDadosFiscaisAdicionaisNome.Visible = RegistroOperacionalEmissaoDaEmpresa and RegistroOperacionalDestinoDadosFiscaisAdicionaisNome <> RegistroOperacionalDestinoDadosFiscaisAdicionaisRazao

//RegistroOperacionalTransportadoraId.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull()
//RegistroOperacionalTransportadoraRazao.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull()
//RegistroOperacionalTransportadoraNome.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull() and
//								RegistroOperacionalTransportadoraNome <> RegistroOperacionalTransportadoraRazao

//RegistroOperacionalRecursoPlaca.Visible = not RegistroOperacionalRecursoId.IsEmpty() and not RegistroOperacionalRecursoId.IsNull()
//RegistroOperacionalRecursoAuxiliarPlaca.Visible = not RegistroOperacionalRecursoAuxiliarId.IsEmpty() and not RegistroOperacionalRecursoAuxiliarId.IsNull()

//Desliga os campos acima

//RegistroOperacionalItemValorOutrasDespesasAcessorias.Enabled = false

//Esconde actions conforme situação
//&IconeUpdate.Visible = 
//(RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and (RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and (RegistroOperacionalEmissaoDaEmpresa or procUsuarioDaSessaoDaEquipeExemplo())

if &RegistroOperacionalModalidadeDoFrete = ExModalidadeFrete.FretePorContaRemessaOrigemCIF and RegistroOperacionalModalidadeDoFreteFilterContainer.Class = ThemeClass:AdvancedContainerItem

	RegistroOperacionalModalidadeDoFreteFilterContainer.Class = ThemeClass:AdvancedContainerItem + !" " + ThemeClass:AdvancedContainerItemExpanded
	&RegistroOperacionalModalidadeDoFrete.Visible = true

endif]]]]><![CDATA[></variable>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSituacao" description="Situacao" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaId" description="Emp" autolink="True" visible="True" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaIndustriaPrestadoraDeServicosId" description="Ind." autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Id" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoOperacao" description="Ent/Sai" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoMovimento" description="T.Mov." autolink="True" visible="True" themeClass="AttributeQuebraLinha" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoEmpresaId" description="R.E." autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoId" description="Mov." autolink="True" visible="True" themeColumnClass="WWColumn">
          <link webpanel="procViewMovimento">
            <parameters>
              <parameter name="RegistroOperacionalTipoMovimento" />
              <parameter name="RegistroOperacionalMovimentoEmpresaId" />
              <parameter name="RegistroOperacionalMovimentoId" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalControleExternoDoMovimento" description="C.Ext.Mov." autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoDocumentoId" description="Mov. Doc. Id" autolink="True" visible="False" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemExternaMovimento" description="Or.R." autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoDocumento" description="T.Doc." autolink="True" visible="True" themeClass="AttributeQuebraLinha" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDocumentoId" description="Doc." autolink="True" visible="True">
          <link webpanel="procViewDocumento">
            <parameters>
              <parameter name="RegistroOperacionalTipoDocumento" />
              <parameter name="RegistroOperacionalEmpresaId" />
              <parameter name="RegistroOperacionalDocumentoId" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalControleExternoDoDocumento" description="C.Ext.Doc." autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAdicionalDeOutroDF" description="Adic." autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemEmpresaId" description="Origem Empresa Id" autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemId" description="Orig." autolink="True" visible="True" themeColumnClass="WWColumn">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalOrigemEmpresaId" />
              <parameter name="RegistroOperacionalOrigemId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemDadosFiscaisAdicionaisRazao" description="Razao" themeClass="AttributeQuebraLinha" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAmbiente" description="Amb." />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoConsumidor" description="Reg.Tipo Cons." visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalData" description="Movto" autolink="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmissao" description="Emissao" autolink="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSaidaEntrada" description="Saida/Entr." autolink="True" visible="False" />
        <variable name="SaidaEntradaData" description="Saida/Ent" domain="00972a17-9975-449e-aab1-d26165d51393-DataCurta" themeColumnClass="WWColumn"><![CDATA[&SaidaEntradaData = RegistroOperacionalSaidaEntrada.ToDate()]]]]><![CDATA[></variable>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModelo" description="Mod." autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModeloSigla" description="Mod." autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSerie" description="S." autolink="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumero" description="Nr" autolink="True" visible="True" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoDocumento" description="Valor" autolink="True" visible="True" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalChaveDeAcesso" description="Chave" autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoId" description="Dest." autolink="True" visible="True" themeColumnClass="WWColumn">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalDestinoEmpresaId" />
              <parameter name="RegistroOperacionalDestinoId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoDadosFiscaisAdicionaisNome" description=" Nome" autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoDadosFiscaisAdicionaisRazao" description="Razao" themeClass="AttributeQuebraLinha" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalVersaoLeiaute" description="Registro Operacional Versao Leiaute" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCFOP" description="CFOP" autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoEmissao" description="T.Em." autolink="True" visible="False" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTransportadoraId" description="Transp." autolink="True">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalTransportadoraEmpresaId" />
              <parameter name="RegistroOperacionalTransportadoraId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoPlaca" description="Recurso" autolink="True" visible="False">
          <link webpanel="ViewRecurso">
            <parameters>
              <parameter name="RegistroOperacionalRecursoEmpresaId" />
              <parameter name="RegistroOperacionalRecursoId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoAuxiliarPlaca" description="Aux." autolink="True" visible="False">
          <link webpanel="ViewRecurso">
            <parameters>
              <parameter name="RegistroOperacionalRecursoAuxiliarEmpresaId" />
              <parameter name="RegistroOperacionalRecursoAuxiliarId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemId" description="Rem." autolink="True" visible="True" themeColumnClass="WWColumn">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalRemessaOrigemEmpresaId" />
              <parameter name="RegistroOperacionalRemessaOrigemId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemRazao" description="Razao" themeClass="AttributeQuebraLinha" themeColumnClass="WWColumn" />
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalExpedicaoId" description="Expedicao Id" autolink="True" visible="True">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalExpedicaoEmpresaId" />
              <parameter name="RegistroOperacionalExpedicaoId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
        <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecebimentoId" description="Recebimento Id" autolink="True" visible="True">
          <link webpanel="viewEntidade">
            <parameters>
              <parameter name="RegistroOperacionalRecebimentoEmpresaId" />
              <parameter name="RegistroOperacionalRecebimentoId" />
              <parameter name="'General'" />
            </parameters>
          </link>
        </attribute>
      </attributes>
      <orders>
        <order name="Id Desc.">
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaId" description="Registro Operacional Empresa Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Registro Operacional Id" ascending="False" />
        </order>
        <order name="Orig. + Mod. + Serie + Nr.Desc.">
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemEmpresaId" description="Registro Operacional Origem Empresa Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemId" description="Registro Operacional Origem Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModelo" description="Registro Operacional Modelo" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSerie" description="Registro Operacional Serie" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumero" description="Registro Operacional Numero" ascending="False" />
        </order>
        <order name="Data Desc. + Orig. + Mod. + Serie + Nr.Desc.">
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaId" description="Registro Operacional Empresa Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalData" description="Registro Operacional Data Movimento" ascending="False" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemEmpresaId" description="Registro Operacional Origem Empresa Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemId" description="Registro Operacional Origem Id" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModelo" description="Registro Operacional Modelo" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSerie" description="Registro Operacional Serie" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumero" description="Registro Operacional Numero" ascending="False" />
        </order>
      </orders>
      <filter>
        <attributes>
          <filterAttribute name="RegistroOperacionalId" description="Id" default="" />
          <filterAttribute name="RegistroOperacionalNumero" description="Numero" />
          <filterAttribute name="NumeroInicial" description="Numero Inicial" domain="00972a17-9975-449e-aab1-d26165d51393-ExNumeroRegistro" />
          <filterAttribute name="NumeroFinal" description="Numero Final" domain="00972a17-9975-449e-aab1-d26165d51393-ExNumeroRegistro" />
          <filterAttribute name="RegistroOperacionalSerie" description="Série" />
          <filterAttribute name="RegistroOperacionalModelo" description="Modelo" allValue="True" />
          <filterAttribute name="RegistroOperacionalAmbiente" description="Ambiente" default="ExAmbienteRegistro.Producao" allValue="True" />
          <filterAttribute name="RegistroOperacionalSituacao" description="Situacao" allValue="True" />
          <filterAttribute name="RegistroOperacionalChaveDeAcesso" description="Chave de Acesso" />
          <filterAttribute name="DataSaidaEntradaInicial" description="Saida / Entrada Inicial" domain="00972a17-9975-449e-aab1-d26165d51393-Data" default="" />
          <filterAttribute name="DataSaidaEntradaFinal" description="Saida / Entrada Final" domain="00972a17-9975-449e-aab1-d26165d51393-Data" default="" />
          <filterAttribute name="DataMovimentoInicial" description="Movimento Inicial" domain="00972a17-9975-449e-aab1-d26165d51393-Data" default="Today()-2" />
          <filterAttribute name="DataMovimentoFinal" description="Movimento Final" domain="00972a17-9975-449e-aab1-d26165d51393-Data" default="Today()" />
          <filterAttribute name="refRegistroOperacionalChaveDeAcesso" description="Chave de Acesso Referenciada" domain="00972a17-9975-449e-aab1-d26165d51393-ExChaveAcesso" />
          <filterAttribute name="RegistroOperacionalTipoOperacao" description="Tipo Operação" default="ExTipoOperacao.SemFiltro" allValue="False" />
          <filterAttribute name="RegistroOperacionalTipoEmissao" description="Tipo Emissao" allValue="True" />
          <filterAttribute name="RegistroOperacionalFinalidadeEmissaoNFe" description="Finalidade Emissao NFe" allValue="True" />
          <filterAttribute name="RegistroOperacionalTipoMovimento" description="Tipo Movimento" allValue="True" />
          <filterAttribute name="RegistroOperacionalMovimentoId" description="Movimento Id" />
          <filterAttribute name="RegistroOperacionalOrigemExternaMovimento" description="Origem Movimento" />
          <filterAttribute name="RegistroOperacionalTipoDocumento" description="Tipo de Documento" allValue="True" />
          <filterAttribute name="RegistroOperacionalTipoConsumidor" description="D.F. Tipo Consumidor" default="ExTipoConsumidor.SemFiltro" allValue="True" />
          <filterAttribute name="RegistroOperacionalOrigemId" description="Origem Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalOrigemFaturamentoEnderecosMunicipioUfId" description="Origem UF" />
          <filterAttribute name="RegistroOperacionalDestinoId" description="Destinatário Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalDestinoInscricaoFederal" description="Destinatário CPF/CNPJ" />
          <filterAttribute name="RegistroOperacionalDestinoFaturamentoEnderecosMunicipioUfId" description="Destinatário UF" />
          <filterAttribute name="RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoContribuinte" description="Dest. Tipo Contribuinte" allValue="True" />
          <filterAttribute name="DestinoMunicipioDaJurisdicaoDaSuframa" description="Destinatário Município da Jurisdição da Suframa" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RegistroOperacionalTransportadoraId" description="Transportadora Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalRecursoId" description="Veículo Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptRecurso" />
          <filterAttribute name="RegistroOperacionalRecursoAuxiliarId" description="RecursoAuxiliar Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptRecurso" />
          <filterAttribute name="TemReferenciaEmCTe" description="Tem Referência em CTe" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RegistroOperacionalModalidadeDoFrete" description="Modalidade de Transporte" default="ExModalidadeFrete.SemFiltro" allValue="True" />
          <filterAttribute name="TemFrete" description="Tem Valor de Frete" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RegistroOperacionalPapelDoTomadorDoServicoNoCTe" description="Papel do Tomador do CTe" default="dfPapelDoTomadorDoServicoNoCTe.SemFiltro" allValue="True" />
          <filterAttribute name="RegistroOperacionalRemessaOrigemId" description="RemessaOrigem Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalExpedicaoId" description="Expedicao Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalRecebimentoId" description="Recebimento Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptPessoa" />
          <filterAttribute name="RegistroOperacionalPresencaComprador" description="Presença Comprador" default="dfPresencaComprador.Convert(-1)" allValue="False" />
          <filterAttribute name="ValorDoDocumentoMinimo" description="Valor do Documento - Mínimo" domain="00972a17-9975-449e-aab1-d26165d51393-dfValorFinanceiro" />
          <filterAttribute name="ValorDoDocumentoMaximo" description="Valor do Documento - Máximo" domain="00972a17-9975-449e-aab1-d26165d51393-dfValorFinanceiro" />
          <filterAttribute name="RegistroOperacionalStatusCodigo" description="Status Código" domain="00972a17-9975-449e-aab1-d26165d51393-dfStatusCodigo" />
          <filterAttribute name="RegistroOperacionalLoteStatusCodigo" description="Lote Status Código" domain="00972a17-9975-449e-aab1-d26165d51393-dfStatusCodigo" />
          <filterAttribute name="RegistroOperacionalVersaoLeiaute" description="Versão Leiaute" allValue="True" />
          <filterAttribute name="TemMovimento" description="Tem Movimento" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="TemDocumento" description="Tem Documento" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="TemTotalValorDosProdutosEServicos" description="Tem Total Valor dos Produtos e Serviços" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="TemValorProFinanceiro" description="Tem Valor pro Financeiro" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="TemTotalValorDeICMS" description="Tem Total Valor de ICMS" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="ComposicaoDeTitulosBateComTotalLiquidoProFinanceiro" description="Composição de Títulos bate com Total Líq.p/Financeiro" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RetencaoEmTitulosBateComTotalDeRencao" description="Retenção em Títulos bate com Total de Retenção" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RegistroOperacionalCFOP" description="CFOP" />
          <filterAttribute name="RegistroOperacionalNaturezaOperacao" description="Natureza da Operação" />
          <filterAttribute name="DataDeMovimentoDiferenteDaDataDoDocumento" description="Data de Movimento Diferente da Data do Documento" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
          <filterAttribute name="RegistroOperacionalTipoCTe" description="Tipo CTe" />
          <filterAttribute name="InclusaoAlteracaoUsuarioId" description="Inclusão ou Alteração Usuário Id" domain="00972a17-9975-449e-aab1-d26165d51393-Id" prompt="c9584656-94b6-4ccd-890f-332d11fc2c25-promptUsuario" />
          <filterAttribute name="UltimaAlteracaoInicio" description="Incluido ou Alterado Desde" domain="00972a17-9975-449e-aab1-d26165d51393-Data" />
          <filterAttribute name="ComDocumentoDiferenteDoMovimento" description="Com Documento &lt;&gt; do Movimento" domain="00972a17-9975-449e-aab1-d26165d51393-SimOuNao" />
        </attributes>
        <conditions>
          <condition value="RegistroOperacionalEmpresaId = procLeEmpresaSessao()" />
          <condition value="RegistroOperacionalSaidaEntrada &gt;= &amp;DataSaidaEntradaInicial when not &amp;DataSaidaEntradaInicial.IsEmpty()" />
          <condition value="RegistroOperacionalSaidaEntrada &lt; &amp;DataSaidaEntradaFinal.AddDays(1) when not &amp;DataSaidaEntradaFinal.IsEmpty();" />
          <condition value="RegistroOperacionalTipoOperacao = &amp;RegistroOperacionalTipoOperacao when &amp;RegistroOperacionalTipoOperacao &lt;&gt; ExTipoOperacao.SemFiltro" />
          <condition value="RegistroOperacionalTipoEmissao = &amp;RegistroOperacionalTipoEmissao when not &amp;RegistroOperacionalTipoEmissao.IsEmpty()" />
          <condition value="RegistroOperacionalTipoMovimento = &amp;RegistroOperacionalTipoMovimento when not &amp;RegistroOperacionalTipoMovimento.IsEmpty()" />
          <condition value="RegistroOperacionalMovimentoId = &amp;RegistroOperacionalMovimentoId when not &amp;RegistroOperacionalMovimentoId.IsEmpty()" />
          <condition value="RegistroOperacionalOrigemExternaMovimento = &amp;RegistroOperacionalOrigemExternaMovimento when not &amp;RegistroOperacionalOrigemExternaMovimento.IsEmpty()" />
          <condition value="RegistroOperacionalModelo = &amp;RegistroOperacionalModelo when not &amp;RegistroOperacionalModelo.IsEmpty()" />
          <condition value="RegistroOperacionalId = &amp;RegistroOperacionalId when not &amp;RegistroOperacionalId.IsEmpty()" />
          <condition value="RegistroOperacionalNumero = &amp;RegistroOperacionalNumero when not &amp;RegistroOperacionalNumero.IsEmpty()" />
          <condition value="RegistroOperacionalChaveDeAcesso = &amp;RegistroOperacionalChaveDeAcesso when not &amp;RegistroOperacionalChaveDeAcesso.IsEmpty()" />
          <condition value="RegistroOperacionalOrigemId = &amp;RegistroOperacionalOrigemId when not &amp;RegistroOperacionalOrigemId.IsEmpty()" />
          <condition value="RegistroOperacionalDestinoId = &amp;RegistroOperacionalDestinoId when not &amp;RegistroOperacionalDestinoId.IsEmpty()" />
          <condition value="RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoContribuinte = &amp;RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoContribuinte when not &amp;RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoContribuinte.IsEmpty()" />
          <condition value="RegistroOperacionalTransportadoraId = &amp;RegistroOperacionalTransportadoraId when not &amp;RegistroOperacionalTransportadoraId.IsEmpty()" />
          <condition value="RegistroOperacionalRecursoId = &amp;RegistroOperacionalRecursoId when not &amp;RegistroOperacionalRecursoId.IsEmpty()" />
          <condition value="RegistroOperacionalRecursoAuxiliarId = &amp;RegistroOperacionalRecursoAuxiliarId when not &amp;RegistroOperacionalRecursoAuxiliarId.IsEmpty()" />
          <condition value="RegistroOperacionalPresencaComprador = &amp;RegistroOperacionalPresencaComprador when &amp;RegistroOperacionalPresencaComprador &lt;&gt; dfPresencaComprador.SemFiltro" />
          <condition value="RegistroOperacionalTotalValorDoDocumento &gt;= &amp;ValorDoDocumentoMinimo when not &amp;ValorDoDocumentoMinimo.IsEmpty()" />
          <condition value="RegistroOperacionalTotalValorDoDocumento &lt;= &amp;ValorDoDocumentoMaximo when not &amp;ValorDoDocumentoMaximo.IsEmpty()" />
          <condition value="RegistroOperacionalSerie.ToNumeric() = &amp;RegistroOperacionalSerie.ToNumeric() when not &amp;RegistroOperacionalSerie.IsEmpty()" />
          <condition value="RegistroOperacionalAmbiente = &amp;RegistroOperacionalAmbiente when not &amp;RegistroOperacionalAmbiente.IsEmpty()" />
          <condition value="RegistroOperacionalStatusCodigo = &amp;RegistroOperacionalStatusCodigo when not &amp;RegistroOperacionalStatusCodigo.IsEmpty()" />
          <condition value="RegistroOperacionalLoteStatusCodigo = &amp;RegistroOperacionalLoteStatusCodigo when not &amp;RegistroOperacionalLoteStatusCodigo.IsEmpty()" />
          <condition value="RegistroOperacionalSituacao = &amp;RegistroOperacionalSituacao when not &amp;RegistroOperacionalSituacao.IsEmpty() and &amp;RegistroOperacionalSituacao &lt;&gt; ExSituacaoRegistro.Inativado and &amp;RegistroOperacionalSituacao &lt;&gt; ExSituacaoRegistro.Ativo and &amp;RegistroOperacionalSituacao &lt;&gt; ExSituacaoRegistro.FaltaProtocolo;" />
          <condition value="(RegistroOperacionalDenegado = true or RegistroOperacionalNumeroInutilizado = true or RegistroOperacionalCancelado = true) when &amp;RegistroOperacionalSituacao = ExSituacaoRegistro.Inativado" />
          <condition value="RegistroOperacionalSituacao = ExSituacaoRegistro.Autorizado or RegistroOperacionalSituacao = ExSituacaoRegistro.Corrigido when &amp;RegistroOperacionalSituacao = ExSituacaoRegistro.Ativo" />
          <condition value="(RegistroOperacionalAutorizado or RegistroOperacionalDenegado) and (RegistroOperacionalDenegacaoProtocolo.IsEmpty() or RegistroOperacionalDenegacaoProtocolo.IsNull()) and (RegistroOperacionalAutorizacaoProtocolo.IsEmpty() or RegistroOperacionalAutorizacaoProtocolo.IsNull()) when &amp;RegistroOperacionalSituacao = ExSituacaoRegistro.FaltaProtocolo;" />
          <condition value="RegistroOperacionalTipoConsumidor = &amp;RegistroOperacionalTipoConsumidor when &amp;RegistroOperacionalTipoConsumidor &lt;&gt; ExTipoConsumidor.SemFiltro" />
          <condition value="RegistroOperacionalVersaoLeiaute = &amp;RegistroOperacionalVersaoLeiaute when not &amp;RegistroOperacionalVersaoLeiaute.IsEmpty()" />
          <condition value="RegistroOperacionalTipoDocumento = &amp;RegistroOperacionalTipoDocumento when not &amp;RegistroOperacionalTipoDocumento.IsEmpty();" />
          <condition value="RegistroOperacionalModalidadeDoFrete = &amp;RegistroOperacionalModalidadeDoFrete when &amp;RegistroOperacionalModalidadeDoFrete &lt;&gt; ExModalidadeFrete.SemFiltro;" />
          <condition value="RegistroOperacionalTotalValorFrete.IsEmpty() or RegistroOperacionalTotalValorFrete.IsNull() when &amp;TemFrete = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalTotalValorFrete.IsEmpty() and not RegistroOperacionalTotalValorFrete.IsNull() when &amp;TemFrete = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalFinalidadeEmissaoNFe = &amp;RegistroOperacionalFinalidadeEmissaoNFe when not &amp;RegistroOperacionalFinalidadeEmissaoNFe.IsEmpty()" />
          <condition value="RegistroOperacionalDestinoFaturamentoEnderecosMunicipioUfId = &amp;RegistroOperacionalDestinoFaturamentoEnderecosMunicipioUfId when not &amp;RegistroOperacionalDestinoFaturamentoEnderecosMunicipioUfId.IsEmpty()" />
          <condition value="RegistroOperacionalOrigemFaturamentoEnderecosMunicipioUfId = &amp;RegistroOperacionalOrigemFaturamentoEnderecosMunicipioUfId when not &amp;RegistroOperacionalOrigemFaturamentoEnderecosMunicipioUfId.IsEmpty()" />
          <condition value="RegistroOperacionalChavesReferenciadas.IndexOf(&amp;refRegistroOperacionalChaveDeAcesso) &gt; 0 when not &amp;refRegistroOperacionalChaveDeAcesso.IsEmpty();" />
          <condition value="RegistroOperacionalRemessaOrigemId = &amp;RegistroOperacionalRemessaOrigemId when not &amp;RegistroOperacionalRemessaOrigemId.IsEmpty()" />
          <condition value="RegistroOperacionalPapelDoTomadorDoServicoNoCTe = &amp;RegistroOperacionalPapelDoTomadorDoServicoNoCTe when &amp;RegistroOperacionalPapelDoTomadorDoServicoNoCTe &lt;&gt; dfPapelDoTomadorDoServicoNoCTe.SemFiltro;" />
          <condition value="RegistroOperacionalMovimentoId.IsEmpty() or RegistroOperacionalMovimentoId.IsNull() when &amp;TemMovimento = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalMovimentoId.IsEmpty() and not RegistroOperacionalMovimentoId.IsNull() when &amp;TemMovimento = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalDocumentoId.IsEmpty() or RegistroOperacionalDocumentoId.IsNull() when &amp;TemDocumento = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalDocumentoId.IsEmpty() and not RegistroOperacionalDocumentoId.IsNull() when &amp;TemDocumento = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalTotalValorDosProdutosEServicos.IsEmpty() or RegistroOperacionalTotalValorDosProdutosEServicos.IsNull() when &amp;TemTotalValorDosProdutosEServicos = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalTotalValorDosProdutosEServicos.IsEmpty() and not RegistroOperacionalTotalValorDosProdutosEServicos.IsNull() when &amp;TemTotalValorDosProdutosEServicos = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalDestinoFaturamentoEnderecosMunicipioDaSUFRAMA when &amp;DestinoMunicipioDaJurisdicaoDaSuframa = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalDestinoFaturamentoEnderecosMunicipioDaSUFRAMA.IsNull() or RegistroOperacionalDestinoFaturamentoEnderecosMunicipioDaSUFRAMA = false when &amp;DestinoMunicipioDaJurisdicaoDaSuframa = SimOuNao.Nao;" />
          <condition value="RegistroOperacionalTotalValorDoIcms.IsEmpty() or RegistroOperacionalTotalValorDoIcms.IsNull() when &amp;TemTotalValorDeICMS = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalTotalValorDoIcms.IsEmpty() and not RegistroOperacionalTotalValorDoIcms.IsNull() when &amp;TemTotalValorDeICMS = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalExpedicaoId = &amp;RegistroOperacionalExpedicaoId when not &amp;RegistroOperacionalExpedicaoId.IsEmpty();" />
          <condition value="RegistroOperacionalRecebimentoId = &amp;RegistroOperacionalRecebimentoId when not &amp;RegistroOperacionalRecebimentoId.IsEmpty()" />
          <condition value="procRetiraCaracteres(RegistroOperacionalDestinoInscricaoFederal,14,&quot;N&quot;) = procRetiraCaracteres(&amp;RegistroOperacionalDestinoInscricaoFederal,14,&quot;N&quot;) when not &amp;RegistroOperacionalDestinoInscricaoFederal.IsEmpty();" />
          <condition value="procRegistroOperacionalTemReferenciaNoutroDF(RegistroOperacionalChaveDeAcesso, 0, 0, RegistroOperacionalAmbiente, dfModelo.CTe) when &amp;TemReferenciaEmCTe = SimOuNao.Sim;" />
          <condition value="not procRegistroOperacionalTemReferenciaNoutroDF(RegistroOperacionalChaveDeAcesso, 0, 0, RegistroOperacionalAmbiente, dfModelo.CTe) when &amp;TemReferenciaEmCTe = SimOuNao.Nao;" />
          <condition value="procABSValorFinanceiro(procTotalComposicaoDeTitulosDeUmRegistroOperacionalId(RegistroOperacionalEmpresaId, RegistroOperacionalId, 0, true, true) - RegistroOperacionalTotalLiquidoProFinanceiro) &lt;= 0.02 when &amp;ComposicaoDeTitulosBateComTotalLiquidoProFinanceiro = SimOuNao.Sim;" />
          <condition value="procABSValorFinanceiro(procTotalComposicaoDeTitulosDeUmRegistroOperacionalId(RegistroOperacionalEmpresaId, RegistroOperacionalId, 0, true, true) - RegistroOperacionalTotalLiquidoProFinanceiro) &gt; 0.02 when &amp;ComposicaoDeTitulosBateComTotalLiquidoProFinanceiro = SimOuNao.Nao;" />
          <condition value="procABSValorFinanceiro(procTotalRetencaoEmTitulosDeUmRegistroOperacionalId(RegistroOperacionalEmpresaId, RegistroOperacionalId) - RegistroOperacionalTotalRetencao) &lt;= 0.02 when &amp;RetencaoEmTitulosBateComTotalDeRencao = SimOuNao.Sim;" />
          <condition value="procABSValorFinanceiro(procTotalRetencaoEmTitulosDeUmRegistroOperacionalId(RegistroOperacionalEmpresaId, RegistroOperacionalId) - RegistroOperacionalTotalRetencao) &gt; 0.02 when &amp;RetencaoEmTitulosBateComTotalDeRencao = SimOuNao.Nao;" />
          <condition value="RegistroOperacionalCFOP = &amp;RegistroOperacionalCFOP when not &amp;RegistroOperacionalCFOP.IsEmpty()" />
          <condition value="RegistroOperacionalNaturezaOperacao.IndexOf(&amp;RegistroOperacionalNaturezaOperacao) &gt; 0 when not &amp;RegistroOperacionalNaturezaOperacao.IsEmpty();" />
          <condition value="RegistroOperacionalData &gt;= &amp;DataMovimentoInicial when not &amp;DataMovimentoInicial.IsEmpty();" />
          <condition value="RegistroOperacionalData &lt;= &amp;DataMovimentoFinal when not &amp;DataMovimentoFinal.IsEmpty();" />
          <condition value="RegistroOperacionalTotalLiquidoProFinanceiro.IsEmpty() or RegistroOperacionalTotalLiquidoProFinanceiro.IsNull() when &amp;TemValorProFinanceiro = SimOuNao.Nao;" />
          <condition value="not RegistroOperacionalTotalLiquidoProFinanceiro.IsEmpty() and not RegistroOperacionalTotalLiquidoProFinanceiro.IsNull() when &amp;TemValorProFinanceiro = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalData &lt;&gt; RegistroOperacionalDocumentoData when &amp;DataDeMovimentoDiferenteDaDataDoDocumento = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalData = RegistroOperacionalDocumentoData when &amp;DataDeMovimentoDiferenteDaDataDoDocumento = SimOuNao.Nao;" />
          <condition value="RegistroOperacionalTipoCTe = &amp;RegistroOperacionalTipoCTe when &amp;RegistroOperacionalTipoCTe &lt;&gt; dfTipoCTe.SemFiltro;" />
          <condition value="RegistroOperacionalUltimaAtualizacaoDataHora &gt;= &amp;UltimaAlteracaoInicio when not &amp;UltimaAlteracaoInicio.IsEmpty();" />
          <condition value="RegistroOperacionalInclusaoUsuarioId = &amp;InclusaoAlteracaoUsuarioId or RegistroOperacionalUltimaAtualizacaoUsuarioId = &amp;InclusaoAlteracaoUsuarioId when not &amp;InclusaoAlteracaoUsuarioId.IsEmpty();" />
          <condition value="RegistroOperacionalNumero &gt;= &amp;NumeroInicial when not &amp;NumeroInicial.IsEmpty();" />
          <condition value="RegistroOperacionalNumero &lt;= &amp;NumeroFinal when not &amp;NumeroFinal.IsEmpty();" />
          <condition value="RegistroOperacionalDocumentoId &lt;&gt; RegistroOperacionalMovimentoDocumentoId when &amp;ComDocumentoDiferenteDoMovimento = SimOuNao.Sim;" />
          <condition value="RegistroOperacionalDocumentoId = RegistroOperacionalMovimentoDocumentoId when &amp;ComDocumentoDiferenteDoMovimento = SimOuNao.Nao;" />
        </conditions>
      </filter>
      <actions>
        <action name="GeraPdfDeRegistroOperacional" caption="Gera Pdf de RegistroOperacional" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="True" image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-relatorio_26x20" tooltip="Gera Documento Auxiliar do DFe">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="RegistroOperacionalEmpresaId" />
            <parameter name="RegistroOperacionalId" />
            <parameter name="ProcessamentoDFe.GeraPdfDFe" />
            <parameter name="0" />
          </parameters>
        </action>
        <action name="LimpaGridState" caption="#" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procLimpaGridState" tooltip="Limpa Filtros na Sessão">
          <parameters>
            <parameter name="&quot;WWRegistroOperacional&quot;" />
          </parameters>
        </action>
        <action name="PlanilhaRegistroOperacionalBaixar" caption="Baixar Xls" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPlanilhaRegistroOperacional" tooltip="Baixar Planilha">
          <parameters>
            <parameter name="false" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalId" />
            <parameter name="&amp;RegistroOperacionalNumero" />
            <parameter name="&amp;RegistroOperacionalSerie" />
            <parameter name="&amp;RegistroOperacionalModelo" />
            <parameter name="&amp;RegistroOperacionalAmbiente" />
            <parameter name="&amp;RegistroOperacionalSituacao" />
            <parameter name="&amp;RegistroOperacionalChaveDeAcesso" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;refRegistroOperacionalChaveDeAcesso" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoEmissao" />
            <parameter name="&amp;RegistroOperacionalFinalidadeEmissaoNFe" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="&amp;RegistroOperacionalMovimentoId" />
            <parameter name="&amp;RegistroOperacionalOrigemExternaMovimento" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
            <parameter name="&amp;RegistroOperacionalTipoConsumidor" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;RegistroOperacionalOrigemFaturamentoEnderecosMunicipioUfId" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalDestinoFaturamentoEnderecosMunicipioUfId" />
            <parameter name="&amp;RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoContribuinte" />
            <parameter name="&amp;RegistroOperacionalTransportadoraId" />
            <parameter name="&amp;RegistroOperacionalRecursoId" />
            <parameter name="&amp;RegistroOperacionalRecursoAuxiliarId" />
            <parameter name="&amp;RegistroOperacionalPresencaComprador" />
            <parameter name="&amp;ValorDoDocumentoMinimo" />
            <parameter name="&amp;ValorDoDocumentoMaximo" />
            <parameter name="&amp;RegistroOperacionalStatusCodigo" />
            <parameter name="&amp;RegistroOperacionalLoteStatusCodigo" />
            <parameter name="&amp;RegistroOperacionalVersaoLeiaute" />
            <parameter name="&amp;RegistroOperacionalModalidadeDoFrete" />
            <parameter name="&amp;TemFrete" />
            <parameter name="&amp;DataMovimentoInicial" />
            <parameter name="&amp;DataMovimentoFinal" />
            <parameter name="&amp;RegistroOperacionalDestinoInscricaoFederal" />
            <parameter name="&amp;TemReferenciaEmCTe" />
            <parameter name="&amp;RegistroOperacionalPapelDoTomadorDoServicoNoCTe" />
            <parameter name="&amp;RegistroOperacionalRemessaOrigemId" />
            <parameter name="&amp;RegistroOperacionalExpedicaoId" />
            <parameter name="&amp;RegistroOperacionalRecebimentoId" />
            <parameter name="&amp;TemMovimento" />
            <parameter name="&amp;TemDocumento" />
            <parameter name="&amp;TemTotalValorDosProdutosEServicos" />
            <parameter name="&amp;DestinoMunicipioDaJurisdicaoDaSuframa" />
            <parameter name="&amp;TemTotalValorDeICMS" />
            <parameter name="&amp;ComposicaoDeTitulosBateComTotalLiquidoProFinanceiro" />
            <parameter name="&amp;RetencaoEmTitulosBateComTotalDeRencao" />
            <parameter name="&amp;RegistroOperacionalCFOP" />
            <parameter name="&amp;RegistroOperacionalNaturezaOperacao" />
            <parameter name="&amp;InclusaoAlteracaoUsuarioId" />
            <parameter name="&amp;UltimaAlteracaoInicio" />
            <parameter name="&amp;NumeroInicial" />
            <parameter name="&amp;NumeroFinal" />
            <parameter name="&amp;OrderedBy" />
          </parameters>
        </action>
        <action name="StatusServicoNFeDaEmpresa" caption="Status Serviço NFe" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procMostraStatusServicoDFeDaEmpresa" tooltip="Status do Serviço NFe da Empresa">
          <parameters>
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="ExAmbienteRegistro.Producao" />
            <parameter name="dfModelo.NFe" />
            <parameter name="dfTipoEmissao.Normal" />
          </parameters>
        </action>
        <action name="DadosCertificadoDaEmpresa" caption="Certificado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procMostraDadosDoCertificadoDaEmpresa" tooltip="Dados do Certificado da Empresa">
          <parameters>
            <parameter name="procLeEmpresaSessao()" />
          </parameters>
        </action>
        <action name="ArquivosRegistroDenegadosDFEs" caption="Arquivos Denegados" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDeDFEs" tooltip="Zipa Arquivos de Registro de Denegação de Varios DFEs - Conforme faixa de datas e destinatário (opcional) ">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="ProcessamentoDFe.DownloadProtocoloRegistro" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="000" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
          </parameters>
        </action>
        <action name="ArquivosDistribuicaoDeVariosDFEs" caption="Arquivos Distribuição" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDeDFEs" tooltip="Zipa Arquivos de Distribuição de Varios DFEs - Conforme faixa de datas e destinatário (opcional) ">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="ProcessamentoDFe.DownloadXmlDistribuicao" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="000" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
          </parameters>
        </action>
        <action name="ArquivosEventoCancelamentoDeVariosDFEs" caption="Arquivos Evento Cancelamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDeDFEs" tooltip="Zipa Arquivos de Evento de Cancelamento de Varios DFEs - Conforme faixa de datas e destinatário (opcional) ">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="ProcessamentoDFe.DownloadEventoCancelamento" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="000" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
          </parameters>
        </action>
        <action name="ArquivosEventoCorrecaoDeVariosDFEs" caption="Arquivos Evento Correcao" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDeDFEs" tooltip="Zipa Arquivos de Evento de Correcao de Varios DFEs - Conforme faixa de datas e destinatário (opcional) ">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="ProcessamentoDFe.DownloadEventoCorrecao" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="000" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
          </parameters>
        </action>
        <action name="ArquivosInutilizacaoDeVariosDFEs" caption="Arquivos Inutilização" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDeDFEs" tooltip="Zipa Arquivos de Inutilização de Varios DFEs - Conforme faixa de datas e destinatário (opcional) ">
          <parameters>
            <parameter name="&quot;&quot;" />
            <parameter name="procLeEmpresaSessao()" />
            <parameter name="&amp;RegistroOperacionalDestinoId" />
            <parameter name="&amp;RegistroOperacionalOrigemId" />
            <parameter name="&amp;DataSaidaEntradaInicial" />
            <parameter name="&amp;DataSaidaEntradaFinal" />
            <parameter name="&amp;RegistroOperacionalTipoOperacao" />
            <parameter name="&amp;RegistroOperacionalTipoMovimento" />
            <parameter name="ProcessamentoDFe.DownloadInutilizacao" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="000" />
            <parameter name="&amp;RegistroOperacionalTipoDocumento" />
          </parameters>
        </action>
        <action name="FinalizaFaturamento" caption="Finaliza Faturamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procDisplayUrlSemPaginaEmbutida" tooltip="Finalização do Faturamento de uma data, Tipo de Movimento, Movimento Id, Tipo de Operação e Destinatário Id" condition="(not &amp;DataSaidaEntradaInicial.IsEmpty() and not &amp;DataSaidaEntradaFinal.IsEmpty()) or (not &amp;DataMovimentoInicial.IsEmpty() and not &amp;DataMovimentoFinal.IsEmpty()) or (not &amp;RegistroOperacionalModelo.IsEmpty() and not &amp;RegistroOperacionalSerie.IsEmpty() and &amp;NumeroInicial &gt; 0 and &amp;NumeroFinal &gt; 0)" buttonClass="">
          <parameters>
            <parameter name="wpFaturamentoFinalizacao.Link(procLeEmpresaSessao(), &amp;DataMovimentoInicial, &amp;DataMovimentoFinal, &amp;RegistroOperacionalTipoMovimento, &amp;RegistroOperacionalMovimentoId, &amp;RegistroOperacionalTipoOperacao, &amp;RegistroOperacionalDestinoId, &amp;DataSaidaEntradaInicial, &amp;DataSaidaEntradaFinal, &amp;RegistroOperacionalModelo, &amp;RegistroOperacionalSerie, &amp;NumeroInicial, &amp;NumeroFinal, &amp;RegistroOperacionalCFOP, &amp;RegistroOperacionalAmbiente, &amp;PgmName, &quot;&quot;)" />
            <parameter name="0" />
            <parameter name="00" />
            <parameter name="true" />
            <parameter name="(true)" />
            <parameter name="&quot;&quot;" />
          </parameters>
        </action>
      </actions>
    </selection>
    <view caption="RegistroOperacionalId.ToString()" description="Registro Operacional" backToSelection="True" masterPage="&lt;default&gt;">
      <parameters>
        <parameter name="RegistroOperacionalEmpresaId" null="True" />
        <parameter name="RegistroOperacionalId" null="True" />
      </parameters>
      <fixedData>
        <attributes>
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Id" autolink="True" visible="True" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumero" description="Núm." autolink="True" visible="True" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemId" description="Orig." autolink="True" visible="True" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoId" description="Dest." autolink="True" visible="True" />
          <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNaturezaOperacao" description="Nat.Op." />
        </attributes>
      </fixedData>
      <tabs>
        <tab name="Geral" code="General" description="Registro Operacional Info" type="Tabular" wcname="RegistroOperacionalGeneral">
          <attributes>
            <variable name="Escondido" domain="00972a17-9975-449e-aab1-d26165d51393-Id"><![CDATA[RegistroOperacionalEmissaoDaEmpresa.Visible = RegistroOperacionalEmissaoDaEmpresa
RegistroOperacionalEmissaoForaDoBaseExemplo.Visible = RegistroOperacionalEmissaoForaDoBaseExemplo
if RegistroOperacionalEmissaoForaDoBaseExemplo
	RegistroOperacionalEmissaoForaDoBaseExemplo.Caption = "Emissao fora do " + procNomeSistemaBaseExemploOuAlternativo()
endif

RegistroOperacionalTipoMovimento.Visible = not RegistroOperacionalTipoMovimento.IsEmpty() and not RegistroOperacionalTipoMovimento.IsNull()
RegistroOperacionalMovimentoEmpresaId.Visible = not RegistroOperacionalMovimentoEmpresaId.IsEmpty() and not RegistroOperacionalMovimentoEmpresaId.IsNull() and
		RegistroOperacionalMovimentoEmpresaId <> RegistroOperacionalEmpresaId
RegistroOperacionalMovimentoId.Visible = not RegistroOperacionalMovimentoId.IsEmpty() and not RegistroOperacionalMovimentoId.IsNull()
////RegistroOperacionalMovimentoPessoaId.Visible = not RegistroOperacionalMovimentoPessoaId.IsEmpty() and not RegistroOperacionalMovimentoPessoaId.IsNull() and RegistroOperacionalMovimentoPessoaId <> RegistroOperacionalDestinoId
////RegistroOperacionalMovimentoDocumentoId.Visible = not RegistroOperacionalMovimentoDocumentoId.IsEmpty() and not RegistroOperacionalMovimentoDocumentoId.IsNull() and RegistroOperacionalMovimentoDocumentoId <> RegistroOperacionalDocumentoId
//RegistroOperacionalMovimentoData.Visible = not RegistroOperacionalMovimentoId.IsEmpty() and not RegistroOperacionalMovimentoId.IsNull() and RegistroOperacionalMovimentoData <> RegistroOperacionalData
////RegistroOperacionalMovimentoTransportadoraId.Visible = not RegistroOperacionalMovimentoTransportadoraId.IsEmpty() and not RegistroOperacionalMovimentoTransportadoraId.IsNull()
////RegistroOperacionalMovimentoRecursoId.Visible = not RegistroOperacionalMovimentoRecursoId.IsEmpty() and not RegistroOperacionalMovimentoRecursoId.IsNull()
////RegistroOperacionalMovimentoRecursoAuxiliarId.Visible = not RegistroOperacionalMovimentoRecursoAuxiliarId.IsEmpty() and not RegistroOperacionalMovimentoRecursoAuxiliarId.IsNull()
RegistroOperacionalMovimentoSemValoresParaFinanceiro.Visible = RegistroOperacionalMovimentoSemValoresParaFinanceiro

RegistroOperacionalDocumentoId.Visible = not RegistroOperacionalDocumentoId.IsEmpty() and not RegistroOperacionalDocumentoId.IsNull()

RegistroOperacionalAdicionalDeOutroDF.Visible = RegistroOperacionalAdicionalDeOutroDF
RegistroOperacionalOrigemExternaMovimento.Visible = not RegistroOperacionalOrigemExternaMovimento.IsEmpty() and not RegistroOperacionalOrigemExternaMovimento.IsNull()

RegistroOperacionalOrigemRazao.Visible = RegistroOperacionalOrigemId <> RegistroOperacionalEmpresaPessoaId

RegistroOperacionalChaveDeDados.Visible = not RegistroOperacionalChaveDeDados.IsEmpty() and not RegistroOperacionalChaveDeDados.IsNull()

RegistroOperacionalRemessaOrigemId.Visible = not RegistroOperacionalRemessaOrigemId.IsEmpty() and not RegistroOperacionalRemessaOrigemId.IsNull()
RegistroOperacionalRemessaOrigemRazao.Visible = not RegistroOperacionalRemessaOrigemId.IsEmpty() and not RegistroOperacionalRemessaOrigemId.IsNull()
RegistroOperacionalRemessaOrigemDadosFiscaisAdicionaisId.Visible = not RegistroOperacionalRemessaOrigemDadosFiscaisAdicionaisId.IsEmpty() and not RegistroOperacionalRemessaOrigemDadosFiscaisAdicionaisId.IsNull()
RegistroOperacionalRemessaOrigemFaturamentoEnderecosId.Visible = not RegistroOperacionalRemessaOrigemFaturamentoEnderecosId.IsEmpty() and not RegistroOperacionalRemessaOrigemFaturamentoEnderecosId.IsNull()
RegistroOperacionalRemessaOrigemTelefonesId.Visible = not RegistroOperacionalRemessaOrigemTelefonesId.IsEmpty() and not RegistroOperacionalRemessaOrigemTelefonesId.IsNull()
RegistroOperacionalRemessaOrigemE_MailsId.Visible = not RegistroOperacionalRemessaOrigemE_MailsId.IsEmpty() and not RegistroOperacionalRemessaOrigemE_MailsId.IsNull()

RegistroOperacionalDestinoRazao.Visible = RegistroOperacionalDestinoId <> RegistroOperacionalEmpresaPessoaId
RegistroOperacionalDestinoNome.Visible = RegistroOperacionalDestinoId <> RegistroOperacionalEmpresaPessoaId and RegistroOperacionalDestinoNome <> RegistroOperacionalDestinoRazao

RegistroOperacionalComissionadoId.Visible = not RegistroOperacionalComissionadoId.IsEmpty() and not RegistroOperacionalComissionadoId.IsNull()
RegistroOperacionalComissionadoNome.Visible = not RegistroOperacionalComissionadoId.IsEmpty() and not RegistroOperacionalComissionadoId.IsNull()

RegistroOperacionalCFOP.Visible = not RegistroOperacionalCFOP.IsEmpty() and not RegistroOperacionalCFOP.IsNull()
//RegistroOperacionalNaturezaOperacao.Visible = not RegistroOperacionalNaturezaOperacao.IsEmpty() and not RegistroOperacionalNaturezaOperacao.IsNull()

RegistroOperacionalFormaDePagamento.Visible = RegistroOperacionalFormaDePagamento <> dfFormaDePagamento.SemFiltro
RegistroOperacionalFormatoImpressao.Visible = RegistroOperacionalFormatoImpressao <> dfFormatoImpressao.NormalRetrato
RegistroOperacionalFinalidadeEmissaoNFe.Visible = not RegistroOperacionalFinalidadeEmissaoNFe.IsEmpty() and not RegistroOperacionalFinalidadeEmissaoNFe.IsNull() and
								RegistroOperacionalFinalidadeEmissaoNFe <> dfFinalidadeEmissaoNFe.Normal

RegistroOperacionalTipoNotaDeDebito.Visible = not RegistroOperacionalTipoNotaDeDebito.IsEmpty() and not RegistroOperacionalTipoNotaDeDebito.IsNull()
RegistroOperacionalTipoNotaDeCredito.Visible = not RegistroOperacionalTipoNotaDeCredito.IsEmpty() and not RegistroOperacionalTipoNotaDeCredito.IsNull()

RegistroOperacionalTipoCTe.Visible = RegistroOperacionalTipoCTe <> dfTipoCTe.SemFiltro and RegistroOperacionalTipoCTe <> dfTipoCTe.Normal
RegistroOperacionalPapelDoTomadorDoServicoNoCTe.Visible = not RegistroOperacionalPapelDoTomadorDoServicoNoCTe.IsEmpty() and not RegistroOperacionalPapelDoTomadorDoServicoNoCTe.IsNull()
RegistroOperacionalInscricaoFederalDoTomadorDoServicoNoCTe.Visible = not RegistroOperacionalInscricaoFederalDoTomadorDoServicoNoCTe.IsEmpty() and not RegistroOperacionalInscricaoFederalDoTomadorDoServicoNoCTe.IsNull()
RegistroOperacionalInscricaoEstadualDoTomadorDoServicoNoCTe.Visible = not RegistroOperacionalInscricaoEstadualDoTomadorDoServicoNoCTe.IsEmpty() and not RegistroOperacionalInscricaoEstadualDoTomadorDoServicoNoCTe.IsNull()

RegistroOperacionalPrevisaoEntregaDisponibilizacao.Visible = not RegistroOperacionalPrevisaoEntregaDisponibilizacao.IsEmpty() and not RegistroOperacionalPrevisaoEntregaDisponibilizacao.IsNull()

RegistroOperacionalPercentualReducaoDeAliquotaEmCompraGovernamental.Visible = not RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoEnteGovernamental.IsEmpty() and not RegistroOperacionalDestinoDadosFiscaisAdicionaisTipoEnteGovernamental.IsNull()
	
RegistroOperacionalTipoDeOperacaoComEnteGovernamental.Visible =	not RegistroOperacionalTipoDeOperacaoComEnteGovernamental.IsEmpty() and not RegistroOperacionalTipoDeOperacaoComEnteGovernamental.IsNull()

RegistroOperacionalEntradaContingencia.Visible = not RegistroOperacionalEntradaContingencia.IsEmpty() and not RegistroOperacionalEntradaContingencia.IsNull()
RegistroOperacionalJustificativaContingencia.Visible = not RegistroOperacionalJustificativaContingencia.IsEmpty() and not RegistroOperacionalJustificativaContingencia.IsNull()

RegistroOperacionalSaidaEntrada.Visible = RegistroOperacionalSaidaEntrada <> RegistroOperacionalEmissao

RegistroOperacionalTransportadoraId.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull()
RegistroOperacionalTransportadoraRazao.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull()
RegistroOperacionalTransportadoraNome.Visible = not RegistroOperacionalTransportadoraId.IsEmpty() and not RegistroOperacionalTransportadoraId.IsNull() and
								RegistroOperacionalTransportadoraNome <> RegistroOperacionalTransportadoraRazao

RegistroOperacionalRecursoPlaca.Visible = not RegistroOperacionalRecursoId.IsEmpty() and not RegistroOperacionalRecursoId.IsNull()
RegistroOperacionalRecursoAuxiliarPlaca.Visible = not RegistroOperacionalRecursoAuxiliarId.IsEmpty() and not RegistroOperacionalRecursoAuxiliarId.IsNull()

RegistroOperacionalDescontoGeralPercentual.Visible = not RegistroOperacionalDescontoGeralPercentual.IsEmpty() and not RegistroOperacionalDescontoGeralPercentual.IsNull()
RegistroOperacionalDescontoGeralEmValor.Visible = not RegistroOperacionalDescontoGeralEmValor.IsEmpty() and not RegistroOperacionalDescontoGeralEmValor.IsNull()
RegistroOperacionalTotalValorFrete.Visible = not RegistroOperacionalTotalValorFrete.IsEmpty() and not RegistroOperacionalTotalValorFrete.IsNull()

RegistroOperacionalTotalBaseDeCalculoDoIcms.Visible = not RegistroOperacionalTotalBaseDeCalculoDoIcms.IsEmpty() and not RegistroOperacionalTotalBaseDeCalculoDoIcms.IsNull()
RegistroOperacionalTotalValorDoIcms.Visible = not RegistroOperacionalTotalValorDoIcms.IsEmpty() and not RegistroOperacionalTotalValorDoIcms.IsNull()
RegistroOperacionalTotalValorDoIcmsDesonerado.Visible = not RegistroOperacionalTotalValorDoIcmsDesonerado.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsDesonerado.IsNull()
RegistroOperacionalTotalBaseDeCalculoDoIcmsST.Visible = not RegistroOperacionalTotalBaseDeCalculoDoIcmsST.IsEmpty() and not RegistroOperacionalTotalBaseDeCalculoDoIcmsST.IsNull()
RegistroOperacionalTotalValorDoIcmsST.Visible = not RegistroOperacionalTotalValorDoIcmsST.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsST.IsNull()
RegistroOperacionalTotalValorDoIcmsFCP.Visible = not RegistroOperacionalTotalValorDoIcmsFCP.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsFCP.IsNull()
RegistroOperacionalTotalValorDoIcmsFCPST.Visible = not RegistroOperacionalTotalValorDoIcmsFCPST.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsFCPST.IsNull()
RegistroOperacionalTotalValorIcmsUfDestFCP.Visible = not RegistroOperacionalTotalValorIcmsUfDestFCP.IsEmpty() and not RegistroOperacionalTotalValorIcmsUfDestFCP.IsNull()
RegistroOperacionalTotalValorIcmsUfDestPartilha.Visible = not RegistroOperacionalTotalValorIcmsUfDestPartilha.IsEmpty() and not RegistroOperacionalTotalValorIcmsUfDestPartilha.IsNull()

RegistroOperacionalTotalValorDosProdutosEServicos.Visible = not RegistroOperacionalTotalValorDosProdutosEServicos.IsEmpty() and not RegistroOperacionalTotalValorDosProdutosEServicos.IsNull()
RegistroOperacionalTotalBrutoProFinanceiro.Visible = not RegistroOperacionalTotalBrutoProFinanceiro.IsEmpty() and not RegistroOperacionalTotalBrutoProFinanceiro.IsNull()
RegistroOperacionalTotalValorSeguro.Visible = not RegistroOperacionalTotalValorSeguro.IsEmpty() and not RegistroOperacionalTotalValorSeguro.IsNull()
RegistroOperacionalTotalDesconto.Visible = not RegistroOperacionalTotalDesconto.IsEmpty() and not RegistroOperacionalTotalDesconto.IsNull()
RegistroOperacionalTotalValorII.Visible = not RegistroOperacionalTotalValorII.IsEmpty() and not RegistroOperacionalTotalValorII.IsNull()
RegistroOperacionalTotalValorIPI.Visible = not RegistroOperacionalTotalValorIPI.IsEmpty() and not RegistroOperacionalTotalValorIPI.IsNull()
RegistroOperacionalTotalValorPIS.Visible = not RegistroOperacionalTotalValorPIS.IsEmpty() and not RegistroOperacionalTotalValorPIS.IsNull()
RegistroOperacionalTotalValorCOFINS.Visible = not RegistroOperacionalTotalValorCOFINS.IsEmpty() and not RegistroOperacionalTotalValorCOFINS.IsNull()

RegistroOperacionalTotalValorIS.Visible = not RegistroOperacionalTotalValorIS.IsEmpty() and not RegistroOperacionalTotalValorIS.IsNull()
RegistroOperacionalTotalValorBaseDeCalculoDeIBSeCBS.Visible = not RegistroOperacionalTotalValorBaseDeCalculoDeIBSeCBS.IsEmpty() and not RegistroOperacionalTotalValorBaseDeCalculoDeIBSeCBS.IsNull()
RegistroOperacionalTotalValorIBSUfDif.Visible = not RegistroOperacionalTotalValorIBSUfDif.IsEmpty() and not RegistroOperacionalTotalValorIBSUfDif.IsNull()
RegistroOperacionalTotalValorIBSUfDevTrib.Visible = not RegistroOperacionalTotalValorIBSUfDevTrib.IsEmpty() and not RegistroOperacionalTotalValorIBSUfDevTrib.IsNull()
RegistroOperacionalTotalValorIBSUf.Visible = not RegistroOperacionalTotalValorIBSUf.IsEmpty() and not RegistroOperacionalTotalValorIBSUf.IsNull()
RegistroOperacionalTotalValorIBSMunDif.Visible = not RegistroOperacionalTotalValorIBSMunDif.IsEmpty() and not RegistroOperacionalTotalValorIBSMunDif.IsNull()
RegistroOperacionalTotalValorIBSMunDevTrib.Visible = not RegistroOperacionalTotalValorIBSMunDevTrib.IsEmpty() and not RegistroOperacionalTotalValorIBSMunDevTrib.IsNull()
RegistroOperacionalTotalValorIBSMun.Visible = not RegistroOperacionalTotalValorIBSMun.IsEmpty() and not RegistroOperacionalTotalValorIBSMun.IsNull()
RegistroOperacionalTotalValorIBS.Visible = not RegistroOperacionalTotalValorIBS.IsEmpty() and not RegistroOperacionalTotalValorIBS.IsNull()
RegistroOperacionalTotalValorIBSCredPres.Visible = not RegistroOperacionalTotalValorIBSCredPres.IsEmpty() and not RegistroOperacionalTotalValorIBSCredPres.IsNull()
RegistroOperacionalTotalValorIBSCredPresCondSus.Visible = not RegistroOperacionalTotalValorIBSCredPresCondSus.IsEmpty() and not RegistroOperacionalTotalValorIBSCredPresCondSus.IsNull()
RegistroOperacionalTotalValorCBSDif.Visible = not RegistroOperacionalTotalValorCBSDif.IsEmpty() and not RegistroOperacionalTotalValorCBSDif.IsNull()
RegistroOperacionalTotalValorCBSDevTrib.Visible = not RegistroOperacionalTotalValorCBSDevTrib.IsEmpty() and not RegistroOperacionalTotalValorCBSDevTrib.IsNull()
RegistroOperacionalTotalValorCBS.Visible = not RegistroOperacionalTotalValorCBS.IsEmpty() and not RegistroOperacionalTotalValorCBS.IsNull()
RegistroOperacionalTotalValorCBSCredPres.Visible = not RegistroOperacionalTotalValorCBSCredPres.IsEmpty() and not RegistroOperacionalTotalValorCBSCredPres.IsNull()
RegistroOperacionalTotalValorCBSCredPresCondSus.Visible = not RegistroOperacionalTotalValorCBSCredPresCondSus.IsEmpty() and not RegistroOperacionalTotalValorCBSCredPresCondSus.IsNull()
RegistroOperacionalTotalValorIBSMono.Visible = not RegistroOperacionalTotalValorIBSMono.IsEmpty() and not RegistroOperacionalTotalValorIBSMono.IsNull()
RegistroOperacionalTotalValorCBSMono.Visible = not RegistroOperacionalTotalValorCBSMono.IsEmpty() and not RegistroOperacionalTotalValorCBSMono.IsNull()
RegistroOperacionalTotalValorIBSMonoReten.Visible = not RegistroOperacionalTotalValorIBSMonoReten.IsEmpty() and not RegistroOperacionalTotalValorIBSMonoReten.IsNull()
RegistroOperacionalTotalValorCBSMonoReten.Visible = not RegistroOperacionalTotalValorCBSMonoReten.IsEmpty() and not RegistroOperacionalTotalValorCBSMonoReten.IsNull()
RegistroOperacionalTotalValorIBSMonoRet.Visible = not RegistroOperacionalTotalValorIBSMonoRet.IsEmpty() and not RegistroOperacionalTotalValorIBSMonoRet.IsNull()
RegistroOperacionalTotalValorCBSMonoRet.Visible = not RegistroOperacionalTotalValorCBSMonoRet.IsEmpty() and not RegistroOperacionalTotalValorCBSMonoRet.IsNull()
RegistroOperacionalTotalValorIBSEstCred.Visible = not RegistroOperacionalTotalValorIBSEstCred.IsEmpty() and not RegistroOperacionalTotalValorIBSEstCred.IsNull()
RegistroOperacionalTotalValorCBSEstCred.Visible = not RegistroOperacionalTotalValorCBSEstCred.IsEmpty() and not RegistroOperacionalTotalValorCBSEstCred.IsNull()
RegistroOperacionalTotalValorDoDocumentoComIbsCbsIs.Visible = not RegistroOperacionalTotalValorDoDocumentoComIbsCbsIs.IsEmpty() and not RegistroOperacionalTotalValorDoDocumentoComIbsCbsIs.IsNull()

RegistroOperacionalTotalOutrasDespesasAcessorias.Visible = not RegistroOperacionalTotalOutrasDespesasAcessorias.IsEmpty() and not RegistroOperacionalTotalOutrasDespesasAcessorias.IsNull()

RegistroOperacionalTotalBaseDeCalculoDoIcmsMono.Visible = not RegistroOperacionalTotalBaseDeCalculoDoIcmsMono.IsEmpty() and not RegistroOperacionalTotalBaseDeCalculoDoIcmsMono.IsNull()
RegistroOperacionalTotalValorDoIcmsMono.Visible = not RegistroOperacionalTotalValorDoIcmsMono.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsMono.IsNull()
RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoRet.Visible = not RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoRet.IsEmpty() and not RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoRet.IsNull()
RegistroOperacionalTotalValorDoIcmsMonoRet.Visible = not RegistroOperacionalTotalValorDoIcmsMonoRet.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsMonoRet.IsNull()
RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoReten.Visible = not RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoReten.IsEmpty() and not RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoReten.IsNull()
RegistroOperacionalTotalValorDoIcmsMonoReten.Visible = not RegistroOperacionalTotalValorDoIcmsMonoReten.IsEmpty() and not RegistroOperacionalTotalValorDoIcmsMonoReten.IsNull()

RegistroOperacionalTotalValorDoDocumento.Visible = not RegistroOperacionalTotalValorDoDocumento.IsEmpty() and not RegistroOperacionalTotalValorDoDocumento.IsNull()

RegistroOperacionalTotalValorFreteCompondoFinanceiro.Visible = not RegistroOperacionalTotalValorFreteCompondoFinanceiro.IsEmpty() and not RegistroOperacionalTotalValorFreteCompondoFinanceiro.IsNull()
RegistroOperacionalTotalValorFreteNaoCompondoFinanceiro.Visible = not RegistroOperacionalTotalValorFreteNaoCompondoFinanceiro.IsEmpty() and not RegistroOperacionalTotalValorFreteNaoCompondoFinanceiro.IsNull()
RegistroOperacionalTotalLiquidoProFinanceiro.Visible = not RegistroOperacionalTotalLiquidoProFinanceiro.IsEmpty() and not RegistroOperacionalTotalLiquidoProFinanceiro.IsNull()

RegistroOperacionalTotalValorAproximadoDeTributos.Visible = not RegistroOperacionalTotalValorAproximadoDeTributos.IsEmpty() and not RegistroOperacionalTotalValorAproximadoDeTributos.IsNull()
RegistroOperacionalRetencaoPercentual.Visible = not RegistroOperacionalRetencaoPercentual.IsEmpty() and not RegistroOperacionalRetencaoPercentual.IsNull()
RegistroOperacionalTotalRetencao.Visible = not RegistroOperacionalTotalRetencao.IsEmpty() and not RegistroOperacionalTotalRetencao.IsNull()

RegistroOperacionalInformacoesAdicionaisDeInteresseDoFisco.Visible = not RegistroOperacionalInformacoesAdicionaisDeInteresseDoFisco.IsEmpty() and not RegistroOperacionalInformacoesAdicionaisDeInteresseDoFisco.IsNull()
RegistroOperacionalInformacoesComplementaresDeInteresseContribuinte.Visible = not RegistroOperacionalInformacoesComplementaresDeInteresseContribuinte.IsEmpty() and not RegistroOperacionalInformacoesComplementaresDeInteresseContribuinte.IsNull()

RegistroOperacionalContingenciaHomologada.Visible = RegistroOperacionalContingenciaHomologada
RegistroOperacionalContingenciaProtocolo.Visible = not RegistroOperacionalContingenciaProtocolo.IsEmpty() and not RegistroOperacionalContingenciaProtocolo.IsNull()
	
RegistroOperacionalLoteEnvio.Visible = not RegistroOperacionalLoteEnvio.IsEmpty() and not RegistroOperacionalLoteEnvio.IsNull()
RegistroOperacionalLoteStatusCodigo.Visible = not RegistroOperacionalLoteStatusCodigo.IsEmpty() and not RegistroOperacionalLoteStatusCodigo.IsNull()
RegistroOperacionalReciboLote.Visible = not RegistroOperacionalReciboLote.IsEmpty() and not RegistroOperacionalReciboLote.IsNull()

RegistroOperacionalStatusCodigo.Visible = not RegistroOperacionalStatusCodigo.IsEmpty() and not RegistroOperacionalStatusCodigo.IsNull()
RegistroOperacionalAutorizado.Visible = RegistroOperacionalAutorizado
RegistroOperacionalAutorizacaoProtocolo.Visible = not RegistroOperacionalAutorizacaoProtocolo.IsEmpty() and not RegistroOperacionalAutorizacaoProtocolo.IsNull()

RegistroOperacionalDenegado.Visible = RegistroOperacionalDenegado
RegistroOperacionalDenegacaoProtocolo.Visible = not RegistroOperacionalDenegacaoProtocolo.IsEmpty() and not RegistroOperacionalDenegacaoProtocolo.IsNull()

RegistroOperacionalCancelamentoJustificativa.Visible = not RegistroOperacionalCancelamentoJustificativa.IsEmpty() and not RegistroOperacionalCancelamentoJustificativa.IsNull()
RegistroOperacionalCancelado.Visible = RegistroOperacionalCancelado
RegistroOperacionalCancelamentoProtocolo.Visible = not RegistroOperacionalCancelamentoProtocolo.IsEmpty() and not RegistroOperacionalCancelamentoProtocolo.IsNull()

RegistroOperacionalCorrecaoTexto.Visible = not RegistroOperacionalCorrecaoTexto.IsEmpty() and not RegistroOperacionalCorrecaoTexto.IsNull()
RegistroOperacionalCorrecaoProtocolo.Visible = not RegistroOperacionalCorrecaoProtocolo.IsEmpty() and not RegistroOperacionalCorrecaoProtocolo.IsNull()
RegistroOperacionalCorrigido.Visible = RegistroOperacionalCorrigido
RegistroOperacionalCorrecaoSequencia.Visible = not RegistroOperacionalCorrecaoSequencia.IsEmpty() and not RegistroOperacionalCorrecaoSequencia.IsNull()

RegistroOperacionalManifestacaoDesconhecimentoJustificativa.Visible = not RegistroOperacionalManifestacaoDesconhecimentoJustificativa.IsEmpty() and not RegistroOperacionalManifestacaoDesconhecimentoJustificativa.IsNull()
RegistroOperacionalManifestacaoDesconhecimentoSequencia.Visible = not RegistroOperacionalManifestacaoDesconhecimentoSequencia.IsEmpty() and not RegistroOperacionalManifestacaoDesconhecimentoSequencia.IsNull()
RegistroOperacionalManifestacaoDesconhecimentoProtocolo.Visible = not RegistroOperacionalManifestacaoDesconhecimentoProtocolo.IsEmpty() and not RegistroOperacionalManifestacaoDesconhecimentoProtocolo.IsNull()
RegistroOperacionalManifestadoDesconhecimento.Visible = RegistroOperacionalManifestadoDesconhecimento

RegistroOperacionalInutilizacaoDeNumeroJustificativa.Visible = not RegistroOperacionalInutilizacaoDeNumeroJustificativa.IsEmpty() and not RegistroOperacionalInutilizacaoDeNumeroJustificativa.IsNull()
RegistroOperacionalNumeroInutilizado.Visible = RegistroOperacionalNumeroInutilizado
RegistroOperacionalInutilizacaoDeNumeroProtocolo.Visible = not RegistroOperacionalInutilizacaoDeNumeroProtocolo.IsEmpty() and not RegistroOperacionalInutilizacaoDeNumeroProtocolo.IsNull()

RegistroOperacionalInativado.Visible = RegistroOperacionalInativado
RegistroOperacionalObservacao.Visible = not RegistroOperacionalObservacao.IsEmpty() and not RegistroOperacionalObservacao.IsNull()

RegistroOperacionalTotalPecas.Visible = not RegistroOperacionalTotalPecas.IsEmpty() and not RegistroOperacionalTotalPecas.IsNull()
RegistroOperacionalTotalVolumes.Visible = not RegistroOperacionalTotalVolumes.IsEmpty() and not RegistroOperacionalTotalVolumes.IsNull()
RegistroOperacionalTotalPesoLiquido.Visible = not RegistroOperacionalTotalPesoLiquido.IsEmpty() and not RegistroOperacionalTotalPesoLiquido.IsNull()
RegistroOperacionalTotalTara.Visible = not RegistroOperacionalTotalTara.IsEmpty() and not RegistroOperacionalTotalTara.IsNull()
RegistroOperacionalTotalPesoBruto.Visible = not RegistroOperacionalTotalPesoBruto.IsEmpty() and not RegistroOperacionalTotalPesoBruto.IsNull()

RegistroOperacionalEspecieDosVolumes.Visible = not RegistroOperacionalEspecieDosVolumes.IsEmpty() and not RegistroOperacionalEspecieDosVolumes.IsNull()
RegistroOperacionalChavesReferenciadas.Visible = not RegistroOperacionalChavesReferenciadas.IsEmpty() and not RegistroOperacionalChavesReferenciadas.IsNull()

RegistroOperacionalChavesReferenciadasDeAntecipacaoDePagto.Visible = not RegistroOperacionalChavesReferenciadasDeAntecipacaoDePagto.IsEmpty() and not RegistroOperacionalChavesReferenciadasDeAntecipacaoDePagto.IsNull()

RegistroOperacionalIntermediadorId.Visible = not RegistroOperacionalIntermediadorId.IsEmpty() and not RegistroOperacionalIntermediadorId.IsNull()
RegistroOperacionalIntermediadorRazao.Visible = not RegistroOperacionalIntermediadorId.IsEmpty() and not RegistroOperacionalIntermediadorId.IsNull()
RegistroOperacionalIntermediadorNome.Visible = not RegistroOperacionalIntermediadorId.IsEmpty() and not RegistroOperacionalIntermediadorId.IsNull() and
								RegistroOperacionalIntermediadorNome <> RegistroOperacionalIntermediadorNome

RegistroOperacionalDocumentoAuxiliarGerado.Visible = RegistroOperacionalDocumentoAuxiliarGerado

RegistroOperacionalExpedicaoId.Visible = not RegistroOperacionalExpedicaoId.IsEmpty() and not RegistroOperacionalExpedicaoId.IsNull()

RegistroOperacionalRecebimentoId.Visible = not RegistroOperacionalRecebimentoId.IsEmpty() and not RegistroOperacionalRecebimentoId.IsNull()

RegistroOperacionalControleExternoDoMovimento.Visible = not RegistroOperacionalControleExternoDoMovimento.IsEmpty() and not RegistroOperacionalControleExternoDoMovimento.IsNull()
RegistroOperacionalControleExternoDoDocumento.Visible = not RegistroOperacionalControleExternoDoDocumento.IsEmpty() and not RegistroOperacionalControleExternoDoDocumento.IsNull()
RegistroOperacionalTipoDocumento.Visible = not RegistroOperacionalTipoDocumento.IsEmpty() and not RegistroOperacionalTipoDocumento.IsNull()

RegistroOperacionalDestinoOperacao.Visible = not RegistroOperacionalDestinoOperacao.IsEmpty() and not RegistroOperacionalDestinoOperacao.IsNull()
RegistroOperacionalTipoConsumidor.Visible = RegistroOperacionalTipoConsumidor <> ExTipoConsumidor.SemFiltro
RegistroOperacionalPresencaComprador.Visible = RegistroOperacionalPresencaComprador <> dfPresencaComprador.SemFiltro
RegistroOperacionalModalidadeDoFrete.Visible = RegistroOperacionalModalidadeDoFrete <> ExModalidadeFrete.SemFiltro 

RegistroOperacionalSiglaDaUFdeSaidaDoPais.Visible = not RegistroOperacionalSiglaDaUFdeSaidaDoPais.IsEmpty() and not RegistroOperacionalSiglaDaUFdeSaidaDoPais.IsNull()
RegistroOperacionalLocalDeSaidaDoPais.Visible = not RegistroOperacionalLocalDeSaidaDoPais.IsEmpty() and not RegistroOperacionalLocalDeSaidaDoPais.IsNull()
RegistroOperacionalLocalDeDespachoAduaneiroNaSaidaDoPais.Visible = not RegistroOperacionalLocalDeDespachoAduaneiroNaSaidaDoPais.IsEmpty() and not RegistroOperacionalLocalDeDespachoAduaneiroNaSaidaDoPais.IsNull()

//Desliga os campos que ficam editaveis indevidamente
RegistroOperacionalEmissaoDaEmpresa.Enabled = false
RegistroOperacionalEmissaoForaDoBaseExemplo.Enabled = false

RegistroOperacionalTipoMovimento.Enabled = false
RegistroOperacionalMovimentoEmpresaId.Enabled = false
RegistroOperacionalMovimentoId.Enabled = false
RegistroOperacionalMovimentoSemValoresParaFinanceiro.Enabled = false

RegistroOperacionalDocumentoId.Enabled = false
RegistroOperacionalAdicionalDeOutroDF.Enabled = false
RegistroOperacionalOrigemExternaMovimento.Enabled = false

RegistroOperacionalOrigemRazao.Enabled = false
RegistroOperacionalFormaDePagamento.Enabled = false

RegistroOperacionalChaveDeDados.Enabled = false

RegistroOperacionalRemessaOrigemId.Enabled = false
RegistroOperacionalRemessaOrigemRazao.Enabled = false
RegistroOperacionalRemessaOrigemDadosFiscaisAdicionaisId.Enabled = false
RegistroOperacionalRemessaOrigemFaturamentoEnderecosId.Enabled = false
RegistroOperacionalRemessaOrigemTelefonesId.Enabled = false
RegistroOperacionalRemessaOrigemE_MailsId.Enabled = false

RegistroOperacionalDestinoRazao.Enabled = false
RegistroOperacionalDestinoNome.Enabled = false

RegistroOperacionalComissionadoId.Enabled = false
RegistroOperacionalComissionadoNome.Enabled = false

RegistroOperacionalCFOP.Enabled = false

RegistroOperacionalFormaDePagamento.Enabled = false
RegistroOperacionalFormatoImpressao.Enabled = false
RegistroOperacionalFinalidadeEmissaoNFe.Enabled = false

RegistroOperacionalTipoCTe.Enabled = false
RegistroOperacionalPapelDoTomadorDoServicoNoCTe.Enabled = false
RegistroOperacionalInscricaoFederalDoTomadorDoServicoNoCTe.Enabled = false
RegistroOperacionalInscricaoEstadualDoTomadorDoServicoNoCTe.Enabled = false

RegistroOperacionalEntradaContingencia.Enabled = false
RegistroOperacionalJustificativaContingencia.Enabled = false

RegistroOperacionalSaidaEntrada.Enabled = false

RegistroOperacionalTransportadoraId.Enabled = false
RegistroOperacionalTransportadoraRazao.Enabled = false
RegistroOperacionalTransportadoraNome.Enabled = false

RegistroOperacionalRecursoPlaca.Enabled = false
RegistroOperacionalRecursoAuxiliarPlaca.Enabled = false

RegistroOperacionalDescontoGeralPercentual.Enabled = false
RegistroOperacionalDescontoGeralEmValor.Enabled = false
RegistroOperacionalTotalValorFrete.Enabled = false

RegistroOperacionalTotalBaseDeCalculoDoIcms.Enabled = false
RegistroOperacionalTotalValorDoIcms.Enabled = false
RegistroOperacionalTotalValorDoIcmsDesonerado.Enabled = false
RegistroOperacionalTotalBaseDeCalculoDoIcmsST.Enabled = false
RegistroOperacionalTotalValorDoIcmsST.Enabled = false
RegistroOperacionalTotalValorDoIcmsFCP.Enabled = false
RegistroOperacionalTotalValorDoIcmsFCPST.Enabled = false
RegistroOperacionalTotalValorIcmsUfDestFCP.Enabled = false
RegistroOperacionalTotalValorIcmsUfDestPartilha.Enabled = false

RegistroOperacionalTotalValorDosProdutosEServicos.Enabled = false
RegistroOperacionalTotalBrutoProFinanceiro.Enabled = false
RegistroOperacionalTotalValorSeguro.Enabled = false
RegistroOperacionalTotalDesconto.Enabled = false
RegistroOperacionalTotalValorII.Enabled = false
RegistroOperacionalTotalValorIPI.Enabled = false
RegistroOperacionalTotalValorPIS.Enabled = false
RegistroOperacionalTotalValorCOFINS.Enabled = false
RegistroOperacionalTotalOutrasDespesasAcessorias.Enabled = false

RegistroOperacionalTotalValorDoDocumento.Enabled = false

RegistroOperacionalTotalValorFreteCompondoFinanceiro.Enabled = false
RegistroOperacionalTotalValorFreteNaoCompondoFinanceiro.Enabled = false
RegistroOperacionalTotalLiquidoProFinanceiro.Enabled = false

RegistroOperacionalTotalValorAproximadoDeTributos.Enabled = false
RegistroOperacionalRetencaoPercentual.Enabled = false
RegistroOperacionalTotalRetencao.Enabled = false

RegistroOperacionalInformacoesAdicionaisDeInteresseDoFisco.Enabled = false
RegistroOperacionalInformacoesComplementaresDeInteresseContribuinte.Enabled = false

RegistroOperacionalContingenciaHomologada.Enabled = false
RegistroOperacionalContingenciaProtocolo.Enabled = false
	
RegistroOperacionalLoteEnvio.Enabled = false
RegistroOperacionalLoteStatusCodigo.Enabled = false
RegistroOperacionalReciboLote.Enabled = false

RegistroOperacionalStatusCodigo.Enabled = false
RegistroOperacionalAutorizado.Enabled = false
RegistroOperacionalAutorizacaoProtocolo.Enabled = false

RegistroOperacionalDenegado.Enabled = false
RegistroOperacionalDenegacaoProtocolo.Enabled = false

RegistroOperacionalCancelamentoJustificativa.Enabled = false
RegistroOperacionalCancelado.Enabled = false
RegistroOperacionalCancelamentoProtocolo.Enabled = false

RegistroOperacionalCorrecaoTexto.Enabled = false
RegistroOperacionalCorrecaoProtocolo.Enabled = false
RegistroOperacionalCorrigido.Enabled = false
RegistroOperacionalCorrecaoSequencia.Enabled = false

RegistroOperacionalManifestacaoDesconhecimentoJustificativa.Enabled = false
RegistroOperacionalManifestacaoDesconhecimentoSequencia.Enabled = false
RegistroOperacionalManifestacaoDesconhecimentoProtocolo.Enabled = false
RegistroOperacionalManifestadoDesconhecimento.Enabled = false

RegistroOperacionalInutilizacaoDeNumeroJustificativa.Enabled = false
RegistroOperacionalNumeroInutilizado.Enabled = false
RegistroOperacionalInutilizacaoDeNumeroProtocolo.Enabled = false

RegistroOperacionalInativado.Enabled = false
RegistroOperacionalObservacao.Enabled = false

RegistroOperacionalTotalPecas.Enabled = false
RegistroOperacionalTotalVolumes.Enabled = false
RegistroOperacionalTotalPesoLiquido.Enabled = false
RegistroOperacionalTotalTara.Enabled = false
RegistroOperacionalTotalPesoBruto.Enabled = false

RegistroOperacionalEspecieDosVolumes.Enabled = false
RegistroOperacionalChavesReferenciadas.Enabled = false

RegistroOperacionalIntermediadorId.Enabled = false
RegistroOperacionalIntermediadorRazao.Enabled = false
RegistroOperacionalIntermediadorNome.Enabled = false

RegistroOperacionalDocumentoAuxiliarGerado.Enabled = false

RegistroOperacionalExpedicaoId.Enabled = false

RegistroOperacionalRecebimentoId.Enabled = false

RegistroOperacionalControleExternoDoMovimento.Enabled = false
RegistroOperacionalControleExternoDoDocumento.Enabled = false
RegistroOperacionalTipoDocumento.Enabled = false

RegistroOperacionalDestinoOperacao.Enabled = false
RegistroOperacionalTipoConsumidor.Enabled = false
RegistroOperacionalPresencaComprador.Enabled = false
RegistroOperacionalModalidadeDoFrete.Enabled = false

RegistroOperacionalSiglaDaUFdeSaidaDoPais.Enabled = false
RegistroOperacionalLocalDeSaidaDoPais.Enabled = false
RegistroOperacionalLocalDeDespachoAduaneiroNaSaidaDoPais.Enabled = false

//Esconde actions conforme situação

//ve se desliga botoes de delet e update
if 	(	(not RegistroOperacionalXmlAssinadoArquivoId.IsEmpty()    and not RegistroOperacionalXmlAssinadoArquivoId.IsNull()   ) or
		(not RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull())
	) and not RegistroOperacionalEmissaoForaDoBaseExemplo

	//if not (RegistroOperacionalEmissaoForaDoBaseExemplo and procUsuarioDaSessaoDaEquipeExemplo())
	
	//if not procUsuarioDaSessaoDaEquipeExemplo()
	
		BtnUpdate.Visible = false
		
	//endif

	BtnDelete.Visible = false
	
	//BtnUpdate.Visible = (RegistroOperacionalMovimentoId.IsEmpty() or RegistroOperacionalMovimentoId.IsNull()) and 
	//	not RegistroOperacionalDocumentoId.IsEmpty() and not RegistroOperacionalDocumentoId.IsNull() and procUsuarioDaSessaoDaEquipeExemplo()
	
Endif 

//ve se desliga botao de envio de email
If not RegistroOperacionalEmissaoDaEmpresa

	BtnEnviaEmailDeRegistroOperacional.Visible = False

Endif 

BtnSituacaoDFe.Caption = "SITUAÇÃO " + RegistroOperacionalModeloSigla.EnumerationDescription()
BtnSituacaoLoteDFe.Caption = "SITUAÇÃO LOTE " + RegistroOperacionalModeloSigla.EnumerationDescription()

//BtnGeraDFeAdicional.Caption = "Gera " + RegistroOperacionalModeloSigla.EnumerationDescription() + " Adicional"
//BtnGeraDFeComplementar.Caption = "Gera " + RegistroOperacionalModeloSigla.EnumerationDescription() + " Complementar"
//BtnGeraDFeDeDevolucaoSemMovimento.Caption = "Gera " + RegistroOperacionalModeloSigla.EnumerationDescription() + " de Devolução Sem Movimento"
//BtnGeraDFeNormalSemMovimento.Caption = "Gera " + RegistroOperacionalModeloSigla.EnumerationDescription() + " Normal Sem Movimento"

//ve se desliga botao de envio de email e de geracacao de pdf do docto auxiliar
if (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and
	(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and
	(RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() or RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull())

	BtnGeraPdfDeRegistroOperacional.Visible = false
	BtnEnviaEmailDeRegistroOperacional.Visible = False
	
else

	Do Case
		Case RegistroOperacionalModelo = dfModelo.NFe
		
			BtnGeraPdfDeRegistroOperacional.Caption = "DANFE"
		
		Case RegistroOperacionalModelo = dfModelo.NFCe
		
			BtnGeraPdfDeRegistroOperacional.Caption = "DANFCE"

		Case RegistroOperacionalModelo = dfModelo.CTe
		
			BtnGeraPdfDeRegistroOperacional.Caption = "DACTE"
			
	Endcase
	
endif

//ve se desliga botao
if not RegistroOperacionalEmissaoDaEmpresa or RegistroOperacionalModelo = dfModelo.NFCe or
	(RegistroOperacionalSituacao <> ExSituacaoRegistro.Autorizado and RegistroOperacionalSituacao <> ExSituacaoRegistro.Corrigido) or 
	not (RegistroOperacionalTipoEmissao <> dfTipoEmissao.ContingenciaSVCRS and RegistroOperacionalTipoEmissao <> dfTipoEmissao.ContingenciaSVCAN)

	BtnCriaEnviaEventoCorrecaoDeRegistroOperacional.Visible = False
		
Endif

//ve se desliga botoes
If RegistroOperacionalEmissaoForaDoBaseExemplo or RegistroOperacionalInativado
	
	BtnAtualizaTotais.Visible = False
	
	BtnApagaArquivoXmlNaoAssinado.Visible = False
	
	BtnApagaArquivoXmlAssinado.Visible = False

	BtnApagaArquivoXmlDistribuicao.Visible = False

	BtnApagaArquivoXmlInutilizacao.Visible = False

	BtnApagaArquivoXmlProtocolo.Visible = False

	BtnApagaArquivoXmlEventoCancelamento.Visible = False

	BtnApagaArquivoXmlEventoCorrecao.Visible = False
	

	BtnGeraXmlDeRegistroOperacional.Visible = False

	BtnCriaEnviaLoteDeRegistroOperacional.Visible = False

	BtnCriaEnviaInutilizacaoDeNumero.Visible = False

	BtnCriaEnviaEventoEPECdeRegistroOperacional.Visible = False

	BtnCriaEnviaEventoCancelamentoDeRegistroOperacional.Visible = False

	BtnGeraDFeAdicional.Visible = False
	
	//ja tem la embaixo
	//if RegistroOperacionalInativado
	//
	//	BtnGeraDFeDeDevolucaoSemMovimento.Visible = False
	//	BtnGeraDFeNormalSemMovimento.Visible = False
	//
	//endif
	
	BtnSituacaoLoteDFe.Visible = False

	//ImpressaoBoletosDosTitulosDoRegistroOperacional.Visible = False
	
	if not RegistroOperacionalEmissaoDaEmpresa or RegistroOperacionalInativado

		BtnGeraDFeComplementar.Visible = False
	
	endif
	
else

	if procUsuarioDaSessaoDaEquipeExemplo()
	
		BtnApagaArquivoXmlDistribuicao.Visible = not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() and not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull()
		BtnApagaArquivoXmlInutilizacao.Visible = not RegistroOperacionalInutilizacaoArquivoId.IsEmpty() and not RegistroOperacionalInutilizacaoArquivoId.IsNull()
		BtnApagaArquivoXmlProtocolo.Visible = not RegistroOperacionalProtocoloDeRegistroArquivoId.IsEmpty() and not RegistroOperacionalProtocoloDeRegistroArquivoId.IsNull()
		BtnApagaArquivoXmlEventoCancelamento.Visible = not RegistroOperacionalEventoDeCancelamentoArquivoId.IsEmpty() and not RegistroOperacionalEventoDeCancelamentoArquivoId.IsNull()
		BtnApagaArquivoXmlEventoCorrecao.Visible = not RegistroOperacionalEventoDeCorrecaoArquivoId.IsEmpty() and not RegistroOperacionalEventoDeCorrecaoArquivoId.IsNull()

	else

		BtnApagaArquivoXmlDistribuicao.Visible = False
		BtnApagaArquivoXmlInutilizacao.Visible = False
		BtnApagaArquivoXmlProtocolo.Visible = False
		BtnApagaArquivoXmlEventoCancelamento.Visible = False
		BtnApagaArquivoXmlEventoCorrecao.Visible = False
	
	endif
	
	if RegistroOperacionalSituacao <> ExSituacaoRegistro.Autorizado and RegistroOperacionalSituacao <> ExSituacaoRegistro.Corrigido
	
		BtnCriaEnviaEventoCancelamentoDeRegistroOperacional.Visible = False
		
		BtnApagaArquivoXmlNaoAssinado.Visible = 	not RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and 
									not RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull() and
									not RegistroOperacionalContingenciaHomologada
		
		BtnApagaArquivoXmlAssinado.Visible = not RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlAssinadoArquivoId.IsNull()
		
	else
			
		BtnApagaArquivoXmlNaoAssinado.Visible = False
	
		BtnApagaArquivoXmlAssinado.Visible = False
	
		//BtnCriaEnviaLoteDeRegistroOperacional.Visible = False
		
	endif
	
	if RegistroOperacionalSituacao = ExSituacaoRegistro.Autorizado or RegistroOperacionalSituacao = ExSituacaoRegistro.Corrigido or 
		(RegistroOperacionalLoteStatusCodigo = 104 and RegistroOperacionalStatusCodigo <> 217)
	
		BtnCriaEnviaLoteDeRegistroOperacional.Visible = False

	endif
	
	if (not RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlAssinadoArquivoId.IsNull()) or
		(not RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull())
	
		BtnAtualizaTotais.Visible = False
		BtnGeraXmlDeRegistroOperacional.Visible = False
		BtnCriaEnviaInutilizacaoDeNumero.Visible = False

	else
	
		BtnCriaEnviaLoteDeRegistroOperacional.Visible = False
	
	endif

	if RegistroOperacionalAdicionalDeOutroDF or RegistroOperacionalDocumentoDFAdicionalPessoaId.IsEmpty() or RegistroOperacionalDocumentoDFAdicionalPessoaId.IsNull()
	
		BtnGeraDFeAdicional.Visible = False
		
	endif
	
	if RegistroOperacionalFinalidadeEmissaoNFe <> dfFinalidadeEmissaoNFe.Normal
	
		BtnGeraDFeAdicional.Visible = False
		BtnGeraDFeComplementar.Visible = False
		BtnGeraDFeDeDevolucaoSemMovimento.Visible = False
		
	endif
	
	if RegistroOperacionalFinalidadeEmissaoNFe <> dfFinalidadeEmissaoNFe.Devolucao
	
		BtnGeraDFeNormalSemMovimento.Visible = False
		
	endif
	
	BtnCriaEnviaEventoEPECdeRegistroOperacional.Visible = RegistroOperacionalTipoEmissao = dfTipoEmissao.ContingenciaEPEC and not RegistroOperacionalContingenciaHomologada
	
	BtnSituacaoLoteDFe.Visible = not RegistroOperacionalReciboLote.IsEmpty() and not RegistroOperacionalReciboLote.IsNull()
	
Endif

if RegistroOperacionalModelo <> dfModelo.NFe or (RegistroOperacionalSituacao <> ExSituacaoRegistro.Autorizado and RegistroOperacionalSituacao <> ExSituacaoRegistro.Corrigido)

	BtnGeraDFeAdicional.Visible = False
	BtnGeraDFeDeDevolucaoSemMovimento.Visible = False
	BtnGeraDFeNormalSemMovimento.Visible = False
	BtnGeraDFeComplementar.Visible = False

endif

if (RegistroOperacionalEmissaoDaEmpresa and not RegistroOperacionalEmissaoForaDoBaseExemplo) or
	RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() or RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull()

	BtnReprocessaArquivoXmlDeDistribuicao.Visible = false

endif

BtnDownloadArquivoXmlNaoAssinado.Visible = not RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()
BtnDownloadArquivoXmlAssinado.Visible = not RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlAssinadoArquivoId.IsNull()
BtnMostraArquivoXmlAssinado.Visible = not RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and not RegistroOperacionalXmlAssinadoArquivoId.IsNull()
BtnDownloadEventoEPEC.Visible = not RegistroOperacionalEPECArquivoId.IsEmpty() and not RegistroOperacionalEPECArquivoId.IsNull()
BtnDownloadArquivoProtocoloRegistro.Visible = not RegistroOperacionalProtocoloDeRegistroArquivoId.IsEmpty() and not RegistroOperacionalProtocoloDeRegistroArquivoId.IsNull()
BtnDownloadRetornoDeCancelamento.Visible = not RegistroOperacionalRetornoDeCancelamentoArquivoId.IsEmpty() and not RegistroOperacionalRetornoDeCancelamentoArquivoId.IsNull()
BtnDownloadEventoDeCancelamento.Visible = not RegistroOperacionalEventoDeCancelamentoArquivoId.IsEmpty() and not RegistroOperacionalEventoDeCancelamentoArquivoId.IsNull()
BtnDownloadEventoDeCorrecao.Visible = not RegistroOperacionalEventoDeCorrecaoArquivoId.IsEmpty() and not RegistroOperacionalEventoDeCorrecaoArquivoId.IsNull()
BtnDownloadArquivoXmlDeDistribuicao.Visible = not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() and not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull()
BtnMostraArquivoXmlDeDistribuicao.Visible = not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() and not RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull()
BtnDownloadArquivoInutilizacao.Visible = not RegistroOperacionalInutilizacaoArquivoId.IsEmpty() and not RegistroOperacionalInutilizacaoArquivoId.IsNull()
]]]]><![CDATA[></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaId" description="Emp." autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmissaoDaEmpresa" description="Emissao da Empresa" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmissaoForaDoBaseExemplo" description="Emissao Fora do Sistema" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Registro Operacional Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSituacao" description="Situacao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoMovimento" description="Tipo Movimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoMovimento" description="Tipo Movimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoEmpresaId" description="Movimento Empresa Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoId" description="Movimento Id" autolink="True" visible="True">
              <link webpanel="procViewMovimento">
                <parameters>
                  <parameter name="RegistroOperacionalTipoMovimento" />
                  <parameter name="RegistroOperacionalMovimentoEmpresaId" />
                  <parameter name="RegistroOperacionalMovimentoId" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalControleExternoDoMovimento" description="Controle Externo do Movimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalMovimentoSemValoresParaFinanceiro" description="Movimento Sem Valores Para Financeiro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoDocumento" description="Tipo Documento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDocumentoId" description="Documento Id" autolink="True" visible="True">
              <link webpanel="procViewDocumento">
                <parameters>
                  <parameter name="RegistroOperacionalTipoDocumento" />
                  <parameter name="RegistroOperacionalEmpresaId" />
                  <parameter name="RegistroOperacionalDocumentoId" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalControleExternoDoDocumento" description="Controle Externo do Documento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAdicionalDeOutroDF" description="Adicional de Outro DF" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemExternaMovimento" description="Origem Mov." autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemId" description="Origem Id" autolink="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalOrigemEmpresaId" />
                  <parameter name="RegistroOperacionalOrigemId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemNome" description="Origem Nome" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalOrigemRazao" description="Origem Razao" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalData" description="Data Movimento" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModelo" description="Modelo" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModeloSigla" description="Modelo Sigla" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSerie" description="Série" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumero" description="Numero" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalChaveDeAcesso" description="Chave" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalChaveDeDados" description="Chave de Dados" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoId" description="Destinatário Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalDestinoEmpresaId" />
                  <parameter name="RegistroOperacionalDestinoId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoNome" description="Destino Nome" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoRazao" description="Destino Razao" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalComissionadoId" description="Comissionado Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalComissionadoEmpresaId" />
                  <parameter name="RegistroOperacionalComissionadoId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalComissionadoNome" description="Nome" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalVersaoLeiaute" description="Versão Leiaute" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCodigoUFdoOrigem" description="Codigo UF do Origem" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoOperacao" description="Tipo Operação" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDestinoOperacao" description="Destino Operação" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCFOP" description="CFOP" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNaturezaOperacao" description="Natureza Operação" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalFormaDePagamento" description="Forma de Pagamento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalFormatoImpressao" description="Formato Impressao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoEmissao" description="Tipo Emissao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAmbiente" description="Ambiente" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalFinalidadeEmissaoNFe" description="Finalidade Emissao NFe" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoNotaDeDebito" description="Tipo de Nota de Débito" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoNotaDeCredito" description="Tipo de Nota de Crédito" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoCTe" description="Tipo CTe" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalPapelDoTomadorDoServicoNoCTe" description="Papel do Tomador do Serviço no CTe" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInscricaoFederalDoTomadorDoServicoNoCTe" description="CNPJ/CPF do Tomador do Serviço no CTe" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInscricaoEstadualDoTomadorDoServicoNoCTe" description="IE do Tomador do Serviço no CTe" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoConsumidor" description="Tipo Consumidor" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalPresencaComprador" description="Presença Comprador" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalProcessoEmissao" description="Processo Emissao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalVersaoProcessoEmissao" description="Versão do Processo de Emissao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalPercentualReducaoDeAliquotaEmCompraGovernamental" description="% Red. Alíq. Em Compra Governamental" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTipoDeOperacaoComEnteGovernamental" description="Tipo de Operaçãoo com Ente Governamental" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmissao" description="Emissao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSaidaEntrada" description="Saída/Entrada" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEntradaContingencia" description="Entrada Contingência" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalJustificativaContingencia" description="Justificativa Contingência" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalPrevisaoEntregaDisponibilizacao" description="Previsão de Entrega/Disponibilização" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalModalidadeDoFrete" description="Modalidade do Transporte" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTransportadoraId" description="Transportadora Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalTransportadoraEmpresaId" />
                  <parameter name="RegistroOperacionalTransportadoraId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTransportadoraNome" description="Transportadora Nome" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTransportadoraRazao" description="Transportadora Razao" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTransportadoraDadosFiscaisAdicionaisPessoaEmpId" description="Transportadora D.F.A.P.Emp.Id" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoPlaca" description="Veículo Placa" autolink="True" visible="True">
              <link webpanel="ViewRecurso">
                <parameters>
                  <parameter name="RegistroOperacionalRecursoEmpresaId" />
                  <parameter name="RegistroOperacionalRecursoId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoForaDeUso" description="Fora de Uso" autolink="True" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoAuxiliarPlaca" description="RecursoAuxiliar Placa" autolink="True" visible="True">
              <link webpanel="ViewRecurso">
                <parameters>
                  <parameter name="RegistroOperacionalRecursoAuxiliarEmpresaId" />
                  <parameter name="RegistroOperacionalRecursoAuxiliarId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecursoAuxiliarForaDeUso" description="Fora de Uso" autolink="True" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDescontoGeralPercentual" description="Desconto Geral %" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDescontoGeralEmValor" description="Desconto Geral Em Valor" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBaseDeCalculoDoIcms" description="Total Base de Cálculo do ICMS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcms" description="Total Valor do Icms" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsDesonerado" description="Total Valor do Icms Desonerado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBaseDeCalculoDoIcmsST" description="Total Base de Cálculo do Icms ST" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsST" description="Total Valor do Icms ST" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsFCP" description="Valor do Icms FCP" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsFCPST" description="Valor do Icms FCP ST" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIcmsUfDestFCP" description="Total Valor Icms UF Dest FCP" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIcmsUfDestPartilha" description="Total Valor Icms UF Dest Partilha" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBaseDeCalculoDoIcmsMono" description="Total Base de Cálculo do Icms Mono" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsMono" description="Total Valor do Icms Mono" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoReten" description="Total Base de Cálculo do Icms Suj Reten" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsMonoReten" description="Total Valor do Icms Mono Suj Reten" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBaseDeCalculoDoIcmsMonoRet" description="Total Base de Cálculo do Icms Ret Ant" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoIcmsMonoRet" description="Total Valor do Icms Mono Ret Ant" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDosProdutosEServicos" description="Total Valor dos Produtos e Serviços" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalBrutoProFinanceiro" description="Total Bruto pro Financeiro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorSeguro" description="Total Valor Seguro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalDesconto" description="Total Desconto" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorII" description="Total Valor II" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIPI" description="Total Valor IPI" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorPIS" description="Total Valor PIS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCOFINS" description="Total Valor COFINS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalOutrasDespesasAcessorias" description="Total Outras Despesas Acessórias" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoDocumento" description="Total Valor do Documento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalIndiceTotalValorDoDoctoSobreTotValorDosProdEServ" description="Índice Total Valor do Documento Sobre Total Valor dos Produtos e Serviços" autolink="True" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorFrete" description="Total Valor Frete" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIS" description="Total Valor IS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorBaseDeCalculoDeIBSeCBS" description="Total Valor Base de Cálculo de IBS/CBS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSUfDif" description="Total Valor IBS UF Diferimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSUfDevTrib" description="Total Valor IBS UF Dev. Tributos" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSUf" description="Total Valor IBS UF" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMunDif" description="Total Valor IBS Mun Diferimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMunDevTrib" description="Total Valor IBS Mun Dev. Tributos" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMun" description="Total Valor IBS Mun" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBS" description="Total Valor IBS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSCredPres" description="Total Valor IBS Crédito Presumido" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSCredPresCondSus" description="Total Valor IBS Créd. Pres. Cond. Suspensiva" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSDif" description="Total Valor CBS Diferimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSDevTrib" description="Total Valor CBS Dev. Tributos" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBS" description="Total Valor CBS" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSCredPres" description="Total Valor CBS Crédito Presumido" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSCredPresCondSus" description="Total Valor CBS Créd. Pres. Cond. Suspensiva" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMono" description="Valor IBSMono" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSMono" description="Valor CBSMono" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMonoReten" description="IBSMono Reten" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSMonoReten" description="CBSMono Reten" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSMonoRet" description="IBSMono Ret" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSMonoRet" description="CBSMono Ret" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorIBSEstCred" description="IBSEst Cred" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorCBSEstCred" description="CBSEst Cred" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorDoDocumentoComIbsCbsIs" description="Total Valor do Documento Com ( IBS + CBS + IS )" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorFreteCompondoFinanceiro" description="Total Valor Frete Compondo Financeiro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorFreteNaoCompondoFinanceiro" description="Total Valor Frete Nao Compondo Financeiro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalLiquidoProFinanceiro" description="Total Líquido pro Financeiro" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalValorAproximadoDeTributos" description="Total Valor Aproximado de Tributos" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRetencaoPercentual" description="Retenção %" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalRetencao" description="Total Retenção" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalSiglaDaUFdeSaidaDoPais" description="Sigla da UF de Saída do País" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalLocalDeSaidaDoPais" description="Local de Saída do País" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalLocalDeDespachoAduaneiroNaSaidaDoPais" description="Local de Despacho Aduaneiro na Saída do País" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInformacoesAdicionaisDeInteresseDoFisco" description="Inf. Adic. de Interesse do Fisco" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInformacoesComplementaresDeInteresseContribuinte" description="Inf. Comp. de Interesse do Contribuinte" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalContingenciaHomologada" description="Contingência Homologada" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalContingenciaProtocolo" description="Contingência Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalLoteEnvio" description="Lote Envio" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalLoteStatusCodigo" description="Lote Status Código" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalReciboLote" description="Recibo Lote" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalStatusCodigo" description="Status Código" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAutorizado" description="Autorizado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalAutorizacaoProtocolo" description="Autorizacao Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDenegado" description="Denegado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDenegacaoProtocolo" description="Denegacao Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCancelamentoJustificativa" description="Cancelamento Justificativa" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCancelado" description="Cancelado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCancelamentoProtocolo" description="Cancelamento Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCorrecaoTexto" description="Correcao Texto" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCorrigido" description="Corrigido" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCorrecaoProtocolo" description="Correcao Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalCorrecaoSequencia" description="Correcao Sequência" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInutilizacaoDeNumeroJustificativa" description="Inutilização Numero Justificativa" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalNumeroInutilizado" description="Numero Inutilizado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInutilizacaoDeNumeroProtocolo" description="Inutilização Numero Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalManifestacaoDesconhecimentoJustificativa" description="Manifestação Desconhecimento Justificativa" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalManifestacaoDesconhecimentoSequencia" description="Manifestação Desconhecimento Sequência" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalManifestacaoDesconhecimentoProtocolo" description="Manifestação Desconhecimento Protocolo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalManifestadoDesconhecimento" description="Manifestado Desconhecimento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalInativado" description="Inativado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalObservacao" description="Observação" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalPecas" description="Total Peças" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalVolumes" description="Total Volumes" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalPesoLiquido" description="Peso Líquido" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalTara" description="Total Tara" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalTotalPesoBruto" description="Peso Bruto" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEspecieDosVolumes" description="Espécie dos Volumes" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalChavesReferenciadas" description="Chaves Referenciadas" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalChavesReferenciadasDeAntecipacaoDePagto" description="Chaves Referenciadas de Antecipação de Pagamento" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalIntermediadorId" description="Intermediador Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalIntermediadorEmpresaId" />
                  <parameter name="RegistroOperacionalIntermediadorId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalIntermediadorNome" description="Intermediador Nome" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalIntermediadorRazao" description="Intermediador Razao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalExpedicaoId" description="Expedicao Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalExpedicaoEmpresaId" />
                  <parameter name="RegistroOperacionalExpedicaoId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRecebimentoId" description="Recebimento Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalRecebimentoEmpresaId" />
                  <parameter name="RegistroOperacionalRecebimentoId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemId" description="RemessaOrigem Id" autolink="True" visible="True">
              <link webpanel="viewEntidade">
                <parameters>
                  <parameter name="RegistroOperacionalRemessaOrigemEmpresaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemRazao" description="Razao" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemDadosFiscaisAdicionaisId" description="Registro Operacional RemessaOrigem Dados Fiscais Adicionais Id" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemFaturamentoEnderecosId" description="Rem.Fat.End. Id" autolink="True" visible="True">
              <link webpanel="ViewPessoaEnderecos">
                <parameters>
                  <parameter name="RegistroOperacionalRemessaOrigemFaturamentoEnderecosPessoaEmpresaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemFaturamentoEnderecosPessoaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemFaturamentoEnderecosId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemTelefonesId" description="Rem.Tel. Id" autolink="True" visible="True">
              <link webpanel="ViewPessoaTelefones">
                <parameters>
                  <parameter name="RegistroOperacionalRemessaOrigemTelefonesPessoaEmpresaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemTelefonesPessoaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemTelefonesId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalRemessaOrigemE_MailsId" description="Rem. e-Mail Id" autolink="True" visible="True">
              <link webpanel="ViewPessoaE_Mails">
                <parameters>
                  <parameter name="RegistroOperacionalRemessaOrigemE_MailsPessoaEmpresaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemE_MailsPessoaId" />
                  <parameter name="RegistroOperacionalRemessaOrigemE_MailsId" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDocumentoAuxiliarGerado" description="Documento Auxiliar Gerado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalResumoAtualizacao" description="Resumo  Atualização" autolink="True" visible="True" />
          </attributes>
          <actions>
            <action name="Update" />
            <action name="Delete" />
            <action name="ApagaArquivoXmlNaoAssinado" caption="Apaga Xml Nao Assinado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml Nao Assinado do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlNaoAssinadoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="SituacaoDFe" caption="Situacao DFe" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Consulta Situacao do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.SituacaoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="SituacaoLoteDFe" caption="Situacao Lote DFe" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Consulta Lote de DFe pelo Recibo">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.SituacaoLoteDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraPdfDeRegistroOperacional" caption="Gera PDF Doc. Auxiliar" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Gera Documento Auxiliar do DFe">
              <parameters>
                <parameter name="iif(RegistroOperacionalXmlDeDistribuicaoArquivoId.IsEmpty() or RegistroOperacionalXmlDeDistribuicaoArquivoId.IsNull(), procUrlCorrente(&quot;General&quot;), &quot;&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraPdfDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="EnviaEmailDeRegistroOperacional" caption="Envia Email" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Envia Email desse Registro Operacional">
              <parameters>
                <parameter name="&quot;&quot;" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.EnviaEmail" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraXmlDeRegistroOperacional" caption="Gera Xml" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Gera Xml do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraXmlDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="CriaEnviaLoteDeRegistroOperacional" caption="Transmite pra SEFAZ" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Cria e Envia Lote desse Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.CriaEnviaLoteDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="DownloadArquivoXmlNaoAssinado" caption="Download Xml Nao Assinado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo Xml Nao Assinado">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadXmlNaoAssinado" />
                <parameter name="RegistroOperacionalXmlNaoAssinadoArquivoId" />
              </parameters>
            </action>
            <action name="DownloadArquivoXmlAssinado" caption="Download Xml Assinado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo Xml Assinado">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadXmlAssinado" />
                <parameter name="RegistroOperacionalXmlAssinadoArquivoId" />
              </parameters>
            </action>
            <action name="MostraArquivoXmlAssinado" caption="Mostra Xml Assinado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procDisplayUrlSemPaginaEmbutida" tooltip="Mostra Arquivo Xml Assinado">
              <parameters>
                <parameter name="wpMostraArquivo.Link(RegistroOperacionalXmlAssinadoArquivoEmpresaId, RegistroOperacionalXmlAssinadoArquivoId)" />
                <parameter name="0" />
                <parameter name="00" />
                <parameter name="true" />
                <parameter name="(true)" />
                <parameter name=" &quot;&quot;" />
              </parameters>
            </action>
            <action name="DownloadEventoEPEC" caption="Download Xml EPEC" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Evento EPEC">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadEPEC" />
                <parameter name="RegistroOperacionalEPECArquivoId" />
              </parameters>
            </action>
            <action name="DownloadArquivoProtocoloRegistro" caption="Download Xml Protocolo de Registro" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Protocolo de Registro">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadProtocoloRegistro" />
                <parameter name="RegistroOperacionalProtocoloDeRegistroArquivoId" />
              </parameters>
            </action>
            <action name="DownloadEventoDeCorrecao" caption="Download Xml Evento de Correcao" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Evento de Correcao">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadEventoCorrecao" />
                <parameter name="RegistroOperacionalEventoDeCorrecaoArquivoId" />
              </parameters>
            </action>
            <action name="DownloadRetornoDeCancelamento" caption="Download Xml Retorno de Cancelamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Retorno de Cancelamento">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadRetornoCancelamento" />
                <parameter name="RegistroOperacionalRetornoDeCancelamentoArquivoId" />
              </parameters>
            </action>
            <action name="DownloadEventoDeCancelamento" caption="Download Xml Evento de Cancelamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Evento de Cancelamento">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadEventoCancelamento" />
                <parameter name="RegistroOperacionalEventoDeCancelamentoArquivoId" />
              </parameters>
            </action>
            <action name="DownloadArquivoXmlDeDistribuicao" caption="Download Xml de Distribuição" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo Xml de Distribuição">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadXmlDistribuicao" />
                <parameter name="RegistroOperacionalXmlDeDistribuicaoArquivoId" />
              </parameters>
            </action>
            <action name="MostraArquivoXmlDeDistribuicao" caption="Mostra Xml de Distribuição" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procDisplayUrlSemPaginaEmbutida" tooltip="Mostra Arquivo Xml de Distribuição">
              <parameters>
                <parameter name="wpMostraArquivo.Link(RegistroOperacionalXmlDeDistribuicaoArquivoEmpresaId, RegistroOperacionalXmlDeDistribuicaoArquivoId)" />
                <parameter name="0" />
                <parameter name="00" />
                <parameter name="true" />
                <parameter name="(true)" />
                <parameter name=" &quot;&quot;" />
              </parameters>
            </action>
            <action name="DownloadArquivoInutilizacao" caption="Download Xml Inutilização" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" tooltip="Download do Arquivo de Inutilização">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.DownloadInutilizacao" />
                <parameter name="RegistroOperacionalInutilizacaoArquivoId" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlAssinado" caption="Apaga Xml Assinado" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml Assinado do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlAssinadoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="CriaEnviaInutilizacaoDeNumero" caption="Cria Envia Inutilização de Numero" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPedeDadosParaProcessamentoDFe" tooltip="Cria e Envia Inutilização de Numero">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.CriaEnviaInutilizacaoNumero" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="CriaEnviaEventoEPECdeRegistroOperacional" caption="Cria Envia Evento EPEC" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Cria e Envia Evento EPEC desse Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.CriaEnviaEventoEPEC" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="CriaEnviaEventoCorrecaoDeRegistroOperacional" caption="Cria Envia Evento de Correcao" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPedeDadosParaProcessamentoDFe" tooltip="Cria e Envia Evento Correcao desse Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.CriaEnviaEventoCorrecao" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="CriaEnviaEventoCancelamentoDeRegistroOperacional" caption="Cria Envia Evento de Cancelamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPedeDadosParaProcessamentoDFe" tooltip="Cria e Envia Evento Cancelamento desse Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.CriaEnviaEventoCancelamento" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlDistribuicao" caption="Apaga Xml de Distribuição" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml de Distribuição do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlDistribuicaoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlInutilizacao" caption="Apaga Xml Inutilização" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml de Inutilzação de Numero  do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlInutilizacaoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlProtocolo" caption="Apaga Xml Protocolo" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml de Protocolo de Registro  do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlProtocoloDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlEventoCancelamento" caption="Apaga Xml Cancelamento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml de Evento de Cancelamento do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlEventoCancelamentoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="ApagaArquivoXmlEventoCorrecao" caption="Apaga Xml Correcao" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Apaga Xml de Evento de Correcao do Registro Operacional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ApagaXmlEventoCorrecaoDFe" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraDFeAdicional" caption="Gera NFe Adicional" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Gera DFe Adicional">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraDFeAdicional" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraDFeComplementar" caption="Gera NFe Complementar" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" tooltip="Gera DFe Complementar">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraDFeComplementar" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraDFeDeDevolucaoSemMovimento" caption="Gera NFe de Devolução Sem Movimento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPedeDadosParaProcessamentoDFe" tooltip="Gera DFe de Devolução Sem Movimento">
              <parameters>
                <parameter name="&quot;&quot;" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraDFeDeDevolucaoSemMovimento" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="GeraDFeNormalSemMovimento" caption="Gera NFe Normal Sem Movimento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procPedeDadosParaProcessamentoDFe" tooltip="Gera DFe Normal Sem Movimento">
              <parameters>
                <parameter name="&quot;&quot;" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.GeraDFeNormalSemMovimento" />
                <parameter name="0" />
              </parameters>
            </action>
            <action name="AtualizaTotais" caption="Atualiza Totais" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procCalculaTotaisRegistroOperacionalSemRetorno" tooltip="Atualiza Totais">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
              </parameters>
            </action>
            <action name="ReprocessaArquivoXmlDeDistribuicao" caption="Reprocessa Xml de Distribuição" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procProcessaAlgoDoDFE" inGrid="False" disabledClass="" tooltip="Reprocessa Arquivo Xml de Distribuição" buttonClass="" inGridClass="">
              <parameters>
                <parameter name="procUrlCorrente(&quot;General&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
                <parameter name="ProcessamentoDFe.ReprocessaXmlDistribuicao" />
                <parameter name="RegistroOperacionalXmlDeDistribuicaoArquivoId" />
              </parameters>
            </action>
          </actions>
        </tab>
        <tab name="Itens" code="RegistroOperacionalItem" type="Grid" wcname="RegistroOperacionalRegistroOperacionalItemWC" page="100">
          <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-RegistroOperacionalItem" />
          <modes Update="false" Delete="true" Display="false" InsertCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" UpdateCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" DeleteCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" />
          <attributes>
            <variable name="IconeUpdate" domain="00972a17-9975-449e-aab1-d26165d51393-Icone" themeClass="UpdateAttribute" themeColumnClass="WWColumn"><![CDATA[&IconeUpdate.FromImage(ActionUpdate)
&IconeUpdate.link = RegistroOperacionalItem.Link(trnmode.Update, RegistroOperacionalEmpresaId, RegistroOperacionalId, RegistroOperacionalItemId)
&IconeUpdate.TooltipText = "GXM_update"

RegistroOperacionalItemNumero.Visible = not RegistroOperacionalItemNumero.IsEmpty() and not RegistroOperacionalItemNumero.IsNull()

RegistroOperacionalItemProdutoDescricao.Visible = RegistroOperacionalItemProdutoDescricao <> RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF and
	RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF.IndexOf(RegistroOperacionalItemProdutoDescricao) = 0

//if RegistroOperacionalItemProdutoDescricao = RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF
//	RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF.TooltipText = RegistroOperacionalItemProdutoDescricao
//endif

RegistroOperacionalItemValorIPI.Visible = not RegistroOperacionalItemValorIPI.IsEmpty() and not RegistroOperacionalItemValorIPI.IsNull()
RegistroOperacionalItemValorIcmsST.Visible = not RegistroOperacionalItemValorIcmsST.IsEmpty() and not RegistroOperacionalItemValorIcmsST.IsNull()
RegistroOperacionalItemValorIcmsFCPST.Visible = not RegistroOperacionalItemValorIcmsFCPST.IsEmpty() and not RegistroOperacionalItemValorIcmsFCPST.IsNull()
RegistroOperacionalItemComSubstituicaoTributariaDeIcms.Visible = RegistroOperacionalItemComSubstituicaoTributariaDeIcms
RegistroOperacionalItemCSTdoICMSdaNotaDeEntradaNaEmpresa.Visible = not RegistroOperacionalItemCSTdoICMSdaNotaDeEntradaNaEmpresa.IsEmpty() and not RegistroOperacionalItemCSTdoICMSdaNotaDeEntradaNaEmpresa.IsNull()
RegistroOperacionalItemSemTransitoNoEstabelecimento.Visible = RegistroOperacionalItemSemTransitoNoEstabelecimento
RegistroOperacionalItemDocumentoItemId.Visible = not RegistroOperacionalItemDocumentoItemId.IsEmpty() and not RegistroOperacionalItemDocumentoItemId.IsNull()
RegistroOperacionalItemDocumentoItemDocumentoExternoItem.Visible = not RegistroOperacionalItemDocumentoItemDocumentoExternoItem.IsEmpty() and not RegistroOperacionalItemDocumentoItemDocumentoExternoItem.IsNull()
RegistroOperacionalItemDocumentoItemDocumentoExternoNumero.Visible = not RegistroOperacionalItemDocumentoItemDocumentoExternoNumero.IsEmpty() and not RegistroOperacionalItemDocumentoItemDocumentoExternoNumero.IsNull()

RegistroOperacionalItemValorTotalBruto.Visible = RegistroOperacionalItemValorTotalBruto <> RegistroOperacionalItemValorTotalLiquido

RegistroOperacionalItemDescontoPercentual.Visible = not RegistroOperacionalItemDescontoPercentual.IsEmpty() and not RegistroOperacionalItemDescontoPercentual.IsNull()
RegistroOperacionalItemValorDesconto.Visible = not RegistroOperacionalItemValorDesconto.IsEmpty() and not RegistroOperacionalItemValorDesconto.IsNull()

RegistroOperacionalItemDesoneracaoIcmsPercentual.Visible = not RegistroOperacionalItemDesoneracaoIcmsPercentual.IsEmpty() and not RegistroOperacionalItemDesoneracaoIcmsPercentual.IsNull()
RegistroOperacionalItemValorDesoneracaoICMS.Visible = not RegistroOperacionalItemValorDesoneracaoICMS.IsEmpty() and not RegistroOperacionalItemValorDesoneracaoICMS.IsNull()
RegistroOperacionalItemValorDesoneracaoIcmsForaDoValorTotalLiquido.Visible = RegistroOperacionalItemValorDesoneracaoIcmsForaDoValorTotalLiquido and
					not RegistroOperacionalItemValorDesoneracaoICMS.IsEmpty() and not RegistroOperacionalItemValorDesoneracaoICMS.IsNull()

RegistroOperacionalItemValorOutrasDespesasAcessorias.Visible = not RegistroOperacionalItemValorOutrasDespesasAcessorias.IsEmpty() and not RegistroOperacionalItemValorOutrasDespesasAcessorias.IsNull()

RegistroOperacionalItemValorTotalLiquido.ToolTipText = RegistroOperacionalItemCompoeTotalProFinanceiro.EnumerationDescription()

RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM.Visible = 
	not RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM.IsEmpty() and 
	not RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM.IsNull() and
	RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM <> RegistroOperacionalItemNCM

RegistroOperacionalItemNCM.Visible = 
	not RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM.IsEmpty() and 
	not RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM.IsNull() and
	RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM <> RegistroOperacionalItemNCM

RegistroOperacionalItemValorTotalFinal.Visible = RegistroOperacionalItemValorTotalFinal <> RegistroOperacionalItemValorTotalLiquido
RegistroOperacionalItemQuilos.Visible = 
	not RegistroOperacionalItemQuilos.IsEmpty() and not RegistroOperacionalItemQuilos.IsNull() and
	RegistroOperacionalItemQuilos <> RegistroOperacionalItemQuantidadeComercial
RegistroOperacionalItemValorUnitarioFinalPorQuilo.Visible = 
	not RegistroOperacionalItemValorUnitarioFinalPorQuilo.IsEmpty() and
	not RegistroOperacionalItemValorUnitarioFinalPorQuilo.IsNull() and
	RegistroOperacionalItemValorUnitarioFinalPorQuilo <> RegistroOperacionalItemValorUnitarioComercial

RegistroOperacionalItemInformacoesAdicionaisDoProduto.Visible = 
	not RegistroOperacionalItemInformacoesAdicionaisDoProduto.IsEmpty() and not RegistroOperacionalItemInformacoesAdicionaisDoProduto.IsNull()

RegistroOperacionalItemDescricaoFinal.Visible = not RegistroOperacionalItemDescricaoFinal.IsEmpty() and not RegistroOperacionalItemDescricaoFinal.IsNull() and
	RegistroOperacionalItemDescricaoFinal <> RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF and
	(not RegistroOperacionalEmissaoDaEmpresa or RegistroOperacionalEmissaoForaDoBaseExemplo)

RegistroOperacionalItemBeneficioFiscalEstadualCodigo.Visible = not RegistroOperacionalItemBeneficioFiscalEstadualCodigo.IsEmpty() and not RegistroOperacionalItemBeneficioFiscalEstadualCodigo.IsNull()

&OperacaoFiscalCodigo.Visible = not RegistroOperacionalItemOperacaoFiscalCodigo.IsEmpty() and not RegistroOperacionalItemOperacaoFiscalCodigo.IsNull()

//Esconde actions conforme situação
&Delete.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo
					
&IconeUpdate.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo
					
BtnInsert.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo and
					(RegistroOperacionalMovimentoId.IsEmpty() or RegistroOperacionalMovimentoId.IsNull() or procUsuarioDaSessaoDaEquipeExemplo()) and
					(RegistroOperacionalDocumentoId.IsEmpty() or RegistroOperacionalDocumentoId.IsNull() or procUsuarioDaSessaoDaEquipeExemplo())
					
BtnAtualizaItensPelosVolumes.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo and
					not RegistroOperacionalMovimentoId.IsEmpty() and not RegistroOperacionalMovimentoId.IsNull()]]]]><![CDATA[></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemId" description="Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemNumero" description="Nr" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoCodigo" description="Prod." autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoDescricao" description="Descrição" themeClass="AttributeQuebraLinha" themeColumnClass="WWColumn LarguraMinima_100px" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoDadosFiscaisAdicionaisId" description="D.F.A. Id" autolink="True" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoDadosFiscaisAdicionaisEmpresaId" description="D.F.A. Empresa Id" autolink="True" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoDadosFiscaisAdicionaisDescricaoSIFeNF" description="Desc. SIF/ NF" autolink="True" visible="True" themeClass="AttributeQuebraLinha" themeColumnClass="LarguraMinima_150px" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemProdutoDadosFiscaisAdicionaisNCM" description="Cad.NCM" autolink="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemNCM" description="NCM" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemBeneficioFiscalEstadualCodigo" description="cBenef" themeColumnClass="" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemUnidadeComercial" description="Unid." autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemQuantidadeComercial" description="Qtde" autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorUnitarioComercial" description="V.Unit." autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorTotalBruto" description="V.T.Bruto" autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDescontoPercentual" description="Desc.%" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorDesconto" description="V.Desc." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDesoneracaoIcmsPercentual" description="Deson.%" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorDesoneracaoICMS" description="V.Deson.ICMS" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorDesoneracaoIcmsForaDoValorTotalLiquido" description="Deson.Icms Fora V.T.Líq." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorOutrasDespesasAcessorias" description="V.O.D.Acessórias" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorTotalLiquido" description="V.T.Liq." autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorIPI" description="V.IPI" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorIcmsST" description="V.Icms ST" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorIcmsFCPST" description="V.Icms FCP ST" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemOperacaoFiscalCodigo" description="CFOP" autolink="True" visible="False">
              <link webpanel="ViewOperacaoFiscal">
                <parameters>
                  <parameter name="RegistroOperacionalItemOperacaoFiscalCodigo" />
                  <parameter name="'General'" />
                </parameters>
              </link>
            </attribute>
            <variable name="OperacaoFiscalCodigo" description="CFOP" domain="00972a17-9975-449e-aab1-d26165d51393-CFOP" themeColumnClass="WWColumn"><![CDATA[&OperacaoFiscalCodigo = RegistroOperacionalItemOperacaoFiscalCodigo]]]]><![CDATA[><link webpanel="ViewOperacaoFiscal"><parameters><parameter name="RegistroOperacionalItemOperacaoFiscalCodigo" /><parameter name="'General'" /></parameters></link></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorTotalFinal" description="V.T.Final" themeClass="" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemQuilos" description="Quilos" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemValorUnitarioFinalPorQuilo" description="V.U.Final P/Kq" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemCSTdoICMSdaNotaDeEntradaNaEmpresa" description="CST ICMS NF Ent." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemComSubstituicaoTributariaDeIcms" description="C/Subst.Trib." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemSemTransitoNoEstabelecimento" description="S/Trans." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDocumentoItemId" description="Doc.Item Id" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDocumentoItemDocumentoExternoItem" description="Doc.Ext.Item" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDocumentoItemDocumentoExternoNumero" description="Doc.Ext.Nr." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDescricaoNoItemDoContrato" description="Desc. no Contrato" visible="False" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemTipoValorUnitario" description="Tipo V.Unit." />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemInformacoesAdicionaisDoProduto" description="Inf.Adicionais" themeClass="AttributeQuebraLinha" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemDescricaoFinal" description="Descrição no Xml" themeClass="AttributeQuebraLinha" />
          </attributes>
          <orders>
            <order name="NrMaisId">
              <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemNumero" description="Registro Operacional Item Numero" />
              <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalItemId" description="Registro Operacional Item Id" />
            </order>
          </orders>
          <actions>
            <action name="AtualizaItensPelosVolumes" caption="Atualiza Itens Pelos Volumes" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procRegistroOperacionalAtualizaItensPelosVolumesSemRetorno" tooltip="Atualiza Itens Pelos Volumes" condition=" not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa">
              <parameters>
                <parameter name="procUrlCorrente(&quot;RegistroOperacionalItem&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
              </parameters>
            </action>
            <action name="AtualizaItensPeloDocumento" caption="Atualiza Itens Pelo Documento" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procRegistroOperacionalAtualizaItensPeloDocumentoSemRetorno" tooltip="Atualiza Itens Pelo Documento" condition=" not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa">
              <parameters>
                <parameter name="procUrlCorrente(&quot;RegistroOperacionalItem&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
              </parameters>
            </action>
          </actions>
        </tab>
        <tab name="Impostos dos Itens" code="RegistroOperacionalImpostosDosItens" type="UserDefined" wcname="wcRegistroOperacionalImpostosDosItens">
          <parameters>
            <parameter name="RegistroOperacionalEmpresaId" />
            <parameter name="RegistroOperacionalId" />
          </parameters>
        </tab>
        <tab name="Lacres" code="RegistroOperacionalLacre" type="Grid" wcname="RegistroOperacionalRegistroOperacionalLacreWC" page="&lt;unlimited&gt;">
          <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-RegistroOperacionalLacre" />
          <modes Update="false" Delete="true" Display="false" InsertCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" UpdateCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" DeleteCondition="RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() and RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() and not RegistroOperacionalInativado and not RegistroOperacionalEmissaoForaDoBaseExemplo" />
          <attributes>
            <variable name="IconeUpdate" domain="00972a17-9975-449e-aab1-d26165d51393-Icone" themeClass="UpdateAttribute" themeColumnClass="WWColumn"><![CDATA[&IconeUpdate.FromImage(ActionUpdate)
&IconeUpdate.link = RegistroOperacionalLacre.Link(trnmode.Update, RegistroOperacionalEmpresaId, RegistroOperacionalId, RegistroOperacionalLacreNumero)
&IconeUpdate.TooltipText = "GXM_update"

//Esconde actions conforme situação
&Delete.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa
					
&IconeUpdate.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa
					
BtnInsert.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa]]]]><![CDATA[></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalLacreNumero" description="Numero" autolink="True" visible="True" />
          </attributes>
        </tab>
        <tab name="Duplicatas" code="RegistroOperacionalDuplicata" type="Grid" wcname="RegistroOperacionalRegistroOperacionalDuplicataWC" page="&lt;default&gt;">
          <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-RegistroOperacionalDuplicata" />
          <modes Update="false" Delete="true" Display="false" />
          <attributes>
            <variable name="IconeUpdate" domain="00972a17-9975-449e-aab1-d26165d51393-Icone" themeClass="UpdateAttribute"><![CDATA[&IconeUpdate.FromImage(ActionUpdate)
&IconeUpdate.link = RegistroOperacionalDuplicata.Link(trnmode.Update, RegistroOperacionalEmpresaId, RegistroOperacionalId, RegistroOperacionalDuplicataId)
&IconeUpdate.TooltipText = "GXM_update"

RegistroOperacionalDuplicataTipoDocumentoCobrancaDescricao.Visible = 
	not RegistroOperacionalDuplicataTipoDocumentoCobrancaId.IsEmpty() and not RegistroOperacionalDuplicataTipoDocumentoCobrancaId.IsNull()
	
RegistroOperacionalDuplicataMeioDePagamentoNFe.Visible = not RegistroOperacionalDuplicataMeioDePagamentoNFe.IsEmpty() and not RegistroOperacionalDuplicataMeioDePagamentoNFe.IsNull()
		
RegistroOperacionalDuplicataDescricaoDoMeioDePagamento.Visible = not RegistroOperacionalDuplicataDescricaoDoMeioDePagamento.IsEmpty() and not RegistroOperacionalDuplicataDescricaoDoMeioDePagamento.IsNull()

&DataBaseParaVencimento = iif( not RegistroOperacionalDocumentoId.IsEmpty() and not RegistroOperacionalDocumentoId.IsNull() and (RegistroOperacionalMovimentoId.IsEmpty() or RegistroOperacionalMovimentoId.IsNull()) ,RegistroOperacionalData, RegistroOperacionalSaidaEntrada.ToDate())
&DataBaseParaVencimento.Visible = not &DataBaseParaVencimento.IsEmpty() and &DataBaseParaVencimento <> RegistroOperacionalDuplicataVencimentoData

&Prazo = RegistroOperacionalDuplicataVencimentoData-&DataBaseParaVencimento
&Prazo.Visible = not &Prazo.IsEmpty()

RegistroOperacionalDuplicataTipoDeIntegracaoParaPagamento.Visible = not RegistroOperacionalDuplicataTipoDeIntegracaoParaPagamento.IsEmpty() and not RegistroOperacionalDuplicataTipoDeIntegracaoParaPagamento.IsNull()
RegistroOperacionalDuplicataTransacaoDePagamentoCodigo.Visible = not RegistroOperacionalDuplicataTransacaoDePagamentoCodigo.IsEmpty() and not RegistroOperacionalDuplicataTransacaoDePagamentoCodigo.IsEmpty()
RegistroOperacionalDuplicataCNPJdaInstituicaoDePagamento.Visible = not RegistroOperacionalDuplicataCNPJdaInstituicaoDePagamento.IsEmpty() and not RegistroOperacionalDuplicataCNPJdaInstituicaoDePagamento.IsNull()
RegistroOperacionalDuplicataBandeiraDeCartaoNome.Visible = not RegistroOperacionalDuplicataBandeiraDeCartaoId.IsEmpty() and not RegistroOperacionalDuplicataBandeiraDeCartaoId.IsNull()
RegistroOperacionalDuplicataBandeiraDeCartaoTipoDescricao.Visible = not RegistroOperacionalDuplicataBandeiraDeCartaoTipoId.IsEmpty() and not RegistroOperacionalDuplicataBandeiraDeCartaoTipoId.IsNull()

//Desliga os campos acima
//nao precisou

//Esconde actions conforme situação
&Delete.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa and
					(RegistroOperacionalDocumentoId.IsEmpty() or RegistroOperacionalDocumentoId.IsNull())
					
&IconeUpdate.Visible = (	(RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa
			     ) or (not RegistroOperacionalEmissaoDaEmpresa and not RegistroOperacionalInativado and RegistroOperacionalAutorizado)	
BtnInsert.Visible = (	(RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
				(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
				not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa and
				(RegistroOperacionalDocumentoId.IsEmpty() or RegistroOperacionalDocumentoId.IsNull())
			  ) or (not RegistroOperacionalEmissaoDaEmpresa and not RegistroOperacionalInativado and RegistroOperacionalAutorizado)

BtnAtualizaDuplicatas.Visible = (RegistroOperacionalXmlAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlAssinadoArquivoId.IsNull()) and 
					(RegistroOperacionalXmlNaoAssinadoArquivoId.IsEmpty() or RegistroOperacionalXmlNaoAssinadoArquivoId.IsNull()) and 
					not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa

//BtnGeraTitulos.Visible = not RegistroOperacionalInativado

if RegistroOperacionalInativado or not RegistroOperacionalEmissaoDaEmpresa

	//nao funciona. da erro ao compilar.
	//MORE.Visible = false
	
	BtnImprimeDuplicatas.Visible 						= false
	BtnImpressaoBoletosDosTitulosDoRegistroOperacional.Visible 	= false
	
else

	BtnImprimeDuplicatas.Visible 						= RegistroOperacionalDuplicataTipoDocumentoCobrancaFormulario = FormularioCobranca.Duplicata
	BtnImpressaoBoletosDosTitulosDoRegistroOperacional.Visible 	= RegistroOperacionalDuplicataTipoDocumentoCobrancaFormulario = FormularioCobranca.BoletoBancario

	//nao funciona. da erro ao compilar.
	//MORE.Visible = RegistroOperacionalDuplicataTipoDocumentoCobrancaFormulario = FormularioCobranca.Duplicata or RegistroOperacionalDuplicataTipoDocumentoCobrancaFormulario = FormularioCobranca.BoletoBancario
	
endif]]]]><![CDATA[></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataId" description="Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataVencimentoData" description="Vencimento" autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataValor" description="Valor" autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataNumero" description="Núm." autolink="True" visible="True" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataMeioDePagamentoNFe" description="Meio Pagto Nota" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataDescricaoDoMeioDePagamento" description="Desc. Meio Pagto ( se Outros)" themeColumnClass="WWColumn" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataTipoDocumentoCobrancaDescricao" description="Tipo Docto Cobrança" themeColumnClass="WWColumn" />
            <variable name="DataBaseParaVencimento" description="Base Vencto" domain="00972a17-9975-449e-aab1-d26165d51393-Data" />
            <variable name="Prazo" description="Prazo" domain="00972a17-9975-449e-aab1-d26165d51393-PrazoValidade" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataTipoDeIntegracaoParaPagamento" description="Tipo Integ.Pagto" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataTransacaoDePagamentoCodigo" description="Trans.Pagto" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataCNPJdaInstituicaoDePagamento" description="CNPJ Instit.Pagto" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataBandeiraDeCartaoNome" description="Band.Cartão" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataBandeiraDeCartaoTipoDescricao" description="Cartão Tipo" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataTransacaoDePagamentoParcela" description="T.P.Parc." autolink="True" visible="True" />
          </attributes>
          <orders>
            <order name="Id">
              <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalEmpresaId" description="Registro Operacional Empresa Id" />
              <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalId" description="Registro Operacional Id" />
              <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-RegistroOperacionalDuplicataId" description="Registro Operacional Duplicata Id" />
            </order>
          </orders>
          <actions>
            <action name="AtualizaDuplicatas" caption="Atualiza Duplicatas" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procAtualizaDuplicatasDoRegistroOperacionalSemRetorno" tooltip="Atualiza Duplicatas desse Registro Operacional" condition=" not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa">
              <parameters>
                <parameter name="procUrlCorrente(&quot;RegistroOperacionalDuplicata&quot;)" />
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="RegistroOperacionalId" />
              </parameters>
            </action>
            <action name="ImprimeDuplicatas" caption="Imprime Duplicatas" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procDisplayUrlSemPaginaEmbutida" tooltip="Imprime Duplicatas" condition="not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa">
              <parameters>
                <parameter name="procImpressaoDuplicatas.Link(RegistroOperacionalEmpresaId, RegistroOperacionalTipoMovimento, 0, RegistroOperacionalMovimentoId, RegistroOperacionalId)" />
                <parameter name="0" />
                <parameter name="00" />
                <parameter name="true" />
                <parameter name="(true)" />
                <parameter name="&quot;&quot;" />
              </parameters>
            </action>
            <action name="ImpressaoBoletosDosTitulosDoRegistroOperacional" caption="Impressao Boletos" gxobject="84a12160-f59b-4ad7-a683-ea4481ac23e9-procImpressaoBoletosDeTitulos" tooltip="Impressao Boletos dos Titulos do Registro Operacional" condition="not RegistroOperacionalInativado and RegistroOperacionalEmissaoDaEmpresa">
              <parameters>
                <parameter name="RegistroOperacionalEmpresaId" />
                <parameter name="0" />
                <parameter name="RegistroOperacionalId" />
              </parameters>
            </action>
          </actions>
        </tab>
        <tab name="Títulos" code="Titulo" type="UserDefined" wcname="wcTitulosDeUmRegistroOperacional">
          <parameters>
            <parameter name="RegistroOperacionalEmpresaId" />
            <parameter name="RegistroOperacionalId" />
          </parameters>
        </tab>
        <tab name="Registros Operacionais Referenciados" code="DocumentosFiscaisReferenciados" description="Registros Operacionais Referenciados" type="UserDefined" wcname="wcDocumentosFiscaisReferenciados">
          <parameters>
            <parameter name="RegistroOperacionalEmpresaId" />
            <parameter name="RegistroOperacionalId" />
          </parameters>
        </tab>
        <tab name="Volume Movimentos" code="VolumeMovimento" type="Grid" wcname="RegistroOperacionalVolumeMovimentoWC" page="&lt;default&gt;">
          <parameters>
            <parameter name="VolumeMovimentoRegistroOperacionalEmpresaId" null="True" />
            <parameter name="VolumeMovimentoRegistroOperacionalId" null="True" />
          </parameters>
          <transaction transaction="1db606f2-af09-4cf9-a3b5-b481519d28f6-VolumeMovimento" />
          <modes Insert="false" Update="false" />
          <attributes>
            <variable name="Escondido" domain="00972a17-9975-449e-aab1-d26165d51393-Id"><![CDATA[VolumeMovimentoCancelado.Visible = VolumeMovimentoCancelado
VolumeMovimentoVolumeCancelado.Visible = VolumeMovimentoVolumeCancelado
VolumeMovimentoVolumeNumeroSerie.Visible = not VolumeMovimentoVolumeNumeroSerie.IsEmpty() and not VolumeMovimentoVolumeNumeroSerie.IsNull()
VolumeMovimentoVolumeCodigoBarras.Visible = not VolumeMovimentoVolumeCodigoBarras.IsEmpty() and not VolumeMovimentoVolumeCodigoBarras.IsNull()
VolumeMovimentoVolumeQuantidadeVolumes.Visible = not VolumeMovimentoVolumeQuantidadeVolumes.IsEmpty() and not VolumeMovimentoVolumeQuantidadeVolumes.IsNull()
VolumeMovimentoVolumeQuantidadePecas.Visible = not VolumeMovimentoVolumeQuantidadePecas.IsEmpty() and not VolumeMovimentoVolumeQuantidadePecas.IsNull()
VolumeMovimentoVolumePesoLiquido.Visible = not VolumeMovimentoVolumePesoLiquido.IsEmpty() and not VolumeMovimentoVolumePesoLiquido.IsNull()

//Desliga os campos acima]]]]><![CDATA[></variable>
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoId" description="Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoCancelado" description="Canc." autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeId" description="Vol.Id" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeCancelado" description="Vol. Cancelado" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeNumeroSerie" description="Nr.Série" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeCodigoBarras" description="Cód.Barras" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeProdutoCodigo" description="Prod." autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeProdutoDescricao" description="Descrição" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeQuantidadeVolumes" description="Vol." autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumeQuantidadePecas" description="Peças" autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoVolumePesoLiquido" description="Peso Liq." autolink="True" visible="True" />
            <attribute attribute="adbb33c9-0906-4971-833c-998de27e0676-VolumeMovimentoRegistroOperacionalItemId" description="D.F. Item Id" />
          </attributes>
        </tab>
        <tab name="Arquivos Referenciados" code="ArquivosReferenciados" type="UserDefined" wcname="wcArquivosReferenciados">
          <parameters>
            <parameter name="&quot;DOCUMENTOFISCAL_&quot;+RegistroOperacionalEmpresaId.ToString().Trim()+&quot;_&quot;+RegistroOperacionalId.ToString().Trim()" />
          </parameters>
        </tab>
      </tabs>
    </view>
  </level>
</instance>]]></Data>
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
      <Value>WorkWithWebRegistroOperacional</Value>
    </Property>
    <Property>
      <Name>KBObject</Name>
      <Value>1db606f2-af09-4cf9-a3b5-b481519d28f6-RegistroOperacional</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

```

## Moldes sanitizados completos de SDT

- Evidência direta: o acervo usado nesta base contem 594 objetos SDT.
- Inferência forte: o tipo combina casos muito simples, colecoes internas e estruturas externas com namespace/soaptype, o que torna útil documentar pelo menos um molde plano e um molde com nesting/metadata externa.

### Molde sanitizado de SDT 1 - `sdtPeriodoExemplo`

- Perfil: SDT enxuto com um nivel unico e dois itens simples baseados em dominio.
- Uso operacional: boa referencia para SDT pequeno de entrada/saida com campos escalares.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="aca52e78-bfbb-4177-8884-c10d48d1fff1" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-05-19T17:55:24.0000000Z" checksum="1c526a33a1f679abfc3a2746ccdeb52b" fullyQualifiedName="sdtPeriodoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f50cac7f-5ce6-42e9-af89-7f4a9ebb7fdf" name="sdtPeriodoExemplo" type="447527b5-9210-4523-898b-5dccb17be60a" description="sdt Periodo Exemplo" parent="PastaExemploSDT" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a">
    <Level Name="sdtPeriodoExemplo">
      <LevelInfo guid="d288f3d0-3834-46af-a65f-5b3fb5308060" name="sdtPeriodoExemplo" type="a76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="sdt Periodo Exemplo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtPeriodoExemplo</Value>
          </Property>
        </Properties>
      </LevelInfo>
      <Item guid="4cedcb11-83cc-4f9b-8367-d93215f5ce1c" name="DataInicial" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Inicial Data" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>DataInicial</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Data</Value>
          </Property>
        </Properties>
      </Item>
      <Item guid="093d4eb3-5f4a-44d5-b0c3-2953dae0d8ab" name="DataFinal" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Final Data" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>DataFinal</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Data</Value>
          </Property>
        </Properties>
      </Item>
    </Level>
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
      <Value>sdtPeriodoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de SDT 2 - `sdtAgrupamentoExemplo`

- Perfil: SDT com item composto, colecao e metadata de serializacao externa (ExternalName, ExternalNamespace, idXmlNamespace, soaptype).
- Uso operacional: boa referencia para SDT mais sensivel a integracao, namespace e estrutura hierarquica declarada.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="5ea9cdc4-1809-4bae-adfa-8e4183dab2f7" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-10-07T11:36:33.0000000Z" checksum="8da196d5696215a0956129a0223fc22a" fullyQualifiedName="sdtAgrupamentoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="da01d928-4061-4b6a-b92f-bc76dddd7397" name="sdtAgrupamentoExemplo" type="447527b5-9210-4523-898b-5dccb17be60a" description="sdt Agrupamento Exemplo" parent="PastaExemploSDT" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a">
    <Level Name="sdtAgrupamentoExemplo">
      <LevelInfo guid="ae2f592a-c84e-4081-b9f0-558ab1a49369" name="sdtAgrupamentoExemplo" type="a76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="sdt Agrupamento Exemplo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtAgrupamentoExemplo</Value>
          </Property>
        </Properties>
      </LevelInfo>
      <Item guid="a8f1c0e4-c0b4-4f7c-afb9-6a120e5cdbe9" name="Grupo" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Grupo" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>Grupo</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:PastaExemploSDTServicetGrupo</Value>
          </Property>
          <Property>
            <Name>idXmlName</Name>
            <Value>Grupo</Value>
          </Property>
          <Property>
            <Name>idXmlNamespace</Name>
            <Value>http://example.org/sdt</Value>
          </Property>
          <Property>
            <Name>soaptype</Name>
            <Value>http://example.org/sdt.tGrupo</Value>
          </Property>
        </Properties>
      </Item>
      <Item guid="0d086759-eb3c-47e4-820b-e1665e63d1f4" name="Itens" type="f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3" description="Country Code And Names" user="SANITIZED\\USER">
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>Itens</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:PastaExemploSDTServiceItemExemplo</Value>
          </Property>
          <Property>
            <Name>AttCollection</Name>
            <Value>True</Value>
          </Property>
          <Property>
            <Name>idCollectionItemName</Name>
            <Value>ItemExemplo</Value>
          </Property>
          <Property>
            <Name>idXmlName</Name>
            <Value>Itens</Value>
          </Property>
          <Property>
            <Name>idXmlNamespace</Name>
            <Value>http://example.org/sdt</Value>
          </Property>
          <Property>
            <Name>soaptype</Name>
            <Value>http://example.org/sdt.ItemExemplo</Value>
          </Property>
        </Properties>
      </Item>
    </Level>
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
      <Value>sdtAgrupamentoExemplo</Value>
    </Property>
    <Property>
      <Name>ExternalName</Name>
      <Value>ItemExemploGroupedByGrupo</Value>
    </Property>
    <Property>
      <Name>ExternalNamespace</Name>
      <Value>http://example.org/sdt</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Domain

- Evidência direta: o acervo usado nesta base contem 592 objetos Domain.
- Inferência forte: o tipo se divide bem entre dominios escalares simples e dominios enumerados com IDEnumDefinedValues, o que justifica documentar um molde de cada perfil.

### Molde sanitizado de Domain 1 - `NumeroExemplo`

- Perfil: Domain escalar simples baseado em as:Numeric.
- Uso operacional: boa referencia para dominios pequenos sem enum e sem metadata adicional relevante.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:42.0000000Z" checksum="e69ba129cdc6aa72ddcef4b634ca05bb" fullyQualifiedName="NumeroExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="cab4dbf1-394a-4e5c-bb72-3abf1987f5ea" name="NumeroExemplo" type="00972a17-9975-449e-aab1-d26165d51393" description="NumeroExemplo">
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
      <Value>NumeroExemplo</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:Numeric</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de Domain 2 - `TipoFluxoExemplo`

- Perfil: Domain enumerado baseado em as:VarChar, com IDEnumDefinedValues e AddEmptyItem.
- Uso operacional: boa referencia para dominios de selecao controlada e listas de valores declaradas no proprio objeto.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-08-03T13:19:15.0000000Z" checksum="4687298b6e435629a409b96cbb475799" fullyQualifiedName="TipoFluxoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ddeec0aa-63a3-450d-bd91-cb44da9360c5" name="TipoFluxoExemplo" type="00972a17-9975-449e-aab1-d26165d51393" description="Tipo Fluxo Exemplo">
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
      <Value>TipoFluxoExemplo</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:VarChar</Value>
    </Property>
    <Property>
      <Name>Length</Name>
      <Value>40</Value>
    </Property>
    <Property>
      <Name>AttMaxLen</Name>
      <Value>40</Value>
    </Property>
    <Property>
      <Name>IDEnumDefinedValues</Name>
      <Value>EntradaSimples, EntradaSimples, Entrada Simples; SaidaSimples, SaidaSimples, Saida Simples; AjusteInterno, AjusteInterno, Ajuste Interno; MovimentoAuxiliar, MovimentoAuxiliar, Movimento Auxiliar; ProducaoInterna, ProducaoInterna, Producao Interna; TransferenciaSaida, TransferenciaSaida, Transferencia de Saida; TransferenciaEntrada, TransferenciaEntrada, Transferencia de Entrada; ConsumoInterno, ConsumoInterno, Consumo Interno; Inventario, Inventario, Inventario; Reprocessamento, Reprocessamento, Reprocessamento</Value>
    </Property>
    <Property>
      <Name>AddEmptyItem</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Theme, PackagedModule, DesignSystem e ColorPalette

- Evidência direta: o acervo usado nesta base contem 7 objetos Theme, 16 PackagedModule, 2 DesignSystem e 1 ColorPalette.
- Inferência forte: nesses tipos pequenos vale mais registrar moldes completos representativos do que tentar classificacoes muito finas por familia.

### Molde sanitizado de Theme - `ThemeExemploMobile`

- Perfil: Theme mobile com PredefinedTypes, KmwSchemaVersion e conjunto grande de classes visuais.
- Uso operacional: boa referencia para temas de plataforma e estilos visuais baseados em classes internas.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T16:08:29.0000000Z" checksum="4f94c975e75fa53cc0a01dceeefd6fb8" fullyQualifiedName="ThemeExemploMobile" moduleGuid="00000000-0000-0000-0000-000000000000" guid="62516c42-4e89-428c-87ef-2a006971b9b4" name="ThemeExemploMobile" type="c804fdbd-7c0b-440d-8527-4316c92649a6" description="Theme Exemplo Mobile">
  <BaseImagePath />
  <TemplateName />
  <Part type="c31007a6-01d3-4788-95b3-425921d47758">
    <KmwSchemaVersion>3</KmwSchemaVersion>
    <PredefinedTypes>
      <Type ID="Application">
        <Default>Application</Default>
      </Type>
      <Type ID="ApplicationBars">
        <Default>ApplicationBars</Default>
      </Type>
      <Type ID="Animation">
        <Default>Animation</Default>
      </Type>
      <Type ID="Form">
        <Default>Form</Default>
      </Type>
      <Type ID="Attribute">
        <Default>Attribute</Default>
      </Type>
      <Type ID="Button">
        <Default>Button</Default>
      </Type>
      <Type ID="Menu">
        <Default>Menu</Default>
      </Type>
      <Type ID="MenuItem">
        <Default>MenuItem</Default>
      </Type>
      <Type ID="Grid">
        <Default>Grid</Default>
      </Type>
      <Type ID="GridRow">
        <Default>GridRow</Default>
      </Type>
      <Type ID="Group">
        <Default>Group</Default>
      </Type>
      <Type ID="GroupSeparator">
        <Default>GroupSeparator</Default>
      </Type>
      <Type ID="HorizontalLine">
        <Default>HorizontalLine</Default>
      </Type>
      <Type ID="Image">
        <Default>Image</Default>
      </Type>
      <Type ID="Multimedia">
        <Default>Multimedia</Default>
      </Type>
      <Type ID="Progress">
        <Default>Progress</Default>
      </Type>
      <Type ID="Tab">
        <Default>Tab</Default>
      </Type>
      <Type ID="TabPage">
        <Default>TabPage</Default>
      </Type>
      <Type ID="Table">
        <Default>Table</Default>
      </Type>
      <Type ID="TextBlock">
        <Default>TextBlock</Default>
      </Type>
      <Type ID="AudioController">
        <Default>AudioController</Default>
      </Type>
      <Type ID="Matrix">
        <Default>Matrix</Default>
      </Type>
      <Type ID="MatrixAxisLabel">
        <Default>MatrixAxisLabel</Default>
      </Type>
      <Type ID="Rating">
        <Default>Rating</Default>
      </Type>
      <Type ID="Calendar">
        <Default>Calendar</Default>
      </Type>
      <Type ID="PageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="Slider">
        <Default>Slider</Default>
      </Type>
      <Type ID="MapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="MapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="MapPolygon">
        <Default>MapPolygon</Default>
      </Type>
      <Type ID="Switch">
        <Default>Switch</Default>
      </Type>
      <Type ID="ToggleButtonGroup">
        <Default>ToggleButtonGroup</Default>
      </Type>
      <Type ID="SDPageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="SDSlider">
        <Default>Slider</Default>
      </Type>
      <Type ID="SDMapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="SDMapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="Dashboard">
        <Default>Dashboard</Default>
      </Type>
      <Type ID="DashboardOption">
        <Default>DashboardOption</Default>
      </Type>
    </PredefinedTypes>
    <Styles>
      <GxClass Name="AttributeTitle" Description="Attribute Title" Guid="8a58438a-f492-5f73-99cf-55a2841b213b">
        <Properties>
          <sd_font_size>18dip</sd_font_size>
          <sd_font_style />
        </Properties>
      </GxClass>
      <GxClass Name="AttributeSubtitle" Description="Attribute Subtitle" Guid="9cc07d44-616e-5dfa-8772-15c59fa18c2e">
        <Properties>
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="Button" Description="Button" Guid="abd2de3e-1c96-5681-b52b-bbe33c0dca49">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>#9E9E9E</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>12dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>12dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>12dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>12dip</sd_border_bottom_right_radius>
          <background_color>White</background_color>
          <highlighted_background_color>#0070ED</highlighted_background_color>
          <color>Black</color>
          <highlighted_color>White</highlighted_color>
          <sd_font_size>14dip</sd_font_size>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
      <GxClass Name="Grid" Description="Grid" Guid="e4351147-2c00-5e86-a86c-1b1683dce3d8">
        <Properties>
          <ThemeGridOddRowClassReference>GridRowOdd</ThemeGridOddRowClassReference>
          <ThemeGridEvenRowClassReference>GridRowEven</ThemeGridEvenRowClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="Group" Description="Group" Guid="5b6cae15-fc08-5644-a800-3bafa192ec88">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>8dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>8dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>8dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>8dip</sd_border_bottom_right_radius>
          <ThemeCaptionClassReference>TextBlockGroupCaption</ThemeCaptionClassReference>
          <ThemeGroupSeparatorClassReference />
          <background_color>white</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="HorizontalLine" Description="Horizontal Line" Guid="1fd49dd6-9a67-5da8-9cec-86596e45e98e">
        <Properties>
          <background_color>Silver</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="Tab" Description="Tab" Guid="41ccdaf1-69f2-55ac-aebd-c82c6cb8c06e">
        <Properties>
          <ThemeSelectedTabPageClassReference>TabPageSelected</ThemeSelectedTabPageClassReference>
          <ThemeUnselectedTabPageClassReference>TabPageUnselected</ThemeUnselectedTabPageClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TableDetail" Description="Table Detail" Guid="f29ce968-0c51-5789-b72a-b00938eb43b7">
        <Properties>
          <background_color>#E0E0E0</background_color>
          <sd_padding_bottom>10dip</sd_padding_bottom>
          <sd_padding_left>10dip</sd_padding_left>
          <sd_padding_right>10dip</sd_padding_right>
          <sd_padding_top>10dip</sd_padding_top>
        </Properties>
      </GxClass>
      <GxClass Name="TableSection" Description="Table Section" Guid="d97cfb58-0788-504c-8882-0413e104c009">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_radius>12dip</sd_border_radius>
          <background_color>White</background_color>
          <sd_row_horizontal_line_separator_table>True</sd_row_horizontal_line_separator_table>
          <ThemeHorizontalLineClassReference>HorizontalLine</ThemeHorizontalLineClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlock" Description="Text Block" Guid="27607de1-bd65-5b1b-99b8-9db711c42fc6">
        <Properties>
          <color />
        </Properties>
      </GxClass>
      <GxClass Name="CalendarLabel" Description="Calendar Label" Guid="b4e3175c-0c31-5e1d-9195-4b737ad6ff2d">
        <Properties>
          <sd_font_size>34dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockTitle" Description="Text Block Title" Guid="abae902b-d82f-59c6-a3f8-52de01a4a9f2">
        <Properties>
          <color />
          <sd_font_size>18dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockSubtitle" Description="Text Block Subtitle" Guid="ae4cb8a2-9d3d-5a1c-b8b1-427ef274d83f">
        <Properties>
          <color />
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockGroupCaption" Description="Text Block Group Caption" Guid="a7187aa1-d84c-57b0-a3cb-d2942a7818c9">
        <Properties>
          <color>White</color>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
    </Styles>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="43b86e51-163f-44af-ac5a-e101541b1a71">
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
      <Value>ThemeExemploMobile</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Theme Exemplo Mobile</Value>
    </Property>
    <Property>
      <Name>ThemeType</Name>
      <Value>idSD</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de PackagedModule - `PacoteExemplo.Servicos`

- Perfil: PackagedModule enxuto, organizado como modulo filho com poucos Part type estruturais.
- Uso operacional: boa referencia para empacotamento modular simples sem conteudo interno complexo.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T21:48:25.0000000Z" checksum="" fullyQualifiedName="PacoteExemplo.Servicos" moduleGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" guid="4b14738c-7611-4134-ab88-db7d218c8353" name="Servicos" type="c88fffcd-b6f8-0000-8fec-00b5497e2117" description="Servicos" parent="PacoteExemplo" parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117">
  <Part type="ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc">
    <Properties />
  </Part>
  <Part type="a5e6a251-2df0-44d8-adab-1da237574326">
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>Servicos</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de DesignSystem 1 - `DesignSystemExemploAuth`

- Perfil: DesignSystem enxuto com Styles e imports externos basicos.
- Uso operacional: boa referencia para design system pequeno e focado em overrides localizados.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="GeneXus" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-09-09T13:56:53.0000000Z" checksum="5d6c8e1c33b0aec4d2e8aa9471ab0656" fullyQualifiedName="DesignSystemExemploAuth" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="3050c016-2f23-456f-875c-afc6c6c52aa1" name="DesignSystemExemploAuth" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="Design System Exemplo Auth" parent="PastaExemploDesignSystem" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles DesignSystemExemploAuth
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    .table-login{
        width: 380px;
        padding: 40px 35px 40px 35px;
    }
    .cell-padding-top-label{
        padding-top: 8px;
    }
    .button-add-grid{
        @include Button;
        margin-bottom: -30px !important;
        z-index: 1 !important;
    } 

    .cell-ispassword{
        max-height: 1.5em;
        overflow: hidden;
    }
}

]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
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
      <Value>DesignSystemExemploAuth</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Design System Exemplo Auth</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>DesignSystem_Samples-web</Categories>
</Object>
` 

### Molde sanitizado de DesignSystem 2 - `dsExemploBase`

- Perfil: DesignSystem mais rico, com 	okens, Styles, imports e muito CSS/Sass customizado.
- Uso operacional: boa referencia para design system extenso com ajustes de layout, componentes e comportamento visual.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-19T15:55:10.0000000Z" checksum="06b5dabbb64ab6e177b8a976cdd4d07f" fullyQualifiedName="dsExemploBase" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ebbe998c-b28d-4173-a685-d41208d4ce72" name="dsExemploBase" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="ds Exemplo Base">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[tokens Name {

	#colors
	{
        
        #region Unanimo_Colors
            //primary: #696ef2;
            //secondary: rgba(128 , 0, 6, 1); //#13142c;
        #endregion

        #region Background_Colors
            ///surface: #ffffff;
        #endregion



        //primary-enabled: $colors.primary; 
        //secondary-enabled: $colors.secondary;

        //primary-active: #3015b0;
        //primary-hover: #413cd4;

        //secondary-active: rgba(128 , 0, 6, 1);
        //secondary-hover: rgba(192, 0, 0, 1);

		AzulClaro: #abc;

		//VermelhoEscuro: rgba(173, 8, 8);
        
	}
}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles dsExemploBase
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    //@import PackageExemploReports.QueryViewer;
    //@import PackageExemploReports.DashboardViewer;

    //nao salvou o problema do conteudo do tab nao aparecer sem clicar.
    //.tab-displayblock{
    //    @include Tab;
    //    display: block;
    //}

    //Para resolver a falta do fundo do item clicado num Dynamic List Box no Google Chrome
    select option {
        background-color: white; //gainsboro; //lightgray;
        color: black;
    }
    select option:checked {
        background-color: dodgerblue; //#007bff;
        color: white;
    }

    DIV.gx-mask
    {
            position: absolute;
            background-color: black;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            animation: entermask 1s;
            -webkit-animation: entermask 1s;
            //opacity: $opacity.mask-opacity;

            z-index: 99;

            background-image: gx-image(Loading_Icon_Exemplo); //(LoadingResults);
            background-repeat: no-repeat;
            background-size: 33%;
            -ms-filter: "alpha(opacity=10)";
            opacity: .20;
            display:inline-block;                      
            background-position: top; //0% 0%;
        }
    .form-group {
        margin-bottom: 1px;
    }

    //usado pelo menos em tables de web components como wcVolumeMovimentos, tambem em transacoes
    .form-horizontal .form-group {
        margin-inline-start: 15px;
        margin-inline-end: 15px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em transacoes
    .form-horizontal .form-container .form-group {
        margin-inline-start: 0px;
        margin-inline-end: 0px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em webpanels com cad-basico
    .form-horizontal .Card-Basico .form-group {
        margin-inline-start: -5px;
        margin-inline-end: -5px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    // .gx-form-group {
    //     margin-bottom: 1px;
    // }

    // .form-control-static {
    //     padding-block: 0px;
    //     min-height: 15px;
    //     width: auto !important;
    // }

    //resolve o problema de linha vazia gastar espaco, em campos escondidos de transacoes.
    .col-xs-12.form__cell{
        display:contents !important;
        padding-block: 1px;
    }

    //faz quebrar o texto do cabeÃ§alho de grid como a aba de estoque movto diario de produto
    ///.gx-tab-padding-fix-1.GridTitle{    
    ///    white-space: normal !important;
    ///}

     //.gx-tab-spacing-fix-2.Grid.table-responsive{

     //.gx-grid.gx-standard-grid{
     //    text-align: left;
     //}

    //nao resolveu o problema do prompt no filtro do ww
    // .gx-prompt {
        
    //     content: gx-image(PackageExemploUI.prompt_light); 
    //     z-index: 0;
    //     width: 50px;
    //     height: 50px;

    // }

    //nao funcionou pra resolver o popup no ios
    //.gx-responsive-popup {
    //    height: auto;
    //}
        
    //para permitir popup em iOS    
    @media screen and (max-width: 767px) {
        .gx-responsive-popup.gx-popup {
            height: auto;
        }
        .gx-responsive-popup .gx-popup-content > iframe {
            height: auto;
        }
    }

    .gx-freestyle-grid{
        padding-block: 0px;
        min-height: 15px;
    }

    // .gx-grid .gx-standard-grid {


    // }

   .gx-action-group {
        display: flex; //Ativa Flexbox, permitindo organizaÃ§Ã£o dinÃ¢mica de elementos.
        flex-wrap: wrap; //Permite que os elementos quebrem para a prÃ³xima linha quando o espaÃ§o horizontal acabar.
        justify-content: flex-start; /* Alinha os itens Ã  esquerda */
        gap: $spacing.inline-xl; //usado para definir o espaÃ§amento entre os itens dentro de um container flex
    }

    .gx-grid-paging-bar {
        justify-content:center;
    }


    //.FreeStyleGrid{
        //line-height: 1;
    //}

    // .attribute-label {
    //     padding-top: 0px;
    // }

    //no carmime tem para a classe
    //gx-label col-xs-8 col-sm-3 col-md-2 col-lg-12 AttributeLabel control-label
    //text-align: left!important;

    //legenda de atributo em caso mais especifico, mas alem da transacao
    //.gx-label.col-sm-3.AttributeLabel.control-label {
    //      text-align: right;
    //}

    //nao funciona
    //.form-group.gx-form-group > label.gx-label.col-sm-3.AttributeLabel.control-label {
    //    text-align: right;
    //}
    
    //nao Ã© especifico o sufiente, pra funcionar apenas pra crud de transacao
    //.form-group.gx-form-group label.gx-label.col-sm-3.AttributeLabel.control-label {
    //     //text-align: right;
    //     color: red;
    //}

    //legenda dos campos de atributo , em transacao ou webpanel qualquer
    .gx-label.AttributeLabel {
        padding-top: 0px;
    }
    //ajuste da legenda dos campos da transacao
    .form-container .gx-label.AttributeLabel {
        text-align: right;
        padding-right: 0px;
        padding-left: 0px;
    }

    //legenda dos campos das transacoes, da aba geral
    .gx-label.ReadonlyAttributeLabel {
        padding-top: 0px;
        //text-align: right;
    }

    //usado em legenda de atributo de transacao, na aba geral do ww da transacao
    .form__cell .ReadonlyAttributeLabel {
        padding-inline-start: 15px;
        padding-inline-end: 3px;
        padding-block-start: 1px;
        text-align: right;
    }

    //usado em atributo de transacao, na aba geral do ww da transacao
    .form__cell .form-control-static {
        padding-block: 1px;
        min-height: 15px;
    }

    //Usado em transacao, junto aos atributos. Tambem em TransacaoGeneral, junto aos atributos
    .form__cell {
        padding-block: 1px;
    }
    //usado em transacao, junto aos atributos
    .form__cell-advanced {
        padding-block: 1px;
    }


    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //desligado em 13/05/2025 para depender de outro recurso
    //.Attribute[data-gx-readonly] {
    //   overflow-wrap:normal;
    //}

    ///faz quebrar linha por padrao em grid do ww
    ///.Attribute[data-gx-readonly]{
    ///    white-space: normal;
    ///    overflow-wrap:normal !important;
    ///}

    //funciona pra aba cadastros externos nao ficar com largura fixa nas colunas
    ///.gx-tab-spacing-fix-2.ViewGrid.table-responsive{
    ///    table-layout: auto;
    ///    display:table-caption; 
    ///    white-space:normal !important;
    ///}


//     .ActionButtons {
//     height: 25px;
// }
//     .HideFiltersButton{
//         margin-top: 0px;
//     }

//     .ShowFiltersButton {
//         margin-top: 0px;
//     }



    //usado em tables de filtros do work with, principalmente em grids ww de transacao
    .filters-container--visible {
        top:00;
        padding-inline-start: 10px;
        padding-inline-end: 10px;
    }
    @media screen and (max-width: 767px) {
        .filters-container--visible {
            
            top: 140px;
            max-height: 500px;
            min-height: calc(100vh - 220px);
            overflow-y: auto;
            margin-bottom: 80px; 

            //inset-inline-end: 1px;
            //inset-inline-start: 16px;

            //max-width: 100%;
            //box-sizing: border-box;

            //max-width: 90%;
            //width: 519px; //90%;

        }

        //usado nos filtros verticais do ww transacao
        .ww__filters-cell .filters-container--visible .col-xs-12 {

            justify-content: left;

        }

    }

    // //539px de largura no google chrome do Thinkphone.
    // @media screen and (min-width: 539px) and (max-width: 767px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 519px; //90%;

    //     }
    // }
    // //462 no edge do thinkphone
    // @media screen and (min-width: 462px) and (max-width: 538px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 442px; //90%;

    //     }
    // }
    // //390 google chrome no lg g8
    // @media screen and (min-width: 390px) and (max-width: 461px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 370px; //90%;

    //     }
    // }
    // //378 no firefox do thinkphone
    // @media screen and (min-width: 378px) and (max-width: 389px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 358px; //90%;

    //     }
    // }

    
    .TextblockLargeLink {
        @include TextblockLarge;
        color: $colors.AzulClaro;
    }

    .HeaderContainer {
        height: 60px;
    }

    //usado em filtros nos grids ww, como legenda
    .filter-item__label {
        
        //original
        font-family: $fonts.primary-semibold;
        color: $colors.on-background;
        position: relative;
        gx-text-block-link-class: filter-item__link;

        //ajuste
        //color: red;
        height: auto;

    }
    //conteudo
    .filter-item__label strong {
        
        //original
        //font-weight: normal;
        font-family: $fonts.primary-regular;
        padding-inline-start: 5px;

        //ajuste
        font-weight: bold;
        color: blue;
        
        ///nao funciona com padding-inline-start
        ///height: auto;

    }

    //para funcionar prompt em filtros no ww
    .filter-item__cell .input-group span.input-group-btn .btn {
        height: 28px;
        content: gx-image(PackageExemploUI.prompt_light); 
    }

    ///desligado porque parece estar atrapalhando.
    // //para para ww mostrar icone de esconder/mostrar um pouco mais longe do texto
    // .filters-container__item {
    //     padding-right: 11px;
    //     ///height: auto;
    // }
    // .filters-container__item--expanded {
    //     padding-right: 11px;    

    //     //z-index: -1; //nao resolve o problema do prompt no filtro do ww
    //     //position: relative; estraga tudo.
    // }

    // //par para ww esconder e mostrar direito o calendario
    // .filters-container__item .calendar.Calendar {
    //         display:none !important;
    // }
    // .filters-container__item--expanded .calendar.Calendar {
    //         display:block !important;
    // }

    .Grid tr:nth-child(even) {
        background-color: LightGray;
    }

    .Grid th {
        background-color: LightGray;
    }

    // .Grid-Basico {
    //     @include Grid;
    //     //gx-grid-odd-row-class: Grid-Basico-FundoCinza;
    // }
    // .Grid-Basico tr:nth-child(even) {
    //     background-color: Gray;
    // }
    // .Grid-Basico-FundoCinza {
    //     @include Grid;
    //     background-color: Gray;
    // }

    //funciona mudar, mas nao precisou
    // .Title
    // {
     
    //      //original
    //      font-size: $fontSizes.xl;
    //      font-family: $fonts.primary-bold;
    //      display: inline-block;
    //      //color: $colors.on-background;

    //     //ajuste
    //     color: red;

    // }

    .TableTop {
        
        //Original
        margin-bottom: $spacing.stack-l;

       //Ajuste
       //column-gap: $spacing.inline-xl;

    }

    // //table do topo da tela do ww quando ainda usa layout carmine
    .TableTopSearch {
         
        @include TableTop; 
        
        //nao adianta colocar mais nada, pois o form layout carmine usa colunas fixas
        //background-color: red;
        
    }
    //@media screen and (max-width: 767px) {
    //    .TableTopSearch {
    //        ;
    //    }
    //}

    .Card-Basico {
        @include Table;
        //border: 1px solid $colors.gray02;

        background-color: White;
        box-shadow: 1px 1px 1px 0px DarkGray;

        border-style: solid;
        border-width: 1px;
        border-radius: 5px;
        border-color: DarkGrey;

        padding-left: 5px;
        padding-right: 5px;
        padding-top: 2px;
        padding-bottom: 2px;
        
        margin-bottom: 2px;
        margin-top: 2px;

        line-height: 1.14;

    }
    .CardPesando {
        @include Card-Basico;
        background-color: LightGrey;

    }
    .CardErro {
        @include Card-Basico;
        background-color: Thistle;

    }
    .CardNovo {
        @include Card-Basico;
        background-color: AliceBlue;

    }
    .CardCarregado {
        @include Card-Basico;
        background-color: LightYellow;

    }
    .CardSalvo {
        @include Card-Basico;
        background-color: Lavender;

    }


    .Button {
        white-space: normal;
        height: auto; //28px;
        padding-inline-start: $spacing.inset-m;
        padding-inline-end: $spacing.inset-m;
        border-radius: $radius.l;
        min-width: auto; //80px;

        //button primary defaults
        background-color: $colors.primary;
        font-size: $fontSizes.s;
        font-family: $fonts.primary-semibold;
        color: $colors.on-primary;
        text-transform: uppercase;
        border: solid $borders.extra-small;

        gx-button-hovered-class: button-primary--hover;
        gx-button-focused-class: button-primary--focused;
        gx-button-highlighted-class: button-primary--active;
        gx-button-disabled-class: button-primary--disabled;

    }

    //.Button_2xHeight {
    //    @include Button;
    //    height: 56px;
    //}
    .ButtonHtmlExtensao {
        @include Button;
    }

    .Altura_64px {
        height: 64px;
    }

    .Altura_100px {
        height: 100px;
    }

    .Largura_64px {
        width: 64px;
    }

    .Largura_100px {
        width: 100px;
    }
    
    .LarguraMinima_50px {
        min-width: 50px;
    }

    .LarguraMinima_85px {
        min-width: 85px;
    }

    .LarguraMinima_100px {
        min-width: 100px;
    }

    .LarguraMinima_150px {
        min-width: 150px;
    }

    .LarguraMinima_200px {
        min-width: 200px;
    }

    .LarguraMinima_250px {
        min-width: 250px;
    }

    .LarguraMinima_300px {
        min-width: 300px;
    }

    .LarguraMaxima_250px {
        max-width: 250px;
    }

    #region varia pelo tamanho da tela
    
    //padrao pra telas acima de 1600px ( mas testando em 1920 px de largura )
    .LarguraMinima_ConformeTela {
        min-width: 450px;
    }

    //padrao pra telas de 1200 atÃ© 1599 px ( mas testando em 1366 px de largura )
    @media screen and (min-width: 1200px) and (max-width: 1599px) {
        .LarguraMinima_ConformeTela {
            min-width: 300px;
        }
    }

    //padrao pra telas de 992 atÃ© 1199 px ( mas testando em 1024 px de largura )
    @media screen and (min-width: 992px) and (max-width: 1199px) {
        .LarguraMinima_ConformeTela {
            min-width: 150px;
        }
    }

    //padrao pra telas de 768 atÃ© 991 px ( mas testando em 800 px de largura )
    @media screen and (min-width: 768px) and (max-width: 991px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    //@media (max-width: 767px) {
    //padrao pra telas atÃ© 767 px  ( mas testando em 360 px que imita celular em retrato )  
    @media screen and (max-width: 767px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    #endregion

    .Largura_AjustaPeloConteudo {
        width: fit-content;
    }

    // //toda tentativa falhou, nao escondendo o date picker
    // .DatePickerDesligado {
    //     //pointer-events: none;   //evitaria clicar no campo
    //     //appearance: textfield; /* Remove o estilo de datepicker */
    //     gx-hide-date-time-picker: True;
    // }

    #region Classes para Column Class

        .WWColumn {
            @include column;
            overflow: hidden;
        }        
        .WWColumnTamanhoLimitado {
            @include WWColumn;
            max-width: 150px;
        }

        .WWColumnTamanhoLimitado100px {
            @include WWColumn;
            max-width: 100px;
        }

        .WWColumnTamanhoLimitado75px {
            @include WWColumn;
            max-width: 75px;
        }

        .WWOptionalColumnTamanhoLimitado300 {
            
            @include column;
            max-width: 300px;

        }
        @media screen and (max-width: 767px) {

            .WWOptionalColumnTamanhoLimitado300 {
                
                //@include OptionalColumn; //nao deixa incluir
                display: none;

            }

         }

    #endregion

    //funciona pra aba cadastros externos nao ficar fixa
    .gx-tab-spacing-fix-2.ViewGrid.table-responsive{
        table-layout: auto;
        display:table-caption; 
        white-space:normal !important;
    }

    .ww__grid {
       table-layout: auto;
       
       display:table-caption; //tira o espaco extra na primeira coluna e deixa de fora, Ã  direita do grid.
       
       //width: auto; //nao resolveu
    }
    .ww__grid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ww__grid th {
        background-color: LightGray;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab {
       height: 5px;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab .tab-content {
        padding: 0px;
        padding-top: 5px;
        padding-bottom: 5px;
        padding-left: 0px;
        padding-right: 0px;
    }
        
    //usado no tab de abas do view transaction com ww web    
    .ww__view__tab__form-container {
        padding-inline-start: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
        padding-inline-end: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
    }

    // .gx_usercontrol gx-basic-tab ww__view__tab {
    //     //height: 12px;
    //     padding: 0px;
    // }

    // .div.ww__view__tab UL.nav-tabs {
    //     height: 12px;
    // }

    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI A {
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI {
        //height: 12px;
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs {
        //height: 12px;
        margin-top: 0px;
    }

    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table { 
        height: 22px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .heading-01 {
        font-size: 14px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .form-control-static {
        
        height: 14px;
        min-height: 14px;
        max-height: 14px;
        padding-block: 0px;

    }


    // //para os campos de dados fixos das Views das transacoes com Work With Web
    // //tambem serve pra ww de transacacoes, pra mostrar o nome da pagina com o grid
    // //tambem pra paginas de edicao de transacoes
    // .heading-01 {
    //     font-size: 12px;
    // }

    //usado no table top do transacao general com ww web, pra mostrar link pra voltar pro grid
    .ww__actions-container {
        margin-bottom: 0px;
    }

    //container do grid em objetos ww
    // .ww__grid-container {
    //     width: auto;
    // }

    //usado em tables de grid do work with
    .ww__grid-cell--expanded .container-fluid {
        padding-inline-start: 1px;
    }

    .WorkWith,.PromptGrid,.ViewGrid {
        
        //original unanimoweb
        text-align: start;
        //table-layout: fixed;
        border-collapse: collapse;

        //ajustado
        table-layout: auto;
        display:table-caption; 
        width:auto;

    }
    .WorkWith tr:nth-child(even) {
        background-color: LightGray;
    }
    .WorkWith th {
        background-color: LightGray;
    }
    .PromptGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .PromptGrid th {
        background-color: LightGray;
    }
    .ViewGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ViewGrid th {
        background-color: LightGray;
    }

    .DescriptionAttribute a{
        
        //original unanimoweb
        color: $colors.primary-enabled; 
        text-decoration: underline;

        //ajustado
        white-space: nowrap;

    }
    .DescriptionAttribute a:hover {
        
        //original unanimoweb
        color: $colors.border-primary-hover;

        //ajustado
        white-space:normal;

    }

    .Attribute {

        //Original
        // min-height: 28px;
        // max-width: 100%;
        // font-family: $fonts.primary-regular;
        // font-size: $fontSizes.s;
        // padding-inline-start: $spacing.inset-s;
        // padding-inline-end: $spacing.inset-s;
        // border-color: $colors.gray04;
        // color: $colors.on-background;
        // background-color: $colors.attribute-bg;
        // border-radius: $radius.l;
        // gx-attribute-focused-class: AttributeFocusedClass;
        // gx-readonly-class: ROAttribute;
        // gx-label-class: attribute-label;
        // gx-datepicker-image-class: datepicker-image;
        // gx-prompt-image-class: gx-prompt;

        //Ajustes
        white-space: nowrap; //nao quebra em linhas, igual estÃ¡ no carmine
        
        //nao funciona
        //gx-hide-date-time-picker: True;

    }

    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //.AttributeQuebraLinha[data-gx-readonly] {
    //   overflow-wrap:normal !important;
    //}

    
    //resolve o problema de largura 100% em campo de transacao unanimo chamada de pagina do carmine
    .Attribute.form-control{
     
        @include Attribute;
     
        width: auto !important;

        height:auto;

    }
    
    //coluna em wwgrid para atributo marcado como descricao
    .attribute-description {
        white-space: nowrap; //nao quebra em linhas
    }

    .AttributeTextoPreservado {
        white-space: pre;
    }
    
    .AttributeQuebraLinha {
        @include Attribute;
        
        white-space: normal !important;
        
        //overflow-wrap:normal !important; //funciona, mas sobra espaco na linha
        overflow-wrap:break-word !important;
        
        //display: inline-block; //nao ajuda a melhorar a quebra
        //min-width: 300px; //nao funciona aqui

    }

    .AttributeQuebraLinhaApenasAteWidth1199px {
        
        @include Attribute;
        
    }
    @media screen and (max-width: 1199px) {

        .AttributeQuebraLinhaApenasAteWidth1199px {
            
            min-height: 28px;
            max-width: 100%;
            font-family: $fonts.primary-regular;
            font-size: $fontSizes.s;
            //padding-inline-start: $spacing.inset-s;
            //padding-inline-end: $spacing.inset-s;
            //border-color: $colors.gray04;
            //color: $colors.on-background;
            //background-color: $colors.attribute-bg;
            //border-radius: $radius.l;
            //gx-attribute-focused-class: AttributeFocusedClass;
            //gx-readonly-class: ROAttribute;
            //gx-label-class: attribute-label;
            //gx-datepicker-image-class: datepicker-image;
            //gx-prompt-image-class: gx-prompt;
            
            white-space: normal !important;
            overflow-wrap:break-word !important;

        }

    }

    //usada pelo ww com form layout carmine
    .FilterAttribute {
        
        @include Attribute;
        //overflow: hidden;

        //copiado de attribute-filter:
        //gx-label-class: attribute-label;
        width: 100%;
        //font-family: $fonts.primary-regular;
        //font-size: $fontSizes.s;
        padding-inline-start: $spacing.inset-s;
        padding-inline-end: $spacing.inset-s;
        //gx-attribute-focused-class: AttributeFocusedClass;
        //background-color: $colors.attribute-bg;

    }
    //usada pelo ww com form layout carmine
    .FilterComboAttribute {
        
        @include FilterAttribute;

    }

    // .WWAdvancedLabel {
    //     color: red;
    // }
    // .WWFilterLabel {
    //     color: blue;
    // }


    .AttributeSenha {
        @include Attribute;
        -webkit-text-security:disc !important;
    }

    .AttributeAvisos {
        @include Attribute;
        height: auto;
        width: auto;
    }

    .AttributeMessagesNormal{
        //@include Attribute;
        color: ForestGreen !important;
    }

    .AttributeMessagesAlertaExtremo{
        //@include Attribute;
        color: OrangeRed !important;

    }

    .AttributeMessagesAlerta{
        //@include Attribute;
        color: DarkOrange !important;
    }

    .AttributeMessagesErro{
        //@include Attribute;
        color: rgb(210, 4, 45) !important;

    }

    .AttributeMessagesInfo{
        //@include Attribute;
        color: Black !important;

    }

    .AttributeMessagesSeparador{
        //@include Attribute;
        color: Silver !important;
        background-color: Silver !important;

    }


    // .column {
    //     @include column;
    //         width: 100%;  
    //         padding-inline-start: $spacing.inset-s;
    //         padding-inline-end: $spacing.inset-s;
    //         border-bottom-width: 1px;
    //         border-bottom-color: $colors.gray01;
    //         border-bottom-style:solid;
    //         gx-grid-column-header-class: column;
    // } 

    //.GridColuna-Opcional {
    //    overflow: hidden;  //NAO ESCONDE COISA NENHUMA !
    //    color: $colors.on-background;
    //}

    // .blink {
    // animation: blink 1s steps(1, end) infinite;
    // }
    .blink {
    animation: blink 1s infinite;
    }

    @keyframes blink {
        0% {
            opacity: 1;
            }
        50% {
            opacity: 0;
        }
        100% {
            opacity: 1;
        }
    }

}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/design-system-migration]]></InnerHtml>
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
      <Value>dsExemploBase</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

` 

### Molde sanitizado de ColorPalette - `PaletteExemplo`

- Perfil: ColorPalette simples, com conjunto de cores nomeadas em PaletteColors.
- Uso operacional: boa referencia para paletas enxutas baseadas apenas em nomes e cores hexadecimais.

`xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-08-16T16:51:47.0000000Z" checksum="2ccb44e8b9d067e4056a4eae8fa03a75" fullyQualifiedName="PaletteExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7bdd2542-2a09-4884-90d6-e1dafe4a4391" name="PaletteExemplo" type="3affc0b3-494b-4d84-9ec1-3a6ab8349cda" description="PaletteExemplo">
  <Part type="5d481862-64bc-4e88-8af2-e21c276dab77">
    <PaletteColors>
      <PaletteColor name="Text" color="#2A3143" />
      <PaletteColor name="Base" color="#2457A7" />
      <PaletteColor name="DarkBase" color="#163B72" />
      <PaletteColor name="Dominant" color="#9FD3FF" />
      <PaletteColor name="Read Only Text" color="#EAEAEA" />
      <PaletteColor name="Action" color="#0C8C74" />
      <PaletteColor name="SecondaryAction" color="#5B6EF5" />
      <PaletteColor name="Border" color="#EFEFEF" />
      <PaletteColor name="DarkBorder" color="#B7B7B7" />
      <PaletteColor name="Background" color="#F9F9F9" />
      <PaletteColor name="MessageBackground" color="#FFFEBC" />
      <PaletteColor name="LightMessageBackground" color="#FFFFE1" />
      <PaletteColor name="RecentLink" color="#3D434F" />
      <PaletteColor name="WarningColor" color="#FF8000" />
    </PaletteColors>
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PaletteExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```
