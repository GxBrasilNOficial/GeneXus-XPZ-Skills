# 09 - Inventario e Rastreabilidade Publica

## Papel do documento
indice e rastreabilidade

## Nivel de confianca predominante
alto

## Depende de
nenhum

## Usado por
00-readme-genexus-xpz-xml.md, 01-base-empirica-geral.md

## Objetivo
Preservar rastreabilidade da consolidacao, inventario documental, inventario bruto publico sanitizado e o mapeamento usado para reduzir a base a ate 10 arquivos.

## Nota sobre historico detalhado

- `Evidência direta`: a raiz desta base passou a priorizar estado atual de trabalho, sem manter no corpo principal a arqueologia completa das rodadas de teste.
- `Evidência direta`: o historico detalhado de validacoes, rodadas de importacao e reclassificacoes deve ficar separado em `historico/`, para nao competir com os `.md` operacionais da raiz.

## Nota sobre a rastreabilidade privada

- `Evidência direta`: existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada para manter rastreabilidade editorial entre aliases publicos e artefatos reais.
- `Regra editorial`: essa rastreabilidade privada nao substitui a documentacao consolidada desta raiz; ela existe apenas como apoio privado de manutencao, sanitizacao e continuidade editorial.

## Nota sobre o motor operacional compartilhado

- `Evidência direta`: o script `scripts/Sync-GeneXusXpzToXml.ps1` e parte da infraestrutura operacional desta base publica.
- `Evidência direta`: esse script pode ser consumido por wrappers e fluxos locais de projetos de producao que mantenham acervos versionados de XMLs extraidos de `XPZ`.
- `Regra editorial`: a pasta `scripts/` existe como apoio operacional e utilitario compartilhavel, mas nao funciona como fonte normativa da documentacao consolidada da raiz.
- `Regra operacional`: esse arquivo nao deve ser apagado silenciosamente do repositório publico.
- `Regra operacional`: se houver refatoracao, mudanca de local ou substituicao do motor, a alteracao deve ser documentada explicitamente e propagada aos consumidores externos antes de remover o arquivo anterior.
- `Evidência direta`: o script recebeu adição do parâmetro `-KbMetadataPath` para gerar metadados da KB em formato Markdown, facilitando reuso em envelopes de importação.

## Nota sobre a skill experimental de MSBuild

