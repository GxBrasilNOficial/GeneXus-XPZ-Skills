# REPLANO da Fase 3 (v10) — motor de gate de deploy-bin Java/Tomcat por família (Plano B, topologia externa)

> **Status:** spec **congelada** (v10). Revisão por pares do replano encerrada 2026-07-05 — painel de **5 famílias** (anthropic/Opus, openai/gpt-5.5, deepseek-v4-pro, moonshot/kimi-k2.7-code, zhipu/glm-5.2), v1→v10, veredito final **CONGELA/APROVA unânime**, zero gap de papel (closeout `resubmissionDeclinedByHuman`, motivo "prova transferida para implementação/self-test", RoundId `java-tomcat-fase3-replano-v10`). Rodadas que pegaram bug real: v4 (glm: falso-fresh por skew Tomcat-adiantado), v6 (glm: imprecisão do strip de sufixos), v9 (kimi: migração-compat do split).
>
> Companheiro de `java-tomcat-paridade-gerador-design.md` (design congelado, sub-passos i–x), `evidence-catalog-java-tomcat.md` (fonte-verdade empírica da Fase 0) e `java-tomcat-fase3-checklist-implementacao.md` (checklist de implementação + Fase 5). Persistido no repo em 2026-07-05 (antes vivia só em scratchpad efêmero). **A implementação (Fase 3) segue esta spec; a Fase 5 empírica é frente própria, gated pela KB Java.**

---

## 0. Contexto mínimo

Skills PowerShell (7.4) operam KBs GeneXus (import/export/build headless via MSBuild). Um gate de segurança é o **deploy-bin freshness** (Eixo A): após um build, confere se o artefato compilado foi **publicado** no destino de deploy (senão o build "verde" esconde uma publicação que falhou — falso-negativo de segurança). Hoje esse gate é **.NET por dentro**: `*.dll` de objeto + `*.config` em `<env>\web\bin`, sentinela `GxNetCoreStartup.dll`.

GeneXus é gerador multi-plataforma; a meta é dar suporte de mesmo nível ao gerador **Java/Tomcat** (`deployment_hosting_kind = java-tomcat`). O design foi **congelado** após 6 rodadas de revisão por pares. As Fases 1 (registro-fonte-única + API + self-test de drift, .NET intacto), 2 (validação por registro + guardas de família dos Eixos C/B) e 4 (docs) estão **implementadas e pushadas**. A Fase 0 (aterramento empírico contra KB Java real) está **concluída**. Esta é a **Fase 3**: o motor do gate por família.

### Três eixos (para desambiguar escopo)
- **Eixo A — deploy-bin freshness** (crítico de segurança): "o build publicou no destino?". **É o escopo da Fase 3.**
- **Eixo B — diagnóstico do fonte gerado** (`<obj>.cs`/`<obj>.java`): Pós-v1. Só guarda de família na Fase 2.
- **Eixo C — runtime-freshness** (`Test-GeneXusRuntimeFreshness`): Pós-v1. Só guarda de família na Fase 2.

---

## 1. O que a Fase 0 estabeleceu (fonte-verdade empírica)

