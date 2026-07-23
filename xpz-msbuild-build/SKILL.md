---
name: xpz-msbuild-build
description: Skill para validação de build pós-import via MSBuild, com execução sem interface gráfica, parâmetros explícitos, classificação de resultado e gates de segurança contra reorg não autorizada
---

# xpz-msbuild-build

Skill para execução do pipeline de build do GeneXus por `MSBuild`, em execução sem
interface gráfica. Destina-se a validação pós-import: detectar erros de especificação,
geração e compilação sem abrir a IDE.

Esta skill não executa reorg por padrão, não substitui o fluxo oficial da trilha paralela
da KB e não trata sucesso operacional como evidência suficiente de sucesso funcional.

Depende da mesma infraestrutura de `xpz-msbuild-import-export`: `MSBuild.exe`,
instalação do GeneXus e `Genexus.Tasks.targets`.

## Decisões de design registradas

Tasks avaliadas e descartadas nesta skill estão documentadas em
`998-ideias-descartadas-e-porque.md`: `Compile` (isolado), `BuildOne`, `Run`,
`RebuildArtifacts`, `CustomBuild`, `SpecifyOneOnly`, `SpecifyOpenAPI`,
`GenerateChatbot`, `GenerateOpenAPI`, `IdeWebBuildAndDeploy`, `IdeWebCreateDB`,
`IdeWebImpactDB`.

---

## GUIDELINE

Orquestre o pipeline de build do GeneXus via `MSBuild` com parâmetros explícitos,
classificação rastreável de resultado e bloqueio de reorg por padrão. Use
`Invoke-GeneXusKbSpecifyGenerate.ps1` para verificação pós-import — menos invasiva que
`BuildAll` quando não há alterações estruturais pendentes no banco, mas **capaz de
disparar reorg real** quando o modelo as contém. Use `Invoke-GeneXusKbBuildAll.ps1`
para BuildAll incremental (equivalente à opção `Build All` do menu Build da IDE
GeneXus — compila apenas objetos alterados desde o último build, fluxo costumeiro
pós-edição/pós-import). `-ForceRebuild=true` é uma operação distinta: equivale a
`Rebuild All` da IDE — regenera **TODOS** os objetos da KB, podendo durar horas em KB
grande; só pode ser habilitado via `-AllowWideRebuild` com confirmação explícita do
usuário por frase exata. Nunca execute reorg sem autorização explícita do usuário.
Quando houver evidência de alteração estrutural de atributo no import recente, exigir
confirmação explícita do usuário antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`.
`BuildAll` ou `SpecifyGenerate` sem **monitoramento legível** não é fluxo válido. Há dois
fluxos de monitoramento legítimos:

- **(padrão) janela visível** — use `-StartWatcher` ao chamar `Invoke-GeneXusKbBuildAll.ps1`
  ou `Invoke-GeneXusKbSpecifyGenerate.ps1`; o wrapper garante o lançamento automático de
  `Watch-GeneXusMsBuildLog.ps1` em janela visível e registra evidência auditável no JSON
  (`watcherContext.watcherLaunched`).
- **(opt-in, build longo) modo desacoplado** — lance via `Start-GeneXusKbBuildDetached.ps1`,
  que roda o build sob uma Tarefa Agendada one-shot fora da sessão do agente (sobrevive a
  fechar a janela ou o app) e sinaliza a conclusão por **arquivo-sentinela**; o monitoramento
  legível passa a ser o `msbuild.stdout.log` (progresso) + a sentinela (conclusão), sem janela.

O modo desacoplado **não é o default**: o agente o **propõe** quando o build for esperado
longo ou for rodar em segundo plano, explicando o trade-off (perde a janela de progresso ao
vivo, ganha robustez a fechamento acidental), e só o usa por **decisão consciente do usuário**.
A **ausência de qualquer monitoramento** (nem janela, nem sentinela) permanece inválida; a
única exceção é justificativa operacional explícita e documentada (ex.: ambiente sem `pwsh`
no PATH, CI headless sem terminal) — nesse caso declarar explicitamente ao usuário e registrar
`watcherContext.watcherLaunched: false` como evidência de ausência. Seguir a seção
**ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL**.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Se a skill estiver publicada por symlink, junction ou outro reparse point, resolva
  primeiro a pasta real da skill e só então interprete referências relativas.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- executar verificação leve pós-import (specify + generate, sem compile)
- executar build completo pós-import (specify + generate + compile)
- detectar se há reorg pendente após import, sem executá-la
- inspecionar o que a reorg alteraria no banco sem executar (`ImpactDatabaseOnly`)
- executar reorg a partir de script de impacto já inspecionado (`ReorganizeOnly`)
- configurar o modo de build antes de `BuildAll` via `SetConfiguration` (valores: `Release`, `Debug`, `Performance Test`)
- classificar resultado de build em categorias operacionais explícitas
- apoiar decisão do usuário sobre o próximo passo após import
- resolver sub-estado `importação real efetiva provada, geração de runtime pendente` declarado por `xpz-msbuild-import-export` — quando import está provado mas artefatos de runtime ainda refletem versão anterior, executar build é o passo que atualiza os artefatos gerados no **environment usado no build**; `specify e generate concluídos` ou `compilou limpo` confirmam sucesso operacional **nesse** environment — em KB multi-environment **não** equivalem sozinhos a “a aplicação em IIS/self-host refletiu o import” sem `-EnvironmentName`/`deployment_environment_name` alinhados ao deploy; após build de validação deploy, passar `-PostImportDeployValidation` para gate de publicação em `web\bin` (max de DLL de objeto excluindo runtime GeneXus/System/Microsoft, ou `*.config` — exit **49** se stale; para `java-tomcat` o gate roda o **co-gate Java** por conjunto de artefatos no `WEB-INF\classes` **externo** do Tomcat — ver seção «Paridade Java/Tomcat» abaixo); em Core, `GxNetCoreStartup.dll` velho em incremental gera warning, não gate; `Test-GeneXusRuntimeFreshness.ps1` verifica `CSharpModel\web` no motor .NET (compartilhado) — complementar, não substituto; em KB `java-tomcat`, passar `-DeploymentHostingKind java-tomcat` para o skip do Eixo C e não usar `ObjStatus` isolado como prova de pendência; `Test-GeneXusDeployBinFreshness.ps1` diagnostica a publicação do environment de deploy (.NET: `web\bin`; para `java-tomcat` roteia ao co-gate Java no `WEB-INF\classes` externo) — aceita `-BuildResultJsonPath` para tomar a linha de corte de `timing.msbuildStart` do build, dispensando `-BuildStartedAt` manual
- quando o objetivo declarado inclui validar endpoint `API`, manter build/deploy e prova funcional separados: build/deploy limpos deixam o subestado existente `operação concluída, pendente de confirmação funcional` até que um teste HTTP registre método, rota, status, payload resumido e ambiente servido; se `[SecurityLevel]`/GAM estiver em escopo, o smoke 401/403/200 de `api-gam-runtime.md` continua sendo a prova de enforcement

Do NOT use esta skill para:
- executar reorg sem autorização explícita do usuário
- substituir o fluxo oficial da trilha paralela da KB
- cenários que dependam de `GeneXus Server` como requisito operacional
- KB de produção ou homologação compartilhada sem janela clara para experimento
- inferir silenciosamente `KbPath`, versão, `Environment` ou parâmetros sensíveis
- afirmar sucesso funcional apenas porque o build terminou sem erro operacional

---

## RESPONSIBILITIES

- Usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md)
  como base de infraestrutura compartilhada com `xpz-msbuild-import-export`
- Antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`, avaliar o contexto do import
  recente em busca de sinais de alteração estrutural com impacto em banco:
  - qualquer objeto do tipo `Attribute:` presente em `importedItems` do log de import
  - mudança de tamanho, tipo, precisão ou subtipo de atributo mencionada pelo usuário
  - resultado `reorg detectada ou executada` em execução anterior desta sessão
  Se qualquer sinal estiver presente, exibir aviso explícito e exigir a frase de
  confirmação `entendo que haverá reorg e concordo que prossiga` antes de executar
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de
  `C:\Program Files (x86)`
- Usar `FailIfReorg=true` como default de `BuildAll` — nunca alterar sem instrução explícita
- Nunca emitir `DoNotExecuteReorg=false` implicitamente: reorg só executa quando o
  usuário pedir explicitamente com plena ciência do efeito
- Tratar `-ForceRebuild=true` como operação ampla análoga a reorg autorizada: bloqueada
  por default e habilitada apenas via `-AllowWideRebuild` com confirmação explícita do
  usuário por frase exata (modo interativo) ou `-AllowWideRebuild -ConfirmWideRebuild`
  após confirmar com o usuário humano (modo não-interativo). Nunca emitir `ForceRebuild=true`
  implicitamente em fluxo pós-import nem em validação cotidiana — `BuildAll` incremental
  é o suficiente
- Tratar `-CompileMains=true` e `-DetailedNavigation=true` como opções caras de build:
  bloqueadas por default e habilitadas apenas via `-AllowCostlyBuildOptions` com
  confirmação explícita do usuário por frase exata (modo interativo) ou
  `-AllowCostlyBuildOptions -ConfirmCostlyBuildOptions` após confirmar com o usuário
  humano (modo não-interativo). Nunca emitir essas opções implicitamente em fluxo
  pós-import nem em validação cotidiana
- Distinguir claramente:
  - sucesso operacional da chamada MSBuild
  - efeito funcional observado depois no GeneXus
- Distinguir **Categoria B** (linhas `error :` no log MSBuild capturadas em `buildErrors`/`specifyErrors` no top-level do JSON): quando `executionEvidence.msBuildExitCode=0` mas essas listas não estiverem vazias, o wrapper rebaixa para **`exitCode=48`** (`msBuildCategoryBBlocked=true`) e `status` `falha operacional com rejeicao MSBuild no log` — **não** classificar como `compilou limpo` nem `specify e generate concluídos`; detalhe em [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) e secção «Categorias A e B» em [xpz-msbuild-import-export/SKILL.md](../xpz-msbuild-import-export/SKILL.md); catálogo numérico em `scripts/msbuild-exit-codes.catalog.json`
- Classificar o resultado de cada execução em uma das categorias definidas em WORKFLOW
- Registrar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` temporário e log
- Recomendar reabertura da KB na IDE somente quando houver warning ou efeito colateral
  detectado no build (ex: extensão ausente, `Access denied`, stderr não vazio), ou quando
  o contexto da solicitação indicar que o objetivo é validar a aplicação em execução —
  não mencionar IDE nem URL em builds sem warning onde apenas "faça um build" foi pedido;
  quando a condição estiver presente (ex: stderr não vazio), formular a recomendação como
  consequência determinística da evidência encontrada — citar o padrão específico detectado
  e recomendar explicitamente (ex: "stderr não estava vazio: [padrão]; recomendo reabrir
  a KB na IDE para conferência funcional antes de tratar o build como validado"); não
  enquadrar como sugestão condicional ao interesse do usuário
- Exigir confirmação explícita antes de qualquer execução de reorg
- Tratar `ImpactDatabaseOnly` como pré-requisito de inspeção antes de autorizar `ReorganizeOnly` explícito
- Exigir confirmação interativa obrigatória antes de `ReorganizeOnly`, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- Tratar `SetConfiguration` como operação auxiliar opcional de pré-build: só emitir
  quando explicitamente solicitado pelo usuário, com valor validado (`Release`, `Debug`,
  `Performance Test`)
- Nunca inferir ou alterar configuração sem instrução explícita
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`,
  `LogPath` e `Genexus.Tasks.targets` antes de qualquer build
- Quando `SetActiveVersion` ou `SetActiveEnvironment` falhar, tratar como bloqueio
  operacional explícito: a versão ou o `Environment` solicitado não existe na KB. O
  diagnóstico deve orientar omitir `-VersionName` ou `-EnvironmentName` para usar o
  contexto ativo **somente** quando `kb_environment_count` em `kb-source-metadata.md` for
  `1` (ou quando o objetivo for explicitamente o environment ativo da IDE). Em KB
  multi-environment (`kb_environment_count` > 1), **nunca** omitir `-EnvironmentName` na
  validação pós-import alinhada ao deploy — usar parâmetro explícito ou
  `deployment_environment_name` gravado pelo `xpz-kb-parallel-setup`.
- **Validação deploy (objetivo A)** vs **fix completo multi-environment (objetivo B)**:
  - **A:** um build (`BuildAll` ou `SpecifyGenerate`) com `-EnvironmentName` igual ao
    environment que serve a aplicação (campo `deployment_environment_name` no metadata, ou
    parâmetro). Conferir `observedContext.ActiveEnvironment` no JSON — deve coincidir com o
    environment de validação resolvido (`deploymentEnvironmentContext` no JSON).
  - **B:** quando a frente exigir fechamento em mais de um generator ativo — **opt-in**, não
    gate pós-import automático. Prática usual: após A no environment de deploy, **Build na IDE**
    nos demais environments que a frente ainda cobre (consultar `kb_environment_names` no metadata);
    falha no segundo environment após A bem-sucedido é **rara**. Headless repetido com
    `-EnvironmentName` por env é **opcional**, não padrão. Ver
    [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) (seção
    «Saída do gerador GeneXus por environment»). Não confundir A bem-sucedido com B completo.
- Ao chamar `Invoke-GeneXusKbBuildAll.ps1` ou `Invoke-GeneXusKbSpecifyGenerate.ps1` a partir
  de pasta paralela, passar `-ParallelKbRoot` (ou `-KbMetadataPath`). Os wrappers **leem**
  `kb_environment_count`, `deployment_environment_name`, `kb_environment_names`,
  `deployment_hosting_kind` e, quando a validação de deploy bin estiver ativa,
  `kb_environment_web_dirs` do metadata — **não** inventariam environments nem inferem
  caminho de `web\bin` por pastas da KB nativa em cada build.
