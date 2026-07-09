---
name: xpz-msbuild-import-export
description: Skill para importação e exportação de XPZ via MSBuild, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates (pontos de liberação ou bloqueio) de segurança
---

# xpz-msbuild-import-export

Skill para operações de importação e exportação de `XPZ` do GeneXus por `MSBuild`, em execução sem interface gráfica.

Esta skill não substitui o fluxo oficial atual da trilha paralela da KB, não depende de `GeneXus Server` e não trata sucesso operacional como evidência suficiente de sucesso funcional.

No estado atual, o mecanismo central desta skill já foi validado operacionalmente em múltiplas KBs. O próximo passo desta frente não é mais provar exportação, `PreviewMode` e importação real como capacidade basal, e sim deixar explícitos:

- o que conta como prontidão operacional estável
- quais limites conhecidos ainda exigem uso controlado
- como classificar exceções sem confundi-las com defeito central do wrapper

Exceções já mapeadas que a skill deve tratar explicitamente:

- conteúdo inconsistente da KB/`XPZ`, como `KB_Teste_A`
- validação funcional incompleta por `GeneXus Server` ou licença, como `KB_Teste_E`
- execução longa em KB grande, como `KB_Teste_Grande_A`
- warning estrutural por extensão ausente, como `WebPanelDesigner`/`K2B Object Designer`

Critério atual de prontidão operacional desta skill:

- probe (sondagem técnica inicial), abertura headless, exportação, `PreviewMode` e importação real já validados em KBs de teste controladas
- classificação explícita entre sucesso operacional, validação funcional incompleta e problema de conteúdo da KB/`XPZ`
- logs, artefatos e parâmetros sensíveis rastreáveis
- limites conhecidos já documentados e não tratados como surpresa operacional

Uso mais amplo desta skill ainda depende de:

- critério estável para KBs com dependência externa, licença ou extensão ausente
- interpretação madura de execução longa em KB grande
- confiança suficiente para uso fora de ambiente de experimento controlado

---

## GUIDELINE

Orquestre operações de `XPZ` via `MSBuild` com parâmetros explícitos, coleta rastreável de evidências e aborto seguro antes de operações sensíveis. Priorize descoberta de ambiente, `PreviewMode`, `UpdateFile` quando suportado pela task carregada, `IncludeItems`/`ExcludeItems` para recortes controlados e validação posterior. Nunca trate importação real como padrão.

> **Exceção — validação de `API` (from-spec):** o `PreviewMode` prioriza inspeção, mas **não valida** uma `API` — reporta `importTaskSuccess:true` mesmo para `API` inválida (valor de `[SecurityLevel]` inválido, `Procedure` de implementação ausente). Só a **importação real** roda a validação de gramática/referências da `API` (inclusive a resolução `API => Procedure`). Quando o objetivo for **validar** uma `API` from-spec, usar importação real (empacotando a `API` com seu `Procedure`, ou fazendo staging do `Procedure` antes) — a autorização de import real e os gates de envelope continuam valendo. Ver `10-base-operacional-msbuild-headless.md` e `xpz-builder/responsibilities-by-type/api.md`.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Se a skill estiver publicada por symlink, junction ou outro reparse point, resolva primeiro a pasta real da skill e só então interprete referências relativas como `../arquivo.md`.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- planejar ou executar validação de ambiente para GeneXus via `MSBuild`
- abrir a `Knowledge Base` por `OpenKnowledgeBase`
- confirmar versão ativa e `Environment` ativo
- executar preview de importação com `PreviewMode`
- gerar `UpdateFile`, quando suportado pela task carregada, para análise prévia de impacto
- exportar `XPZ` com parâmetros explícitos
- importar `XPZ` apenas em fase explicitamente autorizada de teste controlado
- classificar resultado em sucesso operacional versus confirmação funcional pendente
- inspecionar propriedades da KB, Version, Environment, Generator, DataStore ou Object
  para diagnóstico pré-operação via `Get*Property`

Do NOT use esta skill para:
- substituir o fluxo oficial atual da trilha paralela da KB
- cenários que dependam de `GeneXus Server` como requisito operacional
- KB de produção ou homologação compartilhada sem janela clara para experimento
- inferir silenciosamente `KbPath`, versão, `Environment` ou parâmetros sensíveis
- afirmar sucesso funcional apenas porque a chamada via `MSBuild` terminou sem erro
- editar ou ajustar o `Source`, `Rules` ou `CDATA` de um objeto de KB — isso pertence ao `xpz-builder`

---

## RESPONSIBILITIES

- Usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como base principal desta frente
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`, `LogPath` e `Genexus.Tasks.targets`
- Enriquecer preventivamente o `$env:PATH` herdado com subdirs do GeneXus 18 (`GeneXus18`, `gxnet`, `gxnet\bin`, `gxnetcore`) antes de chamar `MSBuild`, registrando `observedContext.pathEnrichment`; isso é defesa de ambiente headless, não evidência de falha reproduzida em import/export puro
- Tratar `Test-GeneXusMsBuildSetup.ps1` como probe (sondagem técnica inicial) não invasivo, anterior a qualquer abertura de KB
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de `C:\Program Files (x86)`
- Permitir auto-criação apenas do `WorkingDirectory` explicitamente informado, depois de validado como seguro e fora das áreas proibidas
- Preferir `Temp` como destino de artefatos efêmeros de execução e manter `scripts` como pasta de wrappers permanentes
- Distinguir claramente:
  - sucesso operacional da chamada
  - efeito funcional observado depois no GeneXus
- Classificar explicitamente quando a rodada for `ensaio metodológico/experimental`, especialmente em casos de serialização, roundtrip controlado, prova de wrapper, prova de envelope, exportação headless, `PreviewMode` ou importação de teste sem validação funcional posterior
- Em `ensaio metodológico/experimental`, não narrar o resultado como mudança funcional validada; limitar a conclusão ao que a evidência realmente cobriu
- Quando a estratégia segura exigir mais de uma fase, tratar cada rodada como incremento controlado e validar build/import antes da fase seguinte
- Sucesso operacional de uma fase não autoriza recompor automaticamente pacote acumulado para a fase seguinte; a próxima rodada deve preferir o delta novo ainda não validado
- Exigir que o probe (sondagem técnica inicial) devolva diagnóstico estruturado com `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`
- Preferir `JSON` como formato canônico inicial desse diagnóstico
- Registrar `stdoutSignals` (campos semânticos por domínio), `stderrContent`, `stderrFilteredNoise`, `exitCode`, caminho do `.msbuild` temporário e caminho do log
- Validar a assinatura efetiva do wrapper e da task antes de assumir formato de parâmetro sensível de exportação ou importação
- Em exportação full da KB, preferir o atalho ergonômico `-FullExport` do wrapper local quando ele existir; manter `ExportAll='true'` apenas como compatibilidade com contratos antigos
- Privilegiar `PreviewMode` e, quando suportado pela task carregada, `UpdateFile` antes de importação real **quando import real ainda não foi autorizado na sessão ou a rodada for exploratória**; com import real já autorizado e passos **6b–6c** sem bloqueio, seguir **Decisão pós-gates** no WORKFLOW (preview não obrigatório; `Invoke-GeneXusXpzImport.ps1` na mesma rodada)
- Distinguir explicitamente `operação na KB` de `atualização do acervo oficial`
- Sucesso de preview ou importação não autoriza atualização manual de `ObjetosDaKbEmXml`
- Quando houver retorno oficial da KB em `XPZ`, a atualização de `ObjetosDaKbEmXml` deve ocorrer depois, pelo fluxo de `xpz-sync`
- Tratar `ImportKBInformation`, `UpdateFile` e defaults internos de importação/exportação como sensíveis e dependentes da assinatura efetiva da task `Import`
- Tratar `ImportKbInformation` como tri-state na chamada e no wrapper: omitido ou `false` significam não emitir o atributo na task (omissão do atributo faz a task aplicar seu próprio default, documentado como `true` em `10-base-operacional-msbuild-headless.md`); apenas `true` emite e exige suporte na instalação atual. Quando o agente passar valor neutro (`false`) e a task não expuser a propriedade, o wrapper deve omitir o atributo, não bloquear; bloqueio por assinatura só vale para valor não neutro (`true`). O mesmo princípio se aplica a `UpdateFile`: omitido equivale a não emitir; valor não vazio em task sem suporte bloqueia.
- Não tratar bloqueio por assinatura da task como ajuste silencioso: quando preview ou import bloquear porque a task carregada não expõe propriedade sensível passada pelo agente ou pelo wrapper, é proibido repetir a chamada sem o parâmetro sem antes declarar nominalmente (1) qual propriedade ausente, (2) que o pacote não foi testado ou importado naquela rodada, (3) que a incompatibilidade é divergência de contrato operacional entre chamada/wrapper e assinatura efetiva da instalação, e (4) qual correção será aplicada — omitir parâmetro neutro, corrigir wrapper para omitir automaticamente quando não suportado, ou abortar a frente. Só depois dessa declaração explícita é admissível repetir a chamada com o parâmetro omitido, e nesse caso classificar a rodada como `chamada corrigida por parâmetro sensível omitido`.
- Normalizar recortes múltiplos de `IncludeItems` e `ExcludeItems` como lista antes de serializar para a task carregada
- Preservar `importedItems` como lista em qualquer diagnóstico JSON, mesmo quando houver apenas um item
- Declarar `importação real efetiva provada` apenas quando `importedItems` contiver explicitamente o objeto esperado; `exitCode=0` com `importedItems` ausente ou vazio classifica como `sucesso operacional sem prova de import efetivo` — nunca como import concluído
- Quando o `Invoke-GeneXusXpzImport.ps1` lançar exceção interna durante o pós-processamento (ex: `Exception calling Join`, falha de serialização do `import.json`, qualquer falha posterior à conclusão da task `Import` do MSBuild) mas o log bruto (`msbuild.stdout.log` ou stdout capturado) contiver `__IMPORTED_ITEM__` ou marca equivalente para o objeto esperado, classificar como `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — nunca como `falha operacional` nem como `sucesso operacional sem prova de import efetivo`; a importação real aconteceu de fato, o que falhou foi a montagem do diagnóstico estruturado pelo wrapper; declarar explicitamente que `importedItems` veio do log bruto e que o `import.json` está degradado ou ausente; registrar a exceção do wrapper como degradação de diagnóstico separada, não como causa de falha de import
- Quando a task carregada não expuser `UpdateFile` nem `ImportKBInformation` em valor não neutro solicitado pelo agente, o wrapper de preview deve bloquear esses parâmetros cedo, com `status` `preview bloqueado por assinatura da task`; valor neutro (omissão de `UpdateFile`, `ImportKbInformation=false`) deve ser tratado como não emissão e não disparar bloqueio
- Tratar `Get*Property` como operação de leitura segura, sem efeito sobre a KB
- Não usar o valor retornado por `GetVersionProperty -Name Name` como `-VersionName` em exportação ou importação; esse valor é o nome descritivo da versão (ex: `"Design"`), não o identificador aceito por `SetActiveVersion` (ex: `"wsEducacaoSpTeste"`); para obter o identificador compatível, usar `GetActiveVersion`
- Não usar o valor retornado por `GetEnvironmentProperty -Name Name` como `-EnvironmentName` pelo mesmo motivo; usar `GetActiveEnvironment` para obter o identificador ativo compatível
- Quando `SetActiveVersion` ou `SetActiveEnvironment` falhar, tratar como bloqueio operacional explícito: a versão ou o `Environment` solicitado não existe na KB. O diagnóstico deve orientar omitir `-VersionName` ou `-EnvironmentName` para usar o contexto ativo, quando esse for o objetivo.
- Validar `-Level` e `-Name` explicitamente antes de emitir a task; exigir `-Target`
  quando `-Level` for `Generator`, `DataStore` ou `Object`
