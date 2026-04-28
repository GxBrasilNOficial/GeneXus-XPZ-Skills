# 09 - Inventario e Rastreabilidade Publica

## Papel do documento
indice e rastreabilidade

## Nivel de confianca predominante
alto

## Depende de
nenhum

## Usado por
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md

## Objetivo
Preservar rastreabilidade da consolidacao, inventario documental, inventario bruto publico sanitizado e o mapeamento usado para reorganizar a base consolidada.

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
- `Evidência direta`: `Open-GeneXusKbHeadless.ps1` foi validado com uma KB de teste sanitizada (`KB_Teste_A`), com `EnvironmentName=NETSQLServer`.
- `Evidência direta`: `Test-GeneXusXpzImportPreview.ps1` foi validado com um `XPZ` full exportado nessa mesma KB sanitizada.
- `Evidência direta`: o `PreviewMode` executado nessa validacao nao alterou a KB.
- `Evidência direta`: `Invoke-GeneXusXpzImport.ps1` foi validado com o `XPZ` exportado nesta frente e concluiu com sucesso operacional, embora tenha produzido mensagens de stderr no log.
- `Evidência direta`: uma nova rodada de importacao real com a KB fechada manteve o mesmo padrao de `stderr`, incluindo as mensagens de `mismatched input ']' expecting 'default'` e o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`, sem impedir `exitCode = 0`.
- `Evidência direta`: na instalacao validada nesta conversa, `IncludeItems` e `ExcludeItems` funcionaram em `PreviewMode`, enquanto `UpdateFile` e `ImportKBInformation` ficaram bloqueados por ausencia de propriedade publica correspondente na task `Import` carregada.
- `Evidência direta`: os wrappers de preview e importacao real passaram a normalizar recortes multiplos de `IncludeItems` e `ExcludeItems`, com serializacao em formato de lista aceito operacionalmente pela task carregada.
- `Evidência direta`: depois dessa normalizacao, recortes combinados passaram a funcionar de forma confiavel e permitiram reduzir o ruido lateral sem alterar o `exitCode = 0` da importacao real.
- `Evidência direta`: na bateria de recortes desta frente, o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json` deixou de ficar restrito a um conjunto pequeno de objetos da `KB_Teste_A` e reapareceu tambem em `Procedure:procExtraiTextoDoPdf`, `Procedure:procGeraPdfDoDANFCE` e `Procedure:procCarregaSDTsDaNFe`.
- `Evidência direta`: no recorte mais reduzido desta bateria, a importacao real manteve `exitCode = 0`, mas o log passou a destacar `src0246` em `Procedure:procCarregaSDTsDaNFe`, com referencia a objeto nao definido `procStrZERO`.
- `Evidência direta`: na inspecao do XML extraido do `XPZ` exportado com `ExportAll=true`, `procStrZERO` apareceu no bloco `Source`, mas nao apareceu como objeto exportado nem como referencia declarada do pacote.
- `Evidência direta`: um teste controlado derivando o `XPZ` exportado via headless e preenchendo o `Source` global com os valores do pacote full nao alterou o padrao principal da importacao real; `CssProperties.json`, `mismatched input ']' expecting 'default'`, `src0246` e `procStrZERO` permaneceram no mesmo comportamento observado antes.
- `Evidência direta`: um segundo teste controlado derivando o mesmo `XPZ` exportado via headless e trocando apenas as duas ocorrencias de `Pattern Settings` de `Padrões GeneXus` para `GeneXus Patterns` tambem nao alterou o padrao principal da importacao real.
- `Inferência forte`: com esses dois testes, as duas diferencas remanescentes identificadas entre o pacote full e o export headless deixaram de ser suspeitas fortes para o ruido principal desta frente.
- `Evidência direta`: em uma segunda KB de teste sanitizada (`KB_Teste_B`), a exportacao full headless com `ExportAll=true` concluiu com sucesso operacional, `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, o `PreviewMode` de importacao do pacote full exportado headless concluiu com `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, a importacao real do pacote full exportado headless concluiu com `exitCode = 0`; o `stderr` residual observado ficou restrito ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteudo especifico da `KB_Teste_A`.
- `Inferência forte`: a bateria em `KB_Teste_B` reforca que a trilha headless de exportacao, preview e importacao via `MSBuild` funciona em outra KB e que o caso `procCarregaSDTsDaNFe`/`procStrZERO` pertence ao conteudo da `KB_Teste_A`, nao ao mecanismo central da skill.
- `Evidência direta`: em uma terceira KB de teste sanitizada (`KB_Teste_C`), a bateria de exportacao full headless, preview de importacao e importacao real do pacote exportado tambem concluiu com sucesso operacional.
- `Evidência direta`: na primeira tentativa de `preview` e importacao de `KB_Teste_C`, o erro foi apenas de orquestracao local (`XpzPath inválido` antes de o arquivo existir), por disparo concorrente antes do fim do export; repetida a rodada em sequencia correta, o fluxo passou sem bloqueio funcional novo.
- `Evidência direta`: na mesma `KB_Teste_C`, o `stderr` residual da importacao real voltou a ficar limitado ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteudo observado na `KB_Teste_A`.
- `Evidência direta`: em uma quarta KB de teste sanitizada (`KB_Teste_D`), a abertura headless confirmou um `Environment` coerente, e a bateria de exportacao full headless, preview de importacao e importacao real do pacote exportado tambem concluiu com sucesso operacional.
- `Evidência direta`: na `KB_Teste_D`, o `stderr` residual da importacao real permaneceu restrito ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`, sem bloqueio de conteudo equivalente ao caso `procCarregaSDTsDaNFe`/`procStrZERO`.
- `Evidência direta`: em uma quinta KB de teste sanitizada (`KB_Teste_E`), a abertura headless confirmou um contexto ativo coerente, e a bateria de exportacao full headless, preview de importacao e importacao real do pacote exportado tambem concluiu com `exitCode = 0`.
- `Evidência direta`: na `KB_Teste_E`, o `PreviewMode` registrou no `stdout` mensagens de contato com `GeneXus Server` em `http://sandbox.genexusserver.com/v18`, exigencia de credenciais e ausencia de licenca `GXtest` valida, mesmo mantendo `exitCode = 0`.
- `Evidência direta`: na mesma `KB_Teste_E`, `importedItems` veio vazio tanto no preview quanto na importacao real, o que impede tratar essa rodada como evidência de sucesso funcional equivalente às KBs `KB_Teste_B`, `KB_Teste_C` e `KB_Teste_D`.
- `Evidência direta`: em `KB_Teste_F`, a bateria completa de exportacao full headless, preview de importacao e importacao real concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importacao real, e o `stderr` residual ficou restrito ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_G`, a bateria completa de exportacao full headless, preview de importacao e importacao real tambem concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importacao real, com o mesmo `stderr` lateral observado nas KBs favoraveis anteriores.
- `Evidência direta`: em `KB_Teste_H`, a bateria completa de exportacao full headless, preview de importacao e importacao real tambem concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importacao real, com o mesmo `stderr` lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_Grande_A`, a abertura headless, o export full headless e o preview de importacao concluiram com sucesso operacional; o preview trouxe `importedItems` preenchido mesmo em uma KB de grande porte.
- `Evidência direta`: na mesma `KB_Teste_Grande_A`, a abertura, o export e o preview reportaram warning recorrente sobre item desconhecido `WebPanelDesigner`, fornecido por extensao ausente `K2B Object Designer`, com alerta de risco de perda de informacao relacionada a esses itens.
- `Evidência direta`: na importacao real da `KB_Teste_Grande_A`, o wrapper inicial bateu timeout por duracao extrema, mas o processo `MSBuild` continuou em execucao; o monitoramento posterior confirmou progresso continuo, inclusive em geracao de padroes `WorkWith`, ate o `stdout` terminar com `Close Knowledge Base Task Sucesso`.
- `Inferência forte`: a `KB_Teste_Grande_A` demonstrou que a skill consegue concluir tambem em KB de grande porte, mas com janela de execucao muito superior a das KBs medias; para esse perfil, timeout curto do wrapper nao deve ser confundido com falha da operacao.
- `Inferência forte`: com evidência operacional repetida em `KB_Teste_A`, `KB_Teste_B`, `KB_Teste_C`, `KB_Teste_D`, `KB_Teste_F`, `KB_Teste_G`, `KB_Teste_H`, `KB_Teste_Grande_A` e agora `KB_Teste_E`, a trilha central de exportacao, preview e importacao via `MSBuild` permanece validada como mecanismo experimental; ao mesmo tempo, ficou demonstrado que `exitCode = 0` isolado nao basta para validar sucesso funcional quando a KB aciona dependencia externa de `GeneXus Server` ou restricao de licenca, e que KBs muito grandes exigem janela de execucao compativel com a escala.
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
00-indice-da-base-genexus-xpz-xml.md, 04-genexus-open-points.md, 99-resumo-da-consolidacao.md

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
01-base-empirica-geral.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 00-indice-da-base-genexus-xpz-xml.md

