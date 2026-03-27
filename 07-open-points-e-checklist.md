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

## Pontos ainda abertos

- `Hipótese`: o significado funcional preciso de cada GUID de `Part type` ainda precisa de catálogo semântico por tipo de objeto.
- `Hipótese`: ainda não está provado quais `Part type` são obrigatórios, opcionais ou apenas vazios estruturais em cada família de objeto.
- `Hipótese`: a correspondência entre nomes compactos de diretório e nomes oficiais mostrados na IDE ainda deve ser validada diretamente na KB quando isso for necessário.
- `Hipótese`: a diferença exata entre `Module` e `PackagedModule` no plano funcional ainda não pode ser fechada só com os XMLs extraídos.
- `Hipótese`: ainda falta validar se os padrões observados nesta KB se repetem sem mudança relevante em outros exports GeneXus 18.
- `Hipótese`: ainda não há evidência nesta trilha documental de importação, build e execução a partir de XMLs gerados.
- `Evidência direta`: o envelope XPZ observado em export real ja foi documentado na base como `<ExportFile>` com os blocos top-level `KMW`, `Source`, `KnowledgeBase`, `Objects`, `Attributes` e `Dependencies`.
- `Inferência forte`: isso fecha a lacuna anterior sobre "como o XPZ é formado" para o formato de export observado nesta trilha.
- `Hipótese`: ainda pode haver variantes de export XPZ nao cobertas por esse unico envelope observado.
- `Evidência direta`: a base consolidada passou a conviver com uma cópia histórica em `docs-kb-md`.
- `Inferência forte`: a raiz deve ser tratada como fonte operacional principal; `docs-kb-md` deve permanecer apenas como histórico de staging para evitar leituras duplicadas.
- `Evidência direta`: `04-webpanel-familias-e-templates.md` ja contem anexos XML sanitizados completos para `WebPanel`.
- `Evidência direta`: `05-transaction-familias-e-templates.md` agora tambem contem anexos XML sanitizados completos para familias representativas de `Transaction`.
- `Evidência direta`: `01-base-empirica-geral.md` agora tambem contem anexos XML sanitizados completos representativos de `Procedure`, `DataProvider`, `Panel` e `API`.
- `Hipótese`: ainda vale completar `Transaction` com anexos equivalentes para as familias mais densas (`F3` e `F4`) se a meta for cobertura integral so pelos `.md`, sem recorrer ao acervo bruto.

## Próximas frentes recomendadas

- `Inferência forte`: vale montar um catálogo dedicado de `Part type` por diretório/tipo extraído.
- `Inferência forte`: vale isolar pares de objetos simples e complexos do mesmo grupo para comparação estrutural.
- `Inferência forte`: vale produzir uma camada de validação cruzando `parent*`, `moduleGuid`, chamadas em código e nomes de objeto.

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
- Exportar pelo menos 1 template adicional de DesignSystem com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de PackagedModule com necessidade baixa, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Panel com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Procedure com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de SDT com necessidade baixa, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Theme com necessidade media, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de Transaction com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de WebPanel com necessidade alta, preferindo um caso simples e outro com mais contexto.
- Exportar pelo menos 1 template adicional de WorkWithForWeb com necessidade alta, preferindo um caso simples e outro com mais contexto.
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