- `Evidência direta`: a skill `xpz-msbuild-import-export` passou a existir na raiz como contrato materializado em `xpz-msbuild-import-export/SKILL.md`.
- `Evidência direta`: essa skill permanece experimental e, nesta fase, ja inclui a implementacao inicial de `scripts/Test-GeneXusMsBuildSetup.ps1` como probe nao invasivo de ambiente.
- `Evidência direta`: essa skill tambem ja inclui a implementacao inicial de `scripts/Open-GeneXusKbHeadless.ps1` para abertura e fechamento controlados da KB com captura de contexto.
- `Evidência direta`: essa skill tambem ja inclui a implementacao inicial de `scripts/Test-GeneXusXpzImportPreview.ps1` para `PreviewMode` de importacao sem alteracao real da KB, validada nesta conversa com `XPZ` real.
- `Evidência direta`: essa skill tambem ja inclui a implementacao inicial de `scripts/Invoke-GeneXusXpzExport.ps1` para exportacao headless de `XPZ` com parametros explicitos.
- `Evidência direta`: essa skill tambem ja inclui a implementacao inicial de `scripts/Invoke-GeneXusXpzImport.ps1` para importacao real de `XPZ` com parametros explicitos.
- `Evidência direta`: `Open-GeneXusKbHeadless.ps1` foi validado com `C:\KBs\Teste1`, `VersionName=Teste1` e `EnvironmentName=NETSQLServer`.
- `Evidência direta`: `Test-GeneXusXpzImportPreview.ps1` foi validado com `C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\Teste1_Full_20260417a.xpz`.
- `Evidência direta`: o `PreviewMode` executado nessa validacao nao alterou a KB.
- `Evidência direta`: `Invoke-GeneXusXpzImport.ps1` foi validado com o `XPZ` exportado nesta frente e concluiu com sucesso operacional, embora tenha produzido mensagens de stderr no log.
- `Evidência direta`: uma nova rodada de importacao real com a KB fechada manteve o mesmo padrao de `stderr`, incluindo as mensagens de `mismatched input ']' expecting 'default'` e o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`, sem impedir `exitCode = 0`.
- `Evidência direta`: na instalacao validada nesta conversa, `IncludeItems` e `ExcludeItems` funcionaram em `PreviewMode`, enquanto `UpdateFile` e `ImportKBInformation` ficaram bloqueados por ausencia de propriedade publica correspondente na task `Import` carregada.
- `Evidência direta`: os wrappers de preview e importacao real passaram a normalizar recortes multiplos de `IncludeItems` e `ExcludeItems`, com serializacao em formato de lista aceito operacionalmente pela task carregada.
- `Evidência direta`: depois dessa normalizacao, recortes combinados passaram a funcionar de forma confiavel e permitiram reduzir o ruido lateral sem alterar o `exitCode = 0` da importacao real.
- `Evidência direta`: na bateria de recortes desta frente, o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json` deixou de ficar restrito a `Module:GeneXusUnanimo` e `DesignSystem:Teste1` e reapareceu tambem em `Procedure:procExtraiTextoDoPdf`, `Procedure:procGeraPdfDoDANFCE` e `Procedure:procCarregaSDTsDaNFe`.
- `Evidência direta`: no recorte mais reduzido desta bateria, a importacao real manteve `exitCode = 0`, mas o log passou a destacar `src0246` em `Procedure:procCarregaSDTsDaNFe`, com referencia a objeto nao definido `procStrZERO`.
- `Evidência direta`: na inspecao do XML extraido do `XPZ` exportado com `ExportAll=true`, `procStrZERO` apareceu no bloco `Source`, mas nao apareceu como objeto exportado nem como referencia declarada do pacote.
- `Evidência direta`: um teste controlado derivando o `XPZ` exportado via headless e preenchendo o `Source` global com os valores do pacote full nao alterou o padrao principal da importacao real; `CssProperties.json`, `mismatched input ']' expecting 'default'`, `src0246` e `procStrZERO` permaneceram no mesmo comportamento observado antes.
- `Evidência direta`: um segundo teste controlado derivando o mesmo `XPZ` exportado via headless e trocando apenas as duas ocorrencias de `Pattern Settings` de `Padrões GeneXus` para `GeneXus Patterns` tambem nao alterou o padrao principal da importacao real.
- `Inferência forte`: com esses dois testes, as duas diferencas remanescentes identificadas entre o pacote full e o export headless deixaram de ser suspeitas fortes para o ruido principal desta frente.
- `Inferência forte`: para o estado atual desta frente, o bloqueio remanescente mais importante deixou de ser do wrapper e passou a apontar para conteudo da KB/`XPZ`, por referencia quebrada em `Source` durante a importacao.
- `Evidência direta`: os scripts previstos para exportacao efetiva e importacao efetiva agora estao materializados nesta fase.
- `Regra editorial`: a existencia dessa skill nao promove a trilha `MSBuild` a fluxo oficial da base nem altera automaticamente o comportamento das skills `xpz-*` existentes.

## Fontes consolidadas
- 00-inventario-da-base-documental.md
- 30-inventario-bruto-kb.md
- 98-mapeamento-para-consolidacao-em-10-arquivos.md
- 99-resumo-da-consolidacao.md

## Origem incorporada - 00-inventario-da-base-documental.md

## Papel do documento
indice

## Nível de confiança predominante
alto

## Depende de
nenhum; este inventario reconstrói o estado da base antes da consolidacao final