- Nunca inferir o nome da propriedade; sempre exigir `-Name` explícito
- Quando recortes sucessivos isolarem erro residual de `Source`, `Specification` ou referência não resolvida em objeto importado, tratar a continuação como frente de conteúdo da KB/`XPZ`, não como ajuste adicional presumido do wrapper
- Quando o sintoma envolver código de evento GeneXus que parece não executar ou não surtir efeito, distinguir **antes de editar o source** os dois mecanismos documentados em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md), seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`: **(a) rejeição na importação** versus **(b) strip silencioso por eliminação de código morto (DCE)**. A ação corretiva é diferente em cada caso; não tratar (b) como falha de import nem (a) como bug de runtime/build.
- **Mecanismo (a):** se `exitCode != 0`, `errors` presentes no `import.json` de `Invoke-GeneXusXpzImport.ps1`, ou mensagem no log/stdout com `Unknown function '<nome>'` / código `src0294` (ou similar) apontando linha/coluna do evento, classificar como `importação real falhou por source` **e** registrar explicitamente que o padrão observado é rejeição na importação — função ou construção não exposta à camada de eventos GeneXus; o objeto **não** foi atualizado na KB. Ler a mensagem para identificar a função rejeitada; a correção é trocar a abordagem no source/XPZ, não reimportar o mesmo pacote nem investigar `.cs` gerado como causa primária.
- **`Transaction` `Rules` + `src0056`:** se a mensagem for `src0056: Missed ';' at the end of the rule` em `Transaction` `Rules`, **não** tratar como pontuação genérica — ver anti-padrão `transaction-rule-on-event-with-attribute-parameter` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) e Catálogo 1 em [xpz-builder/responsibilities-by-type/transaction.md](../xpz-builder/responsibilities-by-type/transaction.md). Antes de wirear reatividade per-attribute em rule declarativa de `Transaction`, consultar esse catálogo (escopo motor XPZ; gatilhos corretos GeneXus: skill **nexa**).
- **Mecanismo (b):** se import OK (`importação real efetiva provada` ou equivalente) mas o comportamento esperado do evento não aparece na UI, **não** classificar como falha de import nem presumir envelope/XML inválido; após build, buscar o handler no `.cs` gerado pelo nome do evento — zero ocorrências ou corpo vazio indica strip por DCE. Handoff para `xpz-msbuild-build` (inspeção do `.cs`) e para a seção canônica em `02`; a correção típica é tornar o corpo do evento observável ao gerador (ex.: operação opaca via proc externa), não ajustar wrapper de import.
- Quando um teste controlado com `Source` global preenchido e outro teste controlado com ajuste isolado de `Pattern Settings` não mudarem o padrão principal do log, registrar explicitamente que essas diferenças deixaram de ser suspeitas fortes e estreitar a hipótese para conteúdo da KB/`XPZ`
- Exigir confirmação explícita antes de importação real
- Recomendar reabertura da KB na IDE oficial após testes relevantes para observar warning, marca de versão ou outro efeito colateral
- Perguntas sobre conteúdo nominal de um XPZ — tanto em turnos posteriores da **mesma rodada** quanto em **sessões novas** sobre um `.xpz` já existente («por que X está aí?», «tem Y nesse pacote?», «quais atributos exatamente?», «quais Domains?») — exigem fonte autoritativa antes de responder. **Caminho A:** na mesma rodada, ou quando o `export.json` da rodada ainda estiver acessível, reler `package-inventory.json` via `packageInventory.nominalInventoryAt`, `packageInventory.packageInventoryPath` ou `artifacts.PackageInventoryPath`. **Caminho B:** em sessão nova, ou quando o sidecar daquela rodada não existir mais (ex.: diretório efêmero em `Temp` já removido), executar `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <xpz>` direto sobre o `.xpz`. `extrasSample`, `objectsByType` e contagens do `export.json` são resumo amostral ou agregado; memória de conversa anterior também é amostral; a fonte autoritativa do conteúdo nominal é o sidecar (caminho A) ou nova execução do motor de inventário (caminho B)
- **Export legado GeneXus 9 (perfil automático do inventário):** se o `.xpz`/XML for um `ExportFile` legado GeneXus 9 (`<GXObject><Elemento>` por nome, sem GUID de tipo), `Get-GeneXusImportPackageObjectInventory.ps1` detecta o perfil automaticamente e devolve `legacyFormatDetected=true`, itens `typeStatus="known-legacy"` (`type` = tipo moderno para `equivalent` ou `gxlegacy/<Elemento>` para `orphan`), `unknownTypeCount=0` e `unknownTypesDiscovery=[]` — **não** confundir esse `0`/`[]` com "zero tipos desconhecidos verificados" do fluxo moderno: o fail-closed de tag desconhecida vive no parser legado. Pacote **misto** (legado + moderno no mesmo `ExportFile`) é **BLOCK** (fail-closed). O contrato moderno de inventário (params, exit, shape de decisão) é inalterado. Regra operacional dona: `02-regras-operacionais-e-runtime.md`; representação: `01k-registro-elementos-legados.md`; materialização: `xpz-sync/SKILL.md` (seção EXPORTS LEGADOS)

---

## COMMUNICATION

- Responda no idioma do usuário
- Seja direto sobre estado operacional, riscos e limites
- Declare quando o resultado é apenas operacional e ainda depende de confirmação funcional
- Em operações de import, declare o sub-estado explicitamente pelo nome (`importação real efetiva provada`, `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)`, `sucesso operacional sem prova de import efetivo`, `importação real efetiva provada, efeito não confirmado na IDE`, `importação real efetiva provada, geração de runtime pendente`, `importação real falhou por source`, etc.) — não deixe o leitor inferir o nível de prova a partir do relato narrativo
- Quando o usuário quiser evidência complementar além de `importedItems`, apresentar as duas opções em paralelo: acionar `xpz-msbuild-build` (headless) ou abrir a KB na IDE e executar o build por lá — ambas são opcionais e o resultado do build não reescreve nem substitui o sub-estado de import já declarado
- Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado e o usuário reportar que o comportamento ainda não mudou, oferecer explicitamente a `checagem de frescor de runtime` como próximo passo nomeado antes de sugerir nova edição; declarar nominalmente o que será verificado no motor atual .NET: `nav_objs.xml` (`ObjStatus=genreq` é tratado como geração pendente pelo diagnóstico .NET; `ObjStatus=nogenreq` indica gerado) e timestamps dos artefatos gerados (`.cs`, `.aspx` ou equivalente); NVG excluído por não ser acessível sem abrir a IDE. Em KB `java-tomcat`, passar `-DeploymentHostingKind java-tomcat`: o Eixo C pula com `skipped-hosting-unsupported`/exit 0, e `ObjStatus` **não** deve ser usado isoladamente como critério de freshness Java. Se a checagem aplicável indicar artefatos de versão anterior, classificar como `importação real efetiva provada, geração de runtime pendente` e propor reabertura + rebuild antes de qualquer nova edição
- Quando import OK mas evento não reflete na UI ou no `.cs` gerado, declarar explicitamente que isso **não** reabre sub-estado de import — tratar como hipótese de **mecanismo (b)** e orientar inspeção pós-build do `.cs` ou handoff para `xpz-msbuild-build`, conforme seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md)
- Quando a rodada for `ensaio metodológico/experimental`, declarar isso nominalmente no resumo e separar:
  - objetivo metodológico da rodada
  - resultado operacional observado
  - confirmação funcional ainda não coberta
- Quando a rodada envolver iteração sobre objeto único, consolidar o resultado no seguinte template antes de recomendar próximo passo:

  ```
  Rodada N — <NomeDoObjeto> (<TipoObjeto>)
  - XML local atualizado: sim / não
  - XML bem-formado: sim / não
  - Sanity: limpo / warnings / bloqueante
  - Preview: reconhecido / não reconhecido / não executado
  - Import real: <sub-estado nomeado>
  - Warnings conhecidos: <lista ou "nenhum">
  ```

- Quando houver ambiguidade de contexto, interrompa a execução e peça definição explícita
- Não use linguagem otimista para sugerir segurança que ainda não foi validada empiricamente
- Quando a exportação headless gerar um `.xpz` para alimentar a pasta paralela da KB, declarar explicitamente o marco `XPZ gerado`
- Se a geração do `.xpz` fizer parte do caminho `B` do setup inicial, diferenciar explicitamente a fase `exportação headless concluída` da fase posterior `materialização em ObjetosDaKbEmXml`
- Se o pedido do usuário for apenas gerar o `.xpz`, parar no artefato gerado; só prosseguir para materialização quando o pedido for seguir com o setup ou com a materialização
- Em exportação seletiva com `-ObjectList`, a presença de `-ObjectList` classifica a rodada como **seletiva/cirúrgica** para fins de sub-estado e de confronto de extras; **nunca** reportar ao usuário a contagem de entradas de `-ObjectList` como se fosse a contagem do pacote — a contagem comunicada é sempre a **real** do `.xpz` (`packageInventory.totalObjects` / `totalAttributes` e `objectsByType`, ou inspeção manual equivalente)
- Em exportação seletiva/cirúrgica cujo objetivo declarado seja obter somente os itens de `-ObjectList`, passar `-DependencyType "None" -ReferenceType "None"` por padrão operacional; isso previne o arrasto na origem e **não substitui** o inventário pós-export. Se o usuário pedir dependências/referências, declarar que a rodada deixou de ser pacote estritamente nominal antes de executar e continuar exigindo inventário completo.
- Quando `export.json` trouxer `packageInventory`, reproduzir no relatório ao usuário **antes** de declarar o XPZ como conclusão limpa: totais reais, `objectsByType`, `systemObjectsPresent`, `attributesTopLevelUnreconciled` / `inventoryWarnings` quando existirem; em export seletiva com `extrasCount > 0`, listar **todos** os extras do bloco `<Objects>` por nome (`Tipo:Nome`) — com `extrasCount <= 50` podem estar em `extrasSample`; com `extrasSampleTruncated=true` ou para lista nominal completa abrir `nominalInventoryAt` / `extrasFullListAt` / `packageInventoryPath` / `artifacts.PackageInventoryPath` e ler `package-inventory.json`; com `attributesTopLevelUnreconciled=true`, listar **cada** atributo top-level do bloco `<Attributes>` por nome (não só `totalAttributes`); `extrasSample` cobre somente extras de objeto no resumo JSON e **não** substitui a comunicação nominal completa do pacote ao humano — não basta o campo existir só no JSON; quando `exportErrors`, `invalidTypesRejected` ou `knownStdOutNoise` (top-level) estiverem presentes, reproduzi-los também no texto ao usuário

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|-----------|-----------------|
| [README.md](../README.md) | Sempre - regras editoriais e posicionamento da base |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais, precedência e restrições da trilha XPZ; carregar também quando import falhar em código de evento (`Unknown function`/`src0294`) ou quando import OK mas evento não aparecer no `.cs`/UI (mecanismos de descarte do gerador) |
| [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) | Sempre - base operacional, riscos conhecidos e interface vigente |
| [xpz-msbuild-build/SKILL.md](../xpz-msbuild-build/SKILL.md) | Handoff quando import OK mas evento não aparece no `.cs`/UI (mecanismo b), quando o usuário pedir build/specify como evidencia complementar, ou para checagem de frescor de runtime após import — sem reabrir sub-estado de import |

---

## EXPECTED INTERFACE

Esta skill assume, como interface operacional, scripts pequenos e explicitamente parametrizados. `Test-GeneXusMsBuildSetup.ps1`, `Open-GeneXusKbHeadless.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzImportThenBuild.ps1`, `Read-MsBuildImportSignals.ps1`, `Test-MsBuildImportSignalsClassifier.ps1`, `Extract-XpzObject.ps1`, `Get-GeneXusObjectSummary.ps1`, `Compare-GeneXusPanelShape.ps1`, `Test-GeneXusKbConsistency.ps1`, `Test-GeneXusImportFileEnvelope.ps1`, `Get-GeneXusImportPackageObjectInventory.ps1`, `GeneXusMsBuildWatcherSupport.ps1`, `Watch-GeneXusMsBuildLog.ps1`, `Resolve-GeneXusGeneratedCsPath.ps1` e `Test-GeneXusRuntimeFreshness.ps1` já foram materializados nesta fase; os demais não devem ser tratados como já implementados sem confirmação explícita. Os motores de montagem de `import_file.xml` referenciados no fluxo preferido (`Build-GeneXusImportFileEnvelope.ps1` para montagem direta a partir de XMLs de objeto e template clonável, `New-XpzImportPackage.ps1` como wrapper PowerShell seguro do motor interno Python `New-XpzImportPackage.py` para montagem por frente da pasta paralela) também estão materializados em `scripts/` e são cobertos pela skill `xpz-builder` e pelas regras operacionais em `02-regras-operacionais-e-runtime.md`; quando esta skill aponta para eles (anti-padrão de export-casca, inventário pré-import), trata-se de uso operacional vigente, não de promessa aspiracional. Ao usar `Build-GeneXusImportFileEnvelope.ps1`, `-AcervoPath <ObjetosDaKbEmXml>` é obrigatório; o motor bloqueia antes da gravação quando houver `lastUpdate` inválido contra o acervo ou `Object/@type` divergente por mesmo `guid`, preservando o bloco `frontObjectTypeDrift` com `objectGuid` normalizado, `acervoPath`/`candidateAcervoPaths` e `message`; objetos realmente modificados devem ser declarados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids` para acionar o bloqueio mecânico de `lastUpdate` velho, igual ao acervo ou futuro sem justificativa.

Estado atual da materialização:

- `Test-GeneXusMsBuildSetup.ps1`: implementado como probe (sondagem técnica inicial) não invasivo
- `Open-GeneXusKbHeadless.ps1`: implementado para abertura e fechamento controlados da KB, com contexto ativo e sem import/export
- `Test-GeneXusXpzImportPreview.ps1`: implementado para `PreviewMode` de importação e já validado nesta conversa com XPZ real
- `Invoke-GeneXusXpzExport.ps1`: implementado para exportação headless de XPZ com parâmetros explícitos e diagnóstico JSON
- `Invoke-GeneXusXpzImport.ps1`: implementado para importação real de XPZ com parâmetros explícitos e diagnóstico JSON
- `Invoke-GeneXusXpzImportThenBuild.ps1`: implementado como wrapper integrador de import real seguido de `BuildAll` pós-import; executa o build somente quando o JSON de import está apto (`exitCode=0`, sem `blockingReasons`, sem `msBuildCategoryBBlocked` e sem status de falha/bloqueio); parâmetros de build amplo/caro continuam sujeitos aos gates do wrapper receptor (`-ForceRebuild` exige `-AllowWideRebuild`, `CompileMains=true` ou `DetailedNavigation=true` exigem `-AllowCostlyBuildOptions`, com confirmações explícitas quando aplicável)
- `Read-MsBuildImportSignals.ps1`: implementado para leitura compacta de `msbuild.stdout.log`/`msbuild.stderr.log`, com `importedItems`, `expectedItemsRaw`/`importedItemsRaw`, `expectedItemsCanonical`/`importedItemsCanonical`, `itemAliasMatches`, warnings, erros, ruídos conhecidos de stdout, `gxImportLogReadStatus`/`gxImportLogReadError`, versão/Environment ativos, sucesso da task Import e warnings de layout agrupados por Panel
- `Test-MsBuildImportSignalsClassifier.ps1`: implementado como bateria mínima de validação do leitor compacto (ruído conhecido de `CssProperties.json`, lock de `GxImport.log`, equivalência `Panel`/`SDPanel` em `itemAliasMatches`); ver também `09-inventario-e-rastreabilidade-publica.md`
- `Extract-XpzObject.ps1`: implementado para extrair um objeto específico de XML/XPZ ou retornar resumo JSON sem imprimir o pacote inteiro
- `Get-GeneXusObjectSummary.ps1`: implementado para resumir objeto GeneXus e, para Panel, expor shape compacto de level/layout, controles, gridData, actions, eventos serializados em `detail/@events`, `actionEventCoverage`, `namedEventNames`, `standardEventNames`, `variableEventNames` e `tapEventNames`, e, para WebPanel classico, o bloco `webpanel` (tables com `tableType` Flex/Responsive e `depth`, controls, buttons em `<action>` e `<ucw>` Button, eventNames, coverage), sem despejar CDATA
- `Compare-GeneXusPanelShape.ps1`: implementado para comparar dois Panels por shape compacto, incluindo Object attrs, Pattern/Data version, level/layout, controles, eventos serializados classificados (`namedEventNames`, `standardEventNames`, `variableEventNames`, `tapEventNames`) e cobertura action/event
- `Test-GeneXusKbConsistency.ps1`: implementado como wrapper de `CheckKnowledgeBase` com diagnóstico JSON, classificação das categorias empíricas documentadas e confirmação interativa obrigatória para `Fix="true"`
- `Test-GeneXusImportFileEnvelope.ps1`: implementado para validação estrutural estática do `import_file.xml` antes de qualquer chamada ao MSBuild; não invasivo, não abre KB
- `Get-GeneXusImportPackageObjectInventory.ps1`: inventário determinístico de `import_file.xml`, XML com raiz `<ExportFile>` ou `.xpz` (XML interno único); lista `<Object>` sob `<Objects>`, `Attribute` top-level sob `<Attributes>`, agrega `objectsByType`, detecta objetos de plataforma/SDK via `scripts/gx-platform-objects.json` (`Get-SystemObjectsPresent` → `systemObjectsPresent`), sinal `attributes-top-level-em-export-cirurgico` em export seletiva sem `Transaction` na lista declarada, e confronta delta declarado (`-DeclaredDeltaPath` ou `-DeclaredDeltaItems` no formato `Tipo:Nome`, separador `;` ou linha)
- `Invoke-GeneXusXpzExport.ps1`: após exportação com XPZ gerado, embute `packageInventory` resumido no diagnóstico e grava sempre `package-inventory.json` completo no diretório de artefatos da rodada; o resumo expõe `nominalInventoryAt` (lista nominal completa no sidecar) sempre que o sidecar for gravado; `extrasSample` (extras de `<Objects>` quando `extrasCount ≤ 50`), `extrasSampleTruncated` quando `extrasCount > 50` (omissão de `extrasSample` no resumo); em export seletiva com confronto de delta, `extrasFullListAt` aponta para o mesmo sidecar (lista completa de extras de `<Objects>`); atributos top-level **não** entram em `extrasSample`; falha de inventário marca `inventoryDegraded=true` sem rebaixar `exitCode` da task MSBuild; regressão mínima do contrato resumido: `scripts/Test-GeneXusPackageInventorySupportSelfTest.ps1` (sentinela `GENEXUS_PACKAGE_INVENTORY_SUPPORT_SELFTEST_OK`)
- `GeneXusMsBuildWatcherSupport.ps1`: implementado como helper comum do contrato de watcher dos wrappers MSBuild; centraliza `-StartWatcher`, `-MonitorLogPath`, `watcherContext`, `timing.phases` e leitura do log do monitor
- `Watch-GeneXusMsBuildLog.ps1`: implementado como monitor incremental de execução headless; usar em preview/import/export grandes para acompanhar o MSBuild sem depender do chat; em importação real de pacote amplo ou com muitos `WorkWithForWeb`, usar watcher como padrão operacional recomendado
- `Resolve-GeneXusGeneratedCsPath.ps1`: implementado como resolvedor somente leitura do `.cs` gerado a partir de `kb_environment_web_dirs` em `kb-source-metadata.md`; usar antes de `Test-GeneXusRuntimeFreshness.ps1` quando a checagem exigir `-GeneratorOutputPath`; exceção Fase 2 (guarda de família do Eixo B): KB `java-tomcat`/família não-.NET pula com `CS_PATH_SKIPPED_HOSTING_UNSUPPORTED`/exit 0, sem exigir `web_dirs` (o artefato Java não é `.cs`)
- `Test-GeneXusRuntimeFreshness.ps1`: implementado como diagnóstico somente leitura de frescor de runtime; usar quando o sub-estado for `importação real efetiva provada, geração de runtime pendente` para confirmar se artefatos de runtime já refletem a versão importada

