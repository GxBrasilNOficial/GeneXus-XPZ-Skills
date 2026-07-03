# 09 - Inventario e Rastreabilidade Publica

## Papel do documento
índice e rastreabilidade

## Nível de confianca predominante
alto

## Depende de
nenhum

## Usado por
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md

## Objetivo
Preservar rastreabilidade da consolidacao, inventario documental, inventario bruto publico sanitizado e o mapeamento usado para reorganizar a base consolidada.

## Nota sobre histórico detalhado

- `Evidência direta`: a raiz desta base passou a priorizar estado atual de trabalho, sem manter no corpo principal a arqueologia completa das rodadas de teste.
- `Evidência direta`: o histórico detalhado de validacoes, rodadas de importação e reclassificacoes deve ficar separado em `historico/`, para não competir com os `.md` operacionais da raiz.

## Nota sobre documentos de governança pública

- `Evidência direta`: `CHANGELOG.md` registra mudanças relevantes a partir da adoção do changelog, sem reconstruir retroativamente versões antigas.
- `Evidência direta`: `CONTRIBUTING.md` orienta contribuições humanas, revisão pré-push, cuidado com dados reais e avaliação de atualização do changelog quando houver impacto público.
- `Evidência direta`: `SECURITY.md` define o fluxo privado para reportar vulnerabilidades, vazamentos e riscos operacionais sensíveis.
- `Evidência direta`: `CODE_OF_CONDUCT.md` define o código de conduta aplicável às interações ligadas ao projeto.

## Nota sobre a rastreabilidade privada

- `Evidência direta`: existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada para manter rastreabilidade editorial entre aliases publicos e artefatos reais.
- `Regra editorial`: essa rastreabilidade privada não substitui a documentação consolidada desta raiz; ela existe apenas como apoio privado de manutencao, sanitizacao e continuidade editorial.

## Nota sobre o motor operacional compartilhado

