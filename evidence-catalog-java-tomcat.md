# Evidence catalog — GeneXus Java/Tomcat (Fase 0, aterramento empírico)

> **Status:** Fase 0 concluída **com um gap declarado** (Q5b — o re-teste controlado de 2026-07-04 ficou inconclusivo por sonda no-op; ver Q5). **VEREDITO: Plano B acionado** — a topologia real do deploy Java/Tomcat é **externa** à árvore de output, invalidando a hipótese *in-place* que o design congelou para o motor da Fase 3 (ver [`java-tomcat-paridade-gerador-design.md`](java-tomcat-paridade-gerador-design.md), seção "Congelamento vale para a hipótese in-place"). O resto do design **não** reabre.
>
> **Data da coleta:** 2026-07-04. **Registro-resumo:** [`999-ideias-pendentes.md`](999-ideias-pendentes.md).

## Fonte da evidência

- Coleta feita por um agente numa **máquina de terceiro** (a máquina de dev **não tem licença Java**; build local impossível). Modo **read-only** (nenhum build rodado — daí o gap Q4/Q5).
- **KB observada:** `EBTECH`. **GeneXus:** 18 Upgrade 14. **Environment Java:** `Prototipo_18U14`. **KB nativa:** `C:\Applications\GeneXus\18U14_IA\EBTECH`.
- **Sabor Java observado:** `JAKARTA_EE` / `TOMCAT_10_1` / JDK 21 / namespace `jakarta.*` / build **Gradle** / DataStore PostgreSQL.
- **Ressalva de generalização:** é **uma** KB Java, no sabor **Jakarta**. O env Java da `wsEducacaoSpTeste` (não buildável aqui) é do **outro sabor** — `JAVA_EE` / `TOMCAT_8_9` / JDK 8 / namespace `javax.*`. Os nomes de jar de runtime diferem entre os dois sabores (`jakarta.*` vs `javax.*`). A família `java-tomcat` precisa ser **namespace-agnóstica** ou cobrir os dois sabores — ver "Itens abertos".

---

## Veredito de topologia: EXTERNO (in-place ✗)

Existem **duas árvores distintas**, em volumes diferentes:

| Papel | Caminho | Natureza |
|---|---|---|
| **Workspace de geração+compilação (na KB)** | `C:\Applications\GeneXus\18U14_IA\EBTECH\Prototipo_18U14\web\` | Projeto **Gradle** (`src\main\java`, `build\classes\java\main`, `build\libs`, `build.gradle`, `gradlew`). **Sem `WEB-INF`.** |
| **Webapp servido/publicado (no Tomcat)** | `C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHPrototipo_18U14\` | Layout webapp desdobrado: `WEB-INF\{classes,lib,private}`, `META-INF`, `static`, `themes`, `web.xml`. **Fora da árvore da KB.** |

**Conclusão:** o alvo de publicação (análogo ao `web\bin` do .NET) é **externo** à árvore de output do environment. No .NET, `web\` e `web\bin` coexistem sob o env; no Java/Tomcat, a geração fica na KB e o artefato servido fica no Tomcat. → **Plano B**.

**Ponto forte para a Fase 3:** o alvo externo **é localizável deterministicamente** pelo `model.ini` do env — não é adivinhação. Campos observados:

- `SERVLET_DIR=C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHPrototipo_18U14\WEB-INF\classes`
- `CLIENT_STATIC_DIR=...\EBTECHPrototipo_18U14\static`
- `TOMCAT_PATH=C:\Program Files\Apache Software Foundation\Tomcat 11`
- `WebRoot=http://localhost:8080/EBTECHPrototipo_18U14/`

Esse `SERVLET_DIR` é o análogo Java do `kb_environment_web_dirs`: um futuro gate **lê** o caminho do alvo, não infere subpath relativo ao env.

---

## Respostas Q1–Q7

### Q1 — Árvore de saída pós-build

