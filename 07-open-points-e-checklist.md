# 07 - Open Points e Checklist

## Papel do documento
governanca e operacional

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md

## Usado por
08-guia-para-agente-gpt.md

## Objetivo
Concentrar pontos em aberto, conflitos, decisoes provisórias e checklist de templates adicionais ou verificacoes futuras.

## Fontes consolidadas
- 04-genexus-open-points.md
- 25-checklist-para-novos-templates.md

## Origem incorporada - 04-genexus-open-points.md

## Papel do documento
conceitual

## Nível de confiança predominante
médio

## Depende de
00-inventario-da-base-documental.md, 01-base-empirica-geral.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md

## Usado por
00-readme-genexus-xpz-xml.md, 26-guia-para-agente-gpt.md, 99-resumo-da-consolidacao.md

## Objetivo
Concentrar lacunas técnicas, conflitos documentais e próximos passos que ainda exigem validação adicional.
Servir como local único para conflitos não resolvidos silenciosamente.

## O que já ficou sólido

- `Evidência direta`: o acervo extraído tem taxonomia estável por diretório e por `Object/@type`.
- `Evidência direta`: há relações aparentes visíveis por `parent`, `parentGuid`, `parentType`, `moduleGuid`, propriedades e referências nominais em código.
- `Evidência direta`: não houve arquivos problemáticos na leitura do conjunto atual.
- `Evidência direta`: a trilha ja contem bateria controlada de importacao real com reconhecimento coerente para `Procedure`, `Domain`, `SDT`, `Data Provider`, `Subtype Group`, `Module`, `External Object`, `Data Store`, `Generator`, `Panel`, `Image`, `Theme Color`, `Document`, `File`, `Language`, `Color Palette`, `Dashboard`, `User Control` e `Stencil`.
- `Evidência direta`: nessa bateria, `Dashboard` chegou a executar geracao de pattern com sucesso apos a importacao.
- `Inferência forte`: a base `.md` local, usada junto com o skill `nexa`, ja e fonte operacional forte para tipos autocontidos ou estruturalmente simples a moderados.

## Pontos ainda abertos

