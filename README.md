# Knowledge GeneXus

## Manutenção trilíngue do README

- a seção `Português (BR)` é a fonte editorial primária do `README.md`
- toda alteração de conteúdo, estrutura, regra operacional ou nomenclatura feita na seção `Português (BR)` deve ser refletida também nas seções `Español` e `English`
- não deixar traduções parciais, defasadas ou estruturalmente incompletas em relação à versão em português
- ao editar apenas uma das três seções, validar explicitamente se as outras duas continuam consistentes
- se a atualização completa das três línguas não puder ser feita na mesma frente, sinalizar isso como pendência explícita antes de concluir

## Português (BR)

Este repositório existe para sustentar e operacionalizar skills para agentes dedicadas ao ecossistema `XPZ`/XML de GeneXus, em especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-msbuild-import-export` e `xpz-index-triage`.

A documentação consolidada e os scripts desta raiz funcionam como base metodológica e operacional dessas skills, com foco em:

- leitura e interpretação de estrutura XML
- famílias estruturais de objetos
- risco por tipo de objeto
- clonagem conservadora
- apoio à geração assistida de `XPZ`
- validação documental de envelope e importação em casos controlados

### O que você vai encontrar aqui

Os arquivos abaixo formam a base compartilhada principal desta raiz, consolidada para facilitar leitura, manutenção e uso controlado.

Além dessa base principal, a raiz também pode conter documentação operacional complementar de frentes ativas, quando ela ainda precisar permanecer visível fora de `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` ate `01h-moldes-sanitizados-metadados-e-artefatos.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: base operacional da trilha MSBuild headless, usada pela skill `xpz-msbuild-import-export`

Os arquivos `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` e `12-diffs-estruturais-por-tipo.md` sao stubs de compatibilidade retroativa: cada um redireciona para o equivalente na serie `01` (`01b`, `01c`, `01d`). Nao contem conteudo proprio e nao devem ser usados como fonte direta.

### Documentacao operacional KB Intelligence

Arquivos da serie KB Intelligence presentes na raiz enquanto a frente estiver ativa. Quando encerrados, migram para `historico/kb-intelligence/`.

- `11-plano-kb-intelligence-incremental.md`
- `14-kb-intelligence-fase-3-contrato.md`
- `16-kb-intelligence-fase-5-contrato.md`
- `17-kb-intelligence-fase-6-contrato.md`
- `18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md`
- `19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md`
- `21-kb-intelligence-fase-6-checklist-operacional-agente.md`
- `22-kb-intelligence-fase-6-contrato-functional-trace-basic.md`
- `23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md`
- `26-kb-intelligence-fase-6-verificacao-pos-filtro.md`
- `27-kb-intelligence-fase-6-primeira-resposta-funcional.md`
- `29-kb-intelligence-estudo-update-incremental.md`

### Skills para agentes

- `xpz-reader`: apoio à leitura e interpretação estrutural de `XPZ` e XMLs relacionados
- `xpz-builder`: apoio à materialização controlada de artefatos e envelopes `XPZ`
- `xpz-sync`: orquestração de sincronização e conferência do acervo XML a partir de parâmetros explícitos e scripts em `scripts/`
- `xpz-daemon`: instalação e gerenciamento de um monitor persistente que observa pastas de XPZ e dispara sincronização automaticamente ao detectar novos arquivos
- `xpz-doc-builder`: geração e recomposição de documentação Markdown a partir do acervo XML e de moldes sanitizados
- `xpz-kb-parallel-setup`: preparação e validação da estrutura inicial da pasta paralela da KB
- `xpz-msbuild-import-export`: skill experimental para importação e exportação de `XPZ` via `MSBuild`, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates de segurança
- `xpz-index-triage`: triagem inicial por índice derivado para orientar a leitura mínima dos XMLs oficiais da KB

### Leitura recomendada para humanos

Se você quer entender a base rapidamente:

1. comece por `00-indice-da-base-genexus-xpz-xml.md`
2. siga para `01-base-empirica-geral.md` e desça ao filho da série `01` mais aderente ao caso (`01a` a `01h`)
3. depois leia `02-regras-operacionais-e-runtime.md`
4. em seguida leia `03-risco-e-decisao-por-tipo.md`
5. para casos práticos, use `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md` e `05b-procedure-relatorio-familias-e-templates.md`
6. se quiser entender limites e próximas frentes, leia `07-open-points-e-checklist.md`
7. para consumo por outro agente GPT, termine em `08-guia-para-agente-gpt.md`
8. para conferir rastreabilidade do inventário, consulte `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: leitura suplementar — indicado quando a dúvida envolver nomenclatura de objetos, prefixos de tipo ou comportamento de `Folder` vs `Module` no `fullyQualifiedName`.

### Avisos importantes

- esta base prioriza evidência estrutural observada em XML
- ela não promete sucesso de importação ou build sem validação externa
- a base já incorpora testes documentados de importação em casos controlados, mas isso não elimina risco
- antes de gerar `import_file.xml` ou pacote importável, a trilha deve separar explicitamente `XML bem-formado` de `Source GeneXus estruturalmente conservador/provavelmente importável`; parse XML sozinho não basta
- em revisão e sanity de objeto legado, a trilha deve separar explicitamente `sanity absoluto do artefato atual` de `comparacao contra baseline oficial`; `igual ao baseline` nao significa `bom`, e `pior que o baseline` indica regressao do delta
- moldes sanitizados completos podem servir como ponto de partida em cenários específicos documentados na própria base; resumos textuais e exemplos incompletos não servem como fonte final de materialização
- o conteúdo foi organizado para reduzir tentativa e erro, não para eliminar risco
- existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada apenas para rastreabilidade editorial privada entre aliases públicos e artefatos reais; a fonte publicada continua sendo esta raiz
- todo novo exemplo sanitizado incorporado na base pública deve receber anotação correspondente no `GeneXus-XPZ-PrivateMap`, ligando o trecho público aos objetos ou pacotes reais de origem
- **modelos de linguagem**: as skills XPZ dependem de carregamento voluntário de skills, execução sequencial de gates e respeito a constraints do tipo NEVER. Modelos fracos ou com tendência a pular etapas (ex: GLM 5.1, DeepSeek V4 Flash, Kimi K2.6, Qwen 3.5 Plus, Qwen 3.6 Plus, MiniMax M2.7, MiMo-V2.5-Pro) não são confiáveis para triagem GeneXus e não devem ser recomendados a usuários. Prefira modelos com forte aderência a instruções (DeepSeek V4 Pro, GPT-5.4, Sonnet 4.6, Opus 4.7).

### Topologia operacional

- nesta trilha, a pasta nativa da KB GeneXus e diferente da pasta paralela da KB
- nesta trilha, a pasta nativa da KB deve ser tratada como area proibida para gravacao por agentes; leitura e permitida apenas quando o fluxo operacional explicito realmente exigir
- a pasta paralela da KB e a pasta de trabalho que concentra `XPZ` exportados pela IDE, XMLs materializados pelo fluxo oficial, indice derivado para triagem e artefatos preparados para importação posterior

- `ObjetosDaKbEmXml`: snapshot oficial da KB; somente leitura para agentes
- `KbIntelligence`: pasta do índice SQLite derivado e regenerável, usado para triagem técnica e funcional curta sem substituir o snapshot oficial
- `KbIntelligence` só deve ser usado para triagem ampla quando `last_index_build_run_at` no SQLite for igual ou posterior a `last_xpz_materialization_run_at` em `kb-source-metadata.md`; todo sync XPZ/XML oficial deve regenerar/validar o índice logo depois da materialização, e índice ausente ou defasado é exceção operacional que deve bloquear pesquisa ampla/geração e oferecer atualização ao usuário
- quando `AGENTS.md` ou `README.md` locais da pasta paralela declararem timestamps, estado operacional ou observações de frescor, esses campos devem permanecer coerentes com `kb-source-metadata.md`, com `-Query index-metadata` do wrapper local e com o gate efetivo; drift documental local também é pendência de setup
- `XpzExportadosPelaIDE`: pasta onde o usuário grava tanto o `XPZ` completo da Carga Inicial quanto os `XPZ` incrementais do dia a dia
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabalho para XMLs gerados, ajustados ou preservados para importação manual na IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de saída para `import_file.xml` e demais pacotes gerados localmente
- `Temp`: destino preferencial de artefatos efêmeros de execução, como diretórios temporários de wrappers, logs auxiliares e saídas intermediárias que não sejam fonte normativa da base
- `ArquivoMorto`: subpasta opcional de `ObjetosGeradosParaImportacaoNaKbNoGenexus` para preservar XMLs contaminados que nao devem ser importados mas precisam de rastreabilidade; nao apagar sem autorizacao explicita do usuario
- em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente ativa deve usar sua propria subpasta no formato `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifica a frente pela combinacao de nome curto, GUID gerado na abertura da frente e data de criacao da frente; `YYYYMMDD` representa a data de criacao da frente, nao a data do pacote
- em `PacotesGeradosParaImportacaoNaKbNoGenexus`, os pacotes devem permanecer na raiz, sem subpastas, usando o formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa apenas a rodada curta de pacote daquela frente; nao representa versao semantica
- antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar se ja existe pacote com o mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn`
- se ja existir pacote com o mesmo prefixo de frente e o mesmo `nn`, abortar a gravacao; nao sobrescrever silenciosamente a rodada
- em caso de colisao, retornar erro explicito com sugestao do proximo `nn` livre para aquela frente, sem autoincrementar nem gravar automaticamente com o valor sugerido
- a promoção para `ObjetosDaKbEmXml` ocorre apenas pelo fluxo oficial do script `.ps1` alimentado por `XPZ` exportado pela IDE
- `ObjetosDaKbEmXml` nao deve ser atualizado por edição manual; ele e atualizado pelo fluxo do `.ps1` a partir dos `XPZ` disponibilizados na pasta paralela da KB
- se o objeto ainda nao voltou da KB por export oficial, o trabalho deve acontecer em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- edição detectada ou pretendida em `ObjetosDaKbEmXml` para delta ainda não reexportado oficialmente pela KB deve ser tratada como erro explícito de processo, não como detalhe operacional
- `AGENTS.md`, `README.md` e documentação equivalente da KB funcionam como camada obrigatória de especialização local; suas regras valem para aquele repositório e não devem ser promovidas automaticamente à metodologia compartilhada de XPZ
- frente tecnicamente validada nao implica publicacao Git; a publicacao so ocorre com autorizacao explicita do usuario, e ate la o estado preferido e `aguardando_decisao_de_fechamento`

### Carga inicial

- quando o usuário não informar nomes alternativos, a KB deve assumir estas subpastas padrão:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` é a pasta de entrada onde o usuário do GeneXus grava os `.xpz` que serão processados
- depois de processado com sucesso pelo fluxo oficial, o `.xpz` pode ser renomeado para `processado_<nome-original>.xpz`
- `scripts` concentra os wrappers `.ps1` que tratam `XPZ` e indice derivado
- quando a pasta paralela da KB for inicializada do zero para operar com fluxo oficial de materializacao XPZ/XML, o bootstrap tecnico minimo deve incluir os wrappers locais principais em `scripts`
- nao declarar `setup inicial concluido` enquanto essa camada minima de wrappers locais ainda nao existir; nesse caso, o status correto e `estrutura parcial` ou `bootstrap incompleto`
- `Test-*KbSourceSanity.ps1` e recomendado quando a pasta tambem adotar fluxo local de geracao e empacotamento; sua ausencia isolada nao impede, por si so, classificar a camada minima de wrappers do fluxo oficial de materializacao ou de `KbIntelligence`
- `KbIntelligence` guarda o SQLite derivado e os relatórios de validação do índice, quando esse fluxo estiver adotado na KB
- a Carga Inicial pode usar um `XPZ` completo novo a qualquer momento para reatualizar `ObjetosDaKbEmXml`
- `XPZ` full define o insumo exportado; a materializacao normal desse insumo nao implica `-FullSnapshot`, que deve ficar restrito a conferencia full explicita ou exigencia documental nominal
- a mesma estrutura também vale para `XPZ` parciais com objetos alterados desde a última atualização
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` guarda objetos temporários destinados à importação manual na IDE
- cada frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus` deve ter sua propria subpasta `NomeCurto_GUID_YYYYMMDD`
- essa subpasta da frente e a unidade ativa da frente de trabalho
- ao retomar uma frente existente, reutilizar a mesma subpasta da frente em vez de criar outra
- `PacotesGeradosParaImportacaoNaKbNoGenexus` guarda o pacote `.xml` e, quando necessário, também `.xpz`, que será importado pela IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` deve permanecer plano, sem subpastas por frente; o vinculo com a frente fica apenas no prefixo `NomeCurto_GUID_YYYYMMDD` somado ao `nn`
- por padrao, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` nao precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteudo, isso deve ser tratado como decisao de politica do repositorio
- `AGENTS.md` e `README.md` podem existir na raiz ou em subpastas quando houver anotação operacional pertinente
- se alguma dessas subpastas ainda não existir, a ordem recomendada de criação é:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando a pasta paralela ja estiver versionada em Git e o setup inicial partir de estrutura vazia, `.gitignore` na raiz e `.gitkeep` nas subpastas vazias fazem parte do bootstrap esperado
- quando a pasta paralela ainda nao estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional; nao deve executar `git init` sem aprovacao explicita do usuario
- se o usuario aceitar versionamento Git local e o Git nao estiver funcional no ambiente, o agente pode oferecer instalar ou orientar a instalacao antes do bootstrap Git
- alterar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisao de politica do repositorio; o agente pode diagnosticar e propor opcoes, mas nao deve mudar essa politica automaticamente so para concluir o fechamento
- quando `XpzExportadosPelaIDE` ainda não existir, o agente deve perguntar onde o usuário pretende salvar os `.xpz` antes de prosseguir com o processamento
- no setup inicial da pasta paralela da KB, se o caminho da pasta nativa da KB nao vier informado, o agente deve pedir esse caminho ao usuario antes de concluir o setup
- no setup inicial da pasta paralela da KB, `kb-source-metadata.md` deve nascer em formato compativel com o motor compartilhado e preservar o campo nominal `last_xpz_materialization_run_at`
- quando `ObjetosDaKbEmXml` ainda não existir, o agente deve tratar isso como KB ainda não materializada e parar antes de assumir qualquer snapshot
- ao concluir o setup inicial da pasta paralela da KB, o agente deve deixar explicito que a estrutura esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
- ao concluir o setup inicial, o agente deve oferecer `A)` exportacao do `.xpz` full pela IDE para `XpzExportadosPelaIDE` ou `B)` geracao do `.xpz` full a partir da pasta nativa da KB via trilha `MSBuild`, seguida de materializacao dos XMLs
- no fechamento do setup inicial, `A)` deve ser apresentado como caminho preferencial e normalmente mais rapido; `B)` deve ser apresentado como caminho possivel, porem mais lento por depender da trilha via `MSBuild`