- Para diagnostico de `.cs` gerado, resolver o caminho com `Resolve-GeneXusGeneratedCsPath.ps1`,
  que le `kb_environment_web_dirs` no mesmo metadata; metadata sem esse campo volta para
  `xpz-kb-parallel-setup`.
- **Paridade Java/Tomcat (Fase 3, split PER-EIXO):** o suporte é por eixo no registro
  `GeneXusKbHostingKindSupport.ps1`; cada consumidor discrimina pelo predicado **do seu eixo**
  (`runsDeployBinEngine`/`runsSourceEngine`/`runsRuntimeEngine`), não pelo alias legado `runsFreshnessEngine`.
  Para `java-tomcat`: **Eixo A (deploy bin) = `supported`** — o gate **roda um co-gate Java por família**
  (`Test-GeneXusKbDeployBinFreshnessCoreJava`): confere publicação atestada por **conjunto de artefatos do
  objeto** (mtime `<obj>*.java` local vs `<obj>*.class` no `WEB-INF\classes` **externo** do Tomcat, resolvido
  por `kb_environment_servlet_dirs`/`_app_package`), classifica `fresh`/`stale`/`no-evidence`/
  `unexpected-publication`/`unknown` com janela de skew bidirecional (**nunca `fresh` sem publicação
  atestada**; `no-evidence` não falha o gate; `stale`/`unexpected-publication`/`unknown` falham sob gate,
  exit 49). Os **Eixos B (`.cs`/`.java`) e C (runtime) seguem `recognized-no-engine`** (Pós-v1): o resolvedor
  de `.cs` e o `Test-GeneXusRuntimeFreshness.ps1` **pulam** (`CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`/
  `skipped-hosting-unsupported`, `exit 0`) em vez de derivar `CSharpModel\web` .NET. **Skip ≠ deploy validado**
  (vale para os skips B/C e para `no-evidence`/`unknown` do Eixo A). `Test-GeneXusRuntimeFreshness.ps1` aceita
  `-DeploymentHostingKind` por compatibilidade com chamadas legadas (ausente → comportamento .NET de hoje), mas KB
  Java/Tomcat conhecida deve passar `-DeploymentHostingKind java-tomcat` para acionar o skip do Eixo C. Valor de `deployment_hosting_kind`
  fora do registro é rejeitado com mensagem canônica (não vira skip).
- **Paridade Java/Tomcat (Fase 5, evidência empírica):** para EBTECH/Jakarta, clean build dedicado confirmou
  `Rebuild All -> Lf=∅, Pf≠∅` (`Lf=0`, `Pf=624`), portanto `unexpected-publication` continua sendo política
  fail-safe de origem não atestável, não prova de deploy errado. A publicação observada é feita por Gradle
  chamado pelo Build All GeneXus/MSBuild, via tarefas `copyTomcat*`; `deployBinTimeSlackSeconds=5` cobre a
  janela interna da cópia (`copyTomcatClassesStartAt -> lastPublishedClassMTime = 1,824s`), mas não o fim de
  `compileJava` como âncora (`24,045s`). Também foi medido um environment GeneXus `JAVA_EE`/Gradle `javaEE`
  com sinais reais `javax`, mas no stack Tomcat 11/JDK 21/Servlet 6 e com jars `jakarta.*`; Java EE clássico
  puro Tomcat 8/9 + JDK 8 segue não medido. Para metadata Java, `SERVLET_DIR`/`model.ini` é evidência útil,
  mas não autoridade cega: resolver o environment/bloco correto e, quando houver Gradle, confrontar
  `gradle.properties` (`TOMCAT_WEBAPP_PATH`/`TOMCAT_STATIC_PATH`), topologia `WEB-INF\classes`, sentinela
  `WEB-INF\lib\GeneXus.jar` e compatibilidade do pacote da app antes de gravar
  `kb_environment_servlet_dirs`/`_app_package`/`_servlet_flavor`; no motor, `_app_package` é allowlist da
  evidência e a ausência de artefatos sob o pacote aparece pela classificação do co-gate.
- Quando o build falhar com erros C# compatíveis com arquivo gerado truncado, como
  `CS1010` (newline em constante) e `CS1513` (`}` esperada) repetidos no mesmo `.cs`,
  verificar primeiro se o artefato gerado termina abruptamente, sem string/funcao
  fechada ou sem newline final. Se esses sinais aparecerem, classificar como suspeita
  de falha de geração truncada e tentar regeneração controlada antes de investigar o
  XML; `-ForceRebuild=true` continua proibido sem o gate de regeneração ampla
  (`-AllowWideRebuild` + frase exata). Ver
  [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md),
  seção `Diagnostico de codigo gerado truncado por falha de generation`.
- Quando o contexto vier de `xpz-msbuild-import-export` com import OK (`importação real efetiva provada` ou equivalente) mas o evento GeneXus não surtir efeito na UI, ou quando o usuário pedir inspeção pós-build do `.cs` por suspeita de **mecanismo (b)** (strip silencioso por DCE), tratar como frente de **conteúdo gerado**, não como falha do wrapper de build nem como reabertura do sub-estado de import. Após build ou `SpecifyGenerate` concluído com artefato gerado disponível, buscar no `.cs` referenciado pelo nome do evento; zero ocorrências ou handler com corpo vazio/sem efeito observável reforça hipótese (b). Ver [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md), seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`; para verificação estrutural de `oparms` e `ajax_rsp_assign_sdt_attri` em `WebPanel`, ver também subseção `WebPanel, Tab aninhada e re-bind de SDT em data attributes` no mesmo `02`.
- Para **Transaction** e sintomas do tipo “rule não dispara” ou “valor não chega no browser” após import OK com geração pendente ou concluída, complementar a busca por evento com `scripts/Find-CsAttributeAssignments.ps1` no `.cs` web da transação (`-CsPath` absoluto, `-Attribute` com ou sem prefixo `A<n>`, `-AsJson`): mapeia cópias da atribuição por método (`OnLoadActions*`, `CheckExtendedTable*`, `Valid_*`, etc.), indica `AssignAttri` no mesmo método e detecta triplet típico (override INS/`Insert_*`, default por proc, fallback ternário) com `cascadeOrder` para diagnóstico de `if/else if` mutuamente exclusivos. Para a entrada nomeada, ver `transaction-attribute-rule-shadowed-by-default-in-cascade` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md).
- **Mecanismo (a) — rejeição na importação:** se o sintoma for `Unknown function '<nome>'`, `src0294` (ou similar) ou `exitCode != 0` / `errors` no `import.json` de importação, **não** investigar o `.cs` gerado como causa primária nesta skill; classificar como frente de import/source e handoff para `xpz-msbuild-import-export` ou correção no XPZ antes de novo build.
- **Mecanismo (b) — strip por DCE:** sucesso operacional de build **não** prova que o evento foi preservado no `.cs`; a correção típica é tornar o corpo do evento observável ao gerador (ex.: operação opaca via proc externa), conforme `02` — não ajustar parâmetros do wrapper de build nem presumir envelope/XML inválido.

---

## COMMUNICATION

- Responda no idioma do usuário
- Declare sempre a categoria de resultado (ver WORKFLOW) de forma explícita
- Quando o resultado for `reorg necessária detectada`, apresente isso como informação,
  não como falha — e pergunte como o usuário quer proceder
- Quando houver timeout em KB grande, não interprete automaticamente como falha
- Não use linguagem otimista para sugerir segurança que ainda não foi validada
- Quando houver ambiguidade de contexto, interrompa e peça definição explícita
- Quando receber handoff de `xpz-msbuild-import-export` com import OK e suspeita de **mecanismo (b)**, declarar explicitamente que o sub-estado de import **não** é reaberto pelo resultado do build; reportar separadamente categoria de resultado do build (WORKFLOW) e achado da inspeção do `.cs` (handler ausente, strip por DCE, ou handler presente com `oparms`/SDT conforme `02`)
- Quando a inspeção do `.cs` confirmar strip por DCE, orientar correção no source/XPZ conforme [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md), seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`, e não tratar `compilou limpo` ou `specify e generate concluídos` como prova de que o evento GeneXus foi preservado

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|---|---|
| [README.md](../README.md) | Sempre — regras editoriais e posicionamento da base |
| [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) | Sempre — base de infraestrutura MSBuild compartilhada |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais e restrições da trilha XPZ; carregar também após handoff de import OK com evento ausente no `.cs`/UI (mecanismo b), para inspeção pós-build do handler e procedimento em `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`; e quando erros C# sugerirem `.cs` truncado (`CS1010`/`CS1513`) |
| [xpz-msbuild-import-export/SKILL.md](../xpz-msbuild-import-export/SKILL.md) | Handoff quando o sintoma for mecanismo (a) (`Unknown function`/`src0294`, `exitCode != 0` ou `errors` no `import.json`) ou quando faltar sub-estado/classificação de import antes de inspecionar `.cs` |

Skills externas não listadas nesta tabela não devem ser carregadas durante a execução desta skill sem necessidade concreta derivada do contexto específico da tarefa; `xpz-msbuild-import-export` na tabela acima é exceção documentada para handoff de importação e classificação (a)/(b).

---

## EXPECTED INTERFACE

Dois scripts PowerShell próprios, seguindo o mesmo padrão de `xpz-msbuild-import-export`, um wrapper integrador de handoff pós-import e um orquestrador opt-in de lançamento desacoplado.

- `Invoke-GeneXusXpzImportThenBuild.ps1` pertence operacionalmente à trilha `xpz-msbuild-import-export`, mas chama `Invoke-GeneXusKbBuildAll.ps1` como etapa receptora. O build só roda quando `importReadyForBuild.ready=true`; com `buildSkippedReason`, tratar como import não apto para build, não como falha autônoma de build.
- `Start-GeneXusKbBuildDetached.ps1` é o orquestrador **opt-in** do modo desacoplado (build longo / em segundo plano): registra uma Tarefa Agendada one-shot que executa `Invoke-GeneXusKbBuildAll.ps1` fora da sessão do agente e sinaliza a conclusão por arquivo-sentinela. Não altera o wrapper de build (apenas o invoca) e é transporte, não autoridade de política — os gates de reorg/rebuild/opções caras permanecem no wrapper. Contrato e fluxo na subseção **Modo desacoplado (opt-in, build longo)** da ORQUESTRAÇÃO. Self-test: `scripts/Test-StartGeneXusKbBuildDetachedContract.ps1`.
- `Wait-GeneXusKbBuildDetached.ps1` é o helper de **espera** do modo desacoplado: combina sentinela + heartbeat da Tarefa Agendada (com margem de corrida e timeout) para não ficar preso quando o processo morre de forma dura sem escrever a sentinela. Somente leitura; retorna `outcome` (`concluido` / `falha-anomala` / `timeout`); exit 0/70/71. Self-test: `scripts/Test-WaitGeneXusKbBuildDetachedContract.ps1`.

### Categoria B (rejeição MSBuild no log)

Barragem estrutural compartilhada: `scripts/GeneXusMsBuildCategoryBSupport.ps1` (exit **48** em `scripts/msbuild-exit-codes.catalog.json`). Antes de varrer stdout/stderr manualmente ou declarar sucesso com `executionEvidence.msBuildExitCode=0`, ler no **top-level** do JSON de resultado: `exitCode`, `msBuildCategoryBBlocked`, `operationalSubState`, `buildErrors` (em `BuildAll`) ou `specifyErrors` (em `SpecifyGenerate`) e `blockingReasons`. Com `exitCode=48`, reproduzir as linhas `error :` ao usuário e tratar o resultado como **não confiável** para handoff operacional — mesmo que a task MSBuild tenha concluído com sucesso aparente.

- **`Transaction` `Events` + `spc0150`:** se `buildErrors`/`specifyErrors` ou o log trouxer `spc0150: Cannot update database. Changes to database are only allowed in procedures.` em `Transaction` `Events`, ver anti-padrão `transaction-event-attribute-assignment-rejected` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) e Catálogo 2 em [xpz-builder/responsibilities-by-type/transaction.md](../xpz-builder/responsibilities-by-type/transaction.md). Não atribuir atributos da `Transaction` dentro de `Event`; valores persistidos ficam em rules declarativas (escopo motor XPZ; modelagem GeneXus: **nexa**).

### Pós-processamento resiliente (BuildAll / SpecifyGenerate)

Após a task `MSBuild` concluir, `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` envolvem parse de stdout, montagem do diagnóstico e serialização JSON em `try/catch` (motor compartilhado `scripts/GeneXusMsBuildGamPlatformsSupport.ps1` para filtro GAM/NetCore).

- `postProcessingFailed` / `postProcessingError` — falha **local** do wrapper depois que o `MSBuild` já rodou (parse, classificação, hints consultivos, serialização ou gravação do log). **Não** reclassificam automaticamente `executionEvidence.msBuildExitCode=0` como falha operacional nem elevam para exit **90** quando a evidência primária do log bruto sustenta conclusão limpa da task.
- Evidência primária completa por trilha quando `postProcessingFailed=true` e `executionEvidence.msBuildExitCode=0`:
  - **build-all:** `__KB_OPEN__=true` **e** `__BUILDALL_DONE__=true` no `msbuild.stdout.log`, materializados no recovery como `observedContext.KbOpen=true` **e** `observedContext.BuildAllDone=true`; só então o status pode ser `compilou limpo com falha no pos-processamento` com `exitCode=0`.
  - **specify-generate:** `__SPECIFY_DONE__=true` **e** `__GENERATE_DONE__=true` no log bruto, materializados no recovery como `observedContext.SpecifyDone=true` **e** `observedContext.GenerateDone=true`; só então o status pode ser `specify e generate concluídos com falha no pos-processamento` com `exitCode=0`.