## Objetivo
Preservar os fatos agregados da varredura XML sem expor nomes reais de objeto, modulos, pais, caminhos ou descricoes de negocio da KB de origem.
Servir como base factual publica para verificacao posterior.

- Fonte sanitizada: `C:\SANITIZED\ObjetosDaKbEmXml`
- Escopo analisado: `7416` arquivos XML
- Total de registros de objetos lidos: `7416`
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
- para materializacao real de XML ou XPZ, a fonte continua sendo XML bruto privado comparavel, exceto nos casos em que a propria base publica ja publicar bloco `molde pronto` suficiente para materializacao controlada

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
futura consolidacao da base em serie documental mais enxuta e roteavel

## Objetivo
Mapear a base atual para a estrutura consolidada proposta, incluindo a serie `01` desdobrada.
Preservar todo o conteudo existente, definindo destino e criterio de incorporacao antes de qualquer fusao.

## Estrutura alvo

1. `00-indice-da-base-genexus-xpz-xml.md`
2. `01-base-empirica-geral.md`
3. `02-regras-operacionais-e-runtime.md`
4. `03-risco-e-decisao-por-tipo.md`
5. `04-webpanel-familias-e-templates.md`
6. `05-transaction-familias-e-templates.md`
7. `06-padroes-de-objeto-e-nomenclatura.md`
8. `07-open-points-e-checklist.md`
9. `08-guia-para-agente-gpt.md`
10. `09-inventario-e-rastreabilidade-publica.md`