Scripts nesta frente:

- `Test-GeneXusMsBuildSetup.ps1`
  - status atual: implementado como probe (sondagem técnica inicial) não invasivo
  - descoberta de `MsBuildPath` quando omitido: `vswhere.exe` e catálogo estático em `scripts/GeneXusMsBuildPathContract.ps1`; JSON inclui `msBuildProbe` (`resolutionSource`, `vsWhere`, `candidates[]`)
- `Test-GeneXusMsBuildDiscoveryContract.ps1`
  - status atual: implementado; regressão mínima do catálogo de candidatos MSBuild (não substitui probe real com GeneXus/VS instalados)
- `Open-GeneXusKbHeadless.ps1`
  - status atual: implementado para abertura e fechamento controlados da KB
  - saída esperada: `status`, `summary`, `exitCode`, `executionEvidence`, `stage`, `requestedContext`, `observedContext`, `artifacts`, `stderrContent`, `blockingReasons`, `warnings`, `strategyTrace`, `msBuildExitCode` top-level como compatibilidade transitória quando existir, e caminhos dos logs
- `Test-GeneXusXpzImportPreview.ps1`
  - status atual: implementado para `PreviewMode` sem importação real, com `IncludeItems` e `ExcludeItems` validados nesta instalação
  - contrato de resiliência do pós-processamento: o bloco que faz parse do stdout, monta `importedItems` e serializa o diagnóstico JSON deve ser envolvido em `try/catch`; em caso de exceção interna (ex: `Exception calling Join` por entrada inesperada, falha de serialização, qualquer erro posterior à conclusão da task `Import` do MSBuild em modo preview), o script não deve perder a evidência já coletada — deve emitir um diagnóstico parcial contendo no mínimo: `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, caminho do `msbuild.stdout.log`, lista de marcas `__IMPORTED_ITEM__` extraídas diretamente do log bruto antes da exceção (quando disponível), marca explícita `postProcessingFailed=true`, `diagnosticDegraded=true`, mensagem da exceção e indicação de que `importedItems` deve ser confirmado por leitura do log bruto; quando `executionEvidence.msBuildExitCode=0` e o preview não tiver alterado a KB, o status emitido é `preview apenas com falha no pos-processamento` e o sub-estado equivalente é `preview concluído sem alterar a KB (falha no pós-processamento do wrapper)` — não é `falha operacional`; nunca substituir `executionEvidence.msBuildExitCode` por código de exceção do PowerShell, nem rebaixar o `exitCode` classificado — ambos são evidência primária de que a task de import em modo preview concluiu
  - contrato de sinais compactos: após o MSBuild, o wrapper deve gravar `msbuild.import.signals.json` ao lado dos logs brutos sempre que possível, consumindo `Read-MsBuildImportSignals.ps1`; quando a leitura compacta conseguir executar, o diagnóstico JSON também deve embutir o objeto parseado em `compactSignals`; falha nessa leitura degrada o diagnóstico, mas não reclassifica a task Import como falha operacional quando `executionEvidence.msBuildExitCode` e stdout indicarem conclusão
- `Invoke-GeneXusXpzExport.ps1`
  - status atual: implementado para exportação headless de XPZ com parâmetros explícitos e validação da task carregada
  - contrato de resiliência do pós-processamento: o bloco que faz parse do stdout, lê `__EXPORTED_FILE__`, `__OPEN_OUTPUT__`, `GetActiveVersion`, `GetActiveEnvironment` e `gxWarnings`, e serializa o diagnóstico JSON deve ser envolvido em `try/catch`; em caso de exceção interna (ex: `Exception calling Join` por entrada inesperada, falha de serialização, qualquer erro posterior à conclusão da task `Export` do MSBuild), o script não deve perder a evidência já coletada — deve emitir um diagnóstico parcial contendo no mínimo: `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, caminho do `msbuild.stdout.log`, valor do marcador `__EXPORTED_FILE__` quando o stdout já estiver lido, marca explícita `postProcessingFailed=true`, mensagem da exceção e indicação de que o caminho do XPZ exportado deve ser confirmado por existência do arquivo e leitura do log bruto; quando `executionEvidence.msBuildExitCode=0` e o arquivo XPZ existir, o status emitido é `sucesso operacional com falha no pos-processamento` e o sub-estado equivalente é `exportação headless concluída e XPZ gerado (falha no pós-processamento do wrapper)` — não é `falha operacional`; nunca substituir `executionEvidence.msBuildExitCode` por código de exceção do PowerShell, nem rebaixar o `exitCode` classificado — ambos são evidência primária de que a task de export concluiu
- `Invoke-GeneXusXpzImport.ps1`
  - status atual: implementado para importação real de XPZ com parâmetros explícitos e diagnóstico JSON
  - contrato de resiliência do pós-processamento: o bloco que faz parse do stdout, monta `importedItems` e serializa o diagnóstico JSON deve ser envolvido em `try/catch`; em caso de exceção interna (ex: `Exception calling Join` por entrada inesperada, falha de serialização, qualquer erro posterior à conclusão da task `Import` do MSBuild), o script não deve perder a evidência já coletada — deve emitir um diagnóstico parcial contendo no mínimo: `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, caminho do `msbuild.stdout.log`, lista de marcas `__IMPORTED_ITEM__` extraídas diretamente do log bruto antes da exceção (quando disponível), marca explícita `postProcessingFailed=true`, `diagnosticDegraded=true`, mensagem da exceção e indicação de que `importedItems` deve ser confirmado por leitura do log bruto; o agente que consumir esse diagnóstico parcial aplica o sub-estado `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` quando o log bruto contiver evidência do objeto esperado, conforme regra em RESPONSIBILITIES; nunca substituir `executionEvidence.msBuildExitCode` por código de exceção do PowerShell, nem rebaixar o `exitCode` classificado — ambos são evidência primária de que a task de import concluiu
  - contrato de sinais compactos: após o MSBuild, o wrapper deve gravar `msbuild.import.signals.json` ao lado dos logs brutos sempre que possível, consumindo `Read-MsBuildImportSignals.ps1`; quando a leitura compacta conseguir executar, o diagnóstico JSON também deve embutir o objeto parseado em `compactSignals`; `importedItems` pode ser preenchido a partir desses sinais quando a montagem principal vier vazia por degradação do diagnóstico
- `Invoke-GeneXusXpzImportThenBuild.ps1`
  - status atual: implementado para encadear import real e `BuildAll` pós-import com parada condicional
  - saída esperada: JSON único com `status`/`roundtripStatus`, `summary`, `exitCode`, `importJson`, `buildJson`, `importReadyForBuild`, `buildSkippedReason`, `importProcess`, `buildProcess`, `resolvedPaths`, `artifacts`, `blockingReasons`, `warnings` e `strategyTrace`
  - regra de segurança: se `Invoke-GeneXusXpzImport.ps1` falhar, bloquear, produzir Categoria B, não gravar JSON interpretável ou retornar `status` de falha/bloqueio, `Invoke-GeneXusKbBuildAll.ps1` não é chamado; reportar `buildJson=null` e explicar em `buildSkippedReason`
  - gates de build propagados: `-AllowWideRebuild`/`-ConfirmWideRebuild`, `-AllowCostlyBuildOptions`/`-ConfirmCostlyBuildOptions` e `-AllowReorg`/`-ConfirmReorg` são apenas repassados ao `Invoke-GeneXusKbBuildAll.ps1`; a autorização humana e as frases exatas continuam sendo responsabilidade do chamador conforme `xpz-msbuild-build`
  - flags de validação de deploy bin propagadas: `-PostImportDeployValidation`, `-StrictDeployBinCheck` e `-SkipDeployBinCheck` também são apenas repassadas ao `Invoke-GeneXusKbBuildAll.ps1` (checagem de publicação no destino do environment — `web\bin` no .NET; para `java-tomcat`, co-gate Java no `WEB-INF\classes` externo — gate com exit **49** quando ativo) — categoria **distinta** dos gates de autorização acima: são opções de validação, **não** têm frase exata nem par `-Confirm*` e não exigem autorização humana; contrato do gate em `xpz-msbuild-build`
- `Read-MsBuildImportSignals.ps1`
  - status atual: implementado
  - objetivo: ler logs brutos de preview/import sem despejar CDATA ou stdout inteiro na conversa
  - parâmetros: `-Path` (diretório de artefatos ou stdout), `-StdOutPath`, `-StdErrPath`, `-ExpectedItems`, `-Stage`, `-OutputPath`, `-AsJson`
  - saída esperada: `importedItems`, `expectedItemsRaw`/`importedItemsRaw`, `expectedItemsCanonical`/`importedItemsCanonical`, `itemAliasMatches`, `warnings`, `errors`, `knownStdOutNoise`, `gxImportLogReadStatus`/`gxImportLogReadError`, `diagnosticDegraded`, `activeVersion`, `activeEnvironment`, `importTaskSuccess`, `layoutWarnings` agrupados por Panel e contadores compactos
  - `knownStdOutNoise` deve registrar mensagens conhecidas de ambiente no stdout sem promovê-las a erro; o caso `cssproperties-access-denied` cobre `O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado.`, quando a rodada também preserva evidência de sucesso (`Bem sucedido`, `Import Task Sucesso` ou marcador equivalente)
- `Test-MsBuildImportSignalsClassifier.ps1`
  - status atual: implementado
  - objetivo: validar extração/classificação de `Read-MsBuildImportSignals.ps1` sem abrir KB
  - uso típico: regressão local após mudança no leitor compacto ou nos wrappers de preview/import
- `Extract-XpzObject.ps1`, `Get-GeneXusObjectSummary.ps1`, `Compare-GeneXusPanelShape.ps1`
  - status atual: implementados
  - objetivo: evitar despejo de XML/XPZ ou CDATA gigante durante triagem de pacote, diagnóstico de Panel e comparação de shape
  - uso típico: extrair um único objeto por nome/tipo, resumir `Part`/identidade/shape e comparar Panels exportados pela IDE contra Panels gerados localmente
- `Test-GeneXusKbConsistency.ps1`
  - status atual: implementado; classifica KB consistente, inconsistências detectadas, check parcial por timeout da Etapa 3 e KB inacessível; `Fix="true"` exige confirmação interativa
- `Test-GeneXusImportFileEnvelope.ps1`
  - status atual: implementado
  - runtime: executar em `pwsh` 7.4 ou superior; o script declara `#requires -Version 7.4` e Windows PowerShell 5.1 não é runtime suportado
  - objetivo: validação estrutural estática do `import_file.xml` antes de qualquer chamada ao MSBuild; não invasivo, não abre KB, não requer GeneXus instalado
  - parâmetros obrigatórios: `-InputPath` (caminho do `import_file.xml`)
  - parâmetros opcionais: `-PanelReferencePath` (objeto ou pacote XML/XPZ comparável usado para confirmar par `level id`/`layout id` em Panel)
  - saída esperada: `status` (`apto para prosseguir` | `apto com ressalvas` | `não apto para prosseguir`), `checks` (mapa de verificações individuais), `objectCount`, `blockingReasons`, `warnings`, `information`
  - verificações realizadas: XML bem-formado; raiz `<ExportFile>`; blocos obrigatórios `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`; ausência de declaração XML interna dentro de `<Objects>`; ausência de texto solto ou placeholder literal em `<Objects>`; GUIDs válidos por objeto; `Source/@kb` e `Source/Version/@guid` em formato GUID
  - regra Panel: sem `-PanelReferencePath`, Panel retorna `panel-level-layout-unverified` como ressalva; com referência que contenha o mesmo par, retorna `panel-level-layout-confirmed` apenas em `information`; referência informada sem par correspondente retorna `panel-level-layout-suspicious`
  - regra cross-KB: formato GUID valido não basta para import headless; quando houver KB nativa local esperada, `Source/@kb` do pacote/template deve corresponder a essa KB. Divergencia indica pacote de outra KB e bloqueia automacao por agente; encaminhar para avaliacao/importacao manual pela IDE, conforme `02-regras-operacionais-e-runtime.md`.