- **Recovery externo dos dois wrappers:** só pode promover `compilou limpo com falha no pos-processamento` quando a classificação anterior é `compilou limpo`, `executionEvidence.msBuildExitCode=0`, `observedContext.KbOpen=true` e `observedContext.BuildAllDone=true`; só pode promover `specify e generate concluídos com falha no pos-processamento` quando a classificação anterior é `specify e generate concluídos`, `executionEvidence.msBuildExitCode=0`, `observedContext.SpecifyDone=true` e `observedContext.GenerateDone=true`. Em qualquer outro caso — inclusive `exitCode=48`/`msBuildCategoryBBlocked=true`, reorg, timeout, marcador ausente ou MSBuild não-zero — preservar `status`, `exitCode`, `executionEvidence.msBuildExitCode`, `executionEvidence.StdOutPath`, `executionEvidence.StdErrPath` e os artefatos já conhecidos; enquanto a serialização do recovery for possível, não trocar por sucesso limpo nem por fallback genérico `exitCode=90`.
- `buildSignals` (presente nos objetos enxutos `$fallback` de serialização e `$recovery` externo do build-all quando o JSON saiu parcial) carrega adiante sinais já computados no caminho normal para o agente **não** precisar reabrir o log bruto: `ReorgDetected`, `ErrorCount` e `PostBuildEvents` (as linhas da janela pós-build, o `.bat` de deploy inclusive, pelo nome real — sem detector dedicado). `Complete=true` ⇒ esses sinais são integrais e confiáveis (não reabrir o log para eles); `Complete=false` ⇒ bucket parcial, e campo `null` **não** é `0`/`[]` (significa "não chegou a ser computado") — reabrir o log só para os campos `null`. Consultar `buildSignals` **antes** do log bruto.
- Consultar `artifacts.MsBuildStdoutLogPath` / `executionEvidence.StdOutPath` quando o JSON estiver parcial, com `note` apontando log bruto.
- `environmentRemediationHints` é **omitido** quando não houve ruído GAM filtrado; falha ao montar hints com stdout limpo não deve derrubar o pós-processamento inteiro (`Get-GamPlatformsStdoutPostFilterResult`).

Contrato transversal ampliado (import/export/preview): `10-base-operacional-msbuild-headless.md` e `xpz-msbuild-import-export/SKILL.md`.

### Find-CsAttributeAssignments.ps1

Motor compartilhado de **diagnóstico** no `.cs` gerado (camada web), complementar aos wrappers MSBuild — não substitui classificação de import nem prova sucesso de build.

**Quando usar:** import OK (`importação real efetiva provada` ou equivalente) com geração pendente ou concluída, e sintomas em **Transaction** do tipo “rule não dispara” ou “valor não chega no browser”; também após `SpecifyGenerate`/`BuildAll` quando o `.cs` da transação estiver disponível. Para **WebPanel** e mecanismo **(b)** (evento/handler/DCE), priorizar busca pelo nome do evento conforme `02`; este script não mapeia handlers de evento.

**Parâmetros:**

- `-CsPath` (obrigatório) — caminho absoluto do `.cs` (ex.: `<KbPath>\<Environment>\web\<transaction>.cs`)
- `-Attribute` (obrigatório) — nome com ou sem prefixo `A<n>`; o motor normaliza para a forma canônica no arquivo
- `-AsJson` (opcional) — saída estruturada (`methods[]`, `totals`, `tripletPattern.cascadeOrder`, `hasAssignAttriInMethod`)

Antes de montar `-CsPath`, preferir `scripts/Resolve-GeneXusGeneratedCsPath.ps1` com `-KbPath`, `-ParallelKbRoot`/`-KbMetadataPath`, `-EnvironmentName` quando necessário e `-ObjectName`. O resolvedor usa `kb_environment_web_dirs` em `kb-source-metadata.md`; se o campo estiver ausente, bloquear e encaminhar para `xpz-kb-parallel-setup`, sem glob recursivo na KB nativa nem inferencia por `CSharpModel`. **Exceção (Fase 2, guarda de família do Eixo B):** KB `java-tomcat`/família não-.NET pula com `CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`/exit 0 **antes** desse bloqueio — não exige `web_dirs` (o artefato Java não é `.cs`).

**Mapa dos métodos `.cs` gerados onde a atribuição pode aparecer:** use `methods[].name` como nome literal gerado e cruze com o mapa canônico longo em [xpz-builder/responsibilities-by-type/transaction.md](../xpz-builder/responsibilities-by-type/transaction.md#generated-cs-map-where-a-transaction-assignment-rule-lives-in-xpz-quarantine).

| Padrão de nome do método | Cenário de runtime | Gatilho JS / AJAX | `AssignAttri` típico | Quando aparece |
|--------------------------|--------------------|-------------------|----------------------|----------------|
| `OnLoadActions<KbId>` | carga inicial, refresh leve de FK e recarga parcial server-side | refresh AJAX genérico; também dentro de outros fluxos | presente | observado como método único por Transaction com cópia da rule |
| `CheckExtendedTable<KbId>` | validação pesada no Confirm/Save | submit do form, `Confirmar` / `btn_enter` | presente | observado como método único por Transaction com cópia da rule |
| `Valid_<FKDoLado>` | validação de FK quando o JS decide chamar `VALID_<FK>` | evento AJAX `VALID_<FK>` em `setEventMetadata` | pode faltar | depende de FK usada pela expressão ou condição da rule; variações negativas ficam `padrao-gx-nao-verificado` sem corpus adicional |
| `GX<n>ASA<ATTR><KbId>` | handler AJAX do prompt-aggregator-selector do atributo | `gxfirstwebparm` como `gxajaxAggSel<n>_<ATTR>` | presente | depende de prompt-control associado ao atributo; sem prompt fica `padrao-gx-nao-verificado` sem corpus adicional |

A rule pode estar presente nesses métodos e ainda assim ficar "escondida" em runtime se a cascata interna `if`/`else if` sombrear a atribuição; ver o anti-padrão `transaction-attribute-rule-shadowed-by-default-in-cascade` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md).

**Interpretação de `cascadeOrder`:** os valores conhecidos `override-then-default-then-fallback` e `override-then-fallback-then-default` descrevem a ordem efetiva de ramos `if/else if` mutuamente exclusivos no `.cs` gerado. Trate isso como diagnóstico em quarentena XPZ, não como catálogo geral de modelagem GeneXus. Quando a correção aprovada for inverter a ordem textual de `Rules` no XML da frente, aplicar com `scripts/Edit-GeneXusXmlSurgical.ps1` (`-DryRun`, âncora literal, contagem esperada de âncoras e baseline de `lastUpdate` quando houver) e repetir import/build + leitura do `.cs` antes de encerrar. Entrada canônica: `transaction-attribute-rule-shadowed-by-default-in-cascade` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md).

**Regressão:** `scripts/Test-FindCsAttributeAssignmentsContract.ps1` (sentinela `FIND_CS_ATTRIBUTE_ASSIGNMENTS_CONTRACT_OK`).

### Invoke-GeneXusKbSpecifyGenerate.ps1

Executa `SpecifyAll` seguido de `GenerateOnly`. Sem compilação explícita. Mais rápido
que `BuildAll` para o primeiro check após import cirúrgico — mas **pode disparar
reorganização real de banco de dados** quando a KB tem alterações estruturais pendentes,
pois `SpecifyAll` executa reorg internamente nesse caso. Ver gate pré-execução em
WORKFLOW e nota de comportamento crítico abaixo.

**Parâmetros transversais:**

- `-KbPath` (obrigatório)
- `-GeneXusDir` (opcional — fallback automático)
- `-MsBuildPath` (opcional — fallback automático)
- `-VersionName` (opcional)
- `-EnvironmentName` (opcional)
- `-WorkingDirectory` (obrigatório)
- `-LogPath` (obrigatório — caminho de **arquivo** de log onde o wrapper grava o JSON de resultado; apontar para um **diretório existente** é bloqueado cedo com **exit 50** — gate fail-fast `parametro-invalido`, antes de abrir a KB / registrar tarefa; motor `scripts/GeneXusMsBuildLogPathSupport.ps1`)
- `-VerboseLog` (opcional)
- `-MonitorLogPath` (String, opcional — caminho do arquivo gravado pelo parâmetro
  `-MonitorLog` de `Watch-GeneXusMsBuildLog.ps1`; quando fornecido e o arquivo existir
  após a execução, o wrapper extrai os timestamps das fases internas
  (`iniciado`/`terminado`) e popula `timing.phases` no JSON de resultado; sem este
  parâmetro, `timing.phases` fica vazio mas os tempos totais da execução continuam
  sendo gravados; obrigatório quando `-StartWatcher` for passado — bloqueado por
  política com exit 46 se ausente)
- `-StartWatcher` (switch — quando presente, o próprio wrapper dispara
  `Watch-GeneXusMsBuildLog.ps1` em janela visível com `Start-Process pwsh` antes de
  iniciar o MSBuild; requer `-MonitorLogPath`; o watcher recebe o PID do processo
  wrapper como alvo de monitoramento; o resultado JSON inclui `watcherContext` com
  `watcherLaunched`, `watcherPid`, `watcherScriptPath`, `watcherMonitorLogPath` e
  `watcherLaunchError`; se o watcher falhar ao iniciar, a execução prossegue com
  warning — não bloqueia a execução)
- `-WatcherIntervalSeconds` (Int, default `5` — intervalo de polling em segundos
  repassado ao watcher; usado apenas quando `-StartWatcher` está presente;
  intervalo válido: 1-60)
- `-WatcherSilenceThresholdSeconds` (Int, default `120` — segundos sem nova linha
  no log antes de o watcher emitir alerta de silêncio; repassado ao watcher; usado
  apenas quando `-StartWatcher` está presente; intervalo válido: 30-3600)

O contrato de watcher acima vale para `Invoke-GeneXusKbSpecifyGenerate.ps1` e
`Invoke-GeneXusKbBuildAll.ps1`. Ele é centralizado em
`scripts/GeneXusMsBuildWatcherSupport.ps1`; ao evoluir watcher, timing ou
`watcherContext`, manter o helper comum como sede da regra e evitar lógica divergente
dentro dos wrappers.

> **Limitação conhecida de `timing.phases`:** somente fases com par completo
> (`iniciado` + `terminado`) aparecem na lista. Fases cujo `terminado` nunca é
> emitido — por erro ou abort — são silenciosamente omitidas (ex.: `Atualização
> de configuração da web` quando o GeneXus falha antes de concluí-la). Pares com
> grafia inconsistente entre `iniciado` e `terminado` (ex.: `Get Active Version`
> vs `GetActiveVersion`) são normalizados e fechados corretamente; o campo `name`
> no JSON usa a grafia do `terminado`.

Se `-VersionName` ou `-EnvironmentName` for informado com valor inválido para a KB, o
wrapper deve detectar a falha de `SetActiveVersion`/`SetActiveEnvironment`, emitir
`blockingReasons` específico e orientar omitir o parâmetro para usar o contexto ativo.

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false` — quando `true`, equivale a `Rebuild All`
  da IDE: muda `SpecifyAll`/`GenerateOnly` de incremental para regeneração total de
  TODOS os objetos da KB; em KB grande pode levar horas; **só pode ser habilitado via
  `-AllowWideRebuild`** — tentativa sem essa autorização é bloqueada por política
  com exit 46)
- `-DetailedNavigation` (Boolean, default `false`; opção cara, só pode ser habilitada
  via `-AllowCostlyBuildOptions`)
- `-AllowWideRebuild` (switch — único caminho autorizado para habilitar
  `-ForceRebuild true`; em modo interativo exige que o usuário digite a frase exata
  `entendo que isto pode regerar a KB inteira e aceito o custo`; em modo não-interativo
  requer `-ConfirmWideRebuild`; com `ForceRebuild=false`, o switch é redundante: o
  wrapper registra warning em `warnings`, não pede a frase exata e mantém
  `AllowWideRebuildConfirmed=false`)
- `-ConfirmWideRebuild` (switch — usado em conjunto com `-AllowWideRebuild` para
  dispensar o `Read-Host` interativo da frase de confirmação; destina-se a processos
  desanexados onde não há terminal disponível; proibido sem `-AllowWideRebuild`; o
  chamador é responsável por confirmar com o usuário humano antes de passar este
  parâmetro)
- `-AllowCostlyBuildOptions` (switch — único caminho autorizado para habilitar
  `-DetailedNavigation true`; em modo interativo exige que o usuário digite a frase
  exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`;
  em modo não-interativo requer `-ConfirmCostlyBuildOptions`)
- `-ConfirmCostlyBuildOptions` (switch — usado em conjunto com
  `-AllowCostlyBuildOptions`; proibido sem `-AllowCostlyBuildOptions`; o chamador é
  responsável por confirmar com o usuário humano antes de passar este parâmetro)

**Categorias de resultado:**

- `falha operacional com rejeicao MSBuild no log` — Categoria B: `executionEvidence.msBuildExitCode=0` mas `specifyErrors` populado; `exitCode=48`, `msBuildCategoryBBlocked=true`, `operationalSubState` tipicamente `build com errors do MSBuild — resultado não confiável`; reproduzir linhas `error :` ao usuário; **não** declarar `specify e generate concluídos`
- `specify e generate concluídos` — ambas as etapas passaram com exitCode 0 (classificado pelo wrapper, **sem** Categoria B), stdout sem padrões de alerta após filtro de ruído estrutural conhecido em stdout (ver padrões abaixo) e sem conteúdo real em stderr após filtro de ruído estrutural conhecido
- `reorg detectada ou executada` — padrão `Reorganiza` encontrado em stdout; `SpecifyAll` disparou reorganização real de banco de dados; não declarar sucesso; apresentar ao usuário e aguardar instrução explícita
- `operação concluída, pendente de confirmação funcional` — exitCode 0, mas impedimentos detectados: stderr não vazio, padrões de alerta (`Access denied`) ou eventos pós-build **não registrados/não reconhecidos** em stdout (eventos registrados em `kb_environment_post_build_event_hashes` não rebaixam)
- `erro de specify` — `SpecifyAll` falhou; objetos com referências inválidas ou inconsistência
- `erro de generate` — `GenerateOnly` falhou após specify bem-sucedido
- `KB inacessível` — `OpenKnowledgeBase` falhou antes de qualquer etapa de build