- `Hipótese`: o significado funcional preciso de cada GUID de `Part type` ainda precisa de catálogo semântico por tipo de objeto.
- `Hipótese`: ainda não está provado quais `Part type` são obrigatórios, opcionais ou apenas vazios estruturais em cada família de objeto.
- `Hipótese`: a correspondência entre nomes compactos de diretório e nomes oficiais mostrados na IDE ainda deve ser validada diretamente na KB quando isso for necessário.
- `Hipótese`: a diferença exata entre `Module` e `PackagedModule` no plano funcional ainda não pode ser fechada só com os XMLs extraídos.
- `Hipótese`: ainda falta validar se os padrões observados nesta KB se repetem sem mudança relevante em outros exports GeneXus 18.
- `Evidência direta`: ja houve importacao bem-sucedida, nesta trilha, de um `.xpz` minimo de `Procedure` gerado a partir da propria base documental.
- `Evidência direta`: nesse teste, placeholders textuais em `Source/@kb` e `Source/Version/@guid` causaram erro de parse; GUIDs sintaticamente validos destravaram a importacao.
- `Evidência direta`: ainda nao ha evidência nesta trilha documental de build e execucao a partir de XMLs gerados.
- `Evidência direta`: ja ha evidência nesta trilha documental de importacao bem-sucedida para muitos tipos diferentes, conforme a bateria controlada registrada nesta base.
- `Evidência direta`: o envelope XPZ observado em export real ja foi documentado na base como `<ExportFile>` com `KMW` e `Source` invariantes; o bloco especial de KB (`KnowledgeBase` ou nome literal da KB) aparece apenas em exportacoes especiais/full e nao no formato normal mais frequente de objetos.
- `Evidência direta`: nos exports normais lidos, `ObjectsIdentityMapping` usa `ObjectIdentity` com `Type`, `Name`, `parent` e `Guid` preenchidos; o bloco nao repete os proprios objetos exportados, mas identidades de contexto.
- `Evidência direta`: nos exports normais lidos, `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name` nao apareceram vazios.
- `Inferência forte`: a coerencia mais util entre `<Objects>` e `ObjectsIdentityMapping` ocorre via `parentGuid` e `moduleGuid`, nao via duplicacao de `Object/@guid` dentro do mapeamento.
- `Hipótese forte`: o erro `Fail creating backup: Empty name is not allowed.` esta mais ligado a variantes especiais com `KnowledgeBase` sem `name` do que ao formato normal de `ObjectsIdentityMapping`.
- `Evidência direta`: a pasta local `C:\\Dev\\Test\\from-anywhere-to-GeneXus` usa um envelope minimo com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, sem `KnowledgeBase` nem `Settings`.
- `Inferência forte`: essa fonte local e util como evidencia complementar de envelope minimo, mas nao deve ensinar valores fixos de `Build`, `username`, `kb`, `parentGuid`, `moduleGuid` ou nomes como `SampleKB` e `BusinessLogic`.
- `Inferência forte`: isso fecha a lacuna anterior sobre "como o XPZ é formado" para o formato de export observado nesta trilha.
- `Hipótese`: ainda pode haver variantes de export XPZ nao cobertas por esse unico envelope observado.
- `Evidência direta`: a base consolidada passou a conviver com uma cópia histórica em `docs-kb-md`.
- `Inferência forte`: a raiz deve ser tratada como fonte operacional principal; `docs-kb-md` deve permanecer apenas como histórico de staging para evitar leituras duplicadas.
- `Evidência direta`: `04-webpanel-familias-e-templates.md` ja contem anexos XML sanitizados completos para `WebPanel`.
- `Evidência direta`: `05-transaction-familias-e-templates.md` agora tambem contem anexos XML sanitizados completos para familias representativas de `Transaction`.
- `Evidência direta`: `01-base-empirica-geral.md` agora tambem contem anexos XML sanitizados completos representativos de `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File`.
- `Hipótese`: ainda vale completar `Transaction` com anexos equivalentes para as familias mais densas (`F3` e `F4`) se a meta for cobertura integral so pelos `.md`, sem recorrer ao acervo bruto.
- `Evidência direta`: `Attribute` tem shape top-level comprovado nesta trilha e ja demonstrou importacao bem-sucedida em caso semanticamente fechado.
- `Evidência direta`: `Folder` ficou esclarecido como tipo XML estruturalmente valido, enquanto `Category` e apenas o rotulo de UI/importador.
- `Evidência direta`: `Theme`, `Pattern Settings`, `Transaction` e `Work With for Web` ja possuem receita empirica de sucesso sob dependencias explicitas conhecidas.
- `Evidência direta`: `Design System`, `Deployment Unit` e `Data Selector` tambem ja tiveram casos controlados de sucesso nesta trilha.
- `Evidência direta`: `API` e a camada fisica `Table/Index` concentram o principal restante da engenharia reversa mais sensivel.
- `Inferência forte`: a lacuna dominante agora nao e mais "como serializar o XPZ", e sim "quais referencias e dependencias minimas precisam existir na KB para cada tipo contextual".
- `Inferência forte`: `Theme`, `PatternSettings`, `Transaction`, `Attribute`, `Folder`, `Design System`, `Deployment Unit`, `Data Selector` e `Work With for Web` deixam de ser pendencias estruturais abertas nesta trilha.
- `Inferência forte`: a fronteira principal remanescente se concentra em `API` e na camada fisica `Table/Index`.

## Próximas frentes recomendadas

- `Inferência forte`: vale montar um catálogo dedicado de `Part type` por diretório/tipo extraído.
- `Inferência forte`: vale isolar pares de objetos simples e complexos do mesmo grupo para comparação estrutural.
- `Inferência forte`: vale produzir uma camada de validação cruzando `parent*`, `moduleGuid`, chamadas em código e nomes de objeto.
- `Inferência forte`: antes de corrigir os `.md` dos tipos problemáticos, vale usar a bateria atual para distinguir "erro de molde" de "erro de dependência de KB" em cada tipo.
- `Inferência forte`: a proxima coleta em exemplos reais deve priorizar `API` e os tipos contextuais ainda nao revisitados com dependencias completas; para `Theme`, `PatternSettings` e `Transaction`, a coleta adicional passa a ser de generalizacao e nao de desbloqueio inicial.

## Decisao operacional - Transaction e WebPanel

- `Evidência direta`: o acervo contem 183 `Transaction` e 1196 `WebPanel`.
- `Inferência forte`: ambos ficam desbloqueados para geracao por clonagem interna da propria base, mesmo mantendo risco alto.
- `Inferência forte`: `Transaction` parece mais apta a trabalhar por padrao estrutural inferido.
- `Inferência forte`: `WebPanel` exige leitura por familias estruturais e selecao de molde interno muito proximo.
- `Hipótese`: o impacto esperado e destravar geracao controlada de KB mais ampla, com aprendizado incremental a partir de erros de importacao.


## Origem incorporada - 25-checklist-para-novos-templates.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
04-genexus-open-points.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md

## Usado por
26-guia-para-agente-gpt.md, manutencao futura da base

## Objetivo
Listar o que ainda valeria exportar da IDE real para reduzir lacunas remanescentes.
Orientar futuras coletas de templates comparáveis.

