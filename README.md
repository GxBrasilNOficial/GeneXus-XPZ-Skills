# Knowledge GeneXus

## Português (BR)

Este repositório existe para sustentar e operacionalizar skills para agentes dedicadas ao ecossistema `XPZ`/XML de GeneXus, em especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon` e `xpz-kb-parallel-setup`.

A documentação consolidada e os scripts desta raiz funcionam como base metodológica e operacional dessas skills, com foco em:

- leitura e interpretação de estrutura XML
- famílias estruturais de objetos
- risco por tipo de objeto
- clonagem conservadora
- apoio à geração assistida de `XPZ`
- validação documental de envelope e importação em casos controlados

### O que você vai encontrar aqui

Os documentos principais foram consolidados em 10 arquivos Markdown para facilitar leitura, manutenção e uso controlado.

- `00-readme-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-historico-e-inventario-publico.md`

### Skills para agentes

- `xpz-reader`: apoio à leitura e interpretação estrutural de `XPZ` e XMLs relacionados
- `xpz-builder`: apoio à materialização controlada de artefatos e envelopes `XPZ`
- `xpz-sync`: orquestração de sincronização e conferência do acervo XML a partir de parâmetros explícitos e scripts em `scripts/`
- `xpz-daemon`: instalação e gerenciamento de um monitor persistente que observa pastas de XPZ e dispara sincronização automaticamente ao detectar novos arquivos
- `xpz-doc-builder`: geração e recomposição de documentação Markdown a partir do acervo XML e de moldes sanitizados
- `xpz-kb-parallel-setup`: preparação e validação da estrutura inicial da pasta paralela da KB

### Leitura recomendada para humanos

Se você quer entender a base rapidamente:

1. comece por `00-readme-genexus-xpz-xml.md`
2. siga para `01-base-empirica-geral.md`
3. depois leia `02-regras-operacionais-e-runtime.md`
4. em seguida leia `03-risco-e-decisao-por-tipo.md`
5. para casos práticos, use `04-webpanel-familias-e-templates.md` e `05-transaction-familias-e-templates.md`
6. se quiser entender limites e próximas frentes, leia `07-open-points-e-checklist.md`
7. para consumo por outro agente GPT, termine em `08-guia-para-agente-gpt.md`

### Avisos importantes

- esta base prioriza evidência estrutural observada em XML
- ela não promete sucesso de importação ou build sem validação externa
- a base já incorpora testes documentados de importação em casos controlados, mas isso não elimina risco
- moldes sanitizados completos podem servir como ponto de partida em cenários específicos documentados na própria base; resumos textuais e exemplos incompletos não servem como fonte final de materialização
- o conteúdo foi organizado para reduzir tentativa e erro, não para eliminar risco
- existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada apenas para rastreabilidade editorial privada entre aliases públicos e artefatos reais; a fonte publicada continua sendo esta raiz
- todo novo exemplo sanitizado incorporado na base pública deve receber anotação correspondente no `GeneXus-XPZ-PrivateMap`, ligando o trecho público aos objetos ou pacotes reais de origem

### Topologia operacional

- nesta trilha, a pasta nativa da KB GeneXus e diferente da pasta paralela da KB
- a pasta paralela da KB e a pasta de trabalho que concentra `XPZ` exportados pela IDE, XMLs materializados pelo fluxo oficial e artefatos preparados para importação posterior

- `ObjetosDaKbEmXml`: snapshot oficial da KB; somente leitura para agentes
- `XpzExportadosPelaIDE`: pasta onde o usuário grava tanto o `XPZ` completo da Carga Inicial quanto os `XPZ` incrementais do dia a dia
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabalho para XMLs gerados, ajustados ou preservados para importação manual na IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de saída para `import_file.xml` e demais pacotes gerados localmente
- em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente ativa deve usar sua propria subpasta no formato `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifica a frente pela combinacao de nome curto, GUID gerado na abertura da frente e data de criacao da frente; `YYYYMMDD` representa a data de criacao da frente, nao a data do pacote
- em `PacotesGeradosParaImportacaoNaKbNoGenexus`, os pacotes devem permanecer na raiz, sem subpastas, usando o formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa apenas a rodada curta de pacote daquela frente; nao representa versao semantica
- a promoção para `ObjetosDaKbEmXml` ocorre apenas pelo fluxo oficial do script `.ps1` alimentado por `XPZ` exportado pela IDE
- `ObjetosDaKbEmXml` nao deve ser atualizado por edição manual; ele e atualizado pelo fluxo do `.ps1` a partir dos `XPZ` disponibilizados na pasta paralela da KB
- se o objeto ainda nao voltou da KB por export oficial, o trabalho deve acontecer em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- edição detectada ou pretendida em `ObjetosDaKbEmXml` para delta ainda não reexportado oficialmente pela KB deve ser tratada como erro explícito de processo, não como detalhe operacional
- `AGENTS.md`, `README.md` e documentação equivalente da KB funcionam como camada obrigatória de especialização local; suas regras valem para aquele repositório e não devem ser promovidas automaticamente à metodologia compartilhada de XPZ