- `Evidência direta`: o script `scripts/Sync-GeneXusXpzToXml.ps1` e parte da infraestrutura operacional desta base publica.
- `Evidência direta`: esse script pode ser consumido por wrappers e fluxos locais de projetos de producao que mantenham acervos versionados de XMLs extraidos de `XPZ`.
- `Regra editorial`: a pasta `scripts/` existe como apoio operacional e utilitario compartilhavel, mas não funciona como fonte normativa da documentação consolidada da raiz.
- `Regra operacional`: esse arquivo não deve ser apagado silenciosamente do repositório publico.
- `Regra operacional`: se houver refatoracao, mudanca de local ou substituicao do motor, a alteracao deve ser documentada explicitamente e propagada aos consumidores externos antes de remover o arquivo anterior.
- `scripts/Sync-GeneXusXpzToXml.ps1` (motor) — materializa XMLs de pacote XPZ e reconcilia o acervo; em `-FullSnapshot` reconcilia rename por `guid` (Move-Item, fail-closed em colisão); `-KbMetadataPath` persiste metadados da KB via `scripts/XpzKbSourceMetadataEditSupport.ps1`; pré-varredura de catálogo (`-ParallelKbRoot`/`-CatalogOverridePath`/`-DiscoveryReportPath`). Resultado = **linha JSON de máquina no stdout** (`Kind=xpz-sync-result`, `SchemaVersion=1`, `-Compress`; **breaking change** vs. o texto `Format-List` anterior — texto humano agora no stderr) com listas nominais `CreatedNames`/`UpdatedNames`/`UnchangedNames`/`SkippedOlderLastUpdateNames`/`RenamedByGuidItems` e `Expected*Names` (achatadas); `$report` completo (com `Writes`/`Renames` crus) segue via `-ReportPath`. **Detecção cross-fluxo de `dataSource`** (`Get-GeneXusCrossFlowDataSourceCollisions` + helper `Resolve-ItemDestinationPath`): novo campo aditivo `CrossFlowCollisions` (stdout) + `Writes[].CrossFlowCollision` (`-ReportPath`); switch `-BlockCrossFlowDataSource` (terminating error `ErrorId=CrossFlowDataSourceCollisionBlocked`); prefixos de stderr `CROSSFLOW_COLLISION:`/`CROSSFLOW_WARNING:`/`CROSSFLOW_BLOCKED_ERRORID:`; `SchemaVersion` mantém `1` (aditivo). Ramo moderno reordenado (fail-closed de tipo desconhecido/intra-pacote passam a pré-metadata; rename `-FullSnapshot` segue pós-metadata). Dono: xpz-sync/SKILL.md; também 02-regras-operacionais-e-runtime.md e 01k-registro-elementos-legados.md. Validação: Test-XpzSyncGuidRenameSelfTest.ps1, Test-XpzSyncCrossFlowCollisionSelfTest.ps1. Tokens: `OK: Test-XpzSyncGuidRenameSelfTest.ps1`, `GENEXUS_XPZ_SYNC_CROSSFLOW_SELFTEST_OK`.
- `scripts/gx-object-type-catalog.json` (catálogo) — GUIDs de tipos de objeto (ex.: `DataView`, `SmartDevicesApplication`, `SmartDevicesPlus`) e `exportTaskLabel` quando o rótulo da task Export diverge do tipo. Dono: 01a-catalogo-e-padroes-empiricos.md; também 10a-gx-export-task-labels.md. Validação: via GeneXusObjectTypeCatalogSupport.ps1 e Build-KbIntelligenceIndex.py.
- `scripts/gx-legacy-export-element-registry.json` (registro) — classifica elementos de export legado GeneXus 9 (`<GXObject><Elemento>` por nome, sem GUID de tipo) como `equivalent` (reusa tipo/`folderName` do catálogo via `catalogType`) ou `orphan` (`materializedFolderName` + `typeToken` `gxlegacy/<Elemento>` + `modernSuccessor`/`successorRelation`); fora do catálogo moderno por design. Camada de representação/governança. O **parser/conversor** legado (`scripts/GeneXusLegacyExportFileSupport.ps1`, ver abaixo) e a **integração no fluxo de sync/inventário** (`Sync-GeneXusXpzToXml.ps1`/`Get-GeneXusImportPackageObjectInventory.ps1`) já consomem este registro. Dono: 01k-registro-elementos-legados.md. Validação: Test-GeneXusLegacyRegistrySchemaSelfTest.ps1, Test-GeneXusLegacyRegistryDisjointSelfTest.ps1.
- `scripts/Test-GeneXusObjectTypeCatalogPuritySelfTest.ps1` (motor) — pureza do catálogo moderno: `objectTypeGuid` null só em `rootKind` Attribute; demais `rootKind` exigem UUID válido; fail-safe para `rootKind` novo. Não usa heurística "parece sintético" (GUIDs `dcdcdcdc-…`/`ecececec-…` são reais). Dono: 01a-catalogo-e-padroes-empiricos.md. Validação: self-test. Tokens: `GENEXUS_CATALOG_PURITY_SELFTEST_OK`.
- `scripts/Test-GeneXusLegacyRegistrySchemaSelfTest.ps1` (motor) — forma intra-registro: `schemaVersion`, `class` equivalent|orphan, campos exatos por classe, `typeToken` (regex `^gxlegacy/[A-Za-z][A-Za-z0-9]*$`) e coerência `successorRelation`×`modernSuccessor`. Dono: 01k-registro-elementos-legados.md. Validação: self-test. Tokens: `GENEXUS_LEGACY_REGISTRY_SCHEMA_SELFTEST_OK`.
- `scripts/Test-GeneXusLegacyRegistryDisjointSelfTest.ps1` (motor) — disjunção registro×catálogo: nome de órfão/`typeToken`/`materializedFolderName` não colidem com tipo/`folderName` do catálogo; `catalogType` de cada `equivalent` e `modernSuccessor` não nulo existem no catálogo. Dono: 01k-registro-elementos-legados.md. Validação: self-test. Tokens: `GENEXUS_LEGACY_REGISTRY_DISJOINT_SELFTEST_OK`.
- `scripts/GeneXusLegacyExportFileSupport.ps1` (motor) — parser/conversor próprio de export legado GeneXus 9: dado o `[xml]` já carregado encoding-aware e o `MergedCatalog`, converte `/ExportFile/GXObject/<Elemento>` e `/ExportFile/Attributes/GXAtt/Attribute` em envelopes modernos `Object`/`Attribute` (`dataSource="gx-legacy-export"`, payload em `GxLegacyPayload`, `guid=""`), consumindo `gx-legacy-export-element-registry.json` — `equivalent`→`type=<GUID real do catálogo>`/`orphan`→`type="gxlegacy/<Elemento>"`; `lastUpdate` ausente/inválido → sentinela determinística `0001-01-01T00:00:00.0000000Z` (nunca `Get-Date`); **fail-closed** para misto, tag fora do registro, >1 elemento-filho por `GXObject` e colisão `FolderType|NormalizedName`. Detecção de perfil compartilhada (`Test-GeneXusLegacyExportFilePackage`/`Test-GeneXusMixedExportFilePackage`), consumida por **Sync** e **Inventory**. Já **integrado ao fluxo**: ramo legado de `Sync-GeneXusXpzToXml.ps1` (materialização no acervo + metadata `-IsLegacyExport`) e de `Get-GeneXusImportPackageObjectInventory.ps1` (itens `known-legacy`). Dono: 01k-registro-elementos-legados.md. Validação: Test-GeneXusLegacyExportFileSupportSelfTest.ps1, Test-XpzSyncLegacyExportFullSnapshotSelfTest.ps1, Test-XpzKbSourceMetadataLegacySelfTest.ps1, Test-XpzInventoryLegacyExportSelfTest.ps1. Tokens: `GENEXUS_LEGACY_EXPORT_FILE_SUPPORT_SELFTEST_OK`.
- `scripts/GeneXusLegacyExportFileFixtureSupport.ps1` (apoio a teste) — gera a fixture de export legado GeneXus 9 em **iso-8859-1** (bytes Latin-1 reais) numa pasta temporária informada pelo chamador, consumida pelos self-tests do motor legado; versionado em UTF-8/LF (evita versionar `.xml` iso-8859-1, frágil à transcodificação por editor/git). Dono: cabeçalho do script. Validação: consumido por Test-GeneXusLegacyExportFileSupportSelfTest.ps1.
- `scripts/Test-GeneXusLegacyExportFileSupportSelfTest.ps1` (motor) — self-test isolado do parser legado: leitura encoding-aware via `.xml` e `.xpz` (acento Latin-1 preservado, não transliterado), detecção de perfil resistente a nós aninhados em payload (XPath-não-vaza), `equivalent`→GUID real / `orphan`→`gxlegacy/Report` e `gxlegacy/Menubar`, sentinela, `guid=""`/`dataSource`/`GxLegacyPayload`, inventário `known-legacy`, delta declarado órfão registry-aware e os quatro fail-closed (misto, tag desconhecida, >1 filho, colisão). Dono: cabeçalho do script. Validação: self-test. Tokens: `GENEXUS_LEGACY_EXPORT_FILE_SUPPORT_SELFTEST_OK`.
- `scripts/Test-XpzSyncLegacyExportFullSnapshotSelfTest.ps1` (motor) — self-test ponta-a-ponta do ramo legado de `Sync-GeneXusXpzToXml.ps1` (processo filho real): `-FullSnapshot` legado não crasha sob StrictMode (o PR original quebrava com `property 'Guid'`), `LegacyFormatDetected`/`MaterializationInterpretation=legacy-export-adapted`/`RenamedByGuid=0`; releitura do disco (`equivalent`→GUID real, `orphan`→`type="gxlegacy/Report"`, `guid=""`, `GxLegacyPayload`); sentinela×data real→`skipped-older-lastUpdate`; misto→throw sem gravar `kb-source-metadata.md`; tag fora do registro + `KbMetadataPath`→throw sem criar/alterar metadata. Dono: cabeçalho do script. Validação: self-test. Tokens: `XPZ_SYNC_LEGACY_EXPORT_FULLSNAPSHOT_SELFTEST_OK`.
- `scripts/Test-XpzSyncCrossFlowCollisionSelfTest.ps1` (motor) — self-test da detecção de divergência de origem (`dataSource`) cross-fluxo moderno↔legado em `Sync-GeneXusXpzToXml.ps1` (processo filho real; fixture legada como incoming + arquivos pré-plantados simulando o outro fluxo): colisão fail-soft (`CrossFlowCollisions` no stdout + `CROSSFLOW_COLLISION:` no stderr), mesmo-fluxo sem colisão, Decisão E.2 (`<GxLegacyPayload>` na ausência de `dataSource`), `-BlockCrossFlowDataSource` com atomicidade de metadata (sem metadata, sem Summary, `CROSSFLOW_BLOCKED_ERRORID:`), `-VerifyOnly` com/sem `-Block`, não-parseável fail-safe (Decisão G), booleano `Writes[].CrossFlowCollision` por item. Dono: cabeçalho do script; também 01k-registro-elementos-legados.md. Validação: self-test. Tokens: `GENEXUS_XPZ_SYNC_CROSSFLOW_SELFTEST_OK`.
- `scripts/Test-XpzKbSourceMetadataLegacySelfTest.ps1` (motor) — self-test do ramo legado de `XpzKbSourceMetadataEditSupport.ps1` (`-IsLegacyExport`): (a) legado com `KMW/MaxGxBuildSaved` sem `<Source>` → Build do `MaxGxBuildSaved`, hint legado literal presente, warning genérico ausente; (b) não-regressão moderno (mesmo pacote sem `-IsLegacyExport` mantém o warning genérico e não aplica o fallback de Build); (c) não-regressão moderno completo (`status=complete`, sem warnings, Build de `KMW/Build`). Dono: cabeçalho do script. Validação: self-test. Tokens: `XPZ_KB_SOURCE_METADATA_LEGACY_SELFTEST_OK`.
- `scripts/Test-XpzInventoryLegacyExportSelfTest.ps1` (motor) — self-test ponta-a-ponta do ramo legado de `Get-GeneXusImportPackageObjectInventory.ps1` (processo filho real): perfil legado-puro → `legacyFormatDetected=true`, itens `known-legacy` (`equivalent`→tipo moderno, `orphan`→`gxlegacy/Report`/`gxlegacy/Menubar`, `guid=null`), `unknownTypeCount=0`/`unknownTypesDiscovery=[]` (guarda contra regressão do gotcha StrictMode `if`-expressão `@()`→`$null`); delta declarado órfão registry-aware (`Report:RelMov`→`gxlegacy/Report:RelMov`, `matchedCount=3`); pacote misto → BLOCK. Dono: cabeçalho do script. Validação: self-test. Tokens: `XPZ_INVENTORY_LEGACY_EXPORT_SELFTEST_OK`.
- `scripts-maintenance/GeneXusExportTaskLabelSupport.ps1`, `Build-ExportTaskLabelCoverageMap.ps1`, `Run-ExportTaskLabelMatrix.ps1`, `Invoke-ExportTaskLabelCampaign.ps1`, `Merge-ExportTaskLabelCampaignResults.ps1` (manutenção) — campanha da matriz `exportTaskLabel` (cobertura, execução MSBuild por tipo, consolidação, `-ApplyCatalog`); não-runtime das skills. Dono: 10a-gx-export-task-labels.md; rodada em `historico/export-task-label-matrix-20260530/`.
- `scripts/Get-GeneXusImportPackageObjectInventory.ps1` (motor) — inventaria `import_file.xml`/`<ExportFile>`/`.xpz`, agrega `objectsByType`, detecta plataforma/SDK e confronta delta declarado (`-DeclaredDeltaPath`/`-DeclaredDeltaItems`); `-FailOnUnknownTypes` (exit 3). Dono: xpz-msbuild-import-export/SKILL.md; também xpz-builder/SKILL.md. Validação: Test-GeneXusImportPackageObjectInventorySelfTest.ps1. Tokens: `INVENTORY_OK`, `GENEXUS_PKG_INVENTORY_SELFTEST_OK`. Exit: 3.
- `scripts/GeneXusObjectListIdentityPreflight.ps1` (motor) — valida identidade `Tipo:Nome` contra KbIntelligence antes de export/import seletivo MSBuild (consumido por Invoke-GeneXusXpzExport/Import e Test-GeneXusXpzImportPreview); homônimo ou índice ausente → exit 35, `not_in_index` apenas avisa. Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusObjectListIdentityPreflightSelfTest.ps1. Exit: 35.
- `scripts/GeneXusXpzExportInventoryGovernance.ps1` (motor) — classifica `operationalSubState` de export (precedência: exportErrors > inventário degradado > sub-estado do inventário). Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusXpzExportSubStateClassifierSelfTest.ps1. Tokens: `EXPORT_SUBSTATE_CLASSIFIER_SELFTEST_OK`.
- `scripts/msbuild-exit-codes.catalog.json` (catálogo) — índice versionado de `exitCode` dos wrappers MSBuild. Dono: o próprio JSON; também 10-base-operacional-msbuild-headless.md. Validação: Test-MsBuildExitCodesCatalog.ps1. Tokens: `MSBUILD_EXIT_CODES_CATALOG_OK`. Exit: 10-16/31-35/40-50/90.
- `scripts/GeneXusMsBuildLogPathSupport.ps1` (motor) — gate fail-fast: rejeita `-LogPath` que aponta para diretório existente (exit 50), nos 10 wrappers MSBuild que recebem `-LogPath`. Dono: cabeçalho do script; também msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildLogPathSupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_LOGPATH_SUPPORT_SELFTEST_OK`. Exit: 50.
- `scripts/GeneXusMsBuildConcurrencySupport.ps1`, `scripts/Test-GeneXusMsBuildKbConcurrency.ps1` (motor) — bloqueio preventivo de `MSBuild.exe` concorrente na mesma KB (exit 46); processo sem `.msbuild`/`KBPath` reconciliável apenas avisa; a trilha não enfileira nem retenta. Dono: xpz-msbuild-build/SKILL.md; também xpz-msbuild-import-export/SKILL.md, msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildConcurrencySupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_CONCURRENCY_SUPPORT_SELFTEST_OK`. Exit: 46.
- `scripts/Invoke-GeneXusKbBuildAll.ps1` (motor) — build headless da KB; bloqueia `CompileMains=true`/`DetailedNavigation=true` sem `-AllowCostlyBuildOptions` (frase de confirmação exata; `AllowCostlyBuildOptionsRequested`/`AllowCostlyBuildOptionsConfirmed`/`ConfirmCostlyBuildOptionsMode`); bloqueia (exit 46, `environment-validacao-indefinido`) em KB multi-environment sem environment de validação resolvido (`deploymentEnvironmentContext`); watcher padrão ou modo desacoplado opt-in. Dono: xpz-msbuild-build/SKILL.md. Validação: via orquestrador. Exit: 46.
- `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` (motor) — specify/generate headless; bloqueia `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`; mesmo bloqueio de environment (exit 46, `environment-validacao-indefinido`). Dono: xpz-msbuild-build/SKILL.md. Validação: via orquestrador. Exit: 46.
- `scripts/Invoke-GeneXusXpzImportThenBuild.ps1` (motor) — wrapper integrador import→build (filhos em `pwsh -File`); só chama `BuildAll` quando `importReadyForBuild.ready=true`; senão `roundtripStatus='import-blocked-or-failed'`, `buildJson=null`. Dono: xpz-msbuild-import-export/SKILL.md; também xpz-msbuild-build/SKILL.md. Validação: via orquestrador. Exit: 46.
- `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1`, `scripts/Register-GeneXusKbPostBuildEvents.ps1` (motor) — extrai e classifica eventos pós-build do stdout MSBuild (esperado/inesperado/inerte/benigno, `shouldDowngrade`); registro de fingerprints por environment (`kb_environment_post_build_event_hashes`). Dono: xpz-msbuild-build/SKILL.md; registro sob xpz-kb-parallel-setup/SKILL.md. Validação: Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1, Test-GeneXusPostBuildEventClassificationSelfTest.ps1, Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_POST_BUILD_EVENTS_SUPPORT_SELFTEST_OK`, `GENEXUS_POST_BUILD_EVENT_CLASSIFICATION_SELFTEST_OK`, `GENEXUS_KB_POST_BUILD_EVENTS_REGISTRATION_SELFTEST_OK`.
- `scripts/GeneXusMsBuildGamPlatformsSupport.ps1` (motor) — filtra ruído GAM/NetCore no stdout (`MSB3491`/`NuGet.targets` acesso negado sob `\Library\GAM\Platforms\`) e sugere `icacls` (não executa concessão NTFS); pós-processamento resiliente, não rebaixa MSBuild limpo para exit 90. Dono: xpz-msbuild-build/SKILL.md. Validação: Test-GeneXusMsBuildGamPlatformsSupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_GAM_PLATFORMS_SUPPORT_SELFTEST_OK`.
- `scripts/Read-MsBuildImportSignals.ps1`, `scripts/GeneXusMsBuildCategoryBSupport.ps1` (motor) — classifica linhas `error :` do log MSBuild por estágio e rebaixa para Categoria B (exit 48) quando `executionEvidence.msBuildExitCode=0` mas há rejeição no log; `operationalSubState` por trilha. Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md, msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildCategoryBSupportSelfTest.ps1, Test-GeneXusXpzExportErrorBarringSelfTest.ps1. Tokens: `MSBUILD_CATEGORY_B_SUPPORT_SELFTEST_OK`, `EXPORT_ERROR_BARRING_SELFTEST_OK`. Exit: 48.
- `scripts/gx-platform-objects.json`, `scripts/GeneXusPlatformObjectsCatalogSupport.ps1` (catálogo) — objetos de plataforma/SDK (`kind` packagedModule|externalObject). Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusPlatformObjectsCatalogSelfTest.ps1. Tokens: `GENEXUS_PLATFORM_OBJECTS_CATALOG_SELFTEST_OK`.
- `scripts/Test-XpzParameterNamingContract.ps1` (motor) — trava por metadados (`Get-Command`) a nomenclatura/aliases de parâmetros das skills XPZ (`-ObjectList`/`-ObjectNames`, `-InputPath`/`-Path`, `-XpzPath`; e a trava negativa do `-AsJson` em Test-GeneXusSourceSanity). Dono: 02-regras-operacionais-e-runtime.md. Validação: gate próprio. Tokens: `XPZ_PARAMETER_NAMING_CONTRACT_OK`.
- `scripts/XpzWrapperEngineParamSupport.ps1` (support-library, dot-source) — check genérico do inventário de wrappers: por AST + `Get-Command` (sem executar motor, sem KB) verifica que todo parâmetro que um wrapper local **repassa** a um motor compartilhado **advanced** existe no motor (nome/alias). Discriminador de escopo **por valor**: resolução transitiva (profundidade 1) do alvo do `&` até `Join-Path … 'scripts\<Leaf>.ps1'` com **literal `'scripts'`** no AST (não o caminho resolvido) + leaf na `scripts/` do auditor. Advanced = CommonParameter **injetado** (`Get-Command.Parameters` − `param()` do AST). Sinais (→ `INVENTORY_CUSTOMIZED`): `forwards_unknown_engine_param`, `shared_engine_unresolved`; diagnóstico brando `engine_unresolved_or_unparseable` (→ `INVENTORY_ENGINE_DIAGNOSTIC`, fora do regex de pendência do agregador). Consumido por `Test-XpzWrapperInventory.ps1`; complementa `Test-XpzParameterNamingContract.ps1` (surface próprio do motor) auditando o **consumo** wrapper→motor. Dono: xpz-kb-parallel-setup/SKILL.md (8.a.ii/8.h). Validação: Test-XpzWrapperEngineParamSupportSelfTest.ps1 (unitário), Test-XpzWrapperEngineParamMoldesSelfTest.ps1 (segurança: zero sinais + cobertura sobre os moldes). Tokens: `XPZ_WRAPPER_ENGINE_PARAM_SELFTEST_OK`, `XPZ_WRAPPER_ENGINE_PARAM_MOLDES_OK`.
- `scripts/GeneXusObjectTypeCatalogSupport.ps1` (support-library) — mescla `gx-object-type-catalog.json` + override local (`gx-object-type-catalog.override.json`), agrega tipos desconhecidos e formata triagem. Dono: 01a-catalogo-e-padroes-empiricos.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Register-GeneXusObjectTypeCatalogOverride.ps1` (motor) — grava override paliativo com `-UserApproved` e `upstreamPending=true`. Dono: 01a-catalogo-e-padroes-empiricos.md; também README.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Test-XpzCatalogOverrideSessionReminder.ps1` (motor) — lembrete de sessão quando o override local de catálogo exige alinhamento upstream (exit 2 em `reminderRequired`). Dono: cabeçalho do script; também xpz-kb-parallel-setup/SKILL.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1. Exit: 2.
- `scripts/New-GeneXusUnknownTypeMaintainerPrompt.ps1` (motor) — gera prompt copiável para o mantenedor registrar tipo no catálogo compartilhado. Dono: cabeçalho do script. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Test-GeneXusUnknownTypeDiscoverySelfTest.ps1` (motor) — self-test de descoberta de tipo desconhecido (agregação GUID, override, lembrete, inventário pós-merge). Dono: 01a-catalogo-e-padroes-empiricos.md. Validação: self-test. Tokens: `OK: Test-GeneXusUnknownTypeDiscoverySelfTest.ps1`.
- `scripts/Test-XpzObjetosDaKbNaming.ps1` (motor) — auditoria de naming em `ObjetosDaKbEmXml` usando o catálogo efetivo (base + override); reconhece elemento legado órfão por `@type` `gxlegacy/<Elemento>` via `gx-legacy-export-element-registry.json` (classifica por `materializedFolderName`, não `TIPO_DESCONHECIDO`). Dono: cabeçalho do script; também 08-guia-para-agente-gpt.md. Validação: Test-XpzObjetosDaKbNamingLegacySelfTest.ps1. Tokens: `OK: Test-XpzObjetosDaKbNamingLegacySelfTest.ps1`.
- `scripts/Test-XpzObjetosDaKbNamingLegacySelfTest.ps1` (motor) — prova que o audit de naming classifica elemento legado órfão por `typeToken` (`gxlegacy/Report` → `materializedFolderName` `Report`, `NAMING_OK`) em vez de `TIPO_DESCONHECIDO`. Dono: cabeçalho do script. Validação: self-test. Tokens: `OK: Test-XpzObjetosDaKbNamingLegacySelfTest.ps1`.
- `scripts/GeneXusPackageInventorySupport.ps1` (support-library) — motor de resumo `packageInventory` compartilhado (import e export). Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusPackageInventorySupportSelfTest.ps1, Test-XpzBuilderPackageInventorySelfTest.ps1. Tokens: `XPZ_BUILDER_PACKAGE_INVENTORY_SELFTEST_OK`, `GENEXUS_PACKAGE_INVENTORY_SUPPORT_SELFTEST_OK`.
- `Inferência forte`: esse inventario complementa a validação de envelope; ele não transforma a pasta `scripts/` em fonte normativa, mas registra motor compartilhado relevante para rastreabilidade operacional.
- `scripts/Test-GeneXusImportFileEnvelope.ps1` (motor) — validação estática de `import_file.xml`; p/ Panel aceita `-PanelReferencePath` e registra panel-level-layout-{confirmed|unverified|suspicious}. Dono: xpz-builder/SKILL.md; também responsibilities-by-type/panel.md. Validação: via fluxo do envelope.
- `scripts/Get-GeneXusObjectSummary.ps1`, `scripts/Compare-GeneXusPanelShape.ps1` (motor) — diagnóstico compacto de Panel SD e WebPanel clássico (tables Flex/Responsive, buttons `<action>`/`<ucw>`, eventos, `coverage`/`unknownUcwControlTypes`) sem despejar CDATA; `gxControlType` via catálogo. Dono: 08-guia-para-agente-gpt.md e 02-regras-operacionais-e-runtime.md; também responsibilities-by-type/panel.md e webpanel.md, 04b-ucw-gxcontroltype-reference.md. Validação: Test-GeneXusWebPanelShapeContract.ps1.
- `scripts/gx-ucw-gxcontroltype-catalog.json` (catálogo) — `gxControlType` de User Controls em `GxMultiForm`. Dono: 04b-ucw-gxcontroltype-reference.md. Validação: via Test-GeneXusWebPanelShapeContract.ps1.
- `scripts/Add-GeneXusButton.ps1` (motor) — insere botão em WebPanel cirurgicamente (`<cell>` `<action>`/`<ucw>` em tabela Flex, `-BeforeControlName`/`-AfterControlName`), reusa GeneXusXmlSurgicalEditSupport.ps1 (não re-serializa CDATA); aborta fail-closed `RESPONSIVE_UNSAFE` em Responsive. Dono: 08-guia-para-agente-gpt.md; também responsibilities-by-type/webpanel.md. Validação: Test-GeneXusAddButtonContract.ps1.
- `scripts/Test-GeneXusTransactionCoherence.ps1` (motor) — gate 9-TWS de coerência de Transaction; finding `wwp-screen-code-on-non-generated-transaction` (fail): Transaction `GenerateObject=False` com código de tela WorkWithPlus órfão. Dono: xpz-builder/SKILL.md, wwp-packaging.md, responsibilities-by-type/transaction.md. Validação: Test-GeneXusTransactionCoherenceSelfTest.ps1. Tokens: `OK: Test-GeneXusTransactionCoherenceSelfTest.ps1`.
- `scripts/Search-GeneXusXmlSourceBlock.ps1` (motor) — busca textual em `<Source>` separando events/layout/code/serialized (evita falso code-behind de `GxMultiForm`); compacto ou `-AsJson`. Dono: 02-regras-operacionais-e-runtime.md e 08-guia-para-agente-gpt.md. Validação: Test-SearchGeneXusXmlSourceBlockSelfTest.ps1. Tokens: `SEARCH_GENEXUS_XML_SOURCE_BLOCK_SELFTEST_OK`.
- `scripts/Resolve-GeneXusKbIdentity.ps1` (motor) — resolve (read-only) identidade estável da KB nativa local (`model.ini`, `knowledgebase.connection`, banco interno). Dono: 02-regras-operacionais-e-runtime.md; também 08-guia-para-agente-gpt.md, README.md, xpz-kb-parallel-setup/SKILL.md. Validação: nenhum self-test próprio.
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1` (motor) — escrita localizada de identidade estável em `kb-source-metadata.md` (preenche ausentes, bloqueia divergência não vazia salvo aprovação; preserva EOL via XpzTextFileEolSupport.ps1). Dono: 02-regras-operacionais-e-runtime.md; também 08, xpz-kb-parallel-setup/SKILL.md, README.md. Validação: nenhum self-test próprio.
- `scripts/Test-XpzWrapperInventory.ps1` (motor) — auditoria de wrappers locais: scripts legados (`INVENTORY_LEGACY_ORPHANS`), finos recomendados ausentes (`INVENTORY_RECOMMENDED_MISSING`) e wrapper customizado (`INVENTORY_CUSTOMIZED`, inclui K8/K9 sem repasse de `-AsJson` via `missing_AsJson_passthrough`, `Update-*KbFromXpz` que consome o stdout textual defasado via `consumes_legacy_text_stdout`, e repasse a motor compartilhado advanced de parâmetro não-declarado via `forwards_unknown_engine_param`/`shared_engine_unresolved` por AST + `Get-Command`, helper `XpzWrapperEngineParamSupport.ps1`); motor canônico ausente/parse-broken sai no canal brando `INVENTORY_ENGINE_DIAGNOSTIC` (não bloqueia). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzWrapperInventorySelfTest.ps1. Tokens: `INVENTORY_LEGACY_ORPHANS`, `INVENTORY_RECOMMENDED_MISSING`, `INVENTORY_CUSTOMIZED`, `INVENTORY_ENGINE_DIAGNOSTIC`.
- `scripts/Test-XpzKbDeploymentMetadata.ps1` (motor) — valida plausibilidade de environment/deploy/output em `kb-source-metadata.md`; dimensão `metadata/deploy` de Test-XpzSetupAudit. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via Test-XpzSetupAudit / self-tests de setup.
- `scripts/Test-XpzWrapperInventorySelfTest.ps1` (motor) — bateria do inventário de wrappers (`INVENTORY_CUSTOMIZED`/`INVENTORY_LEGACY_ORPHANS`/`INVENTORY_RECOMMENDED_MISSING`, incl. `missing_AsJson_passthrough` K8/K9, `consumes_legacy_text_stdout` Update-*KbFromXpz e o caso end-to-end de `forwards_unknown_engine_param`). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: self-test próprio. Tokens: `WRAPPER_INVENTORY_SELFTEST_OK`.
- `scripts/Build-GeneXusImportFileEnvelope.ps1` (motor) — monta `import_file.xml` com gate de colisão embutido + gate mecânico de `lastUpdate` (`-AcervoPath` obrigatório; `-ModifiedObjectNames`/`-ModifiedObjectGuids`); Panel via `-TemplatePackagePath`→`-PanelReferencePath`. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1. Tokens: `BUILD_GENEXUS_IMPORT_FILE_ENVELOPE_SELFTEST_OK`.
- `scripts/New-XpzImportPackage.ps1` (motor; delega ao Python `scripts/New-XpzImportPackage.py`) — empacotamento por frente: lê metadata, classifica raízes Object/Attribute, gate de colisão + gate 9-FD fail-closed; JSON no stdout, `acervoResolvedBy`. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-NewXpzImportPackage.py, Test-NewXpzImportPackageDriftSelfTest.ps1. Exit: 20.
- `scripts/Test-XpzPackageCollision.ps1` (motor) — gate de colisão de rodada de pacote (consumido pelo envelope e wrappers Test-*KbPackageCollision), `-PackagePath`/`-FrontPrefix`; JSON no stdout. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-XpzPackageCollisionSelfTest.ps1. Tokens: `OK: Test-XpzPackageCollisionSelfTest.ps1`. Exit: 0/20.
- `scripts/Test-GeneXusSourceSanity.ps1` (motor) — gate de sanidade mínima de `Source` (`xmlWellFormed`/`sourceSanityStatus`/`probablyImportable`); finding type-aware `procedural-in-conditions` (fail: Procedure com `Conditions` não-vazia → `src0055`). Dono: xpz-builder/SKILL.md; também 08-guia-para-agente-gpt.md, 02. Validação: Test-GeneXusSourceSanitySelfTest.ps1. Tokens: `OK: Test-GeneXusSourceSanitySelfTest.ps1`.
- `scripts/Test-GeneXusFrontAcervoDrift.ps1` (motor) — gate 9-FD drift frente-vs-acervo por `lastUpdate` (`front-older-than-acervo`=fail bloqueia, equals/unparseable=warn, newer/new-object=info); opera sobre frente existente. Dono: xpz-builder/SKILL.md. Validação: via fluxo do empacotamento.
- `scripts/Copy-GeneXusAcervoToFront.ps1` (motor) — resolve drift / seed da frente: copia acervo→frente com bump de `lastUpdate`, `-ObjectList`/`-ObjectNames`/`-ObjectGuids`, `-DryRun`; JSON no stdout. Dono: xpz-builder/SKILL.md; também 02-regras-operacionais-e-runtime.md. Validação: Test-CopyGeneXusAcervoToFrontSelfTest.ps1.
- `Evidência direta`: a frente de geração e empacotamento local passou a registrar a fidelidade textual do delta como verificacao previa ao pacote: copias alteradas em `ObjetosGeradosParaImportacaoNaKbNoGenexus` devem preservar comentarios, `CDATA`, indentacao, linhas em branco, ordem de nos, quebras de linha e whitespace herdado fora do delta aprovado; ruido de reserializacao ou whitespace fora do delta deve bloquear a entrega ate correcao cirurgica ou aprovacao explicita.
- `scripts/Get-GeneXusXpzLastUpdate.ps1` (motor) — timestamp canônico `max(UtcNow+60s, baseline+60s)` com `-BaselineXmlPath`. Dono: xpz-builder/SKILL.md. Validação: via consumidores (Edit-/Set-lastUpdate self-tests).
- `scripts/Edit-GeneXusXmlSurgical.ps1` (motor; usa support-library `scripts/GeneXusXmlSurgicalEditSupport.ps1`) — edição cirúrgica raw de XML (`Replace`/`InsertAfter`, âncora literal, bump `lastUpdate`, backup, restaura em `XML_NOT_WELLFORMED_AFTER`). Dono: xpz-builder/SKILL.md (+ examples/Edit-GeneXusXmlSurgical.example.ps1). Validação: Test-EditGeneXusXmlSurgicalContract.ps1. Tokens: `EDIT_GENEXUS_XML_SURGICAL_CONTRACT_OK`.
- `scripts/Set-GeneXusXmlLastUpdate.ps1` (motor) — re-carimbo in-place do `lastUpdate` (reusa Get-GeneXusXpzLastUpdate + GeneXusXmlSurgicalEditSupport), `-BaselineXmlPath` opcional, `-DryRun`/`-AsJson`. Dono: 08-guia-para-agente-gpt.md; também 02, xpz-builder/SKILL.md, quality-checklist.md. Validação: Test-SetGeneXusXmlLastUpdateSelfTest.ps1.
- `scripts/Test-GeneXusObjectVariableDelta.ps1` (motor) — diagnóstico de variáveis; modo delta por `-VariableName` (fail) e consultivo (varre legado), `-AllowShapeOnlyType`. Dono: xpz-builder/SKILL.md + quality-checklist.md; também 02, 08. Validação: nenhum self-test próprio.
- `scripts/Find-CsAttributeAssignments.ps1` (motor; usa support-library `scripts/GeneXusCsAttributeAssignmentSupport.ps1`) — mapeia atribuições de atributo Transaction no `.cs` web gerado (`AssignAttri`, triplet do Specifier). Dono: responsibilities-by-type/transaction.md; também xpz-msbuild-build/SKILL.md. Validação: Test-FindCsAttributeAssignmentsContract.ps1. Tokens: `FIND_CS_ATTRIBUTE_ASSIGNMENTS_CONTRACT_OK`.
- `Evidência direta`: a base passou a registrar catalogo consultavel de clausulas `on <evento>` e restrições de `Events` em `Transaction` (rejeicoes `src0056`/`spc0150` na trilha XPZ), anti-padroes nomeados em `02-regras-operacionais-e-runtime.md`, rotulos de evidencia para geração XPZ e encaminhamento em `xpz-msbuild-import-export/SKILL.md`, `xpz-msbuild-build/SKILL.md` e `08-guia-para-agente-gpt.md`; fonte canonica do catalogo: `xpz-builder/responsibilities-by-type/transaction.md`; uso correto de linguagem GeneXus permanece em skill **nexa** e documentação de produto.
- `scripts/New-GeneXusXpzFront.ps1` (motor) — abre/reutiliza frente `NomeCurto_GUID_YYYYMMDD` em ObjetosGeradosParaImportacaoNaKbNoGenexus (chamada atômica, devolve GUIDs extras). Dono: xpz-builder/SKILL.md. Validação: nenhum self-test próprio.
- `Evidência direta`: `13-revisao-pre-push.md` concentra a rotina pre-push autoritativa (mecanico, semantica, avaliacao de `CHANGELOG.md` para mudancas com impacto publico, paridade motor↔doc, veredicto); `AGENTS.md` apenas aponta para esse arquivo.
- `Evidência direta`: `14-revisao-pre-push-reforcada.md` e a **aplicacao pre-push** da metodologia de revisao por pares (regua de convergencia e papeis normativos em `15-revisao-por-pares.md`): orquestracao de painel multi-modelo diverso por cima da rotina do `13`, com a "versao" sendo um commit e o "pronto" push-ready; o mecanismo de delegacao a LLM secundario fica em `xpz-llm-delegate/SKILL.md`.
- `Evidência direta`: `15-revisao-por-pares.md` define a **metodologia generica de revisao por pares** e e a fonte normativa da regua de convergencia (manuscrito -> painel independente de modelos distintos que leem as fontes -> revise-and-resubmit -> convergencia do painel inteiro sobre a versao final); valida plano/design, nao so pre-push. O `14` e a aplicacao pre-push; o mecanismo de delegacao fica em `xpz-llm-delegate/SKILL.md`.
- `scripts/Invoke-PrePushMechanicalChecks.ps1` (motor) — orquestrador mecânico da pré-push: contexto git no intervalo `BaseRef..HEAD` (default `origin/main..HEAD`), `git diff --check`, classificação dos arquivos alterados, delega parse a Test-PsScriptsParse.ps1/Test-PyScriptsParse.ps1, emite aviso de possível defasagem do 09 (presença do termo não basta — comparar abrangência) e consolida `pushReadiness`/`PUSH_READINESS`; não substitui a fase semântica. Dono: 13-revisao-pre-push.md. Validação: via gates consultivos que orquestra.
- `scripts/Test-PyScriptsParse.ps1` (motor) — parse AST de `scripts/*.py` via `ast.parse`, sem `py_compile` nem `__pycache__/*.pyc`. Dono: 13-revisao-pre-push.md. Validação: nenhum self-test próprio. Tokens: `FILES=N; ERRORS=M`.
- `scripts/Test-PrePushTraceabilityCoverage.ps1` (motor) — gate consultivo de rastreabilidade editorial: AGENTS/13 não espelhados no 08, script compartilhado sem menção nominal no 09, token rastreável ausente no 09, entrada de script verbosa no 09 (`PUBLIC_TRACEABILITY_VERBOSE_LINE`, trava do índice de ponteiros), paridade assimétrica Build/Query de catálogo (`ParallelKbRoot`/override), cobertura agregada demais motor↔bateria e referência a versão antiga do extrator. Dono: 13-revisao-pre-push.md. Validação: Test-PrePushTraceabilityCoverageSelfTest.ps1. Tokens: `OK: Test-PrePushTraceabilityCoverageSelfTest.ps1`.
- `scripts/Test-GeneXusUnexpectedCharacter.ps1` (motor) — gate consultivo: caracteres Unicode inesperados em linhas adicionadas de `.md`/`.ps1` fora de `historico/` (preserva número da linha nova, ignora blocos fenced); revisão humana, não substitui a fase semântica. Dono: 13-revisao-pre-push.md. Validação: nenhum self-test próprio.
- `scripts/Test-PrePushNewTokenPropagation.ps1` (motor) — gate consultivo: detecta no diff termo de contrato introduzido por transição co-localizada e lista menções que ficaram só com o termo antigo (candidatas em `agentWarnings`); não dispara sem transição co-localizada no mesmo hunk. Dono: 13-revisao-pre-push.md. Validação: Test-PrePushNewTokenPropagationSelfTest.ps1. Tokens: `OK: Test-PrePushNewTokenPropagationSelfTest.ps1`.
- `scripts/Test-PrePushSharedScriptSkillCoverage.ps1` (motor) — gate consultivo: quando o diff altera script compartilhado, lista `SKILL.md`/`quality-checklist.md` que o citam e não estão no diff (skill transversal) como candidatas em `agentWarnings`; severity `warn`, não falha o mecânico. Dono: 13-revisao-pre-push.md. Validação: Test-PrePushSharedScriptSkillCoverageSelfTest.ps1. Tokens: `OK: Test-PrePushSharedScriptSkillCoverageSelfTest.ps1`.
- `scripts/Test-PrePushHistoryCommitPlaceholder.ps1` (motor) — gate consultivo: em `historico/*.md` no diff, sinaliza campo `Commit:`/`PR:` com placeholder genérico em vez do hash real; exceção legítima (hash a preencher) confirmada pelo agente; severity `warn`, escopo diff. Dono: 13-revisao-pre-push.md. Validação: Test-PrePushHistoryCommitPlaceholderSelfTest.ps1. Tokens: `OK: Test-PrePushHistoryCommitPlaceholderSelfTest.ps1`.
- `scripts/Test-PrePushGateEnumerationParity.ps1` (motor) — gate consultivo: deriva do orquestrador os gates realmente executados (exceto o par fixo de parse) e sinaliza linha da doc que enumere ≥2 gates como subconjunto próprio; invariante (não diff-scoped), severity `warn`. Dono: 13-revisao-pre-push.md. Validação: Test-PrePushGateEnumerationParitySelfTest.ps1. Tokens: `OK: Test-PrePushGateEnumerationParitySelfTest.ps1`.
- `scripts/Test-XpzSetupAudit.ps1` (motor) — auditoria consolidada da pasta paralela por dimensões (inclui `declarativo/timestamps` com `DRIFT_TIMESTAMPS_LITERAIS` para timestamps literais em AGENTS/README locais, e `metadata wrapper`/`metadata/deploy`); trata `INVENTORY_LEGACY_ORPHANS` como pendência metodológica que rebaixa o estado sugerido para `atualizacao_metodologica_pendente`. Dono: xpz-kb-parallel-setup/SKILL.md; também 02-regras-operacionais-e-runtime.md. Validação: Test-XpzSetupAuditContractSelfTest.ps1.
- `scripts/Get-XpzSetupContractSignature.ps1` (motor) — assinatura determinística da superfície de contrato declarada em `xpz-kb-parallel-setup/setup-contract.manifest.json`. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzSetupContractSignatureSelfTest.ps1. Tokens: `XPZ_SETUP_CONTRACT_SIGNATURE_SELFTEST_OK`.
- `scripts/Test-XpzSetupFreshness.ps1` (motor) — compara a assinatura de contrato com `setup_contract_signature_*` auditado em `kb-source-metadata.md` (não contra o último commit do repo); estados `GATE_ONLY`/`AUDIT_REQUIRED`. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzSetupContractSignatureSelfTest.ps1. Tokens: `XPZ_SETUP_CONTRACT_SIGNATURE_SELFTEST_OK`.
- `scripts/Set-XpzSetupAuditTimestamp.ps1` (motor) — grava só `last_setup_audit_run_at` e `setup_contract_signature_*` em `kb-source-metadata.md`, preservando demais campos e EOL via XpzTextFileEolSupport.ps1; molde `xpz-kb-parallel-setup/examples/Set-KbSetupAuditTimestamp.example.ps1`. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzSetupAuditTimestampEolSelfTest.ps1. Tokens: `XPZ_SETUP_AUDIT_TIMESTAMP_EOL_SELFTEST_OK`.
- `scripts/Utf8NoBomEncodingSupport.ps1` (support-library) — `Get-Utf8NoBomEncoding` para escrita UTF-8 sem BOM; scripts novos devem reutilizá-lo em vez de duplicar construtores `[System.Text.UTF8Encoding]::new($false)`/`New-Object System.Text.UTF8Encoding($false)` (exceto leitura/detecção de encoding, BOM deliberado ou validação estrita de bytes). Dono: 02-regras-operacionais-e-runtime.md (norma de reuso) + cabeçalho do script. Validação: nenhum self-test próprio.
- `scripts/XpzTextFileEolSupport.ps1` (support-library) — leitura/escrita de texto versionado preservando EOL dominante e newline final, sem reescrever com `Environment.NewLine` no Windows; consumido por motores que mutam `kb-source-metadata.md`. Dono: cabeçalho do script. Validação: via consumidores.
- `scripts/XpzKbSourceMetadataEditSupport.ps1` (support-library) — `Update-XpzKbSourceMetadataFromSync` (mutação cirúrgica de `kb-source-metadata.md` sob autoridade do xpz-sync, preserva `last_setup_audit_run_at`/`setup_contract_signature_*`/frontmatter fora do escopo); invocado por Sync-GeneXusXpzToXml.ps1 com `-KbMetadataPath`. Parâmetro `-IsLegacyExport` (export GeneXus 9): usa `KMW/MaxGxBuildSaved` como Build quando `KMW/Build` ausente e emite hint legado que substitui o warning genérico de `KMW`/`Source` ausente. Dono: xpz-sync/SKILL.md + cabeçalho do script. Validação: Test-XpzSyncKbMetadataSelfTest.ps1, Test-XpzKbSourceMetadataLegacySelfTest.ps1. Tokens: `XPZ_SYNC_KB_METADATA_SELFTEST_OK`.
- `scripts/GeneXusFileBaseNameNormalizationSupport.ps1` (support-library) — fonte única de `Normalize-FileBaseName` (substitui caractere inválido de nome de arquivo por `_`, remove ponto final; preserva ponto interno); dot-sourced por `Sync-GeneXusXpzToXml.ps1` e pelo conversor de export legado `GeneXusLegacyExportFileSupport.ps1`, garantindo detecção de colisão `FolderType|NormalizedName` idêntica entre os caminhos moderno e legado. Dono: cabeçalho do script. Validação: Test-GeneXusFileBaseNameNormalizationSelfTest.ps1. Tokens: `OK: Test-GeneXusFileBaseNameNormalizationSelfTest.ps1`.
- `scripts/Test-GeneXusFileBaseNameNormalizationSelfTest.ps1` (motor) — lock de comportamento da fonte única `Normalize-FileBaseName` (tabela de nomes problemáticos: caracteres inválidos→`_`, ponto final removido, ponto interno preservado). Dono: cabeçalho do script. Validação: self-test. Tokens: `OK: Test-GeneXusFileBaseNameNormalizationSelfTest.ps1`.
- `scripts/Measure-PtBrAccentDegradation.ps1` (motor) — medidor determinístico da degradação de acentuação pt-BR (ASCII onde caberia acento) nos arquivos versionados; piso firme (lista curada `scripts/ptbr-accent-wordlist.json`) vs ambíguas, suprime código fenced/inline e identificadores, grava mapa transitório em `work/ptbr-accent-map.{md,json}` (git-ignored). Dono: cabeçalho do script; também 999-ideias-pendentes.md (baseline). Validação: Test-MeasurePtBrAccentDegradationSelfTest.ps1. Tokens: `PTBR_ACCENT_MEASURE_SELFTEST_OK`.
- `scripts/Repair-PtBrAccentDegradation.ps1` (motor) — contraparte aplicadora: corrige só ocorrências inequívocas (reusa lista/regex/supressão/caixa do medidor via dot-source), preserva EOL LF e UTF-8 sem BOM; em `.md` respeita a fronteira pt-BR (não toca `## Español`/`## English`), em `.ps1`/`.example.ps1` corrige só comentários pelo tokenizer (nunca código nem strings). Dono: cabeçalho do script; também 999-ideias-pendentes.md. Validação: Test-RepairPtBrAccentDegradationSelfTest.ps1. Tokens: `PTBR_ACCENT_REPAIR_SELFTEST_OK`.
- `Evidência direta`: `xpz-kb-parallel-setup/SKILL.md` exige **plano consolidado de correcoes** após toda auditoria mínima (incluindo PRE-CONDICAO do gatilho global e `auditar_setup`), com oferta de execução na mesma sessao de tudo que a skill classificar como corrigivel na pasta; diagnostico isolado não basta quando houver item corrigivel.
- `scripts/GeneXusObjectTypeCatalogCore.py` (support-library) — carga e merge do catálogo efetivo (base + override) para build e query. Dono: scripts/README-kb-intelligence.md; também 01a-catalogo-e-padroes-empiricos.md. Validação: via consumidores.
- `scripts/Query-KbIntelligenceIndex.py` (motor) — consultas do índice; bloqueia as semânticas (`who-uses`/`what-uses`/`impact-basic`/`functional-trace-basic`) quando `queryableByKbIntelligence=false` no catálogo efetivo (`--parallel-kb-root`/`--catalog-override-path`; `blocked`, `reason=QUERY_NOT_SEMANTIC_FOR_TYPE`, exit `11`); também serve `transaction-attributes`/`transaction-writable-attributes` e `css-classes`/`css-class-usage`. Dono: scripts/README-kb-intelligence.md; também 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md. Validação: Test-KbIntelligenceQueryableGuardSelfTest.ps1 (base e override); amostra multi-KB Invoke-ParallelKbEnvelopeScan.ps1. Exit: 11.
- `scripts/GeneXusPythonPrerequisite.ps1` (motor) — resolve Python 3 utilizável no PATH (rejeita stub `WindowsApps`). Dono: scripts/README-kb-intelligence.md; também README.md, 08-guia-para-agente-gpt.md, xpz-sync/SKILL.md. Validação: via Build-KbIntelligenceIndex.ps1. Exit: 8.
- `scripts/Build-KbIntelligenceIndex.ps1` (motor) — wrapper `.ps1` do extrator `.py`; exit `8` + `PREREQUISITO AUSENTE` quando Python ausente, propaga saída do `.py`; consequência editorial: sync XPZ/XML não conclui sem índice — declarar fluxo incompleto, não sync OK; molde `Update-KbFromXpz.example.ps1`. Dono: scripts/README-kb-intelligence.md; também README.md, 08-guia-para-agente-gpt.md, xpz-sync/SKILL.md. Validação: via self-tests do extrator. Exit: 8.
- `scripts/Build-KbIntelligenceIndex.py` (motor) — extrator do índice SQLite (`schema_version=3`, `EXTRACTOR_SIGNATURE_VERSION` atual `7`): mescla `gx-object-type-catalog.json` + override (`--catalog-override-path`/`--parallel-kb-root`); é registry-aware para export legado (carrega `gx-legacy-export-element-registry.json`; reconhece `type="gxlegacy/*"` e pastas órfãs do registro como known-legacy, pulando-as sem `SystemExit`/`BLOCK` e auditando-as em `legacy_orphan_directories_skipped`); grava `extractor_signature_version`/`extractor_signature_hash` na `metadata` e materializa as relações de extração — `creates_webcomponent` (`webpanel_dot_create`), fórmula de `Attribute`→Procedure/WebPanel/DataProvider (`attribute_formula_procedure_direct_call`/`_dot_call`), `calls_external_object_method` (`source_external_object_method`), `transaction_attribute_writability` (via GeneXusTransactionWritabilityCore.py) e classes CSS (`css_class`, `uses_css_class`/`uses_css_class_dynamic`). Dono: scripts/README-kb-intelligence.md. Validação: Test-KbIntelligenceAttributeFormulaExtractionSelfTest.ps1, Test-KbIntelligenceExternalObjectMethodExtractionSelfTest.ps1, Test-KbIntelligenceCssClassExtractionSelfTest.ps1, Test-KbIntelligenceLegacyOrphanSkipSelfTest.ps1. Tokens: `OK: Test-KbIntelligenceCssClassExtractionSelfTest.ps1`.
- `scripts/Test-KbIntelligenceLegacyOrphanSkipSelfTest.ps1` (motor) — prova que o indexador é registry-aware: pasta órfã legada (`Report` com `type="gxlegacy/Report"`) não dispara `SystemExit`/`BLOCK`, fica fora do `snapshot_objects_by_directory` e é auditada em `legacy_orphan_directories_skipped`; tipo moderno segue indexado. Dono: scripts/README-kb-intelligence.md. Validação: self-test. Tokens: `OK: Test-KbIntelligenceLegacyOrphanSkipSelfTest.ps1`.
- `scripts/GeneXusKbIntelligenceExtractorContract.ps1` (motor) — compara `extractor_signature_version`/`extractor_signature_hash` da `metadata` com o motor do repositório ativo; bloqueia índice sem assinatura ou com extrator defasado mesmo com timestamps frescos (molde `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1`). Dono: scripts/README-kb-intelligence.md; também xpz-kb-parallel-setup/SKILL.md. Validação: Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.ps1. Tokens: `KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK`.
- `scripts/GeneXusTransactionWritabilityCore.py` (motor) — classificação canônica de gravabilidade por `Transaction`/`Level`/`Attribute` (`writability_rule_version=1`); o extrator materializa o resultado em `transaction_attribute_writability` e o Query o lê. Dono: scripts/README-kb-intelligence.md; também xpz-builder/SKILL.md. Validação: Test-GeneXusKbIntelligenceWritabilityParity.ps1.
- `scripts/GeneXusTransactionWritabilitySupport.ps1` (support-library) — invoca o núcleo Python de gravabilidade; consumido pelas fachadas PowerShell. Dono: xpz-builder/SKILL.md. Validação: via fachadas.
- `scripts/Test-GeneXusTransactionWritability.ps1` (motor) — fachada PowerShell da classificação de gravabilidade por Transaction/Level/Attribute (sem algoritmo duplicado). Dono: xpz-builder/SKILL.md. Validação: Test-GeneXusKbIntelligenceWritabilityParity.ps1.
- `scripts/Test-GeneXusNewWritableTargets.ps1` (motor) — fachada PowerShell para alvos graváveis em blocos `New` de Procedure. Dono: xpz-builder/SKILL.md. Validação: via fluxo do empacotamento.
- `scripts/Test-GeneXusKbIntelligenceWritabilityParity.ps1` (motor) — paridade índice↔gate de gravabilidade (classificação materializada no índice bate com a fachada). Dono: scripts/README-kb-intelligence.md; também xpz-builder/SKILL.md. Validação: via fluxo de paridade.
- `scripts/Read-MsBuildImportSignals.ps1` (motor) — leitor compacto de sinais de import MSBuild (itens crus/canônicos, `itemAliasMatches`, `gxImportLogReadStatus`); os wrappers preview/import gravam `msbuild.import.signals.json` ao lado dos logs e espelham em `compactSignals`, com falha degradando `diagnosticDegraded` sem reclassificar a task (evidência primária em `executionEvidence`). Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md. Validação: Test-MsBuildImportSignalsClassifier.ps1.
- `scripts/Test-MsBuildImportSignalsClassifier.ps1` (motor) — bateria do leitor compacto (ruído `CssProperties.json`, lock de `GxImport.log`, equivalência `Panel`/`SDPanel` em `itemAliasMatches`). Dono: xpz-msbuild-import-export/SKILL.md. Validação: self-test.
- `scripts/Invoke-OpenCode.ps1` (motor) — chamada síncrona ao opencode (adapter stdin-based: prompt por stdin via `-RedirectStandardInput`, fora do argv; `-Message`/`-MessagePath`; `-OpenCodeExe` override); no timeout, **diagnostica limite de uso do provider (HTTP 429)** lendo o log do opencode via `Get-OpenCodeUsageLimitError` (em `OpenCodeStreamSupport.ps1`) em vez de mascarar como "excedeu Xs"; **`-MaxAttempts <1-3>` (default 1) = retry-once opt-in** que re-despacha só veredito `truncated`/`no-completion` (timeout por-tentativa; guarda anti-429 por-tentativa; `empty` terminal; `-Raw` sem retry); acionamento sempre humano, juízo estrutural GeneXus nunca é delegado. Dono: xpz-llm-delegate/SKILL.md. Validação: via Test-OpenCodeStreamSupportSelfTest.ps1, Test-LlmDelegateStdinHandlingSelfTest.ps1, Test-OpenCodeUsageLimitDetectionSelfTest.ps1, Test-OpenCodeRetrySelfTest.ps1. Tokens: `OPENCODE_USAGE_LIMIT_DETECTION_SELFTEST_OK`, `OK: Test-OpenCodeRetrySelfTest.ps1`.
- `scripts/Start-OpenCodeJob.ps1` (motor) — disparo assíncrono não-bloqueante do opencode (stdin-based, sem runner, prompt em `<GUID>.stdin.txt`; espelha Start-CodexJob). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/Watch-OpenCodeJob.ps1` (motor) — monitor incremental do job opencode. Dono: xpz-llm-delegate/SKILL.md. Validação: via Test-OpenCodeStreamSupportSelfTest.ps1.
- `scripts/Resolve-OpenCodeModelLocality.ps1` (motor) — classifica `local`/`external`/`unknown` pelo `baseURL` do provider na config do opencode (cloud conhecidos `ollama-cloud/*`/`opencode-go/*` = externos). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-OpenCodeModelLocalitySelfTest.ps1. Tokens: `OK: Test-OpenCodeModelLocalitySelfTest.ps1`.
- `scripts/Resolve-LlmDelegateAuthorization.ps1` (motor) — gate de confidencialidade `allow`/`ask`/`deny` combinando `payloadSensitivity` (`kb-sensitive`/`public`), localidade e política por-KB; `-Backend opencode|codex|claude-code|copilot|gemini` (default opencode) seleciona o resolvedor e casa a política pela **chave de destino** (`canonicalModel`), nunca pelo adapter; `-ParallelKbRoot` descobre a política via Resolve-LlmDelegationPolicyPath.ps1. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-LlmDelegateAuthorizationSelfTest.ps1. Tokens: `OK: Test-LlmDelegateAuthorizationSelfTest.ps1`.
- `scripts/OpenCodeStreamSupport.ps1` (support-library) — parsing do stream do opencode (`ConvertFrom-OpenCodeStreamLines`, `Get-OpenCodeFinalText`/`Get-OpenCodeAllText`, `Get-OpenCodeCompletionSignal`/`Get-OpenCodeCompletionVerdict` para detecção de truncamento por `reason`; resposta final = concatenação da última mensagem, erro do stream como BLOCK/`status:error`) e **diagnóstico de limite de uso do provider** (`Get-OpenCodeUsageLimitError`: lê o log do opencode e detecta HTTP 429 quando o adapter estoura por timeout; `-LogDir` para fixture); consumido por Invoke-OpenCode/Watch-OpenCodeJob. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-OpenCodeStreamSupportSelfTest.ps1, Test-OpenCodeUsageLimitDetectionSelfTest.ps1. Tokens: `OK: Test-OpenCodeStreamSupportSelfTest.ps1`, `OPENCODE_USAGE_LIMIT_DETECTION_SELFTEST_OK`.
- `scripts/Invoke-Codex.ps1` (motor) — backend Codex síncrono (`codex exec`, sandbox `read-only`, prompt via stdin — `-Message` inline ou `-MessagePath` de arquivo, exclusivos; resposta pelo `output-last-message`; default da ferramenta quando `-Model` omitido). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/Start-CodexJob.ps1` (motor) — disparo assíncrono não-bloqueante do Codex (`-Message`/`-MessagePath` exclusivos; texto do prompt persiste em `request.json`/`stdin.txt`). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/Watch-CodexJob.ps1` (motor) — monitor incremental do stream `codex exec --json`. Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/CodexCliSupport.ps1` (support-library) — descoberta fail-closed do `codex.exe` da app desktop (`%LOCALAPPDATA%\OpenAI\Codex\bin`, maior versão, ignora shim npm) + extração de erro `ERROR: {json}`. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-CodexCliSupportSelfTest.ps1. Tokens: `OK: Test-CodexCliSupportSelfTest.ps1`.
- `scripts/Resolve-CodexModelLocality.ps1` (motor) — classifica localidade pela `config.toml` do Codex (ou flags `--oss`/`--local-provider`) e emite `canonicalModel` (chave de destino, ex. `openai/gpt-5.5`). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-CodexModelLocalitySelfTest.ps1. Tokens: `OK: Test-CodexModelLocalitySelfTest.ps1`.
- `scripts/Invoke-ClaudeCode.ps1` (motor) — backend Claude Code síncrono (`claude -p`, `--output-format text`, `--permission-mode plan`, ferramentas só leitura `Read,Glob,Grep`, `--max-turns 1`, `bypassPermissions` recusado; `-Message`/`-MessagePath` exclusivos). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/Start-ClaudeCodeJob.ps1` (motor) — disparo assíncrono (`--output-format stream-json`, janela oculta + watcher; `-Message`/`-MessagePath` exclusivos; texto do prompt persiste em `request.json`/`stdin.txt`). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/Watch-ClaudeCodeJob.ps1` (motor) — monitor incremental do stream, grava `result.json`. Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/ClaudeCodeCliSupport.ps1` (support-library) — resolve `claude.exe` do PATH (versão mínima `2.1.118`), valida contrato de flags e classifica o status do job. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-ClaudeCodeCliSupportSelfTest.ps1. Tokens: `OK: Test-ClaudeCodeCliSupportSelfTest.ps1`.
- `scripts/Resolve-ClaudeCodeModelLocality.ps1` (motor) — destino Anthropic sempre `external`; chave `anthropic/<modelo>` (default `claude-opus-4-8`, alias `opus` normalizado). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-ClaudeCodeModelLocalitySelfTest.ps1. Tokens: `OK: Test-ClaudeCodeModelLocalitySelfTest.ps1`.
- `scripts/Invoke-Copilot.ps1` (motor) — backend GitHub Copilot CLI síncrono (`copilot -p` JSONL, `--no-custom-instructions`, `--disable-builtin-mcps`, ferramentas vazias; resposta do evento `assistant.message`; `-Message`/`-MessagePath` exclusivos + guard de tamanho fail-closed `$MaxArgvPromptChars`=30000: argument-based, prompt no argv → `-MessagePath` **não** levanta o teto ~32KB). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/CopilotCliSupport.ps1` (support-library) — resolve `copilot` do PATH (versão mínima `1.0.12`), valida flags e lê o stream JSONL (`Get-CopilotJsonlFinalText`/`Get-CopilotJsonlExitCode`). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-CopilotCliSupportSelfTest.ps1. Tokens: `OK: Test-CopilotCliSupportSelfTest.ps1`.
- `scripts/Resolve-CopilotModelLocality.ps1` (motor) — sempre `external`; chave `github-copilot/<modelo>` (default `gpt-5-mini`), conscientemente não `openai/*`. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-CopilotModelLocalitySelfTest.ps1. Tokens: `OK: Test-CopilotModelLocalitySelfTest.ps1`.
- `scripts/Invoke-Gemini.ps1` (motor) — backend Gemini CLI síncrono (`gemini -p`, `--approval-mode plan`, `--output-format json`, resposta em `.response`; adapter argument-based fecha o stdin; `-Message`/`-MessagePath` exclusivos + guard de tamanho fail-closed `$MaxArgvPromptChars`=30000: prompt no argv → `-MessagePath` **não** levanta o teto ~32KB). Dono: xpz-llm-delegate/SKILL.md. Validação: via self-tests do backend.
- `scripts/GeminiCliSupport.ps1` (support-library) — resolve `gemini` do PATH (versão mínima `0.35.3`), valida contrato de flags. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-GeminiCliSupportSelfTest.ps1. Tokens: `OK: Test-GeminiCliSupportSelfTest.ps1`.
- `scripts/Resolve-GeminiModelLocality.ps1` (motor) — sempre `external`; chave `google/<modelo>` (default `gemini-3-flash-preview`). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-GeminiModelLocalitySelfTest.ps1. Tokens: `OK: Test-GeminiModelLocalitySelfTest.ps1`.
- `scripts/Resolve-LlmDelegationPolicyPath.ps1` (motor) — resolve o caminho efetivo da política de delegação (canônico `llm-delegation-policy.json` com fallback ao legado `opencode-delegation-policy.json`); `-ParallelKbRoot`, `status` `new|legacy|both|none`, `deprecatedNameInUse`; só resolve caminho, não lê/grava. Dono: xpz-llm-delegate/SKILL.md. Validação: Test-LlmDelegationPolicyPathSelfTest.ps1. Tokens: `OK: Test-LlmDelegationPolicyPathSelfTest.ps1`.
- `scripts/Test-LlmDelegateStdinHandlingSelfTest.ps1` (motor) — prova o anti-hang de stdin headless nos dois regimes: os stdin-based (Invoke-OpenCode/Start-OpenCodeJob/Codex/ClaudeCode) entregam o prompt por stdin via `-RedirectStandardInput` (fora do argv, sem o limite ~32KB) e os argument-based (Gemini/Copilot) fecham o stdin do CLI com `$null | & ... @args`; inclui prova comportamental do opencode com prompt > 32KB via fake-exe injetado (`-OpenCodeExe`), guard estático de `-MessagePath` (set `FromFile`, `Get-Content -LiteralPath … -Encoding utf8`, `Test-Path -LiteralPath … -PathType Leaf`) nos 6 adapters Codex/Start-Codex/ClaudeCode/Start-ClaudeCode/Gemini/Copilot + guard de tamanho dos argument-based (Gemini/Copilot seguem no argv → teto ~32KB **persiste**), e prova comportamental dedicada de `-MessagePath` no `Invoke-Codex` (fake-exe via `-CodexExe` escreve no `-o output-last-message`, texto bruto). Dono: xpz-llm-delegate/SKILL.md. Validação: self-test. Tokens: `OK: Test-LlmDelegateStdinHandlingSelfTest.ps1`.
- `scripts/Build-LlmDelegateCapabilityManifest.ps1` (motor) — sonda backends instalados e enumera modelos (opencode/Codex via config; Claude/Copilot/Gemini sem enumeracao nativa), reusa os `Resolve-*ModelLocality`, grava manifesto de capacidade sanitizado (so `canonicalModel`/`backend`/`locality`/`reasonCode`/`sourceKind`) + snapshot por-KB opcional; dica de oferta da revisao por pares, nunca verdade do gate. Dono: xpz-llm-delegate/SKILL.md; tambem 15-revisao-por-pares.md, xpz-kb-parallel-setup/SKILL.md. Validação: Test-LlmDelegateCapabilityManifestSelfTest.ps1. Tokens: `OK: Test-LlmDelegateCapabilityManifestSelfTest.ps1`.
- `scripts/Set-LlmDelegatePreferredReviewers.ps1` (motor) — persiste a curadoria de revisores preferidos (machine-level `preferred-reviewers.json`; schema 2 eixos `targetModelKey`+`invokeArgs` sanitizado; descarta veto duro Mistral/Nemotron). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-LlmDelegatePreferredReviewersSelfTest.ps1. Tokens: `OK: Test-LlmDelegatePreferredReviewersSelfTest.ps1`.
- `scripts/Resolve-LlmDelegatePreferredReviewers.ps1` (motor) — cruza a curadoria com `capabilities.json` (`availableInManifest`) e devolve a composição sugerida do painel; preferência ≠ autorização (não consome o gate). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-LlmDelegatePreferredReviewersSelfTest.ps1.
- `scripts/Resolve-LlmDelegatePanelDiversity.ps1` (motor) — avalia consultivamente o piso de diversidade do painel (≥2 famílias distintas = provider de destino) a partir de candidatos+vereditos do gate (candidatos incluem subagentes nativos = família do orquestrador); devolve `panelReady`/`needsBatchAuthorization`/`insufficientDiversity`; não decide autorização (gate soberano). Dono: xpz-llm-delegate/SKILL.md. Validação: Test-LlmDelegatePanelDiversitySelfTest.ps1. Tokens: `OK: Test-LlmDelegatePanelDiversitySelfTest.ps1`.
- `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` (motor) — verifica o fechamento da revisão por pares e bloqueia o recibo final quando, sem `preferred-reviewers.json`, a oferta de salvar curadoria não foi feita, quando há lista preferida mas falta estado auditável por revisor preferido, ou quando a versão consolidada (vN+1) está `pendingResubmission` ou em declínio não auditado (eixo `-VNextState` + `-ResubmissionDeclinedBy`/`-ResubmissionDeclineReason`/`-RoundId`); é stateless e não grava preferência, não decide autorização e não recalcula diversidade. Dono: xpz-llm-delegate/SKILL.md; também 15-revisao-por-pares.md. Validação: Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1. Tokens: `OK: Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1`.
- `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (motor) — harness MECÂNICO de despacho+coleta do painel de revisão por pares (o «harness de disparo» previsto em `15-revisao-por-pares.md` (`## Futuros`)): por revisor roda o gate `Resolve-LlmDelegateAuthorization.ps1` (sem autorizar), despacha os `allow` aos adapters `Invoke-*.ps1` em paralelo (`ForEach-Object -Parallel -ThrottleLimit 8` + `SemaphoreSlim($OllamaConcurrency)` via `$using:` só para `ollama-cloud/*`), classifica o resultado de forma ESTRUTURAL (texto→`responded`; cota→`unavailable`; timeout→`timeout`; resto→`error`) e emite `panel-summary.json` (1 linha de stdout, `Kind=xpz-llm-panel-dispatch-result`/`SchemaVersion=1` PascalCase, UTF-8 sem BOM; texto humano por `[Console]::Error`) + `manifest.json` + ledger por estado (`.verdict`/`.error`/`.state`). Modelo efetivo + fail-closeds (opencode/codex/claude-code/copilot/gemini); contenção (`permissionMode`/`tools`/`maxTurns`/`agent`/`approvalMode!=plan`) RECUSADA em `securityBlockedArgs` e não repassada (Posição B); opencode em `kb-sensitive`→`unavailable`; `-Cd` precedência+fail-closed (opencode nunca recebe `-Cd`); single-flight DIFERIDO (falha concorrente→`error`+`concurrencySaturationWarning`). NÃO injeta nativo, NÃO calcula piso/closeout/triagem/convergência (do orquestrador). Params TEST-ONLY: `-OpenCodeConfigPath`/`-CodexConfigPath`/`-BackendExeMap`. Dono: xpz-llm-delegate/SKILL.md; também 15-revisao-por-pares.md. Validação: Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1. Tokens: `OK: Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`.

- `scripts/Initialize-XpzSkillsRepoGit.ps1` (motor) — liga pasta baixada como ZIP ao remoto oficial (`git init`+`remote`+`fetch`+`reset --mixed origin/main`), instala Git por `winget` quando ausente; gate anti-destrutivo `GIT_LINKED_WITH_DRIFT` (só alinha working tree via `-AlignToOfficial`). Dono: xpz-skills-setup/SKILL.md. Validação: Test-XpzSkillsRepoGitSelfTest.ps1.
- `scripts/Test-XpzSkillsRegistration.ps1` (motor) — auditoria read-only do registro de cada skill × ferramenta (`OK`/`coberta_por_compatibilidade`/`ausente`/`orfa`/`quebrada`), freshness do MCP do Cursor (`MCP_OK`/`MCP_SERVER_STALE`/`MCP_CONFIG_INVALID`/`MCP_NOT_INSTALLED`), `overall` `REGISTRATION_OK`/`REGISTRATION_GAPS`; classifica também a `nexa` em `externalSkills` (`EXTERNAL_SKILLS_OK`/`EXTERNAL_SKILLS_GAPS`). Dono: xpz-skills-setup/SKILL.md. Validação: Test-XpzSkillsRegistrationSelfTest.ps1.
- `scripts/Test-XpzGlobalInstructions.ps1` (motor) — auditoria dos instrucionais globais por ferramenta (segue `@<caminho>`, `instructions[]` do OpenCode, `agentsPath` do MCP do Cursor) contra o contrato `xpz-global-instructions-topics.psd1`; `overall` `GLOBAL_INSTRUCTIONS_OK`/`GLOBAL_INSTRUCTIONS_REVIEW`. Dono: xpz-skills-setup/SKILL.md. Validação: Test-XpzGlobalInstructionsSelfTest.ps1.
- `scripts/Install-CursorGlobalInstructionsMcp.ps1` (motor) — instala o MCP global do Cursor (`cursor-global-instructions-mcp/server.py` serve o `AGENTS.md` efetivo, merge em `mcp.json` preservando outros servidores). Dono: xpz-skills-setup/SKILL.md. Validação: via Test-XpzSkillsRegistrationSelfTest.ps1.
- `scripts/Initialize-NexaRepoGit.ps1` (motor) — bootstrap do repo que hospeda a `nexa` (`genexuslabs/genexus-skills`): detecta clone existente, clona quando ausente, origin oficial tolerando remotos extras; gate `NEXA_DIR_NOT_REPO` (labels `NEXA_ALREADY_LINKED`/`NEXA_ORIGIN_ADDED`/`NEXA_REPO_CLONED`/`NEXA_REMOTE_MISMATCH`). Os motores não criam/removem vínculos nem gravam instrucionais — resolução manual sob confirmação. Dono: xpz-skills-setup/SKILL.md. Validação: Test-NexaRepoGitSelfTest.ps1.

- `scripts/Invoke-XpzKbParallelPrePushPhase1.ps1` (motor) — orquestrador da pré-push de **pasta paralela de KB** (distinta da pré-push do repositório de skills do `13`): gates G0–G5 + K1–K4/K8/K9/K11, JSON de máquina por padrão, consolida `pushReadiness` (`ready`/`warn`/`blocked`, exit 0/2/1; `unknown`⇒`blocked` fail-closed); descoberta de wrapper K8/K9 (`kb-parallel-pre-push.config.json` → convenção → fail-closed: `config|convention|none|ambiguous`); K8 consome Test-XpzSetupAudit.ps1 -AsJson; `estado_operacional_sugerido`. Pasta da skill: SKILL.md enxuto + satélites fase1/2a/2b + `agents/openai.yaml` + `examples/`. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzKbParallelPrePushPhase1SelfTest.ps1, Test-XpzSetupAuditContractSelfTest.ps1. Tokens: `XPZ_KB_PREPUSH_PHASE1_SELFTEST_OK`, `XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK`.
- `scripts/Test-XpzKbDangerousPaths.ps1` (motor) — K1/K2: paths perigosos. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzKbDangerousPathsSelfTest.ps1. Tokens: `XPZ_KB_DANGEROUS_PATHS_SELFTEST_OK`.
- `scripts/Test-XpzKbLayerDiff.ps1` (motor) — K3/K4: camadas derivada/oficial. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzKbLayerDiffSelfTest.ps1. Tokens: `XPZ_KB_LAYER_DIFF_SELFTEST_OK`.
- `scripts/Test-XpzNotNotIsAntipattern.ps1` (motor) — K11: antipattern `not not X.IsXxx()`. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzNotNotIsAntipatternSelfTest.ps1. Tokens: `XPZ_NOT_NOT_ANTIPATTERN_SELFTEST_OK`.
- `scripts/Test-XpzKbFrenteHygiene.ps1` (motor) — Fase 2a: higiene de frente/pacote (diagnóstico). Emite contrato JSON `Kind=xpz-frente-hygiene-result`/`SchemaVersion=1` + `frentesDir`/`pacotesDir` resolvidos, consumido por `Remove-XpzKbFrenteHygieneFindings.ps1` (lockstep produtor↔consumidor). Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzKbFrenteHygieneSelfTest.ps1. Tokens: `XPZ_KB_FRENTE_HYGIENE_SELFTEST_OK`.
- `scripts/Remove-XpzKbFrenteHygieneFindings.ps1` (motor) — Fase 2a: executor de faxina fail-safe (correção, fora da pré-push). Consome o JSON de `Test-XpzKbFrenteHygiene` (fonte de verdade única; não reimplementa matching); dry-run por padrão, `-Apply` itera até ponto-fixo (cascata), `-Backup`/`-RunStamp` move-aside mesmo-volume; ancora reparse/path sob `-RepoRoot`. Contrato `Kind=xpz-frente-hygiene-cleanup-result`; status normativo, exit 0/2/3/1. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzKbFrenteHygieneCleanupSelfTest.ps1. Tokens: `XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK`.
- `scripts/Compare-XpzChecksums.ps1` (motor) — F1: classificador SAME/DIFF/NEW/DELETED. Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: Test-XpzChecksumCompareSelfTest.ps1. Tokens: `XPZ_CHECKSUM_COMPARE_SELFTEST_OK`.
- `scripts/Test-XpzKbIndexGate.ps1` (motor) — K9: contrato estruturado `-AsJson` (sob `-AsJson` nunca lança; bloqueio vira `{status:BLOCK}`); parte do `xpz-kb-parallel-setup/setup-contract.manifest.json`. Dono: xpz-kb-parallel-pre-push/SKILL.md; também xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzKbIndexGateContractSelfTest.ps1. Tokens: `XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK`.
- `scripts/XpzKbPrePushSelfTestSupport.ps1` (support-library) — helper dos 8 self-tests da frente (monta repos git de fixture, isola o `exit` do motor em pwsh-filho). Dono: xpz-kb-parallel-pre-push/SKILL.md. Validação: usado pelos self-tests da frente.

## Nota sobre a skill experimental de MSBuild

- `Evidência direta`: a skill `xpz-msbuild-import-export` passou a existir na raiz como contrato materializado em `xpz-msbuild-import-export/SKILL.md`.
- `scripts/Test-GeneXusMsBuildSetup.ps1` (motor) — probe não invasivo de ambiente; expõe `msBuildProbe` no JSON; descoberta de `MSBuild.exe` delega a GeneXusMsBuildPathContract.ps1. Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md. Validação: Test-GeneXusMsBuildDiscoveryContract.ps1.
- `scripts/GeneXusMsBuildPathContract.ps1` (support-library) — contrato de descoberta de `MSBuild.exe` (`vswhere` + catálogo estático VS 18/2022/2019). Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md. Validação: Test-GeneXusMsBuildDiscoveryContract.ps1.
- `scripts/Test-GeneXusMsBuildDiscoveryContract.ps1` (motor) — regressão do catálogo de descoberta de MSBuild. Dono: xpz-msbuild-import-export/SKILL.md. Validação: self-test.
- `scripts/Test-PrePushMsBuildProbeDocParity.ps1` (motor) — gate mecânico da pré-push para a frente MSBuild probe: paridade dos exemplos JSON em `10-base`, superfícies doc e inventário da skill quando o motor/probe mudam no intervalo; falha mecânica bloqueia o passo pré-push. Dono: 13-revisao-pre-push.md; também 10-base-operacional-msbuild-headless.md. Validação: self-test.
- `scripts/Open-GeneXusKbHeadless.ps1` (motor) — abertura/fechamento controlados da KB headless com captura de contexto. Dono: xpz-msbuild-import-export/SKILL.md. Validação: via baterias KB_Teste (abaixo).
- `scripts/Test-GeneXusXpzImportPreview.ps1` (motor) — `PreviewMode` de import sem alterar a KB; normaliza recortes `IncludeItems`/`ExcludeItems`; grava sinais (`compactSignals`) e `diagnosticDegraded` sem reclassificar a task. Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md. Validação: via baterias KB_Teste (abaixo).
- `scripts/Invoke-GeneXusXpzExport.ps1` (motor) — exportação headless de `XPZ`; exige `DependencyType="None"`/`ReferenceType="None"` para pacote nominal (sem dispensar inventário pós-export); resumo `packageInventory` + sidecar `package-inventory.json` (`nominalInventoryAt`/`extrasFullListAt`, `inventoryDegraded`), `postProcessingFailed` não reclassifica. Dono: xpz-msbuild-import-export/SKILL.md; também 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md, 10-base-operacional-msbuild-headless.md, README.md. Validação: via GeneXusXpzExportInventoryGovernance.ps1 + baterias KB_Teste.
- `scripts/Invoke-GeneXusXpzImport.ps1` (motor) — importação real de `XPZ`; `diagnosticDegraded` sem reclassificar; na **Decisão pós-gates** exige `-StartWatcher`/`-MonitorLogPath` na mesma rodada. Dono: xpz-msbuild-import-export/SKILL.md; também 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md, 10-base-operacional-msbuild-headless.md. Validação: via baterias KB_Teste (abaixo).
- `scripts/GeneXusKbEnvironmentInventorySupport.ps1` (support-library) — valida via MSBuild os nomes de environment declarados; retorna `kb_environment_names`/`kb_environment_count`; emite `KB_ENVIRONMENT_INVENTORY_OK`. Dono: xpz-kb-parallel-setup/SKILL.md; também xpz-msbuild-build/SKILL.md. Validação: via consumidores.
- `scripts/Get-GeneXusKbEnvironmentNames.ps1` (motor) — lista nomes de environment da KB via MSBuild. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via Test-XpzSetupAudit.ps1.
- `scripts/Set-XpzKbSourceMetadataDeployment.ps1` (motor) — grava `deployment_environment_name`/`deployment_hosting_kind`/`kb_environment_count`/`kb_environment_names`/`kb_environment_output_dirs`/`kb_environment_web_dirs` (de `-KbEnvironmentNames`/`-KbEnvironmentOutputDirs` + validação MSBuild `SetActiveEnvironment`; sem scan de pastas). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via Test-XpzKbDeploymentMetadata.ps1.
- `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1` (support-library) — lê e valida os campos de environment/deploy de `kb-source-metadata.md`. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via consumidores.
- `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (motor) — resolve `.cs` gerado por `kb_environment_web_dirs` e bloqueia quando o mapeamento não cobre o environment. **Fase 2 (guarda de família, Eixo B):** após resolver o environment e **antes** do bloco `web_dirs`, lê `deployment_hosting_kind` do metadata e, pelo registro (discriminador `runsFreshnessEngine`): valor fora do registro → `BLOCK` (exit 1, `nextStep` próprio de hosting_kind, via `New-InvalidHostingKindResult`); `recognized-no-engine` (ex.: `java-tomcat`) → **skip** `exit 0` (`status`=`CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`, sem `csPath`, via `New-SkippedJavaResult`) — **independe de `web_dirs`** (não regride KB .NET/legada sem bloco de deploy: hosting_kind ausente/vazio segue o fluxo `.cs` de hoje). Dono: xpz-msbuild-build/SKILL.md. Validação: Test-ResolveGeneXusGeneratedCsPathSelfTest.ps1 (inclui casos java-sem-`web_dirs`→skip e inválido→BLOCK). Tokens: `RESOLVE_GENEXUS_GENERATED_CS_PATH_SELFTEST_OK`.
- `scripts/Test-XpzKbMetadataWrapper.ps1` (motor) — compara o output do wrapper local `Test-*KbMetadataWrapper.ps1` com `kb-source-metadata.md`; valida campos obrigatórios (`last_xpz_materialization_run_at`/`kb_name`/`source_guid`) e opcionais de environment/deploy; classifica `OK`/`PENDENTE_DE_DADOS`/`PENDENTE`/`BLOCK`; consumido por Test-XpzSetupAudit.ps1 (linhas `metadata wrapper:`/`metadata/deploy:`). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via Test-XpzSetupAudit / self-tests de setup.
- `scripts/GeneXusKbDeployBinSupport.ps1` (support-library) — checa publicação no `web\bin` resolvido por `kb_environment_web_dirs` (max DLL de objeto excl. runtime, ou `*.config`; `GxNetCoreStartup.dll` só complementar em Core) e classifica o pós-build (`Invoke-GeneXusKbDeployBinPostBuildClassification`, consumida por BuildAll e SpecifyGenerate); `binCheck` repassado por `[System.Collections.IDictionary]` (por referência, não cópia). **Política do gate** (`Resolve-GeneXusKbDeployBinCheckPolicy`): roda por **sucesso operacional factual** (`-BuildOperationallySucceeded`), não pela string de status; `-PostImportDeployValidation`/`-StrictDeployBinCheck` ativam o gate (exit 49, status `compilou-mas-dll-destino-desatualizada`). **Fase 2 (Java/Tomcat):** valida `deployment_hosting_kind` pelo registro (`Get-GeneXusKbHostingKindSupportRecord`) e discrimina por `runsFreshnessEngine` — `recognized-no-engine`/`blocked-out-of-scope` (ex.: `java-tomcat`) roteiam para **skip** (`deployBinFreshness`=`skipped-hosting-unsupported`, exit 0, sem reclassificar), com `hostingSkipStatus`/`unsupportedReason` **derivados** do registro (nunca redigitados); os campos são inicializados `$null` na base da política (StrictMode-safe nos skips não-Java). Dono: xpz-msbuild-build/SKILL.md. Validação: Test-GeneXusDeployBinFreshnessSelfTest.ps1, Test-GeneXusDeployBinClassificationSelfTest.ps1, Test-GeneXusDeployBinPolicySelfTest.ps1, Test-GeneXusDeployBinHostingKindRoutingSelfTest.ps1. Tokens: `GENEXUS_DEPLOY_BIN_FRESHNESS_SELFTEST_OK`, `GENEXUS_DEPLOY_BIN_CLASSIFICATION_SELFTEST_OK`, `GENEXUS_DEPLOY_BIN_POLICY_SELFTEST_OK`, `GENEXUS_DEPLOY_BIN_HOSTING_KIND_ROUTING_SELFTEST_OK`. Exit: 49.
- `scripts/Test-GeneXusDeployBinFreshness.ps1` (motor) — diagnóstico **somente-leitura** de frescor de `web\bin` do environment de deploy (complementa `Test-GeneXusRuntimeFreshness.ps1`): resolve `web\bin` por `kb_environment_web_dirs` + `deployment_hosting_kind` e compara timestamps com a linha de corte (`-BuildStartedAt`, ou `timing.msbuildStart` de `-BuildResultJsonPath`); `-EnvironmentName`/`-DeploymentHostingKind`/`-ParallelKbRoot`/`-KbMetadataPath`/`-AsJson`. **Não** é gate (sem exit próprio); o gate de política pós-build (exit 49, `-PostImportDeployValidation`/`-StrictDeployBinCheck`, `-BuildOperationallySucceeded`) vive em `GeneXusKbDeployBinSupport.ps1` (`:189`). **Fase 2 (Java/Tomcat):** fia o registro (discriminador `runsFreshnessEngine`) — `java-tomcat` (recognized-no-engine) → `status`=`skipped-hosting-unsupported` + `summary`=`unsupportedReason`; valor fora do registro → mensagem canônica. Dono: xpz-msbuild-build/SKILL.md. Validação: Test-GeneXusDeployBinFreshnessBuildStartedAtSelfTest.ps1, Test-GeneXusDeployBinDotNetGoldenSelfTest.ps1 (3 casos aceito/skip/rejeitado). Tokens: `GENEXUS_DEPLOY_BIN_FRESHNESS_BUILDSTARTEDAT_SELFTEST_OK`.
- `scripts/Test-GeneXusRuntimeFreshness.ps1` (motor) — diagnóstico **somente-leitura** de frescor de runtime (Eixo C): lê `nav_objs.xml` (`genreq`/`nogenreq`) + timestamps dos artefatos gerados vs `-ImportedAt`; saída `runtime-fresh`/`runtime-stale`/`runtime-unknown`. **Fase 2 (paridade Java/Tomcat):** aceita `-DeploymentHostingKind` **opcional** (guarda de família); família não-.NET (`java-tomcat`, `recognized-no-engine`) → `status=skipped-hosting-unsupported` (exit 0) **sem** derivar `CSharpModel\web`; ausente/vazio → comportamento .NET de hoje (zero regressão); valor fora do registro → `runtime-hosting-kind-invalido` (exit não-zero). Dono: xpz-msbuild-build/SKILL.md; também xpz-msbuild-import-export/SKILL.md, xpz-kb-parallel-setup/SKILL.md. Validação: Test-GeneXusRuntimeFreshnessHostingGuardSelfTest.ps1. Tokens: `GENEXUS_RUNTIME_FRESHNESS_HOSTING_GUARD_SELFTEST_OK`.
- `scripts/GeneXusKbHostingKindSupport.ps1` (registro/motor) — registro-fonte-única dos `deployment_hosting_kind` reconhecidos; acesso **só** via a API pública `Get-GeneXusKbHostingKindSupportRecord` (nenhum consumidor toca a hashtable interna `$script:GeneXusKbHostingKindSupportRegistry`). Materializa por registro `family`/`freshnessSupportState`/`freshnessSkipStatus`/`sentinel`/`webDirFreshnessExtensions`/`runtimeFreshnessExtensions`/`runtimeExclusionPrefixes`/`publicationTargets`/`deployTargetKind`/`outputModelSubPath`/`tentativeFields`; `java-tomcat` entra como `recognized-no-engine` → `skipped-hosting-unsupported` (campos de motor provisórios `tentative-java`/`$null`, não `@()`). Cláusula **no-bridge**: `publicationTargets` opaco às Fases 1/2. Inclui `ArgumentCompleter` fail-soft opt-in. Fase 1 da paridade de gerador Java/Tomcat; **NÃO** toca o motor de deploy-bin (`Get-GeneXusKbDeployBinPaths`/`Test-GeneXusKbDeployBinFreshnessCore` seguem escalares). **Fase 2** fiou o registro nos consumidores via a API pública (validação de `deployment_hosting_kind` na escrita `Set-XpzKbSourceMetadataDeployment.ps1` e no diagnóstico `:526`; discriminador por `runsFreshnessEngine` na política/fachada de deploy-bin; guardas de família dos Eixos C `Test-GeneXusRuntimeFreshness.ps1` e B `Resolve-GeneXusGeneratedCsPath.ps1`) — o motor permanece escalar (aridade é Fase 3). Dono: java-tomcat-paridade-gerador-design.md. Validação: Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1. Tokens: `GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK`.
- `scripts/Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1` (motor) — self-test de drift do registro: mensagem por arquivo + dot-source real + dispatch por família + uso da API pública (varredura estática do token interno) + contrato de skip (string de skip fonte-única, sem redigitação fora do registro) + asserção da cláusula no-bridge (`publicationTargets` não referenciado fora do registro/self-test) + `ArgumentCompleter` fail-soft (prova de caminho vivo via API vs fallback estático, com `Count==1`). Dono: java-tomcat-paridade-gerador-design.md. Validação: self-test. Tokens: `GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK`.
- `scripts/Test-GeneXusDeployBinDotNetGoldenSelfTest.ps1` (motor) — golden da fachada `Test-GeneXusDeployBinFreshness.ps1` com **três** casos (timestamps/paths normalizados `<TS>`/`<ROOT>`): **aceito** `dotnet-framework-iis` com DLL fresca → `fresh`; **skip** `java-tomcat` → `skipped-hosting-unsupported` (Fase 2 fiou o registro na fachada; era rejeitado como inválido na Fase 1); **rejeitado** `foobar` (genuinamente inválido, fora do registro) → `skipped` com mensagem canônica — preserva a cobertura de rejeição que o caso java-tomcat deixou de exercer ao virar skip. É excluído **só da varredura §8** do drift self-test (o baseline SKIP embute o literal `skipped-hosting-unsupported` via `summary`=`unsupportedReason`; baseline congelado, não redigitação de emissor). Dono: xpz-msbuild-build/SKILL.md (família deploy-bin). Validação: self-test (`-UpdateBaseline` para recapturar conscientemente). Tokens: `GENEXUS_DEPLOY_BIN_DOTNET_GOLDEN_SELFTEST_OK`.
- `scripts/GeneXusMsBuildWatcherSupport.ps1` (support-library) — contrato comum de watcher dos wrappers MSBuild (`-StartWatcher`, `-MonitorLogPath`, `watcherContext`, `timing.phases`); compartilhado por build, specify/generate, preview/import e export. Dono: xpz-msbuild-build/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: via consumidores.
- `scripts/Start-GeneXusKbBuildDetached.ps1` (motor) — orquestrador opt-in do modo desacoplado de build longo: Tarefa Agendada one-shot (console oculto, `-WindowStyle Hidden`) que executa Invoke-GeneXusKbBuildAll.ps1 fora da sessão (sobrevive a fechar janela/app, **não** a logoff); sinaliza conclusão por arquivo-sentinela (escrita atômica `.tmp`+rename); repasse por hashtable splatting; transporte, não autoridade de política; v1 sem watcher (`timing.phases` vazio). Dono: xpz-msbuild-build/SKILL.md. Validação: Test-StartGeneXusKbBuildDetachedContract.ps1. Exit: 0/46/90.
- `scripts/Wait-GeneXusKbBuildDetached.ps1` (motor) — helper de espera do modo desacoplado: combina sentinela (`done=true`) + heartbeat da Tarefa Agendada (`Get-ScheduledTask`), com margem de corrida e timeout; só leitura; `outcome` `concluido`/`falha-anomala`/`timeout`. Dono: xpz-msbuild-build/SKILL.md. Validação: Test-WaitGeneXusKbBuildDetachedContract.ps1. Exit: 0/70/71.
- `Evidência direta` (transversal aos wrappers MSBuild): os wrappers das famílias `xpz-msbuild-build`/`xpz-msbuild-import-export` (mais `scripts/Open-GeneXusKbHeadless.ps1`, `scripts/Get-GeneXusKbProperty.ps1` e `scripts/Test-GeneXusKbConsistency.ps1`, via `New-ExecutionEvidence`) separam causas acionáveis em `blockingReasons` da evidência bruta em `executionEvidence`, registram o enriquecimento de `PATH` em `observedContext.pathEnrichment` e marcam `postProcessingFailed`/`diagnosticDegraded` sem reclassificar a task quando a evidência primária do log sustenta conclusão; `msBuildExitCode` top-level é compatibilidade transitória de `executionEvidence.msBuildExitCode`. Contrato em `10-base-operacional-msbuild-headless.md` e `xpz-msbuild-import-export/SKILL.md`.
- `Regra operacional`: contrato **Decisão pós-gates** em `xpz-msbuild-import-export/SKILL.md` (espelhado em `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md` e `10-base-operacional-msbuild-headless.md`): com importação real já autorizada na sessão, `Test-GeneXusImportFileEnvelope.ps1` → `apto para prosseguir` e inventário do pacote (passo 6c da skill) sem bloqueio de extras, o agente deve executar `Invoke-GeneXusXpzImport.ps1` na mesma rodada com `-StartWatcher` e `-MonitorLogPath`; `Test-GeneXusXpzImportPreview.ps1` não é obrigatório nesse caminho — preview permanece para rodada exploratória ou quando import real ainda não foi autorizado. Autorização de import na sessão não cobre extras não conciliados, módulos/ExternalObjects de plataforma não pedidos nem `attributesTopLevelUnreconciled` em pacote cirúrgico (**ABORT** e listar pacote completo ao usuário); **`exitCode=48`** (Categoria B: rejeição MSBuild no log de export/import/preview upstream) **bloqueia** import real na mesma rodada, mesmo com autorização de import na sessão; anti-padrões nomeados na skill: **parada após envelope apto** e **reempacotar lixo de export**.
- `Inferência forte`: as baterias `KB_Teste_*` documentadas abaixo validaram o mecanismo experimental export → preview → import real dos wrappers; essa sequência não substitui a orquestração por sessão da **Decisão pós-gates** quando o usuário já autorizou import real e os gates de envelope/inventário passaram sem bloqueio.
- `Evidência direta`: `Open-GeneXusKbHeadless.ps1` foi validado com uma KB de teste sanitizada (`KB_Teste_A`), com `EnvironmentName=NETSQLServer`.
- `Evidência direta`: `Test-GeneXusXpzImportPreview.ps1` foi validado com um `XPZ` full exportado nessa mesma KB sanitizada.
- `Evidência direta`: o `PreviewMode` executado nessa validação não alterou a KB.
- `Evidência direta`: `Invoke-GeneXusXpzImport.ps1` foi validado com o `XPZ` exportado nesta frente e concluiu com sucesso operacional, embora tenha produzido mensagens de stderr no log.
- `Evidência direta`: uma nova rodada de importação real com a KB fechada manteve o mesmo padrão de `stderr`, incluindo as mensagens de `mismatched input ']' expecting 'default'` e o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`, sem impedir `exitCode = 0`.
- `Evidência direta`: na instalacao validada nesta conversa, `IncludeItems` e `ExcludeItems` funcionaram em `PreviewMode`, enquanto `UpdateFile` e `ImportKBInformation` ficaram bloqueados por ausencia de propriedade publica correspondente na task `Import` carregada.
- `Evidência direta`: os wrappers de preview e importação real passaram a normalizar recortes múltiplos de `IncludeItems` e `ExcludeItems`, com serializacao em formato de lista aceito operacionalmente pela task carregada.
- `Evidência direta`: depois dessa normalizacao, recortes combinados passaram a funcionar de forma confiavel e permitiram reduzir o ruido lateral sem alterar o `exitCode = 0` da importação real.
- `Evidência direta`: na bateria de recortes desta frente, o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json` deixou de ficar restrito a um conjunto pequeno de objetos da `KB_Teste_A` e reapareceu também em `Procedure:procExtraiTextoDoPdf`, `Procedure:procGeraPdfDoDANFCE` e `Procedure:procCarregaSDTsDaNFe`.
- `Evidência direta`: no recorte mais reduzido desta bateria, a importação real manteve `exitCode = 0`, mas o log passou a destacar `src0246` em `Procedure:procCarregaSDTsDaNFe`, com referencia a objeto não definido `procStrZERO`.
- `Evidência direta`: na inspecao do XML extraido do `XPZ` exportado com `ExportAll=true`, `procStrZERO` apareceu no bloco `Source`, mas não apareceu como objeto exportado nem como referencia declarada do pacote.
- `Evidência direta`: um teste controlado derivando o `XPZ` exportado via headless e preenchendo o `Source` global com os valores do pacote full não alterou o padrão principal da importação real; `CssProperties.json`, `mismatched input ']' expecting 'default'`, `src0246` e `procStrZERO` permaneceram no mesmo comportamento observado antes.
- `Evidência direta`: um segundo teste controlado derivando o mesmo `XPZ` exportado via headless e trocando apenas as duas ocorrências de `Pattern Settings` de `Padrões GeneXus` para `GeneXus Patterns` também não alterou o padrão principal da importação real.
- `Inferência forte`: com esses dois testes, as duas diferencas remanescentes identificadas entre o pacote full e o export headless deixaram de ser suspeitas fortes para o ruido principal desta frente.
- `Evidência direta`: em uma segunda KB de teste sanitizada (`KB_Teste_B`), a exportação full headless com `ExportAll=true` concluiu com sucesso operacional, `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, o `PreviewMode` de importação do pacote full exportado headless concluiu com `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, a importação real do pacote full exportado headless concluiu com `exitCode = 0`; o `stderr` residual observado ficou restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteúdo específico da `KB_Teste_A`.
- `Inferência forte`: a bateria em `KB_Teste_B` reforca que a trilha headless de exportação, preview e importação via `MSBuild` funciona em outra KB e que o caso `procCarregaSDTsDaNFe`/`procStrZERO` pertence ao conteúdo da `KB_Teste_A`, não ao mecanismo central da skill.
- `Evidência direta`: em uma terceira KB de teste sanitizada (`KB_Teste_C`), a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com sucesso operacional.
- `Evidência direta`: na primeira tentativa de `preview` e importação de `KB_Teste_C`, o erro foi apenas de orquestracao local (`XpzPath inválido` antes de o arquivo existir), por disparo concorrente antes do fim do export; repetida a rodada em sequência correta, o fluxo passou sem bloqueio funcional novo.
- `Evidência direta`: na mesma `KB_Teste_C`, o `stderr` residual da importação real voltou a ficar limitado ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteúdo observado na `KB_Teste_A`.
- `Evidência direta`: em uma quarta KB de teste sanitizada (`KB_Teste_D`), a abertura headless confirmou um `Environment` coerente, e a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com sucesso operacional.
- `Evidência direta`: na `KB_Teste_D`, o `stderr` residual da importação real permaneceu restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem bloqueio de conteúdo equivalente ao caso `procCarregaSDTsDaNFe`/`procStrZERO`.
- `Evidência direta`: em uma quinta KB de teste sanitizada (`KB_Teste_E`), a abertura headless confirmou um contexto ativo coerente, e a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com `exitCode = 0`.
- `Evidência direta`: na `KB_Teste_E`, o `PreviewMode` registrou no `stdout` mensagens de contato com `GeneXus Server` em `http://sandbox.genexusserver.com/v18`, exigencia de credenciais e ausencia de licenca `GXtest` valida, mesmo mantendo `exitCode = 0`.
- `Evidência direta`: na mesma `KB_Teste_E`, `importedItems` veio vazio tanto no preview quanto na importação real, o que impede tratar essa rodada como evidência de sucesso funcional equivalente às KBs `KB_Teste_B`, `KB_Teste_C` e `KB_Teste_D`.
- `Evidência direta`: em `KB_Teste_F`, a bateria completa de exportação full headless, preview de importação e importação real concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, e o `stderr` residual ficou restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_G`, a bateria completa de exportação full headless, preview de importação e importação real também concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, com o mesmo `stderr` lateral observado nas KBs favoraveis anteriores.
- `Evidência direta`: em `KB_Teste_H`, a bateria completa de exportação full headless, preview de importação e importação real também concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, com o mesmo `stderr` lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_Grande_A`, a abertura headless, o export full headless e o preview de importação concluiram com sucesso operacional; o preview trouxe `importedItems` preenchido mesmo em uma KB de grande porte.
- `Evidência direta`: na mesma `KB_Teste_Grande_A`, a abertura, o export e o preview reportaram warning recorrente sobre item desconhecido `WebPanelDesigner`, fornecido por extensao ausente `K2B Object Designer`, com alerta de risco de perda de informação relacionada a esses itens.
- `Evidência direta`: na importação real da `KB_Teste_Grande_A`, o wrapper inicial bateu timeout por duracao extrema, mas o processo `MSBuild` continuou em execução; o monitoramento posterior confirmou progresso continuo, inclusive em geração de padrões `WorkWith`, ate o `stdout` terminar com `Close Knowledge Base Task Sucesso`.
- `Inferência forte`: a `KB_Teste_Grande_A` demonstrou que a skill consegue concluir também em KB de grande porte, mas com janela de execução muito superior a das KBs medias; para esse perfil, timeout curto do wrapper não deve ser confundido com falha da operacao.
- `Inferência forte`: com evidência operacional repetida em `KB_Teste_A`, `KB_Teste_B`, `KB_Teste_C`, `KB_Teste_D`, `KB_Teste_F`, `KB_Teste_G`, `KB_Teste_H`, `KB_Teste_Grande_A` e agora `KB_Teste_E`, a trilha central de exportação, preview e importação via `MSBuild` permanece validada como mecanismo experimental; ao mesmo tempo, ficou demonstrado que `exitCode = 0` isolado não basta para validar sucesso funcional quando a KB aciona dependencia externa de `GeneXus Server` ou restrição de licenca, e que KBs muito grandes exigem janela de execução compativel com a escala.
- `Inferência forte`: para o estado atual desta frente, o bloqueio remanescente mais importante deixou de ser do wrapper e passou a apontar para conteúdo da KB/`XPZ`, por referencia quebrada em `Source` durante a importação.
- `Evidência direta`: os scripts previstos para exportação efetiva e importação efetiva agora estao materializados nesta fase.
- `Regra editorial`: a existência dessa skill não promove a trilha `MSBuild` a fluxo oficial da base nem altera automaticamente o comportamento das skills `xpz-*` existentes.

## Fontes consolidadas
- 00-inventario-da-base-documental.md
- 30-inventario-bruto-kb.md
- 98-mapeamento-para-consolidacao-em-10-arquivos.md
- 99-resumo-da-consolidacao.md

## Origem incorporada - 00-inventario-da-base-documental.md

## Papel do documento
índice

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

## Classificação por papel

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
- `Inferência forte`: isso cria uma colisao de prefixo, mas não inviabiliza a ordem de leitura porque os nomes continuam distintos.
- `Evidência direta`: arquivos heurísticos da subpasta (`15`, `16`, `17`) já tinham sido endurecidos para evitar promessas de importação.
- `Inferência forte`: qualquer consolidação precisava preservar essa versão mais conservadora como fonte principal.

## Decisão de consolidacao

- `Evidência direta`: a base final foi reorganizada na raiz com numeração global.
- `Evidência direta`: os documentos finais passaram a existir na raiz sob os nomes `00`, `01`, `02`, `03`, `04`, `10`, `11`, `12`, `20` a `26`, `30` e `99`.
- `Inferência forte`: a subpasta `docs-kb-md` deve ser tratada como arquivo histórico de trabalho, não como referência operacional primária.


## Origem incorporada - 30-inventario-bruto-kb.md

## Papel do documento
empirico

## Nível de confianca predominante
alto

## Depende de
nenhum; esta versão substitui o dump bruto nominal para publicacao

## Usado por
01-base-empirica-geral.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 00-indice-da-base-genexus-xpz-xml.md

## Objetivo
Preservar os fatos agregados da varredura XML sem expor nomes reais de objeto, módulos, pais, caminhos ou descricoes de negocio da KB de origem.
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

## Politica de redacao desta versão publica

- nomes reais de objeto foram removidos desta versão
- caminhos reais da KB foram substituidos por caminho sanitizado
- a utilidade operacional permanece nos documentos `10`, `11`, `12`, `27` e `28`, que preservam contagens, GUIDs e familias estruturais
- para materialização real de XML ou XPZ, a fonte continua sendo XML bruto privado comparavel, exceto nos casos em que a própria base publica já publicar bloco `molde pronto` suficiente para materialização controlada

## Observação

- Hipotese: o dump nominal completo deve permanecer apenas em acervo privado controlado.
- Inferencia forte: para uso publico, esta versão agregada cobre os fatos necessários sem expor a KB original.


## Origem incorporada - 98-mapeamento-para-consolidacao-em-10-arquivos.md

## Papel do documento
índice e operacional

## Nível de confianca predominante
alto

## Depende de
00-readme-genexus-xpz-xml.md, 00-inventario-da-base-documental.md, 99-resumo-da-consolidacao.md

## Usado por
futura consolidacao da base em serie documental mais enxuta e roteavel

## Objetivo
Mapear a base atual para a estrutura consolidada proposta, incluindo a serie `01` desdobrada.
Preservar todo o conteúdo existente, definindo destino e critério de incorporacao antes de qualquer fusao.

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

- não apagar conteúdo
- não promover inferencia para evidencia
- manter `Evidência direta`, `Inferência forte` e `Hipótese`
- mover ou fundir por função documental, não por ordem histórica de criacao
- quando houver sobreposicao, manter a versão mais clara e mais conservadora

## Mapeamento arquivo a arquivo

### 00-indice-da-base-genexus-xpz-xml.md

- Destino principal: `00-indice-da-base-genexus-xpz-xml.md`
- Manter:
  - objetivo da base
  - escopo
  - ordem de leitura
  - limites metodologicos
- Incorporar também:
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
  - índice mestre da serie `01`
  - premissas empiricas gerais sobre XML/XPZ
  - observacoes gerais de estrutura
  - limites do que foi de fato observado

### 02-genexus-xpz-generation-rules.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - regras gerais de geração
  - postura conservadora de montagem
  - restrições de fonte e materialização
- Integrar sem duplicar trechos que hoje já estao mais fortes em `02-regras-operacionais-e-runtime.md`

### 03-genexus-object-design-patterns.md

- Destino principal: `06-padroes-de-objeto-e-nomenclatura.md`
- Manter:
  - padrões de nomenclatura
  - padrões de relacionamento aparente
  - leitura conceitual do acervo

### 04-genexus-open-points.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - conflitos
  - lacunas
  - questoes ainda não fechadas
  - decisoes operacionais provisórias

### 10-matriz-part-types-por-tipo.md

- Destino principal: `01b-matriz-part-types-por-tipo.md`
- Manter:
  - tabela de `PartType`
  - frequencias por tipo
  - classificação preliminar
- Consolidar como arquivo filho da serie `01`

### 11-campos-estaveis-vs-variaveis.md

- Destino principal: `01c-campos-estaveis-vs-variaveis.md`
- Manter:
  - atributos recorrentes do no `<Object>`
  - campos estaveis, variáveis e contextuais
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
  - critérios de escolha de template
  - o que preservar
  - o que pode ser alterado com mais cautela
- Consolidar como seção:
  - `Clonagem conservadora`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - leitura heuristica de obrigatoriedade
  - opcionalidade
  - ausencia de evidencia suficiente
- Consolidar como seção:
  - `Obrigatoriedade heuristica`

### 22-tipos-prontos-para-geracao-conservadora.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - classificação por prontidao relativa
  - decisão operacional atual de `Transaction` e `WebPanel`
- Consolidar como seção:
  - `Prontidao por tipo`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - mapa resumido de risco
  - recomendacao prática por tipo
- Consolidar como seção:
  - `Mapa de risco`

### 02-regras-operacionais-e-runtime.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - algoritmo de geração
  - regras de materialização
  - regras de serializacao XPZ
  - regras de fonte
  - validacoes minimas
- Consolidar como seção central:
  - `Especificacao executavel`

### 25-checklist-para-novos-templates.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - checklist de coleta futura
  - critérios de template adicional
- Consolidar como seção:
  - `Checklist de templates`

### 26-guia-para-agente-gpt.md

- Destino principal: `08-guia-para-agente-gpt.md`
- Manter:
  - ordem de consulta
  - critérios de resposta
  - quando gerar, recusar ou abortar
  - regras de materialização, serializacao e fonte do ponto de vista do agente
- Incorporar trechos introdutorios mais curtos também em `00-indice-da-base-genexus-xpz-xml.md`

### 04-webpanel-familias-e-templates.md

- Destino principal: `04-webpanel-familias-e-templates.md`
- Manter:
  - familias estruturais
  - templates representativos
  - regras específicas
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
  - politica de versão publica sanitizada
- Não reincorporar:
  - dump nominal privado antigo

### 99-resumo-da-consolidacao.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - histórico da consolidacao
  - decisoes tomadas
  - renomeacoes
  - conflitos resolvidos

## Mapeamento por seção alvo

### 00-indice-da-base-genexus-xpz-xml.md

- de `00-indice-da-base-genexus-xpz-xml.md`
- de `26-guia-para-agente-gpt.md`: ordem de consulta resumida e limites de uso

### 01-base-empirica-geral.md

- de `01-base-empirica-geral.md`
- de `10-matriz-part-types-por-tipo.md`
- de `11-campos-estaveis-vs-variaveis.md`
- de `12-diffs-estruturais-por-tipo.md`
- reorganizado depois como serie `01` com índice mestre em `01-base-empirica-geral.md` e arquivos filhos `01a` a `01h`

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

- preservar o conteúdo integral, movendo para seções mais amplas
- quando duas seções disserem quase a mesma coisa, manter a versão mais conservadora e citar a complementar
- tabelas muito grandes devem aparecer uma vez só
- templates sanitizados devem permanecer apenas nos arquivos de tipo, não em documentos gerais
- histórico e inventario devem ficar separados das regras executaveis

## Ordem recomendada de execução da consolidacao

1. consolidar `09-inventario-e-rastreabilidade-publica.md`
2. consolidar `01-base-empirica-geral.md`
3. consolidar `02-regras-operacionais-e-runtime.md`
4. consolidar `03-risco-e-decisao-por-tipo.md`
5. manter `04` e `05` como arquivos especializados
6. consolidar `06`, `07` e `08`
7. revisar `00-indice-da-base-genexus-xpz-xml.md` por fim, apontando para a nova estrutura

## Observação final

- Inferencia forte: essa consolidacao reduz bem a fragmentacao sem sacrificar navegabilidade para GPT.
- Hipotese: depois da fusao, a base ficara mais fácil de usar do que hoje, desde que os novos arquivos tenham sumario interno e seções bem delimitadas.


## Origem incorporada - 99-resumo-da-consolidacao.md

## Papel do documento
índice

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

- manter a versão mais conservadora sempre que havia choque entre resumo e heurística operacional
- deixar a raiz como ponto de leitura principal
- tratar `docs-kb-md` como staging/histórico e não como fonte operacional primária
- preservar o caráter heurístico dos antigos `14`, `15`, `16` e `17`, agora `21`, `22`, `23` e `24`
- atualizar a politica para `Transaction` e `WebPanel` de bloqueio por prudencia para execução controlada com base interna

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

- `Evidência direta`: a base passou a reconhecer 183 `Transaction` e 1196 `WebPanel` como massa amostral suficiente para execução controlada.
- `Inferência forte`: a mudanca prática foi de bloqueio por prudencia para tentativa controlada com template interno da própria base.
- `Evidência direta`: um teste controlado de importação de `.xpz` mínimo de `Procedure` foi bem-sucedido nesta trilha e confirmou o envelope normal sem `KnowledgeBase`.
- `Evidência direta`: o mesmo teste mostrou que `Source/@kb` e `Source/Version/@guid` não podem ficar como placeholders textuais; precisam ser GUIDs sintaticamente validos.
- `Hipótese`: os erros adicionais de importação que aparecerem devem continuar sendo incorporados ao refinamento desta mesma documentação.

## Aliases publicos de Procedure de relatório

Estes aliases foram criados em 2026-04-25 a partir da análise estrutural de 77 XMLs de `Procedure` de relatório no acervo privado. Cada alias representa o menor XML observado dentro da respectiva familia estrutural definida em `05b-procedure-relatorio-familias-e-templates.md`.

| Alias publico | Familia | Critério estrutural |
|---|---|---|
| `PRCRelatorioExemploF1` | F1 — Embriao sem layout ativo | FE=0, sem Header, sem Footer; menor XML da faixa |
| `PRCRelatorioExemploF2` | F2 — Molde base com cabecalho de pagina | FE=0, com Header e/ou Footer; menor XML da faixa |
| `PRCRelatorioExemploF3` | F3 — Listagem linear simples | FE=1-2; menor XML da faixa |
| `PRCRelatorioExemploF4` | F4 — Relatório com agrupamento e totalizacao | FE=3-6, PB<=24; menor XML da faixa |
| `PRCRelatorioExemploF5` | F5 — Relatório complexo de alto volume | FE>=7 ou PB>=25; menor XML com FE>=10 e PB>=20 simultaneamente |

- Rastreabilidade privada: os nomes reais dos representantes estao registrados em `GeneXus-XPZ-PrivateMap/maps/object-alias-map.csv`.
- Uso previsto: esses aliases servem como referencia estrutural para `xpz-reader`, `xpz-builder` e `xpz-doc-builder` ao trabalhar com `Procedure` de relatório.
- Regra editorial: nunca usar o alias como única fonte para materialização.
- Regra editorial: quando `05b-procedure-relatorio-familias-e-templates.md` oferecer `molde pronto` suficiente para a familia simples coberta, o alias pode servir apenas como referencia de classificação para chegar a esse molde sanitizado.
- Regra editorial: fora dessa cobertura simples, ou depois de tentativa inicial mais um único corretivo curto sem sucesso, o próximo passo obrigatório volta a ser XML real comparavel.