- `Get-GeneXusImportPackageObjectInventory.ps1`
  - status atual: implementado para `import_file.xml`, XML com raiz `<ExportFile>` ou `.xpz` (XML interno único)
  - objetivo: inventariar o conteúdo efetivo do pacote antes de preview/import, separando `Objects`, `Attributes` top-level, tipos mapeados, GUIDs e confronto opcional com delta declarado
  - parâmetros obrigatórios: `-InputPath` (`import_file.xml`, XML equivalente ou `.xpz`)
  - parâmetros opcionais: `-DeclaredDeltaPath`, `-DeclaredDeltaItems`, `-FailOnDeltaMismatch`, `-CatalogPath`, `-SystemModulesCatalogPath`, `-SystemExternalObjectsCatalogPath`
  - quando o pacote cotidiano já é `import_file.xml`, não fabricar `.xpz` só para validar — chamar o motor direto sobre o `import_file.xml`
- `Watch-GeneXusMsBuildLog.ps1`
  - status atual: implementado
  - objetivo: monitorar incrementalmente o log de uma execução headless em andamento; encerra sozinho quando o processo termina; usar especialmente em importações de KB grande onde o invocador pode encerrar por timeout antes do MSBuild concluir
  - parâmetros obrigatórios: `-Pid`, `-LogPath`
  - parâmetros opcionais: `-MonitorLog`, `-IntervalSeconds` (default 5), `-SilenceThresholdSeconds` (default 120)
- `GeneXusMsBuildWatcherSupport.ps1`
  - status atual: implementado
  - objetivo: helper comum para os wrappers MSBuild dispararem o watcher e registrarem `watcherContext`/`timing.phases` com o mesmo contrato
- `Test-GeneXusRuntimeFreshness.ps1`
  - status atual: implementado
  - objetivo: diagnosticar se o runtime GeneXus reflete a versão mais recente de um objeto após import+build; somente leitura, não abre KB, não invoca MSBuild
  - parâmetros obrigatórios: `-KbPath`, `-ObjectName`, `-ImportedAt`
  - parâmetros opcionais: `-ObjectType` (reservado para uso futuro), `-GeneratorOutputPath` (se omitido, deriva como `<KbPath>\CSharpModel\web`), `-DeploymentHostingKind` (guarda de família do Eixo C; opcional — `java-tomcat` Eixo C `runtimeSupportState=recognized-no-engine`, Pós-v1), `-AsJson`
  - saída esperada: `runtime-fresh` (nogenreq + artefatos posteriores ao import, no motor .NET), `runtime-stale` (genreq ou artefatos anteriores, no motor .NET), `runtime-unknown` (objeto não encontrado em `nav_objs.xml` ou artefatos não localizados), `skipped-hosting-unsupported` (Fase 2 — quando `-DeploymentHostingKind` é `java-tomcat`/família não-.NET: pula sem derivar `CSharpModel\web`, exit 0; valor fora do registro → `runtime-hosting-kind-invalido`, exit não-zero; `ObjStatus` não é critério isolado de freshness Java)
- `Get-GeneXusKbProperty.ps1`
  - status atual: implementado
  - objetivo: leitura de propriedade em qualquer nível da KB sem alterar nenhum dado
  - parâmetros obrigatórios: `-KbPath`, `-Level` (KB | Version | Environment | Generator | DataStore | Object), `-Name`, `-WorkingDirectory`, `-LogPath`
  - parâmetros opcionais: `-Target` (obrigatório quando `-Level` for `Generator`, `DataStore` ou `Object`; nome do generator, datastore ou objeto), `-GeneXusDir`, `-MsBuildPath`, `-VersionName`, `-EnvironmentName`, `-VerboseLog`
  - saída esperada: `status` (`leitura concluída` | `falha de leitura`), `level`, `target` (quando aplicável), `propertyName`, `propertyValue`, `exitCode`, `executionEvidence`, `blockingReasons`, `warnings`, `strategyTrace`, `msBuildExitCode` top-level como compatibilidade transitória quando existir, e caminho do log
  - tasks confirmadas no assembly: `GetKnowledgeBaseProperty`, `GetVersionProperty`, `GetEnvironmentProperty`, `GetGeneratorProperty` (parâmetro opcional `Generator`), `GetDataStoreProperty` (parâmetro opcional `DataStore`), `GetObjectProperty` (parâmetro `Object` obrigatório); todas expõem `Name` e `PropertyValue` como interface comum
  - incompatibilidade conhecida e verificada empiricamente: `GetVersionProperty -Name Name` retorna o nome descritivo da versão (ex: `"Design"`), não o identificador aceito por `SetActiveVersion` (ex: `"wsEducacaoSpTeste"`); `GetEnvironmentProperty -Name Name` tem a mesma incompatibilidade com `SetActiveEnvironment`; para obter o identificador compatível com essas tasks de posicionamento, usar `GetActiveVersion` e `GetActiveEnvironment`

Contrato inicial específico de `Test-GeneXusMsBuildSetup.ps1`:

- obrigatórios: `-WorkingDirectory`, `-LogPath`
- opcionais: `-GeneXusDir`, `-MsBuildPath`, `-KbPath`, `-VerboseLog`
- regra de contrato: `-WorkingDirectory` continua explícito; quando o caminho seguro ainda não existir, o probe pode criar exatamente essa pasta e registrar isso no diagnóstico
- descoberta de `MsBuildPath` quando omitido: `vswhere.exe` (`-all -sort`, componente MSBuild, `Current\Bin` antes de `amd64`) e, em seguida, catálogo estático em `scripts/GeneXusMsBuildPathContract.ps1` (Visual Studio 18/2022/2019, `Program Files` e `Program Files (x86)`); detalhes e exemplo JSON em `10-base-operacional-msbuild-headless.md`
- saída JSON do probe inclui `msBuildProbe` (`resolutionSource`, `vsWhere`, `candidates[]` com `path`/`source`/`exists`/`selected`) além de `strategyTrace`
- regressão mínima do catálogo (sem substituir probe real): `scripts/Test-GeneXusMsBuildDiscoveryContract.ps1`
- códigos de saída contratuais:
  - `0` para `apto para prosseguir`
  - `10` a `16` para bloqueios operacionais esperados com diagnóstico estruturado
  - `90` para falha interna do script antes de diagnóstico completo

Parâmetros transversais esperados:

- `-KbPath`
- `-GeneXusDir`
- `-MsBuildPath`
- `-VersionName`
- `-EnvironmentName`
- `-WorkingDirectory`
- `-LogPath` (caminho de **arquivo** de log onde o wrapper grava o JSON de resultado; apontar para um **diretório existente** é bloqueado cedo com **exit 50** — gate fail-fast `parametro-invalido`, antes de abrir a KB; motor `scripts/GeneXusMsBuildLogPathSupport.ps1`)
- `-VerboseLog`
- `-StartWatcher` (quando suportado pelo wrapper, dispara `Watch-GeneXusMsBuildLog.ps1` antes do MSBuild; requer `-MonitorLogPath`; ausência de `-MonitorLogPath` deve bloquear cedo por política com exit 46)
- `-MonitorLogPath` (caminho do log próprio do watcher; quando existir, alimenta `timing.phases`)
- `-WatcherIntervalSeconds` (default 5; intervalo válido: 1-60)
- `-WatcherSilenceThresholdSeconds` (default 120; intervalo válido: 30-3600)

O contrato de watcher acima vale para `Test-GeneXusXpzImportPreview.ps1`,
`Invoke-GeneXusXpzExport.ps1` e `Invoke-GeneXusXpzImport.ps1`. Ele é centralizado em
`scripts/GeneXusMsBuildWatcherSupport.ps1`; ao evoluir watcher, timing ou
`watcherContext`, manter o helper comum como sede da regra e evitar lógica divergente
dentro dos wrappers.

Parâmetros específicos de exportação:

- `-XpzPath`
- `-ObjectList` (nome canônico da seleção por nome; sinônimo aceito `-ObjectNames`; tipo `[string[]]`, aceita string única com lista ou array) — lista de objetos para exportação seletiva; para múltiplos objetos, separar entradas com ponto-e-vírgula (`;`) no formato `Tipo:Nome`; exemplo: `Procedure:ProcA;WebPanel:WPB;Transaction:TrC`; o prefixo `Tipo` deve ser o **rótulo aceito pela task Export**, não necessariamente o nome do tipo no catálogo interno nem o retorno de KbIntelligence — ver [10a-gx-export-task-labels.md](../10a-gx-export-task-labels.md) e `exportTaskLabel` em `scripts/gx-object-type-catalog.json` quando montar lista a partir do índice ou do catálogo; a presença de `-ObjectList` classifica a rodada como **exportação seletiva/cirúrgica** para confronto de extras; após a exportação, seguir a secção **Inventário do pacote após export seletivo** (`packageInventory` no `export.json` + `package-inventory.json`); **nunca** reportar ao usuário a contagem de entradas da lista como contagem do pacote; quando exportar um único objeto, o formato `Tipo:Nome` continua válido sem separador
- `-ParallelKbRoot` / `-IndexPath` / `-CatalogOverridePath` — **obrigatórios** em export seletivo (`-ObjectList` sem `-ExportAll`/full): o wrapper consulta `KbIntelligence` antes do MSBuild (`objectListPreflight` no `export.json`, `gateContext=export`). Homônimo ou índice ausente/inválido → **exit 35** (estágio `pre-export-identity`). Objeto ausente no índice mas possivelmente só na KB nativa → **aviso** e segue MSBuild; inventário pós-export continua obrigatório. Em sessão na pasta paralela da KB, passar a raiz da sessão em `-ParallelKbRoot`.
- `-DependencyType` — em export seletivo/cirúrgico que deve conter somente a lista nominal, usar `"None"`; valores além de `None` e o default formal quando omitido permanecem pendentes de confirmação nesta base
- `-ReferenceType` — em export seletivo/cirúrgico que deve conter somente a lista nominal, usar `"None"`; valores além de `None` e o default formal quando omitido permanecem pendentes de confirmação nesta base
- `-ExportKbInfo`
- `-ExportAll`

Parâmetros específicos de importação:

- `-InputPath` — nome canônico da entrada primária (aliases retrocompatíveis `-XpzPath` e `-Path`); aceita `.xpz` (formato compactado padrão GeneXus), `.xml` ou `.import_file.xml` (envelope GeneXus com raiz `<ExportFile>`) como insumo válido para preview e import real, desde que o envelope tenha sido validado por `Test-GeneXusImportFileEnvelope.ps1` na mesma rodada; a extensão aceita não é restringida pelo nome do parâmetro
- `-PreviewMode`
- `-UpdateFilePath`
- `-IncludeItems` — recorte seletivo no formato `Tipo:Nome` (separador `;`, `,` ou linha); classifica a rodada como import seletivo para `objectListPreflight`
- `-ExcludeItems`
- `-ParallelKbRoot` / `-IndexPath` / `-CatalogOverridePath` — **obrigatórios** quando `-IncludeItems` estiver preenchido: pré-validação no índice antes do MSBuild (`objectListPreflight` no `import.json` ou preview, `gateContext=import`, estágio `pre-import-identity`). Homônimo ou índice ausente/inválido → **exit 35**; `not_in_index` → aviso e segue; inventário do pacote (passo 6c) continua obrigatório antes de import real
- `-AutomaticBackup`
- `-ImportType`
- `-ImportKbInformation` — tri-state: omitido ou `false` significam não emitir o atributo na task Import (omissão do atributo faz a task aplicar seu próprio default, documentado como `true` em `10-base-operacional-msbuild-headless.md`); apenas `true` emite o atributo e exige que a task carregada exponha a propriedade. Bloqueio por assinatura só ocorre quando o valor for `true` em instalação sem suporte; `false` é tratado como omissão tanto no preview quanto no import real

---

## INVENTÁRIO DO PACOTE ANTES DO IMPORT REAL

- O gate `Test-GeneXusImportFileEnvelope.ps1` valida estrutura do envelope; **não substitui** a verificação do **conjunto de objetos** que efetivamente seria aplicado à KB na importação.
- Use `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <import_file.xml ou .xpz>` como inventário determinístico preferido. Para confronto com lista esperada, use `-DeclaredDeltaPath <arquivo>` ou `-DeclaredDeltaItems "<lista Tipo:Nome separada por ; ou linha>"`. Para bloquear automaticamente divergência, acrescente `-FailOnDeltaMismatch`.
- **Checklist obrigatório** antes de **importação real** quando o pacote **não** foi montado na mesma rodada pelo fluxo `xpz-builder` com manifesto explícito na conversa (objetos + intenção do lote):
  - Extrair a lista completa de objetos no `<ExportFile>` (por exemplo todos os `<Object` sob `<Objects>`, ou conteúdo equivalente dentro do `.xpz`).
  - Confrontar com o **delta declarado** / pedido do utilizador (tipo e nome de cada objeto em foco). Cada objeto **extra** deve ser classificado no espírito de `xpz-builder` como mudança pedida, auxiliar necessária ou **extra não pedida**; se for **extra não pedida** num pacote que o utilizador descreveu como correção pontual ou cirúrgica → **ABORT** salvo confirmação explícita.
  - Se aparecer **objeto de plataforma/SDK** GeneXus (por exemplo `PackagedModule:GeneXus` ou `ExternalObject:Camera` com nome no catálogo `scripts/gx-platform-objects.json`, refletido em `systemObjectsPresent`) num pacote tratado como delta mínimo → **ABORT** salvo pedido explícito desse conteúdo.
  - Se em export seletiva houver **muitos atributos top-level** (`totalAttributes` alto) **sem** `Transaction` na lista declarada (`attributesTopLevelUnreconciled` / warning `attributes-top-level-em-export-cirurgico`) → tratar como **arrasto de base** (risco de estrutura de banco), declarar ao usuário e **ABORT** salvo confirmação explícita antes de import/sync.