> **Comportamento crítico conhecido — SpecifyAll não é leve quando há alterações estruturais pendentes:**
> A task `SpecifyAll` do GeneXus executa internamente: Database Impact Analysis,
> geração de `ReorganizationScript.txt` e `bldReorganization.cs`, **reorganização real
> do banco** (`gxexec bldReorganization.cs`), especificação, segunda geração e
> **eventos pós-build** configurados na KB (ex.: `start cmd`, deploy automático).
> Esse comportamento é intrínseco à task quando o modelo tem alterações estruturais
> pendentes e independe de qualquer parâmetro do wrapper. `SpecifyAll` não expõe
> `FailIfReorg` nem equivalente — ao contrário de `BuildAll`. A classificação
> `reorg detectada ou executada` sinaliza este cenário como bloqueante.

> **Padrão conhecido — ruído estrutural do `dotnet publish` em `GAM\Platforms\NetCore*` (stdout):**
> Mesmo padrão e mesma lógica de filtro documentados em detalhe na seção
> `Invoke-GeneXusKbBuildAll.ps1` (assinaturas: `MSB3491` ou `NuGet.targets(...): error :`,
> sempre com mensagem de acesso negado e caminho contendo `\GeneXus\...\Library\GAM\Platforms\`).
> `Invoke-GeneXusKbSpecifyGenerate.ps1`
> aplica o mesmo filtro e popula `stdoutFilteredNoise` no diagnóstico. Quando houver
> ruído GAM filtrado, o JSON pode incluir `environmentRemediationHints` (mesmo contrato
> documentado na seção `Invoke-GeneXusKbBuildAll.ps1`).
>
> **Cobertura empírica:** a evidência da matriz 2×2 foi coletada via `BuildAll`. Não foi
> verificado empiricamente se `SpecifyAll` puro (sem compile) também dispara a fase de
> `Inicialização Integrada de Segurança` que origina o ruído. O filtro é seguro de qualquer
> forma: se o ruído não aparecer no fluxo `SpecifyGenerate`, o filtro é idempotente (não
> remove nada que não esteja lá); se aparecer, é removido com a mesma assinatura precisa.
> Quando houver primeira execução real que confirme presença ou ausência do ruído neste
> fluxo, atualizar a evidência empírica acima.

> **Padrão conhecido — ruído estrutural do GeneXus 18 em stderr:**
> O GeneXus 18 escreve exatamente 3 linhas `context [anonymous] 1:12 attribute component
> isn't defined` no stderr durante o `SpecifyAll`. `Invoke-GeneXusKbSpecifyGenerate.ps1`
> filtra esse padrão antes de classificar o status — uma execução bem-sucedida cujo stderr
> contenha apenas esse ruído é classificada como `specify e generate concluídos`. Ver nota
> expandida com evidência técnica completa na seção `Invoke-GeneXusKbBuildAll.ps1`.
> O filtro compartilhado também reconhece somente o par comprovado
> `context [/g_service_worker] <linha>:<coluna> attribute obj isn't defined`; combinações
> cruzadas (`anonymous` + `obj`, `g_service_worker` + `component`) permanecem em
> `stderrContent`. O mesmo helper é aplicado no fluxo normal e no recovery.

### Invoke-GeneXusKbBuildAll.ps1

Equivalente à opção `Build All` do menu Build da IDE GeneXus: executa `BuildAll`, que
faz specify + generate + compile dos objetos alterados desde o último build (build
incremental). Detecta — mas não executa por padrão — reorg necessária. Esta é a etapa
cotidiana após import/edição. Para `Rebuild All` (regeneração total de TODOS os
objetos), ver `-ForceRebuild` abaixo, que **só pode ser usado com `-AllowWideRebuild`
e confirmação explícita** por frase exata.

**Parâmetros transversais:** mesmos do `Invoke-GeneXusKbSpecifyGenerate.ps1`.

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false` — quando `true`, equivale a `Rebuild All`
  da IDE: muda a semântica de `BuildAll` incremental para regeneração total de TODOS
  os objetos da KB, independentemente de mudança; em KB grande pode levar horas e
  regenerar centenas/milhares de objetos, incluindo subtype groups; **só pode ser
  habilitado via `-AllowWideRebuild`** — tentativa sem essa autorização é bloqueada
  por política com exit 46)
- `-CompileMains` (Boolean, default `false` — compila apenas Developer Menu; opção
  cara, só pode ser habilitada via `-AllowCostlyBuildOptions`)
- `-DetailedNavigation` (Boolean, default `false`; opção cara, só pode ser habilitada
  via `-AllowCostlyBuildOptions`)
- `-FailIfReorg` (Boolean, default `true` — bloqueia build se houver reorg pendente)
- `-DoNotExecuteReorg` (Boolean, default `false`)
- `-AllowReorg` (switch — quando presente, define `FailIfReorg=false` e
  `DoNotExecuteReorg=false`; em modo interativo exige que o usuário digite `sim` no
  terminal; em modo não-interativo requer `-ConfirmReorg`)
- `-ConfirmReorg` (switch — usado em conjunto com `-AllowReorg` para dispensar o
  `Read-Host` interativo; destina-se a processos desanexados onde não há terminal
  disponível, como quando `Watch-GeneXusMsBuildLog.ps1` roda em paralelo; proibido
  sem `-AllowReorg`; o chamador é responsável por confirmar com o usuário humano
  antes de passar este parâmetro)
- `-AllowWideRebuild` (switch — único caminho autorizado para habilitar
  `-ForceRebuild true`; em modo interativo exige que o usuário digite no terminal
  a frase exata `entendo que isto pode regerar a KB inteira e aceito o custo`; em
  modo não-interativo requer `-ConfirmWideRebuild`; gate independente do gate de
  reorg — `-AllowReorg` não autoriza regeneração ampla, e `-AllowWideRebuild` não
  autoriza reorg; com `ForceRebuild=false`, o switch é redundante: o wrapper registra
  warning em `warnings`, não pede a frase exata e mantém `AllowWideRebuildConfirmed=false`)
- `-ConfirmWideRebuild` (switch — usado em conjunto com `-AllowWideRebuild` para
  dispensar o `Read-Host` interativo da frase de confirmação; destina-se a processos
  desanexados onde não há terminal disponível; proibido sem `-AllowWideRebuild`; o
  chamador é responsável por confirmar com o usuário humano com a frase exata antes
  de passar este parâmetro)
- `-AllowCostlyBuildOptions` (switch — único caminho autorizado para habilitar
  `-CompileMains true` ou `-DetailedNavigation true`; em modo interativo exige a
  frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`;
  em modo não-interativo requer `-ConfirmCostlyBuildOptions`; gate independente de
  `-AllowWideRebuild` e `-AllowReorg`)
- `-ConfirmCostlyBuildOptions` (switch — usado em conjunto com
  `-AllowCostlyBuildOptions`; proibido sem `-AllowCostlyBuildOptions`; o chamador é
  responsável por confirmar com o usuário humano com a frase exata antes de passar
  este parâmetro)
- `-Configuration` (String, opcional — valores válidos: `Release`, `Debug`,
  `Performance Test`; quando informado, emite `SetConfiguration` imediatamente antes
  do `BuildAll`; quando omitido, a configuração ativa da KB é mantida sem alteração)

**Categorias de resultado:**

- `falha operacional com rejeicao MSBuild no log` — Categoria B: `executionEvidence.msBuildExitCode=0` mas `buildErrors` populado; `exitCode=48`, `msBuildCategoryBBlocked=true`, `operationalSubState` tipicamente `build com errors do MSBuild — resultado não confiável`; reproduzir linhas `error :` ao usuário; **não** declarar `compilou limpo`
- `compilou limpo` — `BuildAll` concluiu com exitCode 0 (classificado pelo wrapper, **sem** Categoria B), sem reorg detectada, stderr vazio após filtro de ruído estrutural conhecido e stdout sem padrões de erro após filtro de ruído estrutural conhecido em stdout (ver padrões abaixo); eventos pós-build registrados em `kb_environment_post_build_event_hashes` (ou benignos por som, sem registro) são informativos e **não** impedem `compilou limpo` — ver `stdoutSignals.postBuildEventClassification`
- `compilou-mas-dll-destino-desatualizada` — MSBuild concluiu com exit 0, mas o `web\bin` resolvido por `kb_environment_web_dirs` para o environment de deploy (`deployment_environment_name` + `deployment_hosting_kind` no metadata) não mostra publicação fresca (DLL de objeto ou `*.config` em `bin`); ver `deployBinFreshness`/`deployBinCheck`/`publicationFreshSinceBuild` no JSON. Com `-PostImportDeployValidation` ou `-StrictDeployBinCheck`, o wrapper usa **exit 49**; sem gate, `exitCode` MSBuild permanece 0 mas **não** declarar validação deploy OK. `GxNetCoreStartup.dll` sozinha **não** dispara este status. **Paridade Java/Tomcat (Fase 3):** o **mesmo** status/exit **49** é reusado quando o co-gate Java (Eixo A) dá `stale`/`unexpected-publication`/`unknown` — aí a evidência ausente é publicação no `WEB-INF\classes` **externo** (`.class` por objeto), não `web\bin`/DLL; ver `deployBinCheck.interpretation` e o shape Java do `binCheck` (`localObjectsFresh`/`publishedObjectsFresh`/`publishedAboveUpperWindow`)
- `compilou com erros` — `BuildAll` falhou por erro de compilação
- `reorg necessária detectada` — `FailIfReorg=true` bloqueou o build; reorg gerada mas
  não executada; usuário deve decidir o próximo passo
- `timeout em KB grande` — wrapper encerrou por timeout mas MSBuild pode ainda estar
  executando; distinguir timeout do invocador de falha real do MSBuild antes de concluir;
  usar `Watch-GeneXusMsBuildLog.ps1` com o PID do processo e o caminho do log para
  acompanhar a execução em andamento sem depender do chat
- `KB inacessível` — `OpenKnowledgeBase` falhou antes do build
- `operação concluída, pendente de confirmação funcional` — exitCode 0, reorg não
  detectada, mas stderr não vazio após filtro de ruído estrutural, ou evento
  pós-build não registrado/não reconhecido (`postBuildEventClassification.shouldDowngrade=true`),
  ou marcador de conclusão não detectado; validação funcional depende de inspeção na IDE

**Eventos de timing no pós-build:** outputs estritamente validados de `TimeSpan`
(`Days`, `Hours`, `Minutes`, `Seconds`, `Milliseconds`, `Ticks` com inteiro; propriedades
`Total*` com número completo) e uma data/hora civil válida são ruído estrutural inerte da
janela e não entram como comandos. As linhas `Powershell New-TimeSpan ...`,
`Powershell (Get-Date).ToString()` e marcadores como `> Build All Task Sucesso` são eventos
reais: sem fingerprint em `kb_environment_post_build_event_hashes`, rebaixam por cautela.
Valores incompletos ou inválidos (`Days: not-a-number`, `TotalSeconds: ERROR`, data impossível)
também permanecem não reconhecidos e rebaixam; não ampliar esse conjunto sem evidência.

> **Alternativa manual para processo já separado ou retomada após timeout:**
> Em execução nova de `BuildAll` ou `SpecifyGenerate`, preferir `-StartWatcher` no
> próprio wrapper. Usar `Watch-GeneXusMsBuildLog.ps1` externamente apenas quando o
> processo já tiver sido iniciado em separado ou quando for necessário acompanhar
> uma execução ainda ativa após timeout do invocador. Se o chamador iniciar
> `Invoke-GeneXusKbBuildAll.ps1` como processo desanexado via `Start-Process pwsh`,
> `Read-Host` não terá terminal disponível. Use
> `-AllowReorg -ConfirmReorg` juntos — nunca redirecione stdin como workaround.
> O chamador é responsável por confirmar com o usuário humano antes de lançar o processo.
>
> Para obter timing por fase no JSON de resultado, defina um caminho para o log do
> monitor e conecte os dois scripts: passe `-MonitorLog <caminho>` ao Watch e o mesmo
> `<caminho>` como `-MonitorLogPath` ao build. O build parseia esse arquivo após
> terminar e popula `timing.phases` com os timestamps de cada fase interna.

