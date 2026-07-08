# 07 - Open Points e Checklist

## Papel do documento
governanca e operacional

## Nível de confianca predominante
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
00-indice-da-base-genexus-xpz-xml.md, 26-guia-para-agente-gpt.md, 99-resumo-da-consolidacao.md

## Objetivo
Concentrar lacunas técnicas, conflitos documentais e próximos passos que ainda exigem validação adicional.
Servir como local único para conflitos não resolvidos silenciosamente.

## O que já ficou sólido

- `Evidência direta`: o acervo extraído tem taxonomia estável por diretório e por `Object/@type`.
- `Evidência direta`: há relações aparentes visíveis por `parent`, `parentGuid`, `parentType`, `moduleGuid`, propriedades e referências nominais em código.
- `Evidência direta`: não houve arquivos problemáticos na leitura do conjunto atual.
- `Evidência direta`: a trilha já contem bateria controlada de importação real com reconhecimento coerente para `Procedure`, `Domain`, `SDT`, `Data Provider`, `Subtype Group`, `Module`, `External Object`, `Data Store`, `Generator`, `Panel`, `Image`, `Theme Color`, `Document`, `File`, `Language`, `Color Palette`, `Dashboard`, `User Control` e `Stencil`.
- `Evidência direta`: nessa bateria, `Dashboard` chegou a executar geração de pattern com sucesso após a importação.
- `Inferência forte`: a base `.md` local, usada junto com o skill `nexa`, já e fonte operacional forte para tipos autocontidos ou estruturalmente simples a moderados.

## Pontos ainda abertos