- **Recomendado** executar o mesmo inventário antes de `PreviewMode` quando o pacote veio de **export MSBuild**, **reempacotamento manual** ou qualquer fluxo em que o agente não controlou fecho do lote na conversa.
- **Exportação com lista explícita (`-ObjectList` / `Objects`) não garante**, por si só, pacote com um único objeto nem equivalência “lista nominal = conteúdo do zip”. Para pacote cirúrgico nominal, use `-DependencyType "None" -ReferenceType "None"` como prevenção na origem; ainda assim, **nunca** tratar tudo o que veio no pacote como intencional sem inventário e confronto.

---

## Categorias A e B (MSBuild headless)

Distinção obrigatória entre comportamento esperado da task GeneXus e rejeição explícita no log. Fonte numérica: `scripts/msbuild-exit-codes.catalog.json` (hoje `exitCode` **48** = Categoria B).

**Categoria A — comportamento esperado / decisão do agente (pode manter `exitCode=0` do wrapper):**

- extras por `DependencyType`/`ReferenceType`, `systemObjectsPresent`, atributos top-level em export cirúrgica (`attributesTopLevelUnreconciled`)
- tratamento operacional: inventário, declaração ao usuário, **Decisão pós-gates** com **ABORT** antes de import real quando houver extra não previsto — autorização de import na sessão **não** cobre esses casos

**Categoria B — rejeição MSBuild/compilador (barragem estrutural no wrapper):**

- linhas `error :` no stdout/stderr (`exportErrors`, `importErrors`, `previewErrors`, `buildErrors`, `specifyErrors` no top-level do JSON, conforme o wrapper)
- `invalidTypesRejected` não vazio (export)
- mensagens `error :` no stderr **não** classificadas como ruído conhecido GeneXus 18 (ex.: ruído estrutural `context [anonymous]` já filtrado nos wrappers de build)
- quando `executionEvidence.msBuildExitCode=0` mas Categoria B estiver populada, o wrapper rebaixa para **`exitCode=48`** (`msBuildCategoryBBlocked=true`); o artefato pode existir no disco **apenas para inspeção**
- o agente **nunca** declara export/import/preview/build como entrega operacional limpa nesse cenário; **PARAR** e pedir decisão explícita do usuário antes de materializar, importar, sync ou push
- na **Decisão pós-gates**, `exitCode=48` é bloqueio cego — autorização ampla de import **não** cobre Categoria B (análogo a extras da Categoria A)

A frase «sinalizar sem rebaixar `exitCode`» aplica-se **somente** à Categoria A.

---

## INVENTÁRIO DO PACOTE APÓS EXPORT SELETIVO

- Aplicar **sempre** que a exportação headless concluir com XPZ gerado (`exitCode` classificado pelo wrapper = 0, sem Categoria B, e arquivo existente), **antes** de declarar ao usuário que a exportação está concluída de forma limpa ou de seguir para materialização/import/sync.
- **Motor preferido:** `Invoke-GeneXusXpzExport.ps1` já chama o inventário e preenche `packageInventory` no `export.json` + `package-inventory.json` no diretório de artefatos. Quando o inventário automático falhar (`inventoryDegraded=true`), abrir o `.xpz` manualmente ou chamar `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <xpz>` antes de fechar a rodada.
- **Classificação da rodada:** quando `-ObjectList` foi informado (e não houve `-ExportAll`/`-FullExport`), a rodada é **exportação seletiva/cirúrgica** — o confronto de extras usa **somente** objetos do bloco `<Objects>` cujo par `Tipo:Nome` (case-insensitive) não está na lista. Quando `-ExportAll` ou `-FullExport`, não há conceito de “extra” face à lista; `packageInventory` reporta apenas contagens reais.
- **Critério de extra (seletiva):** objeto presente no pacote com `Tipo:Nome` normalizado ausente de `-ObjectList`. Atributos top-level entram em `totalAttributes` e na lista completa, mas **não** entram na conta de extras da lista nominal.
- **Atributos top-level em export cirúrgica:** quando `-ObjectList` não inclui nenhuma `Transaction` e o pacote traz `Attribute` sob `<Attributes>`, o motor emite warning `attributes-top-level-em-export-cirurgico` e `attributesTopLevelUnreconciled=true` — sinal de arrasto de base (ex.: export só de WorkWith/Procedure que puxou atributos de TRN). Com `Transaction` na lista, atributos top-level são **esperados** (controle negativo: sem esse warning). Promove `operationalSubState` para **extras não conciliados** quando `exportErrors` estiver vazio.
- **Objetos de plataforma/SDK:** entradas em `scripts/gx-platform-objects.json` com `kind` `packagedModule` ou `externalObject`. No inventário, `PackagedModule`/`Module` (GUID `c88fffcd-...` ou `00000000-...-000006`) e `ExternalObject` (GUID `c163e562-...`) presentes no pacote aparecem em `systemObjectsPresent` com `name`, `kind` e `typeName` do XML. Exemplo: `PackagedModule:GeneXus`, não apenas `Module:GeneXus`. Num pacote cirúrgico, qualquer entrada em `systemObjectsPresent` não pedida exige declaração explícita ao usuário antes de preview/import/sync — mesmo que o MSBuild tenha concluído com `exitCode=0`.
- **Anti-padrão (nomeado): contagem da lista no lugar do pacote** — relatar “28 objetos exportados” contando entradas de `-ObjectList` enquanto o `.xpz` contém centenas de `<Object>`/`<Attribute>`. A contagem no relatório ao usuário vem de `packageInventory` (ou inventário manual equivalente), não da lista solicitada.
- **Anti-padrão (nomeado): amostra de extras no lugar da lista completa** — relatar `extrasSample` ou `totalAttributes` como se fossem o conteúdo real do pacote, omitir atributos top-level quando `attributesTopLevelUnreconciled=true`, ou ignorar `package-inventory.json` quando o motor já gravou `nominalInventoryAt` / `packageInventoryPath` / `artifacts.PackageInventoryPath`. Em export seletiva com `extrasCount > 0` ou com `attributesTopLevelUnreconciled=true`, a comunicação ao usuário deve listar **cada item por nome**, separado por bloco (`<Objects>` e `<Attributes>`). O JSON resumido serve à máquina; não substitui a comunicação ao humano.
- **Anti-padrão (nomeado): fallback silencioso por nome** — pedir `Tipo:Nome` (ou lista equivalente em `-ObjectList` / delta declarado) e aceitar como conclusão limpa um pacote cujo objeto efetivo **não** corresponde à identidade pedida, **sem** reclamação visível no log e **sem** Categoria B. Distinguir três situações:
  - **Tipo rejeitado no log** (`error : ... is not a valid type`, `invalidTypesRejected` populado): **não** é silencioso — o wrapper rebaixa para **`exitCode=48`**; artefato só para inspeção; declarar risco de a task GeneXus ter resolvido só por nome antes do rebaixamento.
  - **Divergência de rótulo Export vs catálogo** (ex.: lista `WorkWith:Nome`, pacote `WorkWithForWeb:Nome` com o mesmo `Nome`): **não** é fallback GeneXus por nome inexistente; é equivalência documentada em `exportTaskLabel` / [10a-gx-export-task-labels.md](../10a-gx-export-task-labels.md). O inventário registra `deltaComparison.aliasResolutions[]` (regra `exportTaskLabel`); usar `requestedItemsFound`, `aliasResolutionCount` no `packageInventory` e o sidecar — não tratar `requestedItemsMissing` isolado como falha quando o alias estiver populado.
  - **Silêncio real** — tipo aceito pela task, `exitCode=0`, sem Categoria B, mas identidade canônica não demonstrada no pacote (homônimo entre tipos, nome errado que ainda “achou” outro objeto, tipo no pacote diferente do pedido sem alias documentado): **ABORT** operacional; listar pedido vs inventário; **não** materializar/importar/sync. O wrapper bloqueia **homônimo** e índice inválido/ausente **antes** do MSBuild em export seletivo (`-ObjectList`) e import/preview seletivo (`-IncludeItems`) — **exit 35**; `not_in_index` gera aviso e não bloqueia (objeto pode existir só na KB nativa). Depois do export/import, inventário obrigatório e confronto explícito.
- **Erros `error :` no stdout com sucesso aparente da task (Categoria B):** a task `Export` pode emitir linhas `error :` (ex.: `X is not a valid type`) e ainda concluir com `Export Sucesso` e `__EXPORTED_FILE__`. O wrapper captura em `exportErrors` / `invalidTypesRejected` via `Read-MsBuildImportSignals.ps1 -Stage export` e rebaixa para **`exitCode=48`** quando a lista não estiver vazia. **Nunca** tratar como conclusão limpa. Em seletiva com tipos rejeitados, declarar risco de resolução por nome (homonímia) e verificar `exportTaskLabel` em `10a-gx-export-task-labels.md`.
- **Ruído conhecido no stdout (export):** `knownStdOutNoise` aparece no **top-level** do `export.json` (espelhando `stdoutSignals.knownStdOutNoise` e `msbuild.export.signals.json`) — não basta inspecionar só `stdoutSignals`; caso típico: `cssproperties-access-denied` para acesso negado a `CssProperties.json` quando a task ainda conclui com sucesso aparente.
- **Sub-estados de export (operacionais, após inventário e sinais de stdout):**
  - `exportação concluída e inventário consolidado` — XPZ existe, inventário obtido, sem `exportErrors`, e (em seletiva) sem extras não conciliados nem itens pedidos ausentes nem módulos/ExternalObjects de plataforma não declarados nem `attributesTopLevelUnreconciled`
  - `exportação concluída, inventário com extras não conciliados` — XPZ existe e inventário obtido, mas em export seletiva há extras, itens pedidos ausentes, `systemObjectsPresent` não vazio e/ou `attributesTopLevelUnreconciled` num pacote tratado como cirúrgico; declarar ao usuário antes de materializar/importar (somente quando `exportErrors` estiver vazio)
  - `exportação parcial com errors do MSBuild — artefato não confiável` — XPZ existe, `exportErrors` e/ou `invalidTypesRejected` não vazios; wrapper com `exitCode=48`; reproduzir linhas ao usuário; prioridade sobre sub-estados de inventário “consolidado”; artefato só para inspeção
  - `exportação concluída sem inventário (degradado)` — XPZ existe, mas `inventoryDegraded=true`; inspeção manual obrigatória antes de fechar
  - Manter também `exportação headless concluída e XPZ gerado (falha no pós-processamento do wrapper)` quando `postProcessingFailed=true` e evidência primária do log/arquivo sustentarem o XPZ

### Anti-padrão (nomeado): export MSBuild como “casca” + patch + import