## Usado por
00-readme-genexus-xpz-xml.md, 04-genexus-open-points.md, 99-resumo-da-consolidacao.md

## Objetivo
Mapear os arquivos Markdown encontrados, identificar sobreposições e registrar a lógica de consolidação adotada.
Servir como trilha de auditoria da reorganização da base documental.

## Arquivos encontrados antes da consolidacao

### Raiz

- `README-DevKnowledgeGenexus.md`
- `genexus-xpz-research.md`
- `genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md`
- `genexus-open-points.md`

### Subpasta `docs-kb-md`

- `00-inventario-bruto.md`
- `10-matriz-part-types-por-tipo.md`
- `11-campos-estaveis-vs-variaveis.md`
- `12-diffs-estruturais-por-tipo.md`
- `13-guia-de-clonagem-segura.md`
- `14-indicios-de-obrigatoriedade.md`
- `15-tipos-prontos-para-geracao-conservadora.md`
- `16-mapa-de-risco-por-tipo.md`
- `17-resumo-operacional-para-gerador-xpz.md`
- `18-checklist-para-novos-templates.md`

## Classificacao por papel

### Conceituais

- `README-DevKnowledgeGenexus.md`
- `genexus-xpz-research.md`
- `genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md`
- `genexus-open-points.md`

### Empiricos

- `docs-kb-md/00-inventario-bruto.md`
- `docs-kb-md/10-matriz-part-types-por-tipo.md`
- `docs-kb-md/11-campos-estaveis-vs-variaveis.md`
- `docs-kb-md/12-diffs-estruturais-por-tipo.md`
- `docs-kb-md/14-indicios-de-obrigatoriedade.md`

### Operacionais

- `docs-kb-md/13-guia-de-clonagem-segura.md`
- `docs-kb-md/15-tipos-prontos-para-geracao-conservadora.md`
- `docs-kb-md/16-mapa-de-risco-por-tipo.md`
- `docs-kb-md/17-resumo-operacional-para-gerador-xpz.md`
- `docs-kb-md/18-checklist-para-novos-templates.md`

## Sobreposicoes e duplicidades

- `Evidência direta`: os cinco arquivos da raiz antiga cobrem a camada conceitual e resumem resultados da varredura XML.
- `Evidência direta`: os dez arquivos em `docs-kb-md` aprofundam a camada empírica e operacional.
- `Evidência direta`: havia dependência indireta da subpasta `docs-kb-md` para leitura operacional da base.
- `Inferência forte`: a principal sobreposição estava entre resumos conceituais da raiz e recomendações operacionais da subpasta.
- `Inferência forte`: a consolidação correta exigia manter a raiz como ponto de leitura principal e tratar `docs-kb-md` como staging/histórico, não como destino final.

## Conflitos identificados

- `Evidência direta`: o prompt-alvo pede um `00-readme-genexus-xpz-xml.md` e também um `00-inventario-da-base-documental.md`.
- `Inferência forte`: isso cria uma colisao de prefixo, mas nao inviabiliza a ordem de leitura porque os nomes continuam distintos.
- `Evidência direta`: arquivos heurísticos da subpasta (`15`, `16`, `17`) já tinham sido endurecidos para evitar promessas de importação.
- `Inferência forte`: qualquer consolidação precisava preservar essa versão mais conservadora como fonte principal.

## Decisao de consolidacao

- `Evidência direta`: a base final foi reorganizada na raiz com numeracao global.
- `Evidência direta`: os documentos finais passaram a existir na raiz sob os nomes `00`, `01`, `02`, `03`, `04`, `10`, `11`, `12`, `20` a `26`, `30` e `99`.
- `Inferência forte`: a subpasta `docs-kb-md` deve ser tratada como arquivo histórico de trabalho, não como referência operacional primária.


## Origem incorporada - 30-inventario-bruto-kb.md

## Papel do documento
empirico