- **Raiz local (KB):** `...\EBTECH\Prototipo_18U14\` contém `Library`, `migrations`, `state`, `web`.
  - `...\Prototipo_18U14\web\` = projeto Gradle: `src`, `build`, `staticContent`, `themes`, `Resources`, `modules`, `build.gradle`, `gradlew.bat`, `context.xml`, `web.xml`, etc.
  - `...\web\build\` = `classes\java\main`, `generated\sources`, `libs`, `tmp`.
  - **Não há `WEB-INF` na árvore local.**
- **Raiz servida (Tomcat):** `...\webapps\EBTECHPrototipo_18U14\` — é aqui que aparece o layout `WEB-INF`.
  - `WEB-INF\classes\`: pacotes `com`, `genexus`, `qviewer`, `dummy` + `gx_handler_chain.xml`, `log4j2.xml`. **1455 `.class`.**
    - Amostra por objeto em `com\ebtech`: `bbextratoimportar.class`, `bbextratoimportar__default.class`, `bbextratoimportar__gam.class`, `ebt_gamuserentry.class`, `ebt_gamuserentry_impl.class`.
    - **Não é "1 arquivo por objeto":** um objeto gera múltiplas classes auxiliares (`__default`, `__gam`, `_impl`, ...).
  - `WEB-INF\lib\`: **195 `.jar`** (lista de padrões em Q7 e Apêndice).
  - Descritores (timestamp): `WEB-INF\web.xml` 2026-06-29 19:02:41; `META-INF\context.xml` 2026-06-29 19:02:03; `WEB-INF\sun-jaxws.xml` 2026-06-29 19:02:41; `WEB-INF\classes\log4j2.xml` 2026-07-02 19:06:30.
  - Curiosidade (ignorar para frescor): há DLLs nativas no topo do webapp — `GXDIB32.DLL`, `rbuildj.dll` (helpers nativos GeneXus copiados no deploy; **não** são assemblies .NET nem artefato por-objeto).

### Q2 — In-place vs externo

**EXTERNO** (ver veredito de topologia acima). Lado gerado local: `...\Prototipo_18U14\web\build\classes\java\main`. Lado servido: `...\Tomcat 11\webapps\EBTECHPrototipo_18U14\WEB-INF\classes`.

### Q3 — Existe `.war`? Regrava a cada build?

**Não há `.war` da aplicação.** O deploy é **diretório desdobrado (exploded)** em `webapps\`. O único `.war` no Tomcat é a amostra do próprio servidor (`webapps\docs\appdev\sample\sample.war`), não da app. Um `.war` só surgiria via fluxo explícito "Deploy Application" (não observado nesta prototipagem). Logo, no fluxo cotidiano build→run, **não há `.war` para aferir**; o alvo é o webapp exploded.

### Q4 — Qual artefato regrava a cada build (sinal de frescor)

**Os `.class` da aplicação** em `webapps\<app>\WEB-INF\classes\com\<pacote-da-kb>\*.class` (aqui `com\ebtech\`) — **não** os `.jar` de `WEB-INF\lib`.

Evidência **indireta** (por timestamps escalonados, não por teste controlado): objetos diferentes têm mtime diferente conforme foram tocados em builds incrementais distintos — ex.: `ebt_gamuserentry*.class` e `bb_importarextratoconta*.class` em 2026-06-29 19:02:39, enquanto `bbextrato*.class` e `bb_carregarconfiguracaoconta*.class` em 2026-07-02 19:06:29. Isso indica **regravação por objeto alterado** (incremental), consistente com o modelo .NET de "DLL de objeto regrava". O re-teste controlado de 2026-07-04 **não** confirmou nem refutou esse mecanismo (a sonda foi um no-op semântico; ver Q5) — mas os mtimes escalonados acima **provam** que builds reescreveram `.class` de objeto no `WEB-INF\classes` externo em momentos distintos, ou seja, **o sinal de frescor existe**.

### Q5 — Incremental sem mudança vs com mudança

**Re-teste controlado rodado em 2026-07-04 (KB EBTECH, env `Prototipo_18U14`) — resultado PARCIAL/INCONCLUSIVO.** Três builds incrementais com snapshots de mtime das duas árvores (`web\build\classes\java\main` local e `WEB-INF\classes` publicado):

- **Q5a (build SEM mudança → nenhuma reescrita de `.class`):** confirmado — delta zero nas duas árvores. Calibra "sem mudança = unknown, **não** stale". (Corroboração fraca pelos confounders abaixo, mas na direção esperada.)
- **Q5b/Q4 (build COM mudança de 1 objeto → reescrita do `.class` do objeto):** **NÃO respondido.** A mudança aplicada foi um **no-op semântico** (`&isConnectionOK = &isConnectionOK` no evento Start do `WebPanel:EBT_Login`) e também deu **delta zero**. Isso **não** prova ausência de sinal — é artefato da sonda.

**Por que o "delta zero" NÃO é a verdade do frescor Java (confounders, em ordem de força):**

1. **Sonda no-op.** Autoatribuição de variável é eliminada pelo gerador (mecanismo (b)/DCE, documentado na `xpz-msbuild-build`): o `.java` gerado sai **byte-idêntico**. E — achado central — o build Java é **Gradle**, incremental **por conteúdo/hash**, não por timestamp como o MSBuild/.NET: `.java` idêntico ⇒ não recompila ⇒ `.class` não muda de mtime. A sonda nunca forçou um delta de código gerado.
2. **`exitCode 90` (falha de pós-processamento do wrapper) + a lista de fases não menciona COMPILE nem DEPLOY** (para em "Default (Java) Generation" / "Reorganização" / "Close KB"). Não há prova de que o ciclo generate→compile→deploy-para-Tomcat fechou; se rodou generate-only ou abortou antes do compile, nada tocaria `.class` — independentemente da edição.
3. **Reorg em todas as três execuções** (Database Impact Analysis + Reorganização) indica estado estrutural pendente na KB — ruído que desvia do caminho incremental limpo de objeto.

**Prova cruzada de que o sinal existe:** os mtimes escalonados do **primeiro** relatório (`.class` de objetos distintos em 2026-06-29 vs 2026-07-02, ver Q4) mostram que builds reescreveram `.class` de objeto no `WEB-INF\classes` publicado em momentos diferentes. Logo "o deploy nunca atualiza `WEB-INF\classes`" é contraditado pelos próprios dados. O gap Q4/Q5b **permanece aberto**, pendente de um re-teste com mudança que **provadamente** altere o código gerado — ver "Itens abertos".

### Q6 — Sentinela (análogo a `GxNetCoreStartup.dll`)

**SIM: `WEB-INF\lib\GeneXus.jar`** — âncora de runtime GeneXus sempre presente no webapp servido. Auxiliares sempre presentes: `WEB-INF\web.xml` e `WEB-INF\lib\gxweb-4.10.2.jar`. **Sentinela ≠ frescor:** a presença do `GeneXus.jar` marca "é app GeneXus Java", mas o frescor do build são os `.class` de objeto (Q4).

### Q7 — Artefatos de runtime a excluir

**Modelo estruturalmente diferente do .NET.** No .NET, objeto e runtime são ambos `.dll` distinguidos por prefixo (`GeneXus.`/`System.`/`Microsoft.`). No Java observado:

- O **código do objeto é `.class`** sob o pacote da app (`WEB-INF\classes\com\ebtech\...`), **não** empacotado em jar próprio.
- **Todos os 195 `.jar` de `WEB-INF\lib` são runtime/dependência.**
- Logo, a **exclusão em Java é por pacote**, não por prefixo de nome de jar: para "objeto publicado", **manter** o pacote da app (`com.<kb>`) e **excluir** pacotes de framework em `WEB-INF\classes` (`com\genexus`, `qviewer`, `dummy`, ...). Os `.jar` de `lib` são **integralmente** runtime (excluídos por definição, pois não contêm código de objeto).

Padrões de nome de jar GeneXus/runtime observados (referência; distilação da lista de 195 no Apêndice):

- **GeneXus/WWP/segurança:** `GeneXus*.jar`, `gx*.jar` (`gxclassR-*`, `gxcommon-*`, `gxweb-*`, `gxwrapper*-*`, ...), `genexus.security-postgresql.jar`, `QueryViewerServices*.jar`, `SecurityAPICommons.jar`/`securityapicommons-*.jar`, `WorkWithPlus_*.jar`, `WebExtensionToolkit.jar`, `ExternalObjects.jar`, `gamsaml20-*.jar`/`gamtotp-*.jar`/`gamutils-*.jar`, `GXzip.jar`.
- **Terceiros:** `jakarta.*`, `jersey-*`, `grpc-*`, `netty-*`, `jackson-*`, `commons-*`, `poi-*`, `postgresql-*`, `log4j-*`, `protobuf-*`, `opentelemetry-*`, `opensaml-*`, `xercesImpl-*`, `xmlbeans-*`, `woodstox-*`, `bcprov-*`/`bcpkix-*`/`bcutil-*`, `lucene-*`, `jaxb-*`/`jaxws-*`/`saaj-*`, etc.

### Onde vive o fonte Java gerado (para Eixo B, Pós-v1)

`...\EBTECH\Prototipo_18U14\web\src\main\java\com\ebtech\*.java` (**655 `.java`**). Exemplos: `ebt_home.java`, `ebt_home_impl.java`, `ebt_login.java`, `gamapplicationentry.java`, `ebt_gamuserentry.java`/`ebt_gamuserentry_impl.java`.

**Divergência importante:** o `.java` gerado vive na árvore **local** da KB (`web\src\main\java`), enquanto o `.class` de frescor de deploy (Eixo A) vive na árvore **externa** do Tomcat (`WEB-INF\classes`). No .NET, `.cs` (Eixo B) e `web\bin\*.dll` (Eixo A) ficam ambos sob o env. Em Java, **Eixo A e Eixo B leem árvores diferentes e em volumes diferentes**.

---

## Implicações para o contrato do registro e a Fase 3 (Plano B)

O aterramento confirma que a Fase 3 **é replanejada** (não apenas parametrizada). Impactos concretos no contrato de `GeneXusKbHostingKindSupport.ps1`:

1. **`deployTargetKind = external-webapp`** para `java-tomcat` (empírico), não o default `in-kb-web` do v1.
2. **`publicationTargets[].subPath` não se aplica** ao Java: o alvo é um **caminho absoluto externo** (do `SERVLET_DIR` do `model.ini`), não um subpath relativo ao env. Isso exige, na Fase 3, resolução de alvo **externo/absoluto** — implicação de schema, não só de valor.
3. **Estratégia de evidência (`evidenceStrategy`) Java:** max mtime dos **`.class` do pacote da app** sob o `WEB-INF\classes` **externo**, **excluindo pacotes de framework** — em vez de `.dll` de objeto + `.config` em `web\bin`.
4. **Exclusão por pacote, não por prefixo de jar** (`runtimeExclusionPrefixes` não mapeia 1:1): o eixo de exclusão Java opera sobre **pastas de pacote** em `WEB-INF\classes`, e trata `WEB-INF\lib\*.jar` como runtime por definição.
5. **`sentinel` = `GeneXus.jar`** (no `WEB-INF\lib` externo), com `web.xml`/`gxweb-*.jar` auxiliares.
6. **Sem `.war`** no fluxo cotidiano — o gate afere o **webapp exploded**, não um pacote `.war` (o `.war` seria um fluxo de deploy separado a modelar à parte, se algum dia entrar no escopo).
7. **`outputModelSubPath` provavelmente precisa desdobrar** em Java: raiz do fonte gerado (`web\src\main\java`, local) ≠ raiz do artefato de deploy (`WEB-INF\classes`, externo).
8. **Build Java = Gradle (incremental por conteúdo/hash), não por timestamp** como o MSBuild/.NET (achado do re-teste de 2026-07-04, ver Q5). O Gradle só reescreve o que muda de **conteúdo** — um objeto reeditado com código gerado idêntico (ex.: no-op eliminado por DCE) **não** bumpa o mtime do `.class`. Um gate de frescor Java keyed em mtime herda essa semântica: precisa ser desenhado ciente de que "mtime não avançou" pode significar "conteúdo idêntico, não recompilado" e não necessariamente "build não rodou". Divergência de fundo frente ao modelo .NET a tratar na Fase 3.

Nada disso reabre as decisões (a)–(e) nem a cláusula no-bridge; é o replanejamento da Fase 3 já autorizado pela cláusula de Plano B.

---

## Itens abertos

- **Gap Q4/Q5b (ainda ABERTO após o re-teste de 2026-07-04):** Q5a (sem mudança → sem reescrita) ficou corroborado, mas Q5b (mudança de 1 objeto → reescrita do seu `.class`) **não** foi respondido — a sonda foi um no-op semântico (delta zero por artefato, não por ausência de sinal; ver Q5). **Re-teste decisivo necessário**, removendo os confounders: (i) mudança que **provadamente** altere o código gerado (ex.: trocar um literal de texto exibido na tela, não uma autoatribuição); (ii) usar **BuildAll** (specify+generate+**compile**), confirmando que a fase de compile+deploy rodou e que exit não foi só `90` de pós-processamento; (iii) snapshotar **também** o `.java` gerado (`web\src\main\java\com\<kb>\<obj>.java`), não só os `.class`, para separar "gerou diferente" de "recompilou". Requer build na máquina da colega, com ok dela e edição reversível. Prompt do re-teste decisivo preparado nesta frente.
- **Dois sabores Java (Jakarta vs javax):** a evidência é do sabor `JAKARTA_EE`/`jakarta.*`. O sabor `JAVA_EE`/`javax.*` (ex.: env Java da `wsEducacaoSpTeste`, Tomcat 8/9, JDK 8) tem nomes de jar de runtime distintos. A família `java-tomcat` deve ser namespace-agnóstica ou cobrir os dois. Não força mudança de design agora; é aviso para a Fase 3.
- **`.war` (fluxo de deploy explícito):** não observado; se um dia o escopo incluir deploy empacotado, exige aterramento próprio.

---

## Apêndice — dados brutos (do relatório de coleta)

### Config do env (`model.ini`, env `Prototipo_18U14`)

```
Model=Prototipo_18U14
TargetFullPath=C:\Applications\GeneXus\18U14_IA\EBTECH\Prototipo_18U14
DataStore=Default (PostgreSQL)
GeneratorType=JavaWeb
TOMCAT_VERSION=TOMCAT_10_1
JAVA_PLATFORM_SUPPORT=JAKARTA_EE
TOMCAT_PATH=C:\Program Files\Apache Software Foundation\Tomcat 11
SERVLET_DIR=...\webapps\EBTECHPrototipo_18U14\WEB-INF\classes
CLIENT_STATIC_DIR=...\webapps\EBTECHPrototipo_18U14\static
JAVA_EXE_PATH=C:\Program Files\Java\jdk-21\bin\java.exe
JDK_DIR_JAVA=C:\Program Files\Java\jdk-21
CompilerJava=C:\Program Files\Java\jdk-21\bin\javac.exe
Make=...\Prototipo_18U14\web\GXJMake.exe
GradleOptionsJava=-Dorg.gradle.jvmargs=-Xmx1024m
WebRoot=http://localhost:8080/EBTECHPrototipo_18U14/
```

### Contagens observadas

| Métrica | Valor |
|---|---|
| `.java` gerados em `web\src\main\java` | 655 |
| `.class` em `web\build\classes\java\main` (local) | 894 |
| `.class` em `WEB-INF\classes` (publicado) | 1455 |
| `.jar` em `WEB-INF\lib` (publicado) | 195 |

(A diferença 894 local vs 1455 publicado: o publicado é superconjunto — inclui classes de framework/GAM além do módulo da app.)

### Timestamps de raízes (local vs publicado)

Local (KB) — mais antigos:
```
...\Prototipo_18U14                             2026-05-06 18:00:23
...\Prototipo_18U14\web                         2026-06-17 18:50:13
...\Prototipo_18U14\web\build\classes\java\main 2026-05-04 18:15:46
...\Prototipo_18U14\web\src\main\java           2026-05-04 18:03:54
```
Publicado (Tomcat) — mais recentes:
```
...\webapps\EBTECHPrototipo_18U14                 2026-06-29 19:01:58
...\EBTECHPrototipo_18U14\WEB-INF                  2026-06-29 19:02:41
...\EBTECHPrototipo_18U14\WEB-INF\classes          2026-06-30 17:35:38
...\EBTECHPrototipo_18U14\WEB-INF\lib              2026-07-02 19:06:15
...\EBTECHPrototipo_18U14\static                   2026-07-02 19:06:26
```

### Amostra de `.class` por objeto (mtimes escalonados = incremental)

```
bb_carregarconfiguracaoconta.class          2026-07-02 19:06:29
bb_carregarconfiguracaoconta__default.class 2026-07-02 19:06:29
bb_importarextratoconta.class               2026-06-29 19:02:39
bb_importarextratoconta__gam.class          2026-06-29 19:02:39
bbextratoimportar.class                     2026-07-02 19:06:29
ebt_gamuserentry_impl.class                 2026-06-29 19:02:39
```

> A lista completa dos 195 `.jar` de `WEB-INF\lib` está no relatório de coleta original (não replicada aqui); os padrões de exclusão em Q7 são a distilação operacional.