- **Evitar:** exportar da KB só para obter um `.xpz`, substituir manualmente o nó de um `<Object>` pelo XML da pasta paralela, reempacotar e importar **sem** inventário completo e **sem** alinhamento ao manifesto / delta.
- Quando o XML autoritativo já está na pasta paralela (`ObjetosDaKbEmXml` ou área de geração local), o caminho preferido para import headless é montar **`import_file.xml`** com motor estruturado compartilhado: `Build-GeneXusImportFileEnvelope.ps1` para montagem direta a partir de XMLs de objeto e template válido, com `-AcervoPath <ObjetosDaKbEmXml>` obrigatório, coerência pré-gravação por `lastUpdate` e `Object/@type` por mesmo `guid`, e objetos modificados declarados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids`, ou `New-XpzImportPackage.ps1` para montagem segura por frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus` usando `kb-source-metadata.md` ou `-TemplatePackagePath` apontando para XML/import_file.xml ou `.xpz` comparável (skill `xpz-builder`, metadados em `kb-source-metadata.md` quando aplicável). O `.py` é motor interno do wrapper, não rota operacional equivalente. No wrapper `New-XpzImportPackage.ps1` o gate de drift 9-FD executa **sempre** antes do empacotamento (fail-closed): `-AcervoPath` é opcional e, quando omitido, o acervo canônico `<RepoRoot>/ObjetosDaKbEmXml` é resolvido automaticamente; sem acervo resolvível o empacotamento é bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`). Isso bloqueia XMLs desatualizados ou com `Object/@type` divergente por mesmo `guid` na frente, em vez de fabricar `.xpz` por export só para servir de envelope; acervo ambíguo por GUID é diagnóstico informativo `front-object-type-drift-ambiguous-acervo` com `candidateAcervoPaths`, não escolha automática de tipo. Quando a evidência local indicar que o fluxo ativo de importação exige envelope completo no estilo exportação da IDE, use template comparável exportado pela IDE sem limitar essa regra a uma versão GeneXus específica.

### Footgun (nomeado): import inócuo por `lastUpdate` velho

- **Sintoma:** um pacote cujo objeto tem `lastUpdate` **menor ou igual** ao do objeto vivo na KB é aceito pelo import **sem erro** (`exitCode 0`, sem `error :` no log), mas a KB **não atualiza** o objeto. O resultado parece sucesso e desperdiça um ciclo `import` + `build` inteiro até se descobrir que nada mudou. O GeneXus exige `lastUpdate` **estritamente maior** que o do objeto vivo para efetivar a atualização.
- **Proteção upstream:** o empacotamento por `New-XpzImportPackage.ps1` roda o gate de drift 9-FD **sempre** (fail-closed); `Build-GeneXusImportFileEnvelope.ps1` roda coerência frente-vs-acervo **sempre**, com `-AcervoPath` obrigatório. Em ambos, `lastUpdate` velho ou igual ao acervo em objeto declarado modificado **bloqueia** antes da gravação do pacote; `Object/@type` divergente por mesmo `guid` também bloqueia e exige decisão humana, sem autocorreção por cópia/bump.
- **Limite honesto da proteção:** os dois gates comparam contra o **acervo** (`ObjetosDaKbEmXml`, retrato do último sync), **não** contra a KB viva. Se a KB avançou desde o último sync, um `lastUpdate` "mais novo que o acervo" ainda pode ser `<=` ao objeto vivo, e o footgun escapa mesmo com o gate verde. O gate cobre o caso comum (esquecer de bumpar); **não** substitui conferir contra a KB real quando há suspeita de acervo defasado. Para garantia contra a KB viva, ressincronizar o acervo (`xpz-sync`) antes de empacotar.

### Exportação headless e alinhamento ao pedido

- **Não** iniciar exportação headless da KB como passo próprio quando o utilizador pediu **apenas** importar alterações já existentes na pasta paralela, **salvo** pedido explícito de exportação ou **confirmação explícita** de que a exportação é indispensável (por exemplo impossibilidade documentada de obter `KMW`/`Source`/identidade de envelope por outro meio).

---

## WORKFLOW (fluxo de trabalho)

1. Reler a documentação local aplicável e usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como referência principal
2. Validar se o cenário é compatível com uso controlado e ambiente controlado
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Executar primeiro um probe (sondagem técnica inicial) não invasivo para validar:
   - `KbPath`
   - `GeneXusDir`
   - `MsBuildPath`
   - `WorkingDirectory`
   - `LogPath`
   - existência de `Genexus.Tasks.targets`
   Se `WorkingDirectory` estiver em caminho seguro e ainda não existir, o probe pode auto-criar exatamente essa pasta.
5. Resolver `GeneXusDir` e `MsBuildPath` por ordem explícita de precedência e fallback, registrando origem e descarte de candidatos quando aplicável
6. Classificar o resultado do probe (sondagem técnica inicial) como `apto para prosseguir` ou `não apto para prosseguir`
   O diagnóstico deve incluir `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`.
   O diagnóstico deve distinguir `WorkingDirectory` já existente de `WorkingDirectory` auto-criado no caminho explícito e seguro.
   Preferir `JSON` como formato canônico inicial.
6b. Quando o objetivo for importação (preview ou real), executar o gate de validação do envelope **antes de qualquer chamada ao MSBuild**:
   - Chamar `Test-GeneXusImportFileEnvelope.ps1 -InputPath <caminho>`; a saída de máquina é JSON por padrão. Para Panel com molde/pacote comparável disponível, passar também `-PanelReferencePath <molde-ou-pacote>` para confirmar o par `level id`/`layout id`
   - Interpretar o resultado:
     - `não apto para prosseguir` → **ABORT**; apresentar `blockingReasons` ao usuário antes de prosseguir; não chamar MSBuild
     - `apto com ressalvas` → apresentar `warnings`; exigir confirmação explícita do usuário antes de prosseguir para preview ou import real
     - `apto para prosseguir` → prosseguir normalmente
   - Este gate é não invasivo: lê apenas o arquivo local, não abre KB, não requer GeneXus instalado
   - Aplicar mesmo quando o arquivo vier de geração anterior já validada — o gate é obrigatório por rodada, não por sessão
6c. Antes de **importação real**: executar o **inventário do pacote** (lista completa de objetos no envelope) e confrontá-lo com o delta declarado, conforme a secção **Inventário do pacote antes do import real**. Preferir `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <pacote import_file.xml ou .xpz>`; a saída de máquina é JSON por padrão. Se houver delta declarado em arquivo `Tipo:Nome`, passar `-DeclaredDeltaPath` ou `-DeclaredDeltaItems`; quando a rodada exigir bloqueio automático, `-FailOnDeltaMismatch`. Se o pacote contiver extras não conciliados, módulo/ExternalObject de plataforma não pedido ou `attributesTopLevelUnreconciled` num pacote cirúrgico, **ABORT** salvo confirmação explícita do utilizador. Omitir este passo apenas quando o pacote foi gerado na mesma rodada pelo fluxo `xpz-builder` com manifesto na conversa que já feche o lote esperado.

### Decisão pós-gates (importação real autorizada na sessão)

Quando o usuário **já autorizou importação real headless na mesma sessão** (ex.: «pode importar», «gerar e importar», ou «sim»/«pode executar» a uma **proposta explícita** do agente que inclua import real) e o ambiente for controlado:

1. **Envelope + inventário:** com `Test-GeneXusImportFileEnvelope.ps1` → `apto para prosseguir` e inventário do pacote (passo **6c**) **sem bloqueio**, executar **`Invoke-GeneXusXpzImport.ps1` na mesma rodada**. `apto para prosseguir` valida estrutura do envelope, **não** substitui o inventário nem autoriza ignorar extras.
2. **Sem nova confirmação de import:** o passo **6b** é obrigatório **por rodada**, não uma nova autorização humana por rodada. **Não** encerrar a sessão só porque o envelope está apto.
3. **Preview dispensável:** **não** exigir `Test-GeneXusXpzImportPreview.ps1` antes do import real neste cenário. Preview permanece para rodadas exploratórias ou quando import real **ainda não** foi autorizado.
4. **Pré-requisitos MSBuild:** resolver `KbPath`, `VersionName`, `EnvironmentName`, `WorkingDirectory` e `LogPath` (passos **7–8**) se ainda faltarem.
5. **Watcher obrigatório:** import real com **`-StartWatcher` e `-MonitorLogPath`** (ausência de `-MonitorLogPath` bloqueia cedo, exit 46). Não tratar watcher como opcional nesta skill.
6. **Parada obrigatória (extras):** se o inventário ou a conciliação com o delta revelar **objeto extra não previsto** — objeto, atributo top-level, módulo de plataforma ou ExternalObject fora do pedido da rodada, inclusive itens herdados de **export/reempacotamento** sem classificação — **ABORT imediato** antes de qualquer import real; apresentar lista **completa** do que está no pacote, origem provável (export gordo, merge na montagem, dependência não justificada) e **aguardar decisão explícita** do usuário. Autorização de import na sessão **não** cobre importar extras: impacto pode incluir builds longos (ex.: módulos de plataforma). Ver também anti-padrão **reempacotar lixo de export**.
7. **Ressalvas:** `apto com ressalvas` no envelope, bloqueio de assinatura da task, falha de permissão ou limite do ambiente → parar e reportar; não substituir por import na IDE sem declarar.
7b. **Categoria B no export/preview:** se a exportação que alimentou o pacote saiu com `exitCode=48`, `exportErrors` ou `invalidTypesRejected`, **ABORT** antes do import real — autorização de import na sessão **não** cobre rejeição MSBuild no log.
8. **Build separado:** autorização de import **não** autoriza `xpz-msbuild-build` nem reorg ampla; build só após proposta explícita aceita pelo usuário.

**Anti-padrão (nomeado): parada após envelope apto** — envelope `apto para prosseguir`, usuário já autorizou import real, inventário sem bloqueio, e o agente **não** chama `Invoke-GeneXusXpzImport.ps1`.

**Anti-padrão (nomeado): reempacotar lixo de export** — receber `.xpz`/export com objetos além do delta, **incluir** esses itens no `import_file.xml` da frente atual sem classificar e sem confirmação, e tratar o pacote como cirúrgico.

**Invocação canônica (ajustar caminhos):**

```text
pwsh -NoProfile -File scripts/Invoke-GeneXusXpzImport.ps1 `
  -KbPath "<caminho-kb>" `
  -InputPath "<caminho.import_file.xml ou .xpz>" `
  -VersionName "<versao>" `
  -EnvironmentName "<ambiente>" `
  -WorkingDirectory "<pasta-msbuild-segura>" `
  -LogPath "<pasta-artefatos>/import/import.log" `
  -MonitorLogPath "<pasta-artefatos>/import/watcher.log" `
  -StartWatcher
```

7. Só depois abrir a KB e confirmar versão ativa e `Environment` ativo quando aplicável
   Quando o objetivo for confirmar versão e Environment para usar em `-VersionName`/`-EnvironmentName`, usar `GetActiveVersion` e `GetActiveEnvironment` — nunca `GetVersionProperty -Name Name` nem `GetEnvironmentProperty -Name Name`, pois esses retornam propriedades de metadados incompatíveis com o identificador aceito por `SetActiveVersion`/`SetActiveEnvironment` (verificado empiricamente: `GetVersionProperty -Name Name` retornou `"Design"` enquanto `GetActiveVersion` retornou `"wsEducacaoSpTeste"` na mesma KB)
8. Se o objetivo for inspeção, priorizar:
   - `PreviewMode`
   - `UpdateFile`, quando suportado pela task carregada
9. Se o objetivo for exportação, executar com parâmetros explícitos e conferir o artefato gerado
   Antes de emitir parâmetro sensível de exportação, validar a assinatura efetiva do wrapper e da task carregada para evitar sintaxe presumida incorreta.
   Em exportação full, preferir `-FullExport` quando o wrapper expuser esse atalho.
   Após exportação com XPZ gerado: ler `packageInventory` e `operationalSubState` no `export.json`; **abrir `package-inventory.json` sempre que** o resumo apontar `attributesTopLevelUnreconciled=true`, `extrasCount > 0`, ou `systemObjectsPresent` não vazio (caminho em `nominalInventoryAt`, `packageInventoryPath` ou `artifacts.PackageInventoryPath`); a **lista nominal completa é obrigatória no relatório ao usuário** nesses casos — incluindo **cada atributo top-level por nome** somente quando `attributesTopLevelUnreconciled=true` (export seletiva sem `Transaction` na lista); com `Transaction` na lista, atributos top-level esperados não exigem enumeração nominal no fechamento, salvo pedido explícito do utilizador — conforme a secção **Inventário do pacote após export seletivo**; só então declarar conclusão limpa ou seguir para materialização/import
10. Se o objetivo for importação real, exigir autorização explícita e ambiente controlado na sessão. Quando essa autorização já existir e os passos **6b–6c** tiverem passado sem bloqueio de inventário, seguir **Decisão pós-gates** — inclusive executar `Invoke-GeneXusXpzImport.ps1` sem nova confirmação intermediária só pelo envelope apto e **sem** `Test-GeneXusXpzImportPreview.ps1` obrigatório nesse caminho.
11. Capturar e relatar:
   - `exitCode` — valor classificado pelo wrapper (0/32/41/42/48/...) combinando o código bruto do MSBuild com presença de artefato gerado, `UpdateFile` ou outros sinais; é também o exit code do processo
   - `executionEvidence` — evidência bruta da execução (`msBuildExitCode`, `msBuildFailed`, `wrapperExitCode`, logs brutos); `executionEvidence.msBuildExitCode` é o local canônico do código bruto da task MSBuild, e `blockingReasons` deve priorizar causas acionáveis sem repetir o exit code bruto quando uma causa específica já existir
   - `msBuildExitCode` top-level — compatibilidade transitória quando o wrapper já expõe esse campo; deve duplicar `executionEvidence.msBuildExitCode` e não substitui o bloco canônico
   - `postProcessingFailed` / `postProcessingError` — marca booleana e mensagem quando o pós-processamento do wrapper (parse de stdout, montagem do diagnóstico, serialização JSON ou gravação do log) falhou após o MSBuild já ter rodado
   - `diagnosticDegraded` / `diagnosticDegradedReason` — marca booleana e motivo curto quando o diagnóstico ficou parcial após o MSBuild concluir; pode ocorrer sem `postProcessingFailed=true` quando a saída principal foi montada, mas a leitura compacta de sinais ou outro complemento ficou degradado
   - `compactSignals` — leitura compacta preferencial no diagnóstico JSON de preview/import; se vier ausente, nulo ou insuficiente, usar `msbuild.import.signals.json` como fallback auditável; reparsear `msbuild.stdout.log`/`msbuild.stderr.log` inteiros apenas quando ambos estiverem ausentes ou insuficientes
   - `stdoutSignals` com campos semânticos do domínio (ex: `importWarnings`, `exportMarkerFound`/`gxWarnings`) — presente nos scripts de import/export; omitido nos scripts cujos sinais de domínio já fluem por campos próprios (`observedContext`, `propertyValue`, `consistencyResult`)
   - `observedContext.pathEnrichment` — registro preventivo do enriquecimento de `PATH` aplicado pelo wrapper (`applied`, `subdirsAdded`, `subdirsSkipped`)
   - `stderrContent` — linhas reais de stderr após filtrar ruído GeneXus 18; pode conter o padrão lateral `mismatched input ']' expecting 'default'`, documentado em `10-base-operacional-msbuild-headless.md` como ruído de runtime não bloqueante — não confundir com falha operacional
   - `stderrFilteredNoise` — linhas filtradas do ruído GeneXus 18 (`context [anonymous] N:N attribute component isn't defined`)
   - caminho do `.msbuild`
   - caminho do log
   - artefatos gerados ou consumidos