## Nivel de confianca predominante
alto

## Depende de
nenhum; esta versao substitui o dump bruto nominal para publicacao

## Usado por
01-base-empirica-geral.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 00-readme-genexus-xpz-xml.md

## Objetivo
Preservar os fatos agregados da varredura XML sem expor nomes reais de objeto, modulos, pais, caminhos ou descricoes de negocio da KB de origem.
Servir como base factual publica para verificacao posterior.

- Fonte sanitizada: `C:\SANITIZED\ObjetosDaKbEmXml`
- Escopo analisado: `7219` arquivos XML
- Total de registros de objetos lidos: `7219`
- Total de arquivos problematicos: `0`
- Tipos de objeto observados: `API`, `ColorPalette`, `Dashboard`, `DataProvider`, `DesignSystem`, `Domain`, `Index`, `Module`, `PackagedModule`, `Panel`, `Procedure`, `SDT`, `SubTypeGroup`, `Theme`, `ThemeClass`, `Transaction`, `UserControl`, `WebPanel`, `WorkWithForWeb`

## Contagem por pasta

| FolderType | FileCount |
| --- | ---: |
| API | 1 |
| ColorPalette | 1 |
| Dashboard | 1 |
| DataProvider | 24 |
| DesignSystem | 2 |
| Domain | 137 |
| Index | 228 |
| Module | 27 |
| PackagedModule | 3 |
| Panel | 3 |
| Procedure | 3847 |
| SDT | 181 |
| SubTypeGroup | 709 |
| Theme | 6 |
| ThemeClass | 677 |
| Transaction | 183 |
| UserControl | 7 |
| WebPanel | 1196 |
| WorkWithForWeb | 183 |

## Politica de redacao desta versao publica

- nomes reais de objeto foram removidos desta versao
- caminhos reais da KB foram substituidos por caminho sanitizado
- a utilidade operacional permanece nos documentos `10`, `11`, `12`, `27` e `28`, que preservam contagens, GUIDs e familias estruturais
- para materializacao real de XML ou XPZ, a fonte continua sendo XML bruto privado comparavel, nunca esta versao publica

## Observacao

- Hipotese: o dump nominal completo deve permanecer apenas em acervo privado controlado.
- Inferencia forte: para uso publico, esta versao agregada cobre os fatos necessarios sem expor a KB original.


## Origem incorporada - 98-mapeamento-para-consolidacao-em-10-arquivos.md

## Papel do documento
indice e operacional

## Nivel de confianca predominante
alto

## Depende de
00-readme-genexus-xpz-xml.md, 00-inventario-da-base-documental.md, 99-resumo-da-consolidacao.md

## Usado por
futura consolidacao da base em ate 10 arquivos

## Objetivo
Mapear a base atual para a estrutura consolidada proposta em ate 10 arquivos.
Preservar todo o conteudo existente, definindo destino e criterio de incorporacao antes de qualquer fusao.

## Estrutura alvo

1. `00-readme-genexus-xpz-xml.md`
2. `01-base-empirica-geral.md`
3. `02-regras-operacionais-e-runtime.md`
4. `03-risco-e-decisao-por-tipo.md`
5. `04-webpanel-familias-e-templates.md`
6. `05-transaction-familias-e-templates.md`
7. `06-padroes-de-objeto-e-nomenclatura.md`
8. `07-open-points-e-checklist.md`
9. `08-guia-para-agente-gpt.md`
10. `09-historico-e-inventario-publico.md`

## Regra de consolidacao

- nao apagar conteudo
- nao promover inferencia para evidencia
- manter `Evidência direta`, `Inferência forte` e `Hipótese`
- mover ou fundir por funcao documental, nao por ordem historica de criacao
- quando houver sobreposicao, manter a versao mais clara e mais conservadora

## Mapeamento arquivo a arquivo

### 00-readme-genexus-xpz-xml.md