- `Hipótese`: o significado funcional preciso de cada GUID de `Part type` ainda precisa de catalogo semantico fechado por tipo de objeto; a base atual já prova recorrencia estrutural e indicios fortes de papel por frequência, mas ainda não fecha a semantica funcional completa de cada GUID.
- `Hipótese`: a base já sustenta, para varios tipos, indicios fortes de quais `Part type` são obrigatórios, opcionais ou vazios/estruturais por recorrencia observada e por importacoes controladas; o que ainda não está totalmente provado e o limite de generalizacao dessa leitura para todas as familias, variantes e KBs.
- `Hipótese`: a correspondência entre nomes compactos de diretório e nomes oficiais mostrados na IDE ainda deve ser validada diretamente na KB quando isso for necessário.
- `Hipótese`: a diferença exata entre `Module` e `PackagedModule` no plano funcional ainda não pode ser fechada só com os XMLs extraídos.
- `Hipótese`: ainda falta validar se os padrões observados nesta KB se repetem sem mudança relevante em outros exports GeneXus 18.
- `Hipótese`: a base ainda não fechou automacao confiavel para distinguir, em review de objeto legado, `defeito herdado`, `regressao introduzida`, `melhoria sobre baseline oficial` e `sem baseline oficial comparado` sem reinspecao humana por bloco.
- `Evidência direta`: já houve importação bem-sucedida, nesta trilha, de um `.xpz` mínimo de `Procedure` gerado a partir da própria base documental.
- `Evidência direta`: nesse teste, placeholders textuais em `Source/@kb` e `Source/Version/@guid` causaram erro de parse; GUIDs sintaticamente validos destravaram a importação.
- `Evidência direta`: ainda não ha evidência nesta trilha documental de build e execução a partir de XMLs gerados.
- `Evidência direta`: já ha evidência nesta trilha documental de importação bem-sucedida para muitos tipos diferentes, conforme a bateria controlada registrada nesta base.
- `Evidência direta`: o envelope XPZ observado em export real já foi documentado na base como `<ExportFile>` com `KMW` e `Source` invariantes; o bloco especial de KB (`KnowledgeBase` ou nome literal da KB) aparece apenas em exportacoes especiais/full e não no formato normal mais frequente de objetos.
- `Evidência direta`: nos exports normais lidos, `ObjectsIdentityMapping` usa `ObjectIdentity` com `Type`, `Name`, `parent` e `Guid` preenchidos; o bloco não repete os próprios objetos exportados, mas identidades de contexto.
- `Evidência direta`: nos exports normais lidos, `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name` não apareceram vazios.
- `Inferência forte`: a coerência mais útil entre `<Objects>` e `ObjectsIdentityMapping` ocorre via `parentGuid` e `moduleGuid`, não via duplicacao de `Object/@guid` dentro do mapeamento.
- `Hipótese forte`: o erro `Fail creating backup: Empty name is not allowed.` está mais ligado a variantes especiais com `KnowledgeBase` sem `name` do que ao formato normal de `ObjectsIdentityMapping`.
- `Evidência direta`: a pasta local `C:\\Dev\\Test\\from-anywhere-to-GeneXus` usa um envelope mínimo com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, sem `KnowledgeBase` nem `Settings`.
- `Inferência forte`: essa fonte local e útil como evidencia complementar de envelope mínimo, mas não deve ensinar valores fixos de `Build`, `username`, `kb`, `parentGuid`, `moduleGuid` ou nomes como `SampleKB` e `BusinessLogic`.
- `Inferência forte`: isso fecha a lacuna anterior sobre "como o XPZ é formado" para o formato de export observado nesta trilha.
- `Evidência direta`: em frente posterior desta trilha, um pacote embutido com `4` `Transaction`, `4` `WorkWithForWeb` e `3` `Procedure` passou com sucesso por `Import File Load`, `Import`, `Updating table information` e `Pattern generation`.
- `Inferência forte`: a lacuna de envelope para pacote misto `Transaction + WorkWithForWeb + Procedure` deixa de ser ponto aberto; a decisão operacional validada passa a ser usar export real comparavel da IDE como molde quando existir.
- `Hipótese`: ainda pode haver variantes de export XPZ não cobertas por esse único envelope observado.
- `Evidência direta`: a base consolidada passou a conviver com uma cópia histórica em `docs-kb-md`.
- `Inferência forte`: a raiz deve ser tratada como fonte operacional principal; `docs-kb-md` deve permanecer apenas como histórico de staging para evitar leituras duplicadas.
- `Evidência direta`: `04-webpanel-familias-e-templates.md` já contem anexos XML sanitizados completos para `WebPanel`.
- `Evidência direta`: `05-transaction-familias-e-templates.md` agora também contem anexos XML sanitizados completos para familias representativas de `Transaction`.
- `Evidência direta`: a serie `01` agora distribui anexos XML sanitizados completos representativos de `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em `01e` ate `01h`.
- `Hipótese`: ainda vale completar `Transaction` com anexos equivalentes para as familias mais densas (`F3` e `F4`) se a meta for cobertura integral só pelos `.md`, sem recorrer ao acervo bruto.
- `Evidência direta`: `Attribute` tem shape top-level comprovado nesta trilha e já demonstrou importação bem-sucedida em caso semanticamente fechado.
- `Evidência direta`: `Folder` ficou esclarecido como tipo XML estruturalmente valido, enquanto `Category` e apenas o rotulo de UI/importador.
- `Evidência direta`: `Theme`, `Pattern Settings`, `Transaction` e `Work With for Web` já possuem receita empirica de sucesso sob dependencias explicitas conhecidas.
- `Evidência direta`: `Design System`, `Deployment Unit` e `Data Selector` também já tiveram casos controlados de sucesso nesta trilha.
- `Evidência direta`: a camada física `Table/Index` concentra a principal frente técnica ainda aberta nesta trilha, enquanto `API` ficou delimitada como caso único manual/local da KB.
- `Calibração (from-spec, 2026-07-01)`: o "`API` ficou delimitada como caso único manual/local da KB" acima refere-se ao perfil **cadeia-grande**; a Fase 0 abriu o perfil **from-spec autocontido** (tríade `API`->`Procedure`->`SDT`, validada por importação real), esse generalizável. Ver `03-risco-e-decisao-por-tipo.md` (`API (cadeia)` vs `API (from-spec)`) e `xpz-builder/responsibilities-by-type/api.md`.
- `Inferência forte`: a lacuna dominante agora não é mais "como serializar o XPZ", e sim "quais referencias e dependencias minimas precisam existir na KB para cada tipo contextual".
- `Inferência forte`: `Theme`, `PatternSettings`, `Transaction`, `Attribute`, `Folder`, `Design System`, `Deployment Unit`, `Data Selector` e `Work With for Web` deixam de ser pendencias estruturais abertas nesta trilha.
- `Inferência forte`: a fronteira principal remanescente se concentra na camada física `Table/Index`; `API` fica encerrada por ora como estudo de caso único, sem base para generalizacao adicional.
- `Calibração (from-spec, 2026-07-01)`: o "encerrada como estudo de caso único, sem base para generalização" acima refere-se ao perfil **cadeia-grande**. A Fase 0 (frente `API` from-spec + GAM) abriu um perfil **from-spec autocontido** (tríade `API`->`Procedure`->`SDT`, validada por importação real), esse generalizável; ver `03-risco-e-decisao-por-tipo.md` (`API (cadeia)` vs `API (from-spec)`) e `xpz-builder/responsibilities-by-type/api.md`.

## Próximas frentes recomendadas

- `Inferência forte`: vale montar um catálogo dedicado de `Part type` por diretório/tipo extraído.
- `Inferência forte`: vale isolar pares de objetos simples e complexos do mesmo grupo para comparação estrutural.
- `Inferência forte`: vale produzir uma camada de validação cruzando `parent*`, `moduleGuid`, chamadas em código e nomes de objeto.
- `Inferência forte`: antes de corrigir os `.md` dos tipos problemáticos, vale usar a bateria atual para distinguir "erro de molde" de "erro de dependência de KB" em cada tipo.
- `Inferência forte`: vale abrir uma frente de automacao comparativa por baseline oficial, com diff normalizado por bloco funcional e filtragem de ruido conhecido, para reduzir falso positivo de regressao em objeto legado.
- `Inferência forte`: a próxima coleta em exemplos reais deve priorizar `Table/Index` e outros tipos contextuais ainda não revisitados com dependencias completas; para `API`, só faz sentido nova coleta se surgirem novos casos reais ou automacao externa no ambiente. Para `Theme`, `PatternSettings` e `Transaction`, a coleta adicional passa a ser de generalizacao e não de desbloqueio inicial.
- `Calibração (from-spec, 2026-07-01)`: o "para `API`, só faz sentido nova coleta se surgirem novos casos reais ou automação externa" acima **já foi atendido** — a Fase 0 é o novo caso real (perfil from-spec autocontido, validado por importação real). A coleta adicional de `API` passa a ser de novos perfis/variantes, não de desbloqueio inicial. Ver `03-risco-e-decisao-por-tipo.md` (`API (cadeia)` vs `API (from-spec)`) e `xpz-builder/responsibilities-by-type/api.md`.

## Mini-postmortem de incidente metodologico

- `Regra operacional`: usar este mini-postmortem quando houver incidente de processo, erro de nomenclatura de frente ou pacote, erro de empacotamento, erro de snapshot/acervo, mudanca extra fora do plano ou melhoria candidata para skill/documento.
- `Regra operacional`: esse registro e condicional e não faz parte do fechamento obrigatório de toda frente.
- `Checklist`: registrar o incidente observado de forma objetiva.
- `Checklist`: classificar a categoria principal do incidente.
- `Checklist`: registrar impacto prático na frente, no pacote ou na rastreabilidade.
- `Checklist`: apontar a regra nova ou ajuste metodologico candidato.
- `Checklist`: indicar qual skill, documento ou fluxo precisa evoluir.

## Decisão operacional - Transaction e WebPanel

- `Evidência direta`: o acervo contem 183 `Transaction` e 1196 `WebPanel`.
- `Inferência forte`: ambos ficam desbloqueados para geração por clonagem interna da própria base, mesmo mantendo risco alto.
- `Inferência forte`: `Transaction` parece mais apta a trabalhar por padrão estrutural inferido.
- `Inferência forte`: `WebPanel` exige leitura por familias estruturais e selecao de molde interno muito próximo.
- `Hipótese`: o impacto esperado e destravar geração controlada de KB mais ampla, com aprendizado incremental a partir de erros de importação.


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
- Inferência forte: `Transaction` e `WebPanel` já possuem base suficiente para geração; novos templates passam a servir como refinamento e não como pre-requisito.

## Itens sugeridos

- Só voltar a coletar novos casos de `API` se surgirem novos objetos reais na KB ou alguma ferramenta externa passar a automatizar essa familia no ambiente.
- `Calibração (from-spec, 2026-07-01)`: o "só voltar a coletar novos casos de `API` se surgirem novos objetos reais" acima refere-se ao perfil **cadeia-grande**; a Fase 0 já trouxe o novo caso — o perfil **from-spec autocontido** (tríade `API`->`Procedure`->`SDT`, validada por importação real), montável **sem** depender de objeto real na KB. Ver `03-risco-e-decisao-por-tipo.md` (`API (cadeia)` vs `API (from-spec)`) e `xpz-builder/responsibilities-by-type/api.md`.
- Exportar pelo menos 1 template adicional de DataProvider com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de DataStore com necessidade baixa, preferindo um datastore padrão e outro com metadados adicionais.
- Exportar pelo menos 1 template adicional de Dashboard com necessidade media, preferindo um caso curto e outro com mais objetos analiticos e filtros.
- Exportar pelo menos 1 template adicional de DeploymentUnit com necessidade baixa, preferindo um caso curto e outro com mais `Member`.
- Exportar pelo menos 1 template adicional de DesignSystem com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de ColorPalette com necessidade baixa, preferindo uma paleta curta e outra com mais tons.
- Exportar pelo menos 1 template adicional de Domain com necessidade baixa, preferindo um caso escalar e outro enumerado mais rico.
- Exportar pelo menos 1 template adicional de ExternalObject com necessidade media, preferindo um caso nativo simples e outro com varios métodos externos.
- Exportar pelo menos 1 template adicional de File com necessidade media, preferindo um asset binario pequeno e outro arquivo textual/configuracional.
- Exportar pelo menos 1 template adicional de Folder com necessidade baixa, preferindo uma pasta simples e outra com propriedades de arvore/consulta.
- Exportar pelo menos 1 template adicional de Generator com necessidade baixa, preferindo um caso default e outro com `DefaultType` diferente.
- Exportar pelo menos 1 template adicional de Language com necessidade media, preferindo um idioma curto e outro com mais chaves de traducao.
- Exportar pelo menos 1 template adicional de Module com necessidade baixa, preferindo um módulo raiz e outro filho.
- Exportar pelo menos 1 template adicional de Image com necessidade media, preferindo um caso com item único e outro com varias variantes e referencias de tema.
- Exportar pelo menos 1 template adicional de Index com necessidade media, preferindo um caso simples e outro com muitos índices de usuário e combinacoes de ordem.
- Exportar pelo menos 1 template adicional de Document com necessidade baixa, preferindo um caso curto e outro com HTML mais extenso.
- Exportar pelo menos 1 template adicional de DataSelector com necessidade media, preferindo um caso simples e outro com conjunto maior de `Condition` e parâmetros.
- Exportar pelo menos 1 template adicional de PackagedModule com necessidade baixa, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de PatternSettings com necessidade media, preferindo um caso web e outro mobile com mais contexto de seguranca.
- Exportar pelo menos 1 template adicional de Theme com necessidade baixa, preferindo um tema simples e outro com mais classes visuais.
- Exportar pelo menos 1 template adicional de ThemeClass com necessidade media, preferindo uma classe raiz simples e outra derivada/estado visual.
- Exportar pelo menos 1 template adicional de ThemeColor com necessidade baixa, preferindo uma cor base e outra cor de destaque/estado.
- Exportar pelo menos 1 template adicional de Panel com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Procedure com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de SDT com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Stencil com necessidade media, preferindo um caso visual simples e outro com mais controles e variáveis.
- Exportar pelo menos 1 template adicional de SubTypeGroup com necessidade media, preferindo um caso pequeno e outro mais denso em subtypes derivados.
- Exportar pelo menos 1 template adicional de Theme com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Transaction com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de UserControl com necessidade media, preferindo um caso simples e outro com definicoes/eventos mais ricos.
- Exportar pelo menos 1 template adicional de WebPanel com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de WorkWithForWeb com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar casos em que o mesmo tipo exista com e sem parent.
- Exportar casos em que o mesmo tipo exista com e sem pattern.
- Exportar exemplos onde Part type raro apareca acompanhado de comportamento conhecido na IDE.

## Regras de materialização

- Evidência direta: novos templates devem ser coletados como XML bruto real, não como resumo, screenshot ou exemplo sanitizado
- Inferência forte: para `Transaction`, coletar templates simples e complexos da mesma familia estrutural, preservando `parent*`, `moduleGuid` e ordem de `Part`
- Inferência forte: para `WebPanel`, coletar pelo menos um template bruto por familia estrutural relevante, com foco em `menu/home`, `formulario`, `lista/grid` e `eventos`
- Inferência forte: se um template adicional perder atributos do no `<Object>`, `CDATA` ou qualquer `Part` recorrente, ele não serve como material de materialização

## Regras de serializacao XPZ

- quando houver variante nova de export, coletar pelo menos um contêiner XPZ bruto real que mostre como o objeto entra em `<Objects>`
- guardar o XML exatamente como exportado, sem reformatar `CDATA` para texto escapado
- validar que cada template abre como XML bem-formado antes de entrar no acervo
- rejeitar template coletado se o envelope externo tiver sido reconstruido manualmente fora do padrão de envelope XPZ observado e documentado nesta base

## Regras de fonte

- Fonte valida para ampliar a base: XML bruto exportado ou extraido diretamente de XPZ real
- Fonte invalida para ampliar a base: markdown, snippets copiados de documentação, exemplos sanitizados e pseudo-XML produzido por agente
- Inferência forte: `Transaction` e `WebPanel` não precisam de novos exemplos para desbloqueio operacional, mas qualquer refinamento futuro deve entrar na base como XML bruto, não como derivacao textual
- Hipótese: `WorkWithForWeb` já tem anexos representativos suficientes para estudo e prototipo controlado, mas continua sendo um dos melhores candidatos a refinamento por causa da alta dependencia de pattern e parent transacional
- Hipótese: `SDT` já tem anexos representativos suficientes para prototipos pequenos e medios, mas vale refinar com exemplos adicionais quando houver dependencia forte de namespace, soaptype ou schema externo muito específico
- Hipótese: `Domain` já tem anexos representativos suficientes para prototipos escalares e enumerados comuns, mas ainda pode valer ampliar a base se surgirem dominios com metadata mais exotica ou comportamento especial de enumeracao
- Hipótese: `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `DataSelector`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` já tem anexos representativos suficientes para prototipos controlados, mas `DesignSystem` segue sendo o mais sensivel do grupo por acumular tokens, imports e regras visuais extensas, `ThemeClass` ainda pede cuidado quando a cadeia de heranca visual for mais longa, `ThemeColor` e `ColorPalette` seguem os mais simples do grupo, `Image` pede preservacao rigorosa do binario e das referencias de tema, `Index` pede cuidado forte com a ordem dos `Members` e a distincao entre índices `Automatic` e `User`, `Document` pede apenas atenção ao conteúdo HTML e a qualquer dado embutido sensivel, `DataSelector` pede cuidado com variáveis customizadas, parâmetros e filtros muito específicos, `PatternSettings` pede preservacao de referencias internas e blocos de plataforma, `DataStore` segue bastante declarativo, `Dashboard` pede cuidado com referencias a objetos analiticos, `DeploymentUnit` pede preservacao integral da lista de `Member`, `Generator` pede preservacao rigorosa das flags de categoria/tipo, `Language` pede preservacao integral das entradas de traducao, `Folder` segue simples, `Stencil` pede preservacao rigorosa de `CDATA`, screenshots e controles embutidos, e `File` pede preservacao integral do binario/texto serializado em `base64Binary` e dos caminhos de extracao
- Hipótese: `ExternalObject`, `UserControl`, `Module` e `SubTypeGroup` já tem anexos representativos suficientes para prototipos controlados; dentro desse grupo, `ExternalObject` e `UserControl` ainda merecem refinamento quando houver contratos externos, JavaScript embutido ou comportamento cliente mais denso, e `SubTypeGroup` ainda pede cuidado com nomes residuais e pares subtype/supertype extensos

## Estado atual consolidado das frentes abertas

- `Evidência direta`: `Work With for Web` importa com sucesso quando o pattern usa o convenio real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Evidência direta`: `Table` e familia top-level própria; `Index` aparece embutido em `Table` e o export isolado de `Index` veio vazio nesta trilha.
- `Inferência forte`: a frente aberta de camada física se concentra em `Table/Index`, não mais em `WorkWithForWeb`.
- `Evidência direta`: os exports `XPZExemploTabelaTRNWWPatternA.xpz` e `XPZExemploTabelaTRNDataSelectorA.xpz` explicitaram a ponte estrutural entre camada lógica, camada física e camada de pattern.
- `Evidência direta`: o export `XPZExemploCadeiaAPIA.xpz` mostrou que a `API` relevante desta KB anda com uma subarvore funcional grande.
- `Inferência forte`: o caso de `API` fica suficientemente entendido nesta trilha como dependencia funcional pesada de um único caso manual/local, e não como frente aberta de envelope mínimo ou familia ampla.
- `Calibração (from-spec, 2026-07-01)`: o "`API`... dependência funcional pesada de um único caso... e não como frente aberta de envelope mínimo" acima é do perfil **cadeia-grande** (o export `XPZExemploCadeiaAPIA`). A Fase 0 reabriu `API` pelo perfil **from-spec autocontido** (tríade `API`->`Procedure`->`SDT`), esse sim frente de envelope mínimo viável, validada por importação real. Ver `03-risco-e-decisao-por-tipo.md` e `xpz-builder/responsibilities-by-type/api.md`.
- `Evidência direta`: o export `XPZExemploTemaA.xpz` mostrou a pilha visual completa exportada como familia combinada.
- `Evidência direta`: os exports `XPZExemploFamiliaMistaA.xpz` e `XPZExemploFamiliaMistaB.xpz` mostraram que a IDE também serializa familia combinada com `Attributes` top-level no mesmo `.xpz`.
- `Inferência forte`: a frente aberta de `Attribute` deixa de incluir duvida relevante sobre contêiner multiobjeto; o foco remanescente continua sendo dependencia semantica de propriedades e contexto de KB.
- `Evidência direta`: o par `XPZExemploTRNWWComparacaoSemWW` e `XPZExemploTRNWWComparacaoComWW` mostrou, em escala mínima e comparavel, o custo estrutural de adicionar `WorkWithForWeb` a uma `Transaction`.
- `Inferência forte`: esse tipo de par mínimo comparavel e especialmente valioso para medir expansao de `ObjectsIdentityMapping` e dependencias de contexto sem o ruido dos pacotes grandes.
- `Evidência direta`: a trilha também confirmou, em pacote misto embutido comparavel, que o erro `Value cannot be null. Parameter name: g` não exigia inventar `ObjectsIdentityMapping`; o problema estava no uso do envelope leve errado para aquela composicao.
- `Inferência forte`: futuras analises devem priorizar combinacoes de familias relacionadas, e não apenas tipos isolados.