### Automação operacional

- o script `scripts/Sync-GeneXusXpzToXml.ps1` faz parte da infraestrutura operacional desta base e nao deve ser removido do repositório público
- esse script pode ser usado por projetos de produção que mantenham acervos versionados de XMLs extraidos de `XPZ`
- a pasta `scripts/` existe como apoio operacional, analitico e editorial compartilhavel, mas nao e fonte normativa da documentacao consolidada da raiz
- os scripts públicos desta raiz devem operar por parâmetros explícitos de entrada e saída, sem depender de caminhos absolutos privados
- os `.example.ps1` publicados nas skills funcionam como exemplos metodologicos importantes para bootstrap tecnico e reconstrucao assistida de wrappers locais finais
- esses `.example.ps1` nao substituem o wrapper local real da pasta paralela da KB e nao devem virar fallback automatico de execucao no fluxo normal
- quando a sessao ja publicar o caminho de uma skill ou de seus exemplos, esse caminho publicado prevalece sobre heuristica local de instalacao
- memoria operacional de setup e compatibilidade deve permanecer primeiro na propria pasta paralela da KB, em `AGENTS.md`, `README.md` e arquivos operacionais locais; memoria externa do agente fora do repositorio nao deve ser tratada como requisito nem ser gravada sem autorizacao explicita do usuario
- se o motor precisar evoluir, a mudança deve preservar compatibilidade com esse uso ou ser acompanhada de atualização explícita dos wrappers consumidores

---

## Español

Este repositorio reúne documentación consolidada sobre análisis estructural de objetos GeneXus a partir de XMLs extraídos de `XPZ`, con foco en skills para agentes dedicadas al ecosistema `XPZ`/XML de GeneXus, en especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-msbuild-import-export` y `xpz-index-triage`.

- lectura e interpretación de estructura XML
- familias estructurales de objetos
- riesgo por tipo de objeto
- clonación conservadora
- apoyo a la generación asistida de `XPZ`
- validación documental de contenedor e importación en casos controlados

### Qué encontrarás aquí

Los archivos de abajo forman la base compartida principal de esta raíz, consolidada para facilitar lectura, mantenimiento y uso controlado.

Además de esa base principal, la raíz también puede contener documentación operativa complementaria de frentes activas, cuando todavía necesite permanecer visible fuera de `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` hasta `01h-moldes-sanitizados-metadados-e-artefatos.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: base operacional de la trilha MSBuild headless, usada por la skill `xpz-msbuild-import-export`

