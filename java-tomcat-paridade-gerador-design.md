# Paridade de gerador Java/Tomcat nas skills XPZ — design congelado

> **Status:** design **congelado** após revisão por pares de 6 rodadas (v1→v6). O congelamento foi **liberado por unanimidade** na rodada 6 (5 revisores, 3 famílias). Nenhuma decisão de arquitetura muda daqui sem reabrir revisão por pares. As incógnitas remanescentes são **empíricas** e viram **critério de aceite da Fase 0** contra a KB Java real.
>
> **Origem:** proposta de uma usuária das skills XPZ, em outra máquina, sobre uma KB Java/Tomcat (2026-07-01). Registro-resumo em [`999-ideias-pendentes.md`](999-ideias-pendentes.md).

## Proveniência da revisão por pares

| Rodada | Versão | Painel | Famílias | Resultado |
|---|---|---|---|---|
| 1 | v1 | opus-4.8, gpt-5.5, deepseek-v4-pro, kimi-k2.7-code, glm-5.2 | 3 | direção aprovada; achados estruturais (`.war`/Tomcat externo, 3º eixo, regressão da (e), `ValidateSet` não lê registro em runtime) |
| 2 | v2 | os 5 | 3 | refinos de contrato + 2 ajustes de fronteira de fase |
| 3 | v3 | 3 ollama | 1 (suplementar) | 11 refinos; achou a tensão de aridade Fase 1×Fase 3 |
| 4 | v4 | opus-4.8 + gpt-5.5 | 2 (piso) | painel dividido no fold 1; orquestrador decidiu Opção A |
| 5 | v5 | 3 ollama | 1 (suplementar) | deepseek migrou B→A após ver o argumento; liberado |
| 6 | v6 | os 5 | 3 (piso) | **liberação unânime do congelamento** |

Piso de ≥2 famílias distintas cumprido nas rodadas 1, 2, 4 e 6. Mecanismo: `xpz-llm-delegate` (gate de autorização por destino, payload `public`, closeout auditado). A **implementação** desta frente deve passar por nova revisão por pares.

---

## Contexto

Skills PowerShell para operar KBs GeneXus (import/export/build headless via MSBuild, metadata, gates de segurança). Suporta hoje `dotnet-framework-iis` e `dotnet-core-self-host`; meta: dar suporte de **mesmo nível** a `java-tomcat` (GeneXus é gerador multi-plataforma). Não há KB Java na máquina de dev; a KB `wsEducacaoSpTeste` ganhará um environment Java/Tomcat (outra sessão/agente) como base empírica — **pré-requisito de execução das fases empíricas, não do planejamento**.