> **Padrão conhecido — ruído estrutural do `dotnet publish` em `GAM\Platforms\NetCore*` (stdout):**
> O `BuildAll` em environments .NET Core (NETPostgreSQL, NETCoreSQLServer e similares)
> dispara, na fase `Inicialização Integrada de Segurança`, o comando:
> ```
> dotnet publish -nologo -v q -p:GenInit=false
>   "C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\<NetCore*>\GxDeps.csproj"
>   -o "C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\<NetCore*>"
> ```
> Quando o processo não roda elevado (ver Restrição Operacional de Leitura em
> `10-base-operacional-msbuild-headless.md`), o `dotnet publish` pode falhar com
> `error MSB3491` ao tentar gravar `PublishOutputs.<hash>.txt` em
> `\Library\GAM\Platforms\build\GxDeps\obj\net*\`, ou com a variante
> `NuGet.targets(...): error : Access to the path ... is denied` ao tentar gravar
> temporários sob `\Library\GAM\Platforms\<NetCore*>\obj\`. Esses caminhos ficam sob
> `C:\Program Files (x86)\` — área tratada como estritamente somente leitura pela skill
> por política explícita. Apesar do erro, a fase reporta `Sucesso`, o GAM permanece
> registrado normalmente e o build prossegue sem efeito funcional na KB.
>
> `Invoke-GeneXusKbBuildAll.ps1` filtra esse padrão antes de classificar o status. As
> linhas removidas ficam em `stdoutFilteredNoise` do diagnóstico. Uma execução bem-sucedida
> cujo único padrão bloqueante em stdout seja esse ruído é classificada como `compilou limpo`.
>
> **Assinaturas do filtro:**
> - assinatura 1: linha contém `error MSB3491`, `is denied` (EN) **ou** `acesso negado`
>   (PT-BR), e caminho contendo `\GeneXus\` **e** `\Library\GAM\Platforms\`
> - assinatura 2: linha contém `NuGet.targets(...): error :`, `is denied` (EN) **ou**
>   `acesso negado` (PT-BR), e caminho contendo `\GeneXus\` **e** `\Library\GAM\Platforms\`
>
> Linhas que casem apenas alguns dos critérios (ex.: `MSB3491` em projeto da KB,
> `NuGet.targets` fora da árvore de instalação do GeneXus ou `Access denied` fora de
> `\Library\GAM\Platforms\`) **não são filtradas** — são
> diagnósticos legítimos.
>
> **Remediação opcional (one-time, consultiva):** quando pelo menos uma linha desse ruído
> for filtrada para `stdoutFilteredNoise`, `Invoke-GeneXusKbBuildAll.ps1` (via
> `scripts/GeneXusMsBuildGamPlatformsSupport.ps1`) popula `environmentRemediationHints`
> no diagnóstico JSON com caminhos derivados de `resolvedPaths.GeneXusDir` efetivo,
> a conta `buildUser` que executou o wrapper e comandos `icacls` sugeridos (conceder,
> verificar, reverter) sobre `<GeneXusDir>\Library\GAM\Platforms`. É ação **única** do
> usuário humano em terminal **elevado** — a skill **nunca** executa `icacls` nem altera
> a instalação do GeneXus. **Não** recomenda elevar o build a cada execução; filtrar o
> ruído e classificar como limpo permanece o comportamento padrão aceitável. O hint é
> **não bloqueante**: não entra em `warnings`, não altera `status` nem `exitCode`.

> **Evidência empírica acumulada (ruído GAM/NetCore):**
> Coleta controlada em 2026-05-12, GeneXus 18 Up 14, em duas KBs distintas e dois
> environments cada (matriz 2×2):
>
> | KB | Environment | Generator | `MSB3491` em stdout |
> |---|---|---|---|
> | `wsEducacaoSpTeste` | `NETPostgreSQL` | .NET Core | presente |
> | `wsEducacaoSpTeste` | `NETFrameworkSQLServer` | .NET Framework | ausente |
> | `FabricaBrasil18` | `NETPostgreSQL` | .NET Core | presente |
> | `FabricaBrasil18` | `.Net Environment` | .NET Framework | ausente |
>
> O arquivo target `PublishOutputs.<hash>.txt` é literalmente o mesmo entre KBs distintas
> — é asset compartilhado da instalação do GeneXus, não da KB. A versão GAM no banco
> (`4.1.5` em ambas) permanece idêntica antes e depois, com ou sem elevação. Comparação
> elevado vs não-elevado em `wsEducacaoSpTeste/NETPostgreSQL` confirmou que a falha do
> `dotnet publish` não tem efeito funcional observável: stdout difere em uma única linha
> (a do `MSB3491`); todo o resto — versão GAM, warnings, fases, artefatos gerados em
> `C:\KBs\<kb>\<env>\web\` — é idêntico.
>
> Conclusão: o ruído é determinístico, originário da política de leitura-apenas da
> skill aplicada sobre `C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\`,
> e sem consequência funcional. O filtro é seguro porque cada assinatura é ancorada
> simultaneamente no formato do erro, na mensagem de acesso negado e no caminho de
> instalação do GeneXus, não no padrão genérico `Access denied`.
>
> **Observação sobre cobertura desta matriz (atualização 2026-05-20):** os builds
> da matriz 2×2 acima foram limpos em modo headless sem PATH enriquecido — porque
> nenhum deles atingiu a fase `Atualização de configuração da web` ou
> `DeveloperMenu Compilação`. Quando essas fases são atingidas, builds headless sem
> PATH enriquecido com subdirs do GeneXus 18 falham com mensagem genérica
> `O sistema não pode encontrar o arquivo especificado` (ou, em .NET Framework, a
> versão verbose `gxexec ... Não foi possível encontrar uma parte do caminho`).
> Ver nota "Padrão conhecido — subdirs do GeneXus 18 e PATH herdado em headless"
> abaixo. A política de enriquecimento aplicada pelos wrappers elimina esse modo
> de falha; a matriz histórica é preservada como evidência do estado das KBs em
> 2026-05-12.

> **Padrão conhecido — subdirs do GeneXus 18 e PATH herdado em headless:**
> Tasks internas do MSBuild GeneXus invocam binários auxiliares (`gxexec`,
> `UpdConfigWeb`, `BuildService`, `Reor.exe`) por nome, sem caminho absoluto,
> esperando subdirs do install já presentes em `$env:PATH`. A IDE GeneXus enriquece
> esse PATH implicitamente; um MSBuild lançado por wrapper externo herda apenas o
> PATH do shell do agente, que tipicamente não inclui esses subdirs. Sintomas:
> falha em `DeveloperMenu Compilação para Default (.NET Framework)` ou
> `Atualização de configuração da web`, com `Build All Task falhou` e
> `MsBuildExitCode=1`.
>
> Os wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`
> aplicam enriquecimento automático de `$env:PATH` após resolver `$resolvedGeneXusDir`,
> com lista fixa: raiz `GeneXus18\`, `gxnet\`, `gxnet\bin\`, `gxnetcore\`. Filtro por
> `Test-Path` tolera instalações não-padrão. O resultado é registrado em
> `observedContext.pathEnrichment` do JSON, com `applied` (booleano), `subdirsAdded`
> e `subdirsSkipped`. Subdirs esperados ausentes geram warning em `warnings[]`.
>
> **Evidência empírica (FabricaBrasil18, GeneXus 18 Up 14, 2026-05-20):**
>
> | Rodada | PATH | Status | exit | MsBuildExitCode | BuildAllDone | Duração |
> |---|---|---|---|---|---|---|
> | baseline | default (sem GeneXus) | `compilou com erros` | 45 | 1 | false | 90 s |
> | manual | enriquecido pelo invocador | `compilou limpo` | 0 | 0 | true | 261 s |
> | pós-fix | enriquecido pelo próprio wrapper | `compilou limpo` | 0 | 0 | true | (idem) |
>
> Detalhes técnicos em `10-base-operacional-msbuild-headless.md`, seção "Achado
> Empírico Sobre Subdirs Do GeneXus E PATH Em Headless".

> **Padrão conhecido — ruído estrutural do GeneXus 18 em stderr:**
> O GeneXus 18 escreve exatamente 3 linhas `context [anonymous] 1:12 attribute component
> isn't defined` no stderr durante o `SpecifyAll` — task executada internamente pelo
> `BuildAll` e diretamente por `Invoke-GeneXusKbSpecifyGenerate.ps1`. O próprio GeneXus
> não conta isso como erro: stdout reporta "0 avisos, 0 erros". Evidência empírica
> acumulada: FabricaBrasil18 e wsEducacaoSpTeste em 2026-05-10, environments
> `.Net Environment`, `NETFrameworkSQLServer` e `NETPostgreSQL`, sempre 3 ocorrências,
> mesma posição `1:12`, independente do conteúdo ou de alterações recentes na KB.
> Origem técnica rastreada: `SpecifyAll` invoca `Genexus.MsBuild.Tasks.dll`, que
> referencia `Artech.Genexus.Common` e `Antlr4.StringTemplate`; o warning vaza do
> runtime de templates StringTemplate durante a montagem da changed objects list, antes
> de qualquer especificação real. A IDE absorve essa saída sem registrá-la no `Build.log`;
> artefatos gerados em modo headless são equivalentes aos gerados pela IDE. Ambos os
> scripts filtram esse padrão antes de classificar o status — uma execução bem-sucedida
> cujo stderr contenha apenas esse ruído é classificada como `compilou limpo` /
> `specify e generate concluídos`.
> Há ainda um segundo par comprovado e fechado:
> `context [/g_service_worker] <linha>:<coluna> attribute obj isn't defined`. O filtro não
> aceita o produto cartesiano entre os dois contextos e os dois atributos; qualquer par
> cruzado continua sendo stderr real. No recovery, as mesmas regras alimentam
> `stderrFilteredNoise` e `stderrContent`, evitando que a falha de pós-processamento perca
> essa distinção.

### Invoke-GeneXusDbImpact.ps1

Gera o script de impacto de banco (`ImpactDatabaseOnly`) sem executar a reorganização.
Equivalente ao `PreviewMode` de importação: mostra o que mudaria no banco antes de
qualquer decisão de execução. Usar quando `BuildAll` reportar `reorg necessária detectada`
e o usuário quiser inspecionar antes de autorizar.

**Parâmetros transversais:** mesmos dos scripts anteriores.

**Parâmetros específicos:**

- `-Force` (Boolean, default `false` — força geração do script mesmo que GeneXus ache desnecessário)
- `-EnvironmentName` (String, opcional — Environment a usar; se omitido, usa o ativo)

> `FromModel` e `Model` são propriedades públicas da task confirmadas por reflexão do
> assembly, mas sua semântica exata não foi validada empiricamente. Não emitir sem
> teste controlado que confirme o comportamento esperado.

**Categorias de resultado:**

- `impacto gerado` — script de impacto produzido; caminho do artefato disponível para inspeção
- `nada a reorganizar` — task concluiu sem gerar script de alteração
- `KB inacessível` — `OpenKnowledgeBase` falhou antes da task
- `operação concluída, pendente de confirmação funcional` — exitCode 0, mas o script de impacto ainda precisa ser inspecionado antes de qualquer decisão

**Status:** a implementar.

### Invoke-GeneXusDbReorg.ps1

Executa o script de reorg já gerado (`ReorganizeOnly`), sem repetir o ciclo completo de
`BuildAll`. Usar quando `ImpactDatabaseOnly` já foi executado e inspecionado e o usuário
autoriza explicitamente a execução. Exige confirmação interativa obrigatória.

**Parâmetros transversais:** mesmos dos scripts anteriores.

**Parâmetros específicos:**

- `-DoCreate` (Boolean, default `false` — se `true`, cria também os objetos novos além de alterar os existentes)

**Categorias de resultado:**

- `reorg executada` — script de impacto executado; banco alterado
- `nada a reorganizar` — nenhum script pendente para executar
- `KB inacessível` — `OpenKnowledgeBase` falhou antes da task
- `falha de reorg` — execução do script falhou; banco pode estar em estado parcial

**Status:** a implementar após `Invoke-GeneXusDbImpact.ps1` validado empiricamente.

---

## ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL

Esta seção descreve o fluxo completo para executar `Invoke-GeneXusKbBuildAll.ps1`
com `Watch-GeneXusMsBuildLog.ps1` em paralelo, sem bloquear a conversa com o usuário.

### Por que processo desanexado

`Invoke-GeneXusKbBuildAll.ps1` usa `Start-Process` internamente para o MSBuild e
`Wait-Process` para aguardar o resultado. Se chamado diretamente pelo agente via
PowerShell tool, bloqueia o agente durante todo o build — que pode durar minutos.
A solução é lançar o script como processo filho desanexado e usar `run_in_background: true`
no `Wait-Process` externo, liberando o agente para conversar com o usuário enquanto
o build corre.

### Passo 1 — Preparar pastas e caminhos

```powershell
$testDir    = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-<nome-descritivo>"
New-Item -Path $testDir -ItemType Directory -Force | Out-Null

$monitorLog  = "$testDir\monitor.log"
$buildLog    = "$testDir\build-all.log"
$buildStdout = "$testDir\build-proc-stdout.txt"
$buildStderr = "$testDir\build-proc-stderr.txt"
```

- `$testDir` fica sob `Temp\` do repositório da skill — processos filhos têm permissão de escrita aqui.
- Nunca usar `C:\Temp\` ou pastas fora do repositório — processos desanexados não têm acesso.
- Escolher um nome descritivo que identifique o build (ex.: `xpz-build-20260508-pos-import`).

### Passo 2 — Capturar dirs existentes antes de iniciar

```powershell
$artifactBase = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-msbuild-build"
$dirsBefore   = @([System.IO.Directory]::GetDirectories($artifactBase))
```

O script cria um dir com GUID aleatório em `$artifactBase`. Capturar a lista antes
do início permite identificar o dir novo por diferença — sem depender de timestamp.

### Passo 3 — Iniciar o build como processo desanexado

```powershell
$scriptPath = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\Invoke-GeneXusKbBuildAll.ps1"

$buildArgs = @(
    '-NonInteractive', '-NoProfile', '-File', $scriptPath,
    '-KbPath',         'C:\KBs\<nome-da-kb>',
    '-WorkingDirectory', $testDir,        # obrigatório — pasta já criada no passo 1
    '-LogPath',          $buildLog,       # onde o JSON de resultado será gravado
    '-MonitorLogPath',   $monitorLog,     # conecta com Watch para timing.phases
    '-StartWatcher'                       # wrapper lança o watcher automaticamente
    # adicionar '-AllowReorg', '-ConfirmReorg' apenas se reorg foi autorizada pelo usuário
)

$buildProc = Start-Process pwsh -ArgumentList $buildArgs `
    -RedirectStandardOutput $buildStdout `
    -RedirectStandardError  $buildStderr `
    -NoNewWindow -PassThru
```

- `-WorkingDirectory`: pasta criada no passo 1 — não inventar outro caminho.
- `-LogPath`: onde o JSON de resultado será gravado ao final do build.
- `-MonitorLogPath`: mesmo caminho do log do monitor — obrigatório quando `-StartWatcher` está presente.
- `-StartWatcher`: o wrapper dispara `Watch-GeneXusMsBuildLog.ps1` automaticamente antes do MSBuild; elimina o passo 5 do fluxo externo quando usado.
- `-NoNewWindow`: build roda invisível em segundo plano.
- `-PassThru`: retorna o objeto de processo com o PID.