Los archivos `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` y `12-diffs-estruturais-por-tipo.md` son stubs de compatibilidad retroactiva: cada uno redirige al equivalente en la serie `01` (`01b`, `01c`, `01d`). No contienen contenido propio y no deben usarse como fuente directa.

### Documentacion operacional KB Intelligence

Archivos de la serie KB Intelligence presentes en la raíz mientras la frente esté activa. Cuando se cierran, migran a `historico/kb-intelligence/`.

- `11-plano-kb-intelligence-incremental.md`
- `14-kb-intelligence-fase-3-contrato.md`
- `16-kb-intelligence-fase-5-contrato.md`
- `17-kb-intelligence-fase-6-contrato.md`
- `18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md`
- `19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md`
- `21-kb-intelligence-fase-6-checklist-operacional-agente.md`
- `22-kb-intelligence-fase-6-contrato-functional-trace-basic.md`
- `23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md`
- `26-kb-intelligence-fase-6-verificacao-pos-filtro.md`
- `27-kb-intelligence-fase-6-primeira-resposta-funcional.md`
- `29-kb-intelligence-estudo-update-incremental.md`

### Skills para agentes

- `xpz-reader`: apoyo a la lectura e interpretación estructural de `XPZ` y XMLs relacionados
- `xpz-builder`: apoyo a la materialización controlada de artefactos y envelopes `XPZ`
- `xpz-sync`: orquestación de sincronización y verificación del acervo XML a partir de parámetros explícitos y scripts en `scripts/`
- `xpz-daemon`: instalación y gestión de un monitor persistente que observa carpetas de XPZ y dispara sincronización automáticamente al detectar nuevos archivos
- `xpz-doc-builder`: generación y recomposición de documentación Markdown a partir del acervo XML y de moldes sanitizados
- `xpz-kb-parallel-setup`: preparación y validación de la estructura inicial de la carpeta paralela de la KB
- `xpz-msbuild-import-export`: skill experimental para importación y exportación de `XPZ` vía `MSBuild`, con ejecución sin interfaz gráfica, parámetros explícitos, trazabilidad y compuertas de seguridad
- `xpz-index-triage`: triaje inicial por índice derivado para orientar la lectura mínima de los XML oficiales de la KB

### Lectura recomendada para humanos

Si quieres entender la base rápidamente:

1. empieza por `00-indice-da-base-genexus-xpz-xml.md`
2. continúa con `01-base-empirica-geral.md` y baja al hijo de la serie `01` más adherente al caso (`01a` a `01h`)
3. luego lee `02-regras-operacionais-e-runtime.md`
4. después lee `03-risco-e-decisao-por-tipo.md`
5. para casos prácticos, usa `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md` y `05b-procedure-relatorio-familias-e-templates.md`
6. si quieres ver límites y siguientes frentes, lee `07-open-points-e-checklist.md`
7. para consumo por otro agente GPT, termina en `08-guia-para-agente-gpt.md`
8. para verificar trazabilidad del inventario, consulta `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: lectura suplementaria — indicado cuando la duda involucre nomenclatura de objetos, prefijos de tipo o comportamiento de `Folder` vs `Module` en `fullyQualifiedName`.

### Avisos importantes

- esta base prioriza evidencia estructural observada en XML
- no promete éxito de importación o build sin validación externa
- la base ya incorpora pruebas documentadas de importación en casos controlados, pero eso no elimina el riesgo
- antes de generar `import_file.xml` o paquete importable, la trilha debe separar explícitamente `XML bien formado` de `Source GeneXus estructuralmente conservador/probablemente importable`; el parseo XML por sí solo no alcanza
- en revisión y sanity de objeto legado, la trilha debe separar explícitamente `sanity absoluto del artefacto actual` de `comparacion contra baseline oficial`; `igual al baseline` no significa `bueno`, y `peor que el baseline` indica regresion del delta
- moldes sanitizados completos pueden servir como punto de partida en escenarios específicos documentados en la propia base; resúmenes textuales y ejemplos incompletos no sirven como fuente final de materialización
- el contenido fue organizado para reducir prueba y error, no para eliminar riesgo
- existe una carpeta privada separada, `GeneXus-XPZ-PrivateMap`, usada solo para trazabilidad editorial privada entre aliases públicos y artefactos reales; la fuente publicada sigue siendo esta raíz
- todo nuevo ejemplo sanitizado incorporado en la base pública debe recibir una anotación correspondiente en `GeneXus-XPZ-PrivateMap`, vinculando el trecho público con los objetos o paquetes reales de origen
- **modelos de lenguaje**: las skills XPZ dependen de carga voluntaria de skills, ejecución secuencial de gates y respeto a constraints del tipo NEVER. Modelos débiles o con tendencia a saltar etapas (ej: GLM 5.1, DeepSeek V4 Flash, Kimi K2.6, Qwen 3.5 Plus, Qwen 3.6 Plus, MiniMax M2.7, MiMo-V2.5-Pro) no son confiables para triaje GeneXus y no deben recomendarse a usuarios. Prefiere modelos con fuerte adherencia a instrucciones (DeepSeek V4 Pro, GPT-5.4, Sonnet 4.6, Opus 4.7).

### Topología operativa

- en esta trilha, la carpeta nativa de la KB GeneXus es distinta de la carpeta paralela de la KB
- en esta trilha, la carpeta nativa de la KB debe tratarse como área prohibida para escritura por agentes; la lectura solo se permite cuando el flujo operativo explícito realmente lo exija
- la carpeta paralela de la KB es la carpeta de trabajo que concentra `XPZ` exportados por la IDE, XMLs materializados por el flujo oficial, índice derivado para triaje y artefactos preparados para importación posterior

- `ObjetosDaKbEmXml`: snapshot oficial de la KB; solo lectura para agentes
- `KbIntelligence`: carpeta del índice SQLite derivado y regenerable, usado para triaje técnico y funcional corto sin sustituir el snapshot oficial
- `KbIntelligence` solo debe usarse para triaje amplio cuando `last_index_build_run_at` en SQLite sea igual o posterior a `last_xpz_materialization_run_at` en `kb-source-metadata.md`; todo sync XPZ/XML oficial debe regenerar/validar el indice inmediatamente despues de la materializacion, y un indice ausente o desfasado es una excepcion operativa que debe bloquear investigacion amplia/generacion y ofrecer actualizacion al usuario
- cuando `AGENTS.md` o `README.md` locales de la carpeta paralela declaren timestamps, estado operativo u observaciones de frescura, esos campos deben mantenerse coherentes con `kb-source-metadata.md`, con `-Query index-metadata` del wrapper local y con el gate efectivo; el drift documental local tambien es una pendiente de setup
- `XpzExportadosPelaIDE`: carpeta donde el usuario graba tanto el `XPZ` completo de la Carga Inicial como los `XPZ` incrementales del día a día
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabajo para XMLs generados, ajustados o preservados para importación manual en la IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de salida para `import_file.xml` y demás paquetes generados localmente
- `Temp`: destino preferente de artefactos efímeros de ejecución, como directorios temporales de wrappers, logs auxiliares y salidas intermedias que no sean fuente normativa de la base
- `ArquivoMorto`: subcarpeta opcional de `ObjetosGeradosParaImportacaoNaKbNoGenexus` para preservar XML contaminados que no deben importarse pero necesitan trazabilidad; no borrar sin autorización explícita del usuario
- en `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente activa debe usar su propia subcarpeta con el formato `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifica la frente por la combinación de nombre corto, GUID generado al abrir la frente y fecha de creación de la frente
- en `PacotesGeradosParaImportacaoNaKbNoGenexus`, los paquetes deben permanecer en la raíz, sin subcarpetas, usando el formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa solo la ronda corta del paquete en esa frente; no representa versión semántica
- antes de grabar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar si ya existe un paquete con el mismo prefijo de frente `NomeCurto_GUID_YYYYMMDD` y el mismo `nn`
- si ya existe un paquete con el mismo prefijo de frente y el mismo `nn`, abortar la grabación; no sobrescribir silenciosamente la ronda
- en caso de colisión, devolver un error explícito con sugerencia del próximo `nn` libre para esa frente, sin autoincrementar ni grabar automáticamente con el valor sugerido
- la promoción hacia `ObjetosDaKbEmXml` ocurre solo por el flujo oficial del script `.ps1` alimentado por el `XPZ` exportado por la IDE
- `ObjetosDaKbEmXml` no debe actualizarse por edición manual; se actualiza por el flujo del `.ps1` a partir de los `XPZ` disponibilizados en la carpeta paralela de la KB
- si el objeto todavía no volvió de la KB por export oficial, el trabajo debe ocurrir en `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- una edición detectada o pretendida en `ObjetosDaKbEmXml` para un delta aún no reexportado oficialmente por la KB debe tratarse como error explícito de proceso, no como detalle operativo
- `AGENTS.md`, `README.md` y documentación equivalente de la KB funcionan como capa obligatoria de especialización local; sus reglas valen para ese repositorio y no deben promoverse automáticamente a la metodología compartida de XPZ
- una frente técnicamente validada no implica publicación Git; la publicación solo ocurre con autorización explícita del usuario, y hasta entonces el estado preferido es `aguardando_decisao_de_fechamento`