### Carga inicial

- quando o usuário não informar nomes alternativos, a KB deve assumir estas subpastas padrão:
  - `ObjetosDaKbEmXml`
  - `XpzExportadosPelaIDE`
  - `scripts`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` é a pasta de entrada onde o usuário do GeneXus grava os `.xpz` que serão processados
- depois de processado com sucesso pelo fluxo oficial, o `.xpz` pode ser renomeado para `processado_<nome-original>.xpz`
- `scripts` concentra os wrappers `.ps1` que tratam os `XPZ`
- a Carga Inicial pode usar um `XPZ` completo novo a qualquer momento para reatualizar `ObjetosDaKbEmXml`
- a mesma estrutura também vale para `XPZ` parciais com objetos alterados desde a última atualização
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` guarda objetos temporários destinados à importação manual na IDE
- cada frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus` deve ter sua propria subpasta `NomeCurto_GUID_YYYYMMDD`
- essa subpasta da frente e a unidade ativa da frente de trabalho
- ao retomar uma frente existente, reutilizar a mesma subpasta da frente em vez de criar outra
- `PacotesGeradosParaImportacaoNaKbNoGenexus` guarda o pacote `.xml` e, quando necessário, também `.xpz`, que será importado pela IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` deve permanecer plano, sem subpastas por frente; o vinculo com a frente fica apenas no prefixo `NomeCurto_GUID_YYYYMMDD` somado ao `nn`
- `AGENTS.md` e `README.md` podem existir na raiz ou em subpastas quando houver anotação operacional pertinente
- se alguma dessas subpastas ainda não existir, a ordem recomendada de criação é:
  1. `scripts`
  2. `XpzExportadosPelaIDE`
  3. `ObjetosDaKbEmXml`
  4. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  5. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando `XpzExportadosPelaIDE` ainda não existir, o agente deve perguntar onde o usuário pretende salvar os `.xpz` antes de prosseguir com o processamento
- quando `ObjetosDaKbEmXml` ainda não existir, o agente deve tratar isso como KB ainda não materializada e parar antes de assumir qualquer snapshot

### Automação operacional

- o script `scripts/Sync-GeneXusXpzToXml.ps1` faz parte da infraestrutura operacional desta base e nao deve ser removido do repositório público
- esse script pode ser usado por projetos de produção que mantenham acervos versionados de XMLs extraidos de `XPZ`
- a pasta `scripts/` existe como apoio operacional, analitico e editorial compartilhavel, mas nao e fonte normativa da documentacao consolidada da raiz
- os scripts públicos desta raiz devem operar por parâmetros explícitos de entrada e saída, sem depender de caminhos absolutos privados
- se o motor precisar evoluir, a mudança deve preservar compatibilidade com esse uso ou ser acompanhada de atualização explícita dos wrappers consumidores

---

## Español

Este repositorio reúne documentación consolidada sobre análisis estructural de objetos GeneXus a partir de XMLs extraídos de `XPZ`, con foco en skills para agentes dedicadas al ecosistema `XPZ`/XML de GeneXus, en especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon` y `xpz-kb-parallel-setup`.

- lectura e interpretación de estructura XML
- familias estructurales de objetos
- riesgo por tipo de objeto
- clonación conservadora
- apoyo a la generación asistida de `XPZ`
- validación documental de contenedor e importación en casos controlados

### Qué encontrarás aquí

Los documentos principales fueron consolidados en 10 archivos Markdown para facilitar lectura, mantenimiento y uso controlado.

- `00-readme-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-historico-e-inventario-publico.md`

### Skills para agentes

- `xpz-reader`: apoyo a la lectura e interpretación estructural de `XPZ` y XMLs relacionados
- `xpz-builder`: apoyo a la materialización controlada de artefactos y envelopes `XPZ`
- `xpz-sync`: orquestación de sincronización y verificación del acervo XML a partir de parámetros explícitos y scripts en `scripts/`
- `xpz-daemon`: instalación y gestión de un monitor persistente que observa carpetas de XPZ y dispara sincronización automáticamente al detectar nuevos archivos
- `xpz-doc-builder`: generación y recomposición de documentación Markdown a partir del acervo XML y de moldes sanitizados
- `xpz-kb-parallel-setup`: preparación y validación de la estructura inicial de la carpeta paralela de la KB

### Lectura recomendada para humanos

Si quieres entender la base rápidamente:

1. empieza por `00-readme-genexus-xpz-xml.md`
2. continúa con `01-base-empirica-geral.md`
3. luego lee `02-regras-operacionais-e-runtime.md`
4. después lee `03-risco-e-decisao-por-tipo.md`
5. para casos prácticos, usa `04-webpanel-familias-e-templates.md` y `05-transaction-familias-e-templates.md`
6. si quieres ver límites y siguientes frentes, lee `07-open-points-e-checklist.md`
7. para consumo por otro agente GPT, termina en `08-guia-para-agente-gpt.md`

### Avisos importantes

- esta base prioriza evidencia estructural observada en XML
- no promete éxito de importación o build sin validación externa
- la base ya incorpora pruebas documentadas de importación en casos controlados, pero eso no elimina el riesgo
- moldes sanitizados completos pueden servir como punto de partida en escenarios específicos documentados en la propia base; resúmenes textuales y ejemplos incompletos no sirven como fuente final de materialización
- el contenido fue organizado para reducir prueba y error, no para eliminar riesgo

### Topología operativa

- `ObjetosDaKbEmXml`: snapshot oficial de la KB; solo lectura para agentes
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabajo para XMLs generados, ajustados o preservados para importación manual en la IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de salida para `import_file.xml` y demás paquetes generados localmente
- en `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente activa debe usar su propia subcarpeta con el formato `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifica la frente por la combinación de nombre corto, GUID generado al abrir la frente y fecha de creación de la frente
- en `PacotesGeradosParaImportacaoNaKbNoGenexus`, los paquetes deben permanecer en la raíz, sin subcarpetas, usando el formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa solo la ronda corta del paquete en esa frente; no representa versión semántica
- la promoción hacia `ObjetosDaKbEmXml` ocurre solo por el flujo oficial del script `.ps1` alimentado por el `XPZ` exportado por la IDE
- si el objeto todavía no volvió de la KB por export oficial, el trabajo debe ocurrir en `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- una edición detectada o pretendida en `ObjetosDaKbEmXml` para un delta aún no reexportado oficialmente por la KB debe tratarse como error explícito de proceso, no como detalle operativo
- `AGENTS.md`, `README.md` y documentación equivalente de la KB funcionan como capa obligatoria de especialización local; sus reglas valen para ese repositorio y no deben promoverse automáticamente a la metodología compartida de XPZ