- Destino principal: `00-readme-genexus-xpz-xml.md`
- Manter:
  - objetivo da base
  - escopo
  - ordem de leitura
  - limites metodologicos
- Incorporar tambem:
  - resumo do fluxo de consulta hoje espalhado em `26-guia-para-agente-gpt.md`

### 00-inventario-da-base-documental.md

- Destino principal: `09-historico-e-inventario-publico.md`
- Manter:
  - inventario dos documentos
  - diagnostico de duplicidade/sobreposicao
  - observacoes sobre reorganizacao da base

### 01-base-empirica-geral.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - premissas empiricas gerais sobre XML/XPZ
  - observacoes gerais de estrutura
  - limites do que foi de fato observado

### 02-genexus-xpz-generation-rules.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - regras gerais de geracao
  - postura conservadora de montagem
  - restricoes de fonte e materializacao
- Integrar sem duplicar trechos que hoje ja estao mais fortes em `02-regras-operacionais-e-runtime.md`

### 03-genexus-object-design-patterns.md

- Destino principal: `06-padroes-de-objeto-e-nomenclatura.md`
- Manter:
  - padroes de nomenclatura
  - padroes de relacionamento aparente
  - leitura conceitual do acervo

### 04-genexus-open-points.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - conflitos
  - lacunas
  - questoes ainda nao fechadas
  - decisoes operacionais provisórias

### 10-matriz-part-types-por-tipo.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - tabela de `PartType`
  - frequencias por tipo
  - classificacao preliminar
- Consolidar como secao:
  - `Part types por tipo`

### 11-campos-estaveis-vs-variaveis.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - atributos recorrentes do no `<Object>`
  - campos estaveis, variaveis e contextuais
- Consolidar como secao:
  - `Campos do no Object`

### 12-diffs-estruturais-por-tipo.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - comparacoes simples vs complexas
  - diferencas por tipo
- Consolidar como secao:
  - `Diffs estruturais`

### 02-regras-operacionais-e-runtime.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - criterios de escolha de template
  - o que preservar
  - o que pode ser alterado com mais cautela
- Consolidar como secao:
  - `Clonagem conservadora`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - leitura heuristica de obrigatoriedade
  - opcionalidade
  - ausencia de evidencia suficiente
- Consolidar como secao:
  - `Obrigatoriedade heuristica`

### 22-tipos-prontos-para-geracao-conservadora.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - classificacao por prontidao relativa
  - decisao operacional atual de `Transaction` e `WebPanel`
- Consolidar como secao:
  - `Prontidao por tipo`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - mapa resumido de risco
  - recomendacao pratica por tipo
- Consolidar como secao:
  - `Mapa de risco`

### 02-regras-operacionais-e-runtime.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - algoritmo de geracao
  - regras de materializacao
  - regras de serializacao XPZ
  - regras de fonte
  - validacoes minimas
- Consolidar como secao central:
  - `Especificacao executavel`

### 25-checklist-para-novos-templates.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - checklist de coleta futura
  - criterios de template adicional
- Consolidar como secao:
  - `Checklist de templates`

### 26-guia-para-agente-gpt.md

- Destino principal: `08-guia-para-agente-gpt.md`
- Manter:
  - ordem de consulta
  - criterios de resposta
  - quando gerar, recusar ou abortar
  - regras de materializacao, serializacao e fonte do ponto de vista do agente
- Incorporar trechos introdutorios mais curtos tambem em `00-readme-genexus-xpz-xml.md`

### 04-webpanel-familias-e-templates.md

- Destino principal: `04-webpanel-familias-e-templates.md`
- Manter:
  - familias estruturais
  - templates representativos
  - regras especificas
  - anexos sanitizados
- Estrutura interna sugerida:
  - visao geral
  - familias
  - regras operacionais
  - anexos sanitizados

### 05-transaction-familias-e-templates.md