12. Classificar o resultado como:
   - `não apto para prosseguir`
   - `importação real efetiva provada` — `importedItems` contém explicitamente o objeto esperado
   - `importação real efetiva provada por alias normalizado` — `importedItemsRaw` difere do item esperado cru, mas `expectedItemsCanonical` e `importedItemsCanonical` coincidem e `itemAliasMatches` registra a equivalência, como `Panel:Nome` ↔ `SDPanel:Nome`
   - `importação real efetiva provada, efeito não confirmado na IDE` — `importedItems` contém o objeto esperado, mas build ou execução na IDE ainda exibe comportamento da versão anterior; verificar se KB foi reaberta e se build foi executado após reabertura antes de suspeitar de falha de import
   - `importação real efetiva provada, geração de runtime pendente` — `importedItems` contém o objeto esperado, build foi executado após reabertura, mas artefatos de runtime ainda refletem versão anterior; indicadores no motor atual .NET: objeto em `nav_objs.xml` (raiz da KB nativa) com `ObjStatus=genreq` (tratado pelo diagnóstico .NET como pendente de geração), timestamp dos artefatos gerados (`.cs`, `.aspx` ou equivalente) anterior ao timestamp do import; NVG não integra o diagnóstico somente leitura — é gerado ao abrir a KB na IDE e não é um arquivo estático. Em KB `java-tomcat`, o Eixo C é `recognized-no-engine`/Pós-v1: usar `-DeploymentHostingKind java-tomcat` para obter `skipped-hosting-unsupported`, sem concluir pendência por `ObjStatus` isolado. Tratar como camada de diagnóstico separada do sub-estado de import e do diagnóstico de IDE desatualizada; diagnosticar pela checagem de frescor de runtime (somente leitura) antes de propor nova edição
   - `sucesso operacional sem prova de import efetivo` — `exitCode=0` mas `importedItems` ausente ou não contém o objeto esperado
   - `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — o log bruto (`msbuild.stdout.log` ou stdout capturado) contém `__IMPORTED_ITEM__` ou marca equivalente para o objeto esperado, mas o wrapper lançou exceção interna durante o pós-processamento (ex: `Exception calling Join`, falha de serialização do `import.json`) impedindo que `importedItems` fosse populado no diagnóstico estruturado; a importação real aconteceu — o que falhou foi a camada de diagnóstico do wrapper; declarar nominalmente a origem da evidência (log bruto) e a exceção do wrapper como degradação de diagnóstico separada
   - `importação real efetiva provada com GxImport.log degradado` — stdout/stderr e `executionEvidence.msBuildExitCode` sustentam sucesso, mas `gxImportLogReadStatus=locked` ou `error`; declarar o lock/erro como degradação de diagnóstico, não como causa principal da operação
   - `importação real falhou por source` — erro rastreável ao conteúdo do objeto importado; quando a mensagem indicar `Unknown function '<nome>'`, `src0294` ou equivalente em evento/`Source`, tratar como **mecanismo (a)** da seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus` em [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) — rejeição na importação, objeto não atualizado na KB
   - `importação real falhou por envelope` — erro na estrutura ou envelope do XPZ
   - `importação real falhou sem importedItems` — falha sem trilha de `importedItems` no log
   - `falha operacional` — falha na camada do wrapper ou do MSBuild antes de atingir a task de import
   - `preview bloqueado por assinatura da task` — wrapper de preview abortou antes de chamar MSBuild porque a task carregada na instalação atual não expõe propriedade sensível solicitada em valor não neutro (`UpdateFile` informado, `ImportKbInformation=true`); o pacote não foi testado em preview nessa rodada e a divergência deve ser declarada como contrato operacional entre chamada/wrapper e assinatura efetiva
   - `import bloqueado por assinatura da task` — análogo ao anterior na fase de importação real; o pacote não foi importado e a divergência deve ser declarada antes de qualquer correção
   - `chamada corrigida por parâmetro sensível omitido` — após bloqueio por assinatura, a rodada foi repetida com o parâmetro sensível omitido (apenas para valores neutros), com declaração explícita prévia da divergência detectada e da correção aplicada; este sub-estado complementa o sub-estado principal de preview ou import resultante da nova rodada, não o substitui
   - `preview reconheceu o objeto` — objeto esperado apareceu no retorno do preview
   - `preview apenas` — preview concluído sem evidência de reconhecimento do objeto esperado
   - `preview apenas com falha no pos-processamento` — preview concluído sem alterar a KB (`executionEvidence.msBuildExitCode=0`) e evidência primária do log bruto preservada, mas o pós-processamento local do wrapper falhou e o JSON saiu com `postProcessingFailed=true`; não é `falha operacional`
   - `operação concluída, porém pendente de confirmação funcional`
   - em exportação com XPZ gerado, declarar também o sub-estado de export quando `operationalSubState` estiver presente no diagnóstico: `exportação concluída e inventário consolidado`, `exportação concluída, inventário com extras não conciliados`, `exportação parcial com errors do MSBuild — artefato não confiável` ou `exportação concluída sem inventário (degradado)` — reproduzir `exportErrors`/`invalidTypesRejected`/`knownStdOutNoise` (top-level) quando existirem; com `exitCode=48` ou `msBuildCategoryBBlocked=true`, **PARAR** antes de materializar/importar; nunca fechar export seletiva relatando só a contagem de `-ObjectList`
   - em import real ou preview, ler `importErrors`/`previewErrors` no top-level; com `exitCode=48`, tratar como Categoria B e não declarar conclusão limpa
   - quando aplicável, acumular também o marcador narrativo `ensaio metodológico/experimental`, sem substituir a classificação operacional principal
13. Recomendar o próximo passo seguro; quando o sub-estado for `importação real efetiva provada` e o usuário quiser evidência complementar, apresentar as duas opções em paralelo:
   - acionar `xpz-msbuild-build` (headless) com `-ParallelKbRoot`, `-PostImportDeployValidation` e `-EnvironmentName` alinhado a `deployment_environment_name` no metadata (ou valor explícito do usuário) — `compilou limpo` ou `specify e generate concluídos` reforçam o handoff **no environment usado**; exit **49** ou status `compilou-mas-dll-destino-desatualizada` indicam ausencia de publicacao fresca no `web\bin` resolvido por `kb_environment_web_dirs` em `kb-source-metadata.md` (DLL de objeto ou config) — **não** declarar IIS/self-host OK; `GxNetCoreStartup.dll` velho sozinho não dispara exit **49**. **Fase 3:** se a KB for `java-tomcat`, o Eixo A (deploy-bin) **roda o co-gate Java por família** (publicação atestada no `WEB-INF\classes` externo): `deployBinFreshness` = `fresh`/`stale`/`no-evidence`/`unexpected-publication`/`unknown` (exit **49** sob gate em `stale`/`unexpected-publication`/`unknown`; `no-evidence` não falha, mas não é deploy OK). `compilou limpo`/`specify e generate concluídos` **não** provam publicação Java — quem prova é o co-gate; exige `kb_environment_servlet_dirs`/`_app_package` no metadata (ausentes → `unknown` config-error)
   - abrir a KB na IDE e executar o build por lá
   Recomendar reabertura da KB na IDE quando o teste exigir observação posterior, independentemente da opção de build escolhida
   Se o sub-estado for `importação real efetiva provada` e o usuário não observar o efeito esperado na IDE, diferenciar explicitamente as hipóteses:
   - IDE ainda carregando versão anterior: KB não foi reaberta desde o import, ou foi reaberta mas build não foi executado depois
   - Sintomas concretos de IDE desatualizada: mesmo erro persiste após reabertura + rebuild, propriedades do objeto exibem data/versão anterior ao import, output gerado é idêntico ao da rodada anterior
   - Nenhum desses sintomas invalida o sub-estado de import já declarado — o diagnóstico de IDE desatualizada é camada separada
   Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado após reabertura da KB e o usuário reportar que o comportamento ainda não mudou, oferecer a `checagem de frescor de runtime` como trilha de diagnóstico nomeada antes de sugerir nova edição:
   - Resolver antes o caminho do `.cs` gerado com `scripts\Resolve-GeneXusGeneratedCsPath.ps1 -KbPath <caminho> -ParallelKbRoot <pasta-paralela> -ObjectName <nome> -EnvironmentName <environment-quando-necessario> -AsJson`, usando `kb_environment_web_dirs` de `kb-source-metadata.md`
   - Se o metadata não cobrir o environment, bloquear e encaminhar para `xpz-kb-parallel-setup`; não usar glob recursivo nem inferir `CSharpModel\web` como substituto em KB multi-environment
   - Em seguida executar `scripts\Test-GeneXusRuntimeFreshness.ps1 -KbPath <caminho> -ObjectName <nome> -ImportedAt <timestamp-do-import> -GeneratorOutputPath <webDirectory-resolvido> -AsJson` para verificar automaticamente os dois indicadores no motor .NET; a saída JSON indica `runtime-fresh`, `runtime-stale` ou `runtime-unknown` (Fase 2: em KB `java-tomcat`, passar `-DeploymentHostingKind java-tomcat` → `skipped-hosting-unsupported`/exit 0, pois o diagnóstico `.cs`/.NET não se aplica)
   - Verificar `nav_objs.xml` (raiz da KB nativa) no contexto do motor .NET: confirmar se o objeto aparece com `ObjStatus=nogenreq`; `ObjStatus=genreq` é tratado ali como geração pendente após o import. Para Java/Tomcat, não usar `ObjStatus` isolado como prova de pendência; a evidência empírica exige cruzamento futuro com `ObjNavig` e artefatos locais Java
   - NVG excluído da checagem somente leitura: é gerado ao abrir a KB na IDE e não é um arquivo estático acessível sem abertura
   - Comparar timestamps dos artefatos gerados (`.cs`, `.aspx`, ou equivalente da instalação) com o timestamp do import
   - Se qualquer indicador mostrar artefato de versão anterior: classificar como `importação real efetiva provada, geração de runtime pendente` e propor reabertura da KB seguida de novo build antes de qualquer nova edição
   - Essa checagem é somente leitura, não invasiva e não altera o sub-estado de import já declarado
14. Se a exportação gerou um `.xpz` full para a pasta paralela da KB, declarar explicitamente:
   - caminho do artefato gerado
   - status operacional da exportação
   - warnings estruturais relevantes
   - se a execução para no `.xpz` gerado ou se seguirá para materialização
15. Se o pedido do usuário for seguir com o setup depois da exportação full, anunciar a mudança de fase para materialização em `ObjetosDaKbEmXml` antes de sair da trilha `MSBuild`

---

## WWP IMPORT ORDER

Aplica-se quando os pacotes a importar contêm objetos WorkWithPlus. Siga fases separadas para evitar erros de referência e não misture estrutura base com instâncias de pattern.

### Sequência de importação

1. Importar `SEM_WWP` (preferir dry-run via `PreviewMode` primeiro)
2. Validar log de conflito/import
3. Importar `COM_WWP` ou aplicar pattern na IDE
4. Importar pacote de instâncias/custom (`WorkWithPluswc*`, `wp*`, etc.)
5. Importar pacote(s) de correção cirúrgica
6. Build + Reorganizer em ambiente de teste

### Limpeza pós-import

`import_file` não remove objetos antigos automaticamente. Planejar limpeza manual na IDE para:

- Transactions antigas substituídas
- SubtypeGroups obsoletos
- PatternInstances antigas que serão regeneradas
- Procedures/WebPanels gerados automaticamente e já substituídos

Após a limpeza, reaplicar WWP na Transaction final para regenerar base consistente.

### Ciclo de validação

1. Build após cada fase de import
2. Classificar erros por categoria:
   - Referência ausente (`non-defined object`)
   - Duplicidade em metadata/pattern
   - Incompatibilidade de assinatura em procedures/calls