Aferido na KB `EBTECH` (GeneXus 18 Upgrade 14; env Java `Prototipo_18U14`; sabor **JAKARTA_EE**; `TOMCAT_VERSION=TOMCAT_10_1` no `model.ini`, Tomcat instalado no diretório `...\Tomcat 11\`; JDK 21; namespace `jakarta.*`; build **Gradle**; DataStore PostgreSQL). Re-teste controlado decisivo (2026-07-04, rota manual pela IDE) confirmou o sinal de frescor.

1. **Topologia EXTERNA** (não in-place). Duas árvores em volumes diferentes:
   - **Geração+compilação (na KB):** `...\EBTECH\Prototipo_18U14\web\` — projeto Gradle (`src\main\java`, `build\classes\java\main`, `build\libs`, `build.gradle`, `gradlew`). **Sem `WEB-INF`.**
   - **Webapp servido (no Tomcat):** `...\Tomcat 11\webapps\EBTECHPrototipo_18U14\` — layout desdobrado (`WEB-INF\{classes,lib,private}`, `META-INF`, `static`, `web.xml`). **Fora da árvore de output da KB.**
   - Logo `deployTargetKind = external-webapp`.
   - **TRÊS árvores** (relevante ao co-gate): (a) `web\src\main\java` — fonte `.java` **local** (produto direto da geração GeneXus); (b) `web\build\classes\java\main` — `.class` **local** (compilação Gradle intermediária, **irrelevante ao gate**); (c) `WEB-INF\classes` **externo** — `.class` publicado (o alvo de deploy).
2. **Alvo localizável deterministicamente** pelo `model.ini` do env: `SERVLET_DIR = ...\webapps\EBTECHPrototipo_18U14\WEB-INF\classes`. Também `TOMCAT_PATH`, `CLIENT_STATIC_DIR`, `WebRoot`.
3. **Sinal de frescor = `.class` de objeto sob o `WEB-INF\classes` EXTERNO**. Um objeto gera `<obj>.class`/`.java` (stub) **+ `<obj>_impl.class`/`_impl.java`** (lógica) **+ auxiliares** (`<obj>__default`, `<obj>__gam`, …). Num build **com** mudança, o **mtime avança em TODOS os artefatos do objeto** (stub + impl + auxiliares); num build **sem** mudança, **nada é tocado** (Q5a: `.class` do objeto ficaram com hash/mtime intactos após BuildAll sem mudança — medido no `WEB-INF\classes` externo). O re-teste decisivo confirmou paridade local↔publicado após mudança real. → gate por **mtime ≥ início-do-build** é viável e correto; **hash é proibido** (recompilação Gradle não é byte-determinística).
   - **Frescor por conjunto de artefatos, não por `_impl` isolado (v5):** o `_impl` é o portador de conteúdo de eventos, mas mudanças de **assinatura** (parâmetros, tipo de retorno, método exposto) podem regenerar **só o stub** `<obj>.java`/`.class` sem tocar `_impl`. Como o fato 3 garante que o mtime avança em **todos** os artefatos do objeto num build com mudança, o gate deve chavear pelo **conjunto de artefatos do objeto** (max mtime), não só pelo `_impl` (ver v-bis).
4. **Geração GeneXus é content-aware.** No-op DCE-eliminado não propaga nada; mudança real regenera → Gradle recompila → deploy publica no externo. **Confirmado que build incremental SEM mudança não toca o `WEB-INF\classes` externo** (Q5a) — logo `Pf=∅` num build rotineiro sem mudança (base do quadrante `no-evidence`). **Não aferido:** `Rebuild All`/clean-build **forçado** sem regeneração (ver política em v-bis).
5. **Exclusão por PACOTE, não por prefixo de nome.** Código do objeto = `.class` sob `com\<kb>\...`, não empacotado em jar. Todos os 195 `.jar` de `WEB-INF\lib` são runtime. Contagens: `WEB-INF\classes` publicado = **1455 `.class`** (superconjunto: `com`, `genexus`, `qviewer`, `dummy` — inclui GAM/framework), contra **894 `.class`** local. Amostra em `com\ebtech\`: `bbextratoimportar.class`, `bbextratoimportar__default.class`, `ebt_gamuserentry_impl.class` (objeto GAM **da app**). O GAM de **framework** vive em `com\genexus\`. → o pacote **positivamente identificável** da app é `com\<kb>`.
6. **Sentinela = `WEB-INF\lib\GeneXus.jar`** (irmão da raiz de evidência `WEB-INF\classes`). Presença ("é webapp GeneXus Java"), **não frescor**.
7. **Sem `.war`** no fluxo cotidiano — deploy exploded. Fora de escopo.
8. **Eixo A e Eixo B leem árvores DIFERENTES em volumes diferentes**, **possivelmente máquinas/relógios distintos** (o co-gate compara mtime entre a árvore local da KB e a externa do Tomcat — ver v-ter, skew).
9. **Dois sabores Java:** aferido `JAKARTA_EE`/`jakarta.*`. O outro `JAVA_EE`/`javax.*` (Tomcat 8/9, JDK 8) **não aferido**. O sabor é atributo do **environment** (Tomcat/JDK por env), não da família — uma KB pode ter env Jakarta e env javax (ver vi-bis). `allowlist com\<kb>` é namespace-agnóstica.

### Triagem de alvo de deploy (cláusula de momento)
Na KB de dev `wsEducacaoSpTeste`, o alvo de deploy é **.NET**; o env Java é separado. Classificação **e-mantém**.

---

## 2. Motor .NET atual (a refatorar) — fatos por leitura direta do código

`GeneXusKbDeployBinSupport.ps1`:
- `Get-GeneXusKbDeployBinPaths` (`:291-332`) — resolve `envWebPath` de `kb_environment_web_dirs`; devolve **objeto escalar**. **Consumidor único** de `...Paths`: `Test-GeneXusKbDeployBinFreshnessCore` (`:343`).
- `Test-GeneXusKbDeployBinFreshnessCore` (`:334-434`) — `$paths.environmentBinPath` escalar; `threshold = BuildStartedAt - slack(5s)`; camada diagnóstica varre `environmentWebPath` (exclui subdir `bin`, `:371`) → `environmentWebFresh`; evidência via `Get-GeneXusKbDeployBinPublicationEvidence`; sentinela só `dotnet-core-self-host` (`:395`); `framework-iis` sem sentinela. **Devolve shape** consumido pela fachada (`:162`) e por `Invoke-...Classification` (`:499-511`).
- `Get-GeneXusKbDeployBinPublicationEvidence` (`:206-270`) — `publicationFreshSinceBuild = objectDllFresh -or configFresh` (`:268`).
- `Test-GeneXusKbDeployBinRuntimeDllExcluded` (`:180-204`) — exclusão por prefixo de nome.
- `Resolve-GeneXusKbDeployBinCheckPolicy` (`:41-121`) — discrimina por `$rec.runsFreshnessEngine` (`:106`); ramo `unknown`+`gateEnabled` → exit 49 (`:524-538`).

Registro `GeneXusKbHostingKindSupport.ps1`: `runsFreshnessEngine = (freshnessSupportState -eq 'supported')` derivado (`:93`); aliasing proposital dos arrays `$dotnet*` (`:117-124`). Guarda Eixo C `Test-GeneXusRuntimeFreshness.ps1:128`; guarda Eixo B `Resolve-GeneXusGeneratedCsPath.ps1:196`. §9 (varredura textual do drift self-test) em `Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1:315-332` (exclui só `registryFile`/`selfFile`).

**Infra de AST já existente:** `XpzWrapperEngineParamSupport.ps1` (parse + `FindAll` + `CommandAst`/call-sites/splat) e `Test-PsScriptsParse.ps1`.

---

## 3. Sub-passos (i)–(x) do design, replanejados (v5)

### (i) Inventário de consumidores — auditoria em DOIS níveis
`...Paths` tem **um só** consumidor (`...FreshnessCore`). A mudança de aridade (ii) altera o **shape de `...FreshnessCore`** (consumidores: fachada `:162`, classification `:499-511`). Auditoria em dois níveis, **tratada como gate de implementação** (varredura real).

### (ii) Aridade escalar → lista
`Get-GeneXusKbDeployBinPaths` devolve **lista de alvos** `{ targetKind, targetRootPath, sentinelPath, evidenceStrategy, exclusionSpec, pathResolution* }`. .NET = 1 alvo `in-kb-web`; Java = 1 `external-webapp`. Um alvo por KB no v1 (decisão (e)).

### (ii-bis) Resolução de alvo EXTERNO — B1 com VALIDAÇÃO de topologia
**B1 — metadata, campo dedicado** `kb_environment_servlet_dirs` (por env Java, valor = `SERVLET_DIR`). Coerente com decisão (b). Custo: `AUDIT_REQUIRED` no setup. **Validação:** (a) termina em `WEB-INF\classes` (não `build\classes` local); (b) sibling `WEB-INF\lib\GeneXus.jar` existe; (c) raiz existe/é diretório; (d) reporta a raiz do webapp (pai de `WEB-INF`). Falha → `unknown` (config-error), nunca `fresh`. **Defesa em profundidade:** webapp estruturalmente válido porém **errado** passa (a)-(c) mas é pego pelo co-gate (`stale`).

### (iii) Fork `...CoreDotNet` / `...CoreJava`
Dispatcher por `family`. `...CoreDotNet` = corpo atual **extraído sem mudança de comportamento**. `...CoreJava` = novo; **não** reusa `Get-GeneXusKbDirectoryMaxWriteTime` com `ExcludeDirectoryNames=@('bin')` (em Java não há aninhamento web/bin; a varredura confina-se ao pacote `com\<kb>`).

### (iv) `publicationTargets` Java + `evidenceStrategy` enum + CAMPOS DEDICADOS
```
{
  targetResolution        : env-subpath | external-servlet-dir
  subPath                 : <só env-subpath>          # .NET: 'bin'
  externalTargetKey       : <só external-servlet-dir> # Java: 'kb_environment_servlet_dirs'
  appPackageKey           : <só external-webapp>      # Java: 'kb_environment_app_package'
  evidenceStrategy        : object-dll-or-config | app-object-artifact-mtime
  exclusionPrefixes       : <nomes de arquivo>        # .NET
  exclusionPackages       : { allowRoot, denySanity[] }  # Java
  sentinelRelativeToWebappRoot : <só external-webapp> # Java: 'WEB-INF\lib\GeneXus.jar'
}
```
**Validação cruzada do contrato (nota v9 — deepseek rec 3):** a exclusividade dos campos é **validada**, não só documentada — `subPath` deve ser `$null` quando `targetResolution='external-servlet-dir'`, e `externalTargetKey`/`appPackageKey`/`sentinelRelativeToWebappRoot` são **obrigatórios** nesse caso (e `$null` no caso `env-subpath`). Um self-test/validação simples do shape evita drift silencioso (ex.: um record Java que deixe `subPath='bin'` por cópia acidental do molde .NET — ver cuidado de aliasing (x)).

### (v) Exclusão por pacote — ALLOWLIST `com\<kb>` com FONTE DETERMINÍSTICA
Evidência de frescor sob `com\<kb>`, `<kb>` = pacote da app de campo metadata **dedicado** `kb_environment_app_package` (ex.: `com\ebtech`), gravado pelo setup. Falha de resolução → `unknown` (config-error) + gate falha se obrigatório (nunca varrer `com\` inteiro). Denylist `com\genexus`/`qviewer`/`dummy` = **asserção defensiva de sanidade** (`denySanity[]`). `.jar` de `WEB-INF\lib` nunca varridos.

### (v-bis) CO-GATE de 4 quadrantes por CONJUNTO DE ARTEFATOS DO OBJETO (segurança — REVISADO na v5)

**Definição por objeto (não por `_impl` isolado — correção v5):** agrupa-se por **objeto**, identificado pelo **caminho relativo completo sob `com\<kb>`** + nome-base do objeto, evitando colisão de homônimos em subpacotes distintos. O nome-base sai stripando um **conjunto FECHADO de sufixos-artefato** (correção v6): `{ _impl, __default, __gam }`, derivado da amostra EBTECH. **Sufixo desconhecido** (fora do conjunto fechado) é tratado como parte do nome-base — fail-safe na direção segura: um `<obj>_novo.class` de sufixo não-catalogado vira seu **próprio** objeto, o que só torna o gate **mais estrito** (cada "objeto" exige cobertura), nunca funde indevidamente reduzindo `Pf`. Ampliar o conjunto exige aterramento (Fase 5), não inferência aberta.

**Precisão do strip (correção v7 — achado glm R5):** para os sufixos **conhecidos** o strip é agrupador por definição — `foo_impl.class` **é** o impl do objeto `foo`, então cai no grupo de `foo` (comportamento correto). O que **evita** fundir um objeto **legitimamente chamado** `foo_impl` com o objeto `foo` **não** é o fail-safe acima, mas uma **premissa de nomenclatura do GeneXus**: o gerador não emite dois objetos cujos artefatos colidam no mesmo caminho FS (`foo_impl.class` não pode ser simultaneamente o stub do objeto `foo_impl` e o impl do objeto `foo` — é o mesmo arquivo). O gate **assume** essa premissa; a Fase 5 a confirma. Guarda de robustez na implementação: **strip condicional** — só stripar o sufixo conhecido se existir o stub-base `<base>.class`/`.java` no **mesmo subpacote**; se não existir, tratar o nome inteiro como nome-base (não presumir a colisão). Assim a corretude não depende só da premissa. Segurança intacta em ambos os caminhos (nenhuma fusão reduz `Pf` → sem falso-fresh).

Para cada objeto, o mtime considerado é o **máximo** sobre **todos** os seus artefatos (stub + impl + auxiliares):

- `Lf` = { objeto | max(mtime de todos os `<obj>*.java` sob `com\<kb>\...\`) ≥ threshold } — no fonte **local** `web\src\main\java`. **Deriva do `.java` local — NÃO do `build\classes` local** (intermediário).
- `Pf` = { objeto | max(mtime de todos os `<obj>*.class` sob `com\<kb>\...\`) ≥ threshold } — no **externo** `WEB-INF\classes`. **`Pf` é o subconjunto FRESCO** (mtime ≥ threshold), **não** o conjunto de todos os `.class` publicados.

Chavear pelo conjunto de artefatos fecha a mudança **stub-only** (assinatura): mesmo sem tocar `_impl`, o stub `<obj>.java`/`.class` avança de mtime → o objeto entra em `Lf`/`Pf`.

**Classificação por 4 quadrantes + config-error:**

| Caso | Classificação | Falha o gate obrigatório? |
|---|---|---|
| `Lf ≠ ∅` **e** `Lf ⊆ Pf` | **`fresh`** | não |
| `Lf ≠ ∅` **e** `Lf ⊄ Pf` | **`stale`** (publicação parcial; lista os faltantes) | sim |
| `Lf = ∅` **e** `Pf = ∅` | **`no-evidence`** (build sem mudança; nada a publicar) | **não** (warning) |
| `Lf = ∅` **e** `Pf ≠ ∅` | **`unexpected-publication`** (publicado sem geração local; origem não atestável) | **sim** (fail-safe) |
| sentinela ausente / `<kb>` irresolvível / topologia inválida / evidência ilegível | **`unknown`** (config-error) | sim |

**Diagnóstico `Pf \ Lf` (assimetria explícita — correção v5):** quando `Lf ≠ ∅` e `Lf ⊆ Pf` (`fresh`), se `Pf ⊋ Lf` (há objetos publicados-frescos **sem** geração local correspondente), **reportar** o conjunto `Pf \ Lf` no diagnóstico (não bloqueia). **Redação acionável (correção v8 — kimi item 5):** a mensagem NÃO pode induzir o operador a ler `Pf \ Lf` como falha; usar formulação do tipo *"objetos publicados-frescos sem geração local correspondente (possível recompilação transitiva do Gradle; informativo, não bloqueia)"* — enquadrando como informativo, não como stale. **Racional da assimetria:** (i) `Lf ⊆ Pf` trata extras em `Pf` como **benignos** porque o gate atesta só **cobertura dos objetos gerados** (e `Pf ⊋ Lf` pode ser recompilação transitiva legítima do Gradle — dependente recompila sem regenerar `.java`; **não aferido**, por isso warning e não bloqueio); (ii) `Lf = ∅, Pf ≠ ∅` é **falha** porque **nenhum** objeto foi gerado e ainda assim houve publicação — origem não atestável.

**Teto honesto da recompilação transitiva (correção v7 — achado glm R3):** o tratamento benigno de `Pf \ Lf` pode **subnotificar** um caso fino: mudança de **API** num objeto upstream faz o Gradle recompilar o `.class` de um downstream **sem** que o `.java` do downstream seja regenerado → o downstream entra em `Pf \ Lf` (publicado-fresco sem geração local). O gate não emite falso-`fresh` (a cobertura de `Lf` é satisfeita pelos objetos gerados), mas **não sinaliza** que o downstream foi materialmente impactado. Direção conservativa quanto a `fresh`, porém registra-se como **limite honesto** ao lado do "hash proibido" e do "skew maior que a janela": o co-gate atesta **cobertura de publicação da geração deste build**, não **completude de impacto de API transitivo**.

**Por que não há falso-stale nem falso-fresh no fluxo aferido:**
- Sem **falso-stale** no caso normal: build com mudança real + publicação bem-sucedida → todos os artefatos do objeto ganham mtime novo (fato 3; paridade local↔publicado confirmada). `objeto ∈ Lf` mas `∉ Pf` é **exatamente** a publicação parcial-alvo.
- O `no-evidence` (`∅,∅`) é o build rotineiro sem mudança **porque Q5a confirma que build incremental sem mudança não toca o `WEB-INF\classes` externo** → `Pf=∅`.

**Política do `unexpected-publication` (declarada, correção v5 — achado glm A1):** o quadrante `∅,≠∅` **não** foi provado empiricamente para o caminho **`Rebuild All`/clean-build forçado** (a Fase 0 aferiu build **incremental**). Duas consequências: (1) o gate trata `∅,≠∅` como **política fail-safe** ("origem não atestável", **não** "deploy necessariamente errado"), com **mensagem acionável** enumerando causas prováveis (rebuild forçado sem regeneração / cópia manual / deploy externo) + remédio ("rode geração antes do deploy, ou marque diagnóstico"); (2) **item de Fase 5:** confirmar empiricamente se `Rebuild All` sem regeneração produz `Lf=∅, Pf≠∅` no fluxo nominal — se produzir com frequência, avaliar relaxar (ex.: exigir registro de "última publicação bem-sucedida" como estado adicional).

**`unknown` (config-error) FALHA o gate quando obrigatório** (simétrico ao .NET `:524-538`); **`no-evidence` NÃO falha** (nada a verificar); em modo diagnóstico, ambos são warning.

### (v-ter) Clock skew BIDIRECIONAL (segurança — REVISADO na v5, achado glm A2)
O co-gate compara mtime entre a árvore **local** (KB) e a **externa** (Tomcat), possivelmente **relógios distintos** (fato 8). **Dois sentidos:**
- **Tomcat atrasado** frente à KB → `_impl.class` publicado legítimo com mtime "no passado" frente ao threshold → **falso-stale** (ruído, não perigo).
- **Tomcat adiantado** frente à KB → um `.class` publicado por um build **anterior** tem mtime "no futuro"; como `threshold = BuildStartedAt(KB) - slack` fica **abaixo** dele, entra em `Pf` como "fresco" sem ter sido publicado neste build → `Lf ⊆ Pf` → **falso-FRESH = falso-negativo de segurança**. Este é o sentido crítico, e o `slack` **piora** (só afrouxa o limiar inferior).

**Correção — janela bidirecional:** `Pf` exige `threshold_inf ≤ mtime ≤ threshold_sup`, com `threshold_inf = BuildStartedAt - slack`. O limite superior barra o `.class` "do futuro" de um build anterior sob Tomcat-adiantado; `slack` cobre **ambos** os sentidos.

**Âncora do limite superior — preferência de design (correção v6):** a âncora **preferida-por-design** de `threshold_sup` é o **fim do passo de publicação** — `DeployStepCompletedAt` (o instante em que o deploy termina de copiar ao `WEB-INF\classes`, se observável no bloco `timing` do MSBuild Java) `+ slack`. O `BuildEndedAt + slack` é o **fallback explícito** quando `DeployStepCompletedAt` não estiver disponível. Esta ordem importa: se a publicação for **posterior** ao `BuildEndedAt` (deploy assíncrono/demorado, ou sub-passo cujo timestamp o MSBuild não fecha em `BuildEndedAt`), um `.class` **legítimo** cairia fora de `[threshold_inf, threshold_sup]` sob o fallback → **falso-stale**. Usar o fim-de-publicação como âncora primária evita isso; o fallback só vale para topologia same-host onde deploy é passo síncrono do BuildAll (o caso aferido, skew≈0). **Empírico (Fase 5):** aferir se `DeployStepCompletedAt` existe no `timing` do MSBuild Java — só a **existência** é empírica; a **preferência de design** já está declarada aqui.

**Premissa do ator da cópia (correção v7 — achado glm R1):** a Fase 0 estabeleceu a topologia externa (webapp no Tomcat, fora da árvore de output), mas **não** aferiu **quem** copia para o `WEB-INF\classes` (MSBuild Java direto? passo do `gradlew`? auto-deploy do Tomcat? sub-passo pós-Gradle?). Isso é decisivo: se o ator da cópia **não** for o MSBuild, `DeployStepCompletedAt` provavelmente **não** aparece no bloco `timing` do MSBuild → a âncora **de fato** é o fallback `BuildEndedAt + slack`. Ponto que sustenta o congelamento: **em qualquer dos casos o sentido de falha é conservativo** — quando a âncora superior fica cedo demais, um `.class` legítimo cai **acima** da janela → excluído de `Pf` → `stale`/`no-evidence`, **nunca** falso-`fresh`. Logo a incerteza sobre o ator/observabilidade **não viola a propriedade de segurança**; só pode gerar ruído (falso-stale). Determinar o ator da cópia é **item de Fase 5**.

**Diagnóstico distingue "fora da janela superior" de "ausente" (correção v6):** quando um objeto de `Lf` não entra em `Pf`, o diagnóstico deve reportar **por que**: (i) `.class` **ausente** no `WEB-INF\classes` externo (publicação parcial genuína → `stale`); (ii) `.class` **presente mas fora da janela** (`mtime > threshold_sup`, suspeita de skew Tomcat-adiantado → sinalizar como possível skew, orientar conferir `deployBinTimeSlackSeconds`/relógios, não confundir com publicação faltante). Sem essa distinção, um falso-stale por skew seria lido como falha de publicação inexistente.

**Mascaramento `unexpected-publication`→`no-evidence` sob skew (correção v7 — achado glm R6):** sob **Tomcat-adiantado** com skew maior que a janela, um `.class` de build **anterior** (`mtime > threshold_sup`) é **excluído** de `Pf` → `Pf=∅` → o caso cai em **`no-evidence`** (warning, não falha) em vez de `unexpected-publication`. Isso **não é falso-`fresh`** (nenhum `fresh` é emitido — a propriedade de segurança "não emitir `fresh` sem publicação atestada" está preservada), mas pode dar ao operador a falsa sensação de "nada a verificar". **Nota diagnóstica:** quando a classificação for `no-evidence` **e** houver `.class` no `WEB-INF\classes` externo sob `com\<kb>` com `mtime > threshold_sup`, sinalizar a **possibilidade de skew** ao lado do `no-evidence` (não silenciar). Diagnóstico-only; não muda a classificação.
- **Campo de config:** `deployBinTimeSlackSeconds` no registro `GeneXusKbHostingKindSupport.ps1`, default **5** (coerente com a disciplina metadata-driven; herdado do .NET, **provisório** — o default empírico Java = latência fim-Gradle→fim-deploy medida na Fase 5).
- **Self-test** cobre: build imediatamente antes do deploy (skew≈0), deploy demorado (Pf após threshold_inf), e **Tomcat-adiantado** (`.class` antigo com mtime > threshold_sup → excluído de `Pf` → não vira falso-fresh).
- **Teto honesto** (junto do "hash proibido"): o esquema mtime não detecta divergência de bytes; e mesmo bidirecional, skew **maior que a janela** escapa — daí a preferência pela âncora de deploy quando existir. No caso aferido (KB e Tomcat na mesma máquina), skew≈0 e o default basta.
- **Nota .NET:** mesma máquina → skew≈0; o limite superior é inócuo no `...CoreDotNet` (não muda comportamento), aplicado só no `...CoreJava`.

### (vi) Preencher campos Java + remover `tentative-java`
`sentinelRelativeToWebappRoot='WEB-INF\lib\GeneXus.jar'`; `evidenceStrategy='app-object-artifact-mtime'`; `exclusionPackages={allowRoot:'com\<kb>'(de kb_environment_app_package), denySanity:['com\genexus','qviewer','dummy']}`; `publicationTargets` conforme (iv); `deployTargetKind='external-webapp'`; `outputModelSubPath`=raiz do fonte local; `deployBinTimeSlackSeconds=5`. `runtimeExclusionPrefixes` Java **não** reusado.

### (vi-bis) `servletFlavor` — POR ENVIRONMENT, não no record (correção v5 — achado glm A4)
O sabor (Jakarta vs javax = Tomcat/JDK distintos) é atributo **do environment**, não da família. Uma KB pode ter env Jakarta **e** env javax. Portanto:
- **Metadata por-env:** novo campo `kb_environment_servlet_flavor` (irmão de `kb_environment_servlet_dirs`/`kb_environment_app_package`), valor `jakarta` | `javax`, gravado pelo setup por env Java.
- **Marcação de proveniência empírica por-env:** `certified` | `not-audited` (o env aferido EBTECH/Jakarta = `certified`; qualquer env javax = `not-audited` até a Fase 5).
- **Record `java-tomcat`:** guarda só a **enumeração de sabores suportados** pela família (`{jakarta, javax}`) — não a marcação empírica.
- **Self-test** assere que um env Java recém-registrado sem aferição carrega `not-audited` (fail-closed: não generalizar suporte além da evidência).
- **Premissa declarada:** um mesmo environment tem **um** sabor (Tomcat/JDK são do env). A coexistência é entre **envs distintos** da mesma KB, cada um com seu flavor.

### (vii) Sentinela — presença, fora da raiz de evidência
`GeneXus.jar` (em `WEB-INF\lib`, irmão de `WEB-INF\classes`) = presença. Ausente → `unknown` (config-error), nunca `stale`. Preservar `dotnet-framework-iis` = `sentinel=$null` **e** `supported`.

### (vii-bis) Duas árvores em `...CoreJava`
Recebe raiz local de fonte (`web\src\main\java`, para Lf) + raiz externa de deploy (`WEB-INF\classes`, para Pf). `outputModelSubPath` permanece a raiz do **fonte** (Eixo C/B Pós-v1).

### (viii) Split de estado PER-EIXO + INVENTÁRIO (código E documentação)
Quebrar o estado único: `deployBinSupportState` (Eixo A; Java→`supported`), `runtimeSupportState` (Eixo C), `sourceSupportState` (Eixo B) (C/B Java = `recognized-no-engine` até Pós-v1).

**Inventário — 8 sítios de CÓDIGO** (cada um migra ao campo do seu eixo): policy `GeneXusKbDeployBinSupport.ps1:106`→A; fachada `Test-GeneXusDeployBinFreshness.ps1:156`→A; guarda C `Test-GeneXusRuntimeFreshness.ps1:128`→C; guarda B `Resolve-GeneXusGeneratedCsPath.ps1:196`→B; asserts drift `Test-...DriftSelfTest.ps1:105,120,132`; assert roteamento `Test-GeneXusDeployBinHostingKindRoutingSelfTest.ps1:51`; golden `Test-...DotNetGoldenSelfTest.ps1`.

**Inventário — sítios de DOCUMENTAÇÃO a migrar (correção v5 — achado glm A6; a varredura real por `runsFreshnessEngine` deu ~27 matches):** `02-regras-operacionais-e-runtime.md:163` (a regra operacional "discriminador é o booleano `runsFreshnessEngine`" **muda** com o split per-eixo — `AGENTS.md` exige alinhar o `02`); `09-inventario-e-rastreabilidade-publica.md:~208-213`; `xpz-kb-parallel-setup/SKILL.md:252`. **`CHANGELOG.md`** menciona `runsFreshnessEngine` em entradas históricas da Fase 2 — **não reescrever histórico**; só a documentação **normativa viva** (02/09/SKILL) migra. A pré-push semântica (doc 13) deve pegar isto; registrar como parte da Fase 3, não só "citações genéricas em `.md`".

**Remoção de `runsFreshnessEngine` = gate de implementação por varredura real** (cobrir acesso por membro, splat/reflection, `.example.ps1`, `.md`). Self-test trava "Java: A=supported, C/B=recognized-no-engine".

**Migração-compat: mudança do contrato de SAÍDA + consumidores EXTERNOS (correção v10 — achado kimi #2; rotina do doc 13 pré-push):** o split não é só interno — ele vira `java-tomcat` de `recognized-no-engine` (skip: `status='skipped-hosting-unsupported'`, exit 0) para `supported` (o motor Java **roda** e pode emitir `fresh`/`stale`/`unexpected-publication`/`unknown` + exit de gate). Isso **muda o comportamento de saída** que consumidores da **fachada** (`Test-GeneXusDeployBinFreshness.ps1`) veem para KBs Java — inclusive **wrappers em pastas paralelas de KB**, fora do escopo da varredura deste repo. A **rotina do doc `13-revisao-pre-push.md`** (pré-push semântica: **paridade motor↔doc** + varredura de consumidores) aplica: antes do push, **verificar consumo externo** do contrato (campo `runsFreshnessEngine` direto e o `status` de saída para `java-tomcat`). **Havendo consumo externo, o alias derivado de `deployBinSupportState` DEVE ser mantido por um ciclo de release, com deprecation warning** (correção v10 — reforço deepseek R3): é diretiva, não preferência, porque a fase semântica do doc 13 varre **apenas este** repo — wrappers em pastas paralelas de KB ficam **fora** desse alcance, então o alias por um ciclo é a **única salvaguarda real** para esses consumidores que a varredura estática não vê. O check de drift do doc 13 no mesmo PR cobre os consumidores **internos**; o alias cobre os **externos**. Não é decisão nova de arquitetura — é a **estratégia de migração** do breaking change já previsto em (viii), agora com a dimensão de consumidor externo explícita.

### (ix) §9 no-bridge — RESOLVIDO: allowlist textual invertida (Posição B; AST→999)
**Adjudicação do painel (síntese do orquestrador):** a invariante guarda os arquivos de **Fase 1/2**, que **não têm razão legítima de citar** `publicationTargets`; para eles, "**zero ocorrências**" é uma checagem **completa e mais estrita** que AST (o AST *afrouxaria*, tolerando menções em comentário/string). O AST só agregaria valor na ponta **motor** — que é onde a invariante **permite** o uso, logo não é guardada; e mesmo acesso dinâmico (`$rec.$campo`) deixa o literal no arquivo. Logo:
- **Inverter** a exclusão da §9: de denylist (token proibido fora de registro+self) para **allowlist de arquivos-motor** que **podem** citar/iterar o token (registro, self-test, golden, `...CoreJava`/motor de deploy-bin, fachada, e qualquer gêmeo Java da Fase 5). Assertar que **todo outro `*.ps1` tem zero ocorrências** — arquivo de Fase 1/2 novo cai em "todo outro" e fica guardado por padrão.
- **Fail-closed:** esquecer de allowlistar um arquivo-motor novo → falso-ofensor no CI (visível no PR), não fail-open. A allowlist cresce **um arquivo por PR** conscientemente.
- **Guarda de drift da PRÓPRIA allowlist (correção v7 — achado glm R4):** um self-test deve assertar que a allowlist da §9 **== o conjunto de arquivos-motor ativos** (os que legitimamente citam/iteram `publicationTargets`). Sem isso, a allowlist desatualiza em silêncio: um arquivo-motor **renomeado** vira falso-ofensor (entrada obsoleta aponta para nome inexistente e o novo nome não está listado); um arquivo-motor **removido** deixa uma entrada morta que "permite" um arquivo que não existe. A guarda mantém a allowlist sincronizada com a realidade do repo, não por stare-decisis.
- **AST → `999`** como endurecimento futuro (reusar o padrão de `XpzWrapperEngineParamSupport.ps1` para distinguir citar-vs-iterar), **se** algum dia um arquivo de Fase 1/2 precisar legitimamente mencionar o token. Não é necessário para a Fase 3.
- Nota mecânica: a §9 atual já usa exclusão textual por arquivo (`:315-332`); a mudança é **inverter** a lista + adicionar os arquivos-motor.

### (x) Aliasing — construir arrays Java do zero
Java ganha **arrays novos** (literais próprios), nunca por mutação de cópia rasa dos `$dotnet*`. Self-test trava `[object]::ReferenceEquals(java, dotnet) == $false`.

---

## 4. Guarda de regressão e testes novos
- **Regressão .NET por CONTRATO ESTRUTURAL:** golden compara saída estrutural suficiente (formato de `status`, `paths`/`binCheck`/`diagnosticLayer`, severidade, `exitCode` 49, `slack`, `framework-iis` sem sentinela, exclusão por nome, `-or configFresh`) — **saída canonicalizada** (`ToString('o')` culture-invariante, ordem de chaves de `[ordered]@{}` estável) para não quebrar por normalização ambiental. O `...CoreDotNet` extraído **não** altera o `ToString('o')` atual.
- **Self-tests novos Java** (fixtures ancorados no evidence-catalog EBTECH/Jakarta): alvo externo B1 + validação de topologia; resolução de `<kb>` via `kb_environment_app_package` + falha→`unknown`; **co-gate de 4 quadrantes por conjunto de artefatos** — `fresh` (`Lf≠∅⊆Pf`), `stale` (parcial), `no-evidence` (`∅,∅` não falha), `unexpected-publication` (`∅,≠∅` não sai fresh), **stub-only** (mudança de assinatura só no stub → objeto entra em Lf/Pf), `Pf\Lf` reportado; config-error `unknown` falha; **skew bidirecional** — Tomcat-adiantado (`.class` do futuro excluído de Pf → não vira falso-fresh) **e** (correção v10 — kimi #7) **Tomcat-atrasado** (`.class` legítimo com mtime abaixo de `threshold_inf` → falso-stale por ruído; testar que o `slack` inferior o tolera e que o diagnóstico distingue "fora da janela inferior" de "ausente"); sentinela-presença; split per-eixo + migração dos 8 sítios; `servletFlavor` per-env `not-audited` por default; §9 allowlist-invertida (falso-ofensor se motor novo não allowlistado) **+ guarda de drift da própria allowlist** (`assert allowlist == {arquivos-motor ativos}`); aliasing; `...CoreJava` sem `ExcludeDirectoryNames=@('bin')`.
- **Self-tests de borda do strip condicional (correção v8 — kimi item 4, verifica a correção R5; + caso (d) v9 — Opus):** (a) objeto `foo` com `foo.class`+`foo_impl.class`+`foo__default.class` no mesmo subpacote → **agrupa** em `foo`; (b) `foo_impl.class` **sem** `foo.class`/`foo.java` no mesmo subpacote → tratado como **objeto próprio** (`foo_impl`), não fundido; (c) homônimos em subpacotes distintos (`com\<kb>\a\foo` vs `com\<kb>\b\foo`) → **não** fundidos (chave = caminho relativo completo); **(d) sufixo FORA do conjunto fechado** (`foo_novo.class`, sufixo `_novo` não catalogado) → **vira objeto próprio** (`foo_novo`), gate **mais estrito** — trava no self-test a direção fail-safe que o texto do (v-bis) hoje só declara em prosa. Sem esses testes a correção R5 (e a propriedade fail-safe do sufixo desconhecido) pode regredir silenciosamente na implementação.
- **Self-test do fallback conservativo de âncora (correção v8 — kimi item 3):** exercitar explicitamente o caso **"`threshold_sup` cedo demais"** (âncora superior anterior à publicação real — deploy assíncrono, ou `BuildEndedAt` usado como fallback quando `DeployStepCompletedAt` inexiste): o `.class` legítimo cai **acima** da janela → resultado deve ser **`stale`/`no-evidence`**, **nunca `fresh`**. Trava a propriedade de segurança "a incerteza de âncora só gera ruído (falso-stale), nunca falso-fresh".
- **Método de fixture dos self-tests temporais (nota v9 — deepseek rec 1; + resolução de FS v10 — kimi #5):** os self-tests que dependem de mtime (co-gate, skew bidirecional, fallback de âncora) constroem os fixtures por **`LastWriteTime` forjado** (via `Set-ItemProperty`/`(Get-Item).LastWriteTime = ...`), o **mesmo método já usado pelos self-tests de deploy-bin .NET existentes** — reuso, não infra nova. **Rodar em NTFS/ReFS** (resolução de mtime sub-segundo): em FAT/exFAT a resolução é de **2s** e mascararia os deltas de skew/threshold — se inevitável, ajustar o `slack` de teste para ≥2s. Documentar o método na implementação para a Fase 5 reproduzir com dados reais.
- **Fase 5 (gêmeos empíricos Java) = frente própria**; precisa da KB Java da colega. Itens empíricos herdados: (i) `Rebuild All`/clean-build produz `Lf=∅,Pf≠∅`? (ii) latência fim-Gradle→deploy (default de `slack`); (iii) sabor `javax` (sentinela `GeneXus.jar` existe?); (iv) **ator da cópia** ao `WEB-INF\classes` (define se `DeployStepCompletedAt` é observável no `timing` do MSBuild); (v) **validar o conjunto fechado de sufixos** `{_impl, __default, __gam}` contra tipos variados de objeto — **Work With, Business Component, SDT, Procedure, Data Provider** — atento a possíveis sufixos não catalogados (ex.: `__ww`, `__bc`); a cobertura atual é só a amostra EBTECH (correção v9 — deepseek rec 2). Até a validação, o fail-safe do (v-bis) (sufixo desconhecido → objeto próprio) protege na direção segura.

## 5. Fora de escopo da Fase 3
Motores Eixos B/C em Java = Pós-v1; `.war` = aterramento próprio; migração de alvo .NET→Java = decisão humana; §9 por AST = endurecimento futuro (`999`); âncora de tempo do deploy para skew grande = follow-up (`999`/Fase 5).

---

## Mudanças v4→v5 (mapa ← achado da rodada v4)

| # | Mudança v5 | Onde | Achado v4 |
|---|---|---|---|
| 1 | **Co-gate por CONJUNTO DE ARTEFATOS do objeto** (max mtime sobre stub+impl+auxiliares; chave = caminho relativo completo) — fecha mudança **stub-only** e objetos sem `_impl` | (v-bis), (1.3) | **glm A3** + Opus + kimi (identificador por path) |
| 2 | **Skew BIDIRECIONAL** (limiar inferior E superior; âncora de deploy quando houver) — fecha o **falso-fresh** por Tomcat-adiantado | (v-ter) | **glm A2 (CRÍTICO segurança)** |
| 3 | **Política declarada do `unexpected-publication`** (fail-safe de origem não atestável; mensagem acionável) + Q5a citado (incremental no-op não toca externo) + `Rebuild All` → Fase 5 | (v-bis), (1.4) | **glm A1** |
| 4 | **`servletFlavor` por-ENV** (metadata `kb_environment_servlet_flavor` + marcação `certified`/`not-audited`); record guarda só a enumeração | (vi-bis) | **glm A4** |
| 5 | **Inventário documental** explícito (02:163, 09:~208-213, SKILL.md:252; CHANGELOG não reescrito) | (viii) | **glm A6** |
| 6 | **§9 RESOLVIDA = Posição B** (allowlist textual invertida, fail-closed; AST→999) | (ix) | adjudicação 3A/2B → síntese por mérito |
| 7 | **`Pf \ Lf` diagnosticado** + racional da assimetria; **`Pf` = subconjunto fresco** explícito | (v-bis) | Codex/Opus + deepseek (ambiguidade de `Pf`) |
| 8 | **`deployBinTimeSlackSeconds` no registro**, default 5 provisório | (v-ter),(vi) | deepseek (onde) + glm A7 (justificar default) |
| 9 | **Golden culture-invariante** + ordem de chaves | §4 | glm A9 |
| 10 | Consistência Tomcat 10.1 (version) / dir "Tomcat 11" | §1 | glm A8 |

## Mudanças v5→v6 (mapa ← ressalva de papel-menor da rodada v5, Opus/Codex)

| # | Mudança v6 | Onde | Ressalva v5 |
|---|---|---|---|
| 1 | **Âncora de skew preferida-por-design** = `DeployStepCompletedAt + slack` (fim da publicação); `BuildEndedAt + slack` = **fallback explícito** (evita a preferência invertida que gerava falso-stale em deploy assíncrono). Só a **existência** do campo é Fase 5 | (v-ter) | Opus foco 2 (insistido em papel) |
| 2 | **Lista FECHADA de sufixos-artefato** `{_impl, __default, __gam}` (amostra EBTECH); sufixo desconhecido = parte do nome-base (fail-safe: não funde) | (v-bis) | Opus foco 1b |
| 3 | **Diagnóstico distingue "fora da janela superior" (suspeita de skew) de "ausente" (publicação parcial)** | (v-ter) | Codex (refinamento de impl) |

## Mudanças v6→v7 (mapa ← achado da rodada v6, glm)

| # | Mudança v7 | Onde | Achado v6 |
|---|---|---|---|
| R5 | **Precisão do strip de sufixos:** corrige a afirmação falsa ("`foo_impl` não é fundido com `foo`" era errada p/ sufixo conhecido); o que evita a fusão é premissa de nomenclatura GeneXus (Fase 5) + guarda de **strip condicional** (só stripa se existe stub-base no subpacote) | (v-bis) | **glm R5 (precisão real)** |
| R1 | **Premissa do ator da cópia** (MSBuild? gradlew? auto-deploy?) — decide se `DeployStepCompletedAt` é observável; se não, fallback é a âncora de fato, com falha conservativa; ator → Fase 5 | (v-ter) | glm R1 |
| R3 | **Teto honesto da recompilação transitiva** (`Pf\Lf` pode subnotificar impacto de API upstream; não-falso-fresh) | (v-bis) | glm R3 |
| R4 | **Guarda de drift da própria allowlist da §9** (`assert allowlist == {arquivos-motor ativos}`) | (ix), §4 | glm R4 |
| R6 | **Nota de mascaramento sob skew** (`unexpected-publication`→`no-evidence` quando `.class` de build anterior fica > threshold_sup; não-falso-fresh; sinalizar suspeita de skew) | (v-ter) | glm R6 |

## Mudanças v7→v8 (mapa ← ressalva útil de implementação/self-test da rodada v7, kimi)

| # | Mudança v8 | Onde | Ressalva v7 |
|---|---|---|---|
| 1 | **Self-tests de borda do strip condicional** (agrupa com stub-base; `foo_impl` sem `foo.class` = objeto próprio; homônimos em subpacotes ≠ fundidos) — amarram a correção R5 no teste | §4 | kimi item 4 |
| 2 | **Self-test do fallback conservativo de âncora** (`threshold_sup` cedo demais → sempre `stale`/`no-evidence`, nunca `fresh`) | §4 | kimi item 3 |
| 3 | **Redação acionável do `Pf\Lf`** (enquadrar como informativo/recompilação transitiva, não como falha) | (v-bis) | kimi item 5 |

(Os demais pontos do kimi — varredura real de consumidores/`runsFreshnessEngine`; campos per-eixo tangíveis; reescrever `02:163` no mesmo PR — **já constavam** do v7 nos sub-passos (i)/(viii); ficam como checklist da implementação.)

## Mudanças v8→v9 (mapa ← recomendação não-bloqueante do painel na rodada v8)

| # | Mudança v9 | Onde | Recomendação v8 |
|---|---|---|---|
| 1 | **4º caso de borda do strip:** sufixo FORA do conjunto fechado (`foo_novo`) → vira objeto próprio, gate mais estrito — trava no self-test a direção fail-safe que o (v-bis) só declarava em prosa | §4 | Opus (reforço opcional) |
| 2 | **Nota do método de fixture temporal** (`LastWriteTime` forjado, como nos self-tests .NET existentes) | §4 | deepseek rec 1 |
| 3 | **Validação de sufixos por tipo de objeto na Fase 5** (WW/BC/SDT/Procedure/DP; sufixos como `__ww`/`__bc`) | §4 Fase 5 (v) | deepseek rec 2 |
| 4 | **Validação cruzada do contrato `publicationTargets`** (`subPath=$null` p/ external; `externalTargetKey`/`appPackageKey`/sentinel obrigatórios) | (iv) | deepseek rec 3 |

## Mudanças v9→v10 (mapa ← achado da rodada v9, kimi)

| # | Mudança v10 | Onde | Achado v9 |
|---|---|---|---|
| 1 | **Migração-compat: mudança do contrato de saída + consumidores EXTERNOS** — o split vira `java-tomcat` de skip→motor, mudando a saída p/ wrappers de pastas paralelas; rotina do doc `13-revisao-pre-push.md` (paridade motor↔doc); alias derivado por um ciclo como salvaguarda p/ consumo externo fora do alcance da varredura | (viii) | **kimi #2 (migração/compat — único de spec)** |
| 2 | **Self-test cobre Tomcat-atrasado** (limiar inferior; distinguir "fora da janela inferior" de "ausente") | §4 | kimi #7 |
| 3 | **Nota de resolução de FS** nos self-tests temporais (NTFS/ReFS; FAT/exFAT = 2s mascara skew) | §4 | kimi #5 |

(Os demais achados do kimi — #1 localização da validação cruzada, #3 rename `unexpected-publication`→`unattested-publication`, #4 nota de diagnóstico do strip, #6 teto do dump de `Pf\Lf` — ficam no **checklist de implementação**, não na spec.)