> **Com `-StartWatcher`, o Passo 5 (Watch externo) pode ser omitido** — o wrapper já cuidou do lançamento. O Passo 4 (aguardar artifact dir) ainda é necessário quando se quer o `msbuildLog` para fins de diagnose, mas não para o watcher em si.

### Passo 4 — Aguardar o artifact dir aparecer

```powershell
$artifactDir = $null
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500
    $newDirs = @([System.IO.Directory]::GetDirectories($artifactBase) |
                 Where-Object { $dirsBefore -notcontains $_ })
    if ($newDirs.Count -gt 0) { $artifactDir = $newDirs[0]; break }
}
if ($null -eq $artifactDir) {
    # build falhou antes de criar o dir — ler stderr para diagnose
    return
}
$msbuildLog = Join-Path $artifactDir "msbuild.stdout.log"
```

- O loop aguarda até 20 s (40 × 500 ms). Em hardware lento pode ser necessário aumentar.
- **Usar diff de arrays** (`$dirsBefore -notcontains $_`), nunca indexar `[0]` diretamente
  no resultado do `Where-Object` — quando há um único resultado, indexar retorna o primeiro
  **caractere** da string, não o item.

### Passo 5 — Abrir Watch em janela visível

```powershell
$watchScript = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\Watch-GeneXusMsBuildLog.ps1"

Start-Process pwsh -ArgumentList @(
    '-NoExit',                            # janela permanece aberta após o Watch terminar
    '-NoProfile',
    '-File',    $watchScript,
    '-ProcessId',   $buildProc.Id,
    '-LogPath',     $msbuildLog,          # msbuild.stdout.log dentro do artifact dir
    '-MonitorLog',  $monitorLog,          # mesmo caminho que -MonitorLogPath do build
    '-IntervalSeconds', '5'               # default; diminuir só em testes curtos
)
```

- Sem `-NoNewWindow` e sem redirect: Watch abre em janela nova visível ao usuário.
- `-NoExit`: a janela permanece aberta após Watch encerrar, para o usuário ler com calma e fechar manualmente.
- Watch exibe o contador de silêncio in-place (sem scroll) e imprime uma nova linha apenas quando há conteúdo real (fase, alerta, início/fim).
- O arquivo `$monitorLog` recebe apenas linhas reais — não o contador de silêncio.

### Passo 6 — Aguardar em background sem bloquear a conversa

```powershell
# Este bloco deve ser executado com run_in_background: true no PowerShell tool.
# O agente fica disponível para conversar com o usuário enquanto o build corre.
# Quando Wait-Process retornar, o runtime notifica o agente automaticamente.

Write-Host "Build PID=$($buildProc.Id) | Watch aberto | aguardando..."
$buildProc | Wait-Process -Timeout 600    # 10 min; ajustar para KBs grandes
Write-Host "BUILD CONCLUIDO | exit=$($buildProc.ExitCode) | log=$buildLog"
```

**Importante:** o bloco inteiro (incluindo `Wait-Process`) deve estar em um único
comando com `run_in_background: true`. Não dividir em dois comandos separados.

### Passo 7 — Ler o resultado quando notificado

Quando a notificação de conclusão chegar, ler o JSON com o `Read` tool (sem prompt de permissão):

```
Read tool → $buildLog (build-all.log)
```

Campos relevantes:
- `status` — categoria de resultado (ver EXPECTED INTERFACE); com Categoria B costuma ser `falha operacional com rejeicao MSBuild no log`
- `exitCode` — código de saída classificado pelo wrapper (0 quando `compilou limpo`/`specify e generate concluídos` **sem** Categoria B; **48** quando `msBuildCategoryBBlocked=true`; outros valores não nulos quando há impedimento ou falha); também é o exit code do processo. O valor bruto da task MSBuild aparece canonicamente em `executionEvidence.msBuildExitCode`. **Nunca** tratar `executionEvidence.msBuildExitCode=0` isolado como sucesso limpo quando `exitCode=48` ou `msBuildCategoryBBlocked=true`. `observedContext.MsBuildExitCode` (PascalCase, dentro do contexto observado), quando presente, é contexto observado/compatibilidade e não substitui o campo canônico; `msBuildExitCode` top-level, quando existir por compatibilidade transitória em algum wrapper, deve duplicar o valor canônico.
- `msBuildCategoryBBlocked` — `true` quando Categoria B rebaixou o resultado para exit 48
- `operationalSubState` — quando presente com `build com errors do MSBuild — resultado não confiável`, reforça que o build não é entrega operacional limpa
- `buildErrors` / `specifyErrors` — listas no top-level (e espelhadas em `stdoutSignals` quando aplicável) com linhas `error :` classificadas; reproduzir ao usuário quando não vazias
- `blockingReasons` — causas acionáveis; com Categoria B inclui resumo por estágio (`BuildAll` / `SpecifyGenerate`)
- `executionEvidence` — evidência bruta da execução (`msBuildExitCode`, `msBuildFailed`, `wrapperExitCode`, logs brutos); `blockingReasons` deve priorizar causas acionáveis e não repetir o exit code bruto quando uma causa específica já existir
- `summary` — descrição legível do resultado
- `timing.msbuildDurationSeconds` — duração do MSBuild em segundos
- `timing.phases` — lista de fases com `name`, `start`, `end`, `durationSeconds`
- `observedContext.ReorgDetected` — se reorg foi detectada
- `stdoutSignals` — sinais estruturados de stdout: `blockingPattern` (primeiro padrão bloqueante detectado APÓS filtro de ruído estrutural, ou `null`), `postBuildEvents` (linhas capturadas na janela `Executando eventos pos-construcao ...` ate o próximo separador `==========`; em logs sem marcador, fallback para `start c:` / `start cmd`; prefixo `(commented) ` quando o GeneXus encenou o comando como comentado), `buildWarnings` (linhas de warning com posição; warnings `pmm00xx` de versão de módulo são adicionalmente promovidos a `warnings` top-level — ver nota abaixo)
- `stdoutFilteredNoise` — ruído estrutural removido de stdout antes de classificar (ex: linhas `error MSB3491` ou `NuGet.targets(...): error :` do `dotnet publish` em `GAM\Platforms\NetCore*` quando rodando sem elevação); quando o único conteúdo bloqueante em stdout for ruído filtrado, o build é classificado como limpo
- `environmentRemediationHints` — **omitido** quando não houve ruído GAM filtrado; quando presente, contém `gamPlatformsWriteDeniedFiltered` com `condition`, `filteredLineCount`, `resolvedGeneXusDir`, `resolvedPlatformsPath`, `buildUser`, `summaryForUser`, `suggestedCommands` (`grant`, `verify`, `revert`) e flags `oneTimeUserAction` / `skillDoesNotExecuteGrant` / `doesNotRecommendElevatedBuild`. Oferta consultiva para silenciar o ruído de vez com permissão NTFS — **não** é warning, erro nem mudança de classificação
- `stderrContent` — linhas reais de stderr após remoção do ruído estrutural do GeneXus 18
- `stderrFilteredNoise` — ruído estrutural removido de stderr; quando `stderrContent` está vazio e `stderrFilteredNoise` tem conteúdo, o build é limpo e nenhuma recomendação de IDE deve ser emitida
- `postProcessingFailed` / `postProcessingError` — quando `true`, o pós-processamento local falhou após o `MSBuild`; ler `postProcessingError` e o log bruto em `executionEvidence`/`artifacts`. Só não tratar como `falha operacional` nem inferir exit **90** pelo terminal quando `executionEvidence.msBuildExitCode=0`, a classificação anterior for limpa e houver evidência primária **completa**: build-all exige `__KB_OPEN__=true` **e** `__BUILDALL_DONE__=true`, materializados como `observedContext.KbOpen=true` **e** `observedContext.BuildAllDone=true`; specify-generate exige `__SPECIFY_DONE__=true` **e** `__GENERATE_DONE__=true`, materializados como `observedContext.SpecifyDone=true` **e** `observedContext.GenerateDone=true`. Categoria B, reorg, timeout, MSBuild não-zero ou marcador ausente preservam a classificação anterior; só no caso completo o `exitCode` classificado pode permanecer **0** com `summary` degradado
- `note` — quando presente após falha de serialização, indica diagnóstico parcial; priorizar `msbuild.stdout.log` nos artefatos
- `buildSignals` — presente **apenas** nos objetos enxutos do build-all (`$fallback` de serialização e `$recovery` externo) quando o JSON saiu parcial; **não** aparece no diagnóstico completo. Carrega adiante `ReorgDetected` / `ErrorCount` / `PostBuildEvents` já computados, com `Complete` indicando se o bucket é integral (`true` ⇒ confiar e não reabrir o log; `false` ⇒ parcial, `null` ≠ `0`/`[]`). Ver "Pós-processamento resiliente"

> **Promoção de warnings `pmm00xx` (versão de módulo) a `warnings` top-level:**
> Warnings GeneXus de família `pmm00xx` (ex.: `pmm0003` "módulo deve ser atualizado para versão N", `pmm0045` "version conflict") sinalizam estado da KB que precisa de atenção do usuário — tipicamente resolvido via `Update Modules` na IDE. Como `buildWarnings` é lista interna que o usuário raramente inspeciona, esses warnings são adicionalmente surfacados em `warnings` (top-level) do diagnóstico, com texto orientativo:
>
> - Caso geral: `Alerta de versao de modulo (pmm00xx): <mensagem original>. Resolver via 'Update Modules' na IDE.`
> - Caso `pmm0045` (inversão de versão — módulo satélite exige versão MAIS NOVA do módulo principal do que a instalada): texto adicional explicando que pode exigir update do GeneXus instalado ou downgrade de módulos da KB; inspecionar via `Update Modules` na IDE.
>
> A promoção é **somente para visibilidade** — não muda classificação de status (warnings continuam sendo warnings, não viram erros). O build pode ser `compilou limpo` ou `specify e generate concluídos` mesmo com `pmm00xx` presentes.

### Modo desacoplado (opt-in, build longo)

O fluxo padrão acima (processo desanexado + Watch em **janela visível**) ainda acopla o
build à console/sessão do agente: fechar acidentalmente a janela do Watch, ou a janela-pai
do processo de fundo, derruba o grupo inteiro (wrapper + MSBuild + GeneXus) — matando um
`BuildAll` longo no meio, sem erro no log. O paliativo da própria janela (título e aviso
`NÃO FECHAR` impressos por `Watch-GeneXusMsBuildLog.ps1`) **reduz** o acidente humano, mas
**não impede** o fechamento.

Para build **esperado longo** (ex.: KB grande, `Rebuild All`, pós-import amplo) ou que vá
**rodar em segundo plano** enquanto o agente conversa, há o modo desacoplado via
`Start-GeneXusKbBuildDetached.ps1`. Ele registra uma **Tarefa Agendada one-shot** que executa
`Invoke-GeneXusKbBuildAll.ps1` **fora** da console e do job da sessão do agente: fechar
qualquer janela ou encerrar o app **não toca o build**.

**Não é o default.** O agente **propõe** este modo quando detecta o gatilho (build longo ou
em background), apresenta o trade-off — perde a janela de progresso ao vivo, ganha robustez a
fechamento — e só o usa por **decisão consciente do usuário**. Build curto ou com o usuário
acompanhando ao vivo: manter a janela visível padrão.

Fluxo:

1. Confirmar com o usuário a escolha pelo modo desacoplado (e, se houver reorg/rebuild,
   obter as frases de confirmação **antes**, pois a tarefa não tem terminal interativo —
   repassar `-AllowReorg -ConfirmReorg` / `-AllowWideRebuild -ConfirmWideRebuild` conforme o caso).
2. Lançar (o orquestrador retorna **imediatamente**, sem bloquear a conversa):

```powershell
$scriptPath = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\Start-GeneXusKbBuildDetached.ps1"
& $scriptPath `
    -KbPath           'C:\KBs\<nome-da-kb>' `
    -WorkingDirectory "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-<descritivo>" `
    -LogPath          "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-<descritivo>\build-all.log" `
    -EnvironmentName  '<env de deploy quando kb_environment_count > 1>' `
    -ParallelKbRoot   '<raiz da pasta paralela>'
    # -SentinelPath default: <LogPath>.sentinel