- Destino principal: `05-transaction-familias-e-templates.md`
- Manter:
  - familias estruturais
  - regras por familia
  - validacoes de consistencia interna
- Estrutura interna sugerida:
  - visao geral
  - familias
  - regras operacionais
  - validacoes

### 30-inventario-bruto-kb.md

- Destino principal: `09-historico-e-inventario-publico.md`
- Manter:
  - contagens agregadas
  - escopo da varredura
  - politica de versao publica sanitizada
- Nao reincorporar:
  - dump nominal privado antigo

### 99-resumo-da-consolidacao.md

- Destino principal: `09-historico-e-inventario-publico.md`
- Manter:
  - historico da consolidacao
  - decisoes tomadas
  - renomeacoes
  - conflitos resolvidos

## Mapeamento por secao alvo

### 00-readme-genexus-xpz-xml.md

- de `00-readme-genexus-xpz-xml.md`
- de `26-guia-para-agente-gpt.md`: ordem de consulta resumida e limites de uso

### 01-base-empirica-geral.md

- de `01-base-empirica-geral.md`
- de `10-matriz-part-types-por-tipo.md`
- de `11-campos-estaveis-vs-variaveis.md`
- de `12-diffs-estruturais-por-tipo.md`

### 02-regras-operacionais-e-runtime.md

- de `02-genexus-xpz-generation-rules.md`
- de `02-regras-operacionais-e-runtime.md`
- de `02-regras-operacionais-e-runtime.md`

### 03-risco-e-decisao-por-tipo.md

- de `03-risco-e-decisao-por-tipo.md`
- de `22-tipos-prontos-para-geracao-conservadora.md`
- de `03-risco-e-decisao-por-tipo.md`

### 04-webpanel-familias-e-templates.md

- de `04-webpanel-familias-e-templates.md`

### 05-transaction-familias-e-templates.md

- de `05-transaction-familias-e-templates.md`

### 06-padroes-de-objeto-e-nomenclatura.md

- de `03-genexus-object-design-patterns.md`

### 07-open-points-e-checklist.md

- de `04-genexus-open-points.md`
- de `25-checklist-para-novos-templates.md`

### 08-guia-para-agente-gpt.md

- de `26-guia-para-agente-gpt.md`

### 09-historico-e-inventario-publico.md

- de `00-inventario-da-base-documental.md`
- de `30-inventario-bruto-kb.md`
- de `99-resumo-da-consolidacao.md`

## Regras de fusao

- preservar o conteudo integral, movendo para secoes mais amplas
- quando duas secoes disserem quase a mesma coisa, manter a versao mais conservadora e citar a complementar
- tabelas muito grandes devem aparecer uma vez so
- templates sanitizados devem permanecer apenas nos arquivos de tipo, nao em documentos gerais
- historico e inventario devem ficar separados das regras executaveis

## Ordem recomendada de execucao da consolidacao

1. consolidar `09-historico-e-inventario-publico.md`
2. consolidar `01-base-empirica-geral.md`
3. consolidar `02-regras-operacionais-e-runtime.md`
4. consolidar `03-risco-e-decisao-por-tipo.md`
5. manter `04` e `05` como arquivos especializados
6. consolidar `06`, `07` e `08`
7. revisar `00-readme-genexus-xpz-xml.md` por fim, apontando para a nova estrutura

## Observacao final

- Inferencia forte: essa consolidacao reduz bem a fragmentacao sem sacrificar navegabilidade para GPT.
- Hipotese: depois da fusao, a base ficara mais facil de usar do que hoje, desde que os novos arquivos tenham sumario interno e secoes bem delimitadas.


## Origem incorporada - 99-resumo-da-consolidacao.md

## Papel do documento
indice

## Nível de confiança predominante
alto

## Depende de
00-inventario-da-base-documental.md

## Usado por
manutencao futura da base e auditoria de consolidacao

## Objetivo
Registrar o que foi lido, renomeado, consolidado e mantido em aberto durante a reorganização da base documental.