### Carga inicial

- cuando el usuario no informe nombres alternativos, la KB debe asumir estas subcarpetas estándar:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` es la carpeta de entrada donde el usuario de GeneXus graba los `.xpz` que serán procesados
- después de procesado con éxito por el flujo oficial, el `.xpz` puede renombrarse a `processado_<nome-original>.xpz`
- `scripts` concentra los wrappers `.ps1` que tratan `XPZ` e índice derivado
- cuando la carpeta paralela de la KB se inicialice desde cero para operar con el flujo oficial de materialización XPZ/XML, el bootstrap técnico mínimo debe incluir los wrappers locales principales en `scripts`
- no declarar `setup inicial concluido` mientras esa capa mínima de wrappers locales todavía no exista; en ese caso, el estado correcto es `estructura parcial` o `bootstrap incompleto`
- `Test-*KbSourceSanity.ps1` se recomienda cuando la carpeta también adopte flujo local de generación y empaquetado; su ausencia aislada no impide por sí sola clasificar la capa mínima de wrappers del flujo oficial de materialización o de `KbIntelligence`
- `KbIntelligence` guarda el SQLite derivado y los informes de validación del índice, cuando ese flujo esté adoptado en la KB
- la Carga Inicial puede usar un `XPZ` completo nuevo en cualquier momento para reactualizar `ObjetosDaKbEmXml`
- `XPZ` full define el insumo exportado; la materialización normal de ese insumo no implica `-FullSnapshot`, que debe quedar restringido a la verificación full explícita o a exigencia documental nominal
- la misma estructura también vale para `XPZ` parciales con objetos alterados desde la última actualización
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` guarda objetos temporales destinados a la importación manual en la IDE
- cada frente activa en `ObjetosGeradosParaImportacaoNaKbNoGenexus` debe tener su propia subcarpeta `NomeCurto_GUID_YYYYMMDD`
- esa subcarpeta de la frente es la unidad activa de la frente de trabajo
- al retomar una frente existente, reutilizar la misma subcarpeta de la frente en vez de crear otra
- `PacotesGeradosParaImportacaoNaKbNoGenexus` guarda el paquete `.xml` y, cuando sea necesario, también `.xpz`, que será importado por la IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` debe permanecer plano, sin subcarpetas por frente; el vínculo con la frente queda solo en el prefijo `NomeCurto_GUID_YYYYMMDD` sumado a `nn`
- por defecto, `ObjetosGeradosParaImportacaoNaKbNoGenexus` y `PacotesGeradosParaImportacaoNaKbNoGenexus` no necesitan versionarse en Git; si hay duda sobre rastrear o ignorar su contenido, eso debe tratarse como decisión de política del repositorio
- `AGENTS.md` y `README.md` pueden existir en la raíz o en subcarpetas cuando haya anotación operativa pertinente
- si alguna de esas subcarpetas todavía no existe, el orden recomendado de creación es:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- cuando la carpeta paralela ya esté versionada en Git y el setup inicial parta de estructura vacía, `.gitignore` en la raíz y `.gitkeep` en las subcarpetas vacías forman parte del bootstrap esperado
- cuando la carpeta paralela todavía no esté versionada en Git, el agente puede ofrecer inicializar versionado Git local como paso opcional; no debe ejecutar `git init` sin aprobación explícita del usuario
- si el usuario acepta versionado Git local y Git no está funcional en el entorno, el agente puede ofrecer instalarlo u orientar la instalación antes del bootstrap Git
- cambiar `.gitignore`, la política de versionado o el alcance de archivos rastreados para viabilizar `git add`/`commit` es una decisión de política del repositorio; el agente puede diagnosticar y proponer opciones, pero no debe cambiar esa política automáticamente solo para cerrar la frente
- cuando `XpzExportadosPelaIDE` todavía no exista, el agente debe preguntar dónde el usuario pretende guardar los `.xpz` antes de continuar con el procesamiento
- en el setup inicial de la carpeta paralela de la KB, si el camino de la carpeta nativa de la KB no viene informado, el agente debe pedir ese camino al usuario antes de concluir el setup
- en el setup inicial de la carpeta paralela de la KB, `kb-source-metadata.md` debe nacer en formato compatible con el motor compartido y preservar el campo nominal `last_xpz_materialization_run_at`
- cuando `ObjetosDaKbEmXml` todavía no exista, el agente debe tratar esto como KB aún no materializada y detenerse antes de asumir cualquier snapshot
- al concluir el setup inicial de la carpeta paralela de la KB, el agente debe dejar explícito que la estructura está lista, pero `ObjetosDaKbEmXml` todavía no fue materializada
- al concluir el setup inicial, el agente debe ofrecer `A)` exportación del `.xpz` full por la IDE hacia `XpzExportadosPelaIDE` o `B)` generación del `.xpz` full a partir de la carpeta nativa de la KB por la trilha `MSBuild`, seguida de materialización de los XMLs
- en el cierre del setup inicial, `A)` debe presentarse como camino preferencial y normalmente más rápido; `B)` debe presentarse como camino posible, pero más lento por depender de la trilha via `MSBuild`

### Automación operativa

- el script `scripts/Sync-GeneXusXpzToXml.ps1` forma parte de la infraestructura operativa de esta base y no debe ser removido del repositorio público
- ese script puede ser usado por proyectos de producción que mantengan acervos versionados de XML extraídos de `XPZ`
- la carpeta `scripts/` existe como apoyo operativo, analítico y editorial compartible, pero no es fuente normativa de la documentación consolidada de la raíz
- los scripts públicos de esta raíz deben operar por parámetros explícitos de entrada y salida, sin depender de rutas absolutas privadas
- los `.example.ps1` publicados en las skills funcionan como ejemplos metodológicos importantes para bootstrap técnico y reconstrucción asistida de wrappers locales finales
- esos `.example.ps1` no sustituyen el wrapper local real de la carpeta paralela de la KB y no deben convertirse en fallback automático de ejecución en el flujo normal
- cuando la sesión ya publique la ruta de una skill o de sus ejemplos, esa ruta publicada prevalece sobre cualquier heurística local de instalación
- la memoria operativa de setup y compatibilidad debe permanecer primero en la propia carpeta paralela de la KB, en `AGENTS.md`, `README.md` y archivos operativos locales; la memoria externa del agente fuera del repositorio no debe tratarse como requisito ni escribirse sin autorización explícita del usuario
- si el motor necesita evolucionar, el cambio debe preservar compatibilidad con ese uso o venir acompañado de actualización explícita de los wrappers consumidores

---

## English

This repository contains consolidated documentation about structural analysis of GeneXus objects based on XML extracted from `XPZ`, with emphasis on skills for agents dedicated to the `XPZ`/XML ecosystem of GeneXus, especially `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-msbuild-import-export`, and `xpz-index-triage`.

- reading and interpreting XML structure
- structural object families
- risk by object type
- conservative cloning
- support for assisted `XPZ` generation
- documented envelope and import validation in controlled cases

### What you will find here

The files below form the main shared base in this root, consolidated to make reading, maintenance, and controlled use easier.

In addition to that main base, the root may also contain complementary operational documentation for active workstreams when it still needs to remain visible outside `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` through `01h-moldes-sanitizados-metadados-e-artefatos.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: operational base for the headless MSBuild trail, used by the `xpz-msbuild-import-export` skill