```

3. O JSON retornado traz `status: build desacoplado disparado`, `taskName`, `sentinelPath`,
   `logPath` e `artifactBaseDir`. Guardar `sentinelPath` e `logPath`.
4. **Espera por dois sinais** (nunca só a sentinela): prefira o helper
   `scripts/Wait-GeneXusKbBuildDetached.ps1 -SentinelPath <...> -TaskName <...>` (rodar em
   `run_in_background`), que encapsula a lógica abaixo e retorna `outcome`
   (`concluido` / `falha-anomala` / `timeout`) com a margem de corrida e o timeout tratados.
   Quando feito à mão, **combinar**:
   - **(a) sentinela** em `sentinelPath` com `{ "done": true, "exitCode": <n>, "logPath": "<...>",
     "logExists": <bool>, "error": "<msg ou vazio>", "stdoutPath": "<...>", "stderrPath": "<...>" }`
     = **conclusão normal**:
     - `logExists=true` → o wrapper concluiu e gravou o JSON de resultado em `logPath` (caminho normal).
     - `logExists=false` com `error` preenchido → o wrapper falhou **antes** de escrever o log;
       ler `error` e os arquivos `detached-payload-error.log` / `detached-payload-stderr.log` no
       WorkingDirectory para diagnóstico (o payload **não** mascara mais a falha como exit cego).
   - **(b) heartbeat** da tarefa via `Get-ScheduledTask -TaskName <taskName>` — se a tarefa parou
     de executar (State ≠ `Running`) ou sumiu **e** a sentinela continua ausente após uma **curta
     margem de corrida**, é **falha anômala** (kill abrupto / OOM / estouro de `-ExecutionTimeLimit`
     antes do `finally`): ler `error`/`stderrPath`. **Pollar só a existência da sentinela deixaria a
     espera presa para sempre num kill duro** — daí o heartbeat. (A margem de corrida cobre o
     instante normal entre a tarefa deixar de estar `Running` e o `finally` escrever a sentinela.)

   Para progresso ao vivo enquanto corre, ler o `msbuild.stdout.log` do artifact dir novo sob
   `artifactBaseDir` (diff de diretórios, como no Passo 4 do fluxo padrão).
5. Quando a sentinela indicar conclusão **com `logExists=true`**, ler o JSON completo de `logPath`
   com a ferramenta `Read` e classificar o resultado **exatamente** como no fluxo padrão (mesmas
   categorias, mesma leitura de `exitCode`/`msBuildCategoryBBlocked`/`buildErrors`). A Tarefa
   Agendada roda **sem janela** (console oculto — `-WindowStyle Hidden`; não há janela para fechar
   acidentalmente) e se auto-remove ao fim; `timing.phases` fica vazio neste modo (sem watcher).

> **Robustez vs. limites:** o modo desacoplado sobrevive a fechar janela e a encerrar o app
> do agente. **Não** sobrevive a **logoff** do Windows (a Tarefa Agendada é registrada com
> `LogonType Interactive`, rodando sob a sessão interativa do usuário logado) nem a reboot —
> coerente com o cenário-alvo (o incidente é fechar janela/app, não deslogar no meio do build).
> O modo `S4U`/Password (que rodaria deslogado) **não é oferecido**, por decisão consciente:
> exigiria armazenar/gerenciar credenciais e o build depende do contexto interativo do usuário
> (instalação do GeneXus, drives mapeados, perfil).

### Observações críticas

- **Não usar `C:\Temp\`** para nenhum arquivo: processos filhos desanexados não têm acesso.
- **Não bloquear** a conversa com `Wait-Process` sem `run_in_background: true`.
- **`-ConfirmReorg` sem `-AllowReorg`** é bloqueado pelo script (exit 46) — nunca passar um sem o outro.
- **`-ConfirmReorg`** substitui o `Read-Host` interativo, mas não dispensa a confirmação do usuário humano — obtê-la antes de lançar o processo.
- **Ler resultado com `Read` tool**, não com `PowerShell(Get-Content ...)` — evita prompt desnecessário.
- **Lançamento elevado (`Start-Process -Verb RunAs`):** quando o build for disparado com elevação UAC para experimento controlado, **não confiar em `Wait-Process`** sobre o objeto retornado por `Start-Process -PassThru` — esse PID pode ser o broker/launcher do UAC, não o `pwsh` elevado real. `Wait-Process` retorna prematuramente quando o broker termina, deixando o build ainda em execução. Estratégia confiável: **polling do `LogPath` (arquivo final do wrapper)** — esse arquivo só aparece quando o script termina, tanto no caminho de sucesso quanto no de falha (`status: falha operacional`); aguardar a existência **e** a estabilidade do tamanho do arquivo. Cenário válido apenas para experimentos controlados — `-Verb RunAs` não é fluxo regular da skill.

---

## WORKFLOW

1. Reler [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md)
   como referência de infraestrutura antes de qualquer operação
2. Confirmar que o ambiente já passou por probe (`Test-GeneXusMsBuildSetup.ps1`) ou
   realizar o probe agora — esta skill não substitui a validação de ambiente
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Identificar o objetivo:
   - verificação pós-import cirúrgico → `Invoke-GeneXusKbSpecifyGenerate.ps1`
   - validação completa incluindo compilação → `Invoke-GeneXusKbBuildAll.ps1`
4a. Se o objetivo for `Invoke-GeneXusKbSpecifyGenerate.ps1`, avaliar sinais de alteração
    estrutural no contexto do import recente:
    - `importedItems` do log de import contém qualquer objeto `Attribute:` → sinal presente
    - usuário mencionou mudança de tamanho, tipo, precisão ou subtipo de atributo → sinal presente
    - execução anterior nesta sessão retornou `reorg detectada ou executada` → sinal presente
    Se qualquer sinal estiver presente:
    - exibir aviso: "Esta execução pode disparar reorganização real de banco de dados,
      pois o import recente contém alterações estruturais em atributo. A task SpecifyAll
      do GeneXus executa reorg internamente quando o modelo tem mudanças estruturais
      pendentes. Para prosseguir, confirme com a frase exata:"
    - `entendo que haverá reorg e concordo que prossiga`
    - aguardar a frase exata do usuário — não aceitar paráfrases ou confirmações genéricas
    - só então executar o script
4b. Se o usuário informar `-Configuration`:
    - confirmar que o valor é `Release`, `Debug` ou `Performance Test`
    - emitir `SetConfiguration` como step imediatamente anterior ao `BuildAll`
    - registrar o valor emitido no log e no diagnóstico
4b. **Environment de validação/deploy (objetivo A):** antes de `BuildAll`/`SpecifyGenerate`,
    confirmar `kb_environment_count` em `kb-source-metadata.md` (via `-ParallelKbRoot` ou
    `-KbMetadataPath`). Se `kb_environment_count` > 1: `-EnvironmentName` obrigatório **ou**
    `deployment_environment_name` preenchido no metadata (setup). Se campos ausentes, bloquear
    e orientar `xpz-kb-parallel-setup` + `Set-XpzKbSourceMetadataDeployment.ps1`. Se a frente
    exigir **objetivo B** (opt-in), orientar Build na IDE nos environments secundários ao
    encerrar — não loop headless automático por `kb_environment_names`.
5. Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`,
   `LogPath` e existência de `Genexus.Tasks.targets`
6. Resolver `GeneXusDir` e `MsBuildPath` por ordem explícita de precedência e fallback,
   registrando origem e descarte de candidatos
7. Se o objetivo for `BuildAll` com reorg autorizada (`-AllowReorg`):
   - apresentar ao usuário o que reorg significa neste contexto
   - exigir confirmação explícita antes de prosseguir
   - só então emitir `FailIfReorg=false` e `DoNotExecuteReorg=false`
7a. Se o objetivo envolver `-ForceRebuild=true` (em `BuildAll` ou `SpecifyGenerate`):
    - apresentar ao usuário o que isso significa neste contexto: equivale a
      `Rebuild All` da IDE, regenera TODOS os objetos da KB independentemente de
      mudança, pode levar horas e regenerar centenas/milhares de objetos em KB grande
    - exigir a frase exata `entendo que isto pode regerar a KB inteira e aceito o custo`
      — não aceitar paráfrases ou confirmações genéricas
    - só então passar `-AllowWideRebuild` (e `-ConfirmWideRebuild` se em processo
      desanexado, após obter a frase do usuário humano)
    - gate independente do gate de reorg: `-AllowReorg` não autoriza `-ForceRebuild=true`,
      e `-AllowWideRebuild` não autoriza reorg
8. Executar o script escolhido seguindo a seção **ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL**
   (para `BuildAll`: processo desanexado + Watch em janela visível + `run_in_background`; **ou**,
   para build longo/em segundo plano após o usuário optar conscientemente, o **modo desacoplado**
   via `Start-GeneXusKbBuildDetached.ps1` + espera por sentinela + heartbeat (helper `Wait-GeneXusKbBuildDetached.ps1`) — ver subseção própria) e capturar:
   - `exitCode`, `msBuildCategoryBBlocked`, `operationalSubState`
   - `buildErrors` ou `specifyErrors` no top-level do JSON (quando existirem)
   - `executionEvidence.msBuildExitCode` e `blockingReasons`
   - resumo de `stdout`
   - resumo de `stderr`
   - caminho do `.msbuild` temporário
   - caminho do log
9. Ler `exitCode`, `msBuildCategoryBBlocked` e `buildErrors`/`specifyErrors` no JSON **antes** de classificar. Com `exitCode=48` ou `msBuildCategoryBBlocked=true`, classificar como `falha operacional com rejeicao MSBuild no log`, reproduzir linhas `error :` ao usuário e **não** usar `compilou limpo` nem `specify e generate concluídos`. Caso contrário, escanear stdout e stderr por padrões de erro e risco antes de classificar, inclusive quando `executionEvidence.msBuildExitCode=0` e `exitCode=0`:
   - padrão bloqueante máximo: `Reorganiza` em stdout → status `reorg detectada ou executada`; não declarar sucesso; informar ao usuário e aguardar instrução
   - eventos pós-build: linhas dentro da janela `Executando eventos pos-construcao ...` ate o próximo separador `==========` em stdout; se o marcador não existir, fallback para linhas `start c:` ou `start cmd`. Classificados contra `kb_environment_post_build_event_hashes` do environment ativo (`kb-source-metadata.md`): registrado = esperado (informativo, **não** rebaixa); não registrado/não reconhecido = rebaixa por cautela; `REM` comentado é inerte; sem registro para o environment, player de som (`SoundPlayer`/`PlaySync`/`.wav`) é benigno e o resto rebaixa. Registrar via `xpz-kb-parallel-setup` (`Register-GeneXusKbPostBuildEvents.ps1`); ver `stdoutSignals.postBuildEventClassification`
   - stderr não vazio: qualquer conteúdo → registrar como warning; impede `specify e generate concluídos`
   - demais padrões relevantes: `Access denied`, `error MSB`, `: error `, `FAILED`, stack traces de exceção
   - **carve-out para ruído estrutural GAM/NetCore:** linhas que casam uma das assinaturas conhecidas (`error MSB3491` ou `NuGet.targets(...): error :`) junto com `is denied`/`acesso negado` e caminho contendo `\GeneXus\` e `\Library\GAM\Platforms\` são removidas de stdout antes desta varredura e listadas em `stdoutFilteredNoise`; padrões legítimos de `Access denied` em qualquer outro contexto **permanecem** bloqueantes
   - se encontrados: registrar no diagnóstico e usar `operação concluída, pendente de confirmação funcional` em lugar de `compilou limpo`
   Classificar então o resultado em uma das categorias definidas em EXPECTED INTERFACE
9a. Quando `environmentRemediationHints.gamPlatformsWriteDeniedFiltered` estiver presente no JSON:
   - apresentar ao usuário `summaryForUser` e os três comandos em `suggestedCommands` como nota **opcional** para eliminar o ruído GAM de forma permanente
   - deixar claro que é execução **única** pelo usuário em terminal elevado e que a skill não executa `icacls`
   - **não** promover a `warnings`, **não** reclassificar o build, **não** sugerir build elevado recorrente nem reabertura da IDE só por causa desse hint
10. Quando o resultado for `reorg necessária detectada`:
    - informar ao usuário sem dramatizar
    - apresentar as três opções:
      a. inspecionar primeiro com `Invoke-GeneXusDbImpact.ps1` — gera o script de impacto para o usuário ver o que mudaria no banco
      b. autorizar reorg diretamente: via `-AllowReorg` em `BuildAll` ou via `Invoke-GeneXusDbReorg.ps1` após inspeção prévia
      c. abrir na IDE para decidir
    - aguardar instrução explícita
    - se o usuário escolher `Invoke-GeneXusDbImpact.ps1`: executar, apresentar resultado e caminho do script; só prosseguir para reorg após nova instrução explícita do usuário
    - se o usuário escolher `Invoke-GeneXusDbReorg.ps1`: exigir confirmação interativa mesmo que `ImpactDatabaseOnly` já tenha rodado na mesma sessão
11. Recomendar reabertura da KB na IDE somente se houver warning ou efeito colateral
    detectado no build (ex: extensão ausente, `Access denied`, stderr não vazio), ou se
    o contexto indicar que o objetivo é validar a aplicação em execução; não mencionar
    IDE nem URL quando o pedido foi apenas "faça um build" e o resultado foi limpo
12. Não declarar sucesso funcional apenas por `exitCode = 0` nem por `executionEvidence.msBuildExitCode = 0` quando `exitCode=48` ou `msBuildCategoryBBlocked=true`

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como capacidade operacional validada, com uso controlado
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] Ambiente validado por probe antes do build
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram
      explicitados
- [ ] Antes de abrir a KB por MSBuild em `BuildAll` ou `SpecifyGenerate`, o bloqueio preventivo de concorrência por KB foi executado; se `msBuildConcurrency.status=blocked` ou `exitCode=46`, a rodada foi abortada e o conflito foi reportado ao usuário, sem tentar enfileirar nem aguardar
- [ ] Houve **monitoramento legível**: janela visível (`-StartWatcher`) **ou** modo desacoplado (`Start-GeneXusKbBuildDetached.ps1` com `msbuild.stdout.log` + arquivo-sentinela); nenhuma execução sem monitoramento, salvo justificativa registrada (`watcherContext.watcherLaunched: false`)
- [ ] O modo desacoplado, quando usado, foi **proposto pelo agente** (build longo/em segundo plano) e escolhido por **decisão consciente do usuário** — não acionado como default; reorg/rebuild tiveram as frases de confirmação obtidas **antes** do lançamento (tarefa sem terminal interativo)
- [ ] Quando o objetivo era `Invoke-GeneXusKbSpecifyGenerate.ps1`, os sinais de alteração estrutural do import recente foram avaliados antes de executar
- [ ] Quando havia sinal de alteração estrutural, a confirmação com a frase exata foi exigida e obtida antes de executar
- [ ] `FailIfReorg=true` foi mantido como default em `BuildAll`, salvo instrução explícita
- [ ] Reorg só foi autorizada após confirmação explícita do usuário
- [ ] `-ForceRebuild=true` (equivalente a `Rebuild All`) só foi usado mediante pedido
      explícito do usuário, com aviso do custo apresentado e frase exata
      `entendo que isto pode regerar a KB inteira e aceito o custo` obtida antes de
      passar `-AllowWideRebuild`
- [ ] `-CompileMains=true` ou `-DetailedNavigation=true` só foram usados mediante
      pedido explícito do usuário, com aviso do significado/custo apresentado e frase
      exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`
      obtida antes de passar `-AllowCostlyBuildOptions`