---

## English

This repository contains consolidated documentation about structural analysis of GeneXus objects based on XML extracted from `XPZ`, with emphasis on skills for agents dedicated to the `XPZ`/XML ecosystem of GeneXus, especially `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, and `xpz-kb-parallel-setup`.

- reading and interpreting XML structure
- structural object families
- risk by object type
- conservative cloning
- support for assisted `XPZ` generation
- documented envelope and import validation in controlled cases

### What you will find here

The main documentation has been consolidated into 10 Markdown files to make reading, maintenance, and controlled use easier.

- `00-readme-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `05-transaction-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-historico-e-inventario-publico.md`

### Skills for agents

- `xpz-reader`: support for reading and structural interpretation of `XPZ` and related XMLs
- `xpz-builder`: support for controlled materialization of `XPZ` artifacts and envelopes
- `xpz-sync`: orchestration of synchronization and verification of the XML archive from explicit parameters and scripts in `scripts/`
- `xpz-daemon`: installation and management of a persistent monitor that watches XPZ folders and automatically triggers synchronization when new files are detected
- `xpz-doc-builder`: generation and recomposition of Markdown documentation from the XML archive and sanitized templates
- `xpz-kb-parallel-setup`: preparation and validation of the initial KB parallel-folder structure

### Recommended reading for humans

If you want to understand the repository quickly:

1. start with `00-readme-genexus-xpz-xml.md`
2. continue with `01-base-empirica-geral.md`
3. then read `02-regras-operacionais-e-runtime.md`
4. next read `03-risco-e-decisao-por-tipo.md`
5. for practical cases, use `04-webpanel-familias-e-templates.md` and `05-transaction-familias-e-templates.md`
6. if you want limits and next investigation fronts, read `07-open-points-e-checklist.md`
7. for another GPT agent consuming the base, finish with `08-guia-para-agente-gpt.md`

### Important notes

- this base prioritizes structural evidence observed in XML
- it does not guarantee successful import or build without external validation
- the base already includes documented import tests in controlled cases, but that still does not remove risk
- complete sanitized templates can serve as a starting point in specific scenarios documented in the base itself; textual summaries and incomplete examples are not valid as the final source for materialization
- the content is meant to reduce trial and error, not to eliminate risk

### Operational Topology

- `ObjetosDaKbEmXml`: official KB snapshot; read-only for agents
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: working area for XMLs generated, adjusted, or preserved for manual IDE import
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: output area for `import_file.xml` and other locally generated packages
- in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, each active front must use its own subfolder in the format `NomeCurto_GUID_YYYYMMDD`
- `NomeCurto_GUID_YYYYMMDD` identifies the front by the combination of short name, GUID generated when the front is opened, and the front creation date
- in `PacotesGeradosParaImportacaoNaKbNoGenexus`, packages must remain in the root, without subfolders, using the format `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` represents only the short package round for that front; it is not semantic versioning
- promotion into `ObjetosDaKbEmXml` happens only through the official `.ps1` script flow fed by the XPZ exported from the IDE
- if the object has not yet returned from the KB by official export, the work must happen in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- detected or intended editing in `ObjetosDaKbEmXml` for a delta that has not yet been officially re-exported by the KB must be treated as an explicit process error, not as an operational detail
- `AGENTS.md`, `README.md`, and equivalent KB documentation act as the mandatory local specialization layer; their rules apply to that repository and must not be automatically promoted to the shared XPZ methodology