## Regra de consolidacao

- nao apagar conteudo
- nao promover inferencia para evidencia
- manter `Evidência direta`, `Inferência forte` e `Hipótese`
- mover ou fundir por funcao documental, nao por ordem historica de criacao
- quando houver sobreposicao, manter a versao mais clara e mais conservadora

## Mapeamento arquivo a arquivo

### 00-indice-da-base-genexus-xpz-xml.md

- Destino principal: `00-indice-da-base-genexus-xpz-xml.md`
- Manter:
  - objetivo da base
  - escopo
  - ordem de leitura
  - limites metodologicos
- Incorporar tambem:
  - resumo do fluxo de consulta hoje espalhado em `26-guia-para-agente-gpt.md`

### 00-inventario-da-base-documental.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - inventario dos documentos
  - diagnostico de duplicidade/sobreposicao
  - observacoes sobre reorganizacao da base

### 01-base-empirica-geral.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - indice mestre da serie `01`
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

- Destino principal: `01b-matriz-part-types-por-tipo.md`
- Manter:
  - tabela de `PartType`
  - frequencias por tipo
  - classificacao preliminar
- Consolidar como arquivo filho da serie `01`

### 11-campos-estaveis-vs-variaveis.md

- Destino principal: `01c-campos-estaveis-vs-variaveis.md`
- Manter:
  - atributos recorrentes do no `<Object>`
  - campos estaveis, variaveis e contextuais