### A dor
`deployment_hosting_kind` só aceita os dois valores .NET, e o gate de "o build publicou no destino de deploy?" (deploy-bin freshness) é .NET por dentro (`web\bin\*.dll` + `*.config` + sentinela `GxNetCoreStartup.dll`). Uma KB gerada para Java/Tomcat **não é representável** (o usuário contorna forjando metadata .NET) nem **verificável** (o gate procuraria `.dll`/`GxNetCoreStartup.dll` numa app Java, onde o artefato é `.class`/`.jar`/`.war` sob `WEB-INF\`) — **falso-negativo de segurança** (verde enganoso).

### Fatos verificados (evidência, por leitura direta)
1. `Set-XpzKbSourceMetadataDeployment.ps1:93` — `ValidateSet('dotnet-core-self-host','dotnet-framework-iis')`.
2. `GeneXusKbDeployBinSupport.ps1:88` — rejeita valor fora do par (policy).
3. `Test-GeneXusDeployBinFreshness.ps1:142` — validação espelhada (fachada) rejeita idem.
4. `GeneXusKbDeployBinSupport.ps1:298` (`Get-GeneXusKbDeployBinPaths`) — `Join-Path $envWebPath 'bin'` incondicional; retorno **escalar**. Consumidor **único** no repo: o próprio `Test-GeneXusKbDeployBinFreshnessCore`.
5. `:303` — `sentinelPath`=`GxNetCoreStartup.dll` sempre.
6. `:347` (`Get-GeneXusKbDirectoryMaxWriteTime`) — extensões `@('.cs','.js','.aspx','.dll')`.
7. `:310-409` (`Test-GeneXusKbDeployBinFreshnessCore`) — lógica .NET **inline**; lê `$paths.environmentBinPath` **escalar** (`:319`); sentinela exclusiva de `dotnet-core-self-host` (`:371`); `framework-iis` roda **sem** sentinela.
8. `:156-246` (+`Test-GeneXusKbDeployBinRuntimeDllExcluded` `:156-180`) — evidência: `*.dll` objeto + `*.config`; exclusão por prefixo `GeneXus.`/`System.`/`Microsoft.`.
9. `GeneXusKbDeploymentEnvironmentSupport.ps1:526` — valida presença de `deployment_hosting_kind`, não valor.
10. `Test-GeneXusRuntimeFreshness.ps1:133-148` — consumidor ativo; fallback deriva `CSharpModel\web`; extensões `@('.cs','.js','.aspx','.rsp')`; KB Java → `runtime-unknown` silencioso.
11. `Resolve-GeneXusGeneratedCsPath.ps1`/`Find-CsAttributeAssignments.ps1` — resolvem/parseiam `<obj>.cs`.
12. `deployment_hosting_kind` singular por KB; `deployment_environment_name` singular (aponta um env de deploy); `kb_environment_names` lista. Co-aferir 2 famílias na mesma KB **não** é representável.
13. Sem autodetecção de `GeneratorType`; `Resolve-GeneXusKbIdentity.ps1:258-278` lê `model.ini` só GUID/Namespace/Name.
14. Fora de escopo (não muda): daemon PreToolUse (`PtuCanon.*`), config OpenCode, pasta `gxnetcore` (runtime da instalação GeneXus).

---

## Enquadramento em três eixos
- **Eixo A — Gate de deploy-bin** (crítico de segurança): confere publicação pós-build.
- **Eixo B — Diagnóstico de fonte gerado** (diagnóstico): `<obj>.cs`.
- **Eixo C — Diagnóstico de runtime-freshness** (diagnóstico): `Test-GeneXusRuntimeFreshness`. **Guarda de família = Fase 2; motor Java = Pós-v1.**

## Registro central `GeneXusKbHostingKindSupport.ps1` (contrato)
Acesso **só** via `Get-GeneXusKbHostingKindSupportRecord -HostingKind <string>` (nenhum consumidor acessa hashtable/variável interna). Campos:
- `family` (dotnet|java) — **só roteamento**.
- `freshnessSupportState` (supported | recognized-no-engine | blocked-out-of-scope) — **autoridade do fail-closed; ortogonal a `sentinel`**. `recognized-no-engine` mapeia por contrato para `status='skipped-hosting-unsupported'` na saída.
- `publicationTargets[]` = `{ subPath, evidenceStrategy (string livre; enum fechado só na Fase 3), exclusionPrefixes }` — **lista** (forma-alvo da Fase 3). **Opaco às Fases 1/2** (ver cláusula no-bridge). **A aridade do retorno de `Get-GeneXusKbDeployBinPaths` NÃO muda na Fase 1.**
- `sentinel` — opcional/null (core .NET tem; `framework-iis` **null e supported**; Java `tentative-java`; pode migrar para dentro de `publicationTarget` na Fase 3, preservando o caso `framework-iis`).
- `webDirFreshnessExtensions` (Eixo A, `.dll`) e `runtimeFreshnessExtensions` (Eixo C, `.rsp`) — conjuntos distintos.
- `outputModelSubPath` (raiz do modelo gerado: `CSharpModel\web`; Java `tentative-java`).
- `deployTargetKind` (in-kb-web | external-webapp; v1 in-kb-web).
- `errorMessage`, `humanLabel`, `unsupportedReason` — prosa padronizada.
- `runtimeExclusionPrefixes` — .NET populado; Java **`null`** (não `@()`) + `tentative-java` na Fase 1; preenchido do `evidence-catalog` na Fase 3.

**Contrato de saída do skip:** `exit 0` + `status='skipped-hosting-unsupported'` + `unsupportedReason`.

**Cláusula no-bridge (invariante do congelamento):** os consumidores das Fases 1/2 leem `freshnessSupportState`, `sentinel`, `webDirFreshnessExtensions`, `runtimeFreshnessExtensions`, `outputModelSubPath` e o roteamento `family`; **nunca** iteram `publicationTargets[]` para acionar o motor de deploy-bin. `publicationTargets[]` é **opaco** a essas fases; a ponte registro↔motor é **exclusiva da Fase 3**. Isso protege a Opção A (Fase 1 não toca o motor escalar) e torna a asserção do self-test de drift uma **checagem estática trivial** (código de Fase 1/2 não referencia `publicationTargets`).

## Decisões
- **(a)** fonte única = o registro; consumidores usam a API pública. Self-test de drift: mensagem por arquivo + dot-source real + dispatch por família + uso da API + **emissores nomeados** do contrato de skip + **asserção da cláusula no-bridge**.
- **(a')** trocar `[ValidateSet]` por validação manual no corpo (mensagem do registro) + `ArgumentCompleter` **fail-soft** (lista estática mínima se o registro não carregar); golden test cobre aceito **e** rejeitado, timestamps normalizados. Motivo: `[ValidateSet]` recebe constantes de compilação e não lê o registro em runtime.
- **(b)** metadata declarado pelo usuário; `model.ini`/`GeneratorType` **nunca** autoridade (coerente com a remoção deliberada do scan automático); assistente de sugestão = opt-in explícito; `Resolve-GeneXusKbIdentity` exceção escopada ("só GUID/Namespace/Name; explicitamente não GeneratorType").
- **(c)** nome `java-tomcat` (padrão `<runtime>-<hosting>`); família `java` como ponto de extensão (`java-jboss` futuro), sem construí-la.
- **(d)** alvo de deploy in-place vs `.war`/webapp externo (fora da árvore `web`, ex.: `webapps\` do Tomcat) — decisão da Fase 0; `deployTargetKind`; v1 recomenda in-place.
- **(e)** um alvo de deploy por KB no v1 (fato 12: `deployment_hosting_kind` singular; `deployment_environment_name` singular aponta o env de deploy); **habilitador de (d)**; **triagem de alvo de deploy (3 saídas)** com cláusula de momento (snapshot no instante em que o humano decide o alvo desta frente). Custo explícito: declarar `java-tomcat` numa KB cujo env .NET é alvo de deploy **desabilita o gate .NET** dessa KB — regressão se o usuário quer ambos os gates; intenção se está migrando .NET→Java.

## Fases
- **Fase 0 — Design freeze + aterramento** (gated pela KB Java): congela o contrato (.NET + tag de família; **não** a aridade do motor). Produz `evidence-catalog-java-tomcat.md` (checklist: build limpo; incremental **sem** mudança de objeto → calibrar "sem mudança = unknown, não stale"; `.war` sim/não; conteúdo de `WEB-INF\classes`/`lib`; JARs de runtime GX p/ exclusão; **publicado dentro de `web`?**; artefato que regrava a cada build). **Triagem de alvo de deploy (3 saídas: e-mantém / e-sobe-viável / e-sobe-inviável; cláusula de momento).** **Plano B:** topologia divergente → Fase 3 replanejada.
- **Fase 1 — Espinha** (.NET-safe, arranca já): registro (com entrada Java `recognized-no-engine`) + API pública + self-test de drift (inclui a cláusula no-bridge) + `ArgumentCompleter` fail-soft. **NÃO toca o motor de deploy-bin** (escalar intacto). Guarda de regressão .NET: 4 self-tests de deploy-bin (`Test-GeneXusDeployBinFreshnessSelfTest`, `Test-GeneXusDeployBinClassificationSelfTest`, `Test-GeneXusDeployBinPolicySelfTest`, `Test-GeneXusDeployBinFreshnessBuildStartedAtSelfTest`) + golden tests (aceito **e** rejeitado; timestamps normalizados). ZERO mudança .NET **provada** (trivial — motor não é tocado).
- **Fase 2 — Metadata + guardas de família**: validação por registro (a') + `ArgumentCompleter`; plausibilidade/wrapper cobrem `java-tomcat` como `recognized-no-engine` (skip congelado); **guardas de família dos Eixos C e B** (skip claro, sem derivar `CSharpModel`/`.cs`). Inclui explicitamente `:526` e a fachada `:142`. Respeita a cláusula no-bridge. **Case-folding:** ao trocar o `[ValidateSet]` pela validação por registro, decidir explicitamente se o lookup de `deployment_hosting_kind` é case-insensitive — hoje `Get-GeneXusKbHostingKindSupportRecord` casa **case-sensitive** (`.Contains`), enquanto o `ArgumentCompleter` sugere **case-insensitive** (`OrdinalIgnoreCase`); alinhar validação e completer. Gated pela Fase 1. Fase 4 acompanha.
- **Fase 3 — Motor do gate (Eixo A) = refactor de motor** (gated pela KB Java; desmembrar em sub-passos após o `evidence-catalog`): (i) inventário dos consumidores de `Get-GeneXusKbDeployBinPaths` (hoje **um só**, confirmado); (ii) mudança de aridade escalar→lista com varredura de todos eles; (iii) adaptar o Core a iterar e **extrair `...CoreDotNet` + adicionar `...CoreJava`** (fork por família); (iv) `publicationTargets` Java + `evidenceStrategy` promovido a enum fechado; (v) adaptar `Test-GeneXusKbDeployBinRuntimeDllExcluded` ao registro; (vi) preencher `runtimeExclusionPrefixes` Java do catálogo e remover `tentative-java`; (vii) migração opcional do `sentinel` para dentro de `publicationTarget` (preservando `framework-iis` = `sentinel=null` **e** `supported`); (viii) transição observável dos consumidores legados de `runtime-unknown` para o skip explícito; (ix) reescopar/aposentar a asserção **no-bridge** do self-test de drift (`Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1`, varredura `§9`): a partir da Fase 3 o motor **legitimamente** itera `publicationTargets`, então a varredura textual que hoje proíbe qualquer referência fora do registro deve passar a **excluir** o motor/consumidores de Fase 3 (ou virar checagem por AST/allowlist).
- **Fase 4 — Documentação em paridade**: `02` (+ tabela de status trilíngue), `08`, `09` (+ ponteiro do registro), `10-base`, `xpz-kb-parallel-setup/SKILL.md`, `xpz-msbuild-build/SKILL.md` + satélites; README trilíngue por default. A tabela de status deve documentar o mapeamento estado→`status` de saída; **se** `blocked-out-of-scope` compartilhar `skipped-hosting-unsupported` com `recognized-no-engine`, deixar explícito que **uma** string cobre **dois** estados, desambiguados por `unsupportedReason`/`freshnessSupportState`, não pela string. Acompanha a Fase 2.
- **Fase 5 — Testes**: gêmeos Java dos 4 self-tests + Eixo C + regressão .NET. **Proibido** fixture Java antes do aterramento (Fase 0) — senão testa a hipótese, não o GeneXus real. As três varreduras estáticas do self-test de drift (`§6` token da hashtable interna, `§8` skip fonte-única, `§9` no-bridge) são **textuais** e casam qualquer ocorrência (inclusive comentário/string). Ao adicionar gêmeos/consumidores que **asseram** ou **citam** esses tokens (`skipped-hosting-unsupported`, `GeneXusKbHostingKindSupportRegistry`, `publicationTargets`), estender a lista de exclusão das varreduras (`§6`/`§8`; a `§9` é tratada na Fase 3, item (ix)) para esses arquivos — hoje excluem só o registro + o próprio self-test, então um arquivo legítimo que cite o token apareceria como falso ofensor.
- **Pós-v1 — Motor Eixo B + Eixo C (`.java`)**: parser/paths `.java`; gêmeos de `Resolve-GeneXusGeneratedCsPath`/`Find-CsAttributeAssignments`. (Guardas de família de B e C já na Fase 2.)
- **Fechamento — Pré-push reforçada** (`Invoke-PrePushMechanicalChecks.ps1` + busca semântica `13`) + revisão por pares da implementação.

## Sequência
Fase 1 arranca já (**motor intacto**). Fases 2/4 em paralelo, gated pela Fase 1. Fases 0/3 gated pela KB Java (aridade + fork por família na Fase 3, com a evidência). Motores B/C = Pós-v1 (guardas já na Fase 2). (e) antes de (d), fechadas pela triagem de alvo de deploy.

## Incógnitas empíricas (critério de aceite da Fase 0, não decididas no papel)
- Topologia real do deploy Java: in-place vs `.war`/webapp externo; se o publicado está dentro de `web`.
- Sinal de frescor Java (qual artefato regrava a cada build; tratamento de "incremental sem mudança").
- Prefixos de exclusão de runtime Java.
- **Triagem de alvo de deploy:** há environment .NET ativo como alvo de deploy em `wsEducacaoSpTeste` no instante da decisão? → e-mantém / e-sobe-viável / e-sobe-inviável.

## Congelamento vale para a hipótese in-place
Se a Fase 0 revelar topologia externa (`.war`/webapp fora de `web`) ou co-existência .NET+Java exigindo co-aferição, aplica-se o **Plano B** (Fase 3 replanejada / migração de schema), sem reabrir o resto do design.