## Pendência de refatoração

- `Inferência forte`: os arquivos `.md` desta base repetem informações em diferentes pontos:
  - definições de pastas operacionais (ObjetosDaKbEmXml, XpzExportadosPelaIDE, etc.) aparecem em quase todas as skills
  - regras de envelope XPZ repetem-se em xpz-builder, xpz-sync e xpz-doc-builder
  - validações de Transaction ↔ Attributes duplicam-se em xpz-builder e xpz-reader
- `Hipótese`: essa repetição causa dificuldade de manutenção, risco de inconsistência e documentos muito longos
- `Regra operacional`: deduplicar informações repetidas, substituindo por referências aos documentos canônicos:
  - pastas operacionais → referenciar a seção de topologia operacional do README.md
  - envelope XPZ → referenciar 02-regras-operacionais-e-runtime.md
  - validações de Transaction → referenciar a seção relevante de 05-transaction-familias-e-templates.md
- `Regra operacional`: cada skill deve conter apenas suas próprias responsibilities, constraints e workflow, não a genealogia completa da base

---

## Plano operacional: `lastUpdate`, aviso de KB no futuro e diagnostico de import MSBuild

**Contexto:** em importação real (MSBuild ou IDE), o utilizador pode ver aviso do tipo abertura da KB com última modificacao **no futuro** em relacao ao relogio do sistema, **sem** que o relogio do SÓ tenha sido alterado manualmente. Em caso verificavel, a causa pode ser metadado `Object/@lastUpdate` em UTC (`...Z`) **a frente** do instante local de abertura — por exemplo pacote construido noutro instante, patch de XML com timestamp herdado ou gravacao com instante errado.

