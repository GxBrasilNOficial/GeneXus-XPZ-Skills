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