## Arquivos lidos

- os 5 arquivos Markdown legados da raiz
- os 10 arquivos Markdown da subpasta `docs-kb-md`

## Arquivos renomeados/consolidados para a raiz

- `genexus-xpz-research.md` -> `01-base-empirica-geral.md`
- `genexus-xpz-generation-rules.md` -> `02-genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md` -> `03-genexus-object-design-patterns.md`
- `genexus-open-points.md` -> `04-genexus-open-points.md`
- `docs-kb-md/10-matriz-part-types-por-tipo.md` -> `10-matriz-part-types-por-tipo.md`
- `docs-kb-md/11-campos-estaveis-vs-variaveis.md` -> `11-campos-estaveis-vs-variaveis.md`
- `docs-kb-md/12-diffs-estruturais-por-tipo.md` -> `12-diffs-estruturais-por-tipo.md`
- `docs-kb-md/13-guia-de-clonagem-segura.md` -> `02-regras-operacionais-e-runtime.md`
- `docs-kb-md/14-indicios-de-obrigatoriedade.md` -> `03-risco-e-decisao-por-tipo.md`
- `docs-kb-md/15-tipos-prontos-para-geracao-conservadora.md` -> `22-tipos-prontos-para-geracao-conservadora.md`
- `docs-kb-md/16-mapa-de-risco-por-tipo.md` -> `03-risco-e-decisao-por-tipo.md`
- `docs-kb-md/17-resumo-operacional-para-gerador-xpz.md` -> `02-regras-operacionais-e-runtime.md`
- `docs-kb-md/18-checklist-para-novos-templates.md` -> `25-checklist-para-novos-templates.md`
- `docs-kb-md/00-inventario-bruto.md` -> `30-inventario-bruto-kb.md`

## Arquivos criados na consolidacao

- `00-inventario-da-base-documental.md`
- `00-readme-genexus-xpz-xml.md`
- `26-guia-para-agente-gpt.md`
- `99-resumo-da-consolidacao.md`

## Decisoes tomadas

- manter a versao mais conservadora sempre que havia choque entre resumo e heurística operacional
- deixar a raiz como ponto de leitura principal
- tratar `docs-kb-md` como staging/histórico e não como fonte operacional primária
- preservar o caráter heurístico dos antigos `14`, `15`, `16` e `17`, agora `21`, `22`, `23` e `24`
- atualizar a politica para `Transaction` e `WebPanel` de bloqueio por prudencia para execucao controlada com base interna

## Conflitos encontrados

- conflito de prefixo entre `00-readme-genexus-xpz-xml.md` e `00-inventario-da-base-documental.md`
- houve coexistência temporária entre arquivos legados e arquivos consolidados durante a consolidação
- risco de leitura duplicada entre raiz e `docs-kb-md` se não houver orientação clara

## O que permaneceu em aberto

- semântica exata dos GUIDs de `Part type`
- obrigatoriedade real validada por importação
- estabilidade dos padrões fora desta KB
- diferença funcional precisa entre `Module` e `PackagedModule`

## Atualizacao de politica posterior

- `Evidência direta`: a base passou a reconhecer 183 `Transaction` e 1196 `WebPanel` como massa amostral suficiente para execucao controlada.
- `Inferência forte`: a mudanca pratica foi de bloqueio por prudencia para tentativa controlada com template interno da propria base.
- `Evidência direta`: um teste controlado de importacao de `.xpz` minimo de `Procedure` foi bem-sucedido nesta trilha e confirmou o envelope normal sem `KnowledgeBase`.
- `Evidência direta`: o mesmo teste mostrou que `Source/@kb` e `Source/Version/@guid` nao podem ficar como placeholders textuais; precisam ser GUIDs sintaticamente validos.
- `Hipótese`: os erros adicionais de importacao que aparecerem devem continuar sendo incorporados ao refinamento desta mesma documentacao.