### Regras de gate em `lastUpdate` (acordo de trilha)

- **Objeto modificado nesta rodada** (texto alterado e `lastUpdate` deve refletir a última gravacao no ambiente que produz o XML): calcular `NEW_TS = max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)` quando houver baseline oficial; após parse do valor em UTC, bloquear se o timestamp for igual/anterior ao acervo, ficar abaixo da margem de frescor declarada ou exceder o futuro aceitavel sem justificativa pelo acervo + margem. **Nunca** placeholder, hora cheia, minuto arredondado nem "hora desejada".
- **Objeto preservado** (reenviado só por fecho de dependencias, `lastUpdate` **igual** ao XML oficial do acervo): **aceitar** `lastUpdate` futuro em relacao ao relogio atual; e caso improvavel (corpus ou maquina de origem já desalinhados). **Não** aplicar o bloqueio duro de futuro a este papel.

Estas regras **complementam** (não substituem) as regras canonicas de `lastUpdate` em `02-regras-operacionais-e-runtime.md` e o fluxo de auditoria em `xpz-builder` (classificação modificado vs dependencia preservada, releitura do ficheiro gravado).

### Playbook: primeiro passo quando surgir sintoma de "KB no futuro"

1. Extrair `Object/@lastUpdate` e `Object/@fullyQualifiedName` (ou `name` + contexto) dos `<Object>` do pacote em causa (`import_file.xml` ou XML interior do `.xpz`).
2. Comparar cada valor parseavel em UTC com `UtcNow` e com a hora local percebida pelo operador (conversao de fuso explicita na comunicação).
3. Só **depois** expandir para inventario completo de `<Object>` (extras, módulos de plataforma, cascata de export) — **não** misturar no mesmo raciocinio **pacote inchado** e **metadado temporal** sem evidencia no XML.