- Inferência forte: para fechar lacunas, ainda vale exportar da IDE exemplos simples e complexos do mesmo tipo.
- Hipótese: os templates abaixo devem reduzir duvidas sobre Part type raros, pattern e dependencia de parent/module.
- Inferência forte: `Transaction` e `WebPanel` ja possuem base suficiente para geracao; novos templates passam a servir como refinamento e nao como pre-requisito.

## Itens sugeridos

- Exportar pelo menos 1 template adicional de API com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de DataProvider com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de DataStore com necessidade baixa, preferindo um datastore padrao e outro com metadados adicionais.
- Exportar pelo menos 1 template adicional de Dashboard com necessidade media, preferindo um caso curto e outro com mais objetos analiticos e filtros.
- Exportar pelo menos 1 template adicional de DeploymentUnit com necessidade baixa, preferindo um caso curto e outro com mais `Member`.
- Exportar pelo menos 1 template adicional de DesignSystem com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de ColorPalette com necessidade baixa, preferindo uma paleta curta e outra com mais tons.
- Exportar pelo menos 1 template adicional de Domain com necessidade baixa, preferindo um caso escalar e outro enumerado mais rico.
- Exportar pelo menos 1 template adicional de ExternalObject com necessidade media, preferindo um caso nativo simples e outro com varios metodos externos.
- Exportar pelo menos 1 template adicional de File com necessidade media, preferindo um asset binario pequeno e outro arquivo textual/configuracional.
- Exportar pelo menos 1 template adicional de Folder com necessidade baixa, preferindo uma pasta simples e outra com propriedades de arvore/consulta.
- Exportar pelo menos 1 template adicional de Generator com necessidade baixa, preferindo um caso default e outro com `DefaultType` diferente.
- Exportar pelo menos 1 template adicional de Language com necessidade media, preferindo um idioma curto e outro com mais chaves de traducao.
- Exportar pelo menos 1 template adicional de Module com necessidade baixa, preferindo um modulo raiz e outro filho.
- Exportar pelo menos 1 template adicional de Image com necessidade media, preferindo um caso com item unico e outro com varias variantes e referencias de tema.
- Exportar pelo menos 1 template adicional de Index com necessidade media, preferindo um caso simples e outro com muitos indices de usuario e combinacoes de ordem.
- Exportar pelo menos 1 template adicional de Document com necessidade baixa, preferindo um caso curto e outro com HTML mais extenso.
- Exportar pelo menos 1 template adicional de DataSelector com necessidade media, preferindo um caso simples e outro com conjunto maior de `Condition` e parametros.
- Exportar pelo menos 1 template adicional de PackagedModule com necessidade baixa, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de PatternSettings com necessidade media, preferindo um caso web e outro mobile com mais contexto de seguranca.
- Exportar pelo menos 1 template adicional de Theme com necessidade baixa, preferindo um tema simples e outro com mais classes visuais.
- Exportar pelo menos 1 template adicional de ThemeClass com necessidade media, preferindo uma classe raiz simples e outra derivada/estado visual.
- Exportar pelo menos 1 template adicional de ThemeColor com necessidade baixa, preferindo uma cor base e outra cor de destaque/estado.
- Exportar pelo menos 1 template adicional de Panel com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Procedure com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de SDT com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Stencil com necessidade media, preferindo um caso visual simples e outro com mais controles e variaveis.
- Exportar pelo menos 1 template adicional de SubTypeGroup com necessidade media, preferindo um caso pequeno e outro mais denso em subtypes derivados.
- Exportar pelo menos 1 template adicional de Theme com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Transaction com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de UserControl com necessidade media, preferindo um caso simples e outro com definicoes/eventos mais ricos.
- Exportar pelo menos 1 template adicional de WebPanel com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de WorkWithForWeb com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar casos em que o mesmo tipo exista com e sem parent.
- Exportar casos em que o mesmo tipo exista com e sem pattern.
- Exportar exemplos onde Part type raro apareca acompanhado de comportamento conhecido na IDE.

## Regras de materializacao

- Evidência direta: novos templates devem ser coletados como XML bruto real, nao como resumo, screenshot ou exemplo sanitizado
- Inferência forte: para `Transaction`, coletar templates simples e complexos da mesma familia estrutural, preservando `parent*`, `moduleGuid` e ordem de `Part`
- Inferência forte: para `WebPanel`, coletar pelo menos um template bruto por familia estrutural relevante, com foco em `menu/home`, `formulario`, `lista/grid` e `eventos`
- Inferência forte: se um template adicional perder atributos do no `<Object>`, `CDATA` ou qualquer `Part` recorrente, ele nao serve como material de materializacao