The files `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md`, and `12-diffs-estruturais-por-tipo.md` are backward-compatibility stubs: each one redirects to its equivalent in the `01` series (`01b`, `01c`, `01d`). They contain no content of their own and must not be used as a direct source.

### KB Intelligence operational documentation

KB Intelligence series files present in the root while the workstream is active. When closed, they migrate to `historico/kb-intelligence/`.

- `11-plano-kb-intelligence-incremental.md`
- `14-kb-intelligence-fase-3-contrato.md`
- `16-kb-intelligence-fase-5-contrato.md`
- `17-kb-intelligence-fase-6-contrato.md`
- `18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md`
- `19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md`
- `21-kb-intelligence-fase-6-checklist-operacional-agente.md`
- `22-kb-intelligence-fase-6-contrato-functional-trace-basic.md`
- `23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md`
- `26-kb-intelligence-fase-6-verificacao-pos-filtro.md`
- `27-kb-intelligence-fase-6-primeira-resposta-funcional.md`
- `29-kb-intelligence-estudo-update-incremental.md`

### Skills for agents

- `xpz-reader`: support for reading and structural interpretation of `XPZ` and related XMLs
- `xpz-builder`: support for controlled materialization of `XPZ` artifacts and envelopes
- `xpz-sync`: orchestration of synchronization and verification of the XML archive from explicit parameters and scripts in `scripts/`
- `xpz-daemon`: installation and management of a persistent monitor that watches XPZ folders and automatically triggers synchronization when new files are detected
- `xpz-doc-builder`: generation and recomposition of Markdown documentation from the XML archive and sanitized templates
- `xpz-kb-parallel-setup`: preparation and validation of the initial KB parallel-folder structure
- `xpz-msbuild-import-export`: experimental skill for `XPZ` import and export via `MSBuild`, with headless execution, explicit parameters, traceability, and safety gates
- `xpz-index-triage`: initial triage through a derived index to guide the minimum reading of the KB official XMLs

