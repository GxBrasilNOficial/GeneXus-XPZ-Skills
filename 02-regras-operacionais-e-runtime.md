# 02 - Regras Operacionais e Runtime
## Papel do documento
operacional

## Nível de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 03-risco-e-decisao-por-tipo.md

## Usado por
04-webpanel-familias-e-templates.md, 05-transaction-familias-e-templates.md, 08-guia-para-agente-gpt.md

## Objetivo
Consolidar regras de geração, clonagem conservadora, materialização, serializacao XPZ e uma camada explicita de ligacao entre estrutura XML observada e comportamento provavel de runtime GeneXus.

## Fontes consolidadas
- 02-genexus-xpz-generation-rules.md
- 20-guia-de-clonagem-segura.md
- 24-resumo-operacional-para-gerador-xpz.md
- documentação oficial GeneXus usada de forma complementar e controlada

## Premissas operacionais

- `Evidência direta`: esta base continua sendo centrada em XML extraido de `XPZ`, não em logs completos de especificacao, importação, build ou execução.
- `Regra documentada`: conceitos como `Base Table`, `Extended Table`, navegacao de `For each`, `Load`, `Refresh` e `Refresh Grid` pertencem ao runtime/especificacao do GeneXus e não podem ser inferidos apenas da forma do XML.
- `Inferência forte`: certos sinais estruturais do XML permitem falar em risco runtime relativo, desde que a fala seja qualificada e não prometa comportamento real sem teste.
- `Hipótese`: quanto mais denso o objeto em `events`, `grid`, `Level`, `AttributeProperties`, `parent`, `pattern` e links contextuais, maior tende a ser a sensibilidade a navegacao, carga de dados e comportamento não trivial em execução.
- `Regra operacional`: achados empíricos específicos de scripts MSBuild headless — incompatibilidades de tasks, comportamentos verificados de API, evidências de execução em KB real — pertencem a `10-base-operacional-msbuild-headless.md`, não a este documento; `10-base` é par deste documento, não downstream dele.

## Níveis de confianca de fonte

Esta base usa quatro níveis de confianca, em ordem decrescente de certeza:

| Nível | Descrição | Quando usar |
|-------|-----------|-------------|
| `Evidência direta` | XML bruto lido diretamente desta base ou de XML oficial da KB alvo na sessao corrente | Afirmacoes sobre estrutura, campos, valores ou comportamento observado |
| `Inferência forte — evidência de KB externa inspecionada` | XML real lido de outra KB GeneXus (não desta base), com fonte rastreavel (KB, versão, objeto) | Padrão observado em KB externa pelo agente ou reportado com rastreabilidade; valido para geração conservadora, mas exige validação na KB alvo antes de importar |
| `Inferência forte` | Padrão derivado de recorrencia estatistica ou lógica estrutural observada nesta base, sem XML diretamente lido para o caso específico | Deducoes plausiveis sobre comportamento esperado quando a evidencia direta não cobre o caso |
| `Hipótese` | Especulacao baseada em analogia, plausibilidade ou intuicao estrutural, sem evidencia empirica direta ou reportada | Caminhos não testados, alternativas não validadas; exige sinalizacao explícita ao usuário |

Regras de uso:
- Nunca promover `Hipótese` a `Inferência forte` sem evidencia adicional.
- Nunca promover `Inferência forte` a `Evidência direta` sem XML real lido na sessao corrente.
- `Inferência forte — evidência de KB externa inspecionada` é nível valido para operacao prática; o agente deve declarar a KB de origem, versão e objeto de referencia quando disponível.
- Ao registrar no handoff, usar exatamente um dos quatro rotulos acima para cada afirmacao critica.

## Achados empiricos da trilha experimental via MSBuild

- `Evidência direta`: na instalacao validada nesta frente, a task `Genexus.MsBuild.Tasks.Import` expos publicamente `PreviewMode`, `IncludeItems` e `ExcludeItems`.
- `Evidência direta`: na mesma instalacao, a task `Import` não expos `UpdateFile` nem `ImportKBInformation` como propriedades publicas configuraveis.
- `Regra operacional`: em automacao headless via `MSBuild`, o agente não deve assumir que parâmetros documentados offline estao disponíveis na task efetivamente carregada; deve validar a assinatura real antes de emitir parâmetros sensiveis.
- `Regra operacional`: quando a base compartilhada ganhar um parâmetro operacional relevante, isso não autoriza presumir que wrappers locais ou adaptadores da pasta paralela da KB já o exponham; a exposicao local é decisão separada e pode estar defasada
- `Regra operacional`: ao encontrar essa defasagem local, o agente deve tratar o caso como oportunidade de adaptacao local, sinalizar a sugestao ao usuário e aguardar aprovacao explicita; a ausencia de exposicao local não é erro por si só
- `Regra operacional`: wrapper recomendado para fluxo local de geracao/empacotamento, como `Test-*KbSourceSanity.ps1`, não vira automaticamente wrapper mínimo universal de materialização oficial ou de `KbIntelligence`; a obrigatoriedade depende do fluxo realmente adotado pela pasta paralela da KB
- `Regra operacional`: em busca textual pontual de `Source` de `WebPanel`, usar `scripts\Search-GeneXusXmlSourceBlock.ps1` como ponto de entrada publico para separar `events`, `layout`, `code` e `serialized`; match bruto em `GxMultiForm` inline não prova comportamento de code-behind
- `Regra operacional`: scripts publicos desta raiz devem ser executados em `pwsh` com PowerShell 7.4 LTS ou superior; a versão LTS mais recente disponível é preferivel; Windows PowerShell 5.1 (`powershell.exe`) não é runtime suportado para os scripts da base.
- `Regra operacional`: `scripts-maintenance/` contem ferramentas de manutencao desta base e campanhas empiricas; esses scripts não são runtime publico das skills em pastas paralelas de KB, mas continuam sob contrato de parse `pwsh` 7.4+.
- `Regra operacional`: pontos de entrada publicos em `scripts/*.ps1` devem declarar `#requires -Version 7.4` para falhar cedo em host PowerShell antigo; exceção nominal: `Test-XpzPowerShellRuntime.ps1` deve continuar executavel em Windows PowerShell 5.1 para localizar `pwsh` e emitir bloqueio claro quando o runtime suportado estiver ausente.
- `Regra operacional`: a validação automática de parse PowerShell da base é `scripts/Test-PsScriptsParse.ps1`, também executada por `.github/workflows/parse-ps-scripts.yml`; ela deve cobrir `scripts/*.ps1`, `scripts-maintenance/*.ps1` e `.example.ps1` das skills fora de `historico/` sob o contrato `pwsh` 7.4+.
- `Regra operacional`: `xpz-kb-parallel-setup` deve exigir wrapper local `Test-*KbPowerShellRuntime.ps1` como primeiro gate de uso operacional da pasta paralela; se `pwsh` 7.4 LTS ou superior estiver ausente, o wrapper deve retornar bloqueio e a pasta não deve prosseguir para sync, índice, auditoria substantiva ou empacotamento.
- `Evidência direta`: `PreviewMode` foi validado operacionalmente com `XPZ` real nesta frente, sem alteracao real da KB.
- `Evidência direta`: `IncludeItems` e `ExcludeItems` tiveram efeito operacional observavel em `PreviewMode` nesta instalacao.
- `Regra operacional`: quando `IncludeItems` ou `ExcludeItems` receberem múltiplos recortes, o wrapper deve normalizar a entrada como lista e serializar no formato aceito operacionalmente pela task carregada, em vez de repassar uma única string composta.
- `Regra operacional`: quando houver diagnostico estruturado de preview headless, `importedItems` deve permanecer lista mesmo quando só um item for retornado.
- `Regra operacional`: ao comparar itens esperados de `IncludeItems` com `importedItems`, o diagnostico compacto deve preservar `expectedItemsRaw`/`importedItemsRaw`, emitir `expectedItemsCanonical`/`importedItemsCanonical` e registrar `itemAliasMatches`; `Panel:Nome` e `SDPanel:Nome` são equivalentes para esse matching, sem esconder a forma crua emitida pelo GeneXus.
- `Regra operacional`: quando o diagnostico JSON de preview/import trouxer `compactSignals`, essa deve ser a leitura compacta preferencial dos sinais de importação; o arquivo lateral `msbuild.import.signals.json` é fallback auditavel quando `compactSignals` estiver ausente, nulo ou insuficiente.
- `Regra operacional`: quando a task `Genexus.MsBuild.Tasks.Import` não expuser `UpdateFile` nem `ImportKBInformation`, o wrapper deve bloquear cedo esses parâmetros quando explicitamente pedidos em valor não neutro (`UpdateFile` com caminho informado, `ImportKbInformation=true`); valor neutro (`ImportKbInformation=false` ou `UpdateFile` omitido) deve ser tratado como não emissao, sem bloqueio. O bloqueio não deve ser contornado por repeticao silenciosa sem o parâmetro: a divergencia entre chamada/wrapper e assinatura efetiva deve ser declarada nominalmente antes de qualquer correcao.
- `Regra operacional`: wrappers e scripts permanentes ficam em `scripts`; artefatos efemeros de execução, logs auxiliares e diretórios temporarios de rodada devem preferir `Temp`.
- `Regra operacional`: wrappers compartilhados e wrappers locais de empacotamento XPZ devem emitir JSON de maquina por padrão no stdout e não usar `-AsJson`; wrappers locais antigos devem ser atualizados pela skill `xpz-kb-parallel-setup`. Bloqueios esperados devem retornar objeto estruturado com `status`, `exitCode`, `stage`/`reason`, `blockingReasons` e campos acionaveis (por exemplo `nextFreeNN` em colisao de pacote), sem ANSI nem stack trace no canal de maquina. Para conceitos equivalentes, preferir `-InputPath` para caminho de entrada e `-ObjectList` para lista nominal `Tipo:Nome`; `-Path` e `-ObjectNames`, quando aceitos, são aliases/compatibilidade.
- `Regra operacional`: os wrappers MSBuild que suportam watcher (`Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1` e `Invoke-GeneXusXpzImport.ps1`) devem expor o mesmo contrato (`-StartWatcher`, `-MonitorLogPath`, `-WatcherIntervalSeconds`, `-WatcherSilenceThresholdSeconds`) e registrar `watcherContext`/`timing.phases` por meio de `scripts\GeneXusMsBuildWatcherSupport.ps1`; `-StartWatcher` sem `-MonitorLogPath` deve bloquear cedo com exit 46. Em `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`, watcher (janela visível) e fluxo padrão, com alternativa **opt-in** para build longo/em segundo plano via `scripts\Start-GeneXusKbBuildDetached.ps1` (Tarefa Agendada one-shot fora da sessão do agente + arquivo-sentinela, sem watcher; janela permanece o default, desacoplado é decisão consciente do usuário sob conselho do agente; ao aguardar a conclusão, **não** pollar só a sentinela — combinar sentinela (`done=true`) + heartbeat da Tarefa Agendada (`Get-ScheduledTask`), ou usar `scripts\Wait-GeneXusKbBuildDetached.ps1` (outcomes `concluido`/`falha-anomala`/`timeout`, exit 0/70/71); o modo sobrevive a fechar janela/app mas **não** a logoff/reboot (`LogonType Interactive`; S4U/Password não oferecido por decisão consciente) — `xpz-msbuild-build`); em preview/export/import, e padrão para execução longa. **Fora** da **Decisão pos-gates**, em importação real de pacote amplo ou com muitos `WorkWithForWeb`, executar sem watcher deve ser tratado como exceção operacional justificada, porque a importação pode disparar regeneracao dos objetos derivados do pattern e durar tempo significativo sem feedback visual; essa exceção por justificativa **não** se aplica quando valer **Decisão pos-gates** (regra dedicada abaixo).
- `Regra operacional`: privilegiar `PreviewMode` antes de importação real apenas quando import real ainda não foi autorizado na sessao ou a rodada for exploratoria; contrato detalhado em `xpz-msbuild-import-export/SKILL.md` (seção **Decisão pos-gates**).
- `Regra operacional`: quando o usuário já autorizou importação real headless na mesma sessao, `Test-GeneXusImportFileEnvelope.ps1` retornou `apto para prosseguir` e o inventario do pacote (passo 6c de `xpz-msbuild-import-export`) passou sem bloqueio de extras, o agente deve executar `Invoke-GeneXusXpzImport.ps1` na mesma rodada com `-StartWatcher` e `-MonitorLogPath` (obrigatórios nesse caminho; sem exceção por justificativa de ausencia de watcher); não encerrar só pelo envelope apto nem exigir `Test-GeneXusXpzImportPreview.ps1` obrigatório antes do import nesse cenário.
- `Regra operacional`: autorizacao de import real na sessao não cobre objetos extras, modulos/ExternalObjects de plataforma não pedidos nem `attributesTopLevelUnreconciled` em pacote cirurgico; nesses casos **ABORT** antes do import e listar o pacote completo ao usuário — anti-padroes **parada após envelope apto** e **reempacotar lixo de export** em `xpz-msbuild-import-export/SKILL.md`.
- `Regra operacional`: em trilha MSBuild headless, distinguir **Categoria A** (comportamento esperado da task — extras de inventario, módulos de plataforma, atributos top-level em export cirurgica; sinalizar ao usuário sem rebaixar `exitCode` quando só A estiver presente) de **Categoria B** (rejeicao no log — linhas `error :`, `invalidTypesRejected`, `exportErrors`/`importErrors`/`previewErrors`/`buildErrors`/`specifyErrors`). Quando `executionEvidence.msBuildExitCode=0` mas Categoria B estiver populada, os wrappers rebaixam o `exitCode` classificado para **48** (`scripts/GeneXusMsBuildCategoryBSupport.ps1`, catalogo em `scripts/msbuild-exit-codes.catalog.json`); artefato no disco não autoriza entrega operacional limpa. Na **Decisão pos-gates**, `exitCode=48` bloqueia import real — autorizacao da sessao não cobre B.
- `Regra operacional`: distinguir **fallback silencioso por nome** (pedido `Tipo:Nome` sem identidade demonstrada no inventario, com `exitCode=0` e sem Categoria B — homonimia, resolucao errada da task GeneXus) de **divergencia de rotulo Export** (`exportTaskLabel` / `10a-gx-export-task-labels.md`, ex. lista `WorkWith:Nome`, pacote `WorkWithForWeb:Nome` — motor em `Get-GeneXusImportPackageObjectInventory.ps1` preenche `deltaComparison.aliasResolutions[]` com regra `exportTaskLabel`). Categoria B e tipo invalido no log não são silenciosos. Com `exitCode=0` e identidade não demonstrada (sem match literal nem `aliasResolutions[]`), **ABORT** antes de materializar/importar/sync — anti-padrao e CONSTRAINT em `xpz-msbuild-import-export/SKILL.md`. Export seletivo via `Invoke-GeneXusXpzExport.ps1` e import/preview seletivo com `-IncludeItems` via `Invoke-GeneXusXpzImport.ps1` / `Test-GeneXusXpzImportPreview.ps1` exigem `-ParallelKbRoot` ou `-IndexPath`; homonimia ou índice invalido/ausente bloqueia com **exit 35** (`objectListPreflight`, estagios `pre-export-identity` / `pre-import-identity`); ausencia no índice sem homonimia gera aviso e segue MSBuild (objeto pode existir só na KB nativa). Inventario pos-pacote continua obrigatório no import.
- `Regra operacional`: índice numerico de `exitCode` dos wrappers MSBuild GeneXus XPZ — fonte canônica `scripts/msbuild-exit-codes.catalog.json` (verificacao mecanica `scripts/Test-MsBuildExitCodesCatalog.ps1`). Para **exit 46**, nunca inferir causa apenas pelo número: consultar `causes[]`, `summary` e `blockingReasons` no JSON do wrapper (watcher sem `-MonitorLogPath`, wide rebuild/reorg, combinacoes invalidas de switches — ver catálogo). Para demais exits, distinguir `exitCode` classificado de `executionEvidence.msBuildExitCode` conforme `legend` do catálogo e `10-base-operacional-msbuild-headless.md`.
- `Regra operacional`: quando `exitCode=46` representar bloqueio preventivo de `MSBuild` concorrente na mesma KB, a rodada deve parar e reportar o conflito; a trilha compartilhada não enfileira, não aguarda automaticamente e não faz retentativa em loop.
- `Regra operacional`: em trilha `MSBuild`, distinguir sempre `sucesso operacional da chamada`, `preview apenas`, `sucesso operacional com falha no pos-processamento` (MSBuild concluiu com `exitCode=0` — valor bruto canônico em `executionEvidence.msBuildExitCode=0` — e a evidencia primaria do log bruto está presente — em import/export: `__IMPORTED_ITEM__` ou `__EXPORTED_FILE__` mais arquivo XPZ existente; em build-all: `__BUILDALL_DONE__=true` e/ou `observedContext.BuildAllDone=true` no diagnostico parcial; em specify-generate: `__SPECIFY_DONE__=true` e/ou `__GENERATE_DONE__=true` e/ou `observedContext.SpecifyDone`/`observedContext.GenerateDone` no diagnostico parcial —, mas o pos-processamento local do wrapper falhou e o JSON saiu com `postProcessingFailed=true`), `preview apenas com falha no pos-processamento` (analogo ao anterior na fase de preview: MSBuild concluiu com `exitCode=0` — valor bruto canônico em `executionEvidence.msBuildExitCode=0` — sem alterar a KB e a evidencia primaria do log bruto está presente, mas o pos-processamento local do wrapper falhou e o JSON saiu com `postProcessingFailed=true`) e `confirmacao funcional posterior na IDE`. O campo `exitCode` no JSON dos wrappers e o valor classificado pelo wrapper (0/32/41/42/48/...); o valor bruto da task MSBuild fica preservado canonicamente em `executionEvidence.msBuildExitCode`; `msBuildExitCode` top-level, quando existir, e compatibilidade transitoria e deve duplicar o valor canônico, enquanto `blockingReasons` deve concentrar causas acionaveis.
- `Regra operacional`: `diagnosticDegraded=true` em diagnostico MSBuild indica diagnostico parcial depois da execução, não falha operacional automática. Ele pode coexistir com `postProcessingFailed=false` quando a saida principal foi montada, mas algum complemento (como `msbuild.import.signals.json`) falhou ou ficou parcial. A classificação final deve considerar `executionEvidence`, marcas do log bruto e a skill responsável pelo wrapper.
- `Regra operacional`: erro de leitura de `GxImport.log` por arquivo bloqueado deve ser classificado como diagnostico degradado (`gxImportLogReadStatus=locked`, `diagnosticDegraded=true`) quando houver evidencias primarias de stdout/stderr suficientes para classificar a chamada; esse sintoma não deve virar causa principal de falha operacional por si só.
- `Regra operacional`: nos caminhos degradados do build-all (`Invoke-GeneXusKbBuildAll.ps1`), o objeto enxuto carrega `buildSignals` com sinais já computados no caminho normal (`ReorgDetected`, `ErrorCount`, `PostBuildEvents`); `buildSignals.Complete=true` indica bucket integral e confiável e dispensa reabrir o log bruto para esses sinais; `Complete=false` indica parcial, e campo `null` não é `0`/`[]` (não computado). Contrato e detalhe em `xpz-msbuild-build/SKILL.md`.
- `Evidência direta`: a IDE do GeneXus permite selecionar objetos modificados depois de uma data/hora antes de exportar, mas o `XPZ` resultante não preserva a condição do filtro; ele contem apenas os objetos selecionados e seus `lastUpdate`.
- `Evidência direta`: na instalacao validada, a task `Export` expos publicamente `ExportAtTimestamp`, mas chamadas headless com esse parâmetro falharam dentro da task, enquanto exportacoes equivalentes por `Objects` explicito concluiram com sucesso e geraram o mesmo conjunto de objetos observado no `XPZ` parcial da IDE.
- `Regra operacional`: ate haver evidencia contraria, a exportação headless via `MSBuild` não deve ser tratada como capaz de filtrar objetos por data de modificacao; para exportação parcial, o caminho validado é fornecer explicitamente a lista de objetos em `Objects`/`ObjectList`.
- `Evidencia direta`: na KB `FabricaBrasil18`, exportação headless de `WebPanel:wpProcessaArquivoDeTransacaoDePagamento` com `ObjectList` preenchido e `DependencyType`/`ReferenceType` omitidos gerou pacote com 25 objetos e 50 atributos top-level; a mesma chamada com `DependencyType="None"` e `ReferenceType="None"` gerou pacote com exatamente 1 objeto e 0 atributos top-level.
- `Regra operacional`: em exportação seletiva/cirurgica cujo objetivo seja obter somente os objetos listados em `Objects`/`ObjectList`, passar `DependencyType="None"` e `ReferenceType="None"` como prevencao na origem. Isso não substitui inventario pos-export: o pacote gerado continua devendo ser confrontado com o delta declarado antes de materializar, importar ou sincronizar. Valores aceitos além de `None` e o default formal quando esses atributos são omitidos permanecem a confirmar.
- `Regra operacional`: depois que os recortes passarem a funcionar de forma confiavel, erro residual de `Source`, `Specification` ou referencia não resolvida em objeto importado deve ser tratado como problema de conteúdo da KB/`XPZ`, não como problema de envelope ou do wrapper, salvo evidencia contraria.
- `Evidência direta`: na KB `FabricaBrasil18` (.Net Environment, GeneXus com instalacao VS2022), a task `SpecifyAll` via MSBuild executou internamente, em sequência: Database Impact Analysis, geração de `ReorganizationScript.txt` e `bldReorganization.cs`, **reorganizacao real de banco** (`gxexec bldReorganization.cs`), especificacao, segunda geração e **eventos pos-build** configurados na KB (`start c:\temp\sino.mp3`, `start cmd /c c:\Dropbox\...\AtualizaDeployFB18.Bat`). O gatilho foi import de atributo com mudanca de tamanho (de 2 para 5). Nenhum parâmetro explicito de autorizacao de reorg foi passado ao wrapper; o comportamento é intrinsecos a task.
- `Evidência direta`: na mesma execução, `SpecifyAll` não expoe `FailIfReorg` nem equivalente — ao contrario de `BuildAll`; não é possível bloquear a reorg via parâmetro do wrapper quando chamando `SpecifyAll` diretamente.
- `Regra operacional`: o wrapper `Invoke-GeneXusKbSpecifyGenerate.ps1` deve varrer stdout pelo padrão `Reorganiza` antes de classificar o resultado; se encontrado, o status deve ser `reorg detectada ou executada` e nunca `specify e generate concluidos` ou qualquer classificação de sucesso sem confirmacao do usuário.
- `Regra operacional`: stderr não vazio em execução headless de `SpecifyAll` deve ser registrado como warning e impedir classificação limpa, independente do exitCode — o padrão `context [anonymous] \d+:\d+ attribute component isn't defined` e ruido estrutural provado do GeneXus 18 e constitui exceção explicita a esta regra.
- `Regra operacional`: em stdout de execução MSBuild, a janela iniciada por `Executando eventos pos-construcao ...` e encerrada pelo próximo separador `==========` indica eventos pos-build configurados na KB que dispararam processos externos; registrar como warning separado, pois esses processos podem incluir deploys automáticos ou outras ações com efeito colateral fora do escopo da verificacao. Para logs sem esse marcador, os wrappers mantem fallback histórico para linhas `start c:` ou `start cmd`.
- `Regra operacional`: quando houver evidencia de import recente de objeto `Attribute:` ou de mudanca declarada de tamanho/tipo/precisao/subtipo de atributo, o agente deve exibir aviso explicito de risco de reorg e exigir confirmacao com a frase `entendo que havera reorg e concordo que prossiga` antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`.
- `Regra operacional`: `BuildAll` via MSBuild com `ForceRebuild=true` equivale a `Rebuild All` da IDE — regenera TODOS os objetos da KB independentemente de mudanca, não apenas os alterados desde o último build. Em KB grande pode durar horas e regenerar centenas/milhares de objetos. Os wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueiam `ForceRebuild=true` por padrão (exit 46); só pode ser habilitado via `-AllowWideRebuild` com confirmacao explicita do usuário pela frase exata `entendo que isto pode regerar a KB inteira e aceito o custo`.
- `Regra operacional`: `CompileMains=true` em `BuildAll` compila também os objetos Main além do Developer Menu; `DetailedNavigation=true` em `BuildAll` ou `SpecifyGenerate` executa navegacao detalhada durante a especificacao. Essas opções podem ampliar muito o custo de uma validação cotidiana em KB grande. Os wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueiam essas opções por padrão (exit 46); só podem ser habilitadas via `-AllowCostlyBuildOptions` com confirmacao explicita do usuário pela frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`.
- `Regra operacional`: o gate de regeneracao ampla (`-AllowWideRebuild`), o gate de opções caras de build (`-AllowCostlyBuildOptions`) e o gate de reorg (`-AllowReorg`) são independentes: autorizar um não autoriza os outros. Cada operacao ampla ou cara exige sua própria confirmacao por frase exata específica.

## Metadado da KB no sync parcial

- `Regra operacional`: um `XPZ` parcial pode ser valido para sync de objetos mesmo quando `Source` vier vazio, incompleto ou ausente.
- `Regra operacional`: esse mesmo `XPZ` pode ser insuficiente para refresh completo de `kb-source-metadata.md`; nesses casos, o fluxo deve preservar os valores estaveis previamente conhecidos em vez de sobrescrever campos com vazio.
- `Regra operacional`: campos vazios ou incompletos do pacote novo não podem apagar `Source/@kb`, `Source/@username`, `Source/@UNCPath`, `Source/Version/@guid` ou `Source/Version/@name` quando houver baseline estavel anterior.
- `Regra operacional`: se o pacote novo trouxer todos esses valores completos e validos, o refresh de metadado pode seguir normalmente.
- `Regra operacional`: `kb-source-metadata.md` deve ser tratado por autoridade de campo: identidade estavel da KB pertence ao setup/resolvedor da KB nativa local, `KMW` vem de XPZ real ou template real comparavel, metadados de materialização pertencem ao `xpz-sync`, e `last_setup_audit_run_at`/`setup_contract_signature_*` pertencem ao setup/auditoria.
- `Regra operacional`: quando o sync XPZ/XML atualizar `kb-source-metadata.md` com `-KbMetadataPath`, usar `scripts\Sync-GeneXusXpzToXml.ps1` via `scripts\XpzKbSourceMetadataEditSupport.ps1` para atualizacao **cirurgica** dos campos de materialização (`updated`, `last_xpz_materialization_run_at`, `source_xpz`, `source_refresh_status` e tabelas `KMW`/`Source`/`Source/Version`), preservando `last_setup_audit_run_at`, `setup_contract_signature_*`, demais frontmatter fora do escopo e EOL dominante via `scripts\XpzTextFileEolSupport.ps1`; não regerar o arquivo inteiro nesse caminho.
- `Regra operacional`: após auditoria de setup bem-sucedida, preferir `scripts/Set-XpzSetupAuditTimestamp.ps1` (wrapper local `Set-*KbSetupAuditTimestamp.ps1`) para gravar `last_setup_audit_run_at` e a assinatura atual do contrato de setup (`setup_contract_signature_version`/`setup_contract_signature_hash`); oferecer na mesma sessao quando `Test-*KbSetupFreshness.ps1` tiver exigido auditoria completa por campo ausente, assinatura ausente ou assinatura defasada e o gate tiver passado — adiar só com recusa ou adiamento explicito do usuário.
- `Regra operacional`: ao concluir auditoria mínima de pasta paralela (`xpz-kb-parallel-setup`), o agente deve montar um **plano consolidado de correcoes** com tudo que a skill classificar como corrigivel na pasta, oferecer execução na mesma sessao após aprovacao quando exigida, e só tratar adiamento como legitimo com recusa ou adiamento explicito do usuário — não fechar apenas com diagnostico quando houver item corrigivel.
- `Regra operacional`: a validação **pré-push do estado de uma pasta paralela de KB** (antes de o usuário fazer push dessa KB) é coberta pela skill `xpz-kb-parallel-pre-push` (orquestrador `Invoke-XpzKbParallelPrePushPhase1.ps1`, gates G0–G5 + K1–K4/K8/K9/K11; `pushReadiness` ready/warn/blocked com `unknown`⇒`blocked` fail-closed; exit 0/2/1). As regras substantivas de cada gate vivem nos satélites dessa skill. É **distinta** da rotina pré-push do repositório de skills (documento `13`) — não confundir os dois contextos. Os gates K8/K9 consomem wrappers locais da pasta paralela por contrato estruturado `-AsJson`; correção de wrapper defasado/ausente é via `xpz-kb-parallel-setup`, não nesta rotina.
- `Regra operacional`: reconciliacao aprovada de identidade estavel deve usar `scripts\Resolve-GeneXusKbIdentity.ps1` para resolver a KB nativa local e `scripts\Update-XpzKbSourceMetadataIdentity.ps1` para escrita localizada em `kb-source-metadata.md`; o atualizador preenche campos ausentes e bloqueia divergencias não vazias sem aprovacao explicita de sobrescrita.
- `Regra operacional`: `metadata wrapper` diferente de `OK` por identidade estavel ausente, parse incompleto ou falha funcional não é ressalva informativa; impede declarar `materializado_e_indice_validado` ate que o metadado seja reconciliado ou o wrapper seja corrigido. `GATE_OK` e índice valido provam apenas a aptidao do índice, não a integridade do contrato de metadata.
- `Regra operacional`: `metadata/deploy` diferente de `OK` em `Test-*KbSetupAudit.ps1` (`PENDENTE` ou `BLOCK`) indica campos de environment/deploy/output ausentes, `kb_environment_names` inconsistente ou legado (ex.: nomes tipicos de scan por pastas `web\`), ou mapeamento `kb_environment_output_dirs`/`kb_environment_web_dirs` ausente/divergente. Complementa `metadata wrapper: OK`; impede declarar `materializado_e_indice_validado` ate perguntar ao usuário os nomes exatos, o diretório de output de cada environment, gravar via `Set-*KbSourceMetadataDeployment.ps1` com `-KbEnvironmentNames` e `-KbEnvironmentOutputDirs`, e validar cada nome via MSBuild (`SetActiveEnvironment` headless). Scan/inventario automático por pastas (`-InventoryFromKbNativePath`, `-InventoryFromGeneXusMsBuild`) foi removido. `Test-XpzWrapperInventory.ps1` sinaliza wrapper local que ainda usa descoberta automática ou omite `-KbEnvironmentNames`/`-KbEnvironmentOutputDirs`.
- `Regra operacional`: `Source` ausente ou incompleto pode ser metadata incompleto da própria KB; `Source/@kb` preenchido com GUID diferente da KB nativa local é pacote de outra KB. Agente não deve trocar esse GUID para normalizar o pacote nem prosseguir com import headless; nesse caso, orientar importação manual pela IDE.
- `Regra operacional`: o caso deve produzir warning claro separando `sync de objetos aceito` de `refresh de metadado parcial`.
- `Regra operacional`: `kb-source-metadata.md` deve expor `last_xpz_materialization_run_at` como horario da última solicitacao/processamento de materialização XPZ/XML, mesmo quando não houver mudanca material nos XMLs.

## Frescor do índice derivado da KB

- `Regra operacional`: `KbIntelligence\kb-intelligence.sqlite` deve expor `last_index_build_run_at` na tabela `metadata` como horario da última solicitacao/processamento de geração do índice, mesmo quando o conteúdo resultante for equivalente ao anterior.
- `Regra operacional`: todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize ou atualize XMLs em `ObjetosDaKbEmXml` deve acionar compulsoriamente a regeneracao/validacao do índice derivado logo depois da materialização.
- `Regra operacional`: quando a pasta paralela adotar `KbIntelligence`, o agente só deve considerar o fluxo de `sync` normal como compativel se houver evidencia clara, na documentação local ou no próprio wrapper local, de que o wrapper de materialização encadeia esse refresh compulsorio do índice.
- `Regra operacional`: na ausencia dessa evidencia clara, o agente deve tratar o caso como compatibilidade operacional pendente da pasta paralela, bloquear o `sync` normal e oferecer atualizacao via setup antes de seguir.
- `Regra operacional`: a superficie exposta pelo wrapper local pode ficar temporariamente a frente, atras ou levemente desalinhada em relacao ao motor compartilhado efetivo da pasta paralela.
- `Regra operacional`: se a falha ocorrer apenas em capability opcional de conferencia/comparacao, sem afetar materialização, contrato principal do wrapper nem refresh obrigatório do índice, o agente deve tratar o caso como divergencia wrapper/engine, rerodar sem o opcional, registrar o incidente e não promover isso automaticamente a bloqueio do sync principal.
- `Regra operacional`: essa tolerancia não vale para falhas que atinjam a operacao central; impacto na materialização, no contrato principal do wrapper, no refresh compulsorio do índice ou em outro gate obrigatório continua sendo bloqueio operacional real.
- `Regra operacional`: o índice está apto para triagem ampla apenas quando `last_index_build_run_at` for igual ou posterior a `last_xpz_materialization_run_at` lido nominalmente em `kb-source-metadata.md`, `inventory_validation_status` estiver literalmente `OK` no `index-metadata` e `extractor_signature_version`/`extractor_signature_hash` na metadata do SQLite coincidirem com o motor em `scripts/Build-KbIntelligenceIndex.py` do repositório ativo (comparacao via `scripts/GeneXusKbIntelligenceExtractorContract.ps1` ou gate `Test-*KbIndexGate.ps1`).
- `Regra operacional`: antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catalogo efetivo (`scripts/gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` na pasta paralela quando existir) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, `Query-KbIntelligenceIndex.py` devolve exit `11`, `blocked=true` e `reason=QUERY_NOT_SEMANTIC_FOR_TYPE` — **não** tratar como zero dependencias; preferir `object-info`, `search-objects`, `list-by-type` ou XML pontual (lista canônica no JSON).
- `Regra operacional`: o índice materializa chamadas resolviveis em `Property Formula` de `Attribute` para `Procedure`, `WebPanel` e `DataProvider` (mesmos padrões de `Source` efetivo); `who-uses` em procedure deixa de ignorar esse uso, mas não substitui leitura da formula quando a semantica da expressao for decisiva.
- `Regra operacional`: em `ExternalObject`, o índice diferencia referencia declarativa por `ATTCUSTOMTYPE` de uso efetivo por chamada de método em variável `exo:<ExternalObject>` no `Source` efetivo; a chamada efetiva gera relacao `calls_external_object_method` com regra `source_external_object_method`, mas ainda não substitui leitura do XML quando a pergunta depender de assinatura, parâmetros ou binding nativo.
- `Regra operacional`: gravabilidade por `Transaction`/`Level`/`Attribute` fica materializada em `transaction_attribute_writability` no build (`schema_version=4`, extrator `8`); `transaction-writable-attributes` no índice tem paridade com `Test-GeneXusTransactionWritability.ps1` quando `Test-GeneXusKbIntelligenceWritabilityParity.ps1` passa na pasta paralela. Fonte canonica do algoritmo: `scripts/GeneXusTransactionWritabilityCore.py`; os gates PowerShell `Test-GeneXusTransactionWritability.ps1` e `Test-GeneXusNewWritableTargets.ps1` são fachadas via `GeneXusTransactionWritabilitySupport.ps1` (sem reimplementacao duplicada). Classificação `unclassified-*` (`writable=null`) continua bloqueando `New`/atribuicao sem leitura adicional do XML. Blocos `New` em `Procedure` ainda exigem `Test-GeneXusNewWritableTargets.ps1`.
- `Regra operacional`: classes CSS ficam catalogadas em `css_class` no build (`schema_version=4`, extrator `8`), com dimensoes `model` (`legacy-theme` de `ThemeClass` | `design-system` de SCSS no Part Styles `c6b14574-...` de `DesignSystem`) e `origin` (`kb-authored` | `packaged-module`); o uso vira relacao `uses_css_class` (resolvivel, `evidence_role` `css_layout`/`css_event`) ou `uses_css_class_dynamic` (atribuicao `.Class=` por variavel/`Format()`, não atribuivel a uma classe). Consultas `css-classes` (catalogo; visao padrão só `kb-authored`, lookup nominal `case-sensitive` nunca filtra origem; `legacy-theme` marcado depreciado) e `css-class-usage` (uso; declara `dynamic_uses_total` e `found_in_catalog`, e lista usadas-mas-nao-catalogadas). Localizador = objeto + snippet (no layout tudo numa linha só, `line` pouco útil). É acelerador de triagem com frescor por gate — renomear/remover classe exige conferencia por busca literal no XML. Ver `08` e `scripts/README-kb-intelligence.md`.
- `Regra operacional`: o índice materializa na tabela `objects` se um objeto foi GERADO por Pattern (WorkWith For Web) vs AUTORAL — colunas `is_generated_object` (0/1), `pattern_object_id` e `instance_key`, extraídas do `<Properties>` de nível-objeto (escopadas ao objeto raiz via parse XML com fallback regex, nunca de `<Object>` aninhado em contêiner como `PackagedModule`). Preferir esse sinal determinístico à heurística de nome (`ww*`/`*WC`/`*General`/`*Selection`) ao separar autoral de gerado (ex.: auditoria de segurança). Filtro `--generated`/`--authored` (switches `-Generated`/`-Authored` no wrapper) em `search-objects` e `list-by-type`; contador `generated_objects_count` na metadata. Reverse lookup por instância: `search-objects -InstanceKey <nome|<GUID>-<nome>>` lista os objetos gerados por uma instância WorkWithForWeb (auto-detecção nome vs chave completa, correspondência exata ignorando caixa, AND com os demais filtros; `-InstanceKey` só em `search-objects`; `search-objects` exige `-ObjectName` OU `-InstanceKey`); o campo derivado `instance_name` (nome da instância, `null` quando não derivável) é servido em `object-info`/`search-objects`/`list-by-type` (não em `attribute-info`/`transaction-*`). Ver `08` e `scripts/README-kb-intelligence.md`.
- `Regra operacional`: `AGENTS.md` e `README.md` locais da pasta paralela da KB não devem gravar timestamps literais de materialização ou índice; devem apontar para `kb-source-metadata.md`, para `-Query index-metadata` do wrapper local e para o gate efetivo. Timestamp literal nesses markdowns é drift documental e pendencia operacional real; a correcao é substituir por ponteiros para as fontes autoritativas, não atualizar o valor duplicado.
- `Regra operacional`: se o índice estiver ausente, sem metadado, mais antigo que a última materialização XPZ/XML, com `inventory_validation_status` ausente ou diferente de `OK`, com assinatura de extrator ausente ou divergente do motor ativo, se `kb-source-metadata.md` estiver ausente ou se esse arquivo não expuser literalmente `last_xpz_materialization_run_at`, o agente não deve consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, e também não deve gerar objetos para importação na KB pela IDE.
- `Regra operacional`: o agente não deve substituir `last_xpz_materialization_run_at` por data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatório ou outro metadado aproximado.
- `Regra operacional`: índice ausente ou defasado é exceção operacional, tipicamente de pasta paralela ainda sem wrappers XPZ atualizados ou de falha fortuita; o agente deve bloquear pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML oficial de objeto e geração, oferecendo ao usuário a atualizacao do índice antes de seguir.
- `Regra operacional`: em pasta que adota `KbIntelligence`, o agente não deve apresentar `sync` seguido de regeneracao manual separada do índice como fluxo normal; esse desenho só e aceitavel como etapa consciente de reparo/compatibilidade aprovada pelo usuário.
- `Regra operacional`: com gate de índice bloqueado, leitura pontual só e aceitavel para diagnostico mínimo da incompatibilidade em documentação local, estrutura, wrappers e metadados operacionais; não montar, testar existência, listar ou abrir caminho de XML oficial de objeto para responder pergunta de negocio.
- `Regra operacional`: o gate do índice deve ser sequencial e atômico; não testar, listar ou abrir caminho filho de uma camada antes de validar a camada pai, como `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`.
- `Regra operacional`: se o wrapper local documentado de consulta do índice estiver ausente, não listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup.
- `Regra operacional`: scripts do motor com parâmetros totalmente dinâmicos por execução não requerem wrapper local na pasta paralela — devem ser chamados diretamente pelo caminho absoluto do motor; wrapper local só se justifica quando há parâmetros estáticos da KB a encapsular.
- `Regra operacional`: para inspecionar XML/XPZ grande sem despejar `CDATA` inteiro no chat ou no log de agente, usar utilitarios compactos do motor compartilhado (`scripts\Extract-XpzObject.ps1`, `scripts\Get-GeneXusObjectSummary.ps1`, `scripts\Compare-GeneXusPanelShape.ps1`) antes de recorrer a busca textual que imprima linhas completas.

## Evidencia complementar de gerador local

- `Evidência direta`: a pasta local `C:\Dev\Test\from-anywhere-to-GeneXus` contem um gerador simplificado que monta XML de importação GeneXus usando um envelope com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: nesse gerador local, o `README` e o script principal apontam para geração de `import_file.xml` e importação direta do XML, não para empacotamento `.xpz` zipado real.
- `Inferência forte`: essa fonte local serve como confirmacao secundaria de envelope mínimo plausivel e do formato de `ObjectIdentity`, mas não como autoridade principal para valores concretos de producao.
- `Inferência forte`: o gerador local reforca a decisão de manter `KnowledgeBase` e `Settings` fora do formato normal de objetos.
- `Hipótese`: valores hardcoded dessa fonte local, como `Build=0`, `username="root"`, `SampleKB`, `BusinessLogic`, `parentGuid` fixo e `moduleGuid` fixo, podem levar o agente para caminho errado se forem tratados como regra geral.
- `Evidência direta`: um `.xpz` mínimo de `Procedure`, montado nesta trilha com `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, foi importado com sucesso no GeneXus quando `Source/@kb` e `Source/Version/@guid` estavam em formato GUID valido.

## Status de deploy/diagnóstico por `deployment_hosting_kind` (paridade Java/Tomcat)

- `Decisão congelada`: os `deployment_hosting_kind` reconhecidos vêm do registro-fonte-única `GeneXusKbHostingKindSupport.ps1` (acesso só via `Get-GeneXusKbHostingKindSupportRecord`). A partir da **Fase 3**, o suporte é **PER-EIXO**: cada kind carrega `deployBinSupportState` (Eixo A — deploy-bin), `runtimeSupportState` (Eixo C — runtime-freshness) e `sourceSupportState` (Eixo B — `.cs`/`.java` gerado), cada um em `supported` | `recognized-no-engine` | `blocked-out-of-scope`. Valor **fora** do registro é rejeitado com mensagem canônica (`Get-GeneXusKbHostingKindSupportInvalidValueMessage`), **não** vira skip.

| kind | Eixo A (deploy-bin) | Eixo B (`.cs`/`.java`) | Eixo C (runtime) |
|---|---|---|---|
| `dotnet-core-self-host`, `dotnet-framework-iis` | `supported` → `fresh`/`stale`/`unknown` | `supported` → `CS_PATH_RESOLVED` | `supported` → `runtime-*` |
| `java-tomcat` | **`supported`** (Fase 3) → co-gate: `fresh`/`stale`/`no-evidence`/`unexpected-publication`/`unknown` | `recognized-no-engine` → `CS_PATH_SKIPPED_HOSTING_UNSUPPORTED` (skip, Pós-v1) | `recognized-no-engine` → `skipped-hosting-unsupported` (skip, Pós-v1) |

- `Regra (discriminador PER-EIXO)`: cada consumidor discrimina pelo predicado **do seu eixo** — `runsDeployBinEngine` (Eixo A: política/fachada de deploy-bin), `runsSourceEngine` (Eixo B: `Resolve-GeneXusGeneratedCsPath.ps1`), `runsRuntimeEngine` (Eixo C: `Test-GeneXusRuntimeFreshness.ps1`) — **não** pelo alias legado `runsFreshnessEngine` (que segue o Eixo A e, para Java pós-Fase 3, é `true`; ler o alias nos Eixos B/C rodaria o motor `.cs`/`.rsp` indevidamente). Os aliases `runsFreshnessEngine`/`freshnessSupportState`/`freshnessSkipStatus`/`unsupportedReason` persistem **um ciclo de release** (deprecados, derivados do Eixo A) para consumidores externos (wrappers de pasta paralela); migrar para os campos per-eixo.
- `Regra (co-gate Java, Eixo A)`: o gate Java confere **publicação atestada** por **conjunto de artefatos do objeto** (max mtime dos `<obj>*.java` locais em `web\src\main\java` vs `<obj>*.class` publicados no `WEB-INF\classes` **externo** do Tomcat), com **janela de skew bidirecional**. Propriedade de segurança: **nunca `fresh` sem publicação atestada neste build**. Classificação: `fresh` (todos os objetos gerados têm `.class` fresco), `stale` (publicação parcial — falha sob gate), `no-evidence` (build sem mudança — **não** falha), `unexpected-publication`/publicação não-atestada (publicado sem geração local — falha, fail-safe), `unknown` (config-error — falha sob gate). Evidência Fase 5 (EBTECH/Jakarta, 2026-07-07): clean build dedicado pode produzir `Lf=∅, Pf≠∅` (`Lf=0`, `Pf=624`), então esse quadrante é real e deve permanecer fail-safe ou exigir estado/decisão explícita de "última publicação bem-sucedida", não virar `fresh`; no environment GeneXus `JAVA_EE`/`javaEE` medido, o co-gate fechou com `Lf=618`, `Pf=618`, diferenças zero, mas no stack Tomcat 11/JDK 21/Servlet 6 com sinais `javax` e `jakarta.*`. Skew: `.class` "do futuro" (Tomcat-adiantado) é excluído da janela → jamais falso-`fresh`. Âncora superior **operativa na Fase 3** = `Now` (a fachada pública não cabeia `BuildEndedAt`; a preferida-por-design `DeployStepCompletedAt` ficou como follow-up pós-Fase 5) — exposta em `deployBinCheck.thresholdSupAt`. Evidência Fase 5: `5s` cobreu a janela interna `copyTomcatClassesStartAt -> lastPublishedClassMTime` (1,824s), mas não `compileJavaEndAt -> lastPublishedClassMTime` (24,045s); portanto a âncora correta para eliminar falso-`stale` é o fim da publicação/cópia (`copyTomcatClasses`/`copyTomcat*`, futuro `DeployStepCompletedAt`), não o fim de `compileJava`. Limite: com topologia externa, `Now` (relógio da máquina KB) e os `mtime` dos `.class` (relógio do servidor de deploy) podem divergir por skew de NTP → falso-`stale` sistêmico (nunca falso-`fresh`).
- `Regra`: **skip ≠ deploy validado** (Eixos B/C Java = Pós-v1). Um `CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`/`skipped-hosting-unsupported` significa "não verificado por falta de motor por família", **não** "publicação confirmada". (Para o Eixo A Java, isso vale para `unknown`/`no-evidence`: não são "deploy OK".)
- `Metadata do alvo Java (Eixo A)`: o co-gate resolve o alvo externo por campos dedicados de `kb-source-metadata.md`, por env Java: `kb_environment_servlet_dirs` (= alvo externo que termina em `WEB-INF\classes`; evidência pode vir do `SERVLET_DIR` do `model.ini` do environment correto e, quando houver Gradle, deve ser confrontada com `<output>\web\gradle.properties`/`TOMCAT_WEBAPP_PATH`), `kb_environment_app_package` (pacote da app, ex.: `com\ebtech` — nunca varrer `com\` inteiro) e `kb_environment_servlet_flavor` (`jakarta`|`javax`). Fase 5 mediu `JAKARTA_EE` e um environment GeneXus `JAVA_EE`/Gradle `javaEE` com sinais reais `javax` em Tomcat 11/JDK 21/Servlet 6; Java EE clássico puro Tomcat 8/9 + JDK 8 segue não medido. Antes de gravar o metadata, auditar que `kb_environment_servlet_dirs` termina em `WEB-INF\classes`, que existe a sentinela irmã `WEB-INF\lib\GeneXus.jar` e que o pacote informado para a app é compatível com o alvo; em runtime, o motor usa `kb_environment_app_package` como allowlist da evidência e a ausência de artefatos publicados aparece pela classificação do co-gate, não por uma guarda adicional de topologia. Divergência entre `model.ini` e `gradle.properties`/sentinelas exige auditoria, não escrita cega. Ausência/topologia inválida → `unknown` (config-error, fail-safe), nunca `fresh`.
- `Superfícies observáveis`: Eixo A .NET/**Java** roda o motor (fachada `Test-GeneXusDeployBinFreshness.ps1` → `status` do co-gate; classificação `Invoke-GeneXusKbDeployBinPostBuildClassification` reclassifica/gate em `stale`/`unexpected-publication`/`unknown`). Eixos B/C Java **pulam**: `Resolve-GeneXusGeneratedCsPath.ps1` → `CS_PATH_SKIPPED_HOSTING_UNSUPPORTED` (`exit 0`, sem `csPath`); `Test-GeneXusRuntimeFreshness.ps1` com `-DeploymentHostingKind` → `skipped-hosting-unsupported`. Tab-completion interativo de `-DeploymentHostingKind` requer registrar o `ArgumentCompleter` (fail-soft, opt-in) em perfil/módulo.

## Envelope XPZ observado em export real

- `Evidência direta`: no export real inspecionado nesta trilha, o arquivo `.xpz` continha um único XML principal com raiz `<ExportFile>`.
- `Evidência direta`: no export full observado, os blocos de primeiro nível foram `KMW`, `Source`, um bloco especial de KB, `Objects`, `Attributes` e `Dependencies`, nessa ordem.
- `Evidência direta`: o bloco `KMW` observado continha `MajorVersion`, `MinorVersion` e `Build`.
- `Evidência direta`: em um export completo observado nesta trilha, o bloco top-level `<Objects>` continha `7219` nos `<Object>`.
- `Regra editorial`: esse `7219` descreve aquele envelope/export observado e não deve ser lido automaticamente como total do inventario publico atual, cuja rastreabilidade agregada fica em `09-inventario-e-rastreabilidade-publica.md`.
- `Evidência direta`: após o fechamento do bloco top-level `<Objects>`, o envelope observado seguiu com `<Attributes>`, depois `<Dependencies>`, e por fim `</ExportFile>`.
- `Inferência forte`: para esta base, a forma mais segura de pensar um XPZ é "envelope `<ExportFile>` com seções top-level recorrentes", e não "arquivo `Objects.xml` isolado" sem prova local.
- `Evidência direta`: no lote amplo de `.xpz` reais, o formato normal mais frequente não traz bloco especial de KB; esse bloco aparece apenas em exportacoes especiais/full e em variacoes antigas de mudanca de versão.
- `Hipótese`: outros formatos de export GeneXus 18 podem existir; esta base só prova o envelope observado acima.
- `Evidência direta`: no lote amplo de `.xpz` reais, também apareceu pacote valido sem itens exportaveis materializaveis no acervo final.
- `Regra operacional`: pacote sem itens exportaveis não deve ser classificado automaticamente como falha de leitura; a interpretacao correta depende do recorte de export efetivamente aceito pela IDE.
- `Regra operacional`: quando houver relatório de execução, distinguir explicitamente entre `no-exportable-items` e erro real de leitura, mapeamento ou verificacao.
- `Evidência direta`: no acervo amplo analisado, todos os XMLs individualizados continham `lastUpdate` presente e parseavel no elemento raiz.
- `Regra operacional`: quando o acervo individualizado e o pacote processado tiverem `lastUpdate` valido, usar esse campo como protecao contra regressao de ordem de processamento.
- `Regra operacional`: item vindo de pacote mais antigo não deve sobrepor em disco um XML individualizado com `lastUpdate` mais novo; nesse caso, o processamento deve marcar o item como ignorado por obsolescencia, não como falha de leitura.
- `Evidência direta`: em importação real de `Attribute`, a KB preservou o `lastUpdate` do XML como `Modified Date`, independentemente do `Import Date`.
- `Regra operacional`: ao gerar ou alterar XML de objeto GeneXus, preencher `lastUpdate` por procedimento mecanico, obtido do relogio local atualizado do ambiente que produz o XML e comparado com o acervo oficial quando existir baseline do mesmo objeto.
- `Regra operacional`: para objeto realmente modificado, calcular `NEW_TS = max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)`; se o acervo oficial estiver ausente por se tratar de objeto novo, usar `UtcNow + 60s` e registrar explicitamente que não houve baseline oficial comparado.
- `Regra operacional`: toda regravacao de XML gerado localmente deve atualizar `lastUpdate` para `NEW_TS`; não usar hora cheia, minuto arredondado, valor literal escrito a mao, `lastUpdate` copiado de outro XML ou timestamp herdado do acervo em objeto modificado.
- `Regra operacional`: quando o XML serializar `lastUpdate` em UTC com sufixo `Z`, converter corretamente a partir do horario local real; não reutilizar timestamp antigo, aproximado ou herdado de rodada anterior.
- `Regra operacional`: se o `lastUpdate` salvo de objeto modificado ficar igual ou anterior ao `lastUpdate` do acervo oficial, tratar como defeito bloqueante, porque o GeneXus pode aceitar o import sem atualizar efetivamente o objeto.
- `Regra operacional`: se o `lastUpdate` salvo ficar varios minutos no futuro sem justificativa pelo acervo oficial + margem, tratar como defeito bloqueante, porque pode disparar avisos de KB modificada depois da hora atual e mascarar diagnosticos reais.
- `Regra operacional`: em pacote de importação, somente o objeto efetivamente alterado deve receber `lastUpdate` novo; objetos apenas reenviados para fechamento de dependencias devem manter o `lastUpdate` original do XML da KB.
- `Regra operacional`: em XMLs GeneXus parecidos, não assumir que a mesma insercao vai casar em todos os objetos; confirmar o trecho exato em cada arquivo antes de aplicar a mesma edicao.
- `Regra operacional`: depois de regravar XML local, validar no arquivo final tanto o `lastUpdate` quanto a presenca real dos nos inseridos no ponto esperado.
- `Regra operacional`: em XMLs GeneXus com blocos repetidos ou muito parecidos, localizar e validar cada ocorrência antes de aplicar a mesma edicao.
- `Regra operacional`: depois de editar XML local, validar não só se o XML abre, mas se os nos novos aparecem em todos os pontos funcionais esperados do objeto, especialmente em `Transaction` e `WorkWithWeb`.
- `Regra operacional`: para aplicar delta textual aprovado em XML de objeto GeneXus sem reserializar o arquivo, preferir `scripts/Edit-GeneXusXmlSurgical.ps1` com ancora literal validada (`-ExpectedAnchorCount`), `-DryRun` antes do apply, bump automático de `lastUpdate` (escape `-PreserveLastUpdate` apenas para dependencia reenviada sem mudanca) e baseline do acervo via `-LastUpdateBaselinePath` quando existir; em falha de well-formedness após gravacao, o motor restaura backup.

### Gravacao segura de XML grande

- `Regra operacional`: XML GeneXus grande, especialmente `Procedure` com `Source` extenso ou blocos `CDATA`, não deve ser tratado como valido apenas porque o comando de escrita terminou sem erro fatal.
- `Regra operacional`: depois de gerar XML grande, reler cabecalho, cauda do arquivo e bloco funcional afetado antes de qualquer empacotamento.
- `Regra operacional`: a validação mínima é: XML bem-formado, raiz esperada fechada (`</Object>` ou `</ExportFile>`), `lastUpdate` conferido quando aplicavel, `CDATA` encerrado e ausencia de linha final truncada.
- `Regra operacional`: se a geração usar heredoc, here-string ou mecanismo equivalente e o stderr indicar delimitador encerrado por EOF, como `here-document ... delimited by end-of-file`, o artefato deve ser tratado como corrompido e descartado para regeneracao controlada.
- `Regra operacional`: em PowerShell, here-string com interpolacao não deve carregar chamada de método sem subexpressao; usar `$($variavel.Metodo())` ou evitar here-string para composicao complexa, porque `$variavel.Metodo()` pode materializar texto literal em vez do resultado.
- `Regra operacional`: para XML grande, preferir serializacao estruturada, script dedicado ou gravacao em arquivo temporario seguida de validação e troca atômica; escrita em blocos só e aceitavel quando a validação final do arquivo completo for obrigatória.
- `Regra operacional`: quando houver tamanho, quantidade de linhas ou fechamento estrutural esperado por molde comparavel, usar esses sinais como alerta de truncamento; divergencia relevante bloqueia empacotamento ate reinspecao.

### Gate de sanidade do `Source` GeneXus antes do empacotamento

- `Regra operacional`: antes de gerar `import_file.xml` ou outro pacote importavel, diferenciar explicitamente `XML bem-formado` de `objeto provavelmente importavel`.
- `Regra operacional`: `XML bem-formado` cobre parse XML, raiz fechada, `CDATA` encerrado, `lastUpdate` conferido quando aplicavel e ausencia de truncamento evidente.
- `Regra operacional`: quando um bloco `CDATA` carregar `Source` GeneXus literal, entidades XML escapadas como `&amp;`, `&quot;`, `&gt;` e `&lt;` dentro do código salvo devem ser tratadas como erro de materialização; antes do empacotamento, reler o bloco e bloquear o artefato se esses spellings aparecerem onde o código deveria permanecer literal.
- `Regra operacional`: `objeto provavelmente importavel` exige também um gate mínimo de sanidade do `Source` GeneXus para objetos cujo comportamento principal vive no `Source`, especialmente `Procedure`, `DataProvider` e casos comparaveis.
- `Regra operacional`: o gate mínimo de sanidade do `Source` deve conferir pelo menos o balanceamento estrutural básico dos pares realmente tocados pela mudanca, como `Sub/EndSub`, `For each/EndFor`, `Do Case/EndCase` e `If/EndIf`.
- `Regra operacional`: quando a mudanca inserir ou mover bloco em `Source` grande, revisar o trecho alterado junto com algumas linhas antes e depois, incluindo os fechamentos ao redor.
- `Regra operacional`: em objeto grande ou sensivel, preferir delta mínimo, sintaxe conservadora e reaproveitamento do estilo sintatico já dominante no próprio objeto.
- `Regra operacional`: se o bloco novo tiver analogia local clara no mesmo objeto, comparar com esse bloco irmao para copiar forma sintatica, distribuicao de quebras de linha e padrão de fechamento, sem transformar o estilo local em regra funcional universal.
- `Regra operacional`: quando a mudanca inserir novo `Case` em um `Do Case` de `Source` que dependa materialmente de `parm(...)`, revisar os `Case` irmaos do mesmo bloco antes de aceitar o delta.
- `Regra operacional`: nessa revisao de `Do Case`, conferir se os parâmetros de entrada relevantes, esperados pelo padrão local do bloco, aparecem de forma coerente no novo ramo; ausencia de parâmetro comparavelmente esperado exige justificativa explicita.
- `Regra operacional`: se o novo `Case` divergir do padrão local dos ramos irmaos sem justificativa explicita, bloquear o delta em vez de aceitar branch hardcoded ou sustentado apenas por analogia fraca.
- `Regra operacional`: sinais como `elseif`, `iif(...)`, condição nova excessivamente densa ou chamada de funcao/procedure dentro da condição devem entrar como alerta consultivo de conservadorismo, não como erro funcional universal.
- `Regra operacional`: quando um alerta consultivo aparecer em trecho novo e a base metodologica não sustentar claramente aquela forma, preferir reescrever para a forma mais conservadora documentada antes do empacotamento.
- `Regra operacional`: falha em balanceamento estrutural básico do `Source` bloqueia empacotamento.
- `Regra operacional`: alerta consultivo isolado não bloqueia automaticamente, mas deve ser registrado como risco e resolvido quando o trecho ainda estiver sustentado apenas por plausibilidade.
- `Regra operacional`: cheque automatizado leve de `Source`, quando existir no repositório, deve ser tratado como apoio de triagem e não como prova completa de importabilidade.
- `Regra operacional`: o cheque automatizado leve de `Source` no repositório é `scripts/Test-GeneXusSourceSanity.ps1` (base do wrapper local `Test-*KbSourceSanity.ps1`); recebe `-InputPath` (alias `-Path`) e emite JSON por padrão no stdout, sem `-AsJson` — passar `-AsJson` a esse motor é erro de binding em runtime, sintaticamente valido e portanto invisivel ao parse.
- `Regra operacional`: o `Test-GeneXusSourceSanity.ps1` é **type-aware** para partes que não devem ter conteúdo em certos tipos de objeto. Um `Procedure` (`type 84a12160-...`) com a parte `Conditions` (`763f0d8b-...`) não-vazia recebe o finding `procedural-in-conditions` (`fail`) e bloqueia o empacotamento, porque `Procedure` não tem filtro de `Conditions` (predicados vivem em `For Each ... Where`, parte `528d1c06`) e código ali causa `src0055` no import (`confirmado-import` GX18U13 + WorkWithPlus_Web 16.0.3.1; `confirmado-acervo` 0/milhares de Procedures no FabricaBrasil). A regra usa um mapa extensível `objectType→partes-proibidas` (`$script:ForbiddenNonEmptyParts`, só `Procedure` hoje); `WebPanel`/`Prompt`/`Selection List`, onde `Conditions` é filtro legítimo, ficam fora, e `Data Selector` **não** entra (tem `Conditions` própria). Self-test `scripts/Test-GeneXusSourceSanitySelfTest.ps1`.

### Gate de variáveis tocadas por delta de `Source`

- `Evidência direta`: em corpus real de KB GeneXus de producao, a edicao combinada de `Source` e `Variables` apareceu como caso operacional sensivel: `Source` pode usar tabs enquanto a estrutura XML de `Variables` usa espacos, e o arquivo pode ser CRLF conforme `.gitattributes` da pasta paralela.
- `Evidência direta`: no mesmo corpus, blocos `<Variable>` observados usam familias variadas de tipagem (`idBasedOn=Domain:*`, `idBasedOn=Attribute:*`, `ATTCUSTOMTYPE=bas:*`, `sdt:*`, `exo:*`, `bc:*`, `ext:*`) e também existem formas legadas sem `idBasedOn`/`ATTCUSTOMTYPE`.
- `Regra operacional`: quando o delta inserir ou alterar código em `Source` e declarar novas variáveis, a transicao `Source -> Variables` deve ser declarada como bloco adjacente justificado antes do empacotamento.
- `Regra operacional`: o agente deve preservar separadamente o estilo textual observado no `Source` e na estrutura `Variables`; não normalizar tabs, espacos, EOL ou CDATA fora do delta funcional aprovado.
- `Regra operacional`: variável nova não deve ser montada a partir de lista universal de propriedades obrigatórias; deve clonar forma comparavel do próprio objeto, depois do mesmo tipo de objeto na KB, e só por último de molde sanitizado.
- `Regra operacional`: validação mecanica ampla sobre todas as variáveis legadas deve ser consultiva, porque o acervo real contem formas raras e historicas; bloqueio antes do pacote deve focar variáveis declaradas como novas ou tocadas pelo delta.
- `Regra operacional`: usar `scripts/Test-GeneXusObjectVariableDelta.ps1 -InputPath <xml> -VariableName <nomes> -AsJson` para checar variáveis novas/tocadas. `status=fail` bloqueia o pacote; `status=warn` exige revisao conservadora e justificativa antes de prosseguir.
- `Regra operacional`: não validar ingenuamente toda ocorrência textual `&X` no `Source` contra `<Variables>`; entidades XML, variáveis especiais e formas geradas produzem falsos positivos. A validação deve focar os nomes do delta e o trecho funcional alterado.

### Baseline oficial conhecido em revisao e sanity

- `Regra operacional`: em objeto legado, separar explicitamente duas decisoes independentes: `sanity absoluto do artefato atual` e `comparacao contra baseline oficial`.
- `Regra operacional`: `sanity absoluto` responde se o artefato atual está aceitavel por si só, independentemente do histórico.
- `Regra operacional`: `comparacao contra baseline oficial` responde apenas se o delta atual preservou, piorou, melhorou ou não foi comparado contra o estado oficial anterior da KB.
- `Regra operacional`: o baseline valido para essa comparacao deve ser oficial e rastreavel, como snapshot oficial em `ObjetosDaKbEmXml`, export oficial comparavel da IDE ou outro artefato explicitamente qualificado como baseline oficial pela trilha.
- `Regra operacional`: copia intermediaria de trabalho, XML contaminado, pacote provisório, export informal ou delta local ainda não devolvido oficialmente pela KB não valem como baseline oficial.
- `Regra operacional`: a classificação comparativa canonica deve usar exatamente um destes estados: `same as official baseline`, `worse than official baseline`, `better than official baseline` ou `no official baseline compared`.
- `Regra operacional`: `same as official baseline` não significa `bom`; significa apenas que o delta não introduziu diferenca relevante naquela dimensao comparada.
- `Regra operacional`: `worse than official baseline` indica regressao introduzida pelo delta atual naquela dimensao comparada, salvo reclassificacao posterior por ruido conhecido explicitamente documentado.
- `Regra operacional`: `better than official baseline` indica melhoria em relacao ao baseline oficial, mas não dispensa verificar se essa melhoria fazia parte do pedido ou se virou `mudanca extra nao pedida`.
- `Regra operacional`: `no official baseline compared` deve ser usado quando não houver baseline oficial confiavel, quando o baseline não tiver sido efetivamente aberto, ou quando a comparacao segura ainda não puder ser concluida.
- `Regra operacional`: falha em `sanity absoluto` bloqueia consolidacao e empacotamento mesmo que o resultado comparativo seja `same as official baseline` ou `better than official baseline`.
- `Regra operacional`: comparacao contra baseline não absolve defeito herdado; se o artefato atual falhar em sanidade, o resultado deve continuar reprovado, ainda que o problema já existisse no baseline oficial.
- `Regra operacional`: quando o achado comparativo indicar problema herdado sem piora do delta, registrar isso como ressalva ou risco herdado, e não como regressao introduzida pelo delta.
- `Regra operacional`: antes de concluir `worse than official baseline`, filtrar ruido já conhecido e explicitamente documentado pela trilha, para não promover diferenca não funcional a regressao real.
- `Regra operacional`: quando a revisao estiver organizada por blocos, a comparacao contra baseline deve priorizar primeiro o `bloco primario` tocado pelo delta e abrir bloco adjacente apenas se a dependencia funcional exigir.

### Conferencia auditavel de `lastUpdate`

- `Regra operacional`: gravou ou regravou XML local de objeto, releia o arquivo salvo antes de seguir.
- `Regra operacional`: a conferencia mínima obrigatória é: cabecalho final lido, `lastUpdate` confirmado e decisão registrada entre `objeto alterado` versus `objeto nao alterado`.
- `Regra operacional`: objeto realmente alterado deve sair com `lastUpdate` calculado por `max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)` quando houver baseline oficial; a margem padrão e 60 segundos.
- `Regra operacional`: objeto reenviado apenas por dependencia ou composicao de pacote deve preservar o `lastUpdate` oficial do XML da KB.
- `Regra operacional`: empacotamento não deve prosseguir enquanto o `lastUpdate` do arquivo final não tiver sido conferido no próprio XML salvo.
- `Regra operacional`: quando o empacotamento usar `scripts/Build-GeneXusImportFileEnvelope.ps1`, informar obrigatoriamente `-AcervoPath <ObjetosDaKbEmXml>`; o script sempre executa a coerencia frente-vs-acervo antes de gravar o pacote: gate de `lastUpdate` e bloqueio de `Object/@type` divergente quando o XML de entrada e o acervo compartilham o mesmo `guid`. Objetos modificados devem ser declarados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids` para transformar a conferencia de `lastUpdate` em bloqueio mecanico antes da gravacao do pacote.
- `Regra operacional`: quando o empacotamento usar `scripts/New-XpzImportPackage.ps1` (montagem por frente), o gate de drift frente-vs-acervo (`scripts/Test-GeneXusFrontAcervoDrift.ps1`, 9-FD) é executado sempre antes do empacotamento (fail-closed): `-AcervoPath` é opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` é resolvido automaticamente; sem acervo resolvivel o empacotamento é bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`). O gate compara contra o acervo (retrato do último sync), não contra a KB viva — quando houver suspeita de acervo defasado, ressincronizar antes de empacotar. Além de `lastUpdate`, o 9-FD bloqueia `front-object-type-drift` quando frente e acervo têm o mesmo `guid` e `Object/@type` diferente; esse caso exige decisao humana e não deve ser resolvido automaticamente por copia/bump.
- `Regra operacional`: para apenas re-carimbar (bump) o `lastUpdate` de um XML da frente JÁ editado (rodada 2+), sem copiar do acervo nem aplicar delta, usar `scripts/Set-GeneXusXmlLastUpdate.ps1` (`-InputPath`, `-BaselineXmlPath` opcional, `-DryRun`, `-AsJson`); recalcula `max(UtcNow + margem, baseline + margem)` e grava in-place com backup e validação de well-formedness, em vez de busca-e-troca manual do atributo. Sem `-BaselineXmlPath`, o baseline é o próprio arquivo — suficiente para ficar acima do objeto vivo na KB em rodadas subsequentes, já que o GeneXus preserva o `lastUpdate` importado como Modified Date; para garantir acima do acervo, apontar `-BaselineXmlPath` para o XML oficial em `ObjetosDaKbEmXml`.

## Topologia operacional do workspace

- `Regra operacional`: a pasta nativa da KB é area proibida para gravacao por agentes; leitura é permitida apenas quando o fluxo operacional explicito realmente exigir.
- `Regra operacional`: `ObjetosDaKbEmXml` é o snapshot oficial da KB e deve ser tratado como somente leitura para agentes.
- `Regra operacional`: agente nunca pode criar, alterar, mover, renomear ou sobrescrever arquivos em `ObjetosDaKbEmXml`.
- `Regra operacional`: a única origem oficial de atualizacao de `ObjetosDaKbEmXml` é o script `.ps1` do fluxo de sincronizacao alimentado por `XPZ` exportado pela IDE.
- `Regra operacional`: `KbIntelligence` é a pasta do índice SQLite derivado e regeneravel a partir de `ObjetosDaKbEmXml`; ela serve para triagem e não substitui o snapshot oficial.
- `Regra operacional`: XML gerado, clonado ou ajustado localmente nunca deve ser tratado como se já fosse snapshot oficial da KB.
- `Regra operacional` (anti-padrão "editar acervo esperando que o pacote pegue"): editar `ObjetosDaKbEmXml` com a intencao de que o próximo empacotamento use essa versão é um anti-padrao. O motor de empacotamento le os XMLs da subpasta ativa da frente (`ObjetosGeradosParaImportacaoNaKbNoGenexus/<Frente>/`), nunca do acervo. A edicao do acervo não afeta o conteúdo do pacote; a única forma de influenciar o empacotamento é editar o XML na pasta da frente. O gate 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`, sempre executado pelo wrapper `New-XpzImportPackage.ps1` em modo fail-closed: `-AcervoPath` opcional, acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` auto-resolvido quando omitido, empacotamento bloqueado sem acervo resolvivel) detecta drift de `lastUpdate` e drift de `Object/@type` por mesmo `guid` entre frente e acervo, mas o anti-padrao conceitual permanece mesmo quando esses sinais não aparecem: o acervo é fonte normativa, não area de rascunho. Quem precisa alterar um objeto para importação deve copiar do acervo para a frente, editar a copia e, se necessário, bump o `lastUpdate`; nunca editar o acervo diretamente. Para drift de `lastUpdate`, copiar e bump pode ser feito com `Copy-GeneXusAcervoToFront.ps1` (`-FrontFolder <pasta-da-frente> -AcervoFolder <ObjetosDaKbEmXml>`). Para `front-object-type-drift`, não copiar/bump automaticamente: decidir humanamente se o XML correto é o da frente, o do acervo ou se houve erro de geração/seleção. Para seed inicial de objeto ainda ausente na frente, informar alvo explicito por `-ObjectList`, `-ObjectNames` ou `-ObjectGuids`; frente vazia sem alvo explicito continua `not-applicable`. A pasta da frente deve já existir, aberta por `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` para retomar); nunca criá-la manualmente — `Copy-GeneXusAcervoToFront.ps1` e os gates 9-* apenas populam ou inspecionam uma frente existente.
- `Regra operacional`: `ObjetosGeradosParaImportacaoNaKbNoGenexus` é a area de trabalho para XMLs gerados, clonados, ajustados ou preservados para importação manual na IDE.
- `Regra operacional`: `PacotesGeradosParaImportacaoNaKbNoGenexus` é a area de saida para `import_file.xml` e demais pacotes gerados localmente.
- `Regra operacional`: `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` são areas gerenciadas por agente, não pastas de deposito do usuário; XML de exemplo, referencia ou template colocado ali fora do fluxo controlado deve bloquear o empacotamento ate ser tratado explicitamente.
- `Regra operacional`: na area ativa de `ObjetosGeradosParaImportacaoNaKbNoGenexus`, os XMLs candidatos do lote devem ficar juntos na raiz da subpasta ativa da frente, sem subpastas por tipo, salvo regra local explicita do repositório.
- `Regra operacional`: agente nunca deve criar subpastas por tipo automaticamente em `ObjetosGeradosParaImportacaoNaKbNoGenexus`.
- `Regra operacional`: agente nunca deve mover XMLs para `ArquivoMorto` sem pedido explicito do usuário.
- `Regra operacional`: quando houver conflito entre habito anterior do agente e documentação local do repositório, a documentação local prevalece.
- `Regra operacional`: ao referenciar qualquer objeto GeneXus do acervo local, identificar sempre `tipo + nome`; nunca operar apenas pelo nome isolado.
- `Regra operacional`: o tipo do objeto determina a pasta esperada no acervo (`Procedure`, `Transaction`, `WebPanel`, `Attribute` e correlatas) e deve ser confirmado antes de qualquer leitura, comparacao, clonagem, ajuste ou empacotamento.
- `Regra operacional`: o mesmo nome pode existir simultaneamente em tipos diferentes; antes de agir sobre um objeto, confirmar em qual pasta o arquivo realmente existe no acervo local.
- `Regra operacional`: agente não deve inferir tipo de objeto apenas por contexto funcional, nome parecido ou conversa anterior; a pasta real é a evidência direta mínima para localizar o artefato correto.
- `Regra operacional`: ao concluir o setup inicial da pasta paralela da KB, o agente deve distinguir explicitamente `estrutura pronta` de `snapshot oficial ainda nao materializado`.
- `Regra operacional`: ao concluir o setup inicial, o agente deve oferecer `A)` exportação de `.xpz` full pela IDE para `XpzExportadosPelaIDE` ou `B)` geração do `.xpz` full a partir da pasta nativa da KB via trilha `MSBuild`, seguida de materialização dos XMLs.
- `Regra operacional`: no fechamento do setup inicial, `A)` deve ser apresentado como caminho preferencial e normalmente mais rápido; `B)` deve ser apresentado como caminho possível, porém mais lento por depender da trilha via `MSBuild`.

## Compatibilidade de `Source`

- `Regra operacional`: validar compatibilidade de função, assinatura e tipo primeiro pela metodologia desta trilha e pela semantica GeneXus consolidada em `nexa`; a KB local entra como reforco apenas quando os exemplos metodologicos não cobrirem o caso.
- `Regra operacional`: não exigir busca ampla no acervo inteiro da KB como padrão para validar um `Source`; se a base metodologica já cobrir o padrão, ela prevalece.
- `Regra operacional`: quando a cobertura vier apenas de melhor esforco, declarar explicitamente que a compatibilidade não está garantida e elevar o risco metodologico.

### Gramatica operacional para `Procedure` de relatório

- `Regra operacional`: em `Procedure` de relatório simples, o fluxo primario deve partir de molde sanitizado documentado da trilha antes de escalar para XML real comparavel.
- `Regra operacional`: a cobertura primaria barata desta trilha vale para relatório simples das familias `F2` e `F3`, desde que o shape completo esteja documentado em molde sanitizado suficiente e marcado como `molde pronto` na trilha.
- `Regra operacional`: em `Procedure` de relatório, separar sempre tres camadas antes de corrigir ou gerar: `Source`, `Rules` e layout.
- `Regra operacional`: `Source` é a camada de fluxo procedural; nela entram `Header`, `Footer`, `For each`, `print printBlock...`, `Output_file` e lógica de preparacao de variáveis.
- `Regra operacional`: `Rules` é a camada de assinatura/regra; nela entram `parm(...)` e regras próprias dessa camada, não `print`, `For each`, `Header`, `Footer` nem shape de layout.
- `Regra operacional`: o layout do `Part` `c414ed00-8cc4-4f44-8820-4baf93547173` é a camada estrutural de `Bands`, `PrintBlock`, `ReportLabel` e `ReportAttribute`; não deve receber pseudo-`Source` procedural.
- `Regra operacional`: `RPT_INTERNAL_NAME`, identificadores de `PrintBlock` e referencias usadas em `print printBlock...` devem permanecer coerentes entre `Source` e layout.
- `Regra operacional`: antes de empacotar `Procedure` de relatório, tratar a coerência `Source <-> layout` como gate bloqueante: se houver `print printBlock...` no `Source`, o layout deve materializar `Bands` com `PrintBlock` correspondente e `RPT_INTERNAL_NAME` coerente; ausencia dessa correspondencia bloqueia o pacote.
- `Regra operacional`: em relatório simples, a falta de XML real da KB não bloqueia o primeiro prototipo quando a trilha já oferecer molde sanitizado canonico suficiente.
- `Regra operacional`: escalar para XML real comparavel apenas quando o pedido fugir da cobertura simples, quando a tentativa inicial mais um único corretivo estrutural curto falharem, ou quando surgir sinal de dialeto/localismo da KB.
- `Regra operacional`: em `Procedure` de relatório, `;` faltando em `Rules` deve ser tratado como erro da camada `Rules`; `;` rejeitado em `Source` deve ser tratado como erro de dialeto/sintaxe de `Source`.
- `Regra operacional`: não inventar `GXML`, controles, propriedades ou shape alternativo para o `Part c414...` sem ancoragem em molde documentado ou XML real comparavel.

### Protocolo geral de revisao por blocos

- `Regra operacional`: em tipos heterogeneos cobertos por esta base, a revisao fina deve declarar antes qual é o `bloco primario` do sintoma atual.
- `Regra operacional`: `bloco adjacente` é apenas o bloco adicional aberto por dependencia funcional explicita com o `bloco primario`; ele não deve ser aberto por curiosidade, inseguranca ou "garantia".
- `Regra operacional`: toda `transicao justificada` entre blocos deve ser nomeada no raciocinio e no handoff, por exemplo `Rules/parm -> Variables` ou `events -> variables`.
- `Regra operacional`: o `criterio de parada` da revisao por blocos é simples: parar a expansao quando a hipotese já estiver sustentada; não reabrir o objeto inteiro por reflexo.
- `Regra operacional`: o `escopo da conclusao` deve ser declarado no menor nível funcional que a evidencia sustenta; quando o tipo tiver mais de um contexto de execução relevante, explicitar também esse contexto.

### Revisao por blocos em `Procedure`

- `Regra operacional`: em `Procedure`, não presumir `Source` como bloco inicial universal; a revisao fina deve declarar antes qual é o bloco primario do sintoma atual.
- `Regra operacional`: os blocos canonicos de revisao em `Procedure` são `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container` e, quando aplicavel, `Report layout`.
- `Regra operacional`: `Source` cobre fluxo procedural, filtros, atribuicoes, navegacao, condições e chamadas feitas no corpo.
- `Regra operacional`: `Rules/parm` cobre assinatura declarativa e contrato de parâmetros; não deve ser tratado como prova de call site.
- `Regra operacional`: `Variables` cobre existência, tipo, coerência de nome e classificação de colecao vs simples quando isso for relevante ao caso.
- `Regra operacional`: `Calls and dependencies` cobre procedures chamadas, objetos auxiliares e a cadeia funcional imediata necessária para justificar a conclusao.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: `Report layout` só existe como bloco próprio quando a `Procedure` for de relatório e houver `Bands`, `PrintBlock`, `ReportLabel` ou `ReportAttribute` em jogo.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do objeto.
- `Regra operacional`: em `Procedure`, as transicoes mais comuns e justificadas são `Rules/parm -> Variables`, `Rules/parm -> Source`, `Source -> Variables`, `Source -> Calls and dependencies` e `Report layout -> Source`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Procedure` inteira por reflexo.
- `Regra operacional`: quando `Source` de `Procedure` contiver `New`, validar os alvos gravaveis antes de empacotar com `scripts\Test-GeneXusNewWritableTargets.ps1`; atributo visivel, formula, descritivo extendido ou derivado por subtipo não é automaticamente gravavel no `New`.

### Revisao por blocos em `DataSelector`

- `Regra operacional`: em `DataSelector`, não presumir que XML pequeno equivale a revisao simples; a revisao fina deve separar explicitamente contrato de selecao, lógica de filtro, dependencias semanticas e contexto de navegacao.
- `Regra operacional`: os blocos canonicos de revisao em `DataSelector` são `Selection contract`, `Selection logic and conditions`, `Attribute and function dependencies`, `Navigation context` e `Identity and container`.
- `Regra operacional`: `Selection contract` cobre assinatura de entrada, parâmetros, variáveis declarativas e o contrato esperado pelo seletor.
- `Regra operacional`: `Selection logic and conditions` cobre `Condition`, filtros, expressoes, critérios de selecao e a lógica efetiva que decide o conjunto retornado.
- `Regra operacional`: `Attribute and function dependencies` cobre atributos referenciados, funções chamadas, nomes usados em filtro e qualquer dependencia semantica que precise existir de verdade na KB.
- `Regra operacional`: `Navigation context` cobre base implicita ou explicita da selecao, contexto transacional/fisico e a moldura funcional em que o seletor opera.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `DataSelector`.
- `Regra operacional`: em `DataSelector`, as transicoes mais comuns e justificadas são `Selection contract -> Selection logic and conditions`, `Selection logic and conditions -> Attribute and function dependencies`, `Attribute and function dependencies -> Selection logic and conditions`, `Selection logic and conditions -> Navigation context`, `Navigation context -> Selection logic and conditions`, `Selection contract -> Attribute and function dependencies`, `Identity and container -> Selection contract` e `Identity and container -> Navigation context`.
- `Regra operacional`: usar `Selection contract` como bloco inicial quando a duvida nascer de parâmetros, assinatura de entrada, variável de controle ou diferenca entre o que o seletor espera receber e o que o caso parece fornecer.
- `Regra operacional`: usar `Selection logic and conditions` como bloco inicial quando o sintoma falar de `Condition`, filtro, expressao, critério de selecao, recorte de conjunto ou comportamento lógico do seletor.
- `Regra operacional`: usar `Attribute and function dependencies` como bloco inicial quando a pergunta falar de atributo citado, função usada no filtro, referencia quebrada, nome não resolvido ou dependencia semantica inexistente na KB.
- `Regra operacional`: usar `Navigation context` como bloco inicial quando a duvida falar de base implicita, contexto transacional/fisico, encaixe da selecao no modelo ou coerência do seletor com a moldura de navegacao em volta.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural ou risco de estar olhando o seletor errado.
- `Regra operacional`: em `DataSelector`, parâmetro não prova filtro aplicado, e filtro não prova existência real de atributo ou função no destino; manter essas camadas separadas ate a evidencia permitir unificacao controlada.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataSelector` inteiro por reflexo.

### Revisao por blocos em `DataProvider`

- `Regra operacional`: em `DataProvider`, não presumir `Source` como bloco inicial universal; a revisao fina deve declarar antes qual é o bloco primario do sintoma atual.
- `Regra operacional`: os blocos canonicos de revisao em `DataProvider` são `Output structure`, `Source`, `Navigation context`, `Calls and dependencies` e `Identity and container`.
- `Regra operacional`: `Output structure` cobre grupos, colecao vs simples, aninhamento, nomes de nos, cardinalidade e coerência estrutural do retorno prometido.
- `Regra operacional`: `Source` cobre lógica de montagem, atribuicoes, blocos, `For each`, condições, calculos e preenchimento dos nos de saida.
- `Regra operacional`: `Navigation context` cobre base transacional implicita ou declarada, contexto de navegacao e ambiguidade de busca que afetem o `DataProvider`.
- `Regra operacional`: `Calls and dependencies` cobre `SDT`, `BC`, `Transaction`, `Procedure`, objetos auxiliares e a cadeia funcional imediata necessária para justificar a conclusao.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do objeto.
- `Regra operacional`: em `DataProvider`, as transicoes mais comuns e justificadas são `Output structure -> Source`, `Source -> Navigation context`, `Source -> Calls and dependencies`, `Navigation context -> Source` e `Calls and dependencies -> Output structure`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataProvider` inteiro por reflexo.

### Revisao por blocos em `API`

- `Regra operacional`: em `API`, não presumir leitura centrada em código ou dependencias; a revisao fina deve declarar antes qual é o bloco primario do sintoma atual.
- `Regra operacional`: os blocos canonicos de revisao em `API` são `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract` e `Identity and container`.
- `Regra operacional`: `Service contract` cobre identidade do servico, métodos expostos, assinatura externa e shape publicado no nível do endpoint.
- `Regra operacional`: `Events and orchestration` cobre eventos `.Before/.After`, fluxo interno, validacoes, transformacoes e coordenacao executada pela camada de `API`.
- `Regra operacional`: `Calls and dependencies` cobre `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, `DataProvider` e a cadeia funcional imediata necessária para justificar a conclusao.
- `Regra operacional`: `Data contract` cobre shape de entrada e saida, coerência de tipos, estruturas e mapeamentos entre contrato exposto e dados processados.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do objeto.
- `Regra operacional`: em `API`, as transicoes mais comuns e justificadas são `Service contract -> Data contract`, `Service contract -> Events and orchestration`, `Events and orchestration -> Calls and dependencies`, `Calls and dependencies -> Data contract` e `Data contract -> Calls and dependencies`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir a `API` inteira por reflexo.

### Revisao por blocos em `SDT`

- `Regra operacional`: em `SDT`, não tratar objeto pequeno ou declarativo como leitura monolitica; a revisao fina deve separar explicitamente estrutura interna, tipagem referenciada e metadata externa.
- `Regra operacional`: os blocos canonicos de revisao em `SDT` são `Structure definition`, `Item typing and dependencies`, `External serialization contract`, `Top-level type properties` e `Identity and container`.
- `Regra operacional`: `Structure definition` cobre `Level`, `LevelInfo`, sequência de `Item`, hierarquia, composicao simples vs composta, colecao vs simples e shape interno do `SDT`.
- `Regra operacional`: `Item typing and dependencies` cobre `idBasedOn`, `ATTCUSTOMTYPE`, dominio base, referencia a outro `SDT` e coerência entre papel estrutural do item e tipo declarado.
- `Regra operacional`: `External serialization contract` cobre `ExternalName`, `ExternalNamespace`, `idXmlName`, `idXmlNamespace`, `soaptype`, `idCollectionItemName` e metadata equivalente de serializacao ou integracao.
- `Regra operacional`: `Top-level type properties` cobre propriedades declaradas no nível do próprio objeto `SDT`, especialmente quando expressarem tipagem, comportamento estrutural ou contrato do tipo como um todo, e não de um item específico.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `type`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `SDT`.
- `Regra operacional`: em `SDT`, as transicoes mais comuns e justificadas são `Structure definition -> Item typing and dependencies`, `Structure definition -> External serialization contract`, `Structure definition -> Identity and container`, `Item typing and dependencies -> Structure definition`, `Item typing and dependencies -> External serialization contract`, `Item typing and dependencies -> Identity and container`, `Item typing and dependencies -> Top-level type properties`, `External serialization contract -> Structure definition`, `External serialization contract -> Item typing and dependencies`, `External serialization contract -> Top-level type properties`, `External serialization contract -> Identity and container`, `Top-level type properties -> Item typing and dependencies`, `Top-level type properties -> External serialization contract`, `Top-level type properties -> Identity and container`, `Identity and container -> Structure definition`, `Identity and container -> Item typing and dependencies`, `Identity and container -> Top-level type properties` e `Identity and container -> External serialization contract`.
- `Regra operacional`: usar `Structure definition` como bloco inicial quando o sintoma falar de shape, nível, item ausente, item no lugar errado, colecao vs simples, hierarquia, composicao interna ou regressao estrutural do `SDT`.
- `Regra operacional`: usar `Item typing and dependencies` como bloco inicial quando o sintoma falar de `ATTCUSTOMTYPE`, `idBasedOn`, dominio, tipo invalido, referencia a outro `SDT`, item semanticamente quebrado ou dependencia tipada ausente no destino.
- `Regra operacional`: usar `External serialization contract` como bloco inicial quando o sintoma falar de XML externo, SOAP, namespace, nome externo, nome serializado de item/colecao, contrato publicado ou integracao.
- `Regra operacional`: usar `Top-level type properties` como bloco inicial quando o sintoma falar de propriedade do próprio `SDT`, especialmente tipagem ou comportamento estrutural top-level, sem apontar primeiro para um `Item` específico.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, pasta, módulo, `parent`, `fullyQualifiedName`, clonagem, colisao de identidade ou contexto estrutural do `SDT`.
- `Regra operacional`: em `SDT`, não tratar `ATTCUSTOMTYPE` de item interno e `ATTCUSTOMTYPE` top-level como a mesma camada de evidencia; cada um pede bloco próprio.
- `Regra operacional`: em `SDT`, não tratar `External serialization contract` como prova automática de shape interno correto, e não tratar shape interno correto como prova automática de contrato externo valido.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `shape interno`, `tipagem/dependencia`, `contrato externo`, `propriedade top-level` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `SDT` inteiro por reflexo.

### Revisao por blocos em `Theme`

- `Regra operacional`: em `Theme`, não tratar o objeto como XML visual pequeno autossuficiente; a revisao fina deve separar explicitamente tema-base, grafo de classes, bindings normativos e superficie de simplificacao visual.
- `Regra operacional`: os blocos canonicos de revisao em `Theme` são `Theme core definition`, `Class graph and references`, `Predefined types and style bindings`, `Visual simplification and override surface` e `Identity and container`.
- `Regra operacional`: `Theme core definition` cobre o nucleo declarativo do tema, propriedades centrais, shape do objeto e definicao-base do `Theme`.
- `Regra operacional`: `Class graph and references` cobre a malha de `ThemeClass`, referencias internas entre classes do tema, heranca visual e dependencias entre classes do próprio grafo visual.
- `Regra operacional`: `Predefined types and style bindings` cobre `PredefinedTypes`, `Styles` e os vinculos normativos entre tipos visuais conhecidos do GeneXus e a pilha concreta do tema, incluindo `ThemeClass`, `ThemeColor`, `ColorPalette` e `DesignSystem` quando esse acoplamento estiver materializado no próprio binding do tema.
- `Regra operacional`: `Visual simplification and override surface` cobre simplificacao, override, enxugamento visual e qualquer reducao controlada da superficie do tema depois que o acoplamento visual básico já estiver sustentado.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Theme`.
- `Regra operacional`: em `Theme`, as transicoes mais comuns e justificadas são `Theme core definition -> Class graph and references`, `Theme core definition -> Predefined types and style bindings`, `Theme core definition -> Identity and container`, `Class graph and references -> Predefined types and style bindings`, `Class graph and references -> Visual simplification and override surface`, `Class graph and references -> Identity and container`, `Predefined types and style bindings -> Class graph and references`, `Predefined types and style bindings -> Theme core definition`, `Predefined types and style bindings -> Visual simplification and override surface`, `Predefined types and style bindings -> Identity and container`, `Visual simplification and override surface -> Class graph and references`, `Visual simplification and override surface -> Predefined types and style bindings`, `Visual simplification and override surface -> Theme core definition`, `Visual simplification and override surface -> Identity and container`, `Identity and container -> Theme core definition`, `Identity and container -> Class graph and references`, `Identity and container -> Predefined types and style bindings` e `Identity and container -> Visual simplification and override surface`.
- `Regra operacional`: usar `Theme core definition` como bloco inicial quando o sintoma falar do tema como unidade principal, propriedades centrais, shape do objeto, definicao-base ou configuração global do `Theme`.
- `Regra operacional`: usar `Class graph and references` como bloco inicial quando o sintoma falar de cadeia de `ThemeClass`, referencia entre classes, heranca visual ou quebra no grafo de classes do tema.
- `Regra operacional`: usar `Predefined types and style bindings` como bloco inicial quando o sintoma falar de `PredefinedTypes`, `Styles`, binding entre tipo visual conhecido e a pilha concreta `ThemeClass`/`ThemeColor`/`ColorPalette`/`DesignSystem`, ou mapeamento visual normativo do tema.
- `Regra operacional`: usar `Visual simplification and override surface` como bloco inicial quando o sintoma falar de simplificacao, enxugamento, override, remocao visual ou reducao de superficie depois que a malha básica de classes e bindings já estiver suficientemente sustentada.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, contêiner, clonagem, contexto estrutural ou suspeita de molde/base errada.
- `Regra operacional`: em `Theme`, não tratar `Class graph and references` como prova automática de `PredefinedTypes` e `Styles` corretos, não tratar `Predefined types and style bindings` como prova automática de grafo de classes integro, e não abrir `Visual simplification and override surface` como atalho quando o acoplamento visual básico ainda não foi fechado.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `definicao-base`, `grafo de classes`, `binding visual normativo`, `simplificacao/override` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Theme` inteiro por reflexo.

### Revisao por blocos em `ThemeClass`

- `Regra operacional`: em `ThemeClass`, não tratar o objeto como XML visual pequeno, direto e trivial; a revisao fina deve separar explicitamente superficie direta da classe, cadeia de heranca, marcadores de aplicabilidade e dependencias visuais externas.
- `Regra operacional`: os blocos canonicos de revisao em `ThemeClass` são `Direct class surface`, `Inheritance and parent linkage`, `Theme applicability and internal classification`, `Visual references and external dependencies` e `Identity and container`.
- `Regra operacional`: `Direct class surface` cobre as `Properties` top-level da própria classe, propriedades visuais concretas, shape direto do objeto e o que a classe declara sem mediação por `Part`.
- `Regra operacional`: `Inheritance and parent linkage` cobre `parent`, `parentGuid`, `parentType`, cadeia de heranca visual, classe base, variante derivada e estados visuais como `hover`.
- `Regra operacional`: `Theme applicability and internal classification` cobre marcadores como `ThemeElementThemeTypes`, `ThemeElementInternalType`, escopo de aplicabilidade e classificação interna da classe tematica.
- `Regra operacional`: `Visual references and external dependencies` cobre referencias nominais a cores, imagens, classes auxiliares e outros recursos visuais externos que a leitura da classe dependa de sustentar.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`; em `ThemeClass`, não colapsar automaticamente `parent*` neste bloco quando a evidencia apontar heranca funcional.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa da `ThemeClass`.
- `Regra operacional`: em `ThemeClass`, as transicoes mais comuns e justificadas são `Direct class surface -> Inheritance and parent linkage`, `Direct class surface -> Visual references and external dependencies`, `Direct class surface -> Theme applicability and internal classification`, `Inheritance and parent linkage -> Direct class surface`, `Inheritance and parent linkage -> Visual references and external dependencies`, `Inheritance and parent linkage -> Identity and container`, `Theme applicability and internal classification -> Direct class surface`, `Theme applicability and internal classification -> Inheritance and parent linkage`, `Visual references and external dependencies -> Direct class surface`, `Visual references and external dependencies -> Inheritance and parent linkage`, `Visual references and external dependencies -> Identity and container`, `Identity and container -> Inheritance and parent linkage`, `Identity and container -> Theme applicability and internal classification` e `Identity and container -> Direct class surface`.
- `Regra operacional`: usar `Direct class surface` como bloco inicial quando o sintoma falar de propriedade visual errada, override local, shape direto da classe ou simplificacao pontual da própria `ThemeClass`.
- `Regra operacional`: usar `Inheritance and parent linkage` como bloco inicial quando o sintoma falar de classe base faltante, heranca visual, variante derivada, propagacao de estilo ou quebra de cadeia.
- `Regra operacional`: usar `Theme applicability and internal classification` como bloco inicial quando o sintoma falar de `ThemeElementThemeTypes`, `ThemeElementInternalType`, aplicabilidade web/mobile ou reconhecimento da classe pelo ecossistema visual.
- `Regra operacional`: usar `Visual references and external dependencies` como bloco inicial quando o sintoma falar de cor, imagem, classe auxiliar ou outro recurso visual externo ausente, quebrado ou semanticamente incorreto.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, módulo, contexto estrutural, clonagem ou suspeita de molde/base errada.
- `Regra operacional`: em `ThemeClass`, não tratar `Inheritance and parent linkage` como mero contexto estrutural, e não tratar `Theme applicability and internal classification` como detalhe cosmetico.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `superficie direta`, `heranca`, `aplicabilidade/classificacao`, `dependencia visual externa` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir a `ThemeClass` inteira por reflexo.

### Revisao por blocos em `ThemeColor`

- `Regra operacional`: em `ThemeColor`, não tratar o objeto como cor trivial isolada só porque ele e declarativo e não usa `Part`; a revisao fina deve separar explicitamente identidade nominal, valor direto, encaixe tematico e dependencia de uso visual.
- `Regra operacional`: os blocos canonicos de revisao em `ThemeColor` são `Color identity and naming`, `Direct color value surface`, `Theme applicability and palette coupling`, `Visual references and usage dependencies` e `Identity and container`.
- `Regra operacional`: `Color identity and naming` cobre nome lógico da cor, identidade nominal e papel tematico esperado da cor dentro da familia visual.
- `Regra operacional`: `Direct color value surface` cobre as `Properties` top-level da própria cor, valor serializado, shape direto do objeto e definicao concreta da cor sem mediacao por `Part`.
- `Regra operacional`: `Theme applicability and palette coupling` cobre aplicabilidade tematica, relacao com `Theme`, `ColorPalette`, `DesignSystem` e o encaixe semantico da cor dentro da organizacao visual.
- `Regra operacional`: `Visual references and usage dependencies` cobre consumo da cor por `ThemeClass`, `Theme`, estilos e outros elementos visuais que dependam dessa identidade existir e apontar para o valor esperado.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa de `ThemeColor`.
- `Regra operacional`: em `ThemeColor`, as transicoes mais comuns e justificadas são `Color identity and naming -> Direct color value surface`, `Color identity and naming -> Visual references and usage dependencies`, `Color identity and naming -> Identity and container`, `Direct color value surface -> Color identity and naming`, `Direct color value surface -> Theme applicability and palette coupling`, `Direct color value surface -> Visual references and usage dependencies`, `Theme applicability and palette coupling -> Direct color value surface`, `Theme applicability and palette coupling -> Visual references and usage dependencies`, `Theme applicability and palette coupling -> Identity and container`, `Visual references and usage dependencies -> Direct color value surface`, `Visual references and usage dependencies -> Theme applicability and palette coupling`, `Visual references and usage dependencies -> Color identity and naming`, `Identity and container -> Color identity and naming`, `Identity and container -> Theme applicability and palette coupling` e `Identity and container -> Direct color value surface`.
- `Regra operacional`: usar `Color identity and naming` como bloco inicial quando o sintoma falar de nome de cor errado, colisao nominal, renomeacao, papel semantico ou alias visual inadequado.
- `Regra operacional`: usar `Direct color value surface` como bloco inicial quando o sintoma falar de valor de cor errado, serializacao incorreta, propriedade faltante ou duvida sobre a própria definicao concreta da cor.
- `Regra operacional`: usar `Theme applicability and palette coupling` como bloco inicial quando o sintoma falar de encaixe em tema/paleta, escopo da cor, organizacao tematica ou coerência com a familia visual.
- `Regra operacional`: usar `Visual references and usage dependencies` como bloco inicial quando o sintoma falar de referencia quebrada, consumo incorreto por classe/tema ou impacto em objetos visuais dependentes.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `guid`, `fullyQualifiedName`, módulo, clonagem ou contexto estrutural.
- `Regra operacional`: em `ThemeColor`, não tratar `Color identity and naming` e `Direct color value surface` como a mesma camada de evidencia, e não tratar `Theme applicability and palette coupling` como mero agrupamento decorativo.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade nominal`, `valor direto`, `encaixe tematico`, `dependencia de uso visual` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir `ThemeColor` inteiro por reflexo.

### Revisao por blocos em `ColorPalette`

- `Regra operacional`: em `ColorPalette`, não tratar o objeto como agrupador visual trivial só porque ele e declarativo; a revisao fina deve separar explicitamente identidade da paleta, composicao declarada, acoplamento arquitetural e superficie de uso visual.
- `Regra operacional`: os blocos canonicos de revisao em `ColorPalette` são `Palette identity and naming`, `Palette composition and declared members`, `Theme and design-system coupling`, `Color references and usage surface` e `Identity and container`.
- `Regra operacional`: `Palette identity and naming` cobre nome lógico da paleta, identidade nominal e papel tematico esperado dentro da camada visual.
- `Regra operacional`: `Palette composition and declared members` cobre composicao interna da paleta, itens declarados, ordem/organizacao quando relevante, shape direto do objeto e a lista funcional que a paleta realmente materializa.
- `Regra operacional`: `Theme and design-system coupling` cobre relacao com `Theme`, `DesignSystem` e o encaixe da paleta na arquitetura visual mais ampla.
- `Regra operacional`: `Color references and usage surface` cobre relacao com `ThemeColor` e os consumos visuais dependentes da paleta, inclusive uso por tema, classes e outras camadas visuais.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa de `ColorPalette`.
- `Regra operacional`: em `ColorPalette`, as transicoes mais comuns e justificadas são `Palette identity and naming -> Palette composition and declared members`, `Palette identity and naming -> Color references and usage surface`, `Palette identity and naming -> Identity and container`, `Palette composition and declared members -> Palette identity and naming`, `Palette composition and declared members -> Theme and design-system coupling`, `Palette composition and declared members -> Color references and usage surface`, `Theme and design-system coupling -> Palette composition and declared members`, `Theme and design-system coupling -> Color references and usage surface`, `Theme and design-system coupling -> Identity and container`, `Color references and usage surface -> Palette composition and declared members`, `Color references and usage surface -> Theme and design-system coupling`, `Color references and usage surface -> Palette identity and naming`, `Identity and container -> Palette identity and naming`, `Identity and container -> Theme and design-system coupling` e `Identity and container -> Palette composition and declared members`.
- `Regra operacional`: usar `Palette identity and naming` como bloco inicial quando o sintoma falar de nome da paleta, papel semantico, colisao nominal, alias inadequado ou renomeacao.
- `Regra operacional`: usar `Palette composition and declared members` como bloco inicial quando o sintoma falar de itens da paleta, composicao, shape direto, membro faltante ou organizacao interna da paleta.
- `Regra operacional`: usar `Theme and design-system coupling` como bloco inicial quando o sintoma falar de encaixe com `Theme` ou `DesignSystem`, coerência arquitetural ou posicao da paleta dentro da familia visual.
- `Regra operacional`: usar `Color references and usage surface` como bloco inicial quando o sintoma falar de relacao com `ThemeColor`, consumo visual dependente ou impacto funcional de uso da paleta.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `guid`, `fullyQualifiedName`, módulo, clonagem ou contexto estrutural.
- `Regra operacional`: em `ColorPalette`, não tratar `Palette identity and naming` como prova automática de composicao correta, e não tratar `Theme and design-system coupling` como mero contexto decorativo.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade da paleta`, `composicao declarada`, `acoplamento arquitetural`, `superficie de uso` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir `ColorPalette` inteiro por reflexo.

### Revisao por blocos em `DesignSystem`

- `Regra operacional`: em `DesignSystem`, não tratar o objeto como camada visual genérica ou só como contêiner declarativo; a revisao fina deve separar explicitamente identidade do sistema, tokens/recursos declarados, acoplamento com tema/paleta e superficie de consumo visual.
- `Regra operacional`: os blocos canonicos de revisao em `DesignSystem` são `System identity and naming`, `Design tokens and declared resources`, `Theme and palette coupling`, `Visual rules and consumption surface` e `Identity and container`.
- `Regra operacional`: `System identity and naming` cobre nome lógico do sistema, identidade nominal e papel arquitetural esperado na camada visual.
- `Regra operacional`: `Design tokens and declared resources` cobre tokens, recursos declarados, composicao interna, itens faltantes e o shape funcional do que o `DesignSystem` realmente materializa.
- `Regra operacional`: `Theme and palette coupling` cobre relacao com `Theme`, `ColorPalette` e a coerência arquitetural do encaixe entre essas camadas.
- `Regra operacional`: `Visual rules and consumption surface` cobre regras visuais consumidas por outras camadas, impacto funcional de uso e a superficie em que o sistema realmente irradia efeito visual.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa de `DesignSystem`.
- `Regra operacional`: em `DesignSystem`, as transicoes mais comuns e justificadas são `System identity and naming -> Design tokens and declared resources`, `System identity and naming -> Visual rules and consumption surface`, `System identity and naming -> Identity and container`, `Design tokens and declared resources -> System identity and naming`, `Design tokens and declared resources -> Theme and palette coupling`, `Design tokens and declared resources -> Visual rules and consumption surface`, `Theme and palette coupling -> Design tokens and declared resources`, `Theme and palette coupling -> Visual rules and consumption surface`, `Theme and palette coupling -> Identity and container`, `Visual rules and consumption surface -> Design tokens and declared resources`, `Visual rules and consumption surface -> Theme and palette coupling`, `Visual rules and consumption surface -> System identity and naming`, `Identity and container -> System identity and naming`, `Identity and container -> Theme and palette coupling` e `Identity and container -> Design tokens and declared resources`.
- `Regra operacional`: usar `System identity and naming` como bloco inicial quando o sintoma falar de nome do sistema, papel semantico, colisao nominal, alias inadequado ou renomeacao.
- `Regra operacional`: usar `Design tokens and declared resources` como bloco inicial quando o sintoma falar de tokens, recursos declarados, composicao interna, itens faltantes ou shape funcional do sistema.
- `Regra operacional`: usar `Theme and palette coupling` como bloco inicial quando o sintoma falar de relacao com `Theme` ou `ColorPalette`, coerência arquitetural ou encaixe entre as camadas visuais.
- `Regra operacional`: usar `Visual rules and consumption surface` como bloco inicial quando o sintoma falar de regra visual aplicada, consumo por outras camadas ou impacto funcional de uso do sistema.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `guid`, `fullyQualifiedName`, módulo, clonagem ou contexto estrutural.
- `Regra operacional`: em `DesignSystem`, não tratar `System identity and naming` como prova automática de tokens/recursos corretos, e não tratar `Theme and palette coupling` como mero contexto decorativo.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade do sistema`, `tokens/recursos declarados`, `acoplamento tema/paleta`, `superficie de consumo` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir `DesignSystem` inteiro por reflexo.

### Revisao por blocos em `PackagedModule`

- `Regra operacional`: em `PackagedModule`, não tratar o objeto como contêiner trivial de instalacao; a revisao fina deve separar explicitamente identidade do módulo, fronteira de empacotamento, contexto de instalacao e superficie de dependencia/consumo.
- `Regra operacional`: os blocos canonicos de revisao em `PackagedModule` são `Module identity and naming`, `Packaging boundary and declared members`, `Parent and installation context`, `Dependency and consumption surface` e `Identity and container`.
- `Regra operacional`: `Module identity and naming` cobre nome lógico do módulo, identidade nominal e papel semantico esperado do pacote.
- `Regra operacional`: `Packaging boundary and declared members` cobre fronteira do pacote, membros declarados, composicao interna, itens faltantes e o conjunto funcional que o módulo empacotado realmente delimita.
- `Regra operacional`: `Parent and installation context` cobre relacao com instalacao, `parent` estrutural, contexto do módulo empacotado e o encaixe do objeto na hierarquia em que ele e distribuido.
- `Regra operacional`: `Dependency and consumption surface` cobre dependencias do módulo e a forma como ele e consumido por outros objetos, camadas ou módulos.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa de `PackagedModule`.
- `Regra operacional`: em `PackagedModule`, as transicoes mais comuns e justificadas são `Module identity and naming -> Packaging boundary and declared members`, `Module identity and naming -> Dependency and consumption surface`, `Module identity and naming -> Identity and container`, `Packaging boundary and declared members -> Module identity and naming`, `Packaging boundary and declared members -> Parent and installation context`, `Packaging boundary and declared members -> Dependency and consumption surface`, `Parent and installation context -> Packaging boundary and declared members`, `Parent and installation context -> Dependency and consumption surface`, `Parent and installation context -> Identity and container`, `Dependency and consumption surface -> Packaging boundary and declared members`, `Dependency and consumption surface -> Parent and installation context`, `Dependency and consumption surface -> Module identity and naming`, `Identity and container -> Module identity and naming`, `Identity and container -> Parent and installation context` e `Identity and container -> Packaging boundary and declared members`.
- `Regra operacional`: usar `Module identity and naming` como bloco inicial quando o sintoma falar de nome do módulo, papel semantico, colisao nominal, alias inadequado ou renomeacao.
- `Regra operacional`: usar `Packaging boundary and declared members` como bloco inicial quando o sintoma falar de fronteira do pacote, membros declarados, composicao interna, itens faltantes ou delimitacao funcional do módulo.
- `Regra operacional`: usar `Parent and installation context` como bloco inicial quando o sintoma falar de instalacao, `parent`, contexto hierarquico ou encaixe do módulo empacotado.
- `Regra operacional`: usar `Dependency and consumption surface` como bloco inicial quando o sintoma falar de dependencias do módulo ou da forma como ele e consumido por outras camadas.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `guid`, `fullyQualifiedName`, `moduleGuid`, clonagem ou contexto estrutural.
- `Regra operacional`: em `PackagedModule`, não tratar `Module identity and naming` como prova automática de fronteira de empacotamento correta, e não tratar `Parent and installation context` como mero detalhe administrativo.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade do modulo`, `fronteira de empacotamento`, `contexto de instalacao`, `superficie de dependencia/consumo` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir `PackagedModule` inteiro por reflexo.

### Revisao por blocos em `Image`

- `Regra operacional`: em `Image`, não tratar o objeto como binario isolado ou como lista trivial de itens; a revisao fina deve separar explicitamente identidade do recurso, variantes declaradas, payload binario e referencias externas de tema/idioma.
- `Regra operacional`: os blocos canonicos de revisao em `Image` são `Image identity and naming`, `Image item set and declared variants`, `Binary payload and extraction fidelity`, `Theme and language references` e `Identity and container`.
- `Regra operacional`: `Image identity and naming` cobre nome lógico da imagem, identidade nominal e papel semantico esperado do recurso.
- `Regra operacional`: `Image item set and declared variants` cobre `ImageItem`, variantes, composicao interna, item único vs múltiplos itens e o shape funcional do recurso.
- `Regra operacional`: `Binary payload and extraction fidelity` cobre `base64Binary`, integridade do payload, preservacao do conteúdo e fidelidade de extracao/materializacao.
- `Regra operacional`: `Theme and language references` cobre `ThemeReference`, `LanguageReference` e a relacao da imagem com dependencias externas de apresentacao.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa de `Image`.
- `Regra operacional`: em `Image`, as transicoes mais comuns e justificadas são `Image identity and naming -> Image item set and declared variants`, `Image identity and naming -> Theme and language references`, `Image identity and naming -> Identity and container`, `Image item set and declared variants -> Binary payload and extraction fidelity`, `Image item set and declared variants -> Theme and language references`, `Image item set and declared variants -> Image identity and naming`, `Binary payload and extraction fidelity -> Image item set and declared variants`, `Binary payload and extraction fidelity -> Theme and language references`, `Theme and language references -> Image item set and declared variants`, `Theme and language references -> Image identity and naming`, `Theme and language references -> Identity and container`, `Identity and container -> Image identity and naming`, `Identity and container -> Theme and language references` e `Identity and container -> Image item set and declared variants`.
- `Regra operacional`: usar `Image identity and naming` como bloco inicial quando o sintoma falar de nome da imagem, papel semantico, colisao nominal, alias inadequado ou renomeacao.
- `Regra operacional`: usar `Image item set and declared variants` como bloco inicial quando o sintoma falar de item faltante, múltiplas variantes, composicao do recurso ou shape do `Part` de imagens.
- `Regra operacional`: usar `Binary payload and extraction fidelity` como bloco inicial quando o sintoma falar de `base64Binary` quebrado, binario truncado, corrupcao do conteúdo ou divergencia entre recurso e arquivo extraido.
- `Regra operacional`: usar `Theme and language references` como bloco inicial quando o sintoma falar de tema, idioma, referencia externa ausente ou dependencia de apresentacao incoerente.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `guid`, `fullyQualifiedName`, `moduleGuid`, clonagem ou contexto estrutural.
- `Regra operacional`: em `Image`, não tratar `Image item set and declared variants` como prova automática de payload integro, e não tratar `Binary payload and extraction fidelity` como prova automática de referencia tematica/idiomatica correta.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade da imagem`, `variantes declaradas`, `fidelidade do payload`, `referencias de tema/idioma` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir `Image` inteiro por reflexo.

### Revisao por blocos em `Attribute`

- `Regra operacional`: em `Attribute`, não tratar o objeto como definicao escalar trivial; a revisao fina deve separar explicitamente shape top-level, propriedades semanticas, referencias nominais e contexto estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Attribute` são `Attribute core definition`, `Typing and base linkage`, `Semantic property references`, `Presentation and control semantics` e `Identity and container`.
- `Regra operacional`: `Attribute core definition` cobre o shape top-level do atributo, definicao-base, propriedades centrais e o nucleo estrutural do objeto.
- `Regra operacional`: `Typing and base linkage` cobre `idBasedOn`, dominio base, tipo declarado, ligacao estrutural ao contrato de dados e coerência da base tipada do atributo.
- `Regra operacional`: `Semantic property references` cobre propriedades nominais que apontem para outros atributos ou elementos reais da KB, como `ControlItemDescription` e referencias equivalentes.
- `Regra operacional`: `Presentation and control semantics` cobre propriedades funcionais de exibicao, controle e comportamento serializado do atributo que não sejam mera identidade nem mera tipagem base.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Attribute`.
- `Regra operacional`: em `Attribute`, as transicoes mais comuns e justificadas são `Attribute core definition -> Typing and base linkage`, `Attribute core definition -> Presentation and control semantics`, `Attribute core definition -> Identity and container`, `Typing and base linkage -> Semantic property references`, `Typing and base linkage -> Attribute core definition`, `Typing and base linkage -> Identity and container`, `Semantic property references -> Typing and base linkage`, `Semantic property references -> Presentation and control semantics`, `Semantic property references -> Identity and container`, `Presentation and control semantics -> Semantic property references`, `Presentation and control semantics -> Attribute core definition`, `Presentation and control semantics -> Identity and container`, `Identity and container -> Attribute core definition`, `Identity and container -> Typing and base linkage`, `Identity and container -> Semantic property references` e `Identity and container -> Presentation and control semantics`.
- `Regra operacional`: usar `Attribute core definition` como bloco inicial quando o sintoma falar de shape top-level, definicao do atributo, estrutura-base ou suspeita de objeto malformado.
- `Regra operacional`: usar `Typing and base linkage` como bloco inicial quando o sintoma falar de `idBasedOn`, dominio, tipo do atributo, base tipada ou incoerencia de contrato de dados.
- `Regra operacional`: usar `Semantic property references` como bloco inicial quando o sintoma falar de `ControlItemDescription`, referencia nominal quebrada, atributo inexistente no destino ou dependencia semantica concreta de outro atributo real.
- `Regra operacional`: usar `Presentation and control semantics` como bloco inicial quando o sintoma falar de comportamento funcional serializado, semantica de exibicao, controle associado ou propriedade de apresentacao que afete o uso do atributo.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, contêiner, clonagem ou contexto estrutural do atributo.
- `Regra operacional`: em `Attribute`, não tratar `idBasedOn` como prova automática de fechamento semantico completo, e não tratar propriedade de controle/apresentacao como mero detalhe cosmetico quando ela apontar para outro atributo real.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `definicao-base`, `tipagem/base`, `referencia semantica`, `semantica de controle/apresentacao` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Attribute` inteiro por reflexo.

### Revisao por blocos em `PatternSettings`

- `Regra operacional`: em `PatternSettings`, não tratar o objeto como XML pequeno autossuficiente; a revisao fina deve separar explicitamente registro do pattern, configuração interna, dependencias de contexto e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `PatternSettings` são `Pattern registration and environment fit`, `Internal pattern configuration`, `Context and callable dependencies`, `Security and auxiliary references` e `Identity and container`.
- `Regra operacional`: `Pattern registration and environment fit` cobre existência do pattern no ambiente, aderencia ao pattern alvo, compatibilidade de registro e qualquer sintoma do tipo `pattern nao registrado` ou `was not changed` por falta de encaixe operacional.
- `Regra operacional`: `Internal pattern configuration` cobre o XML interno em `CDATA`, a configuração declarativa do pattern, seus nos, flags, parâmetros e o shape interno da configuração persistida.
- `Regra operacional`: `Context and callable dependencies` cobre `ContextVariable`, `LoadProcedure`, procedures chamadas, contexto funcional exigido pelo pattern e referencias executaveis que precisem existir de verdade no ambiente.
- `Regra operacional`: `Security and auxiliary references` cobre `Security`, referencias auxiliares do pattern e dependencias complementares que não sejam o próprio contexto principal nem o registro base do pattern.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `PatternSettings`.
- `Regra operacional`: em `PatternSettings`, as transicoes mais comuns e justificadas são `Pattern registration and environment fit -> Internal pattern configuration`, `Pattern registration and environment fit -> Context and callable dependencies`, `Pattern registration and environment fit -> Identity and container`, `Internal pattern configuration -> Context and callable dependencies`, `Internal pattern configuration -> Security and auxiliary references`, `Internal pattern configuration -> Pattern registration and environment fit`, `Context and callable dependencies -> Internal pattern configuration`, `Context and callable dependencies -> Security and auxiliary references`, `Context and callable dependencies -> Identity and container`, `Security and auxiliary references -> Context and callable dependencies`, `Security and auxiliary references -> Internal pattern configuration`, `Security and auxiliary references -> Identity and container`, `Identity and container -> Pattern registration and environment fit`, `Identity and container -> Internal pattern configuration`, `Identity and container -> Context and callable dependencies` e `Identity and container -> Security and auxiliary references`.
- `Regra operacional`: usar `Pattern registration and environment fit` como bloco inicial quando o sintoma falar de pattern não registrado, incompatibilidade do ambiente, objeto lido mas não aplicado, `was not changed` ou duvida se o pattern do XML corresponde ao pattern disponível no destino.
- `Regra operacional`: usar `Internal pattern configuration` como bloco inicial quando o sintoma falar de configuração interna do pattern, `CDATA`, flags, shape declarativo, parâmetro persistido ou diferenca de comportamento explicavel pelo conteúdo interno do `PatternSettings`.
- `Regra operacional`: usar `Context and callable dependencies` como bloco inicial quando o sintoma falar de `ContextVariable`, `LoadProcedure`, procedure faltante, dependencia executavel, contexto funcional ou referencia de chamada exigida pelo pattern.
- `Regra operacional`: usar `Security and auxiliary references` como bloco inicial quando o sintoma falar de `Security`, referencia auxiliar, dependencia secundaria do pattern ou configuração complementar fora do contexto principal.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, contêiner, clonagem ou contexto estrutural do `PatternSettings`.
- `Regra operacional`: em `PatternSettings`, não tratar configuração interna em `CDATA` como prova automática de viabilidade operacional, e não tratar erro de registro do pattern como se fosse defeito principal de serializacao.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `registro/encaixe do pattern`, `configuracao interna`, `dependencia de contexto/chamada`, `referencia auxiliar/seguranca` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `PatternSettings` inteiro por reflexo.

### Revisao por blocos em `Folder`

- `Regra operacional`: em `Folder`, não tratar o objeto como caso resolvido apenas por shape mínimo; a revisao fina deve separar explicitamente shape estrutural, contexto pai/modulo, leitura semantica da IDE e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Folder` são `Minimal structural shape`, `Parent and module context`, `IDE semantic reading`, `Identity and naming semantics` e `Identity and container`.
- `Regra operacional`: `Minimal structural shape` cobre o envelope XML mínimo do `Folder`, `Object/@type`, metadados essenciais e a estrutura curta esperada do objeto.
- `Regra operacional`: `Parent and module context` cobre `parent`, `parentGuid`, `parentType`, `moduleGuid` e o encaixe estrutural do `Folder` na hierarquia real do repositorio/modelo.
- `Regra operacional`: `IDE semantic reading` cobre a leitura semantica feita pela IDE/importador, inclusive quando o objeto estruturalmente `Folder` aparecer rotulado como `Category`.
- `Regra operacional`: `Identity and naming semantics` cobre a semantica nominal do objeto, inclusive a diferenca entre nome estrutural do XML, nome exibido e qualquer ambiguidade entre tipo XML e rotulo de UI.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, contêiner estrutural e o risco de estar avaliando o agrupador errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Folder`.
- `Regra operacional`: em `Folder`, as transicoes mais comuns e justificadas são `Minimal structural shape -> Parent and module context`, `Minimal structural shape -> IDE semantic reading`, `Minimal structural shape -> Identity and container`, `Parent and module context -> IDE semantic reading`, `Parent and module context -> Identity and naming semantics`, `Parent and module context -> Identity and container`, `IDE semantic reading -> Identity and naming semantics`, `IDE semantic reading -> Parent and module context`, `IDE semantic reading -> Minimal structural shape`, `Identity and naming semantics -> IDE semantic reading`, `Identity and naming semantics -> Identity and container`, `Identity and naming semantics -> Parent and module context`, `Identity and container -> Minimal structural shape`, `Identity and container -> Parent and module context`, `Identity and container -> IDE semantic reading` e `Identity and container -> Identity and naming semantics`.
- `Regra operacional`: usar `Minimal structural shape` como bloco inicial quando o sintoma falar de envelope, `Object/@type`, shape mínimo, serializacao básica ou suspeita de XML malformado.
- `Regra operacional`: usar `Parent and module context` como bloco inicial quando o sintoma falar de `parent`, `module`, posicao hierarquica, encaixe estrutural ou suspeita de `Folder` no contexto errado.
- `Regra operacional`: usar `IDE semantic reading` como bloco inicial quando o sintoma falar de `Category`, leitura da IDE, rotulo exibido, diferenca entre o que o XML e e o que o importador mostra.
- `Regra operacional`: usar `Identity and naming semantics` como bloco inicial quando o sintoma falar de nome do agrupador, ambiguidade nominal, diferenca entre tipo estrutural e rotulo visual, ou expectativa errada sobre o nome exibido.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `Folder`, não tratar `Category` como tipo rival de envelope XML; ele deve ser lido como rotulo de UI/importador enquanto `Folder` permanece o tipo estrutural XML.
- `Regra operacional`: em `Folder`, não tratar shape mínimo correto como prova automática de leitura semantica identica na IDE; a camada de UI/importador continua separada.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `shape minimo`, `contexto pai/modulo`, `leitura semantica da IDE`, `semantica nominal` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Folder` inteiro por reflexo.

### Revisao por blocos em `Domain`

- `Regra operacional`: em `Domain`, não tratar o objeto como definicao tipada trivial; a revisao fina deve separar explicitamente tipo base, limites/parametros, valores enumerados e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Domain` são `Base type definition`, `Limits and scalar constraints`, `Enumerated values contract`, `Usage-facing semantic contract` e `Identity and container`.
- `Regra operacional`: `Base type definition` cobre o tipo base do dominio, `ATTCUSTOMTYPE` quando aplicavel, a definicao nuclear do `Domain` e a coerência do contrato tipado principal.
- `Regra operacional`: `Limits and scalar constraints` cobre tamanho, precisao, escala, limites, flags e demais parâmetros escalares que modulam o tipo base sem transforma-lo em enumeracao.
- `Regra operacional`: `Enumerated values contract` cobre `IDEnumDefinedValues`, lista de valores, descrição de enumerados e a coerência entre código, descrição e contrato enumerado publicado.
- `Regra operacional`: `Usage-facing semantic contract` cobre a semantica com que o dominio sera consumido por `Attribute`, `SDT`, `Transaction`, `Procedure` ou UI, quando o sintoma falar do papel funcional do dominio e não apenas do seu shape interno.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Domain`.
- `Regra operacional`: em `Domain`, as transicoes mais comuns e justificadas são `Base type definition -> Limits and scalar constraints`, `Base type definition -> Enumerated values contract`, `Base type definition -> Usage-facing semantic contract`, `Base type definition -> Identity and container`, `Limits and scalar constraints -> Base type definition`, `Limits and scalar constraints -> Usage-facing semantic contract`, `Limits and scalar constraints -> Identity and container`, `Enumerated values contract -> Base type definition`, `Enumerated values contract -> Usage-facing semantic contract`, `Enumerated values contract -> Identity and container`, `Usage-facing semantic contract -> Base type definition`, `Usage-facing semantic contract -> Limits and scalar constraints`, `Usage-facing semantic contract -> Enumerated values contract`, `Usage-facing semantic contract -> Identity and container`, `Identity and container -> Base type definition`, `Identity and container -> Limits and scalar constraints`, `Identity and container -> Enumerated values contract` e `Identity and container -> Usage-facing semantic contract`.
- `Regra operacional`: usar `Base type definition` como bloco inicial quando o sintoma falar de tipo base, shape nuclear do dominio, `ATTCUSTOMTYPE`, contrato tipado principal ou suspeita de definicao errada do dominio.
- `Regra operacional`: usar `Limits and scalar constraints` como bloco inicial quando o sintoma falar de tamanho, precisao, escala, limite, flag escalar ou parâmetros numericos/textuais do dominio.
- `Regra operacional`: usar `Enumerated values contract` como bloco inicial quando o sintoma falar de enumeracao, valores permitidos, descrição de valor, código enumerado ou incoerencia na lista publicada de valores.
- `Regra operacional`: usar `Usage-facing semantic contract` como bloco inicial quando o sintoma falar do papel funcional do dominio no consumo por outros objetos, na UI ou no contrato de dados que ele sustenta.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, contêiner, clonagem ou contexto estrutural do dominio.
- `Regra operacional`: em `Domain`, não tratar tipo base correto como prova automática de limites corretos, e não tratar limites corretos como prova automática de contrato enumerado ou de papel semantico adequado no consumo.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `tipo base`, `limites/constraints`, `contrato enumerado`, `contrato semantico de uso` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Domain` inteiro por reflexo.

### Revisao por blocos em `Table`

- `Regra operacional`: em `Table`, não tratar o objeto como bloco físico único de leitura; a revisao fina deve separar explicitamente chave primaria, índices embutidos, acoplamento com `Transaction` e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Table` são `Primary key structure`, `Secondary indexes and embedded index members`, `Transaction coupling and physical context` e `Identity and container`.
- `Regra operacional`: `Primary key structure` cobre composicao da chave primaria, ordem estrutural, membros da chave e coerência do nucleo físico principal da `Table`.
- `Regra operacional`: `Secondary indexes and embedded index members` cobre índices embutidos, membros declarados em índice, ordenacao, cobertura de busca e leitura do `Index` como estrutura interna da `Table`.
- `Regra operacional`: `Transaction coupling and physical context` cobre a reassociacao física da `Table` com a `Transaction` de mesmo nome, o contexto estrutural no destino e a dependencia contextual que não desaparece só porque `parent` nomeado não aparece.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parentGuid`, `moduleGuid` e o risco de estar lendo a `Table` errada no contexto estrutural errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa da `Table`.
- `Regra operacional`: em `Table`, as transicoes mais comuns e justificadas são `Primary key structure -> Secondary indexes and embedded index members`, `Primary key structure -> Transaction coupling and physical context`, `Primary key structure -> Identity and container`, `Secondary indexes and embedded index members -> Primary key structure`, `Secondary indexes and embedded index members -> Transaction coupling and physical context`, `Secondary indexes and embedded index members -> Identity and container`, `Transaction coupling and physical context -> Primary key structure`, `Transaction coupling and physical context -> Secondary indexes and embedded index members`, `Transaction coupling and physical context -> Identity and container`, `Identity and container -> Transaction coupling and physical context`, `Identity and container -> Primary key structure` e `Identity and container -> Secondary indexes and embedded index members`.
- `Regra operacional`: usar `Primary key structure` como bloco inicial quando o sintoma falar de chave, composicao da tabela, atributos-chave, ordem estrutural da chave ou coerência do nucleo físico principal.
- `Regra operacional`: usar `Secondary indexes and embedded index members` como bloco inicial quando o sintoma falar de índice, membro de índice, cobertura de busca, ordenacao, presenca/ausencia de índice ou leitura de `Index` embutido.
- `Regra operacional`: usar `Transaction coupling and physical context` como bloco inicial quando a duvida falar de reassociacao física, relacao com a `Transaction` de mesmo nome, contexto estrutural no destino ou papel da `Table` fora da `Transaction`.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parentGuid`, `moduleGuid`, colisao de identidade ou contexto estrutural.
- `Regra operacional`: em `Table`, `Index` deve ser lido como estrutura embutida da própria `Table` nesta trilha de export, e não como tipo top-level independente na revisao por blocos.
- `Regra operacional`: em `Table`, ausencia de `parent` nomeado não prova autonomia estrutural; a dependencia contextual continua devendo ser lida por `parentGuid`, `moduleGuid` e pelo acoplamento com a `Transaction` de mesmo nome.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `chave primaria`, `indices embutidos`, `acoplamento fisico/contextual` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Table` inteira por reflexo.

### Revisao por blocos em `ExternalObject`

- `Regra operacional`: em `ExternalObject`, não tratar o objeto como contrato externo monolitico; a revisao fina deve separar explicitamente superficie exposta, assinaturas tipadas, metadata de binding nativo e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `ExternalObject` são `External contract surface`, `Method signatures and parameter typing`, `Platform and native binding metadata` e `Identity and container`.
- `Regra operacional`: `External contract surface` cobre nome externo, superficie de metodos/propriedades expostas e o papel funcional publicado pelo wrapper.
- `Regra operacional`: `Method signatures and parameter typing` cobre métodos, parâmetros, retorno, coerência de assinatura e dependencias tipadas como `SDT`, dominios ou tipos auxiliares.
- `Regra operacional`: `Platform and native binding metadata` cobre assembly, biblioteca, metadata de plataforma, binding nativo e o acoplamento técnico específico do `ExternalObject`.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o wrapper errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `ExternalObject`.
- `Regra operacional`: em `ExternalObject`, as transicoes mais comuns e justificadas são `External contract surface -> Method signatures and parameter typing`, `External contract surface -> Platform and native binding metadata`, `External contract surface -> Identity and container`, `Method signatures and parameter typing -> External contract surface`, `Method signatures and parameter typing -> Platform and native binding metadata`, `Method signatures and parameter typing -> Identity and container`, `Platform and native binding metadata -> External contract surface`, `Platform and native binding metadata -> Method signatures and parameter typing`, `Platform and native binding metadata -> Identity and container`, `Identity and container -> External contract surface`, `Identity and container -> Method signatures and parameter typing` e `Identity and container -> Platform and native binding metadata`.
- `Regra operacional`: usar `External contract surface` como bloco inicial quando o sintoma falar do que o objeto expoe, do nome externo, da surface funcional ou do papel do wrapper.
- `Regra operacional`: usar `Method signatures and parameter typing` como bloco inicial quando a duvida falar de método, parâmetro, retorno, tipo quebrado, assinatura incoerente ou dependencia tipada.
- `Regra operacional`: usar `Platform and native binding metadata` como bloco inicial quando o sintoma falar de binding nativo, plataforma, assembly, biblioteca alvo ou metadata técnica específica.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `ExternalObject`, não tratar surface externa publicada como prova automática de assinatura tipada correta, e não tratar metadata de binding nativo como prova automática de contrato funcional bem definido.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `superficie externa`, `assinatura e tipagem`, `binding nativo/plataforma` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `ExternalObject` inteiro por reflexo.

### Revisao por blocos em `UserControl`

- `Regra operacional`: em `UserControl`, não tratar o objeto como controle visual monolitico; a revisao fina deve separar explicitamente contrato do controle, bindings de propriedades/eventos, dependencias runtime e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `UserControl` são `Control contract surface`, `Properties and event bindings`, `Runtime resources and external dependencies` e `Identity and container`.
- `Regra operacional`: `Control contract surface` cobre a interface declarada do controle, o que ele expoe funcionalmente e o shape geral da surface consumida pelo host.
- `Regra operacional`: `Properties and event bindings` cobre propriedades, eventos, parâmetros e o contrato de binding entre o controle e quem o consome.
- `Regra operacional`: `Runtime resources and external dependencies` cobre scripts, assets, recursos auxiliares, dependencias tecnicas e acoplamentos de execução do `UserControl`.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o controle errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `UserControl`.
- `Regra operacional`: em `UserControl`, as transicoes mais comuns e justificadas são `Control contract surface -> Properties and event bindings`, `Control contract surface -> Runtime resources and external dependencies`, `Control contract surface -> Identity and container`, `Properties and event bindings -> Control contract surface`, `Properties and event bindings -> Runtime resources and external dependencies`, `Properties and event bindings -> Identity and container`, `Runtime resources and external dependencies -> Control contract surface`, `Runtime resources and external dependencies -> Properties and event bindings`, `Runtime resources and external dependencies -> Identity and container`, `Identity and container -> Control contract surface`, `Identity and container -> Properties and event bindings` e `Identity and container -> Runtime resources and external dependencies`.
- `Regra operacional`: usar `Control contract surface` como bloco inicial quando o sintoma falar do que o controle expoe, da interface declarada, do papel funcional ou do shape geral do controle.
- `Regra operacional`: usar `Properties and event bindings` como bloco inicial quando a duvida falar de propriedade, evento, parâmetro, binding de uso ou contrato entre host e controle.
- `Regra operacional`: usar `Runtime resources and external dependencies` como bloco inicial quando o sintoma falar de script, asset, recurso externo, dependencia técnica ou acoplamento de execução.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `UserControl`, não tratar contrato declarado do controle como prova automática de binding correto em propriedades/eventos, e não tratar dependencia runtime presente como prova automática de surface funcional coerente.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `contrato do controle`, `bindings de propriedades/eventos`, `dependencias runtime` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `UserControl` inteiro por reflexo.

### Revisao por blocos em `SubTypeGroup`

- `Regra operacional`: em `SubTypeGroup`, não tratar o objeto como agrupamento nominal monolitico; a revisao fina deve separar explicitamente definicao do grupo, mapeamentos de subtype, contrato contextual de uso e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `SubTypeGroup` são `Group definition and member structure`, `Subtype mappings and role assignments`, `Contextual usage contract` e `Identity and container`.
- `Regra operacional`: `Group definition and member structure` cobre composicao do grupo, membros declarados, shape estrutural e integridade do agrupamento.
- `Regra operacional`: `Subtype mappings and role assignments` cobre quem atua como supertipo, quem atua como subtipo e os papeis/mapeamentos internos entre os membros.
- `Regra operacional`: `Contextual usage contract` cobre como o `SubTypeGroup` sustenta uso em `Attribute`, `Transaction` e outros objetos do modelo, sem colapsar isso com a definicao interna do grupo.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o grupo errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `SubTypeGroup`.
- `Regra operacional`: em `SubTypeGroup`, as transicoes mais comuns e justificadas são `Group definition and member structure -> Subtype mappings and role assignments`, `Group definition and member structure -> Contextual usage contract`, `Group definition and member structure -> Identity and container`, `Subtype mappings and role assignments -> Group definition and member structure`, `Subtype mappings and role assignments -> Contextual usage contract`, `Subtype mappings and role assignments -> Identity and container`, `Contextual usage contract -> Group definition and member structure`, `Contextual usage contract -> Subtype mappings and role assignments`, `Contextual usage contract -> Identity and container`, `Identity and container -> Group definition and member structure`, `Identity and container -> Subtype mappings and role assignments` e `Identity and container -> Contextual usage contract`.
- `Regra operacional`: usar `Group definition and member structure` como bloco inicial quando o sintoma falar de composicao do grupo, membros declarados, shape estrutural ou integridade do agrupamento.
- `Regra operacional`: usar `Subtype mappings and role assignments` como bloco inicial quando a duvida falar de supertipo, subtipo, papel de membro ou mapeamento interno.
- `Regra operacional`: usar `Contextual usage contract` como bloco inicial quando o sintoma falar do papel do grupo em `Attribute`, `Transaction` ou outros objetos consumidores do modelo.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `SubTypeGroup`, não tratar composicao do grupo como prova automática de mapeamento correto de papeis, e não tratar uso contextual em outro objeto como prova automática de definicao interna correta.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `definicao do grupo`, `mapeamentos de subtype`, `contrato contextual de uso` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `SubTypeGroup` inteiro por reflexo.

### Revisao por blocos em `File`

- `Regra operacional`: em `File`, não tratar o objeto como recurso monolitico; a revisao fina deve separar explicitamente identidade/surface declarada, fidelidade do payload e contexto de consumo.
- `Regra operacional`: os blocos canonicos de revisao em `File` são `File identity and declared surface`, `Binary or textual payload fidelity`, `References and consumption context` e `Identity and container`.
- `Regra operacional`: `File identity and declared surface` cobre nome do recurso, extensao/logica declarada, papel funcional e a surface top-level do arquivo.
- `Regra operacional`: `Binary or textual payload fidelity` cobre conteúdo materializado, integridade do payload, preservacao de bytes/texto e fidelidade de extracao.
- `Regra operacional`: `References and consumption context` cobre quem consome o `File`, referencias externas, dependencias de runtime e o contexto de uso do recurso.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o arquivo errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `File`.
- `Regra operacional`: em `File`, as transicoes mais comuns e justificadas são `File identity and declared surface -> Binary or textual payload fidelity`, `File identity and declared surface -> References and consumption context`, `File identity and declared surface -> Identity and container`, `Binary or textual payload fidelity -> File identity and declared surface`, `Binary or textual payload fidelity -> References and consumption context`, `Binary or textual payload fidelity -> Identity and container`, `References and consumption context -> File identity and declared surface`, `References and consumption context -> Binary or textual payload fidelity`, `References and consumption context -> Identity and container`, `Identity and container -> File identity and declared surface`, `Identity and container -> Binary or textual payload fidelity` e `Identity and container -> References and consumption context`.
- `Regra operacional`: usar `File identity and declared surface` como bloco inicial quando o sintoma falar do que o arquivo e, do nome do recurso, da extensao lógica ou do papel funcional declarado.
- `Regra operacional`: usar `Binary or textual payload fidelity` como bloco inicial quando a duvida falar de conteúdo materializado, payload, integridade binaria/textual, extracao ou preservacao do conteúdo.
- `Regra operacional`: usar `References and consumption context` como bloco inicial quando o sintoma falar de quem consome o arquivo, referencias externas, dependencia de runtime ou contexto de uso.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `File`, não tratar identidade/surface declarada como prova automática de payload integro, e não tratar payload integro como prova automática de consumo correto no contexto.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `identidade/surface`, `payload`, `contexto de consumo` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `File` inteiro por reflexo.

### Revisao por blocos em `Dashboard`

- `Regra operacional`: em `Dashboard`, não tratar o objeto como composicao visual monolitica; a revisao fina deve separar explicitamente composicao estrutural, widgets com seus bindings, contexto de navegacao/interacao e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Dashboard` são `Dashboard composition and layout`, `Widgets and data bindings`, `Navigation and interaction context` e `Identity and container`.
- `Regra operacional`: `Dashboard composition and layout` cobre seções, blocos visuais, organizacao estrutural e shape composicional do dashboard.
- `Regra operacional`: `Widgets and data bindings` cobre widgets, componentes, bindings de dados, parâmetros e o vinculo entre cada parte visivel e seu dado/fornecedor.
- `Regra operacional`: `Navigation and interaction context` cobre ações, links, drill-down, interacao do usuário e o encaixe funcional do dashboard no fluxo mais amplo.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o dashboard errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Dashboard`.
- `Regra operacional`: em `Dashboard`, as transicoes mais comuns e justificadas são `Dashboard composition and layout -> Widgets and data bindings`, `Dashboard composition and layout -> Navigation and interaction context`, `Dashboard composition and layout -> Identity and container`, `Widgets and data bindings -> Dashboard composition and layout`, `Widgets and data bindings -> Navigation and interaction context`, `Widgets and data bindings -> Identity and container`, `Navigation and interaction context -> Dashboard composition and layout`, `Navigation and interaction context -> Widgets and data bindings`, `Navigation and interaction context -> Identity and container`, `Identity and container -> Dashboard composition and layout`, `Identity and container -> Widgets and data bindings` e `Identity and container -> Navigation and interaction context`.
- `Regra operacional`: usar `Dashboard composition and layout` como bloco inicial quando o sintoma falar de composicao, seções, organizacao visual ou shape estrutural do dashboard.
- `Regra operacional`: usar `Widgets and data bindings` como bloco inicial quando a duvida falar de widget, componente, binding, fonte de dados, parâmetro ou vinculo entre visualizacao e dado.
- `Regra operacional`: usar `Navigation and interaction context` como bloco inicial quando o sintoma falar de ação, link, drill-down, interacao do usuário ou encaixe do dashboard no fluxo.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `Dashboard`, não tratar composicao estrutural como prova automática de binding correto de widget, e não tratar binding de widget como prova automática de navegacao/interacao coerente.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `composicao`, `widgets e bindings`, `navegacao/interacao` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Dashboard` inteiro por reflexo.

### Revisao por blocos em `Stencil`

- `Regra operacional`: em `Stencil`, não tratar o objeto como molde estrutural monolitico; a revisao fina deve separar explicitamente definicao do artefato, parametros/configuracao variável, contexto de consumo por pattern/geracao e identidade estrutural.
- `Regra operacional`: os blocos canonicos de revisao em `Stencil` são `Stencil definition and structural surface`, `Parameters and configurable slots`, `Pattern or generation consumption context` e `Identity and container`.
- `Regra operacional`: `Stencil definition and structural surface` cobre shape do stencil, composicao declarada, estrutura-base e a surface estrutural do artefato.
- `Regra operacional`: `Parameters and configurable slots` cobre parâmetros, pontos variáveis, placeholders e o contrato configuravel do stencil.
- `Regra operacional`: `Pattern or generation consumption context` cobre como o stencil é consumido por pattern, geração ou fluxo dependente, sem colapsar isso com a definicao interna do artefato.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o stencil errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Stencil`.
- `Regra operacional`: em `Stencil`, as transicoes mais comuns e justificadas são `Stencil definition and structural surface -> Parameters and configurable slots`, `Stencil definition and structural surface -> Pattern or generation consumption context`, `Stencil definition and structural surface -> Identity and container`, `Parameters and configurable slots -> Stencil definition and structural surface`, `Parameters and configurable slots -> Pattern or generation consumption context`, `Parameters and configurable slots -> Identity and container`, `Pattern or generation consumption context -> Stencil definition and structural surface`, `Pattern or generation consumption context -> Parameters and configurable slots`, `Pattern or generation consumption context -> Identity and container`, `Identity and container -> Stencil definition and structural surface`, `Identity and container -> Parameters and configurable slots` e `Identity and container -> Pattern or generation consumption context`.
- `Regra operacional`: usar `Stencil definition and structural surface` como bloco inicial quando o sintoma falar de shape do stencil, composicao declarada, estrutura-base ou surface do artefato.
- `Regra operacional`: usar `Parameters and configurable slots` como bloco inicial quando a duvida falar de parâmetro, placeholder, ponto variável ou contrato configuravel.
- `Regra operacional`: usar `Pattern or generation consumption context` como bloco inicial quando o sintoma falar do uso do stencil por pattern, geração ou fluxo dependente.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `Stencil`, não tratar estrutura declarada do artefato como prova automática de parametrizacao correta, e não tratar consumo por pattern/geracao como prova automática de definicao interna coerente.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `definicao estrutural`, `parametros/configuracao`, `consumo por pattern/geracao` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Stencil` inteiro por reflexo.

### Revisao por blocos em `DataStore`

- `Regra operacional`: em `DataStore`, não tratar o objeto como definicao de armazenamento monolitica; a revisao fina deve separar explicitamente definicao do store, configuração operacional e contexto de consumo no modelo.
- `Regra operacional`: os blocos canonicos de revisao em `DataStore` são `Store definition and declared connection surface`, `Configuration parameters and runtime options`, `Model and consumption context` e `Identity and container`.
- `Regra operacional`: `Store definition and declared connection surface` cobre a identidade declarada do store, a surface principal de conexão e o shape estrutural da definicao.
- `Regra operacional`: `Configuration parameters and runtime options` cobre parâmetros, flags, opções e configuração operacional do `DataStore`.
- `Regra operacional`: `Model and consumption context` cobre como o `DataStore` se encaixa no modelo, o papel contextual do store e seu consumo por outros objetos ou pelo runtime.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `parent`, `parentGuid`, `parentType` e `moduleGuid`, além do risco de estar lendo o `DataStore` errado.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `DataStore`.
- `Regra operacional`: em `DataStore`, as transicoes mais comuns e justificadas são `Store definition and declared connection surface -> Configuration parameters and runtime options`, `Store definition and declared connection surface -> Model and consumption context`, `Store definition and declared connection surface -> Identity and container`, `Configuration parameters and runtime options -> Store definition and declared connection surface`, `Configuration parameters and runtime options -> Model and consumption context`, `Configuration parameters and runtime options -> Identity and container`, `Model and consumption context -> Store definition and declared connection surface`, `Model and consumption context -> Configuration parameters and runtime options`, `Model and consumption context -> Identity and container`, `Identity and container -> Store definition and declared connection surface`, `Identity and container -> Configuration parameters and runtime options` e `Identity and container -> Model and consumption context`.
- `Regra operacional`: usar `Store definition and declared connection surface` como bloco inicial quando o sintoma falar do que o store declara ser, da surface de conexão ou do shape principal da definicao.
- `Regra operacional`: usar `Configuration parameters and runtime options` como bloco inicial quando a duvida falar de parâmetro, flag, opção ou configuração operacional.
- `Regra operacional`: usar `Model and consumption context` como bloco inicial quando o sintoma falar do encaixe do store no modelo, no runtime ou no consumo por objetos dependentes.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de objeto errado, `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, contêiner ou risco de clonagem/classificacao equivocada.
- `Regra operacional`: em `DataStore`, não tratar surface declarada como prova automática de configuração runtime correta, e não tratar configuração runtime como prova automática de consumo contextual coerente.
- `Regra operacional`: declarar a conclusao no menor nível funcional que a evidencia sustentar: `definicao do store`, `configuracao runtime`, `contexto de consumo` ou `identidade/contêiner`.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataStore` inteiro por reflexo.

### Revisao por blocos em Generator

- `Regra operacional`: `Generator` não deve ser tratado como bloco único; separar definicao do gerador, parâmetros tecnicos, contexto de uso e identidade estrutural.
- `Blocos canonicos`:
  - `Generator definition and declared surface`
  - `Generation options and technical parameters`
  - `Model and target-platform usage context`
  - `Identity and container`
- `Definicao do bloco Generator definition and declared surface`: usar quando a duvida principal for o que o gerador declara ser, sua surface estrutural ou seu papel principal.
- `Definicao do bloco Generation options and technical parameters`: usar quando a duvida principal for parâmetro, flag, opção ou comportamento técnico de geração.
- `Definicao do bloco Model and target-platform usage context`: usar quando a duvida principal for encaixe no modelo, alvo de geração, consumo efetivo ou papel no fluxo.
- `Definicao do bloco Identity and container`: usar quando a duvida principal for `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` ou risco de objeto errado.
- `Regra de condução`: declarar o bloco primario antes da leitura fina e abrir bloco adjacente apenas quando houver dependencia funcional explicita.
- `Transicoes permitidas`:
  - `Generator definition and declared surface -> Generation options and technical parameters`
  - `Generator definition and declared surface -> Model and target-platform usage context`
  - `Generator definition and declared surface -> Identity and container`
  - `Generation options and technical parameters -> Generator definition and declared surface`
  - `Generation options and technical parameters -> Model and target-platform usage context`
  - `Generation options and technical parameters -> Identity and container`
  - `Model and target-platform usage context -> Generator definition and declared surface`
  - `Model and target-platform usage context -> Generation options and technical parameters`
  - `Model and target-platform usage context -> Identity and container`
  - `Identity and container -> Generator definition and declared surface`
  - `Identity and container -> Generation options and technical parameters`
  - `Identity and container -> Model and target-platform usage context`
- `Gatilhos do bloco primario`:
  - `Generator definition and declared surface` para duvida sobre o que o gerador declara ser, seu papel principal ou sua surface estrutural.
  - `Generation options and technical parameters` para duvida sobre parâmetros, flags, opções ou comportamento técnico de geração.
  - `Model and target-platform usage context` para duvida sobre encaixe no modelo, alvo de geração, consumo efetivo ou papel no fluxo.
  - `Identity and container` para duvida sobre `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` e risco de objeto errado.
- `Regra de fronteira`: não colapsar surface declarada, parâmetros tecnicos e contexto de uso como se provassem a mesma coisa.
- `Conclusao`: fechar a resposta no menor nível funcional sustentado pelo XML e pela dependencia realmente aberta: definicao, parâmetros, contexto de uso ou identidade estrutural.

### Revisao por blocos em Language

- `Regra operacional`: `Language` não deve ser tratado como bloco único; separar definicao do idioma, parâmetros tecnicos de localização, contexto de uso e identidade estrutural.
- `Blocos canonicos`:
  - `Language definition and declared surface`
  - `Localization parameters and technical options`
  - `Model and runtime usage context`
  - `Identity and container`
- `Definicao do bloco Language definition and declared surface`: usar quando a duvida principal for o que o objeto declara ser, sua surface estrutural ou seu papel principal.
- `Definicao do bloco Localization parameters and technical options`: usar quando a duvida principal for parâmetro, opção, código, flag ou configuração técnica de localização.
- `Definicao do bloco Model and runtime usage context`: usar quando a duvida principal for encaixe no modelo, consumo efetivo, vinculo com runtime ou papel funcional do idioma.
- `Definicao do bloco Identity and container`: usar quando a duvida principal for `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` ou risco de objeto errado.
- `Regra de condução`: declarar o bloco primario antes da leitura fina e abrir bloco adjacente apenas quando houver dependencia funcional explicita.
- `Transicoes permitidas`:
  - `Language definition and declared surface -> Localization parameters and technical options`
  - `Language definition and declared surface -> Model and runtime usage context`
  - `Language definition and declared surface -> Identity and container`
  - `Localization parameters and technical options -> Language definition and declared surface`
  - `Localization parameters and technical options -> Model and runtime usage context`
  - `Localization parameters and technical options -> Identity and container`
  - `Model and runtime usage context -> Language definition and declared surface`
  - `Model and runtime usage context -> Localization parameters and technical options`
  - `Model and runtime usage context -> Identity and container`
  - `Identity and container -> Language definition and declared surface`
  - `Identity and container -> Localization parameters and technical options`
  - `Identity and container -> Model and runtime usage context`
- `Gatilhos do bloco primario`:
  - `Language definition and declared surface` para duvida sobre o que o objeto declara ser, seu papel principal ou sua surface estrutural.
  - `Localization parameters and technical options` para duvida sobre parâmetros, opções, códigos, flags ou configuração técnica de localização.
  - `Model and runtime usage context` para duvida sobre encaixe no modelo, consumo efetivo, vinculo com runtime ou papel funcional do idioma.
  - `Identity and container` para duvida sobre `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` e risco de objeto errado.
- `Regra de fronteira`: não colapsar surface declarada, parâmetros tecnicos e contexto de uso como se provassem a mesma coisa.
- `Conclusao`: fechar a resposta no menor nível funcional sustentado pelo XML e pela dependencia realmente aberta: definicao, parâmetros, contexto de uso ou identidade estrutural.

### Revisao por blocos em Document

- `Regra operacional`: `Document` não deve ser tratado como bloco único; separar identidade do artefato, payload materializado, contexto de consumo e identidade estrutural.
- `Blocos canonicos`:
  - `Document identity and declared surface`
  - `Materialized content and payload fidelity`
  - `References and functional consumption context`
  - `Identity and container`
- `Definicao do bloco Document identity and declared surface`: usar quando a duvida principal for o que o documento declara ser, sua surface estrutural ou seu papel principal.
- `Definicao do bloco Materialized content and payload fidelity`: usar quando a duvida principal for conteúdo materializado, integridade do payload, preservacao de texto/bytes ou fidelidade de extracao.
- `Definicao do bloco References and functional consumption context`: usar quando a duvida principal for quem consome o documento, vinculos externos, dependencia funcional ou papel no fluxo.
- `Definicao do bloco Identity and container`: usar quando a duvida principal for `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` ou risco de objeto errado.
- `Regra de condução`: declarar o bloco primario antes da leitura fina e abrir bloco adjacente apenas quando houver dependencia funcional explicita.
- `Transicoes permitidas`:
  - `Document identity and declared surface -> Materialized content and payload fidelity`
  - `Document identity and declared surface -> References and functional consumption context`
  - `Document identity and declared surface -> Identity and container`
  - `Materialized content and payload fidelity -> Document identity and declared surface`
  - `Materialized content and payload fidelity -> References and functional consumption context`
  - `Materialized content and payload fidelity -> Identity and container`
  - `References and functional consumption context -> Document identity and declared surface`
  - `References and functional consumption context -> Materialized content and payload fidelity`
  - `References and functional consumption context -> Identity and container`
  - `Identity and container -> Document identity and declared surface`
  - `Identity and container -> Materialized content and payload fidelity`
  - `Identity and container -> References and functional consumption context`
- `Gatilhos do bloco primario`:
  - `Document identity and declared surface` para duvida sobre o que o documento declara ser, nome, papel principal ou surface estrutural.
  - `Materialized content and payload fidelity` para duvida sobre conteúdo materializado, integridade do payload, preservacao de texto/bytes ou fidelidade de extracao.
  - `References and functional consumption context` para duvida sobre quem consome o documento, vinculos externos, dependencia funcional ou papel no fluxo.
  - `Identity and container` para duvida sobre `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` e risco de objeto errado.
- `Regra de fronteira`: não colapsar surface declarada, payload e contexto de consumo como se provassem a mesma coisa.
- `Conclusao`: fechar a resposta no menor nível funcional sustentado pelo XML e pela dependencia realmente aberta: identidade declarada, payload, contexto de consumo ou identidade estrutural.

### Revisao por blocos em DeploymentUnit

- `Regra operacional`: `DeploymentUnit` não deve ser tratado como bloco único; separar definicao da unidade, parâmetros tecnicos, contexto de entrega/uso e identidade estrutural.
- `Blocos canonicos`:
  - `Deployment unit definition and declared surface`
  - `Packaging parameters and technical options`
  - `Runtime or delivery context`
  - `Identity and container`
- `Definicao do bloco Deployment unit definition and declared surface`: usar quando a duvida principal for o que a unidade declara ser, sua surface estrutural ou seu papel principal.
- `Definicao do bloco Packaging parameters and technical options`: usar quando a duvida principal for parâmetro, opção, flag ou configuração técnica de empacotamento/entrega.
- `Definicao do bloco Runtime or delivery context`: usar quando a duvida principal for encaixe no fluxo, destino de entrega, consumo efetivo ou papel operacional.
- `Definicao do bloco Identity and container`: usar quando a duvida principal for `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` ou risco de objeto errado.
- `Regra de condução`: declarar o bloco primario antes da leitura fina e abrir bloco adjacente apenas quando houver dependencia funcional explicita.
- `Transicoes permitidas`:
  - `Deployment unit definition and declared surface -> Packaging parameters and technical options`
  - `Deployment unit definition and declared surface -> Runtime or delivery context`
  - `Deployment unit definition and declared surface -> Identity and container`
  - `Packaging parameters and technical options -> Deployment unit definition and declared surface`
  - `Packaging parameters and technical options -> Runtime or delivery context`
  - `Packaging parameters and technical options -> Identity and container`
  - `Runtime or delivery context -> Deployment unit definition and declared surface`
  - `Runtime or delivery context -> Packaging parameters and technical options`
  - `Runtime or delivery context -> Identity and container`
  - `Identity and container -> Deployment unit definition and declared surface`
  - `Identity and container -> Packaging parameters and technical options`
  - `Identity and container -> Runtime or delivery context`
- `Gatilhos do bloco primario`:
  - `Deployment unit definition and declared surface` para duvida sobre o que a unidade declara ser, seu papel principal ou sua surface estrutural.
  - `Packaging parameters and technical options` para duvida sobre parâmetros, opções, flags ou configuração técnica de empacotamento/entrega.
  - `Runtime or delivery context` para duvida sobre encaixe no fluxo, destino de entrega, consumo efetivo ou papel operacional.
  - `Identity and container` para duvida sobre `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid` e risco de objeto errado.
- `Regra de fronteira`: não colapsar surface declarada, parâmetros tecnicos e contexto de entrega/uso como se provassem a mesma coisa.
- `Conclusao`: fechar a resposta no menor nível funcional sustentado pelo XML e pela dependencia realmente aberta: definicao, parâmetros, contexto de entrega/uso ou identidade estrutural.

### Escalada para corpus real

- `Regra operacional`: quando a trilha já cobrir o caso comum por molde sanitizado forte, o corpus real da KB não deve ser exigido como primeiro passo.
- `Regra operacional`: depois de uma tentativa inicial e no máximo um corretivo estrutural curto, o agente deve parar de iterar por analogia e escalar para XML real comparavel.
- `Regra operacional`: enquanto o caso continuar coberto pelo molde forte da trilha sem necessidade de escalada, rotular a base usada como `molde sanitizado`.
- `Regra operacional`: ao escalar, registrar explicitamente se a base usada passa a ser `XML real da KB atual` ou `XML real de outra KB`.
- `Regra operacional`: se a resposta ainda estiver sustentada apenas por tentativa plausivel sem molde documentado nem XML real comparavel, classificar como `hipotese` e bloquear consolidacao.

## Citacao de linhas em XML GeneXus

- `Regra operacional`: ao citar linha de XML GeneXus como evidencia, classificar explicitamente o papel do trecho citado: `Source efetivo`, `Rules/parm`, `metadado XML`, `chamada no chamador` ou `assinatura no chamado`.
- `Regra operacional`: em `Procedure`, uma linha no `Part` de `Rules/parm` do objeto chamado prova apenas a assinatura ou regra de parâmetros desse próprio objeto; ela não prova que outro objeto chamou essa `Procedure`.
- `Regra operacional`: para afirmar que objeto A chama objeto B, a evidencia deve estar no `Source` efetivo de A, na linha em que B aparece como chamada, ou em metadado de chamada explicitamente materializado no objeto A.
- `Regra operacional`: se a linha citada pertence ao XML de B e mostra `parm(...)`, descreve-la como `assinatura no chamado`, nunca como ponto de chamada a partir de A.
- `Regra operacional`: quando a análise envolver cadeia de chamadas, registrar separadamente arquivo/linha do chamador e arquivo/linha da assinatura do chamado, sem colapsar as duas evidencias em um único link.

## Identidade de frente e identidade de pacote

- `Regra operacional`: distinguir explicitamente `mesmo objeto` de `mesma frente`.
- `Regra operacional`: o agente não deve reaproveitar `NomeCurto`, GUID da frente, data de abertura da frente ou contador `nn` apenas porque o objeto alvo e o mesmo.
- `Regra operacional`: o agente só pode reutilizar a identidade de uma frente anterior quando o usuário declarar continuidade da mesma frente ou quando houver evidencia direta suficiente no repositório para fechar essa continuidade sem ambiguidade relevante.
- `Regra operacional`: reuso de precedente estrutural de pacote e decisão separada do reuso da identidade nominal da frente.
- `Regra operacional`: envelope, `Dependencies`, `ObjectsIdentityMapping` e demais elementos estruturais podem herdar de precedente validado quando o caso for comparavel.
- `Regra operacional`: identidade nominal da frente não deve herdar automaticamente do pacote anterior por analogia, recencia, coincidencia de objeto ou habito operacional.
- `Regra operacional`: quando a continuidade da frente não estiver explicitamente confirmada nem diretamente evidenciada, o agente deve bloquear a heranca automática da identidade anterior e tratar a decisão como pendente ou como abertura explicita de frente nova, conforme a documentação local aplicavel.

## Contrato de nomenclatura de parâmetros

Vocabulario canonico dos parâmetros dos wrappers e motores compartilhados XPZ. O objetivo e que um agente chame qualquer membro da familia sem tentativa-erro de flag e parseie a saida de forma uniforme. Aliases são aditivos: não quebram chamadas existentes.

- `Regra operacional`: selecao de objeto por nome usa o nome canonico `-ObjectList`; `-ObjectNames` e sinonimo aceito. No motor de export (`Invoke-GeneXusXpzExport.ps1`), `-ObjectList` e `[string[]]` (aceita string única ou array) com alias `ObjectNames`; o `Copy-GeneXusAcervoToFront.ps1` aceita tanto `-ObjectList` quanto `-ObjectNames`.
- `Regra operacional`: selecao por GUID usa `-ObjectGuids` (hoje exposto no `Copy-GeneXusAcervoToFront.ps1`) — dimensao de enderecamento distinta da selecao por nome, não sinonimo de `-ObjectList`, e não garantido em todo motor (o export, por exemplo, seleciona só por nome).
- `Regra operacional`: entrada primaria (o artefato que o script consome) usa o nome canonico `-InputPath`, com alias `-Path` em todos os wrappers e motores de entrada simples (ex.: `Sync-GeneXusXpzToXml.ps1`, `Edit-GeneXusXmlSurgical.ps1`, `Extract-XpzObject.ps1`, `Get-GeneXusObjectSummary.ps1`); a lista autoritativa do conjunto coberto está em `scripts/Test-XpzParameterNamingContract.ps1`.
- `Regra operacional`: na familia de import (o insumo e um `.xpz`, `.xml` ou envelope `.import_file.xml`), `-InputPath` carrega os aliases `-XpzPath` (retrocompativel) e `-Path`. Vale para `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzImportThenBuild.ps1` e `Test-GeneXusXpzImportPreview.ps1`.
- `Regra operacional`: regra de direcao — artefato de SAIDA mantem nome por papel e não vira `-InputPath`. No export (`Invoke-GeneXusXpzExport.ps1`), o `.xpz` produzido e `-XpzPath` (saida) e NÃO recebe alias `-InputPath`. A mesma chave `XpzPath` permanece nos diagnosticos JSON de saida — contrato de saida estavel, não renomear.
- `Regra operacional`: atenção ao token `XpzPath` — ele e ENTRADA (alias de `-InputPath`) na familia de import e SAIDA (nome canonico do artefato produzido) no export; o papel depende da direcao da operacao, não do nome.
- `Regra operacional`: conceitos vizinhos NÃO são selecao de objeto e não herdam o vocabulario de `-ObjectList`: `-ModifiedObjectNames`/`-ModifiedObjectGuids` (handoff de objetos modificados para envelope/inventario), `-ExpectedItems` (assercao de validação do que se espera no pacote) e `-IncludeItems`/`-ExcludeItems` (parâmetros da própria task MSBuild do GeneXus). Cada um conserva nome e semantica próprios.
- `Regra operacional`: a trava deterministica deste contrato e `scripts/Test-XpzParameterNamingContract.ps1`, que verifica nomes canonicos, aliases, tipo e a regra de direcao via metadados, sem executar os scripts nem exigir KB.

## Delta estrito

- `Regra operacional`: frente faseada e valida quando a limitacao operacional do GeneXus impedir pacote monolitico seguro.
- `Regra operacional`: depois de uma rodada validada da mesma frente, a preferencia metodologica e por delta novo, não por reempacotamento acumulado desnecessario.
- `Regra operacional`: quando a introducao de FK nova depender de `SubTypeGroup`, a revisao estrutural mínima deve alcancar também a `Table` correspondente.
- `Regra operacional`: antes de empacotar, classificar cada mudanca candidata como `mudanca pedida`, `mudanca auxiliar necessaria` ou `mudanca extra nao pedida`.
- `Regra operacional`: se a mudanca for apenas metadado, reserializacao ou ruido, ela deve ser classificada como `mudanca extra nao pedida`, salvo quando houver justificativa objetiva de dependencia obrigatória.
- `Regra operacional`: mudanca extra não pedida deve ser sinalizada explicitamente antes do empacotamento.
- `Regra operacional`: o agente não deve absorver mudanca extra não pedida no pacote apenas porque ela apareceu no XML ativo, no diff local ou na reserializacao.
- `Regra operacional`: o delta deve ser estrito pelo conteúdo do pacote, não por `git diff` abstrato.

### Revisao por blocos em `Panel`

- `Regra operacional`: em `Panel`, não presumir que pouco volume de XML signifique baixa sensibilidade metodologica; a revisao fina deve separar explicitamente superficie funcional, comportamento serializado e acoplamento estrutural com `parent` e pattern.
- `Regra operacional`: os blocos canonicos de revisao em `Panel` são `Panel structure and layout`, `Serialized behavior and configuration`, `Pattern and parent coupling`, `External dependencies` e `Identity and container`.
- `Regra operacional`: `Panel structure and layout` cobre a composicao funcional e visual do painel, controles, organizacao declarativa e shape estrutural da tela.
- `Regra operacional`: `Serialized behavior and configuration` cobre comportamento e configuração serializados no XML, inclusive metadados funcionais que não são mera decoracao visual.
- `Regra operacional`: `Pattern and parent coupling` cobre `parent`, `parentGuid`, `parentType`, `moduleGuid` e o acoplamento do painel ao contexto estrutural e de pattern de origem.
- `Regra operacional`: `External dependencies` cobre objetos externos chamados, referenciados ou necessários para sustentar a leitura funcional do painel.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, contêiner e classificação estrutural do objeto.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `Panel`.
- `Regra operacional`: em `Panel`, as transicoes mais comuns e justificadas são `Panel structure and layout -> Serialized behavior and configuration`, `Serialized behavior and configuration -> Panel structure and layout`, `Panel structure and layout -> Pattern and parent coupling`, `Pattern and parent coupling -> Panel structure and layout`, `Serialized behavior and configuration -> Pattern and parent coupling`, `Pattern and parent coupling -> External dependencies`, `External dependencies -> Serialized behavior and configuration`, `Identity and container -> Pattern and parent coupling` e `Identity and container -> Panel structure and layout`.
- `Regra operacional`: usar `Panel structure and layout` como bloco inicial quando a duvida nascer de composicao visual, controles, organizacao declarativa, shape da tela ou estrutura funcional aparente do painel.
- `Regra operacional`: usar `Serialized behavior and configuration` como bloco inicial quando o sintoma falar de comportamento serializado, configuração persistida, metadado funcional ou algo que não se explica só pela superficie visual.
- `Regra operacional`: usar `Pattern and parent coupling` como bloco inicial quando a duvida falar de `parent`, `parentGuid`, `parentType`, `moduleGuid`, pattern de origem, acoplamento estrutural ou suspeita de painel fora do contexto correto.
- `Regra operacional`: usar `External dependencies` como bloco inicial quando a pergunta falar de objeto externo chamado, vinculo ausente, referencia necessária ou dependencia funcional fora do próprio painel.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de `name`, `fullyQualifiedName`, `guid`, contêiner, classificação estrutural ou risco de ter aberto o painel errado.
- `Regra operacional`: em Panel SD, `detail/@events` e fonte de comportamento serializado; ações em layout com `onClickEvent` devem ser confrontadas com os eventos persistidos nesse atributo antes de concluir cobertura ou equivalencia entre Panels.
- `Regra operacional`: quando um Panel SD comparavel usar `<action onClickEvent="'Nome'">` com `Event 'Nome'`, preservar esse vinculo; não sintetizar `Event Controle.Tap` sem evidencia equivalente em Panel real comparavel da mesma KB.
- `Regra operacional`: o aviso de acoplamento `level id`/`layout id` só pode deixar de ser ressalva quando o par do pacote for localizado em template ou referencia comparavel explicitamente informada; mera presenca de dois GUIDs não comprova coerência.
- `Regra operacional`: ao validar envelope com `scripts\Test-GeneXusImportFileEnvelope.ps1`, passar `-PanelReferencePath <objeto-ou-pacote-comparavel>` quando houver referencia real disponível; em Panel, ausencia dessa referencia retorna `panel-level-layout-unverified` em `warnings`, referencia sem o mesmo par retorna `panel-level-layout-suspicious` em `warnings`, e par comprovado retorna `panel-level-layout-confirmed` somente em `information`, sem rebaixar o status por essa verificacao.
- `Regra operacional`: em `Panel`, não tratar `Panel structure and layout` como prova suficiente de autonomia do objeto; sempre manter a possibilidade de que o risco real esteja no acoplamento estrutural ao redor dele.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Panel` inteiro por reflexo.

### Revisao por blocos em `Transaction`

- `Regra operacional`: em `Transaction`, não tratar a transacao inteira como bloco único de leitura; a revisao fina deve declarar antes qual é o bloco primario do sintoma atual.
- `Regra operacional`: os blocos canonicos de revisao em `Transaction` são `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context` e `Identity and container`.
- `Regra operacional`: `Transaction structure` cobre `Level`, chave, `DescriptionAttribute`, shape transacional e coerência estrutural do nucleo da transacao.
- `Regra operacional`: `Attributes and attribute properties` cobre atributos, `AttributeProperties`, subtipos e relacoes de contrato de dados que afetem a transacao.
- `Regra operacional`: `Rules` cobre regras declarativas da `Transaction` e seus efeitos normativos.
- `Regra operacional`: `Events` cobre fluxo procedural e comportamento acionado via interface, especialmente via edicao web.
- `Regra operacional`: `Execution context` cobre a separacao explicita entre comportamento via edicao web e comportamento via BC; essa camada não deve ser colapsada por analogia.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa da `Transaction`.
- `Regra operacional`: em `Transaction`, as transicoes mais comuns e justificadas são `Transaction structure -> Attributes and attribute properties`, `Rules -> Execution context`, `Rules -> Attributes and attribute properties`, `Events -> Execution context` e `Transaction structure -> Rules`.
- `Regra operacional`: quando a duvida for de comportamento, declarar explicitamente se a conclusao vale via edicao web, via BC, ou se a evidencia atual ainda não separa os dois contextos.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Transaction` inteira por reflexo.

## Fechamento técnico e Git

- `Regra operacional`: concluir `sync`, importação, exportação, materialização, validação ou build gera apenas o estado `validado_tecnicamente`; isso não autoriza automaticamente `git add`, `commit` ou `push`.
- `Regra operacional`: o agente pode sugerir próximos passos de Git e publicacao quando isso for oportuno, mas sugestao não equivale a execução.
- `Regra operacional`: qualquer ação de fechamento ou publicacao em Git só pode ser executada com autorizacao explicita do usuário.
- `Regra operacional`: enquanto houver frente tecnicamente validada sem decisão de publicacao, o estado operacional preferido e `aguardando_decisao_de_fechamento`.
- `Regra operacional`: a documentação local da pasta de trabalho pode declarar override mais específico para fechamento e publicacao, mas a regra padrão desta base permanece em vigor ate essa override ser explicitada.

## Gate visual de `Source`

- `Regra operacional`: quando houver edicao de `Source`, releia o trecho salvo antes do empacotamento.
- `Regra operacional`: se a mudanca introduzir `if/endif`, `do case/endcase`, deslocamento de bloco, reindentacao relevante ou novo aninhamento, conferir explicitamente identacao, fechamento visual e legibilidade local.
- `Regra operacional`: comentarios estruturais humanos já existentes, como `//if`, devem ser preservados quando ajudam a leitura do bloco; não tratar esse apoio como sujeira cosmetica.
- `Regra operacional`: em `Source` grande, revisar o contorno visual do bloco afetado e algumas linhas antes e depois; isso é uma heuristica de escalada, não uma regra metodologica central para toda edicao.
- `Regra operacional`: esse gate reduz erro humano em XML e `Source` grandes e não substitui validação semantica GeneXus.

## Ruido conhecido de `WorkWithWeb`

- `Evidência direta`: em casos comprovados desta frente, houve ruido não funcional em `WorkWithWeb` associado a `Load Code` no atributo de `Selection` e/ou em tabs de `View`.
- `Regra operacional`: esse ruido deve ser tratado como inevitavel apenas nesses pontos comprovados, sem generalizar para todo `WorkWithWeb`.
- `Regra operacional`: quando esse ruido aparecer, registrar no manifesto como não funcional para triagem de comparacao; não orientar correcao manual como se fosse defeito de estrutura.

## Contaminacao de workspace e isolamento de lote

- `Regra operacional`: antes de empacotar, listar os XMLs ativos na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus` e tratar esse conjunto como lote candidato.
- `Regra operacional`: se houver mais de um lote plausivel na pasta de geração, o agente deve bloquear o empacotamento por contaminacao de workspace.
- `Regra operacional`: o agente não deve inferir o lote correto apenas por recencia se houver risco de mistura de frentes.
- `Regra operacional`: o agente não deve fechar pacote por inferencia quando houver mais de um lote plausivel no workspace.
- `Regra operacional`: a ordem obrigatória antes de empacotar é: isolar lote, classificar raizes, validar fidelidade textual do delta, validar `lastUpdate`, validar BOM, validar manifesto e só entao serializar o pacote.
- `Regra operacional`: manifesto deve ser tratado primeiro como saida estruturada na própria conversa, e não como arquivo físico por padrão.
- `Regra operacional`: nome de pacote local gerado para importação na IDE deve priorizar clareza humana e separacao de frentes paralelas, preferindo o padrão `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`.
- `Regra operacional`: nesse padrão, `NomeCurto` e uma descrição curta, legivel e semanticamente forte da frente; `GUID` e o identificador aberto para aquela frente; `YYYYMMDD` e a data de abertura da frente; `nn` e apenas o contador curto e incremental da rodada daquela frente.
- `Regra operacional`: `nn` não representa versão semantica profunda nem histórico de release; ele representa somente o candidato curto daquela frente.
- `Regra operacional`: enquanto a mesma frente ativa não estiver encerrada, microajustes sucessivos devem reutilizar a mesma subpasta `NomeCurto_GUID_YYYYMMDD` e manter o mesmo prefixo de pacote, alterando somente `nn`.
- `Regra operacional`: antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` em `PacotesGeradosParaImportacaoNaKbNoGenexus`, verificar se já existe arquivo com o mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn`.
- `Regra operacional`: quando a decisão for deterministica, o enforcement primario deve viver em `.ps1`; para colisao de pacote, preferir um gate dedicado como `Test-XpzPackageCollision.ps1` ou wrapper local equivalente, em vez de recalcular a regra no texto da resposta.
- `Regra operacional`: se já existir pacote com o mesmo prefixo de frente e o mesmo `nn`, o gate deve abortar a gravacao; não sobrescrever silenciosamente a rodada.
- `Regra operacional`: quando houver colisao de `nn`, o erro explicito e a sugestao do próximo `nn` livre devem sair do próprio gate `.ps1`, sem autoincrementar nem gravar automaticamente com o valor sugerido.
- `Regra operacional`: não usar como padrão nome só com assunto, nome só com data ou hora, descrição excessivamente longa da conversa ou sobrescrita recorrente do mesmo nome de pacote.
- `Regra operacional`: se um pacote anterior perder validade por mudanca de direcao da frente, ele deve ser marcado como provisório ou obsoleto e deixar de ser tratado como candidato principal.

## Protocolo para alteracoes indevidas no snapshot oficial

- `Regra operacional`: se o agente detectar alteracoes locais preexistentes em `ObjetosDaKbEmXml`, deve presumir erro de processo ate esclarecimento em contrario.
- `Regra operacional`: nesse cenário, o fluxo seguro e preservar esses XMLs em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, restaurar `ObjetosDaKbEmXml` para a versão oficial do Git e registrar manifesto dos itens preservados; esse manifesto pode ficar na conversa, mas deve virar arquivo quando a rastreabilidade local do incidente for necessária.
- `Regra operacional`: o agente não deve empacotar diretamente a partir de `ObjetosDaKbEmXml` alterado.

## Mudanca paralela legitima vinda da KB

- `Regra operacional`: quando um `XPZ` oficial exportado da KB trouxer objetos adicionais além do foco imediato da frente atual, isso pode representar mudanca paralela legitima feita diretamente na IDE do GeneXus.
- `Regra operacional`: no `sync` de retorno oficial da KB, o padrão e materializar o que a KB devolveu oficialmente, mesmo quando houver itens que o agente não estava esperando.
- `Regra operacional`: o agente deve sinalizar os itens inesperados sem presumir, por si só, erro de processo, contaminacao indevida ou violacao da trilha.
- `Regra operacional`: a distincao mínima obrigatória e entre `artefato da frente atual`, `mudanca paralela legitima vinda da KB/IDE` e `mudanca lateral indevida do proprio agente fora do escopo`.
- `Regra operacional`: regras de contaminacao, incidente de processo e restauracao do snapshot oficial se aplicam a alteracao lateral indevida do agente ou a edicao manual indevida do acervo, não ao simples fato de um `XPZ` oficial trazer retorno adicional da KB.
- `Regra operacional`: quando o contexto da frente estiver disponível, o `sync` pode comparar opcionalmente um conjunto esperado de itens contra o retorno oficial da KB, classificando `esperados que voltaram`, `esperados que nao voltaram` e `retorno oficial adicional da KB`.
- `Regra operacional`: essa classificação comparativa e complementar; ela não substitui nem bloqueia a materialização oficial do que veio no `XPZ`.

## Checklist obrigatório antes do empacotamento

- `Regra operacional`: antes de empacotar, classificar cada XML ativo como `alterado na rodada` ou `reenviado sem mudanca por dependencia obrigatoria`.
- `Regra operacional`: ao criar uma copia alterada de XML GeneXus em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, preservar fielmente o XML de origem fora do delta funcional aprovado; a operacao padrão e edicao cirurgica, não reconstrucao nem reserializacao ampla.
- `Regra operacional`: fora do delta funcional, preservar comentarios, `CDATA`, indentacao, linhas em branco, ordem de nos, quebras de linha e whitespace herdado; não introduzir espacos ou tabs finais em linhas novas ou modificadas.
- `Regra operacional`: antes de empacotar, comparar a copia alterada contra o XML de origem e confirmar que o diff contem apenas o delta pretendido; mudancas apenas de whitespace, indentacao, quebra de linha, comentarios removidos ou reserializacao devem bloquear a entrega ate a copia ser refeita de forma mais cirurgica ou ate aprovacao explicita do usuário.
- `Regra operacional`: se o objeto foi realmente modificado nesta rodada, o `lastUpdate` deve seguir `max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)` quando houver baseline oficial, ou `UtcNow + 60s` para objeto novo sem baseline.
- `Regra operacional`: se o objeto não foi modificado e entrou apenas para dependencia obrigatória ou composicao mínima do pacote, o `lastUpdate` oficial anterior deve ser preservado.
- `Regra operacional`: o empacotamento deve abortar quando houver divergencia entre a classificação do item e o `lastUpdate` materializado.
- `Regra operacional`: antes de empacotar, classificar a raiz top-level de cada XML ativo em `Object`, `Attribute` ou `outro tipo`.
- `Regra operacional`: `Object` top-level deve entrar em `<Objects>`.
- `Regra operacional`: `Attribute` top-level deve entrar em `<Attributes>`.
- `Regra operacional`: nunca colocar `Attribute` top-level dentro de `<Objects>`.
- `Regra operacional`: se surgir raiz top-level não suportada pelo fluxo atual, o empacotamento deve abortar ou exigir tratamento explicito.
- `Regra operacional`: XML gerado localmente deve ser salvo em UTF-8 sem BOM.
- `Regra operacional`: antes de empacotar, verificar presenca de BOM UTF-8 no inicio de todos os XMLs ativos.
- `Regra operacional`: se houver BOM, remover e registrar a correcao como higiene operacional.
- `Regra operacional`: arquivos `.md` e `.ps1` deste repositório usam UTF-8 sem BOM; o gate `Test-GeneXusUnexpectedCharacter.ps1` (invocado pela pre-push mecanica) detecta caracteres Unicode fora dos blocos esperados para conteúdo em pt-BR/es/en (CJK, Cirilico, Arabic, etc.) em linhas adicionadas ao diff, excluindo `historico/` e blocos de código cercados em `.md`; findings são consultivos (severity `warn`); revisar e descartar falso positivo antes de concluir a pre-push.
- `Regra operacional`: scripts `.ps1` desta raiz que gravem texto em UTF-8 sem BOM devem carregar `scripts/Utf8NoBomEncodingSupport.ps1` e usar `Get-Utf8NoBomEncoding`; manter construtores inline de `UTF8Encoding` apenas quando o objetivo for leitura/deteccao de encoding, BOM deliberado ou validação estrita de bytes.
- `Regra operacional`: antes de gerar `import_file.xml` ou `.xpz`, produzir ou validar manifesto do lote, preferencialmente na própria conversa, com frente ou descrição curta do lote, origem do lote, quantidade total de XMLs, quantidade de `Objects`, quantidade de `Attributes`, lista ou resumo dos arquivos incluidos, `lastUpdate` aplicado ou preservado, pacote gerado, pacote anterior substituido quando houver e observacoes de risco ou pendencia.
- `Regra operacional`: salvar manifesto em arquivo não é o comportamento padrão; isso só deve ocorrer quando houver incidente de processo envolvendo `ObjetosDaKbEmXml`, substituicao de pacote com necessidade real de rastreabilidade local, pedido explicito do usuário ou necessidade concreta de retomada futura fora da conversa imediata.
- `Regra operacional`: esse manifesto deve servir para conferencia humana e para bloquear mistura de frentes.
- `Regra operacional`: quando houver pacote anterior da mesma frente com risco real de confusao, o prefixo `OBSOLETO_` pode ser usado como ferramenta de contencao; isso não faz parte da convencao principal de nome do pacote.

### Exemplo sanitizado do envelope observado

```xml
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>4</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <Build>BUILD_OBSERVADO</Build>
  </KMW>
  <Source kb="GUID_SANITIZED" username="SANITIZED\\USER" UNCPath="\\\\SANITIZED\\KBPATH">
    <Version guid="GUID_SANITIZED" name="KB_SANITIZED" />
  </Source>
  <BlocoEspecialDaKB name="KB_SANITIZED" type="GUID_TIPO_KB" description="Descricao sanitizada" user="SANITIZED\\USER">
    <Properties />
    <Version guid="GUID_SANITIZED" versionDate="0001-01-01T00:00:00.0000000" checksum="CHECKSUM_SANITIZED" server_checksum="">
      <Properties />
    </Version>
    <Environments />
  </BlocoEspecialDaKB>
  <Objects>
    <Object ... />
  </Objects>
  <Attributes>
    <Attribute ... />
  </Attributes>
  <Dependencies>
    <Reference ... />
  </Dependencies>
</ExportFile>
```

- Evidência direta: `Attributes` é um bloco adicional comum no formato normal, mas não invariavel
- Inferência forte: para geração conservadora de objetos comuns, este envelope mínimo continua sendo referencia útil, mas não deve ser promovido a formato universal para qualquer pacote misto
- Evidência direta: esse envelope mínimo já sustentou uma importação bem-sucedida de um `Procedure` de teste nesta trilha, desde que os GUIDs de `Source` fossem sintaticamente validos
- Evidência direta: em frente posterior desta mesma trilha, um pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure` só passou quando foi remontado como pacote embutido, tomando export real comparavel da IDE como molde.

- `Evidência direta`: em teste real de `Import File Load`, um arquivo contendo apenas `<Object>` falhou com `Invalid format, MajorVersion not found`.
- `Evidência direta`: nesta trilha, `import_file.xml` foi validado como artefato operacional de importação pela IDE, não como sinonimo exato do `XPZ` completo observado em export real.
- `Regra operacional`: para `Load/Import` pela IDE, não assumir que XML individualizado de objeto seja suficiente; quando o objetivo for carga na KB, empacotar em `import_file.xml` com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`.
- `Regra operacional`: quando a frente atual alterar apenas um subconjunto de objetos, preferir pacote mínimo contendo só os objetos realmente mudados, para reduzir ruido, risco de regressao e retrabalho de validação.
- `Regra operacional`: se um objeto não foi alterado, ele não deve entrar no pacote apenas por conveniencia; só entra quando for necessário para fechar dependencias obrigatórias do objeto realmente modificado.
- `Regra operacional`: ao embutir XML individualizado de objeto dentro de `<Objects>` no `import_file.xml`, remover a declaracao `<?xml ...?>` do objeto; essa declaracao deve existir apenas no topo do arquivo do pacote.
- `Regra operacional`: ao documentar ou raciocinar sobre formato, separar explicitamente `XPZ observado em export real` de `envelope de importacao pela IDE`; ambos compartilham a raiz `ExportFile`, mas não devem ser tratados como o mesmo artefato sem qualificacao.
- `Evidência direta`: em teste real de renomeacao de objeto, a importação preservou histórico apenas quando o pacote manteve o mesmo `Object/@guid` do objeto existente.
- `Regra operacional`: se existir export real comparavel da IDE para a mesma composicao de objetos, esse export deve prevalecer como molde estrutural do pacote sobre qualquer envelope leve hipotetico.
- `Regra operacional`: para pacote misto de `Transaction + WorkWithForWeb + Procedure`, o caminho validado nesta trilha foi pacote embutido com objetos completos em `<Objects>`, reaproveitando `Dependencies` e `ObjectsIdentityMapping` contextuais de export real comparavel.
- `Regra operacional`: renomeacao, mudanca de propriedades, `source`, `rules`, `variables` ou `folder` de um objeto existente devem preservar o mesmo `guid`; trocar o `guid` significa criar outro objeto.

## Aprendizados com pacotes de importação na IDE

- `Regra operacional`: pacote mínimo deve ser a referencia padrão; se uma frente alterou apenas alguns objetos, não reenviar XMLs não tocados apenas para "completar" a rodada.
- `Regra operacional`: `lastUpdate` novo deve existir só no objeto realmente alterado; objeto reenviado sem mudanca precisa conservar o `lastUpdate` original do XML da KB.
- `Regra operacional`: ao embutir XMLs em `import_file.xml`, remover declaracao `<?xml ...?>` interna do objeto e manter a declaracao apenas no topo do pacote.
- `Regra operacional`: quando o pacote envolver `WorkWithForWeb`, validar o `CDATA` interno do `Data` como XML completo, porque erros de fechamento de `selection`, `tab`, `view` ou `variable` costumam aparecer só no `Load`.
- `Regra operacional`: ao alterar `WorkWithForWeb`, desencorajar substituicoes textuais amplas em tags repetidas, especialmente `<actions>`; localizar estruturalmente a `Selection` alvo dentro do XML interno antes de inserir, remover ou alterar uma action.
- `Regra operacional`: em `WorkWithForWeb`, uma action nova só deve ser considerada materializada quando estiver no `Selection` correto, com identificador/nome esperado, e aparecer exatamente uma vez naquele escopo.
- `Regra operacional`: se houver mais de um `<actions>` plausivel, ou se a mesma action aparecer em escopos diferentes sem justificativa documental, bloquear o pacote ate reinspecao estrutural do XML interno.
- `Regra operacional`: se o `Selection` do `WorkWithWeb` usar ordenacao sensivel a volume, conferir se a `Table` tem índice exato para a mesma sequência de campos e direcoes.
- `Evidência direta`: em importacoes reais desta KB, a frente de `CompraRevenda` ficou com cobertura exata de ordenacao; outros casos fiscais da mesma trilha exigiram anotação específica para avaliacao de índice composto.
- `Exemplo sanitizado`: `TRN + WorkWithWeb + Attributes + Procedures` pode importar com sucesso quando o pacote leva só o fecho mínimo e preserva um `lastUpdate` real por objeto.
- `Exemplo sanitizado`: também houve sucesso real, nesta trilha, com pacote embutido de `4` `Transaction`, `4` `WorkWithForWeb` e `3` `Procedure`, passando por `Import File Load`, `Import`, `Updating table information` e `Pattern generation`.
- `Exemplo sanitizado`: um `WorkWithWeb` com filtros fiscais, ação de planilha e `IconeUpdate` deve ser validado por partes, comparando o XML gerado com o artefato equivalente da KB antes do `Load`.
- `Referencia privada`: os casos completos, sem sanitizacao, ficam mapeados em `C:\\Dev\\Knowledge\\GeneXus-XPZ-PrivateMap`; a raiz publica deve manter apenas o aprendizado resumido e os exemplos anonimizados.

## Leitura operacional de logs de importação

- `Regra operacional`: ler log de importação por etapa, não por linha isolada.
- `Regra operacional`: classificar cada mensagem em uma destas categorias: `erro estrutural de XML/pacote`, `erro de identidade/serializacao do objeto`, `erro de sintaxe/semantica do Source`, `erro lateral da IDE`, `warning nao bloqueante`, `sucesso terminal`.
- `Regra operacional`: a conclusao final deve usar a etapa terminal relevante do log e o conjunto das mensagens bloqueantes.
- `Regra operacional`: falha lateral da IDE antes, durante ou depois do import não deve ser promovida automaticamente a falha estrutural do pacote.
- `Regra operacional`: se o pacote abriu, mas o `Source` falhou, classificar como falha de `Source`, não de envelope.
- `Regra operacional`: se alguns objetos entraram e outros não, classificar o resultado como parcial e registrar o objeto ou etapa afetada.
- `Regra operacional`: warning ou erro lateral coexistente com `Import` bem-sucedido deve gerar `sucesso com ressalva`, não `falha total`.
- `Regra operacional`: ao gerar pacote corretivo depois de falha parcial, relatar explicitamente: pacote original, objetos importados com sucesso, objetos falhos, causa provavel por objeto ou etapa, e novo pacote corretivo.
- `Regra operacional`: pacote corretivo deve conter apenas o delta necessário para corrigir os objetos falhos ou dependencias estritamente necessárias; não reenviar automaticamente todos os objetos do pacote original.

### Playbook de diagnostico para `Procedure` de relatório

- `src0212 invalid control`: suspeitar primeiro do layout; revisar o shape do `Part c414ed00-8cc4-4f44-8820-4baf93547173`, `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute` e a coerência entre bloco impresso e bloco materializado.
- `src0201 output_file invalid type`: suspeitar primeiro de `Source` ou de mistura de camadas; revisar assinatura usada em `Output_file`, tipo dos parâmetros e se o comando ficou realmente no `Source`.
- `src0119 ';' not longer supported`: suspeitar primeiro de `Source`; revisar transplante indevido de sintaxe de `Rules`, legado de dialeto ou terminador herdado.
- `src0056 Missed ';' at the end of the rule`: suspeitar primeiro de `Rules`; revisar fechamento de `parm(...)` e demais regras, sem deslocar o diagnostico para o layout; em `Transaction` `Rules`, ver também anti-padrao `transaction-rule-on-event-with-attribute-parameter` (clausula `on <evento>(...)` rejeitada na importação).
- erro citando `printBlock`, `ReportLabel`, `ReportAttribute` ou `invalid control`: suspeitar primeiro do layout.
- erro citando `parm`, `rule`, `end of the rule` ou assinatura: suspeitar primeiro de `Rules`.
- erro citando `For each`, `Header`, `Footer`, `Output_file` ou comando procedural: suspeitar primeiro de `Source`.
- `Regra operacional`: classificar esses casos como `erro de sintaxe/semantica do Source` ou `erro estrutural de XML/pacote` conforme a camada realmente afetada; não colapsar tudo como defeito de envelope.
- `Regra operacional`: depois da tentativa inicial mais um único corretivo estrutural curto nesse playbook, bloquear nova iteracao por analogia e exigir XML real comparavel.

### Procedimento auditavel de leitura

- `Regra operacional`: identificar primeiro a etapa de cada mensagem: `Import File Load`, `Import`, `Updating table information`, `Pattern generation`, `Specification`, `backup` ou equivalente.
- `Regra operacional`: para cada mensagem, registrar `etapa`, `categoria`, `bloqueia objeto`, `bloqueia pacote` e `conclusao parcial`.
- `Regra operacional`: concluir o estado final a partir da etapa terminal relevante do caso, e não da linha mais alarmante do log.
- `Regra operacional`: quando houver falha parcial, registrar separadamente o estado final do pacote e o estado final por objeto.

### Revisao por blocos em `WebPanel` e validação de pacote delta

- `Regra operacional`: tratar `WebPanel` como objeto de revisao por blocos funcionais, não como massa única de XML, sempre que a duvida envolver comportamento, filtro, evento, dependencia ou diagnostico fino.
- `Regra operacional`: os blocos canonicos de revisao em `WebPanel` são `layout`, `events`, `variables`, `metadado funcional serializado`, `identidade e contêiner` e `dependencias`.
- `Regra operacional`: antes de aprofundar a leitura, declarar um bloco primario para o sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional declarada; transicao sem motivo explicito degrada a revisao e reintroduz mistura de camadas.
- `Regra operacional`: `metadado funcional serializado` é camada funcional própria de `WebPanel`; ele orbita o layout, mas não deve ser reduzido a mera apresentacao visual.
- `Regra operacional`: em `WebPanel`, não assumir que o `Conditions` visivel na IDE venha automaticamente de um `Part` fixo; antes de concluir shape, localizar no XML real onde aquele tipo de controle persiste o filtro.
- `Regra operacional`: quando a duvida for "onde a IDE realmente persiste esta propriedade?", decidir a partir de XML exportado pela própria IDE para objetos comparaveis da mesma KB; não decidir por analogia com outro controle, outro `Part` ou outra familia de `WebPanel`.
- `Regra operacional`: tratar `Conditions` materializado, `Defaults` de template (`ViewConditions.dkt`, `TabGridConditions.dkt`) e metadado serializado de layout como camadas distintas; a mera presenca textual da palavra `Conditions` não prova filtro persistido.
- `Regra operacional`: em `WebPanel`, `ControlWhere`, `ControlBaseTable`, `ControlOrder` e `ControlUnique` devem ser procurados primeiro no `Source` do `Part` de layout, normalmente dentro de `PATTERN_ELEMENT_CUSTOM_PROPERTIES`; só tratar outro `Part` como origem quando houver evidencia direta no XML real.
- `Regra operacional`: `WebUserControlProperties` e `PATTERN_ELEMENT_CUSTOM_PROPERTIES` devem ser lidos como metadado serializado de controle no layout, e não como propriedades planas do objeto.
- `Regra operacional`: se a leitura do layout serializado em `CDATA` vier truncada ou parcial, nunca reconstruir manualmente esse layout; a recuperacao segura e extrair o bloco completo por método estruturado ou operar por substituicao cirurgica sobre o raw integral, preservando byte a byte o layout fora do delta pretendido.
- `Regra operacional`: em `WebPanel`, um botao e declarado uma única vez no layout, em uma de duas formas serializadas do mesmo controle Button — `<action controlName= onClickEvent= caption=>` ou `<ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES=...>` (nome e evento dentro das Properties escapadas) — e disparado por um Event de usuário nomeado (`Event 'Nome'`) ou padrão (`Enter`/`Back`); a escolha da forma é detalhe de serializacao, não de modelagem (padrão observado: `ucw` em menus, `<action>` no restante).
- `Regra operacional`: não confundir tres usos distintos no XML de `WebPanel` — botao de layout (`<action controlName= onClickEvent=>` ou `<ucw>` Button) dentro de `<layout>`; ação de pattern `WorkWithForWeb` (`<action name=>` dentro de `<actions>`); e referencia de propriedade em código de evento (`Botao.Visible`/`.Icon`/`.Enabled`), que manipula controle já declarado e não é declaracao nem evento; N ocorrências do nome de um botao no `Source` não significam N botoes.
- `Regra operacional`: para inspecionar o shape de `WebPanel` classico sem despejar `CDATA`, usar o bloco `webpanel` de `scripts/Get-GeneXusObjectSummary.ps1` (tabelas com `tableType` Flex/Responsive e `depth`, controles, botoes nas duas formas, eventos e bloco `coverage`); `gxControlType` é resolvido pelo catalogo versionado `scripts/gx-ucw-gxcontroltype-catalog.json` e, quando ausente, reportado em `unknownUcwControlTypes`, nunca omitido — não ler controle ausente do resumo como prova de ausencia sem checar `coverage`.
- `Regra operacional`: para adicionar um botao a `WebPanel`, preferir `scripts/Add-GeneXusButton.ps1`, que insere `<cell>` antes ou após a celula de um controle folha em tabela Flex (ancoras `-BeforeControlName`/`-AfterControlName`, mutuamente exclusivas; com stub de Event e bump de `lastUpdate`, por insercao cirurgica); em tabela Responsive com `responsiveSizes` preenchido o helper aborta fail-closed (`RESPONSIVE_UNSAFE`) em vez de reescrever o array de breakpoints — nesse caso, gerar o snippet e ajustar `responsiveSizes` manualmente.
- `Regra operacional`: em `Prompt`, `Selection List`, `Dynamic Combo` e variantes com grid, confirmar por familia se o filtro operacional está no `Part` de `Conditions`, no layout, ou nos dois lugares; não promover padrão localizado a regra universal.
- `Evidência direta`: em `FreeStyleGrid`, já houve caso em que o filtro navegou em runtime, mas a mesma forma não foi aceita pelo parser estrutural da IDE.
- `Regra operacional`: tratar `Load`, `Import` e `Specification` como validacoes separadas; sucesso em uma camada não prova sucesso nas outras.
- `Regra operacional`: `Import File Load` é apenas a etapa de listagem e preview do pacote na IDE — o objeto NÃO entra na KB nessa etapa; a importação real só ocorre quando o usuário confirma explicitamente na etapa subsequente `Import`. Mensagem `Success: Import File Load` significa que o pacote foi parseado e listado com sucesso, não que o objeto foi importado.
- `Regra operacional`: ao ajustar `ControlWhere` no XML, preferir a sintaxe aceita pelo editor estrutural da IDE; navegacao em runtime, sozinha, não basta como critério de materialização segura.
- `Regra operacional`: em clonagem conservadora de `WebPanel` que deveria preservar a superficie de bindings, comparar antes do empacotamento os bindings serializados relevantes entre original e clone; no mínimo, `fieldSpecifier` deve bater em contagem e nomes, e divergencia sem classificação explicita bloqueia o pacote.
- `Evidência direta`: declarar `controlName` explicito em `<data>` pode reduzir ambiguidade estrutural no XML, mas isso não garante que o nome fique disponível como identificador manipulavel no source do objeto.
- `Regra operacional`: em pacote delta GeneXus, quando já existir pacote equivalente validado na IDE, reaproveitar o envelope completo desse pacote como molde; não simplificar cabecalho, `Dependencies` ou `ObjectsIdentityMapping` por inferencia.
- `Regra operacional`: a montagem do `import_file.xml` a partir de XMLs de objeto deve usar motor estruturado compartilhado, nunca concatenacao textual manual. Para montagem direta com template clonavel, usar `scripts\Build-GeneXusImportFileEnvelope.ps1` (com `-AcervoPath <ObjetosDaKbEmXml>` obrigatório, coerencia pré-gravação por `lastUpdate` e `Object/@type` por mesmo `guid`, e declaracao de modificados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids`), que executa o gate de colisao (`Test-XpzPackageCollision.ps1`) antes de qualquer escrita — colisao de `_nn` aborta o script sem materializar nenhum byte — clona `KMW`/`Source`/`Dependencies`/`ObjectsIdentityMapping` do template, clona top-level `Attributes` do template quando não houver atributos explicitos passados ao helper, embute cada objeto via `ImportNode` (impossibilitando declaracao XML interna em `<Objects>`) e executa o gate de envelope automaticamente; para `Panel`, esse gate recebe automaticamente o próprio `-TemplatePackagePath` como `-PanelReferencePath` e propaga `information`/`warnings` conforme a confirmacao do par `level id`/`layout id`. Para montagem por frente da pasta paralela, usar `scripts\New-XpzImportPackage.ps1` como wrapper do motor `scripts\New-XpzImportPackage.py`, que classifica raizes top-level `Object`/`Attribute`, aplica gate de colisao e pode usar `kb-source-metadata.md` para envelope mínimo ou `-TemplatePackagePath` para clonar pacote real comparavel, incluindo top-level `Attributes` do template quando a frente não trouxer raizes `Attribute` explicitas. O wrapper executa sempre, antes do empacotamento, o gate de drift frente-vs-acervo (`Test-GeneXusFrontAcervoDrift.ps1`, passo 9-FD) em modo fail-closed: `-AcervoPath` é opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` é resolvido automaticamente; sem acervo resolvivel o empacotamento é bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`). O gate bloqueia XMLs com `lastUpdate` mais antigo que o acervo e XMLs com mesmo `guid` mas `Object/@type` divergente. `-TemplatePackagePath` pode apontar para XML/import_file.xml ou para `.xpz` que contenha XML `ExportFile`; em pacote misto/complexo, preferir template real comparavel. Envelope mínimo derivado de metadados é apoio operacional para casos simples, não formato universal.
- `Regra operacional`: antes de usar `kb-source-metadata.md` ou `-TemplatePackagePath` para montar pacote importavel, confrontar a identidade `Source/@kb` do envelope/template com a KB nativa local esperada quando essa informação estiver disponível. Divergencia indica pacote de outra KB e bloqueia import headless por agente; o usuário deve usar a IDE se quiser avaliar esse import.
- `Regra operacional`: quando o gate rejeita a montagem, o helper preserva o candidato como `<OutputPath>.rejected.<A..Z>` para inspecao forense, sem ocupar o nome canonico do pacote; renomear arquivo `.rejected` de volta para `*.import_file.xml` e gravacao silenciosa indevida.

### Revisao por blocos em `WorkWithForWeb`

- `Regra operacional`: em `WorkWithForWeb`, não tratar o objeto como XML pequeno autossuficiente; a revisao fina deve separar explicitamente vinculo transacional, comportamento serializado do pattern e identidade estrutural da instancia.
- `Regra operacional`: os blocos canonicos de revisao em `WorkWithForWeb` são `Transaction binding`, `Pattern structure and navigation`, `Actions, links and prompts`, `Attribute references and data contract` e `Identity and container`.
- `Regra operacional`: `Transaction binding` cobre `parent`, `parentGuid`, `parentType` e o vinculo explicito com a `Transaction` pai.
- `Regra operacional`: `Pattern structure and navigation` cobre o XML interno do `Data` no que define `selection`, `tab`, `view`, filtros, navegacao e organizacao funcional do pattern.
- `Regra operacional`: `Actions, links and prompts` cobre actions estruturadas, `gxobject`, links explicitos, prompts e disparos associados dentro do pattern serializado.
- `Regra operacional`: `Attribute references and data contract` cobre referencias a atributos, filtros, colunas, abas e o convenio estrutural `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, contêiner e classificação estrutural do objeto.
- `Regra operacional`: antes de aprofundar a leitura, declarar qual é o bloco primario do sintoma atual; se o agente ainda não souber qual é o bloco primario, ele ainda não está pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do `WorkWithForWeb`.
- `Regra operacional`: em `WorkWithForWeb`, as transicoes mais comuns e justificadas são `Transaction binding -> Attribute references and data contract`, `Transaction binding -> Pattern structure and navigation`, `Pattern structure and navigation -> Attribute references and data contract`, `Pattern structure and navigation -> Actions, links and prompts`, `Actions, links and prompts -> Pattern structure and navigation`, `Actions, links and prompts -> Attribute references and data contract`, `Attribute references and data contract -> Transaction binding`, `Identity and container -> Transaction binding` e `Identity and container -> Pattern structure and navigation`.
- `Regra operacional`: usar `Transaction binding` como bloco inicial quando a duvida nascer de `parent*`, acoplamento estrutural, `Transaction` associada ou suspeita de `WorkWithForWeb` ligado ao pai errado.
- `Regra operacional`: usar `Pattern structure and navigation` como bloco inicial quando o sintoma falar de `selection`, abas, `view`, filtro, navegacao, organizacao funcional da listagem ou shape interno do pattern.
- `Regra operacional`: usar `Actions, links and prompts` como bloco inicial quando a pergunta falar de action, botao, item de menu, `gxobject`, link, prompt, abertura de outro objeto ou disparo explicito a partir do `WorkWithForWeb`.
- `Regra operacional`: usar `Attribute references and data contract` como bloco inicial quando o sintoma falar de atributo exibido, filtro por atributo, coluna, aba dependente de atributo, referencia quebrada ou contrato de dados presumido pelo pattern.
- `Regra operacional`: usar `Identity and container` como bloco inicial quando a duvida falar de `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, contêiner, origem do objeto ou risco de confundir a instancia alvo com outra parecida.
- `Regra operacional`: em `WorkWithForWeb`, `WebPanel` gerado ao redor e familias `WorkWithPlus` só entram na revisao como dependencia externa explicita; não usa-los como bloco funcional interno padrão deste tipo.
- `Regra operacional`: parar a expansao quando a hipotese já estiver sustentada; não reabrir o `WorkWithForWeb` inteiro por reflexo.

#### Exemplos sanitizados minimos

- `Exemplo sanitizado`: em um `WebPanel` de prompt com `simplegrid`, o layout expunha o controle com `controlName`, mas o filtro pesquisavel ficou materializado em outro `Part`, como linhas de condição no `Source`; isso prova que o ponto real de persistencia precisa ser confirmado no XML antes de atribuir o `Conditions` a um bloco fixo.
- `Exemplo sanitizado`: em outro `WebPanel` com `grid class="FreeStyleGrid"`, o mesmo critério de filtro apareceu tanto no `ControlWhere` do layout quanto em `Part` estrutural separado; esse tipo de duplicidade explica por que `Load`, `Import` e `Specification` precisam continuar sendo validados como camadas distintas.
- `Exemplo sanitizado`: em `WPExemploGridEstruturalA`, um grid tradicional persistiu `ControlBaseTable`, `ControlOrder`, `ControlWhere` e `ControlUnique` no layout, dentro de `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, sem depender de propriedade plana no objeto.
- `Exemplo sanitizado`: em `WPExemploComboDinamicoA`, o `Dynamic Combo Box` persistiu `ControlWhere` no layout e configuração complementar em `WebUserControlProperties`; isso mostra que filtro de combo dinamico não deve ser confundido com `Conditions` materializado.
- `Exemplo sanitizado`: em pacotes delta reais com um único objeto, o envelope completo continuou incluindo `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, mesmo quando os dois blocos finais estavam vazios; por isso, a forma segura e clonar o pacote equivalente validado, não podar o fecho por "limpeza" manual.
- `Exemplo sanitizado`: em uma pasta paralela de KB de teste, dois pacotes unitarios de `Domain` gerados para importação manual mantiveram o objeto completo embutido em `<Objects>`, `Dependencies` vazio e `ObjectsIdentityMapping` contendo apenas o módulo raiz; isso reforca que pacote pequeno não deve ser reduzido a XML individual de objeto nem promovido manualmente ao acervo oficial.

### Modos de falha observados e correcoes

- `Erro sanitizado`: declaracao `<?xml ...?>` duplicada dentro de `<Objects>` no `import_file.xml`.
  `Correção`: manter a declaracao XML apenas no topo do pacote; o XML embutido no objeto deve entrar sem prologo.
- `Erro sanitizado`: `Unexpected XML declaration` ou parse quebrado no meio do pacote.
  `Correção`: localizar a declaracao interna repetida ou ruido de concatenacao antes do `Load`.
- `Erro sanitizado`: `Data` de `WorkWithForWeb` terminando com fechamento invalido de `variable`, `selection` ou `tab`.
  `Correção`: validar o XML interno do `CDATA` como documento completo, não apenas o envelope externo.
- `Erro sanitizado`: `Unknown function 'IsEmpty'` em `Procedure` importada.
  `Correção`: comparar a `Procedure` com um molde valido da KB e ajustar o `Source` e o bloco de `Variables` para a assinatura real do objeto.
- `Erro sanitizado`: `Guid should contain 32 digits with 4 dashes` durante Import File Load causado por `ObjectIdentity/@Type` com valor inteiro (ex.: `Type="1"` ou `Type="8"`).
  `Correção`: substituir o valor inteiro pelo GUID real do tipo correspondente, derivado do campo `Object/@parentType` do XML de origem do objeto empacotado.
- `Erro sanitizado`: `Cannot insert Folder ... already exists in this model`.
  `Correção`: revisar `parentGuid` e `ObjectsIdentityMapping`; não usar identidade de contêiner errada nem reaproveitar container inexistente no destino.
- `Erro sanitizado`: `lastUpdate` novo aplicado a objeto apenas reenviado.
  `Correção`: preservar `lastUpdate` do XML original para objetos não modificados e atualizar apenas o que foi realmente alterado.
- `Erro sanitizado`: pacote grande com objetos não tocados atrasando importação sem ganho funcional.
  `Correção`: reter somente o fecho mínimo da frente atual e excluir artefatos sem mudança efetiva.
- `Erro sanitizado`: `Import File Load` falhando com `Value cannot be null. Parameter name: g` em pacote misto montado com envelope leve por `FilePath`.
  `Correção`: parar de ajustar `ObjectsIdentityMapping` por hipotese e comparar primeiro com export real da IDE para a mesma composicao; no caso validado nesta trilha, a correcao foi remontar o pacote como embutido em `<Objects>`.
- `Exemplo sanitizado ligado à privada`: os casos completos de `EntradaDeTerceiro`, `EntradaDoIndustrializador` e dos pacotes associados ficam referenciados na pasta privada `C:\\Dev\\Knowledge\\GeneXus-XPZ-PrivateMap`; nesta raiz publica ficam apenas os sintomas resumidos e as correcoes operacionais.

## Vocabulario operacional de fonte e molde

- `Molde bruto comparavel`: XML bruto real do mesmo `Object/@type` e de familia estrutural próxima, usado para materialização final quando a base ainda não tem anexo completo suficiente.
- `Molde sanitizado documentado`: XML completo e sanitizado embutido nesta base, preservando estrutura suficiente para leitura e, em casos suportados, para geração controlada sem recorrer ao acervo bruto.
- `Envelope XPZ observado`: estrutura externa `<ExportFile>` documentada acima, derivada de export real inspecionado nesta trilha.
- `Resumo textual`: tabelas, frequencias, heuristicas e explicacoes. Serve para decidir; sozinho não substitui um molde XML completo.

## Politica para compatibilidade de `Source`

- `Regra operacional`: `Source` GeneXus plausivel não deve ser tratado como `Source` pronto apenas por parecer sintaticamente valido.
- `Regra operacional`: a base primaria para aceitar novo `Source` nesta trilha é a própria documentação metodologica, em duas formas: regra explicita e exemplo sanitizado ou molde documentado.
- `Regra operacional`: o corpus real da KB, quando existir, entra como reforco, confirmacao ou desempate; ele não substitui a base metodologica da trilha.
- `Regra operacional`: isso vale também para KB nova ou pouco povoada; a camada metodologica da trilha deve bastar para orientar a geração conservadora sem depender de corpus rico.
- `Regra operacional`: antes de consolidar um `Source` novo ou alterado, materializar explicitamente os itens novos introduzidos pela mudanca em quatro grupos: `operadores`, `funcoes`, `conversoes` e `padroes string/numerico`.
- `Regra operacional`: cada item novo desses grupos deve apontar pelo menos uma base metodologica desta trilha: regra explicita, exemplo sanitizado ou molde documentado.
- `Regra operacional`: se um item novo estiver sustentado apenas por intuicao, memoria genérica de GeneXus ou ocorrência isolada do corpus local sem amparo metodologico da trilha, o `Source` não deve ser consolidado.
- `Regra operacional`: quando não houver base metodologica suficiente para um item essencial do `Source`, o agente deve reescrever a solucao usando padrão já documentado ou abortar a consolidacao.
- `Regra operacional`: `XML` bem-formado, envelope correto, `Load` parcial ou `runtime` plausivel não substituem validação de compatibilidade do dialeto de `Source` aceito nesta trilha.

### Decisão operacional para `Source`

- `Prosseguir`: todos os itens novos do `Source` estao ancorados em regra explicita, exemplo sanitizado ou molde documentado desta trilha.
- `Prosseguir com ressalva`: a trilha cobre o padrão principal e o corpus local apenas confirma ou desempata a escolha.
- `Hipotese`: permitido apenas para análise; não autoriza consolidar `Source` final nem empacotar.
- `Abortar`: item essencial do `Source` sem base metodologica suficiente na trilha e sem reescrita para padrão documentado.

## Ligacao estrutural com runtime GeneXus

- `Evidência direta`: no acervo desta KB, `Transaction` aparece em 183 objetos, todos com `parent`, todos com `Level`, e 177/183 com `AttributeProperties`.
- `Evidência direta`: `WebPanel` aparece em 1196 objetos; 1195/1196 possuem `parent`; 437/1196 mostram sinal estrutural de eventos; 25/1196 exibem sinal textual de `grid`.
- `Evidência direta`: `Procedure` aparece em 2281 objetos, todos com `parent`; `DataProvider` em 24, todos com `parent`; `API` em 1, com `parent`; `WorkWithForWeb` em 183, todos com `parent`, `Level` e marca de pattern no bloco `<Data Pattern=\"...\">`.
- `Regra documentada`: em GeneXus, a determinacao de `Base Table` e a navegacao associada dependem dos atributos usados, do `For each`, da `Base Transaction clause`, da estrutura do objeto e dos eventos envolvidos.
- `Inferência forte`: por isso, a estrutura XML permite detectar objetos mais ou menos propensos a joins implicitos, dependencia contextual e carga extra, mas não substituir o relatório de navegacao nem a especificacao real da IDE.
- `Regra operacional`: ao editar `WorkWithForWeb`, não validar apenas o envelope externo do pacote; validar também o XML interno reconstruido do `CDATA` em `Data`, porque erros de fechamento em `variable`, `attributes`, `filter`, `tab` ou `view` podem surgir só no `Load/Import` pela IDE.

## Regras documentadas de runtime

### Base Table e Extended Table

- `Regra documentada`: a `Base Transaction clause` declara a intencao de navegacao e pode ser usada em `For each` e em grupos de `Data Provider` para definir a tabela base com mais clareza e reduzir ambiguidade de especificacao.
- `Regra documentada`: quando um `For each` declara uma `Base Transaction`, a tabela associada passa a ser a `Base Table`, e atributos usados no corpo, filtros e ordens precisam estar na `Extended Table` correspondente.
- `Regra documentada`: GeneXus também pode determinar a `Base Table` implicitamente a partir dos atributos presentes, inclusive em grids e eventos `Load`.
- `Inferência forte`: logo, objetos com muitos atributos de diferentes contextos, FKs paralelas ou múltiplos níveis tendem a ser mais sensiveis a efeitos de `Extended Table`, filtros condicionais e custo de navegacao.
- `Regra operacional`: em `For each`, a análise prática é sempre sobre a `Base Table` determinada, seja ela explicita no cabeçalho ou implicita pelo conjunto de atributos usados no bloco.
- `Regra operacional`: se a `Base Table` for implicita, o conjunto coerente de atributos do corpo, `Where`, `Order` e demais referencias que participam da navegacao determina a tabela base; atributos fora dessa tabela ou fora do contexto coerente de `Extended Table`/subtype não devem ser aceitos no bloco.
- `Regra operacional`: ao revisar um `For each`, checar primeiro a tabela base real e só depois validar se cada atributo pertence a essa base ou ao contexto coerente da navegacao.

### Navegacao, filtros e loops

- `Regra documentada`: `For each` e grupos de `Data Provider` são pontos centrais de navegacao; filtros, ordens e atributos fora da tabela base podem alterar joins, subselects e forma de acesso.
- `Regra documentada`: quando ha `Load` sobre grid ou painel com base implicita, um `For each` escrito dentro do evento pode ficar aninhado em uma navegacao implicita já existente.
- `Inferência forte`: isso aumenta o risco relativo de padrões do tipo `N+1`, carga repetida por linha e custo difícil de perceber olhando apenas o XML final.
- `Hipótese`: em objetos com muito código de evento e muitos controles ligados a dados, a ausencia de relatório de navegacao detalhado torna prudente assumir performance potencialmente sensivel ate prova em contrario.
- `Regra operacional`: ao alterar filtro de identidade, unicidade, contagem, existência, selecao candidata ou ambiguidade em um `for each`, procurar no mesmo `Source` outros blocos próximos ou semanticamente relacionados sobre a mesma tabela/base.
- `Regra operacional`: tratar pares como `count/then-copy`, `exists/then-load`, `validate/then-apply` e `select-candidate/then-materialize` como unidade lógica quando um bloco define o conjunto candidato e outro materializa, copia, carrega ou aplica o registro selecionado.
- `Regra operacional`: classificar esses blocos irmaos, por exemplo como `candidate/count query`, `existence/validation query`, `materialization/copy query` ou `load/apply query`, e validar que os critérios de identidade do registro permanecem coerentes.
- `Regra operacional`: se a mudanca afetar a identidade do registro candidato, ajustar ou reconciliar todos os blocos irmaos relacionados; alterar apenas um bloco exige justificativa explicita antes de empacotar.

### WebPanel, Refresh e Grid

- `Regra documentada`: o `Refresh event` e o `Refresh Grid event` são executados antes da carga/re-carga dos dados exibidos, e o `Load event` pode ser executado para cada linha quando ha grid com base de navegacao.
- `Regra documentada`: em Web, os eventos de refresh usam ciclo Ajax; isso melhora a troca com o cliente, mas não elimina custo server-side de navegacao e carga de dados.
- `Evidência direta`: em `WebPanel`, declarar `Event &Variavel.ControlValueChanged()` mesmo vazio registra roundtrip Ajax implicito para a variável, em vez de funcionar como marcador inofensivo.
- `Regra operacional`: remover `ControlValueChanged` vazio deve ser lido como ajuste de performance e previsibilidade, não apenas como limpeza cosmetica de código.
- `Regra operacional`: não posicionar `SetFocus()` em `Event Refresh` quando o foco desejado depender de uma ação específica; por ser escopo global de refresh Ajax, esse evento tende a reaplicar foco em momentos laterais e produzir salto inesperado.
- `Regra operacional`: quando houver necessidade real de reposicionar foco em `WebPanel`, preferir `Event Start`, `Event Enter`, `Event Click` ou `Sub` chamado por evento explicitamente controlado.
- `Inferência forte`: `WebPanel` com `events` + `grid` + ações + `parent` contextual tende a merecer cautela runtime maior que uma casca mínima sem eventos.
- `Inferência forte`: `WebPanel` gerado por pattern/defaults ou acoplado a `MasterPage` e seguranca integrada tende a depender mais do contexto da KB do que um painel isolado e pequeno.

### WebPanel, Tab aninhada e re-bind de SDT em data attributes

- `Evidência direta`: em `WebPanel` com Tab externa contendo outra Tab interna cujas sub-abas exibem campos bindados em `&Sdt.<membro>` via data attributes, a sub-aba default da Tab interna aparece vazia na primeira ativacao da aba externa correspondente, mesmo com o SDT já populado server-side; o workaround manual eh clicar em outra sub-aba e voltar.
- `Inferência forte`: o re-bind das data attributes nas sub-abas internas eh disparado client-side quando o framework JS recebe a chamada `ajax_rsp_assign_sdt_attri(..., AV<NomeSdt>, AV<NomeSdt>)` no `.cs` gerado; sem evento server-side que marque o SDT como mutado, essa chamada não eh emitida.
- `Regra operacional`: para forcar a emissao, declarar `Event <OuterTab>.TabChanged` com branch por `<OuterTab>.ActivePageControlName`, dentro da branch fazer `touch opaco` em UM membro do SDT via proc helper identidade (`parm(in:&T, out:&T)` com corpo `&Volta = &Vinda`) e chamar `<InnerTab>.SelectTab(2)` seguido de `<InnerTab>.SelectTab(1)`; o par `(2);(1)` emula o click manual do usuário e gera duas chamadas `executeUsercontrolMethod "SelectTab"` no `.cs`, suficientes para o cliente processar o re-bind.
- `Regra operacional`: aplicar o touch em UM MEMBRO do SDT, nunca no SDT inteiro; proc com `parm(in:&Sdt, out:&Sdt)` aplicada ao SDT inteiro funciona para serializacao, mas o `out` reatribui a identidade do SDT e pode quebrar o binding de WebComponents irmaos em outras abas externas.
- `Anti-pattern`: `&sdt = &sdt`, `&sdt.<membro> = &sdt.<membro>`, `&sdt.<campo> = &sdt.<campo> + ""`, `&sdt.FromJson(&sdt.ToJson())`, `&sdt.FromJSonString(&sdt.ToJSonString(false))` e `Refresh` sozinho não funcionam — os primeiros são eliminados como no-op pelo dead-code do gerador (handler stripado do `.cs` sem erro nem warning), `FromJson/ToJson` não existem na API, `FromJSonString/ToJSonString` não estao expostos a camada de eventos e `Refresh` mantem o handler vivo mas não inclui o SDT no `oparms` — para a diferenca estrutural entre rejeicao na importação (`src0294`, mecanismo a) e strip silencioso por DCE (mecanismo b), ver subsecao `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`.
- `Anti-pattern`: `<InnerTab>.SelectTab(1)` sozinho, quando a sub-aba 1 já eh a ativa default, eh no-op no cliente; o par `(2);(1)` eh o que produz o efeito.
- `Procedimento de verificacao no .cs gerado`: após build, no `<wpName>.cs`, confirmar (1) que o handler do evento existe (busca por `TABCHANGED` ou nome do evento); (2) que o SDT aparece no `oparms` do evento — buscar `setEventMetadata("<EVENTO>", ... "oparms":[...])` e verificar `<NomeAvDoSdt>` no array; (3) que a chamada `ajax_rsp_assign_sdt_attri("..", false, "<NomeAv>", <NomeAv>)` está no corpo do handler. Handler stripado por DCE significa que falta operacao reconhecivel pelo gerador; SDT ausente do `oparms` significa que o write em membro não foi detectado como mutacao real.
- `Escopo da evidência`: padrão observado em um `WebPanel` real (`wpGtaConsultaDoGoverno` em Gx_FabricaBrasil), com duas branches por outer tab e familia local de procs helper por tipo (`procVoltaDo<Tipo>QueFoi`); aplicabilidade em `Panel SD` não foi verificada localmente e deve ser validada caso a caso quando a estrutura de eventos for equivalente.

### Procedure, Data Provider, Transaction e API

- `Regra documentada`: `Procedure` e `Data Provider` podem disparar navegacoes a partir de `For each`, grupos e atributos usados; o runtime relevante depende mais do código e da base implicita do que do simples inventario de `Part`.
- `Regra documentada`: `Transaction` descreve estrutura transacional e níveis; sua sensibilidade runtime cresce quando ha subniveis, relacoes pai-filho e maior densidade de atributos relacionais.
- `Inferência forte`: `Transaction` com múltiplos `Level` sugere maior probabilidade de joins implicitos, contexto pai-filho e custo de manutencao/performance superior ao de `Transaction` de um nível.
- `Inferência forte`: `API` com bloco `Service`, `RestMethod`, eventos `.Before/.After` e chamadas a `Procedure` sugere camada de orquestracao server-side; o XML não prova custo, mas indica dependencia de código interno e contexto de seguranca/sessao.
- `Hipótese`: `DataProvider` pequeno e direto, com poucos filtros e saida simples, tende a ser menos arriscado em runtime do que `Procedure` ou `WebPanel` com eventos cruzados e composicao de tela.

### Mecanismos de descarte de código de evento pelo gerador GeneXus

- `Evidência direta`: o gerador pode silenciar código de evento por dois caminhos estruturalmente distintos, e o diagnostico exige diferencia-los.
- `Mecanismo (a) — rejeicao na importacao`: a chamada existe na API do `.cs` gerado mas não está exposta a camada de eventos GeneXus (caso observado: `ToJSonString`/`FromJSonString` no SDT). O import via MSBuild falha com mensagem `Unknown function '<nome>'` (código `src0294` ou similar), `exitCode != 0` e número de linha/coluna apontando o source do evento; o objeto NÃO eh atualizado na KB.
- `Mecanismo (b) — strip silencioso por dead-code elimination`: o corpo do evento contem apenas operacoes que o gerador classifica estaticamente como no-op (ex: `&x = &x`, `&sdt.<m> = &sdt.<m>`, `&str = &str + ""`). O import passa, o build passa, sem erro nem warning; o handler do evento simplesmente não aparece no `.cs` gerado, ou aparece com corpo vazio.
- `Procedimento de diagnostico`: (1) conferir o `import.json` do wrapper `Invoke-GeneXusXpzImport`; `errors` presentes ou `exitCode != 0` indicam mecanismo (a) — ler a mensagem para identificar a função rejeitada. (2) se import OK mas o comportamento esperado não aparece em UI, buscar no `.cs` gerado pelo nome do evento; zero ocorrências indica strip por DCE (mecanismo b). (3) para escapar de (b), incluir no corpo do evento operacao opaca ao otimizador — tipicamente chamada a proc externa que escreva em variável observada; `Refresh` sobrevive ao DCE mas tem outros limites (ver subsecao `WebPanel, Tab aninhada e re-bind de SDT em data attributes` para o caso em que `Refresh` mantem o handler mas não inclui o SDT no `oparms`).
- `Regra operacional`: ao investigar código de evento que parece não executar, sempre identificar PRIMEIRO se o caso eh (a) ou (b) antes de mexer no source — a ação corretiva eh diferente em cada caso.
- `Regra operacional`: para `Transaction` com sintoma de atributo que não reflete na UI após import OK e geração disponível, resolver primeiro o `.cs` web por `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (ou wrapper local) a partir de `kb_environment_web_dirs`; em seguida mapear atribuicoes com `scripts/Find-CsAttributeAssignments.ps1` (`-CsPath` absoluto resolvido, `-Attribute`, `-AsJson`) antes de concluir que a rule foi eliminada; distinguir copias sem `AssignAttri` no mesmo método e padrão triplet do Specifier (`cascadeOrder` em `if/else if` mutuamente exclusivos). Não substitui busca por nome de evento/handler em `WebPanel` (mecanismo b).
- `Regra operacional` (quarentena XPZ para `Transaction`): `tripletPattern.cascadeOrder` em `Find-CsAttributeAssignments.ps1` é evidencia de ordem efetiva no `.cs` gerado, não catalogo geral de modelagem GeneXus. Para o anti-padrao nomeado e a correcao por inversao textual de `Rules`, ver `transaction-attribute-rule-shadowed-by-default-in-cascade` na seção **Anti-padroes nomeados (`Transaction` — motor XPZ)**.

### Diagnostico de código gerado truncado por falha de generation

- `Evidência direta`: em build pos-generation, erros `CS1010` (Newline em constante) e `CS1513` (`}` esperada) repetidos no `.cs` referenciado podem indicar truncamento do arquivo gerado, não erro real no XML do objeto. Caso observado: linha final do `.cs` com menos chars do que o esperado, terminando no meio de uma string literal sem aspa de fechamento e sem newline final.
- `Causa tipica`: o gerador GeneXus interrompeu a geração no meio da escrita do `.cs` — processo cancelado, exception interna, falta de espaco em disco, IDE travada, etc. O MSBuild compila o arquivo incompleto e os erros C# apontam para a regiao do truncamento.
- `Heuristica para distinguir do erro real no XML`: antes de investigar o XML, conferir no `.cs` referenciado se (i) a linha final termina abruptamente, (ii) ha chamada de função em aberto, (iii) ha string literal não fechada, (iv) o arquivo termina sem newline final e (v) o total de linhas eh inferior ao esperado para o tamanho do objeto. Comparar a regiao com a mesma regiao em outro environment da mesma KB ou em uma KB irma onde a geração tenha completado: o código gerado em torno do mesmo controle deve ser estruturalmente identico.
- `Regra operacional`: antes de mexer no XML, executar primeiro uma regeneracao controlada do objeto ou do conjunto mínimo afetado. Em fluxo MSBuild cotidiano, preferir `BuildAll`/`SpecifyGenerate` sem `-ForceRebuild`; `Rebuild All`/`ForceRebuild=true` continua sendo regeneracao ampla e só pode ser usado com o gate de `-AllowWideRebuild` e confirmacao explicita. Se o sintoma persistir após a regeneracao limpa, ai sim investigar o XML.

### Saida do gerador GeneXus por environment

- `Evidência direta`: para a mesma KB com a mesma versão do objeto, o gerador GeneXus pode produzir código `.cs` materialmente diferente entre environments. Caso observado: `Default` (.NET Framework, env CSharpModel) compilando para `net48` e `NETPostgreSQL` (target Core, env equivalente) compilando para `net8.0`; layout do código, runtime APIs disponíveis e detalhes de geração variam.
- `Inferência forte`: um fix de código de evento validado em um environment não se transfere automaticamente para outro; o fix valida o XML, não a saida final do gerador.
- `Regra operacional`: distinguir **validação alinhada ao deploy (objetivo A)** — um environment, o que IIS/self-host executa (`deployment_environment_name`, headless com `xpz-msbuild-build`, gate de deploy-bin quando aplicavel) — de **fix completo multi-environment (objetivo B)** — quando a frente exigir fechamento em mais de um generator ativo, não basta A sozinho.
- `Regra operacional`: objetivo B **não** exige orquestrador headless nem loop automático por `kb_environment_names`. Prática usual e suficiente: após A bem-sucedido no environment de deploy, **Build na IDE** nos demais environments ativos que a frente ainda cobre (consultar `kb_environment_names` no metadata); conferir compilacao e, se houver duvida, resolver o `.cs` pelo `kb_environment_web_dirs` do metadata (`Resolve-GeneXusGeneratedCsPath.ps1` ou wrapper local) ou, manualmente, pelo output dir declarado em `kb_environment_output_dirs` (`<KbNative>\<OutputDir>\web\`); não usar o nome do environment como pasta por inferencia. Headless repetido com `-EnvironmentName` e opcional, não padrão.
- `Regra operacional`: objetivo B e **opt-in por frente** — não é gate pos-import automático. Quando o deploy principal passou e o segundo environment e buildado na IDE ao encerrar, falha ai e **rara**; priorizar A + Ponto 2 no fluxo agente/headless. Inventario `kb_environment_count`/`kb_environment_names` e mapeamento `kb_environment_output_dirs`/`kb_environment_web_dirs` ficam em `kb-source-metadata.md` (setup: lista e output dirs declarados pelo usuário em `-KbEnvironmentNames`/`-KbEnvironmentOutputDirs` + validação MSBuild obrigatória; sem scan de pastas); build/import não revarrem a KB nativa para contar environments.
- `Regra operacional`: `CSharpModel\web` e compartilhado entre environments; timestamps frescos ali **não** provam que o `web\bin` do output de deploy foi atualizado. Não usar só `Test-GeneXusRuntimeFreshness.ps1` para concluir validação deploy em KB multi-environment. Validação deploy pos-import: wrappers com `-PostImportDeployValidation` checam publicacao no destino de deploy por família — **.NET**: `web\bin` resolvido por `kb_environment_web_dirs` (max timestamp de DLL de objeto excluindo runtime GeneXus/System/Microsoft, ou `*.config`); **`java-tomcat`**: co-gate Java no `WEB-INF\classes` externo (por `kb_environment_servlet_dirs`/`_app_package`) — em Core, `GxNetCoreStartup.dll` e só complementar (warning se velho em build incremental); status `compilou-mas-dll-destino-desatualizada` ou exit **49** quando gate ativo sem evidencia de publicacao. O gate decide por **sucesso operacional factual** (MSBuild `exitCode` 0 + marcador de conclusao do build), não pela string de status: rebaixamento benigno (evento pos-build como sino de fim de build, ruido em stderr) **não** suprime `-PostImportDeployValidation`; só falha real (Categoria B, reorg, timeout, KB inacessivel — que derrubam o `exitCode`) pula o gate.
- `Regra operacional`: eventos pos-build no stdout (ex.: sino de fim de build, script de deploy `.Bat`) **não** rebaixam o status cegamente. O wrapper classifica cada evento contra `kb_environment_post_build_event_hashes` do environment ativo em `kb-source-metadata.md`: registrado = esperado (informativo, não rebaixa); não registrado = inesperado (rebaixa por cautela); linha comentada (`REM`) e inerte e nunca conta. Sem registro para o environment, rede de seguranca reconhece player de som (`SoundPlayer`/`PlaySync`/`.wav`) como benigno e rebaixa o resto. Registrar eventos legitimos via `xpz-kb-parallel-setup` (`Register-GeneXusKbPostBuildEvents.ps1`, autoria do campo); inspecionar `stdoutSignals.postBuildEventClassification` no diagnostico.
- `Regra operacional`: para diagnostico pontual de `.cs` gerado, não fazer glob recursivo em `C:\GxModels` nem inferir diretório por nome parecido de pasta. Usar `scripts\Resolve-GeneXusGeneratedCsPath.ps1` com `-KbPath`, `-ParallelKbRoot` ou `-KbMetadataPath`, `-EnvironmentName` quando necessário e `-ObjectName`; o script le `kb_environment_web_dirs` em `kb-source-metadata.md` e monta `<webDir>\<objeto-lowercase>.cs`. Se o metadata não tiver `kb_environment_web_dirs` para o environment, bloquear e executar `xpz-kb-parallel-setup` para reconciliar `kb-source-metadata.md`; não aceitar chute de diretório como substituto. **Exceção (guarda de família do Eixo B):** KB com `deployment_hosting_kind` de família não-.NET (`java-tomcat`, `sourceSupportState=recognized-no-engine`) **pula** com `status=CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`/exit 0 **antes** desse bloqueio — o resolvedor não exige `web_dirs` para o skip (o artefato Java não é `.cs`; o motor Java do Eixo B é Pós-v1 — o Eixo A/deploy-bin já tem co-gate desde a Fase 3).

## Politicas específicas para tipos contextuais

### Politica para `Transaction`

- `Evidência direta`: o teste isolado com `Transaction 'TRNExemploMinBancoA'`, seus `Attribute` top-level reais, `SDT 'Context'` e `SDT 'TransactionContext'` importou com sucesso.
- `Evidência direta`: nesse mesmo teste houve geração de pattern bem-sucedida para `WWExemploMinBancoA`.
- `Evidência direta`: em teste controlado separado, um pacote contendo apenas `Transaction` falhou com erro do tipo `Attribute 'X' in 'Transaction Y' does not exist` quando os atributos referenciados no `<Level>` não existiam na KB de destino.
- `Evidência direta`: no mesmo cenário, ao incluir no mesmo pacote os `Attribute` top-level correspondentes, a importação passou a reconhecer os atributos e avancou para a validação estrutural da `Transaction`.
- `Evidência direta`: após ajuste do shape do `Level` e dos `Part`, o pacote contendo `Attribute + Transaction` foi importado com sucesso completo, incluindo atualizacao de tabela.
- `Inferência forte`: quando o molde de `Transaction` usa `Context`, `TrnContext` ou `TrnContextAtt`, os SDTs de contexto correspondentes deixam de ser detalhe auxiliar e passam a ser dependencias de primeira classe do pacote.
- `Inferência forte`: quando a KB de destino não contem previamente os atributos referenciados pela `Transaction`, o pacote mínimo precisa inclui-los como `Attribute` top-level, e não apenas como referencias inline no `Level`.
- `Regra operacional`: antes de materializar `Transaction`, validar nesta ordem: familia estrutural correta, atributos reais do `Level`, `SDT 'Context'`, `SDT 'TransactionContext'` e só depois regras/eventos mais específicos.
- `Regra operacional`: ao gerar pacote mínimo de `Transaction`, verificar primeiro se os atributos do `Level` já existem na KB de destino; se não existirem, incluir `Attributes` top-level correspondentes no mesmo pacote.
- `Regra operacional`: erro em `ATTCUSTOMTYPE` de `sdt:Context`, `sdt:TransactionContext` ou `sdt:TransactionContext.Attribute` deve ser lido como falta de dependencia contextual, não como falha do envelope XML.
- `Regra operacional`: não confiar que o GeneXus criara automaticamente atributos implicitos a partir do `Level`; no caso validado, a ausencia explicita levou a erro de validação.
- `Evidência direta`: em trilha posterior validada na IDE, um pacote misto com `4` `Attribute` top-level, `1` `Transaction` e `1` `WorkWithForWeb` importou com sucesso e concluiu também a geração do pattern associado.
- `Regra operacional`: quando a alteracao de `Transaction` impactar atributos exibidos, filtros, abas ou navegacao do pattern web, revisar também o `WorkWithForWeb` associado antes de considerar a frente fechada.
- `Regra operacional`: ao diagnosticar rule ou atributo `Transaction` no código gerado da camada web, resolver primeiro o `.cs` da transacao com `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (ou wrapper local) e entao usar `scripts/Find-CsAttributeAssignments.ps1` no caminho absoluto resolvido após build ou `SpecifyGenerate` quando o artefato estiver disponível; consumo complementar documentado em `xpz-msbuild-build/SKILL.md`.

#### Politica de evidencia para catalogos `Transaction` (geração XPZ)

Esta subsecao complementa os **níveis de confianca de fonte** do inicio deste documento (`Evidencia direta`, `Inferencia forte`, etc.) com rotulos **específicos de permissao de geração** para catalogos consultaveis de `Rules`/`Events` em `Transaction` (fonte canônica do catalogo: `xpz-builder/responsibilities-by-type/transaction.md`). Os rotulos abaixo respondem: *o agente pode materializar esta sintaxe no XML/XPZ agora?*

| Rotulo | Significado | Permissao de geração |
|--------|-------------|----------------------|
| `confirmado-import` | Aceitacao ou rejeicao observada na importação MSBuild/Specifier, com mensagem e `exitCode` rastreaveis | Sintaxe rejeitada: **não gerar**. Sintaxe aceita: pode gerar após demais gates |
| `confirmado-build` | Observado em `BuildAll`/`SpecifyGenerate` (ex.: `spc0150`), com mensagem rastreavel | Idem |
| `confirmado-acervo` | Uso real no XML da pasta paralela (`ObjetosDaKbEmXml/...`) após sync recente, ou molde sanitizado reproduzivel nesta base (`01*`) | Pode gerar a sintaxe listada, sujeito a gates de writability e coerência |
| `padrao-gx-nao-verificado` | Convencao ou documentação GeneXus sem teste nesta base nem no acervo paralelo da sessao | **Não usar como premissa de geração**; leitura humana ou pesquisa antes de testar |
| `nao-listar` | Sem evidencia mínima | **Não entra** no catalogo publicado |

Regras de uso:

- `Regra operacional`: cada linha de catalogo `Transaction` (clausula `on <evento>`, tipo de `Event`, sintoma→erro) deve trazer **exatamente um** rotulo da tabela acima.
- `Regra operacional`: **só gerar** sintaxe com rotulo `confirmado-import`, `confirmado-build` ou `confirmado-acervo`. Itens `padrao-gx-nao-verificado` ficam em subsecao separada, titulada de forma explicita (ex.: «Padrão GeneXus — não verificado nesta base»), e nunca misturados na mesma tabela que itens confirmados.
- `Regra operacional`: não promover item a `confirmado-*` apenas por relato de outro agente, lista do prompt ou documentação offline; exige import/build reproduzivel na KB alvo **ou** leitura do XML no acervo paralelo **ou** molde sanitizado versionado nesta raiz.
- `Regra operacional`: mensagens de erro do Specifier com texto literal estavel (ex.: `src0056: Missed ';' at the end of the rule`, `spc0150: Cannot update database`) podem constar com `confirmado-import` ou `confirmado-build` **sem** hospedar o XML da `Transaction` neste repositório — a evidencia é o contrato motor + classificação MSBuild, não o objeto de negocio.
- `Regra operacional`: citacoes por nome de arquivo (ex.: `Animal.xml`, `VendaPedidoItens.xml`) com `confirmado-acervo` devem indicar que o artefato está na **pasta paralela da KB** (`ObjetosDaKbEmXml/...` após sync), salvo quando o exemplo for **molde sanitizado** em `01*` com rastreabilidade em `09`/`GeneXus-XPZ-PrivateMap`; não tratar esses paths como arquivos desta raiz `GeneXus-XPZ-Skills`.
- `Regra operacional`: completude aparente de catalogo é risco operacional — listas longas sem rotulo honesto induzem o agente a tentar sintaxe não validada; preferir catalogo menor e rotulado a checklist aparentemente exaustiva.

#### Anti-padroes nomeados (`Transaction` — motor XPZ)

Catalogo consultavel (sintaxe aceita/rejeitada): `xpz-builder/responsibilities-by-type/transaction.md`, seção **Catalog: `on <event>` clauses…**. Uso correto de rules e gatilhos GeneXus: documentação de produto e skill **nexa** — não duplicar aqui.

Não confundir `src0056` em `Transaction` `Rules` com o playbook de `Procedure` de relatório no mesmo `02` (la o sintoma costuma ser fechamento de `parm(...)` ou terminador de rule no relatório).

##### `transaction-rule-on-event-with-attribute-parameter`

- **Sintoma observado**: import MSBuild/Specifier falha na `Transaction` com mensagem de pontuacao na rule; o agente tenta “corrigir `;`” ou reordenar a expressao sem remover o gatilho com parâmetro.
- **Erro exato (Specifier)**: `src0056: Missed ';' at the end of the rule. (Transaction '<nome>' Rules, Linha: <n>, Char: <c>)` — `confirmado-import` na trilha XPZ (GeneXus 18).
- **Causa raiz**: forma `on <evento>(<atributo>)` ou `on AfterValidate(<Attribute>)` em rule declarativa de `Transaction` **não é aceita** pelo motor testado; o `(` após o evento é token inesperado e o diagnostico aponta o fim da rule anterior.
- **Correcao idiomatica**: não tratar como erro genérico de `;`. Remover o parâmetro entre parenteses; não gerar essa forma no XPZ. Usar apenas clausulas `on <evento>` sem parâmetros conforme catalogo 1 no satelite `transaction.md`. Para “depois de validar este campo” ou timing de field-out, consultar **nexa**/produto — não simular com `on (...)` na rule.

##### `transaction-event-attribute-assignment-rejected`

- **Sintoma observado**: import pode ter passado; `BuildAll`/`SpecifyGenerate` falha na `Transaction` ao atribuir valor a atributo da transacao dentro de `Events` (ex.: reacao “na hora” a mudanca de outro campo).
- **Erro exato (Specifier)**: `spc0150: Cannot update database. Changes to database are only allowed in procedures. (Transaction '<nome>' Events, Linha: <n>)` — `confirmado-build` na trilha XPZ.
- **Causa raiz**: atribuicao a atributo da própria `Transaction` no bloco `Events` é tratada como atualizacao de base; o Specifier rejeita — persistencia de valor de atributo pertence a rules declarativas (e a gates de writability), não a `Event`.
- **Correcao idiomatica**: mover a lógica de valor para `Rules`; no `Event`, limitar-se a superficie UI (`.Caption`, `.Visible`, `.Enabled`), variáveis, `msg`/`Error`, chamadas a procedure, `SetFocus` — ver catalogo 2 no satelite. Não repetir a mesma atribuicao no `Event` após `spc0150`.

##### `transaction-attribute-rule-shadowed-by-default-in-cascade`

- **Sintoma observado**: rule de atribuicao existe no XML, eh aceita pelo Specifier, importa OK e builda OK; em runtime o atributo não recebe o valor esperado da rule, recebendo o `Default(...)` por proc (frequentemente `0`) ou ficando vazio. Via edicao web, o sintoma tipico e campo de FK derivada continuar vazio depois de tabular do atributo gatilho, mesmo com rule no XML que indicaria preenchimento.
- **Erro do Specifier**: nenhum. A patologia não aparece como erro de importação, especificacao, geração ou compilacao; exige inspecao do `.cs` gerado da camada web.
- **Causa raiz**: `Default(...)` e rule de atribuicao sobre o mesmo atributo podem virar cascata `if`/`else if` mutuamente exclusiva no `.cs` gerado em métodos como `OnLoadActions<KbId>`, `CheckExtendedTable<KbId>`, `Valid_<FKDoLado>` e `GX<n>ASA<ATTR><KbId>`. A ordem textual no XML determina a ordem dos branches; quando o default fica antes da rule, ele pode sombrear a atribuicao pretendida.
- **Correcao idiomatica**: inverter a ordem textual no XML da frente, colocando a assignment rule antes de `Default(...)`. Aplicar via `scripts/Edit-GeneXusXmlSurgical.ps1` com `-DryRun`, ancora literal, `-ExpectedAnchorCount` e baseline de `lastUpdate` quando houver; não reserializar a `Transaction` inteira. Revalidar por import/build e nova leitura do `.cs`.
- **Verificacao**: resolver o `.cs` com `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (ou wrapper local) e executar `scripts/Find-CsAttributeAssignments.ps1` antes e depois (`-CsPath` absoluto resolvido, `-Attribute`, `-AsJson`). `tripletPattern.cascadeOrder` deve mudar de `override-then-default-then-fallback` para `override-then-fallback-then-default`.
- **Evidencia**: `confirmado-acervo` na trilha XPZ (`VendaPedido` em pasta paralela após sync) e `confirmado-build` por inspecao reproduzivel do `.cs` antes/depois.
- **Nota de escopo (quarentena XPZ)**: este conhecimento pertence naturalmente a modelagem GeneXus e a skills de produto como **nexa**. Ele fica documentado aqui porque o diagnostico operacional usa `scripts/Find-CsAttributeAssignments.ps1`, a correcao aprovada acontece no XML da pasta paralela via helper XPZ, e a skill **nexa** não é contribuivel por esta base. Se **nexa** ou skill equivalente se tornar contribuivel, esta entrada e candidata a migracao; não generalizar para outros temas semanticos GeneXus sem o mesmo critério de diagnostico e correcao dentro do escopo XPZ.

##### `transaction-default-rule-with-conditional`

- **Sintoma observado**: import MSBuild/Specifier falha na `Transaction` ao escrever uma rule `Default(<Atributo>, <expressão>)` seguida de cláusula condicional (`... if <condição>;`); o agente tende a ajustar pontuacao ou reordenar a expressao em vez de remover o condicional do `Default`.
- **Erro exato (Specifier)**: `src0239: 'Default' rule does not support a conditional expression. (Transaction '<nome>' Rules, Linha: <n>, Char: <c>)` — `confirmado-import` na trilha XPZ (GeneXus 18 U13 + WorkWithPlus_Web 16.0.3.1; reproduzido em `OperacaoItem` na KB FabricaBrasil18 / environment NETPostgreSQL, `importTaskSuccess=false`).
- **Causa raiz**: a rule `Default(<Atributo>, <expressão>)` define o **valor inicial** do atributo quando ele está vazio e **não aceita** cláusula condicional; o `if` apos a expressao e token inesperado e o Specifier barra no import. Forma rejeitada observada: `Default(OperacaoItemTituloIntermediarioEmpresaId, procEmpresaPessoa()) if not OperacaoItemTituloIntermediarioId.IsEmpty();`.
- **Correcao idiomatica**: não tratar como erro generico de sintaxe. Manter o `Default(...)` **incondicional** e, quando a intencao for atribuir condicionalmente, mover a condicao para uma **rule de assignment** separada (`<Atributo> = <expressão> if <condição>;`). **Atencao (sem equivalencia de runtime)**: as duas formas **não** são equivalentes — `Default` da valor inicial quando o atributo esta vazio; a assignment avalia a rule sob seu proprio gatilho. Documentar como forma idiomatica que passa no import, **sem** afirmar equivalencia semantica; a escolha correta entre `Default` e assignment condicional e conhecimento de modelagem GeneXus (fronteira **nexa**), como nas irmãs.
- **Relacao com a cascata**: tema relacionado mas **mecanismo distinto** da entrada `transaction-attribute-rule-shadowed-by-default-in-cascade` (acima neste `02`; detalhada na seção «Cascade ordering» do satelite `transaction.md`): `src0239` e **rejeicao no import** (o Specifier barra antes de gerar); a cascata e **sombreamento em runtime** com import/build limpos. **Não confundir** nem fundir.

### Politica para `API`

- `Evidência direta`: a base observa apenas `1` `API` real nesta KB.
- `Evidência direta`: esse caso corresponde a uma construcao manual/local da KB, sem evidencia nesta trilha de ferramenta complementar de automacao de `API`.
- `Evidência direta`: o teste isolado com `APIExemploIntegracaoA` e seus SDTs reais resolveu a camada de erro em `ATTCUSTOMTYPE`.
- `Evidência direta`: depois disso, a `API` passou a falhar por `Procedure` ausente (`PRCExemploListaA`) e por contexto de negocio (`DomainExemploTipoA`, `TRNExemploProdutoA`).
- `Evidência direta`: o export real `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos e mostrou que a `API` desta KB já sai da IDE acompanhada por uma subarvore funcional grande.
- `Inferência forte`: por haver apenas um caso real, a leitura operacional de `API` nesta base deve permanecer ancorada em estudo de caso da KB, e não em suposta familia ampla de APIs GeneXus manuais ou automatizadas.
- `Inferência forte`: a hierarquia de validação de `API` nesta trilha é: primeiro `ATTCUSTOMTYPE`/SDTs, depois `Procedure`, e por fim atributos, dominios ou contexto de negocio usados no codigo/eventos.
- `Inferência forte`: para `API`, o melhor recorte operacional deixa de ser o objeto isolado e passa a ser uma familia funcional contendo pelo menos `Procedure`, `SDT`, `Domain`, e possivelmente `Transaction`, `Table` e `DataProvider`.
- `Regra operacional`: não regenerar `API` “igual” após erro de `ATTCUSTOMTYPE`; primeiro materializar os SDTs reais e reexecutar. Se o erro remanescente migrar para `Procedure` ou atributo de negocio, tratar a camada semantica seguinte.
- `Calibração (from-spec, 2026-07-01)`: esta seção descreve o perfil **cadeia-grande** (caso único da KB, subárvore funcional). A dimensão **from-spec + GAM/runtime** (tríade autocontida `API`->`Procedure`->`SDT`, importação real ≠ preview, enforcement GAM como pré-condição de runtime) está na seção `## Politica para API` adiante e no `03-risco-e-decisao-por-tipo.md` (`API (cadeia)` vs `API (from-spec)`).

### Politica para `Attribute` em export combinado

- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades.
- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Evidência direta`: nesses dois recortes, a IDE serializou `Attributes` como bloco top-level próprio no mesmo `.xpz` que também carrega `Objects`.
- `Inferência forte`: quando a familia funcional inclui `Attribute` real, `Transaction`, `Domain` e `SubtypeGroup`, o formato normal observado fica mais forte com `Objects` + `Attributes`, e não apenas com `Objects`.
- `Regra operacional`: ao analisar ou materializar pacote centrado em `Attribute` top-level, preservar a separacao entre `Objects` e `Attributes`; não rebaixar `Attribute` real para pseudo-objeto dentro de `<Objects>`.
- `Evidência direta`: no caso publico validado de pacote misto, `Transaction` e `WorkWithForWeb` coexistiram em `<Objects>`, enquanto os atributos novos coexistiram em `<Attributes>`.
- `Regra operacional`: em pacote misto com `Transaction`, `WorkWithForWeb` e atributos novos, manter `Transaction` e `WorkWithForWeb` em `<Objects>` e os atributos top-level em `<Attributes>`.
- `Regra operacional`: se o pacote misto incluir `WorkWithForWeb`, preservar no bloco `Dependencies` a referencia de `Pattern` correspondente.
- `Evidência direta`: no acervo extraido para filesystem Windows, apareceu ao menos um caso real de nome lógico invalido como nome de arquivo (`ThemeClass` com `name="ImageHandCenter:hover"`), materializado em disco como `ImageHandCenter_hover.xml`.
- `Regra operacional`: quando o nome lógico do objeto ou atributo contiver caractere invalido para o filesystem alvo, aplicar normalizacao mínima, deterministica e rastreavel apenas no nome do arquivo em disco, preservando o `name` interno do XML sem alteracao.
- `Regra operacional`: na auditoria de completude entre o XML total e o acervo extraido, comparar por `tipo + nome logico` e considerar explicitamente a camada de normalizacao de filename quando houver caractere invalido para o filesystem.
- `Regra operacional`: a reconciliação do sync em `-FullSnapshot` (`scripts/Sync-GeneXusXpzToXml.ps1`) usa a identidade estável `guid` do nó raiz, não só `tipo + nome logico`: quando o mesmo `guid` aparece no acervo sob nome diferente, o motor trata como rename e renomeia o arquivo no acervo (`Move-Item` antigo → novo), preservando um arquivo só e o histórico git por similaridade; cobre `Attribute` e `Object`. Em `-VerifyOnly`, apenas classifica o resíduo de rename no relatório (`RenameResidualsDetected`), sem tocar o disco. Resíduo de nome antigo removido por rename reconhecido por `guid` não é deleção cega do acervo.

### Politica para `Theme`

- `Evidência direta`: o `Theme 'ThemeExemploMobileA'` falhou isoladamente mesmo sendo objeto real, com ausencia de `Theme class 'TableDetail'`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: quando essas tres `ThemeClass` reais foram importadas junto, o `Theme 'ThemeExemploMobileA'` importou com sucesso.
- `Evidência direta`: o export real `XPZExemploTemaA.xpz` mostrou a pilha visual exportada como familia combinada.
- `Inferência forte`: nesta trilha, `Theme` deve ser tratado como dependente de `ThemeClass` materializadas na KB, e não apenas do XML do próprio tema.
- `Inferência forte`: quando a meta for engenharia reversa da camada visual, `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` devem ser lidos como familia conjunta.
- `Regra operacional`: antes de materializar `Theme`, levantar as `ThemeClass` referenciadas pelo grafo mínimo do tema e inclui-las no pacote.
- `Regra operacional`: falha “Theme class X does not exist” deve ser tratada como dependencia faltante de `ThemeClass`, não como prova de erro no `Theme` principal.

### Politica para `PatternSettings`

- `Evidência direta`: o teste sintetico inicial resultou em `was not changed`, mas o teste posterior com `Pattern Settings 'WorkWith'` real importou com sucesso.
- `Inferência forte`: `PatternSettings` deixa de ser pendencia estrutural aberta e passa a depender principalmente de pattern real compativel com o ambiente.
- `Regra operacional`: sempre preferir `PatternSettings` reais do pattern alvo; se o log disser `pattern nao registrado`, tratar como incompatibilidade do ambiente, não como erro do envelope.
- `Evidência direta`: no par mínimo `XPZExemploTRNWWComparacaoSemWW.xpz` e `XPZExemploTRNWWComparacaoComWW.xpz`, a inclusao de `WWExemploMinPaisA` elevou o pacote de `25` para `49` identidades em `ObjectsIdentityMapping`, mesmo acrescentando apenas um objeto top-level.
- `Inferência forte`: para `WorkWithForWeb`, o aumento de risco operacional não está apenas no XML do pattern; ele também aparece como ampliacao do grafo de identidades e dependencias de contexto.
- `Regra operacional`: ao montar pacote mínimo com `WorkWithForWeb`, comparar sempre a lista de `ObjectsIdentityMapping` com a versão sem `WW`; o delta de identidades ajuda a separar dependencia real do pattern de ruido do contêiner.

### Politica para `Table` e `Index`

- `Evidência direta`: nesta trilha, `Table` aparece como familia top-level própria e `Index` aparece embutido dentro de `Table`.
- `Evidência direta`: o export isolado de `Index` veio vazio, enquanto `Table + Index` repetiu a mesma serializacao top-level de `Table`.
- `Evidência direta`: pacotes combinados com `Transaction` mostraram `Table` convivendo no mesmo `.xpz` com `Transaction`, `WorkWithForWeb`, `PatternSettings` e `DataSelector`.
- `Evidência direta`: comparacao privada posterior com pares reais da KB de origem confirmou repeticao da correspondencia nominal entre `Transaction` e `Table`, tanto em caso simples quanto em caso mais denso.
- `Evidência direta`: na mesma comparacao privada, a chave do primeiro `Level` da `Transaction` coincidiu com o bloco `<Key>` da `Table`, inclusive em casos de chave composta.
- `Evidência direta`: na mesma amostra, cada `Table` comparada apresentou `1` índice `Unique` automático para a chave e um conjunto variável de índices `Duplicate` `Automatic` e `User`.
- `Evidência direta`: na mesma amostra privada, todos os membros de índices `Automatic` observados já existiam como atributos do primeiro `Level` da `Transaction` correspondente.
- `Evidência direta`: nesta KB, prefixo `I` identifica índice automaticamente criado pelo GeneXus a partir de PK ou FK definidas pelo modelador.
- `Evidência direta`: nesta KB, prefixo `U` identifica índice criado manualmente pelo operador humano.
- `Evidência direta`: quando um índice automático `I...` recebe nome mais amigavel, a alteracao e apenas no nome; campos, ordem e natureza do índice permanecem os mesmos.
- `Evidência direta`: o naming default do GeneXus para índices automáticos e pouco descritivo, normalmente derivado do nome da `Table` com numeração incremental a partir do segundo índice.
- `Evidência direta`: nos índices automáticos de FK, os campos seguem a mesma ordem estabelecida pelo modelador na `Transaction` e refletida na `Table`.
- `Evidência direta`: na mesma amostra, os índices `Automatic` `Duplicate` apareceram principalmente como atributo único `...Id` ou como par `...EmpresaId + ...Id|...Codigo`.
- `Evidência direta`: na mesma investigacao privada, varios atributos `...Id` e `...Codigo` do primeiro `Level` não reapareceram em índices `Automatic`, inclusive em objetos mais densos.
- `Evidência direta`: os nomes amigaveis de varios índices `Duplicate` observados nesta KB devem ser lidos como convencao local da KB, e não como naming default do GeneXus.
- `Evidência direta`: abreviacoes e nomes descritivos observados em índices desta KB decorrem da renomeacao humana para manutencao, log e diagnostico; não devem ser tratados como naming automático do GeneXus nem como comportamento normal diante de limite de 63 caracteres.
- `Evidência direta`: numa ampliacao posterior da amostra privada para o conjunto local de `Table`, o formato mais recorrente de índice `Automatic` `Duplicate` foi o par `...EmpresaId + ...Id|...Codigo`, seguido por índices únicos de auditoria de usuário e por `...EmpresaId` isolado.
- `Evidência direta`: na mesma ampliacao, parte relevante das `Table` locais acumulou ao mesmo tempo índices automáticos de relacionamento principal e de auditoria de usuário, mas esse padrão não cobriu todo o conjunto.
- `Evidência direta`: numa releitura posterior do conjunto local completo com parse direto do bloco `<Indexes>`, `143/228` `Table` apresentaram pelo menos um índice `User`, enquanto `85/228` não apresentaram nenhum `User`.
- `Evidência direta`: nesse mesmo recorte, entre as `Table` sem `User`, `69/85` ficaram com apenas `1` ou `2` índices `Automatic` `Duplicate`; entre as `Table` com `User`, `124/143` ficaram na faixa de `1` a `3` índices `User`.
- `Evidência direta`: a releitura ampla encontrou apenas `3` `Table` sem qualquer índice `Automatic` `Duplicate`: `OperacaoFiscal`, `Pais` e `TipoDocumento`; nas tres, ainda assim havia pelo menos um índice `User`.
- `Evidência direta`: no mesmo recorte amplo, o acervo totalizou `429` índices `User`; `239/429` continham pelo menos um `Member` em `Descending`, e `229/429` terminavam com o último `Member` em `Descending`.
- `Evidência direta`: no mesmo recorte, `190/429` índices `User` ficaram totalmente em `Ascending`, mostrando que nem todo índice manual desta KB existe para ordenacao descendente; parte deles cobre busca ou navegacao por combinacoes específicas de negocio.
- `Inferência forte`: para engenharia reversa da camada física, a unidade mínima útil não é `Index` solto, e sim `Table` comparavel, preferencialmente junto da `Transaction` correspondente.
- `Inferência forte`: índices automáticos de auditoria devem ser lidos, nesta KB, como índices de FK automaticamente criados pelo GeneXus e depois eventualmente renomeados de forma amigavel.
- `Inferência forte`: índice `User` deve ser lido como tuning manual empirico, criado quando a ordenacao real de grid, relatório ou procedure não é bem atendida pelos índices automáticos e o volume esperado justifica um índice dedicado.
- `Inferência forte`: um caso recorrente de índice `User` é reaproveitar quase a mesma composicao de um índice automático, mas com direcao `Descending` no último campo para acelerar busca do registro mais recente.
- `Inferência forte`: a familia residual mais comum fora das `Table` com varios `User` não é ausencia total de índice, e sim `Table` que permanece suficiente com PK e poucos `Automatic` `Duplicate`.
- `Inferência forte`: os casos sem `Automatic` `Duplicate` formam exceção pequena e simples; neles, o `User` tende a cumprir papel único de busca ou ordenacao por atributo de negocio.
- `Inferência forte`: `OperacaoFiscal`, `Pais` e `TipoDocumento` devem ser tratados nesta trilha como exceções locais da KB, potencialmente sujeitas a revisao de modelagem, e não como moldes preferenciais para inferencia da camada física.
- `Regra operacional`: não classificar `Index` como objeto top-level independente nesta trilha sem nova evidencia estrutural externa.
- `Regra operacional`: ao materializar ou revisar `Table`, preservar o bloco de chave e o bloco `<Indexes>` integralmente, incluindo ordem dos `TableIndex`, `Index/@Type`, `Index/@Source` e ordem dos `Member`.
- `Regra operacional`: quando a leitura exigir ponte com a camada lógica, validar primeiro a correspondencia nominal e estrutural entre `Transaction` e `Table`; só depois analisar os `Index` embutidos.
- `Regra operacional`: quando a pergunta for sobre chave física básica, usar como primeira leitura conservadora a chave do primeiro `Level` da `Transaction` e conferir se ela reaparece integralmente no bloco `<Key>` da `Table`.
- `Regra operacional`: quando a pergunta for sobre origem de índice `Automatic`, conferir primeiro se os `Members` já pertencem ao primeiro `Level` da `Transaction`, antes de supor regra extra de runtime ou metadata externa.
- `Regra operacional`: quando a pergunta for sobre autoria do índice nesta KB, tratar prefixo `I` como automático do GeneXus e prefixo `U` como criacao manual humana, salvo evidencia privada muito forte em contrario.
- `Regra operacional`: se um índice `I...` tiver nome descritivo, assumir primeiro renomeacao editorial do nome, e não alteracao de composicao, ordem ou tipo.
- `Regra operacional`: na ausencia de evidencia mais forte, tratar como candidatos recorrentes a índice `Automatic` adicional os formatos `...Id` único e `...EmpresaId + ...Id|...Codigo`, sempre confirmando no molde comparavel antes de concluir.
- `Regra operacional`: não inferir índice `Automatic` apenas porque o atributo termina em `Id` ou `Codigo`; o critério mais seguro continua sendo a repeticao em `Table` comparavel do mesmo grupo estrutural.
- `Regra operacional`: quando houver muitos candidatos possíveis no primeiro `Level`, priorizar primeiro a inspeção de pares `...EmpresaId + ...Id|...Codigo`, depois campos de auditoria de usuário, e só depois `...EmpresaId` ou outros `...Id` isolados.
- `Regra operacional`: não inferir que toda `Table` relevante precise de índice `User`; a ausencia de `U...` pode ser decisão consciente de custo/beneficio quando o volume esperado e pequeno.
- `Regra operacional`: tratar decisão sobre índice `User` como tuning empirico de performance e ordenacao, e não como regra estrutural previsivel apenas pelo XML.
- `Regra operacional`: se a `Table` comparavel cair fora do nucleo mais carregado de `User`, testar primeiro a hipotese mais conservadora: PK + poucos `Automatic` `Duplicate` já suficientes, sem `User` adicional.
- `Regra operacional`: só promover hipotese de `User` novo quando houver evidencia comparavel de ordenacao ou busca de negocio não coberta pelos índices automáticos existentes.
- `Regra operacional`: tratar como exceção rara os casos sem `Automatic` `Duplicate`; quando aparecerem, verificar se o papel do `User` observado e busca simples por descricao/nome ou ordenacao básica por `Id Descendente`.
- `Regra operacional`: não usar `OperacaoFiscal`, `Pais` ou `TipoDocumento` como molde preferencial para inferir ausencia de `Automatic` `Duplicate` em novas `Table`.
- `Regra operacional`: no acervo operacional atual, materializar esses objetos fisicos em pasta `Table`; se surgir pasta `Index` em algum contexto antigo, tratar isso como legado de extracao, e não como prova de tipo top-level diferente.
- `Regra operacional`: se o caso concreto depender de afirmar reassociacao física exata entre `Transaction`, `Table` e navegacao real da IDE, responder com cautela e separar explicitamente estrutura observada de comportamento runtime inferido.

### Politica para `Folder`

- `Evidência direta`: os exemplos reais de `Folder` usam shape mínimo e estavel com `Object/@type=\"00000000-0000-0000-0000-000000000006\"`.
- `Evidência direta`: a IDE importou o caso de teste como `Category`, e as capturas de `New Object` mostraram `Category` como agrupador visual da UI, não como tipo XML de objeto.
- `Inferência forte`: `Folder` fica encerrado como tipo estrutural simples; a divergencia residual é apenas de nomenclatura exibida pela IDE/importador.
- `Regra operacional`: ao relatar resultado de `Folder`, separar sempre tipo estrutural XML (`Folder`) do rotulo de UI reconhecido no log (`Category`, quando for o caso).

## Ponte estrutura -> runtime por tipo e familia

### Transaction

- `Evidência direta`: 162/183 `Transaction` observadas possuem exatamente 1 `Level`; 12/183 possuem 2 `Level`; 9/183 possuem 3 ou mais `Level`.
- `Inferência forte`: familias simples de 1 nível tendem a ter risco runtime relativo menor para navegacao do que familias mestre-detalhe e multinivel.
- `Inferência forte`: alta densidade de `AttributeProperties` e muitos atributos referenciais no mesmo nível sugerem maior sensibilidade a `Extended Table`, filtros e relacoes implicitas.
- `Hipótese`: quando a clonagem altera atributos-chave, `DescriptionAttribute` ou distribuicao entre níveis, o risco runtime cresce junto com o risco estrutural.

### WebPanel

- `Evidência direta`: o recorte estrutural mostra familias com casca mínima, casca gerada por defaults/pattern, navegacional com eventos, formulario com ação, lista com grid e combinacoes mais densas.
- `Inferência forte`: familias com `grid` e `events` são mais sensiveis a carga, refresh e navegacao implicita do que familias de menu/home ou casca simples.
- `Inferência forte`: familias geradas com marcas de `Defaults`, `IsGeneratedObject`, `parent` contextual e elementos de pattern tendem a depender mais do runtime/KB de origem.
- `Hipótese`: quanto maior o número de controles, links, actions e código de evento, maior a chance de existir comportamento não trivial de autorizacao, refresh, carga condicional ou dependencia de master page.

### Procedure, DataProvider, API e objetos dependentes de pattern

- `Evidência direta`: `Procedure` e `DataProvider` frequentemente expõem blocos `Source`, `Parm` e `Variables`; `API` expõe `Service`, `RestMethod` e eventos `.Before/.After`; `WorkWithForWeb` carrega pattern e parent transacional em 183/183 casos.
- `Inferência forte`: objetos com `pattern`, `parentType` forte e blocos de código gerado merecem leitura runtime mais cautelosa porque parte da navegacao e da expectativa funcional vem do contexto de geração.
- `Inferência forte`: `WorkWithForWeb` e derivados patternizados devem ser tratados como de risco operacional/runtime alto mesmo quando a estrutura parece recorrente.
- `Evidência direta`: no experimento `.md`-only, `Work With for Web 'WorkWithWebTrnTesteMdF1'` importou com sucesso quando o pattern usou o convenio real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Inferência forte`: para `WorkWithForWeb`, a referencia de atributo do pattern deve ser tratada como convenio estrutural fixo do pattern, e não como GUID do `Attribute` top-level ou do atributo inline do `Level`.
- `Hipótese`: `API` pequena pode ter runtime simples, mas a presenca de múltiplos métodos e eventos de pre/pós-processamento sugere custo invisivel ao olhar apenas o contrato externo.

## Regras de decisão operacional com impacto runtime

- `Quando falar com mais confianca`:
  - `Regra documentada`: quando a conclusao vier diretamente de conceito oficial de GeneXus, como `Base Table`, `Extended Table`, `Load`, `Refresh` ou `Refresh Grid`.
  - `Evidência direta`: quando a estrutura XML mostrar claramente sinais repetidos, como `Level`, `Pattern`, `events`, `grid`, `parent` ou densidade de `AttributeProperties`.
- `Quando falar com cautela`:
  - `Inferência forte`: quando o XML sugere navegacao não trivial, mas sem relatório de navegacao ou sem código suficiente para confirmar custo e cardinalidade.
  - `Hipótese`: quando a conclusao depender de supor joins, roundtrips ou custo de banco sem prova direta.
- `Quando exigir molde mais proximo`:
  - `Inferência forte`: em `WebPanel` com `grid` + `events` + `parent` ou marcas de objeto gerado.
  - `Inferência forte`: em `Transaction` com 2+ `Level` ou densidade alta de atributos relacionais.
  - `Inferência forte`: em `WorkWithForWeb`, `Panel` gerado por pattern e `API` com eventos server-side relevantes.
- `Quando abortar`:
  - `Inferência forte`: quando a mudanca exigir alterar estrutura e, ao mesmo tempo, houver alto acoplamento com runtime implicito, pattern ou contexto pai-filho não reproduzivel.
  - `Hipótese`: quando o caso exigir garantir performance, importação ou comportamento em producao sem validação externa.

## Limites do que a base ainda não prova

- `Evidência direta`: esta trilha não contem relatórios completos de navegacao gerados pela IDE nem medições reais de performance.
- `Regra documentada`: os conceitos oficiais ajudam a interpretar risco, mas não substituem especificacao nem teste do objeto concreto na KB.
- `Inferência forte`: a base agora consegue responder melhor sobre sensibilidade runtime relativa.
- `Hipótese`: ela ainda não permite afirmar, sem teste, que um clone vai importar, buildar, navegar bem ou performar de forma aceitavel.

## Referencias oficiais complementares

- `Regra documentada`: `Base Transaction clause` - [docs.genexus.com/en/wiki?25418,Base+Transaction+clause](https://docs.genexus.com/en/wiki?25418,Base+Transaction+clause)
- `Regra documentada`: `Base Transaction in For each command` - [docs.genexus.com/en/wiki?23945,Base+Transaction+in+For+each+command](https://docs.genexus.com/en/wiki?23945,Base+Transaction+in+For+each+command)
- `Regra documentada`: `Load event` - [wiki.genexus.com/commwiki/wiki?8188,Load+event](https://wiki.genexus.com/commwiki/wiki?8188,Load+event)
- `Regra documentada`: `Refresh Grid event` - [wiki.genexus.com/commwiki/wiki?8187,Refresh+Grid+event](https://wiki.genexus.com/commwiki/wiki?8187,Refresh+Grid+event)
- `Regra documentada`: `Web Form Refresh` - [wiki.genexus.com/commwiki/wiki?6566,Web+Form+Refresh](https://wiki.genexus.com/commwiki/wiki?6566,Web+Form+Refresh)

## Heurísticas operacionais acionáveis

### Heurística H01 - Transaction simples de 1 nível

#### Sinais observáveis
- `Transaction` da familia simples de 1 nível em `05-transaction-familias-e-templates.md`
- 1 `Level`
- sem subnivel
- baixa ou moderada densidade de `AttributeProperties`

#### Leitura técnica
- `Evidência direta`: 162/183 `Transaction` observadas possuem exatamente 1 `Level`.
- `Regra documentada`: navegacao transacional tende a ser menos sensivel quando o contexto estrutural e mais simples e local.
- `Inferência forte`: esse é o melhor ponto de partida para clonagem controlada de `Transaction`.
- `Hipótese`: a chance de erro runtime relativo é menor do que em familias com detalhe ou muitos atributos relacionais.

#### Ação do agente
- responder com cautela controlada, não com otimismo
- preservar `Level`, `DescriptionAttribute`, `parent*`, `moduleGuid` e todos os `Part`
- não prometer importação, build ou comportamento de navegacao final
- escalar o risco se surgir FK adicional, alteracao de contexto ou mudanca de `DescriptionAttribute`

#### Exemplos de aplicação
- nova `Transaction` simples de cadastro básico deve partir de molde da familia simples de 1 nível e não de familia mestre-detalhe

### Heurística H02 - Transaction com 2+ níveis

#### Sinais observáveis
- `Transaction` com 2 ou mais `Level`
- relacao pai-filho explicita
- estrutura mestre-detalhe ou multinivel

#### Leitura técnica
- `Evidência direta`: 21/183 `Transaction` observadas possuem 2 ou mais `Level`.
- `Regra documentada`: múltiplos níveis ampliam sensibilidade a contexto transacional e navegacao.
- `Inferência forte`: o risco estrutural e runtime relativo sobe quando ha distribuicao de atributos entre níveis.
- `Hipótese`: mudancas entre níveis podem afetar navegacao, joins implicitos e comportamento não trivial na KB.

#### Ação do agente
- exigir molde interno muito próximo
- preservar hierarquia inteira e evitar mover atributos entre níveis
- não prometer simplicidade de manutencao ou boa performance
- abortar se a mudanca exigir redesenho de níveis sem paralelo bruto

#### Exemplos de aplicação
- pedido com itens deve partir de familia mestre-detalhe equivalente, e não de um molde de 1 nível

### Heurística H03 - Transaction com alta densidade de AttributeProperties

#### Sinais observáveis
- muitos blocos `AttributeProperties`
- varios atributos referenciais ou de controle no mesmo `Level`
- XML significativamente mais denso que a familia enxuta

#### Leitura técnica
- `Evidência direta`: 177/183 `Transaction` observadas possuem `AttributeProperties`, com densidade variável.
- `Regra documentada`: atributos fora do contexto imediato podem aumentar sensibilidade a `Extended Table` e navegacao.
- `Inferência forte`: densidade alta de `AttributeProperties` sugere mais pontos de dependencia estrutural e funcional.
- `Hipótese`: a chance de vazamento do molde-base e de erro por coerência interna cresce junto com a densidade.

#### Ação do agente
- responder com cautela
- preservar atributos, propriedades e referencias internas com diff estrutural rigoroso
- não tratar remocao de atributos como edicao trivial
- exigir molde mais próximo se houver muitos atributos relacionais ou flags internos

#### Exemplos de aplicação
- `Transaction` com dezenas de `AttributeProperties` não deve ser usada como casca de edicao agressiva sem familia equivalente

### Heurística H04 - WebPanel casca mínima

#### Sinais observáveis
- familia de casca mínima em `04-webpanel-familias-e-templates.md`
- layout pequeno
- sem `grid`
- sem eventos relevantes

#### Leitura técnica
- `Evidência direta`: existem familias de `WebPanel` com casca mínima e baixa variabilidade interna.
- `Regra documentada`: ausencia de `grid` e de eventos reduz superficie de comportamento server-side observavel.
- `Inferência forte`: esse é o caso menos arriscado dentro de `WebPanel`.
- `Hipótese`: ainda pode haver dependencia externa de `parent`, `MasterPage` ou seguranca.

#### Ação do agente
- responder com confianca relativa, mas ainda conservadora
- preservar `layout`, `Part type`, `parent*` e bindings existentes
- não prometer que o painel sera totalmente isolado do contexto
- escalar o risco se surgirem actions, links, componentes customizados ou seguranca integrada

#### Exemplos de aplicação
- tela de menu/home simples pode partir de uma casca mínima sem tentar herdar familia com grid e eventos

### Heurística H05 - WebPanel gerado por pattern/defaults

#### Sinais observáveis
- marcas como `Defaults`, `IsGeneratedObject`, `WEB_COMP=Yes`
- `parent` contextual
- assinatura recorrente de objeto gerado

#### Leitura técnica
- `Evidência direta`: ha familias de `WebPanel` com sinais explicitos de defaults/pattern no acervo.
- `Regra documentada`: objetos gerados tendem a depender mais do contexto de geração e navegacao da KB.
- `Inferência forte`: isso aumenta o risco operacional e runtime relativo.
- `Hipótese`: parte do comportamento esperado pode estar fora do XML isolado, em pattern, master page ou objeto pai.

#### Ação do agente
- exigir molde interno mais próximo
- preservar marcas estruturais e contexto de `parent`
- não responder com linguagem otimista do tipo “casca simples”
- abortar se o caso exigir descolar o objeto do contexto gerado sem paralelo bruto
- tratar derivados gerados por pattern como artefatos de saida: não gravar nem empacotar correcao manual diretamente neles; identificar a fonte declarativa e trabalhar nela, como pattern pai, instancia declarativa, objeto pai ou objeto chamado
- ler derivados gerados apenas quando houver diagnostico concreto que exija confirmar erro, caller gerado ou artefato de runtime; leitura casual de derivado não deve ser o ponto de partida

#### Exemplos de aplicação
- `WebPanel` vindo de familia gerada por defaults não deve ser reaproveitado como molde genérico para tela livre

### Heurística H06 - WebPanel com events

#### Sinais observáveis
- bloco `Events` com código real
- actions, chamadas de objetos ou regras condicionais
- variáveis ligadas a fluxo de tela

#### Leitura técnica
- `Evidência direta`: 437/1196 `WebPanel` mostram sinal estrutural de eventos.
- `Regra documentada`: eventos em Web podem acionar refresh, carga Ajax e lógica server-side adicional.
- `Inferência forte`: a presenca de eventos aumenta a chance de comportamento contextual não trivial.
- `Hipótese`: o custo real depende do código e da navegacao que não aparecem integralmente só pela assinatura superficial.

#### Ação do agente
- responder com cautela
- preservar eventos, nomes de controles referenciados e variáveis envolvidas
- não prometer que editar texto ou layout sera suficiente
- escalar o risco se os eventos chamarem procedimentos, seguranca, validacoes ou navegacao indireta

#### Exemplos de aplicação
- painel com `Event Start` e eventos de botao deve ser tratado como painel comportamental, não apenas visual

### Heurística H07 - WebPanel com grid + events

#### Sinais observáveis
- familia com `grid`
- bloco `Events`
- possível `Load`, `Refresh` ou filtros/acoes associados

#### Leitura técnica
- `Evidência direta`: ha `WebPanel` com assinatura estrutural de `grid` e eventos no acervo, embora sejam minoria relativa.
- `Regra documentada`: grid com base de navegacao pode executar `Load` por linha; eventos e refresh aumentam sensibilidade de runtime.
- `Inferência forte`: esta é uma das combinacoes mais sensiveis para custo, carga repetida e dependencia de contexto.
- `Hipótese`: sem relatório de navegacao, o risco de leitura incompleta do runtime continua alto.

#### Ação do agente
- exigir molde interno muito próximo
- preservar estrutura de grid, eventos, filtros, bindings e ordem dos blocos
- não tratar como casca simples nem autorizar simplificacao agressiva
- abortar se a familia estrutural equivalente não estiver clara

#### Exemplos de aplicação
- lista com grid filtravel e eventos de ação deve partir de familia de lista/grid equivalente e não de menu simples

### Heurística H08 - Procedure/DataProvider com sensibilidade de navegacao

#### Sinais observáveis
- código `Source` com consultas, filtros, ordens ou mapeamentos
- `Parm` e `Variables` conectados a atributos
- saida estruturada em `DataProvider` ou lógica procedural em `Procedure`

#### Leitura técnica
- `Evidência direta`: `Procedure` e `DataProvider` expõem blocos de código, parâmetros e variáveis no acervo.
- `Regra documentada`: navegacao nesses objetos depende de `For each`, grupos, atributos usados e base implicita/explicita.
- `Inferência forte`: esses objetos podem parecer simples no XML externo, mas carregar sensibilidade alta de navegacao no código.
- `Hipótese`: custo e qualidade de especificacao podem variar muito conforme filtros, ordens e atributos usados.

#### Ação do agente
- responder com cautela
- preservar assinatura de parâmetros, blocos de código e relacao entre variáveis e atributos
- não falar de `For each` ou performance sem considerar `Base Table` e navegacao
- exigir molde mais próximo se o código tocar consulta de dados relevante

#### Exemplos de aplicação
- `DataProvider` com filtros e mapeamento de SDT deve ser clonado a partir de outro `DataProvider` com forma de consulta comparavel

### Heurística H09 - Dependencia forte de parent/pattern

#### Sinais observáveis
- `parent`, `parentGuid`, `parentType` presentes
- `Pattern=` ou marcas de objeto gerado
- contexto estrutural amarrado a objeto pai

#### Leitura técnica
- `Evidência direta`: `WorkWithForWeb` aparece com `parent` e `pattern` em 183/183 casos; varios outros tipos dependem fortemente de `parent`.
- `Regra documentada`: objetos dependentes de contexto gerado ou pai tendem a trazer comportamento e navegacao herdados da KB.
- `Inferência forte`: esse é um forte sinal de cautela operacional e runtime.
- `Hipótese`: remover ou trocar esse contexto pode quebrar comportamento esperado mesmo que o XML permaneça bem-formado.

#### Ação do agente
- exigir molde muito próximo ou contexto completo
- preservar todos os vinculos de `parent*`, `moduleGuid` e marcas de pattern
- não autorizar “generalizacao” do objeto
- abortar se o objetivo for desacoplar o objeto do pai/pattern sem base real equivalente

#### Exemplos de aplicação
- `WorkWithForWeb` deve ser tratado como altamente dependente do objeto pai transacional e do pattern de origem

### Heurística H10 - Quando exigir molde mais próximo ou abortar

#### Sinais observáveis
- mistura de familias
- blocos raros/opacos
- evento + grid + contexto pai
- multinivel transacional
- pattern sem equivalente claro

#### Leitura técnica
- `Evidência direta`: a base já documenta familias, riscos e dependencias contextuais para os tipos mais sensiveis.
- `Regra documentada`: runtime e navegacao não podem ser garantidos apenas por semelhanca superficial de XML.
- `Inferência forte`: quando sinais de alta sensibilidade se acumulam, a postura correta deixa de ser “seguir” e passa a ser “exigir molde” ou “abortar”.
- `Hipótese`: insistir em clonagem nessas condições aumenta bastante a chance de erro estrutural ou runtime.

#### Ação do agente
- exigir molde mais próximo quando ainda houver caminho estrutural comparavel
- abortar quando não houver familia equivalente ou quando a mudanca pedir invencao de estrutura
- não prometer importação, build, navegacao correta ou performance
- deixar explicito o motivo do aborto

#### Exemplos de aplicação
- `WebPanel` com grid, eventos, parent gerado e controles raros sem familia equivalente deve ser abortado em vez de improvisado

## Anti-patterns operacionais

- nunca inferir boa performance só pelo XML
- nunca responder “vai buildar” ou “vai importar” sem evidencia externa
- nunca tratar `grid + events` como casca simples
- nunca responder sobre `For each` sem considerar `Base Table`, navegacao e contexto de atributos
- nunca autorizar edicao agressiva em `Transaction` multinivel sem molde equivalente
- nunca usar entusiasmo estrutural para atropelar heuristica que mandou exigir molde ou abortar
- nunca gerar bloco especial de KB (`KnowledgeBase`, `Settings` ou elemento top-level com o nome da KB) em `.xpz` normal de objetos

## Delegacao a LLM secundario (xpz-llm-delegate)

- delegacao a um modelo secundario via opencode, Codex (`codex exec`), Claude Code (`claude -p`, Opus 4.8), GitHub Copilot CLI (`copilot -p`) ou Gemini CLI (`gemini -p`) e sempre **acionada por humano** (pedido do usuário ou concordancia explicita a uma sugestao do agente); nunca automática
- nunca delegar juizo estrutural GeneXus (classificação de risco/familia/tipo, seguranca de import/build, veredito de gate) ao subagente; isso fica com o agente forte, que também **valida** toda saida delegada antes de usar
- confidencialidade por gate deterministico: antes de enviar payload a um modelo, classificar `kb-sensitive` vs `public` e passar por `scripts/Resolve-LlmDelegateAuthorization.ps1` com `-Backend opencode|codex|claude-code|copilot|gemini` (que chama o resolvedor do backend — `scripts/Resolve-OpenCodeModelLocality.ps1`, `scripts/Resolve-CodexModelLocality.ps1`, `scripts/Resolve-ClaudeCodeModelLocality.ps1`, `scripts/Resolve-CopilotModelLocality.ps1` ou `scripts/Resolve-GeminiModelLocality.ps1`); conteúdo de pasta paralela só vai a modelo externo com autorizacao, conteúdo publico e livre
- localidade e deterministica (provider com baseURL/`base_url` loopback na config do backend = local; caso contrario externo); sensibilidade do payload ancora no contexto/origem, não em varredura de texto
- a chave que casa na politica e o **provider de destino** (`canonicalModel`, ex.: `openai/gpt-5.5`, `anthropic/claude-opus-4-8`, `github-copilot/gpt-5-mini`, `google/gemini-3-flash-preview`), nunca o adapter: o Codex com modelo OpenAI explícito ou default da config e governado pelas mesmas entradas `openai/*` do opencode, sem prefixo `codex/`; Claude Code com Opus 4.8 casa `anthropic/*`, sem prefixo `claude-code/`; Copilot casa `github-copilot/*`, sem prefixo `copilot/`; Gemini casa `google/*`, sem prefixo `gemini/`; adapters agenticos (incluindo `codex exec`, `claude -p`, `copilot -p` e `gemini -p`) com sandbox/permissao/modo restrito **não** contornam o gate
- nos adapters opencode (`Invoke-OpenCode.ps1` e `Start-OpenCodeJob.ps1`), o default sem `-Agent` explícito e o agente `reviewer-ro` least-privilege ("sem execucao/escrita"): o guard `OpenCodeReviewerRoGuard.ps1` roda fail-closed antes do run/spawn (estatico + `opencode agent list`, allow-set resolvido exatamente `{read,grep,glob,list}` e versao testada; motivos `static`/`version`/`allowset`/`agentlist`); a leitura fica confinada ao cwd herdado via `external_directory: deny`; no painel, a chave `agent` e bloqueada e o revisor sempre cai no `reviewer-ro`; `-Agent <x>` explícito fora do painel e opt-out consciente, e cwd-seguro continua responsabilidade de quem dispara
- modo assistido por dossiê na pré-push reforçada (fonte normativa `13`/`14`): como o `reviewer-ro` nega `bash`, o revisor opencode fica **semantic-only** (sem git) e não roda o passo mecanico do `13`. Matriz de **capacidade**: **git-capable** (roda git — Codex-delegate em sandbox read-only, subagente nativo com Bash) vs **semantic-only** (sem shell — opencode `reviewer-ro`, Claude Code, Copilot, Gemini). Para o semantic-only o orquestrador roda o mecanico **1x** e monta um dossiê (`scripts/Build-PrePushReviewDossier.ps1`: Secao A git bruto + Secao B `-AsJson` rotulada «candidatas, não verdade» + sentinelas `HEAD:`/`END_DOSSIER sha256=`), entregue **inline no prompt** (nos `stdin-dossier-capable` como o opencode, por stdin — `external_directory: deny` não bloqueia; nos `argv-limited` Copilot/Gemini, por argv se couber, senão omitido `dossier-too-large`), e o revisor roda só a fase semantica. Painel valido retem **>=1 git-capable** que reproduz a Secao A; com working tree suja o orquestrador **não despacha** semantic-only (pede commit/stash). Guard/adapters/`Invoke-LlmDelegatePanelDispatch.ps1` **intactos**
- autorizacao duravel por KB no arquivo de politica da pasta paralela — nome canonico `llm-delegation-policy.json`, nome legado `opencode-delegation-policy.json` ainda aceito (granularidade fina por `provider/modelo`, curinga de provider e `defaultExternal`; ausente => `ask`); `scripts/Resolve-LlmDelegationPolicyPath.ps1` resolve o caminho (canonico com fallback ao legado, `status` `new|legacy|both|none`) e o gate aceita `-ParallelKbRoot` para descobri-lo quando `-PolicyPath` e omitido; detalhe em `xpz-llm-delegate/SKILL.md`
- fechamento mecanico da revisao por pares: `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` bloqueia o recibo final quando a curadoria de preferidos nao foi ofertada, falta estado auditavel de revisor preferido, **ou** a versao consolidada (vN+1) esta `pendingResubmission` ou em declinio nao auditado (`-VNextState`/`-ResubmissionDeclinedBy`/`-ResubmissionDeclineReason`/`-RoundId`); o script e **stateless** (monotonicidade/append-only entre chamadas e do orquestrador + recibo, nao do script) e nao decide autorizacao nem diversidade. Dono normativo: `xpz-llm-delegate/SKILL.md` e `15-revisao-por-pares.md` — nao duplicar o contrato aqui
- limites operacionais dos adapters (anti-hang de stdin headless nos dois regimes — stdin-based opencode/Codex/ClaudeCode vs argument-based Gemini/Copilot; o sintoma nao-deterministico `StandardOutputEncoding` so nos argument-based, com workaround de invocar pela ferramenta Bash; o limite ~32KB de linha de comando do Windows, que o opencode evita entregando o prompt por stdin/`-MessagePath`, fora do argv) ficam em `xpz-llm-delegate/SKILL.md` (secoes «LIMITE CONHECIDO»); dono normativo la, nao duplicar aqui

## Origem incorporada - 02-genexus-xpz-generation-rules.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
01-base-empirica-geral.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
02-regras-operacionais-e-runtime.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Registrar regras conservadoras para qualquer tentativa futura de geração de XPZ.
Explicitar o que a base já sustenta e o que ainda permanece apenas heurístico.

## Premissa

Este arquivo não assume que a geração sintética de `XPZ` já esteja provada para qualquer cenário. Ele traduz apenas o que pode ser sustentado pelo inventário bruto e pelos XMLs extraídos desta KB.

## Regras com classificação explícita

### Regra 1

- `Evidência direta`: os objetos extraídos são compostos por um nó `<Object ...>` com metadados e, em muitos casos, múltiplos blocos `<Part type="...">`.
- `Inferência forte`: qualquer geração futura de `XPZ` deve preservar essa forma básica por objeto, em vez de tentar reduzir tudo a um XML simplificado de campos soltos.

### Regra 2

- `Evidência direta`: objetos do mesmo diretório extraído compartilham o mesmo GUID em `Object/@type`.
- `Inferência forte`: ao gerar objetos, o `Object/@type` precisa ser coerente com o grupo/tipo que se deseja representar.
- `Hipótese`: um `Object/@type` incorreto pode até importar em alguns cenários, mas a chance de inconsistência estrutural é alta.

### Regra 3

- `Evidência direta`: vários objetos dependem de `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Inferência forte`: uma geração segura deve manter esses vínculos quando o objeto observado os utiliza.
- `Hipótese`: omitir esses vínculos pode causar importação parcial, reposicionamento inesperado na KB ou perda de associação lógica.

### Regra 4

- `Evidência direta`: o acervo mostra conjuntos recorrentes de `Part type` por grupo como `Procedure`, `WebPanel`, `Transaction`, `SDT` e `SubTypeGroup`.
- `Inferência forte`: a geração deve partir de objetos-modelo reais do mesmo tipo, e não de um conjunto de `Part type` inventado.

### Regra 5

- `Evidência direta`: `WorkWithForWeb` contém `parentType` apontando para `Transaction` e carrega `<Data Pattern="...">`.
- `Inferência forte`: objetos gerados por pattern parecem depender mais do contexto do objeto pai do que objetos isolados como `Domain` simples.
- `Hipótese`: gerar pattern objects sem o contexto correspondente pode resultar em imports frágeis ou semanticamente incompletos.

### Regra 6

- `Evidência direta`: o inventário bruto trabalha no nível de objeto extraído, sem registrar alterações globais de KB, versão ou ambiente.
- `Inferência forte`: uma política conservadora de geração deve priorizar pacotes focados em objetos, evitando expandir o escopo para metadados globais sem necessidade comprovada.
- `Hipótese`: esse recorte mínimo tende a reduzir efeito colateral, mas isso ainda precisa de teste de importação controlado.

### Regra 7

- `Evidência direta`: o inventário atual conseguiu ler `7219` XMLs sem erros estruturais.
- `Inferência forte`: antes de empacotar qualquer geração, é razoável exigir ao menos XML bem-formado e consistência interna dos atributos observados.
- `Hipótese`: uma validação adicional por diff estrutural contra objetos-modelo do mesmo tipo deve aumentar a taxa de sucesso de importação.

## Política prática sugerida

- `Inferência forte`: para um primeiro gerador, começar pelos tipos com estrutura mais legível no acervo, como `Domain`, `SDT`, `Procedure` e talvez `WebPanel` simples.
- `Inferência forte`: tratar `Transaction`, `WorkWithForWeb`, `ThemeClass`, `SubTypeGroup` e objetos de pattern como classes de maior risco estrutural.
- `Hipótese`: objetos com menos `Part type`, menos relacionamentos aparentes e menos dependência de pattern devem ser os melhores candidatos iniciais para geração automatizada.

## O que este acervo ainda não prova

- `Evidência direta`: o inventário bruto não registra testes de importação, build ou execução.
- `Hipótese`: portanto, qualquer regra de geração aqui ainda é preparatória e não conclusiva.


## Origem incorporada - 20-guia-de-clonagem-segura.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Traduzir a análise empírica em orientação prudente para clonagem conservadora de objetos.
Indicar o que preservar, o que exige molde bruto comparável e onde o risco cresce.

Este guia é operacional, mas conservador.

- Evidência direta: ele se baseia em recorrencia de atributos, Part type, parent/module e blocos textuais observados.
- Inferência forte: pode alterar aqui significa bom candidato para clonagem controlada, não garantia de importação.

## API

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 36e32e2d-023e-4188-95df-d13573bac2e0.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: objetos com parent: 1/1; com pattern: 0/1.

## DataProvider

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 2a9e9aba-d2de-4801-ae7f-5e3819222daf.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: objetos com parent: 24/24; com pattern: 0/24.

## DesignSystem

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 78b3fa0e-174c-4b2b-8716-718167a428b5.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: medio.
- Evidência direta: Part type mais recorrentes: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: objetos com parent: 1/2; com pattern: 0/2.

## PackagedModule

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c88fffcd-b6f8-0000-8fec-00b5497e2117.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: alto.
- Evidência direta: Part type mais recorrentes: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc; a5e6a251-2df0-44d8-adab-1da237574326.
- Evidência direta: objetos com parent: 2/16; com pattern: 0/16.

## Panel

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = d82625fd-5892-40b0-99c9-5c8559c197fc.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 7/7; com pattern: 7/7.

## Procedure

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 84a12160-f59b-4ad7-a683-ea4481ac23e9.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173.
- Evidência direta: objetos com parent: 2281/2281; com pattern: 0/2281.

## SDT

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 447527b5-9210-4523-898b-5dccb17be60a.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 591/594; com pattern: 0/594.

## Theme

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c804fdbd-7c0b-440d-8527-4316c92649a6.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: alto.
- Evidência direta: Part type mais recorrentes: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: objetos com parent: 0/7; com pattern: 0/7.

## Transaction

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 1db606f2-af09-4cf9-a3b5-b481519d28f6.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa.
- Evidência direta: objetos com parent: 183/183; com pattern: 0/183.

## WebPanel

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c9584656-94b6-4ccd-890f-332d11fc2c25.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778.
- Evidência direta: objetos com parent: 1195/1196; com pattern: 0/1196.

## WorkWithForWeb

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 78cecefe-be7d-4980-86ce-8d6e91fba04b.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais são candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nível de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 183/183; com pattern: 183/183.



## Origem incorporada - 24-resumo-operacional-para-gerador-xpz.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-genexus-xpz-generation-rules.md, 26-guia-para-agente-gpt.md

## Objetivo
Concentrar as instruções práticas mais curtas para um gerador GPT orientado por clonagem conservadora.
Funcionar como resumo decisório sem esconder os limites da evidência.

## Premissa

- Evidência direta: este resumo deriva apenas do acervo XML extraído e dos relatórios `10` a `16`.
- Inferência forte: ele serve para reduzir tentativa e erro por clonagem conservadora.
- Hipótese: ele não substitui validação real por importação, abertura na IDE e build.

## Algoritmo sugerido de geração por clonagem

1. Escolher o tipo alvo e localizar um molde XML completo do mesmo diretório e do mesmo `Object/@type`.
2. Preferir template do mesmo contexto estrutural do alvo:
   mesmo uso de `parent`, mesmo uso de `pattern`, mesma familia de objeto.
3. Preservar integralmente `Object/@type`, `guid`, `parent`, `parentGuid`, `parentType`, `moduleGuid` e todos os `Part type` recorrentes do template.
4. Alterar primeiro apenas nomes, descricoes e blocos textuais claramente recorrentes.
5. Rejeitar a clonagem se surgir qualquer bloco raro, opaco ou ausente no molde comparavel.
6. Só empacotar depois de validar XML bem-formado e diff estrutural contra o molde-base.

## Quando abortar a geração

- Inferência forte: abortar quando o tipo estiver em risco `alto` ou `muito alto` e não houver molde suficientemente próximo.
- Inferência forte: abortar quando o objeto alvo exigir `pattern` ou contexto de `parent` não representado no molde.
- Inferência forte: abortar quando o molde comparavel tiver mais de um bloco raro/exclusivo que ainda não foi entendido.
- Hipótese: abortar também quando a mudanca pretendida exigir alterar blocos não textuais pouco recorrentes.

## Quando exigir molde bruto comparável

- Evidência direta: exigir molde bruto comparável muito próximo para tipos ainda sem anexo XML completo equivalente nesta base.
- Evidência direta: exigir molde bruto comparável também para `DesignSystem`, por causa da amostra muito pequena.
- Inferência forte: para `Theme` e `PackagedModule`, um molde bruto comparável próximo continua sendo a opção mais segura, mesmo quando a estrutura pareca menos agressiva.
- Hipótese: `Domain` agora já pode partir dos anexos sanitizados desta base tanto em casos escalares quanto enumerados, desde que o clone preserve `ATTCUSTOMTYPE`, limites e `IDEnumDefinedValues` quando existirem.
- Hipótese: `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` agora já contam com moldes sanitizados completos representativos; mesmo assim, `DesignSystem` continua pedindo cuidado extra quando houver imports, tokens e regras visuais extensas, `ThemeClass` continua pedindo preservacao rigorosa da cadeia `parent` quando houver variantes derivadas, `ThemeColor` e `ColorPalette` continuam extremamente declarativos mas ainda devem preservar identidade nominal e organizacao tematica, `Image` continua pedindo preservacao cuidadosa do binario em `base64`, dos `ImageItem` e das referencias de tema, `Index` continua pedindo preservacao rigorosa da ordem dos `Members`, do `Type` e do `Source` de cada índice, `PatternSettings` continua pedindo cuidado com referencias internas de seguranca/contexto, `DataStore` segue bastante declarativo, `Dashboard` segue sensivel a referencias internas de objetos analiticos, `DeploymentUnit` segue dependente da lista completa de `Member`, `Generator` segue bastante declarativo mas ainda pede preservacao de flags como `IsUser`, `IsDefaultCategory`, `IsReorg` e `DefaultType`, `Language` pede preservacao integral do bloco de `Translations`, `Folder` segue simples e declarativo, `Stencil` pede cuidado alto com `CDATA`, screenshots embutidos, controles e referencias visuais textuais, e `File` pede preservacao rigorosa do `base64Binary`, do nome extraido e dos caminhos de extracao.
- Hipótese: `ExternalObject`, `UserControl`, `Module` e `SubTypeGroup` agora também contam com moldes sanitizados completos representativos; dentro desse grupo, `ExternalObject` e `UserControl` merecem cautela extra quando carregarem contratos externos, scripts ou eventos mais densos, enquanto `SubTypeGroup` segue mais declarativo, mas ainda sensivel a nomes residuais e mapeamentos de subtype/supertype.
- Hipótese: `SDT` agora já pode partir dos anexos sanitizados desta base em cenários pequenos e medios, mas casos com metadata externa muito específica ainda merecem comparacao com molde bruto mais próximo.

## Politica para Transaction

- Evidência direta: existem 183 `Transaction` no acervo.
- Inferência forte: usar padrão estrutural inferido da própria base em vez de bloquear execução por falta de exemplo.
- Inferência forte: escolher uma familia simples e estruturalmente próxima do alvo.
- Evidência direta: a bateria de importação mostrou que `Transaction` pode manter envelope coerente e ainda falhar por atributos inexistentes e tipos de contexto não resolvidos na KB de destino.
- Inferência forte: para `Transaction`, a ordem correta de validação e `familia estrutural -> atributos reais do Level -> tipos de contexto -> regras e eventos`.
- Inferência forte: não abortar só por ausencia de template externo; a referencia principal passa a ser molde interno da própria base.
- Hipótese: os erros por objeto devem ser tratados incrementalmente para refinar os documentos.

## Politica para API

- Evidência direta: o acervo desta trilha traz apenas `1` `API` real, e a consulta a esse caso confirmou uso pesado de `ATTCUSTOMTYPE`, `EXO`, `SDT` e chamadas a `Procedure`.
- Evidência direta: esse caso real deve ser lido como construcao manual/local da KB, sem evidencia nesta trilha de automacao complementar de terceiros.
- Evidência direta: a bateria de importação mostrou que `API` pode falhar sem erro de envelope, apenas por `ATTCUSTOMTYPE` não conversivel ou tipo inexistente no destino.
- Inferência forte: para `API`, a ordem correta de validação e `molde estrutural -> ATTCUSTOMTYPE valido -> EXO e SDT existentes -> Procedure e eventos chamados`.
- Inferência forte: em `API`, trocar nomes e código sem fechar primeiro a camada de tipos tende a produzir falha semantica imediata.
- Hipótese: os erros por API também devem ser tratados incrementalmente, priorizando tipos e referencias antes de mexer em regras ou eventos.
- Calibração (from-spec + GAM, 2026-07-01, KMW 4.0.187794 + GAM 3.15.78): além do caso único de cadeia grande acima, a Fase 0 provou um perfil `API` autocontido from-spec — tríade `API` -> `Procedure` -> `SDT` escrita em XML, com única referência `ATTCUSTOMTYPE` externa = os próprios SDTs. Ver `03-risco-e-decisao-por-tipo.md` (perfis `API (cadeia)` vs `API (from-spec)`) e o satélite `xpz-builder/responsibilities-by-type/api.md`.
- Regra operacional (validação): validar uma `API` from-spec por importação real, nunca por preview — o preview reporta `importTaskSuccess:true` para `API` inválida (valor de `[SecurityLevel]` inválido, `Procedure` de implementação ausente); só o import real roda a validação de gramática/referências da `API`. Empacotar a `API` junto com seu `Procedure` de implementação, ou fazer staging do `Procedure` antes.
- Regra operacional (segurança runtime — dimensão GAM): `[SecurityLevel]` na `API` (`None`/`Authentication`/`Authorization`; nunca `Authorize`, rejeitado pelo parser) define o nível em C# (`SecurityNone`/`SecurityLow`/`SecurityHigh`), mas não prova enforcement: uma `API` gerada como `SecurityHigh` pode responder `200` a usuário sem papel se a aplicação GAM estiver com "Habilitar autorização?" desmarcada — falso-positivo de segurança. O enforcement é pré-condição de runtime fora da automação XPZ, documentada em `xpz-builder/responsibilities-by-type/api-gam-runtime.md` (smoke 2 fases 401/403/200 + reversibilidade). OpenAPI mostrando `oAuthGXGAM` não é evidência de enforcement.

## Politica para Theme

- Evidência direta: a consulta ao acervo real confirmou que `Theme` simples valido preserva `PredefinedTypes`, `Styles` e classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- Evidência direta: a bateria de importação mostrou que `Theme` pode falhar mesmo com envelope correto quando o pacote perde classes visuais referenciadas internamente.
- Inferência forte: para `Theme`, a ordem correta de validação e `molde estrutural -> PredefinedTypes e Styles -> classes base existentes -> referencias internas entre classes`.
- Inferência forte: em `Theme`, podar classe "aparentemente sobrando" antes de mapear as referencias internas e a forma mais comum de quebrar o import.
- Hipótese: os erros por `Theme` devem ser tratados por reconstrucao do grafo mínimo de classes, não por simplificacao progressiva do XML.

## Politica para PatternSettings

- Evidência direta: a consulta ao acervo real confirmou que `PatternSettings` embute configuração em `CDATA` com `Pattern="..."`, `ContextVariable`, `LoadProcedure`, `Security` e outros elementos do pattern.
- Evidência direta: a bateria de importação mostrou que `PatternSettings` pode ser lido pela IDE e ainda assim resultar em `was not changed`, com aviso de pattern não registrado.
- Inferência forte: para `PatternSettings`, a ordem correta de validação e `Pattern registrado -> contexto e procedures do pattern -> seguranca e referencias auxiliares -> detalhe declarativo interno`.
- Inferência forte: em `PatternSettings`, editar apenas o XML interno sem garantir pattern e contexto reais tende a produzir objeto estruturalmente aceitavel, mas operacionalmente inutil.
- Hipótese: os erros por `PatternSettings` devem ser tratados como falta de contexto do pattern no ambiente, e não como problema principal de serializacao.

## Politica para Folder

- Evidência direta: a consulta ao acervo real confirmou que `Folder` usa um shape XML mínimo e estavel, com `Object/@type="00000000-0000-0000-0000-000000000006"` e poucos metadados.
- Evidência direta: na bateria de importação, o caso de teste entrou, mas a IDE o exibiu como `Category`, não como `Folder`.
- Evidência direta: as capturas da janela `New Object` da IDE mostram que `Category` nomeia o agrupador visual da lista de tipos criaveis, e não o tipo XML do objeto.
- Evidência direta: nas mesmas capturas, um mesmo tipo pode aparecer sob mais de uma `Category` da UI, portanto `Category` não se comporta como identidade estrutural única de objeto.
- Inferência forte: para `Folder`, a ordem correta de validação e `shape minimo correto -> parent/module coerentes quando existirem -> leitura semantica da IDE`.
- Inferência forte: aqui o risco principal não é quebrar o XML, e sim confundir `Category` da UI com tipo estrutural de objeto.
- Inferência forte: para esta trilha, `Folder` deve ser lido como tipo XML estruturalmente aceito, enquanto `Category` deve ser lido como rotulo de agrupamento/exibicao da IDE.
- Hipótese: o importador pode estar reutilizando o mesmo vocabulário visual da IDE ao relatar `Category`, sem implicar mudanca real do tipo estrutural importado.

## Politica para identidade estrutural de objeto sob Folder ou Module

- Evidência direta: no acervo real desta KB, `Procedure` em `Folder` aparece com `fullyQualifiedName` igual ao nome do objeto, enquanto a pasta aparece em `parent` e `parentGuid`.
- Evidência direta: no acervo real desta KB, `WebPanel` em `Folder` segue o mesmo padrão: `fullyQualifiedName` sem prefixo da pasta, e `parent`/`parentGuid` apontando para o contêiner.
- Evidência direta: no acervo real desta KB, objetos sob `Module` podem trazer qualificacao em `fullyQualifiedName`, como `General.Services.DirectionsServiceRequest`.
- Evidência direta: também existe caso em que o objeto está sob `Folder` dentro de `Module`; nesse perfil, o nome do módulo permanece em `fullyQualifiedName`, mas o nome da pasta continua restrito a `parent`.
- Regra operacional: antes de serializar identidade de objeto, classificar primeiro o contêiner por `parentType`.
- Regra operacional: se `parentType="00000000-0000-0000-0000-000000000008"`, tratar o contêiner como `Module/Folder` (Pasta/Módulo do usuário); o nome da pasta não deve ser promovido automaticamente para `fullyQualifiedName`.
- Regra operacional: se `parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117"`, tratar o contêiner como `PackagedModule` (Módulo instalado); a qualificacao em `fullyQualifiedName` só pode ser mantida ou introduzida quando houver exemplar comparavel da mesma KB confirmando esse padrão.
- Regra operacional: validar sempre em conjunto `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid`; não validar esses campos isoladamente.
- Regra operacional: `fullyQualifiedName` não deve ser derivado por concatenacao textual de `parent + "." + name`.
- Regra operacional: se a trilha não conseguir decidir, por exemplar comparavel, se o contêiner real e `Folder` ou `Module`, a geração deve abortar antes da serializacao.
- Regra operacional: em clonagem ou criacao a partir de XML existente, validar identidade interna ampliada antes de empacotar: `Object/@name`, `fullyQualifiedName`, `guid`, propriedade `Name`, `Description`, `Source`, `Rules/parm`, chamadas internas, dependencias e `ObjectsIdentityMapping`.
- Regra operacional: toda ocorrência residual do nome, descrição, GUID ou chamada do objeto molde deve ser classificada como `intencional`, `dependencia necessaria` ou `erro de clonagem`; ocorrência não classificada bloqueia o pacote.
- Regra operacional: para objeto novo, `guid` novo não basta; nomes internos, propriedades nominais, assinatura, chamadas e dependencias também precisam deixar de apontar indevidamente para o objeto de origem.

## Politica para WebPanel

- Evidência direta: existem 1196 `WebPanel` no acervo.
- Inferência forte: identificar primeiro a familia estrutural antes de gerar.
- Inferência forte: escolher o molde interno mais próximo, sem generalizar `WebPanel` como tipo homogeneo.
- Inferência forte: manter todos os `Part type` recorrentes do molde escolhido.
- Hipótese: abortar apenas quando não houver familia estrutural identificavel ou quando a proximidade do molde continuar ambigua.

## Quando aceitar apenas experimento conservador

- Inferência forte: `PackagedModule` e `Theme` são os melhores candidatos relativos do recorte, mas apenas para experimento muito controlado.
- Inferência forte: `SDT` pode entrar nessa mesma trilha somente quando houver molde muito próximo e preservacao rigorosa de `parent`.
- Inferência forte: `Transaction` e `WebPanel` ficam desbloqueados para execução controlada usando a própria base como fonte de moldes internos.
- Hipótese: nenhum tipo deste acervo deveria ser liberado para geração automática ampla sem uma rodada externa de validação.

## Validacoes minimas antes de empacotar

- XML bem-formado.
- `Object/@type` coerente com o tipo clonado.
- `Part type` recorrentes preservados.
- `parent*` e `moduleGuid` preservados quando presentes no template.
- `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid` conferidos em conjunto contra exemplar comparavel.
- Revisao manual dos campos textuais alterados.
- Diff estrutural curto entre molde-base e clone.

## Estrategia incremental recomendada

- Inferência forte: comecar por provas de conceito extremamente pequenas.
- Inferência forte: manter o escopo por tipo e por molde, sem misturar familias estruturais diferentes.
- Inferência forte: para `Transaction` e `WebPanel`, priorizar execução controlada e retroalimentar a base com os erros observados.
- Inferência forte: só depois de casos externos bem-sucedidos vale endurecer linguagem como "obrigatório", "editavel com baixo risco" ou "apto para geração conservadora".

## Ajuste no algoritmo

- Inferência forte: `Transaction` não deve abortar apenas por ausencia de template externo.
- Inferência forte: `WebPanel` deve abortar apenas quando não houver familia estrutural identificavel ou molde interno suficientemente próximo.

## Regras de materialização

- Evidência direta: a materialização final de `Transaction` e `WebPanel` pode partir de um molde XML completo desta base ou de XML bruto real do mesmo `Object/@type`, desde que a estrutura usada seja completa e comparavel.
- Inferência forte: nunca montar um objeto do zero a partir de descrição em markdown; sempre partir de um molde XML completo e editar o clone.
- Regra operacional: ao materializar um acervo de XMLs individualizados para versionamento, manter serializacao textual consistente entre todos os arquivos do lote.
- Regra operacional: quando o pipeline controlar a escrita desses arquivos, preferir declaracao XML explicita com `encoding="utf-8"` como convencao operacional do acervo, sem tratar isso como prova de exigencia universal do GeneXus para qualquer XML interno.
- Regra operacional: a checagem pos-extracao deve validar não só completude estrutural, mas também consistencia de declaracao XML e encoding declarado entre os arquivos materializados.
### Transaction

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid` e inventario completo de `Part` do molde-base
- não remover `Part` recorrente nem trocar a ordem dos blocos
- alterar apenas campos textuais, nomes e trechos internos que tenham paralelo claro em outros `Transaction` da mesma familia
- validar antes do empacotamento que cada atributo declarado em `Level` exista de fato na KB alvo
- validar que `DescriptionAttribute` e `AttributeProperties` continuem apontando para atributos presentes no mesmo objeto
- validar explicitamente `Context`, `TrnContext` e `TrnContextAtt` quando existirem, incluindo seus `ATTCUSTOMTYPE`
- se um atributo do no `<Object>` não existir no molde usado, não inventar esse atributo no clone
- se o caso exigir inventar atributo, `sdt:Context`, `sdt:TransactionContext` ou `sdt:TransactionContext.Attribute` inexistentes no destino, abortar
- se surgir referencia a `parent`, módulo ou pattern que não exista no molde comparavel, abortar
- `Evidência direta`: em bateria recente de importação real, uma `Transaction` mínima com `1 Level`, `2` atributos, `DescriptionAttribute` e `AttributeProperties` foi aceita com sucesso quando os `Attribute` top-level estavam no pacote e o `Part` principal seguia o shape esperado da familia.
- `Evidência direta`: nessa mesma bateria, `AttributeProperties` funcionou isoladamente e também combinado com `DescriptionAttribute`.
- `Evidência direta`: `DescriptionAttribute` foi aceito no caso mínimo expandido quando apontava para atributo existente no mesmo `Level`.
- `Evidência direta`: o erro `Level is empty` voltou a aparecer em tentativa com atributos presentes quando o shape estrutural do `Part` principal não seguia o template esperado.
- `Inferência forte`: nos casos minimos validados, a aceitacao do `Level` dependeu tanto da disponibilidade real dos atributos quanto da preservacao do shape estrutural do `Part` onde o `Level` foi inserido.
- Regra operacional: `Attribute` inline em `Level` não substitui `Attribute` top-level no pacote.
- Regra operacional: se os atributos do `Level` não existirem previamente na KB de destino, a composicao mínima segura e inclui-los como `Attribute` top-level no mesmo pacote da `Transaction`.
- Regra operacional: `DescriptionAttribute` e opcional no caso mínimo, mas quando presente deve apontar para atributo do mesmo `Level`.
- Regra operacional: `AttributeProperties` e opcional no caso mínimo e já foi validado tanto isoladamente quanto combinado com `DescriptionAttribute`.
- Regra operacional: para primeiro pacote mínimo de `Transaction`, continuar preferindo validar antes a variante mais enxuta, e só depois enriquecer com `DescriptionAttribute`, `AttributeProperties` ou contexto adicional.

### API

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, inventario de `Part` e blocos estruturais de `Service`, `RestMethod`, `Variables` e eventos do molde-base
- validar antes do empacotamento cada `ATTCUSTOMTYPE` presente no molde ou introduzido na edicao
- aceitar apenas `ATTCUSTOMTYPE` comprovado no destino como tipo base suportado, `EXO` existente ou `SDT` existente
- validar que cada `Procedure` chamada em `Source`, eventos ou metadados exista de fato na KB alvo
- não inventar nomes de `EXO`, `SDT` ou `Procedure` para "completar" a API
- se o caso exigir tipos ou procedures inexistentes no destino, abortar em vez de simplificar o XML arbitrariamente

### Theme

- preservar `Object/@type`, `guid`, inventario de `Part`, `PredefinedTypes`, `Styles` e a organizacao geral do molde-base
- validar antes do empacotamento que cada classe visual referenciada por outra classe continue existindo no objeto final
- tratar `TableDetail`, `TableSection`, `TextBlockGroupCaption` e classes equivalentes do molde como candidatas fortes a compor o grafo mínimo
- não remover classe apenas porque ela não parece ser usada diretamente pela tela alvo; primeiro validar referencias indiretas no próprio tema
- se a edicao exigir reduzir o tema abaixo do grafo mínimo de classes referenciadas, abortar em vez de simplificar o XML arbitrariamente

### PatternSettings

- preservar `Object/@type`, `guid`, inventario de `Part` e o bloco `<Data Pattern="..."><![CDATA[...]]></Data>` do molde-base
- validar antes do empacotamento se o `Pattern` referenciado no bloco existe de fato no ambiente de destino
- validar que `ContextVariable`, `LoadProcedure`, `Security`, `NotAuthorized` e referencias equivalentes apontem para objetos reais do destino
- não inventar `Pattern`, `LoadProcedure`, contexto de seguranca ou procedures auxiliares para "completar" o objeto
- se o ambiente não reconhecer o pattern ou os objetos referenciados, abortar em vez de tratar o XML como autocontido

### Table e Index

- tratar `Table` como objeto top-level da camada física e `Index` como estrutura interna embutida
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, bloco de chave e inventario de `Part` do molde-base
- preservar integralmente o bloco `<Indexes>`, sem reordenar `TableIndex`, `Index`, `Members` ou trocar `Type="Automatic|User|Unique|Duplicate"` por conveniencia
- não tentar materializar `Index` como objeto top-level isolado nesta trilha; quando o caso pedir índice, usar `Table` comparavel que já o contenha
- quando o objetivo for ponte com a camada lógica, validar junto a `Transaction` correspondente em vez de analisar a `Table` como se fosse familia totalmente autonoma
- se a mudanca exigir inferir índice inexistente, chave física nova ou correspondencia física não visivel no molde comparavel, abortar

### Folder

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid` e o inventario mínimo de `Part` do molde-base
- preferir o molde mais simples quando a necessidade for apenas organizacao lógica de objetos
- não inflar `Folder` com propriedades extras sem paralelo claro no molde real
- registrar separadamente o tipo estrutural do XML (`Folder`) e o rotulo exibido pela IDE/importador (`Category`, quando ocorrer)
- não reinterpretar `Category` da UI como prova de outro tipo XML concorrente sem evidencia estrutural adicional
- se o objetivo depender da distincao funcional exata entre `Folder` e o rotulo `Category` na interface, tratar o caso como diferenca de nomenclatura da IDE ate prova contraria, e não como falha de envelope
- ao gerar objeto dentro de `Folder`, manter o nome da pasta em `parent`/`parentGuid`; não inserir o nome da pasta em `fullyQualifiedName` sem evidencia direta de corpus

### WebPanel

- escolher primeiro a familia estrutural e só depois o molde interno completo
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, quantidade de `Part` e a ordem dos blocos
- manter `layout`, `events`, `variables` e todos os `Part type` recorrentes do molde selecionado
- não substituir controles, bindings ou componentes raros por texto livre; se não houver equivalente estrutural no molde, abortar
- quando houver anexo sanitizado completo e explicitamente preservado nesta base, ele pode servir como molde de partida para prototipo controlado; na falta disso, recorrer ao XML bruto correspondente

## Regras de serializacao XPZ

- Evidência direta: o XML do objeto deve continuar com raiz única `<Object>` e permanecer bem-formado após qualquer edicao
- Evidência direta: cada `Part` deve manter seu atributo `type` e seu conteúdo no mesmo bloco estrutural do molde-base
- Inferência forte: quando o molde usado trouxer `<![CDATA[...]]>` em `Source` ou `InnerHtml`, o clone deve manter `CDATA`; não converter esses blocos em texto escapado
- Inferência forte: o objeto pode ser incluido em `<Objects>` usando o envelope XPZ observado e documentado nesta base, desde que o prototipo preserve a mesma hierarquia externa conhecida; não inventar estrutura fora do que o envelope observado já demonstra
- Evidência direta: `KMW`, `Source` e `Dependencies` aparecem em todos os `.xpz` validos lidos nesta amostra ampla; `Objects` aparece no formato normal de export de objetos e pode ser substituido por `Attributes` em exportacoes parciais focadas em atributos
- Evidência direta: nos exports normais de objetos com `ObjectsIdentityMapping`, o bloco usa elementos `<ObjectIdentity Type=\"...\" Name=\"...\" parent=\"...\">` contendo `<Guid>...</Guid>`; não aparece como espelho 1:1 dos objetos exportados
- Evidência direta: em amostra ampla de exports normais, `Object/@guid` não reaparece em `ObjectsIdentityMapping`; o papel observado do bloco e descrever identidades de contexto, especialmente pais, módulos e referencias auxiliares
- Evidência direta: `ObjectIdentity/@Name`, `ObjectIdentity/@Type` e `ObjectIdentity/Guid` vieram preenchidos nos exports normais lidos; `Source/Version/@name` também veio preenchido nesses casos
- Evidência direta: no teste de importação bem-sucedida desta trilha, `Source/@kb` e `Source/Version/@guid` precisaram estar em formato GUID valido; placeholders textuais causaram erro de parse antes da importação
- Evidência direta: nos exports normais lidos, `Object/@name` também veio sempre preenchido; `Dependency/Properties/@Name` e `Dependency/Properties/@PackageName`, quando presentes, vieram preenchidos
- Evidência direta: campos de nome opcionais existem, mas não se comportam como invariantes: `Object/@description` apareceu vazio em minoria dos casos e `ObjectIdentity/@parent` apareceu majoritariamente vazio
- Inferência forte: se o objeto exportado tiver `parentGuid` ou `moduleGuid` apontando para contexto externo relevante, o `.xpz` normal fica mais coerente quando `ObjectsIdentityMapping` trouxer a identidade correspondente com o mesmo `Guid`
- Inferência forte: `Dependencies` descreve principalmente metamodelo, parts e pacotes, não o mapeamento principal de identidade entre objetos exportados e contexto
- Inferência forte: para geração de `.xpz` de objetos, o bloco especial de KB (`KnowledgeBase` ou elemento top-level com nome literal da KB) deve ser tratado como proibido
- Hipótese forte: o erro `Fail creating backup: Empty name is not allowed.` está mais ligado ao bloco especial de KB em exports full/especiais, sobretudo quando `KnowledgeBase/@name` falta, do que ao formato normal de `ObjectsIdentityMapping`
- Inferência forte: antes de empacotar, validar parse XML do objeto clonado e validar que o envelope XPZ continua contendo o mesmo padrão estrutural do molde usado
- Hipótese: checksum, datas e outros metadados externos só devem ser recalculados se houver processo real de exportação que faca isso; na ausencia desse processo, preservar o padrão do molde usado

### Campos de nome invariantes no formato normal

- Evidência direta: `Source/Version/@name` não apareceu vazio nos exports normais lidos
- Evidência direta: `Object/@name` não apareceu vazio nos exports normais lidos
- Evidência direta: `ObjectIdentity/@Name` não apareceu vazio nos exports normais lidos
- Evidência direta: `ObjectIdentity/@Type` e `ObjectIdentity/Guid` também vieram sempre preenchidos nos exports normais lidos
- Regra operacional: `ObjectIdentity/@Type` deve ser um GUID valido, derivado do campo `Object/@parentType` do XML de origem do objeto sendo empacotado; nunca usar valor inteiro (como `"1"` ou `"8"`) — valor inteiro causa erro `Guid should contain 32 digits with 4 dashes` no GeneXus durante Import File Load
- Evidência direta: `Source/@kb` e `Source/Version/@guid` precisam ser GUIDs sintaticamente validos para que o GeneXus ao menos aceite o parse inicial do `.xpz`
- Evidência direta: `Dependency/Properties/@Name` e `Dependency/Properties/@PackageName`, quando o no `Properties` existe, vieram preenchidos
- Inferência forte: entre os campos de nome do formato normal, os candidatos mais fortes a obrigatoriedade estrutural são `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name`
- Hipótese forte: como esses campos vieram consistentes no formato normal, o erro `Empty name is not allowed` fica mais plausivelmente associado ao bloco especial `KnowledgeBase/@name` em variantes especiais do que a um campo nominal do envelope normal

### Coerência entre `Objects` e `ObjectsIdentityMapping`

- Evidência direta: `ObjectsIdentityMapping` não repete automaticamente cada objeto de `<Objects>`
- Evidência direta: a correspondencia observada e contextual, principalmente por `parentGuid` e, em muitos pacotes, por `moduleGuid`
- Evidência direta: em amostra ampla de exports normais com `Objects` + `ObjectsIdentityMapping`, a resolucao de `parentGuid` em `Objects` ou `ObjectsIdentityMapping` ocorreu na grande maioria dos casos; para `moduleGuid`, a cobertura foi parcial e frequentemente ligada ao `Root Module`
- Inferência forte: a regra mais segura para serializacao normal de objetos e manter no `ObjectsIdentityMapping` todas as identidades externas realmente referenciadas pelo objeto, sem tentar transformar o bloco em inventario completo de tudo que existe na KB
- Inferência forte: se `parentGuid` ou `moduleGuid` apontarem para um GUID externo que não exista nem em `<Objects>` nem em `<ObjectsIdentityMapping>`, o pacote fica estruturalmente mais fraco e merece cautela extra

### Pares observados validos

- Evidência direta: em `AJRS_MOSTRA_URL.xpz`, o objeto `PRCExemploMostraUrlA` usa `moduleGuid=afa47377-41d5-4ae8-9755-6f53150aa361` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"Root Module\"` com o mesmo `Guid`
- Evidência direta: em `AJRSgxIonicZip.xpz`, o objeto `DotNetZip` usa `parentGuid=65ff024e-84e1-4042-9321-cd3a230317d6` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"ZipUnzip\"` com o mesmo `Guid`
- Evidência direta: em `AJRS_ConcatenaPdfEouPoeMarcaDagua-2.xpz`, o objeto `ZipFile` usa `parentGuid=9f21f62d-2d18-4f8d-8ec3-8399f3485298` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"DotNetZip\"` com o mesmo `Guid`

### Modelo mínimo correto de `.xpz` normal de objetos

```xml
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>4</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <Build>...</Build>
  </KMW>
  <Source kb="GUID_DA_KB" username="USUARIO" UNCPath="\\\\HOST\\CAMINHO">
    <Version guid="GUID_DA_VERSAO" name="NOME_DA_KB" />
  </Source>
  <Objects>
    <Object ... />
  </Objects>
  <Dependencies>
    <Reference ... />
  </Dependencies>
  <ObjectsIdentityMapping>
    <ObjectIdentity Type="..." Name="..." parent="...">
      <Guid>...</Guid>
    </ObjectIdentity>
  </ObjectsIdentityMapping>
</ExportFile>
```

- Evidência direta: `Attributes` e um bloco adicional comum no formato normal, mas não invariavel
- Inferência forte: para geração conservadora de objetos comuns, este envelope mínimo continua sendo referencia útil, mas não deve ser promovido a formato universal para qualquer pacote misto
- Evidência direta: esse envelope mínimo já sustentou uma importação bem-sucedida de um `Procedure` de teste nesta trilha, desde que os GUIDs de `Source` fossem sintaticamente validos
- Evidência direta: em frente posterior desta mesma trilha, um pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure` só passou quando foi remontado como pacote embutido, tomando export real comparavel da IDE como molde.

## Regras de fonte

- Fonte valida: XML bruto extraido do acervo ou de export XPZ real comparavel
- Fonte valida: molde sanitizado documentado nesta base, quando o anexo embutir XML completo suficiente para o tipo e a familia alvo e estiver marcado como `molde pronto`
- Fonte invalida: markdown meramente descritivo, sem XML completo
- Fonte invalida: reconstrucoes feitas só por resumo textual, tabela, frequência ou memoria do agente
- Fonte invalida: tentativa de sintetizar `KnowledgeBase`, `Settings` ou bloco top-level com nome da KB em `.xpz` gerado para objetos comuns
- Inferência forte: `04-webpanel-familias-e-templates.md` já contem moldes sanitizados completos para familias de `WebPanel`
- Inferência forte: `05-transaction-familias-e-templates.md` agora também contem moldes sanitizados completos para familias representativas de `Transaction` (`F1`, `F2`, `F5` e `F6`)
- Inferência forte: a serie `01` agora distribui moldes sanitizados completos representativos de `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em `01e` ate `01h`
- Hipótese: mesmo com anexos representativos, `WorkWithForWeb` continua entre os tipos mais sensiveis a `pattern`, `parent` transacional e contexto gerado; por isso, casos muito distantes do molde documentado ainda podem pedir paralelo bruto mais próximo
- Hipótese: as familias `F3` e `F4` de `Transaction` ainda ficam mais seguras com molde bruto comparavel adicional, por terem densidade estrutural maior e ainda não terem anexo completo próprio
- Inferência forte: para o envelope externo do XPZ observado, a especificacao desta própria base já e suficiente para evitar inventar `Objects.xml` isolado ou hierarquia externa sem prova local

## Validação funcional pos-import: objetos com insumo externo oficial

- `Regra operacional`: quando o XPZ importado contiver objeto que consome insumo externo oficial (planilha, arquivo de dados, configuração externa), a prova de import não encerra a frente funcional.
- `Regra operacional`: o agente deve declarar explicitamente que o import provou que o objeto entrou na KB com a estrutura esperada, mas não provou que o objeto se comporta corretamente com o insumo real.
- `Regra operacional`: a confirmacao funcional exige teste com o insumo oficial na versão correta e no formato esperado pelo objeto; esse teste e responsabilidade da frente funcional, não da trilha de import.
- `Regra operacional`: essa camada complementa os sub-estados já definidos na skill `xpz-msbuild-import-export` — em particular `importacao real efetiva provada` — com consciencia explicita do insumo externo como dimensao de validação separada.
- `Regra operacional`: ausencia de teste funcional com insumo real não invalida o sub-estado de import já declarado; são camadas independentes.

## Limite do XPZ/XML frente a providers e extensoes GeneXus

- `Regra operacional`: o acervo XPZ/XML materializado em `ObjetosDaKbEmXml` e fonte normativa para objetos GeneXus exportaveis comuns; ele não cobre metadados internos de providers, designers ou extensoes que a KB persiste diretamente no banco interno.
- `Regra operacional`: quando um warning de abertura, build ou export da KB mencionar provider ausente, item desconhecido, designer, part ou metadado de extensao, classificar o item citado antes de buscar no XPZ/XML: (a) objeto GeneXus exportavel comum; (b) part/metadado interno; (c) designer/provider de extensao; (d) tipo desconhecido.
- `Regra operacional`: se a busca no XPZ/XML for negativa e o item não pertencer a categoria (a), a conclusao deve ser limitada: "não encontrado no XPZ/XML" — nunca "não existe na KB".
- `Regra operacional`: as seis verbalizacoes canonicas de conclusao para esse caso são, em ordem de certeza crescente: `nao encontrado no XPZ/XML`, `nao exportado como objeto comum`, `possivel metadado interno de provider`, `confirmado em tabela interna da KB`, `provider ausente ou incompativel no ambiente`, `remocao requer ferramenta oficial ou suporte`.
- `Regra operacional`: nunca usar apenas o resultado negativo da busca no XPZ/XML para concluir que o warning de provider e falso ou que não ha residuo na KB.
- `Regra operacional`: termos que devem acionar classificação antes de concluir ausencia: `FormDesigner`, `WebPanelDesigner`, `SDPanelDesigner`, `Object Designer`, `FormDesignerPart`, `provider GUID`, `extension provider`, `item desconhecido` e qualquer GUID não reconhecido citado em warning de abertura ou build.
- `Regra operacional`: referencia textual a K2B, K2BTools ou nome de framework no XML exportado não é, por si só, evidencia de provider ausente; pode ser consumo legitimo de design system ou framework. Não confundir objeto funcional com metadado interno de designer.
- `Regra operacional`: diagnostico SQL somente leitura no banco interno da KB e o caminho para evidencia de segunda camada, quando o XPZ/XML não cobrir o item. Esse diagnostico só deve ser sugerido quando houver evidencia concreta de provider/item desconhecido na abertura ou build, e nunca como varredura de rotina.

## Tipo desconhecido no catálogo XPZ (sync bloqueado)

- `Regra operacional`: quando `Sync-GeneXusXpzToXml.ps1` ou a pre-varredura (`Get-GeneXusImportPackageObjectInventory.ps1` com `-FailOnUnknownTypes`) reportarem GUID de `Object/@type` ausente do catálogo efetivo, tratar como lacuna de catálogo da base XPZ — não como defeito do XPZ exportado pela KB.
- `Regra operacional`: não materializar parcialmente nem improvisar pasta `Unknown_*` em `ObjetosDaKbEmXml` sem decisão explicita do usuário e entrada documentada no override local.
- `Regra operacional`: antes de sync full ou primeira materialização longa, executar inventario do pacote com `-FailOnUnknownTypes`; se bloquear, não chamar materialização.
- `Regra operacional`: ao detectar tipo desconhecido, perguntar ao usuário se autoriza consulta recomendavel a skill `nexa` e documentação oficial GeneXus (`docs.genexus.com`, `wiki.genexus.com`); não consultar automaticamente sem consentimento.
- `Regra operacional`: registro local paliativo somente em `scripts/gx-object-type-catalog.override.json` na pasta paralela, via `Register-GeneXusObjectTypeCatalogOverride.ps1` com `-UserApproved` após consentimento explicito; manter `upstreamPending=true` ate o mantenedor atualizar `scripts/gx-object-type-catalog.json` e `01a-catalogo-e-padroes-empiricos.md` em GeneXus-XPZ-Skills.
- `Regra operacional`: override local não é silencioso — em cada nova sessao na pasta paralela, executar `Test-XpzCatalogOverrideSessionReminder.ps1` e repetir ao usuário que ainda falta alinhar o catálogo compartilhado.
- `Regra operacional`: oferecer `New-GeneXusUnknownTypeMaintainerPrompt.ps1` para gerar prompt copiavel ao mantenedor da base XPZ; não editar GeneXus-XPZ-Skills a partir da pasta paralela sem troca de contexto explicita.
- `Regra operacional`: o fluxo de tipo desconhecido acima vale para export **moderno** (GUID em `Object/@type`). Export **legado GeneXus 9** (`ExportFile` com `<GXObject><Elemento>` por nome, sem GUID de tipo) é caso distinto: governado pelo registro `scripts/gx-legacy-export-element-registry.json` (doc-dono `01k-registro-elementos-legados.md`), que classifica cada elemento como `equivalent` (reusa tipo moderno) ou `orphan` (`typeToken` `gxlegacy/<Elemento>`). Não inventar GUID, não reusar o GUID do tipo moderno sucessor como identidade do elemento legado, nem registrá-lo no catálogo/override moderno.
- `Regra operacional`: o **motor de export/materialização legado já existe e está integrado** ao `Sync-GeneXusXpzToXml.ps1` (ramo legado: materializa cada elemento em envelope moderno `Object`/`Attribute` com `dataSource="gx-legacy-export"`/payload em `GxLegacyPayload`/`guid=""`; equivalent→GUID real do catálogo, orphan→`type="gxlegacy/<Elemento>"`) e ao `Get-GeneXusImportPackageObjectInventory.ps1` (itens `known-legacy`). Leitura **encoding-aware** local (export GX9 é iso-8859-1, lido por `XmlDocument.Load`, não `Get-Content -Raw`). **Pacote misto** (elementos legados `<GXObject>` e modernos `<Objects>`/`<Attributes>` no mesmo `ExportFile`) é **fail-closed** (`throw` em ambos os motores, sem gravar `kb-source-metadata.md`). No perfil legado, o Sync expõe `LegacyFormatDetected=true` e `MaterializationInterpretation=legacy-export-adapted`; o Inventory devolve `unknownTypeCount=0`/`unknownTypesDiscovery=[]` (fail-closed de tag desconhecida vive no parser legado, não no discovery moderno por GUID). Tag fora do registro → `throw` com instrução de estender o registro. Ver `01k`, `xpz-sync/SKILL.md`, `xpz-reader/SKILL.md`.
- `Evidência direta`: motores `Sync-GeneXusXpzToXml.ps1`, inventario, `Test-XpzObjetosDaKbNaming.ps1` e `Build-KbIntelligenceIndex.py` (via `Build-KbIntelligenceIndex.ps1`) aceitam `-ParallelKbRoot` / `-CatalogOverridePath` (ou deteccao automática de `scripts/gx-object-type-catalog.override.json` a partir de `ObjetosDaKbEmXml`) e usam o mesmo catalogo efetivo (base + override); sync e inventario agregam amostras (`name`, `parent`, `parentType`, snippet XML) em falha ou JSON de triagem.
- `Evidência direta`: `scripts/GeneXusPythonPrerequisite.ps1` e `Build-KbIntelligenceIndex.ps1` exigem Python 3 utilizavel (exit `8`, mensagem `PREREQUISITO AUSENTE`); falha do `.py` propaga saida capturada; molde `Update-KbFromXpz.example.ps1` chama rebuild no mesmo `pwsh` e prefixa que a materialização XPZ/XML pode ter concluido; **rigor**: sync oficial **não** termina sem índice regenerado — declarar **fluxo incompleto**, não declarar sync OK nem autorizar triagem ampla sem índice; ver `README.md`, `08-guia-para-agente-gpt.md` e `xpz-sync`.
- `Regra operacional`: o resultado do `Sync-GeneXusXpzToXml.ps1` é **uma linha JSON de máquina no stdout** (`Kind=xpz-sync-result`, `SchemaVersion=1`, `-Compress`), com todo texto humano no **stderr** — consumir via `ConvertFrom-Json`, não parsear texto. Em processo filho (`pwsh -File`), `Write-Host`/`Write-Warning`/`Write-Information` vazam para o stdout capturado; só `[Console]::Error` (fd 2) fica de fora, por isso o contrato exige stderr para diagnóstico. O resultado traz listas nominais (`CreatedNames`/`UpdatedNames`/`UnchangedNames`/`SkippedOlderLastUpdateNames` no formato `Tipo:Nome`, `RenamedByGuidItems`, e `Expected*Names` com `-ExpectedItems`) que dispensam `git diff` para nomear objetos; o `$report` completo (com `Writes`/`Renames` crus) segue via `-ReportPath`. Mudança de contrato (era texto `Format-List`) registrada no `CHANGELOG.md`. Dono: `xpz-sync/SKILL.md`.
- `Regra operacional`: **detecção cross-fluxo de origem (`dataSource`)** — o Sync detecta, antes de gravar metadata/XML, quando um item entrante colide no acervo (`FolderType|NormalizedName`) com um arquivo de origem diferente (caso central moderno sem `dataSource` ↔ legado `dataSource="gx-legacy-export"`). Campo aditivo `CrossFlowCollisions` (array; `[]` vazio; item `{FolderType, NormalizedName, LogicalName, ExistingDataSource, IncomingDataSource, FilePath}`) no stdout + `Writes[].CrossFlowCollision` (booleano) no `$report`; também por stderr (`CROSSFLOW_COLLISION:` JSONL). `SchemaVersion` permanece `1` (aditivo — varredura de consumidores executada: o único molde que lê o JSON, `Update-KbFromXpz.example.ps1`, acessa por nome e tolera campos novos). Switch opt-in `-BlockCrossFlowDataSource` aborta (terminating error `ErrorId=CrossFlowDataSourceCollisionBlocked`) antes de qualquer metadata/XML; para XML existente não-parseável (Decisão G) a detecção não gera colisão nem bloqueia, só um warning — sem garantir a sobrescrita (o sync pode falhar adiante em estágios de parse preexistentes, fora do escopo). **Ressalva normativa de atomicidade:** os bloqueios pré-metadata valem para a nova detecção e para os fail-closed reordenados do ramo moderno (tipo desconhecido / colisão intra-pacote, que passaram a abortar **antes** da gravação de `kb-source-metadata.md`); **não** valem para `Resolve-GuidAwareRenames` (rename sob `-FullSnapshot`), que continua abortando **pós-metadata** e pode deixar metadata gravada sem writes. Dono: `xpz-sync/SKILL.md`; também `01k-registro-elementos-legados.md`.