### Narrativas separadas

- **Pacote inchado / cascata de export:** contagem de objetos, extras face ao delta declarado, `Module:GeneXus`, dependencias arrastadas — trilha já orientada em `xpz-msbuild-import-export` (inventario antes do import real).
- **Metadado temporal:** `lastUpdate` futuro face ao relogio de quem abre — tratar como hipotese **primeira** quando o XML mostra esse padrão, sem concluir corrupcao de envelope ou "módulo fantasma" no zip sem listagem dos nos.

### Import JSON vs log bruto (wrapper MSBuild)

- `exitCode` alto no **script** (ex.: `90` contratual para falha interna antes de diagnostico completo) ou `importedItems` vazio por exceção no pos-processamento (ex.: `Join` com null) **não** substituem a leitura de `msbuild.stdout.log` / stdout quando a questao e "importou ou não".
- Quando o log bruto contiver marca de item importado esperado mas o JSON estiver degradado, aplicar o **sub-estado** já nomeado na skill `xpz-msbuild-import-export`: importação real provada por evidencia de stdout com falha no pos-processamento do wrapper.

### Comunicação ao utilizador (quando bater com `lastUpdate` futuro)

Declarar explicitamente: `fullyQualifiedName` (ou identificador estavel), valor UTC literal, conversao para o fuso do operador, e que isso **não implica** por si só módulo fantasma nem pacote corrompido — implica desalinhamento temporal verificavel no metadado do objeto.