3. Corrigir no menor pacote possível (cirúrgico)
4. Rebuild até zerar regressão introduzida por aquela fase

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como capacidade operacional validada, com uso controlado
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] O probe (sondagem técnica inicial) não invasivo ocorreu antes de qualquer abertura de KB
- [ ] O probe (sondagem técnica inicial) devolveu diagnóstico estruturado completo
- [ ] O probe (sondagem técnica inicial) respeitou o contrato de parâmetros obrigatórios, opcionais e `exitCode`
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram explicitados
- [ ] Antes de abrir a KB por MSBuild em preview, import real ou export, o bloqueio preventivo de concorrência por KB foi executado; se `msBuildConcurrency.status=blocked` ou `exitCode=46`, a rodada foi abortada e o conflito foi reportado ao usuário, sem tentar enfileirar nem aguardar
- [ ] O probe só auto-criou `WorkingDirectory` quando o caminho explícito era seguro e permaneceu bloqueando caminhos proibidos, inválidos ou ambíguos
- [ ] `GeneXusDir` e `MsBuildPath` foram resolvidos por precedência e fallback rastreáveis
- [ ] `observedContext.pathEnrichment` registrou o enriquecimento preventivo do `PATH` (`applied`, `subdirsAdded`, `subdirsSkipped`)
- [ ] `Genexus.Tasks.targets` foi validado
- [ ] `PreviewMode` foi priorizado quando a intenção era inspeção
- [ ] Quando a intenção era **validar** uma `API` from-spec, usou-se **importação real** (não preview) — o preview reporta sucesso para `API` inválida
- [ ] Quando o objetivo era importação (preview ou real): `Test-GeneXusImportFileEnvelope.ps1` foi executado antes de qualquer chamada ao MSBuild
- [ ] O gate de envelope retornou `apto para prosseguir` ou `apto com ressalvas` com confirmação explícita do usuário
- [ ] O gate de envelope não foi ignorado por presunção de que o arquivo já havia sido validado anteriormente
- [ ] Importação real só ocorreu com autorização explícita
- [ ] Com importação real autorizada na sessão e envelope `apto para prosseguir`, `Invoke-GeneXusXpzImport.ps1` foi executado com `-StartWatcher` e `-MonitorLogPath`, ou o bloqueio foi declarado explicitamente
- [ ] Quando a rodada usou `Invoke-GeneXusXpzImportThenBuild.ps1`, `buildJson` só foi considerado quando `importReadyForBuild.ready=true`; com `buildSkippedReason`, a rodada foi relatada como import não apto para build, não como build pendente esquecido
- [ ] Quando a rodada usou `Invoke-GeneXusXpzImportThenBuild.ps1` com `ForceRebuild=true`, `CompileMains=true`, `DetailedNavigation=true` ou reorg autorizada, os gates e confirmações explícitas do `Invoke-GeneXusKbBuildAll.ps1` foram respeitados antes de repassar `-AllowWideRebuild`, `-AllowCostlyBuildOptions` ou `-AllowReorg`
- [ ] Não houve parada após envelope apto sem import real nem inclusão de extras de export no pacote sem ABORT e decisão do usuário
- [ ] `watcherContext.watcherLaunched` foi verificado no JSON de resultado quando `-StartWatcher` era esperado; **fora** da **Decisão pós-gates**, se `false`, a ausência foi documentada e justificada explicitamente; **dentro** da Decisão pós-gates, `-StartWatcher` com `-MonitorLogPath` é obrigatório na mesma invocação de `Invoke-GeneXusXpzImport.ps1` — `watcherLaunched=false` nesse caminho é falha ou bloqueio operacional a reportar ao usuário, não exceção por justificativa de ausência de watcher (alinhado a `08-guia-para-agente-gpt.md`)
- [ ] `stdoutSignals`, `stderrContent`, `stderrFilteredNoise`, `exitCode`, `.msbuild` e log foram registrados
- [ ] O resultado foi separado entre sucesso operacional e confirmação funcional
- [ ] O resultado de import foi classificado com sub-estado explícito: `importação real efetiva provada`, `sucesso operacional sem prova de import efetivo` ou sub-estado de falha com causa nomeada — nunca apenas `sucesso operacional` ou `falha operacional` para operações de import
- [ ] Quando o sintoma envolve evento GeneXus que não executa ou import falhou em código de evento, foi identificado se o caso é **mecanismo (a)** (`exitCode != 0`, `errors` no `import.json`, ou `Unknown function`/`src0294` no log) ou **mecanismo (b)** (import OK, handler ausente/vazio no `.cs` após build) — conforme [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md), seção `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`; (a) não foi tratado como bug de runtime, (b) não foi tratado como falha de import/envelope
- [ ] Com `src0056` … `end of the rule` em `Transaction` `Rules`, foi aplicado o anti-padrão `transaction-rule-on-event-with-attribute-parameter` e o Catálogo 1 em [xpz-builder/responsibilities-by-type/transaction.md](../xpz-builder/responsibilities-by-type/transaction.md) — não tratado como pontuação genérica
- [ ] Quando preview ou import bloqueou por assinatura da task (propriedade sensível não exposta na instalação atual em valor não neutro), o sub-estado declarado foi `preview bloqueado por assinatura da task` ou `import bloqueado por assinatura da task`, e a divergência foi tratada como contrato operacional entre chamada/wrapper e assinatura efetiva — não como ajuste silencioso
- [ ] Antes de repetir a chamada com parâmetro sensível omitido após bloqueio por assinatura, foram declaradas nominalmente (1) a propriedade ausente, (2) que o pacote não foi testado ou importado naquela rodada, (3) a divergência de contrato operacional, e (4) a correção aplicada; a nova rodada foi classificada com `chamada corrigida por parâmetro sensível omitido` em complemento ao sub-estado principal resultante
- [ ] Quando o wrapper lançou exceção interna durante o pós-processamento mas o log bruto contém `__IMPORTED_ITEM__` para o objeto esperado, o sub-estado declarado foi `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — nunca `falha operacional` nem `sucesso operacional sem prova de import efetivo`; a origem da evidência (log bruto) e a exceção do wrapper foram declaradas explicitamente como camadas separadas
- [ ] Quando o wrapper de export lançou exceção interna durante o pós-processamento mas o log bruto contém `Export Sucesso` e `__EXPORTED_FILE__=<caminho>` e o arquivo XPZ existe, o sub-estado declarado foi `exportação headless concluída e XPZ gerado (falha no pós-processamento do wrapper)` — nunca `falha operacional` nem `XPZ não gerado`; a origem da evidência (log bruto + existência do arquivo) e a exceção do wrapper foram declaradas explicitamente como camadas separadas
- [ ] O script `Invoke-GeneXusXpzImport.ps1` em uso tem o pós-processamento envolvido em `try/catch` e emite diagnóstico parcial com `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, marcas brutas extraídas do log, `postProcessingFailed=true` e `diagnosticDegraded=true` em caso de exceção — não perde toda a evidência por falha de serialização
- [ ] O script `Invoke-GeneXusXpzExport.ps1` em uso tem o pós-processamento envolvido em `try/catch` e emite diagnóstico parcial com `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, valor de `__EXPORTED_FILE__` extraído do log bruto quando disponível e `postProcessingFailed=true` em caso de exceção — não perde toda a evidência por falha de serialização
- [ ] O script `Test-GeneXusXpzImportPreview.ps1` em uso tem o pós-processamento envolvido em `try/catch` e emite diagnóstico parcial com `executionEvidence.msBuildExitCode` como local canônico do valor bruto da task MSBuild, `msBuildExitCode` top-level apenas como compatibilidade transitória quando existir, `exitCode` classificado pelo wrapper, marcas brutas extraídas do log, `postProcessingFailed=true` e `diagnosticDegraded=true` em caso de exceção — não perde toda a evidência por falha de serialização
- [ ] Quando `diagnosticDegraded=true` aparecer com `postProcessingFailed=false` (por exemplo, falha ao gerar ou ler `msbuild.import.signals.json`), a rodada foi relatada como diagnóstico parcial/degradado, não como sucesso limpo nem como falha operacional automática
- [ ] Quando o sub-estado for `importação real efetiva provada` e o usuário não observar o efeito na IDE, o diagnóstico de IDE desatualizada foi tratado como camada separada — não como revisão do sub-estado de import
- [ ] Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado e o usuário reportar que o comportamento ainda não mudou, a `checagem de frescor de runtime` foi oferecida como próximo passo nomeado antes de sugerir nova edição
- [ ] O sub-estado `importação real efetiva provada, geração de runtime pendente` foi aplicado quando artefatos de runtime do motor aplicável ainda refletiam versão anterior após build confirmado (`nav_objs.xml` com `ObjStatus=genreq` ou timestamps de artefatos gerados anteriores ao import no fluxo .NET); em `java-tomcat`, o Eixo C pula com `skipped-hosting-unsupported` e `ObjStatus` não foi usado isoladamente como critério de pendência. NVG pode ser consultado manualmente como indicador complementar, mas não integra a checagem somente leitura automatizada
- [ ] Quando `-ObjectList` (export) ou `-IncludeItems` (import/preview) foi usado, `-ParallelKbRoot` ou `-IndexPath` foi passado; `objectListPreflight` no JSON foi lido (`exit 35` = parar; avisos `not_in_index` não dispensam inventário pós-pacote)
- [ ] Quando `-ObjectList` foi usado para export seletivo/cirúrgico com intenção de conter somente a lista nominal, `-DependencyType "None"` e `-ReferenceType "None"` foram passados; se foram omitidos ou trocados por outro valor, o usuário pediu dependências/referências explicitamente ou a rodada foi tratada como sujeita a extras antes de qualquer materialização/import/sync
- [ ] Quando `-ObjectList` foi usado (um ou mais objetos), o formato `Tipo:Nome` e separadores foram validados; o inventário real do `.xpz` foi obtido (`packageInventory` no `export.json` ou `Get-GeneXusImportPackageObjectInventory.ps1`) e o relatório ao usuário reproduziu **totais reais** (`totalObjects`, `totalAttributes`, `objectsByType`, `systemObjectsPresent`) — não a contagem de entradas de `-ObjectList`
- [ ] Em export seletiva, extras, módulos/ExternalObjects de plataforma e `attributesTopLevelUnreconciled` foram confrontados com a intenção da rodada; sub-estado `exportação concluída, inventário com extras não conciliados` foi declarado quando aplicável, antes de materializar/importar
- [ ] Após export com XPZ gerado, `exportErrors`, `invalidTypesRejected`, `knownStdOutNoise`, `msBuildCategoryBBlocked` e `exitCode` foram lidos no **top-level** do `export.json`; com Categoria B (`exitCode=48`), a rodada foi tratada como bloqueada e o XPZ só como inspeção, não como entrega limpa
- [ ] Em export/import seletivo com `exitCode=0` e sem Categoria B, a identidade de cada entrada pedida foi demonstrada no inventário (par `Tipo:Nome` literal, ou entrada em `aliasResolutions[]` / `packageInventory.aliasResolutionCount` com regra `exportTaskLabel` conforme [10a-gx-export-task-labels.md](../10a-gx-export-task-labels.md)); entradas em `requestedItemsMissing` sem alias correspondente, ou só nome batendo com tipo divergente sem equivalência documentada, foram tratadas como **fallback silencioso por nome** — **ABORT** e decisão explícita do usuário antes de materializar/importar/sync
- [ ] Quando o `export.json` apontou `extrasCount > 0`, `attributesTopLevelUnreconciled=true`, ou `systemObjectsPresent` não vazio, `package-inventory.json` foi lido e a **lista nominal completa** (não apenas `extrasSample` ou contagens) foi reproduzida ao usuário no relatório de fechamento — extras e objetos de plataforma (`systemObjectsPresent`: `kind` + `name`) por nome; atributos top-level **por nome** somente quando `attributesTopLevelUnreconciled=true`
- [ ] Em qualquer pergunta sobre conteúdo nominal do XPZ (mesma rodada ou sessão nova), o sidecar foi relido (caminho A) ou o motor de inventário foi reexecutado sobre o `.xpz` (caminho B) antes de responder
- [ ] Quando `-VersionName` ou `-EnvironmentName` foram informados explicitamente, confirmar que o valor veio de `GetActiveVersion`/`GetActiveEnvironment` ou de fonte comprovadamente compatível com `SetActiveVersion`/`SetActiveEnvironment` — nunca de `GetVersionProperty -Name Name` nem de `GetEnvironmentProperty -Name Name`
- [ ] Quando a frente foi descrita por fluxo funcional e o usuário reportar "não mudou no navegador" após import confirmado, foi verificado primeiro (1) se o objeto importado é o alvo executado pelo fluxo real, antes de (2) checar frescor de runtime ou (3) propor nova edição
- [ ] Antes de importação real, o inventário completo de objetos no pacote foi confrontado com o delta declarado (ou o pacote veio da mesma rodada `xpz-builder` com manifesto que fecha o lote)
- [ ] O inventário foi obtido por `Get-GeneXusImportPackageObjectInventory.ps1` (aceita `import_file.xml` e `.xpz`) quando o script estava disponível; se houve delta declarado, `-DeclaredDeltaPath` ou `-DeclaredDeltaItems` foram usados
- [ ] Quando o pacote veio de export MSBuild ou reempacotamento manual, não se assumiu que o conteúdo coincide com a lista nominal nem que extras eram intencionais sem confirmação
- [ ] Exportação headless não foi executada sem pedido ou confirmação explícita quando o objetivo do utilizador era apenas importar XML já existente na pasta paralela

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER assumir defaults internos de importação ou exportação como seguros sem validação prática
- NEVER tratar importação real como comportamento implícito
- NUNCA encerrar rodada com importação real já autorizada na sessão, envelope `apto para prosseguir` e inventário sem bloqueio de extras, sem chamar `Invoke-GeneXusXpzImport.ps1` ou sem declarar bloqueio operacional explícito (permissão negada, limite do plano, assinatura da task, inventário com extra não previsto, etc.)
- NUNCA tratar `Invoke-GeneXusXpzImportThenBuild.ps1` como autorização para build incondicional: se `importReadyForBuild.ready=false`, o build deve permanecer pulado e o motivo deve ser reportado
- NUNCA prosseguir para importação real quando o inventário apontar extra não previsto, módulo/ExternalObject de plataforma não pedido ou `attributesTopLevelUnreconciled` em pacote cirúrgico, esperando que a autorização ampla da sessão cubra o risco — **ABORT**, listar o pacote completo ao usuário e aguardar decisão
- NUNCA executar importação real sem `-StartWatcher` e `-MonitorLogPath`; ausência bloqueia cedo (exit 46). Exceção apenas com bloqueio documentado e reportado ao usuário, nunca por omissão silenciosa
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER chamar MSBuild para preview ou import sem antes executar `Test-GeneXusImportFileEnvelope.ps1` no arquivo alvo
- NEVER chamar MSBuild para preview, import real ou export quando o preflight `msBuildConcurrency` confirmar `MSBuild.exe` em execução para a mesma KB; abortar com exit 46 e reportar o processo conflitante
- NEVER usar o valor retornado por `GetVersionProperty -Name Name` como `-VersionName`; para exportar da versão ativa, omitir `-VersionName`; se for necessário posicionar versão explicitamente, obter o identificador via `GetActiveVersion`, não via `GetVersionProperty`
- ABORT se `KbPath`, versão, `Environment`, pacote ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
- ABORT se a operação não puder produzir trilha rastreável de logs e artefatos
- ABORT se `Test-GeneXusImportFileEnvelope.ps1` retornar `não apto para prosseguir`
- NEVER prosseguir para **importação real** com pacote montado como export MSBuild + substituição manual de conteúdo + reempacotamento **sem** inventário completo dos objetos no pacote e conciliação explícita com o delta
- NEVER tratar export seletiva/cirúrgica como tentativa de pacote exatamente nominal quando `-DependencyType` e `-ReferenceType` foram omitidos; para esse objetivo, passar `None`/`None`, ou declarar que a rodada aceita dependências/referências por decisão explícita do usuário
- NEVER assumir que `-ObjectList` (ou lista equivalente) com uma única entrada produz `.xpz` contendo **apenas** esse objeto
- NEVER reportar a contagem de entradas de `-ObjectList` como se fosse a contagem do pacote gerado; a contagem comunicada ao usuário é sempre a real do `.xpz` (`packageInventory` ou inspeção manual equivalente)
- NEVER declarar export seletiva como conclusão limpa sem `packageInventory` (ou inventário manual) e sem reproduzir no texto ao usuário os totais reais, `systemObjectsPresent` e sinais de atributos top-level quando existirem
- NEVER declarar export/import/preview como concluído quando `exportErrors`, `importErrors`, `previewErrors` ou `invalidTypesRejected` estiverem populados, ou quando `exitCode=48` / `msBuildCategoryBBlocked=true` — mesmo com `executionEvidence.msBuildExitCode=0` e artefato no disco; pedir decisão explícita do usuário antes de qualquer próximo passo (materialização, import, sync, push)
- NEVER declarar exportação ou importação seletiva/cirúrgica como conclusão limpa quando `exitCode=0`, sem Categoria B e com inventário obtido, mas a **identidade canônica** pedida em `-ObjectList` / `-IncludeItems` (ou delta equivalente) **não** estiver demonstrada no pacote — entrada em `requestedItemsMissing` que não seja só divergência de rótulo Export coberta por `exportTaskLabel` em [10a-gx-export-task-labels.md](../10a-gx-export-task-labels.md); objeto presente só pelo `Nome` com `Tipo` no pacote diferente do pedido sem alias documentado. Tratar como **fallback silencioso por nome** (anti-padrão nomeado nesta skill): **ABORT**, listar pedido vs `package-inventory.json` / delta do inventário e aguardar decisão explícita — independentemente de `executionEvidence.msBuildExitCode=0`. Isto **complementa** o NEVER de `exitCode=48` e a pré-validação **exit 35** em export/import seletivo (homônimo / índice obrigatório)
- NEVER responder perguntas sobre conteúdo nominal do XPZ em qualquer sessão usando só memória de conversa anterior, `extrasSample` ou contagens do `export.json` — reler `package-inventory.json` quando o sidecar ou o `export.json` da rodada ainda existir (caminho A), ou reexecutar `Get-GeneXusImportPackageObjectInventory.ps1` sobre o `.xpz` (caminho B), antes de responder
- NEVER invocar exportação headless da KB quando o utilizador pediu **somente** importar alterações já existentes na pasta paralela, salvo pedido explícito de exportação ou confirmação explícita de que a exportação é indispensável para obter envelope/metadata utilizável
- NEVER incluir em pacote tratado como **delta cirúrgico** objetos de módulo de sistema, ExternalObject de plataforma GeneXus (catálogo `scripts/gx-platform-objects.json`, `systemObjectsPresent`) ou arrasto massivo de atributos top-level sem `Transaction` na lista (`attributesTopLevelUnreconciled`) salvo pedido explícito do utilizador