- Consolidar como arquivo filho da serie `01`

### 12-diffs-estruturais-por-tipo.md

- Destino principal: `01d-diffs-estruturais-por-tipo.md`
- Manter:
  - comparacoes simples vs complexas
  - diferencas por tipo
- Consolidar como arquivo filho da serie `01`

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
- Incorporar trechos introdutorios mais curtos tambem em `00-indice-da-base-genexus-xpz-xml.md`

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

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - contagens agregadas
  - escopo da varredura
  - politica de versao publica sanitizada
- Nao reincorporar:
  - dump nominal privado antigo

### 99-resumo-da-consolidacao.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - historico da consolidacao
  - decisoes tomadas
  - renomeacoes
  - conflitos resolvidos

## Mapeamento por secao alvo

### 00-indice-da-base-genexus-xpz-xml.md

- de `00-indice-da-base-genexus-xpz-xml.md`
- de `26-guia-para-agente-gpt.md`: ordem de consulta resumida e limites de uso

### 01-base-empirica-geral.md

- de `01-base-empirica-geral.md`
- de `10-matriz-part-types-por-tipo.md`
- de `11-campos-estaveis-vs-variaveis.md`
- de `12-diffs-estruturais-por-tipo.md`
- reorganizado depois como serie `01` com indice mestre em `01-base-empirica-geral.md` e arquivos filhos `01a` a `01h`

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

### 09-inventario-e-rastreabilidade-publica.md

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

1. consolidar `09-inventario-e-rastreabilidade-publica.md`
2. consolidar `01-base-empirica-geral.md`
3. consolidar `02-regras-operacionais-e-runtime.md`
4. consolidar `03-risco-e-decisao-por-tipo.md`
5. manter `04` e `05` como arquivos especializados
6. consolidar `06`, `07` e `08`
7. revisar `00-indice-da-base-genexus-xpz-xml.md` por fim, apontando para a nova estrutura

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

## Aliases publicos de Procedure de relatorio

Estes aliases foram criados em 2026-04-25 a partir da analise estrutural de 77 XMLs de `Procedure` de relatorio no acervo privado. Cada alias representa o menor XML observado dentro da respectiva familia estrutural definida em `05b-procedure-relatorio-familias-e-templates.md`.

| Alias publico | Familia | Criterio estrutural |
|---|---|---|
| `PRCRelatorioExemploF1` | F1 — Embriao sem layout ativo | FE=0, sem Header, sem Footer; menor XML da faixa |
| `PRCRelatorioExemploF2` | F2 — Molde base com cabecalho de pagina | FE=0, com Header e/ou Footer; menor XML da faixa |
| `PRCRelatorioExemploF3` | F3 — Listagem linear simples | FE=1-2; menor XML da faixa |
| `PRCRelatorioExemploF4` | F4 — Relatorio com agrupamento e totalizacao | FE=3-6, PB<=24; menor XML da faixa |
| `PRCRelatorioExemploF5` | F5 — Relatorio complexo de alto volume | FE>=7 ou PB>=25; menor XML com FE>=10 e PB>=20 simultaneamente |

- Rastreabilidade privada: os nomes reais dos representantes estao registrados em `GeneXus-XPZ-PrivateMap/maps/object-alias-map.csv`.
- Uso previsto: esses aliases servem como referencia estrutural para `xpz-reader`, `xpz-builder` e `xpz-doc-builder` ao trabalhar com `Procedure` de relatorio.
- Regra editorial: nunca usar o alias como unica fonte para materializacao.
- Regra editorial: quando `05b-procedure-relatorio-familias-e-templates.md` oferecer `molde pronto` suficiente para a familia simples coberta, o alias pode servir apenas como referencia de classificacao para chegar a esse molde sanitizado.
- Regra editorial: fora dessa cobertura simples, ou depois de tentativa inicial mais um unico corretivo curto sem sucesso, o proximo passo obrigatorio volta a ser XML real comparavel.