- [ ] Quando `reorg necessária detectada`, as três opções foram apresentadas ao usuário
- [ ] Quando `reorg detectada ou executada` (pós-SpecifyAll), o resultado foi apresentado ao usuário sem ser classificado como sucesso
- [ ] `Invoke-GeneXusDbImpact.ps1` foi executado antes de `Invoke-GeneXusDbReorg.ps1` quando o objetivo era inspecionar o impacto
- [ ] `Invoke-GeneXusDbReorg.ps1` recebeu confirmação interativa explícita, mesmo quando precedida de `ImpactDatabaseOnly`
- [ ] `stdout`, `stderr`, `exitCode`, `.msbuild` e log foram registrados
- [ ] `msBuildCategoryBBlocked`, `operationalSubState` e `buildErrors`/`specifyErrors` no top-level do JSON foram lidos antes de declarar sucesso; com `exitCode=48`, a rodada foi tratada como Categoria B e as linhas `error :` foram reproduzidas ao usuário
- [ ] Com `spc0150` … `only allowed in procedures` em `Transaction` `Events`, foi aplicado o anti-padrão `transaction-event-attribute-assignment-rejected` e o Catálogo 2 em [xpz-builder/responsibilities-by-type/transaction.md](../xpz-builder/responsibilities-by-type/transaction.md) — atribuição a atributo da transação no `Event` não é correção válida
- [ ] `executionEvidence.msBuildExitCode` foi registrado como local canônico do valor bruto da task MSBuild; `msBuildExitCode` top-level, quando existir, foi tratado apenas como compatibilidade transitória e duplicação do valor canônico
- [ ] `observedContext.pathEnrichment` registrou o enriquecimento preventivo do `PATH` (`applied`, `subdirsAdded`, `subdirsSkipped`)
- [ ] O resultado foi classificado em categoria explícita
- [ ] Sucesso operacional foi separado de confirmação funcional
- [ ] Quando a frente foi descrita por fluxo funcional ("o objeto que X", "a tela que abre ao Y", "o objeto chamado quando Z") em vez de referência direta ao nome, foi confirmado que o objeto em `importedItems` é o alvo executado pelo fluxo descrito antes de declarar a frente encerrada — independente do tipo de objeto
- [ ] Quando erros C# como `CS1010`/`CS1513` sugeriram truncamento de `.cs` gerado, o arquivo referenciado foi inspecionado antes de atribuir a falha ao XML, e qualquer regeneração ampla preservou o gate de `-ForceRebuild=true`
- [ ] Quando o contexto for handoff de import OK com evento que não surte efeito, o `.cs` gerado foi inspecionado pelo nome do evento após build/`SpecifyGenerate`; foi distinguido **mecanismo (b)** (handler ausente/vazio — strip por DCE, correção no source conforme `02`) de falha de build e de **mecanismo (a)** (rejeição na importação — handoff para `xpz-msbuild-import-export`, sem tratar `.cs` como causa primária)
- [ ] Quando o sintoma for Transaction (“rule não dispara” ou valor não chega no browser) após import OK com geração disponível, o `.cs` web foi resolvido antes com `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (ou wrapper local) a partir de `kb_environment_web_dirs`; o `csPath` resolvido foi usado em `scripts/Find-CsAttributeAssignments.ps1` (`-CsPath` absoluto, `-Attribute`, `-AsJson`); caminho, fonte da resolução, cópias por método, `AssignAttri` e `tripletDetected`/`cascadeOrder` foram considerados antes de concluir
- [ ] `watcherContext.watcherLaunched` foi verificado no JSON de resultado; se `false`, a ausência foi documentada e justificada explicitamente
- [ ] Quando `environmentRemediationHints` estiver presente, a oferta `icacls` foi apresentada como consultiva e opcional, sem confundir com warning nem com falha de build
- [ ] `kb_environment_count` e `deployment_environment_name` foram lidos do metadata (ou `-EnvironmentName` explícito) antes do build de validação
- [ ] Com `kb_environment_count` > 1, `-ParallelKbRoot`/`-KbMetadataPath` foi passado e o environment de deploy foi resolvido
- [ ] `ActiveEnvironment` no JSON foi comparado ao environment de validação resolvido antes de declarar validação deploy OK
- [ ] Quando a frente exigiu objetivo B (opt-in): deploy validado (A) **e** Build na IDE nos environments secundários que a frente cobre — ou headless repetido documentado como exceção
- [ ] Validação deploy pós-import usou `-PostImportDeployValidation` (ou `-StrictDeployBinCheck`) com `deployment_hosting_kind` e paths resolvidos por `kb_environment_web_dirs` no metadata; `deployBinFreshness`/`deployBinCheck`/`publicationFreshSinceBuild` foram lidos — **não** declarar deploy OK com `compilou-mas-dll-destino-desatualizada` ou exit **49**; **para `java-tomcat` (Fase 3/5, co-gate)** o alvo resolve por `kb_environment_servlet_dirs`/`_app_package` (não `kb_environment_web_dirs`) e o `deployBinCheck.binCheck` tem **shape próprio** (`localObjectsFresh`/`publishedObjectsFresh`/`publishedAboveUpperWindow`, não `publicationFreshSinceBuild`/`objectDllMaxWriteTime`/`configMaxWriteTime`); tampouco declarar deploy OK com `deployBinFreshness` em `no-evidence`/`unexpected-publication`/`unknown` (não são publicação atestada; Fase 5 confirmou `Rebuild All -> Lf=∅,Pf≠∅`); o skip `skipped-hosting-unsupported` no deploy-bin vale só para um hosting kind com Eixo A `recognized-no-engine` (nenhum hoje); warning de sentinela Core (`GxNetCoreStartup.dll` velho) não substitui gate
- [ ] Build limpo rebaixado a `operação concluída, pendente de confirmação funcional` por motivo benigno (evento pós-build como sino de fim de build, ruído em stderr) **não** suprimiu `-PostImportDeployValidation`: o gate decide por sucesso operacional (`exitCode` 0 + marcador de conclusão do build), não pela string de status; só falha real (Categoria B, reorg, timeout, KB inacessível, que derrubam `exitCode`) pula o gate
- [ ] Quando a frente incluiu validação funcional de endpoint `API`, o resultado HTTP registrou método, rota, status, payload resumido e ambiente servido; esse registro não foi usado como evidência de enforcement GAM sem o smoke 401/403/200

---

## CONSTRAINTS

- Ao interpretar `exitCode` do processo ou do JSON (`46`, `47`, `49`, `50`, `40`–`45`, `48`, …), consultar `scripts/msbuild-exit-codes.catalog.json` — especialmente o anexo `causes[]` do **46**, exit **49** (`deployBinFreshness`) e exit **50** (`-LogPath` apontando para diretório existente); não inferir causa só pelo número no terminal
- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER executar `icacls` nem qualquer concessão NTFS na instalação do GeneXus — apenas oferecer comandos em `environmentRemediationHints` para o usuário executar uma vez, por conta própria, se quiser silenciar o ruído GAM filtrado
- NEVER recomendar elevar o build MSBuild a cada execução como substituto do filtro de ruído GAM; a única elevação mencionada é terminal administrativo **one-time** para o usuário rodar `icacls` sugerido
- NEVER executar `BuildAll` ou `SpecifyGenerate` **sem monitoramento legível** — janela visível (`-StartWatcher`) **ou** modo desacoplado (`Start-GeneXusKbBuildDetached.ps1`, com `msbuild.stdout.log` + arquivo-sentinela). A janela visível é o fluxo padrão; o modo desacoplado é **opt-in consciente do usuário sob conselho do agente** (build longo ou em segundo plano), nunca acionado em silêncio. Ausência **total** de monitoramento (nem janela, nem sentinela) só com justificativa operacional explícita e documentada, declarada ao usuário com base em `watcherContext.watcherLaunched: false` no JSON
- NEVER chamar MSBuild para `BuildAll` ou `SpecifyGenerate` quando o preflight `msBuildConcurrency` confirmar `MSBuild.exe` em execução para a mesma KB; abortar com exit 46 e reportar o processo conflitante
- NEVER executar reorg sem autorização explícita do usuário
- NEVER emitir `FailIfReorg=false` implicitamente — sempre explicitar quando e por quê
- NEVER passar `-ConfirmReorg` sem `-AllowReorg` — combinação bloqueada por política (exit 46)
- NEVER usar `-ConfirmReorg` sem ter obtido confirmação explícita do usuário humano antes
  de lançar o processo — o parâmetro muda o canal de confirmação, não dispensa a confirmação
- NEVER passar `-ForceRebuild true` sem `-AllowWideRebuild` — combinação bloqueada por
  política (exit 46) tanto em `Invoke-GeneXusKbBuildAll.ps1` quanto em
  `Invoke-GeneXusKbSpecifyGenerate.ps1`
- NEVER passar `-ConfirmWideRebuild` sem `-AllowWideRebuild` — combinação bloqueada por
  política (exit 46)
- NEVER passar `-CompileMains true` ou `-DetailedNavigation true` sem
  `-AllowCostlyBuildOptions` — combinação bloqueada por política (exit 46) tanto em
  `Invoke-GeneXusKbBuildAll.ps1` quanto em `Invoke-GeneXusKbSpecifyGenerate.ps1`
- NEVER passar `-ConfirmCostlyBuildOptions` sem `-AllowCostlyBuildOptions` —
  combinação bloqueada por política (exit 46)
- NEVER usar `-ConfirmCostlyBuildOptions` sem ter obtido a frase exata
  `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`
  do usuário humano antes de lançar o processo
- NEVER passar `-ForceRebuild true` em fluxo pós-import cotidiano nem como "validação
  completa automática" — `BuildAll` incremental (sem `-ForceRebuild`) é o passo correto
- NEVER usar `-ConfirmWideRebuild` sem ter obtido a frase exata
  `entendo que isto pode regerar a KB inteira e aceito o custo` do usuário humano antes
  de lançar o processo — o parâmetro muda o canal de confirmação, não dispensa a
  confirmação
- NEVER aceitar paráfrases ou confirmações genéricas no lugar da frase exata de
  confirmação de regeneração ampla
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER tratar `exitCode = 0` isolado como confirmação funcional
- NEVER classificar como `compilou limpo` quando stdout ou stderr contiver padrões de erro (`Access denied`, `error MSB`, `: error `, `FAILED`, stack traces) fora do ruído estrutural GAM/NetCore documentado, mesmo que exitCode = 0
- NEVER ignorar **`exitCode=48`** (`msBuildCategoryBBlocked=true`) — Categoria B: `executionEvidence.msBuildExitCode=0` com linhas `error :` em `buildErrors`/`specifyErrors` no JSON; ver `scripts/msbuild-exit-codes.catalog.json` e Categorias A/B em `xpz-msbuild-import-export/SKILL.md`
- NEVER classificar como `specify e generate concluídos` quando stdout contiver padrão `Reorganiza` — o status correto é `reorg detectada ou executada`
- NEVER tratar stderr não vazio como irrelevante — qualquer conteúdo em stderr deve ser registrado como warning e impede classificação como `specify e generate concluídos`
- NEVER chamar `Invoke-GeneXusKbSpecifyGenerate.ps1` quando houver sinal de alteração estrutural de atributo no import recente sem a confirmação explícita do usuário com a frase `entendo que haverá reorg e concordo que prossiga`
- NEVER aceitar paráfrases ou confirmações genéricas no lugar da frase exata de confirmação de reorg
- NEVER executar `Invoke-GeneXusDbReorg.ps1` sem confirmação interativa explícita do usuário, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- NEVER emitir `FromModel` ou `Model` em `ImpactDatabaseOnly` sem validação empírica prévia do comportamento desses parâmetros nesta instalação
- NEVER emitir `SetConfiguration` implicitamente ou inferir o valor de configuração desejado
- ABORT se `KbPath`, versão, `Environment` de validação/deploy ou destino de logs estiverem ambíguos
- NEVER executar `BuildAll`/`SpecifyGenerate` de validação pós-import em KB com `kb_environment_count` > 1 sem `-EnvironmentName` resolvido (parâmetro ou `deployment_environment_name` no metadata) — o wrapper bloqueia (exit 46)
- NEVER tratar `compilou limpo` como prova de que o IIS/self-host refletiu o import quando `ActiveEnvironment` divergir de `deploymentEnvironmentContext.validationEnvironmentResolved`
- NEVER declarar validação deploy OK quando `status` for `compilou-mas-dll-destino-desatualizada`, `deployBinFreshness=stale`, `publicationFreshSinceBuild=false` ou `exitCode=49` — investigar `deployBinCheck.interpretation`, `objectDllMaxWriteTime`/`configMaxWriteTime` e paths resolvidos por `kb_environment_web_dirs`; **não** usar `GxNetCoreStartup.dll` sozinha como prova de publicação. **Tampouco** declarar deploy OK **para `java-tomcat` (Fase 3/5, co-gate Java)** — cujo alvo é o `WEB-INF\classes` externo por `kb_environment_servlet_dirs`/`_app_package` e cujo `binCheck` tem shape próprio (`localObjectsFresh`/`publishedObjectsFresh`/`publishedAboveUpperWindow`, **não** os campos .NET `objectDllMaxWriteTime`/`configMaxWriteTime`/`publicationFreshSinceBuild`) — quando `deployBinFreshness` for `no-evidence`/`unexpected-publication`/`unknown` — não são publicação atestada (`stale`/`unexpected-publication`/`unknown` falham sob gate; `no-evidence` = build sem mudança, não é evidência de deploy; Fase 5 confirmou que `unexpected-publication` pode surgir em clean build). O skip `skipped-hosting-unsupported` no deploy-bin só ocorreria para um hosting kind com Eixo A `recognized-no-engine` (nenhum hoje)
- ABORT se não houver ambiente controlado compatível com a fase solicitada