## Regras de serializacao XPZ

- quando houver variante nova de export, coletar pelo menos um contêiner XPZ bruto real que mostre como o objeto entra em `<Objects>`
- guardar o XML exatamente como exportado, sem reformatar `CDATA` para texto escapado
- validar que cada template abre como XML bem-formado antes de entrar no acervo
- rejeitar template coletado se o envelope externo tiver sido reconstruido manualmente fora do padrao de envelope XPZ observado e documentado nesta base

## Regras de fonte

- Fonte valida para ampliar a base: XML bruto exportado ou extraido diretamente de XPZ real
- Fonte invalida para ampliar a base: markdown, snippets copiados de documentacao, exemplos sanitizados e pseudo-XML produzido por agente
- Inferência forte: `Transaction` e `WebPanel` nao precisam de novos exemplos para desbloqueio operacional, mas qualquer refinamento futuro deve entrar na base como XML bruto, nao como derivacao textual
- Hipótese: `WorkWithForWeb` ja tem anexos representativos suficientes para estudo e prototipo controlado, mas continua sendo um dos melhores candidatos a refinamento por causa da alta dependencia de pattern e parent transacional
- Hipótese: `SDT` ja tem anexos representativos suficientes para prototipos pequenos e medios, mas vale refinar com exemplos adicionais quando houver dependencia forte de namespace, soaptype ou schema externo muito especifico
- Hipótese: `Domain` ja tem anexos representativos suficientes para prototipos escalares e enumerados comuns, mas ainda pode valer ampliar a base se surgirem dominios com metadata mais exotica ou comportamento especial de enumeracao
- Hipótese: `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `DataSelector`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` ja tem anexos representativos suficientes para prototipos controlados, mas `DesignSystem` segue sendo o mais sensivel do grupo por acumular tokens, imports e regras visuais extensas, `ThemeClass` ainda pede cuidado quando a cadeia de heranca visual for mais longa, `ThemeColor` e `ColorPalette` seguem os mais simples do grupo, `Image` pede preservacao rigorosa do binario e das referencias de tema, `Index` pede cuidado forte com a ordem dos `Members` e a distincao entre indices `Automatic` e `User`, `Document` pede apenas atencao ao conteudo HTML e a qualquer dado embutido sensivel, `DataSelector` pede cuidado com variaveis customizadas, parametros e filtros muito especificos, `PatternSettings` pede preservacao de referencias internas e blocos de plataforma, `DataStore` segue bastante declarativo, `Dashboard` pede cuidado com referencias a objetos analiticos, `DeploymentUnit` pede preservacao integral da lista de `Member`, `Generator` pede preservacao rigorosa das flags de categoria/tipo, `Language` pede preservacao integral das entradas de traducao, `Folder` segue simples, `Stencil` pede preservacao rigorosa de `CDATA`, screenshots e controles embutidos, e `File` pede preservacao integral do binario/texto serializado em `base64Binary` e dos caminhos de extracao
- Hipótese: `ExternalObject`, `UserControl`, `Module` e `SubTypeGroup` ja tem anexos representativos suficientes para prototipos controlados; dentro desse grupo, `ExternalObject` e `UserControl` ainda merecem refinamento quando houver contratos externos, JavaScript embutido ou comportamento cliente mais denso, e `SubTypeGroup` ainda pede cuidado com nomes residuais e pares subtype/supertype extensos

## Estado atual consolidado das frentes abertas

- `Evidência direta`: `Work With for Web` importa com sucesso quando o pattern usa o convenio real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Evidência direta`: `Table` e familia top-level propria; `Index` aparece embutido em `Table` e o export isolado de `Index` veio vazio nesta trilha.
- `Inferência forte`: a frente aberta de camada fisica se concentra em `Table/Index`, nao mais em `WorkWithForWeb`.
- `Evidência direta`: os exports `Table + Transaction + WorkWithForWeb + PatternSettings` e `Table + Transaction + DataSelector` explicitaram a ponte estrutural entre camada logica, camada fisica e camada de pattern.
- `Evidência direta`: o export `Table + Domain + Transaction + SDT + API + Procedure + DataProvider` mostrou que a `API` relevante desta KB anda com uma subarvore funcional grande.
- `Inferência forte`: a frente aberta de `API` e funcional, nao de envelope minimo.
- `Evidência direta`: o export `Table + Transaction + ColorPalette + DesignSystem + Theme + WebTheme + Category + ThemeClass + ThemeColor` mostrou a pilha visual completa exportada como familia combinada.
- `Inferência forte`: futuras analises devem priorizar combinacoes de familias relacionadas, e nao apenas tipos isolados.