### Automacao

A verificacao mecanica foi incorporada ao ponto de montagem `scripts/Build-GeneXusImportFileEnvelope.ps1`: `-AcervoPath <ObjetosDaKbEmXml>` e obrigatório e a coerencia frente-vs-acervo roda sempre antes da gravacao, cobrindo `lastUpdate` e `Object/@type` divergente por mesmo `guid`, com declaracao opcional de modificados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids` para a parte temporal. O helper `scripts/Get-GeneXusXpzLastUpdate.ps1` aceita `-BaselineXmlPath` e calcula o timestamp canonico com margem padrão de 60 segundos. `Test-GeneXusImportFileEnvelope.ps1` continua validando o envelope estatico; sozinho, ele não tem contexto suficiente para inferir acervo e classificação de modificado vs preservado.

---

## Erros recorrentes

### `For each` com Base Table incoerente

- `Causa`: assumir a `Base Table` pelo nome do objeto ou por leitura parcial do bloco, sem confirmar a determinacao explicita ou implicita.
- `Consequência`: aceitar atributos que não pertencem a `Base Table`/`Extended Table` coerente, gerando análise errada ou ajuste de `Source` fora da navegacao real.
- `Regra de checagem`: antes de validar atributos do bloco, identificar a `Base Table` determinada do `For each` e verificar cada referencia contra essa base e seu contexto coerente de navegacao.

---

## Gates determinísticos da Fase 9 do xpz-builder

A skill `xpz-builder` extraiu seus gates da Fase 9 (`9-BC`, `9-WW`, `9-PSM`, `9-IDO`, `9-PNW`, `9-TWS`, `Writability`, `9-FD`) para scripts em `scripts/Test-GeneXus*.ps1`. Contrato de invocação, códigos de finding e regras de uso ficam em `xpz-builder/SKILL.md` e satélites `xpz-builder/responsibilities-by-type/*.md`; esta seção só registra a existência dos scripts para descoberta a partir da raiz.

- `scripts/Test-GeneXusBCDependency.ps1` — gate `9-BC` (Procedures que escrevem em Transaction como Business Component)
- `scripts/Test-GeneXusBatchDependencyOrdering.ps1` — gate `9-IDO` (ordem entre Procedure e Transaction no batch)
- `scripts/Test-GeneXusNewWritableTargets.ps1` — gate `9-PNW` (atributos graváveis em comandos `New` de Procedure; fachada PowerShell sobre `GeneXusTransactionWritabilityCore.py`)
- `scripts/Test-GeneXusProcedureSubPattern.ps1` — gate `9-PSM` (padrão dominante de Sub em Procedures)
- `scripts/Test-GeneXusTransactionCoherence.ps1` — gate `9-TWS` (coerência de Transaction pré-empacotamento: integridade de Level e, para Transaction `GenerateObject=False`, código de tela WorkWithPlus DVelop órfão em Events/Rules — finding `wwp-screen-code-on-non-generated-transaction`)
- `scripts/Test-GeneXusTransactionWritability.ps1` — gate `Writability` (Transactions efetivamente graváveis; fachada PowerShell sobre `GeneXusTransactionWritabilityCore.py`)
- `scripts/Test-GeneXusWorkWithWebApply.ps1` — gate `9-WW` (Apply em WorkWithForWeb, formas A e B)
- `scripts/Test-GeneXusFrontAcervoDrift.ps1` — gate `9-FD` (drift frente-vs-acervo: compara `lastUpdate` de cada XML da frente contra o homônimo no acervo; findings `front-older-than-acervo` bloqueiam empacotamento; findings `front-object-type-drift` bloqueiam empacotamento quando o mesmo `guid` diverge em `Object/@type`, exigindo decisão humana)
- `scripts/Copy-GeneXusAcervoToFront.ps1` — motor de resolução de drift temporal/seed: copia XMLs do acervo para a frente com bump automático de `lastUpdate`; resolve o anti-padrão "editar acervo esperando que o pacote pegue"; bloqueia autocópia quando o mesmo `guid` diverge em `Object/@type` (`front-object-type-drift-skip`)