### Recommended reading for humans

If you want to understand the repository quickly:

1. start with `00-indice-da-base-genexus-xpz-xml.md`
2. continue with `01-base-empirica-geral.md` and then open the most relevant child in the `01` series (`01a` through `01h`)
3. then read `02-regras-operacionais-e-runtime.md`
4. next read `03-risco-e-decisao-por-tipo.md`
5. for practical cases, use `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md`, and `05b-procedure-relatorio-familias-e-templates.md`
6. if you want limits and next investigation fronts, read `07-open-points-e-checklist.md`
7. for another GPT agent consuming the base, finish with `08-guia-para-agente-gpt.md`
8. to verify inventory traceability, consult `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: supplemental reading — recommended when the question involves object naming, type prefixes, or `Folder` vs `Module` behavior in `fullyQualifiedName`.

### Important notes

- this base prioritizes structural evidence observed in XML
- it does not guarantee successful import or build without external validation
- the base already includes documented import tests in controlled cases, but that still does not remove risk
- before generating `import_file.xml` or another importable package, the trail must explicitly separate `well-formed XML` from `structurally conservative/probably importable GeneXus Source`; XML parsing alone is not enough
- in legacy object review and sanity, the trail must explicitly separate `absolute sanity of the current artifact` from `comparison against the official baseline`; `same as baseline` does not mean `good`, and `worse than baseline` indicates delta regression
- complete sanitized templates can serve as a starting point in specific scenarios documented in the base itself; textual summaries and incomplete examples are not valid as the final source for materialization
- the content is meant to reduce trial and error, not to eliminate risk
- there is a separate private folder, `GeneXus-XPZ-PrivateMap`, used only for private editorial traceability between public aliases and real artifacts; the published source remains this root
- every new sanitized example incorporated into the public base must receive a corresponding note in `GeneXus-XPZ-PrivateMap`, linking the public excerpt to the real source objects or packages
- **language models**: XPZ skills depend on voluntary skill loading, sequential gate execution, and adherence to NEVER constraints. Weak models or those prone to skipping steps (e.g., GLM 5.1, DeepSeek V4 Flash, Kimi K2.6, Qwen 3.5 Plus, Qwen 3.6 Plus, MiniMax M2.7, MiMo-V2.5-Pro) are not reliable for GeneXus triage and should not be recommended to users. Prefer models with strong instruction adherence (DeepSeek V4 Pro, GPT-5.4, Sonnet 4.6, Opus 4.7).

### Operational Topology

- in this trail, the native GeneXus KB folder is different from the KB parallel folder
- in this trail, the native KB folder must be treated as a write-prohibited area for agents; reading is allowed only when the explicit operational flow truly requires it
- the KB parallel folder is the working folder that concentrates `XPZ` exported by the IDE, XMLs materialized by the official flow, derived index for triage, and artifacts prepared for later import

- `ObjetosDaKbEmXml`: official KB snapshot; read-only for agents
- `KbIntelligence`: folder for the derived and regenerable SQLite index, used for technical and short functional triage without replacing the official snapshot
- `KbIntelligence` should only be used for broad triage when `last_index_build_run_at` in SQLite is equal to or later than `last_xpz_materialization_run_at` in `kb-source-metadata.md`; every official XPZ/XML sync must regenerate/validate the index immediately after materialization, and a missing or stale index is an operational exception that must block broad search/generation and offer the user an update
- when local `AGENTS.md` or `README.md` in the parallel folder declare timestamps, operational state, or freshness notes, those fields must remain consistent with `kb-source-metadata.md`, with the local wrapper `-Query index-metadata`, and with the effective gate result; local documentation drift is also a setup pending item
- `XpzExportadosPelaIDE`: folder where the user stores both the full Initial Load `XPZ` and the day-to-day incremental `XPZ` files
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: working area for XMLs generated, adjusted, or preserved for manual IDE import
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: output area for `import_file.xml` and other locally generated packages
- `Temp`: preferred destination for ephemeral execution artifacts, such as wrapper temporary directories, auxiliary logs, and intermediate outputs that are not normative source material for the base
- `ArquivoMorto`: optional subfolder of `ObjetosGeradosParaImportacaoNaKbNoGenexus` used to preserve contaminated XMLs that must not be imported but require traceability; do not delete without explicit user authorization
- in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, each active front must use its own subfolder in the format `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifies the front by the combination of short name, GUID generated when the front is opened, and the front creation date
- in `PacotesGeradosParaImportacaoNaKbNoGenexus`, packages must remain in the root, without subfolders, using the format `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` represents only the short package round for that front; it is not semantic versioning
- before writing `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, check whether a package with the same front prefix `NomeCurto_GUID_YYYYMMDD` and the same `nn` already exists
- if a package with the same front prefix and the same `nn` already exists, abort the write; do not silently overwrite that round
- in case of collision, return an explicit error with the next free `nn` suggested for that front, without auto-incrementing or writing automatically with the suggested value
- promotion into `ObjetosDaKbEmXml` happens only through the official `.ps1` script flow fed by the XPZ exported from the IDE
- `ObjetosDaKbEmXml` must not be updated by manual editing; it is updated by the `.ps1` flow from the XPZ files made available in the KB parallel folder
- if the object has not yet returned from the KB by official export, the work must happen in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- detected or intended editing in `ObjetosDaKbEmXml` for a delta that has not yet been officially re-exported by the KB must be treated as an explicit process error, not as an operational detail
- `AGENTS.md`, `README.md`, and equivalent KB documentation act as the mandatory local specialization layer; their rules apply to that repository and must not be automatically promoted to the shared XPZ methodology
- a technically validated front does not imply Git publication; publication only occurs with explicit user authorization, and until then the preferred state is `aguardando_decisao_de_fechamento`

### Initial load

- when the user does not provide alternative names, the KB must assume these standard subfolders:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` is the input folder where the GeneXus user stores the `.xpz` files that will be processed
- after being successfully processed by the official flow, the `.xpz` can be renamed to `processado_<nome-original>.xpz`
- `scripts` concentrates the `.ps1` wrappers that handle `XPZ` and the derived index
- when the KB parallel folder is initialized from zero to operate with the official XPZ/XML materialization flow, the minimum technical bootstrap must include the main local wrappers in `scripts`
- do not declare `initial setup complete` while that minimum local wrapper layer does not exist yet; in that case, the correct status is `partial structure` or `incomplete bootstrap`
- `Test-*KbSourceSanity.ps1` is recommended when the folder also adopts a local generation and packaging flow; its isolated absence does not by itself prevent classifying the minimum wrapper layer for the official materialization flow or for `KbIntelligence`
- `KbIntelligence` stores the derived SQLite index and index validation reports when that flow is adopted in the KB
- the Initial Load can use a new full `XPZ` at any time to refresh `ObjetosDaKbEmXml`
- full `XPZ` defines the exported input; normal materialization of that input does not imply `-FullSnapshot`, which must stay restricted to explicit full verification or nominal documentary requirement
- the same structure also applies to partial `XPZ` files with objects changed since the last update
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` stores temporary objects intended for manual IDE import
- each active front in `ObjetosGeradosParaImportacaoNaKbNoGenexus` must have its own `NomeCurto_GUID_YYYYMMDD` subfolder
- that front subfolder is the active unit of the working front
- when resuming an existing front, reuse the same front subfolder instead of creating another one
- `PacotesGeradosParaImportacaoNaKbNoGenexus` stores the `.xml` package and, when needed, also `.xpz`, which will be imported by the IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` must remain flat, without subfolders by front; the link to the front exists only in the `NomeCurto_GUID_YYYYMMDD` prefix plus `nn`
- by default, `ObjetosGeradosParaImportacaoNaKbNoGenexus` and `PacotesGeradosParaImportacaoNaKbNoGenexus` do not need to be versioned in Git; if there is doubt about tracking or ignoring their contents, treat that as repository policy
- `AGENTS.md` and `README.md` may exist in the root or in subfolders when there is relevant operational annotation
- if any of those subfolders does not exist yet, the recommended creation order is:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- when the parallel folder is already versioned in Git and the initial setup starts from an empty structure, `.gitignore` at the root and `.gitkeep` in empty subfolders are part of the expected bootstrap
- when the parallel folder is not yet versioned in Git, the agent may offer to initialize local Git versioning as an optional step; it must not run `git init` without explicit user approval
- if the user accepts local Git versioning and Git is not functional in the environment, the agent may offer to install it or guide the installation before the Git bootstrap
- changing `.gitignore`, versioning policy, or the scope of tracked files just to make `git add`/`commit` work is a repository policy decision; the agent may diagnose and propose options, but must not change that policy automatically just to close the front
- when `XpzExportadosPelaIDE` does not exist yet, the agent must ask where the user intends to save the `.xpz` files before continuing with processing
- in the initial setup of the KB parallel folder, if the native KB folder path is not provided, the agent must ask the user for that path before concluding setup
- in the initial setup of the KB parallel folder, `kb-source-metadata.md` must start in a format compatible with the shared engine and preserve the nominal `last_xpz_materialization_run_at` field
- when `ObjetosDaKbEmXml` does not exist yet, the agent must treat this as a KB not yet materialized and stop before assuming any snapshot
- when concluding the initial setup of the KB parallel folder, the agent must make it explicit that the structure is ready, but `ObjetosDaKbEmXml` has not yet been materialized
- when concluding the initial setup, the agent must offer `A)` full `.xpz` export by the IDE into `XpzExportadosPelaIDE` or `B)` full `.xpz` generation from the native KB folder through the `MSBuild` track, followed by XML materialization
- in the initial setup closeout, `A)` must be presented as the preferred and usually faster path; `B)` must be presented as a possible but slower path because it depends on the `MSBuild` track

### Operational automation

- the script `scripts/Sync-GeneXusXpzToXml.ps1` is part of the operational infrastructure of this base and must not be removed from the public repository
- that script can be used by production projects that keep versioned XML archives extracted from `XPZ`
- the `scripts/` folder exists as shared operational, analytical, and editorial support, but it is not the normative source of the consolidated root documentation
- the public scripts in this root must operate through explicit input and output parameters, without depending on private absolute paths
- the `.example.ps1` files published inside the skills act as important methodological examples for technical bootstrap and assisted reconstruction of final local wrappers
- those `.example.ps1` files do not replace the real local wrapper of the KB parallel folder and must not become an automatic execution fallback in the normal flow
- when the session already publishes the path of a skill or its examples, that published path takes precedence over local installation heuristics
- setup and compatibility operational memory should remain first inside the KB parallel folder itself, in `AGENTS.md`, `README.md`, and local operational files; external agent memory outside the repository must not be treated as a requirement or written without explicit user authorization
- if the engine needs to evolve, the change must preserve compatibility with that use or be accompanied by explicit updates to the consuming wrappers
