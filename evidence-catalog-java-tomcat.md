# Evidence catalog — GeneXus Java/Tomcat (Fase 0, aterramento empírico)

> **Status:** Fase 0 **concluída** (Q5b **confirmado** pelo re-teste controlado decisivo de 2026-07-04, rota manual pela IDE; ver Q5). **VEREDITO: Plano B acionado** — a topologia real do deploy Java/Tomcat é **externa** à árvore de output, invalidando a hipótese *in-place* que o design congelou para o motor da Fase 3 (ver [`java-tomcat-paridade-gerador-design.md`](java-tomcat-paridade-gerador-design.md), seção "Congelamento vale para a hipótese in-place"). O resto do design **não** reabre.
>
> **Fase 5 (2026-07-07):** medições na KB `EBTECH` confirmaram o ator da publicação (`gradlew`/Gradle chamado pelo Build All, tarefas `copyTomcat*`) e fecharam, para Jakarta, `Rebuild All -> Lf=∅, Pf≠∅` em rodada limpa dedicada (`Lf=0`, `Pf=624`). A opção GeneXus `JAVA_EE`/`javaEE` também foi medida no environment `JavaEE`, mas no stack real disponível (Tomcat 11/JDK 21/Servlet 6, com sinais `javax` e também jars `jakarta.*`), não em Java EE clássico puro Tomcat 8/9 + JDK 8. Ver seções "Fase 5 parcial", "Fase 5 rodada 2" e "Fase 5 JavaEE/javax".
>
> **Eixos B/C (2026-07-09):** coleta read-only na mesma KB `EBTECH` confirmou a raiz de fonte Java por environment (`<TargetFullPath>\web\src\main\java`), o uso prático de `JAVA_PACKAGE_NAME_FOLDER` e o mapeamento de módulos GeneXus para subpackages (`GestaoMail.Email` -> `com\ebtech\gestaomail`). Para o Eixo C, `nav_objs.xml` existe na raiz da KB nativa e trouxe `ObjStatus=genreq`/`nogenspc`, com `ObjNavig` apontando para XMLs de navegação/specification. Experimento controlado posterior em KB descartável/de teste (`WebPanel:TestWP`, env `Prototipo_18U14`) mostrou que `ObjStatus=genreq` não é critério isolado de freshness; o caminho operacional é cruzar `ObjNavig`, XML de navegação/specification e artefatos locais `.java`/`.class`/`.js`.
>
> **Coletas:** inicial 2026-07-04; Fase 5 2026-07-07; Eixos B/C 2026-07-09. **Registro-resumo:** [`999-ideias-pendentes.md`](999-ideias-pendentes.md).

## Fonte da evidência

- Coleta feita por um agente numa **máquina de terceiro** (a máquina de dev **não tem licença Java**; build local impossível). Modo **read-only** na coleta inicial; os re-testes de frescor (Q5, rota manual pela IDE) **rodaram builds** na máquina da colega — Q4/Q5 fechados.
- **KB observada:** `EBTECH`. **GeneXus:** 18 Upgrade 14. **Environment Java:** `Prototipo_18U14`. **KB nativa:** `C:\Applications\GeneXus\18U14_IA\EBTECH`.
- **Sabor Java observado:** `JAKARTA_EE` / `TOMCAT_10_1` / JDK 21 / namespace `jakarta.*` / build **Gradle** / DataStore PostgreSQL.
- **Ressalva de generalização:** a Fase 0 original era **uma** KB Java, no sabor **Jakarta**. Na Fase 5, a mesma KB `EBTECH` também teve um environment `JavaEE` medido com `JAVA_PLATFORM_SUPPORT=JAVA_EE`/Gradle `JAVA_PLATFORM=javaEE`, mas no stack Tomcat 11/JDK 21/Servlet 6, com presença simultânea de artefatos `javax` e `jakarta.*`. O stack clássico puro Tomcat 8/9 + JDK 8 segue não medido — ver "Itens abertos".

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

Evidência **indireta** (por timestamps escalonados, não por teste controlado): objetos diferentes têm mtime diferente conforme foram tocados em builds incrementais distintos — ex.: `ebt_gamuserentry*.class` e `bb_importarextratoconta*.class` em 2026-06-29 19:02:39, enquanto `bbextrato*.class` e `bb_carregarconfiguracaoconta*.class` em 2026-07-02 19:06:29. Isso indica **regravação por objeto alterado** (incremental), consistente com o modelo .NET de "DLL de objeto regrava". O re-teste controlado **decisivo** de 2026-07-04 (rota manual pela IDE) **confirmou** o mecanismo (ver Q5): uma mudança real de objeto recompilou o **`<obj>_impl.class`** e atualizou o `.class` publicado no `WEB-INF\classes` externo, com o publicado batendo com o local.

### Q5 — Incremental sem mudança vs com mudança

**Fechado por re-teste controlado decisivo em 2026-07-04 (KB EBTECH, env `Prototipo_18U14`, rota manual pela IDE, sem import).**

**Tentativas anteriores (contexto):** a 1ª (2026-07-04) foi **inconclusiva por sonda no-op** — a mudança `&isConnectionOK = &isConnectionOK` no Start do `WebPanel:EBT_Login` foi eliminada pelo gerador (DCE) → `.java` gerado idêntico → nada tocado (**delta zero por artefato da sonda**, não ausência de sinal). Uma 2ª tentativa ficou barrada por uma **reorg de banco pré-existente** da KB (ruído estrutural, não do frescor). Lição transportável: em Java, quem é content-aware é a **geração GeneXus** — um no-op que gera código idêntico não propaga nada.

**Tentativa decisiva — CONFIRMADA.** Com a KB restaurada e limpa (BuildAll sem mudança rodou **sem reorg**, exitCode 0, BuildAllDone true — reconfirma Q5a), inseriu-se pela **IDE** `msg("FASE0-PROBE-20260704")` no Start do `EBT_Login` (mudança real, resistente a DCE). BuildAll com mudança rodou **sem reorg** (Specification + Default (Java) Generation + compilação Java). Resultado por hash+mtime nas três localizações:

| Local | Artefato | Hash ANTES→DEPOIS | mtime avançou |
|---|---|---|---|
| A (`.java` local) | `ebt_login.java` (stub) | **inalterado** | sim |
| A (`.java` local) | `ebt_login_impl.java` (lógica) | **literal apareceu** | sim |
| B (`.class` local) | `ebt_login_impl.class` | **mudou** (`072F8A20…`→`A624A810…`) | sim |
| B (`.class` local) | `ebt_login.class` (stub) | inalterado | sim |
| C (`.class` publicado) | `ebt_login_impl.class` | **mudou; = ao local B** | sim |
| C (`.class` publicado) | `ebt_login.class` (stub) | inalterado | sim |

- **Q5a (build sem mudança → sem stale):** confirmado — os `.class` do objeto ficaram com hash/mtime intactos (2026-06-29) após o BuildAll sem mudança.
- **Q5b (build com mudança → objeto regrava):** **confirmado** — a mudança real propagou **geração → recompile Gradle do `_impl.class` → deploy no `WEB-INF\classes` externo**, com o publicado (C) batendo com o local (B). Um gate de deploy-bin Java keyed no `.class` de objeto sob o `WEB-INF\classes` externo **detectaria** a publicação. Confirma também a **prova cruzada** (mtimes escalonados do 1º relatório): o sinal de frescor **existe** e regrava por objeto.

**Nuances confirmadas (relevantes para a Fase 3):**

- **Split stub/impl:** o objeto gera `<obj>.class`/`<obj>.java` (stub, estável) **+** `<obj>_impl.class`/`_impl.java` (a lógica). O código do evento vive no **`_impl`**; é o `_impl.class` que muda de conteúdo. O artefato portador de frescor é o **`_impl.class`**.
- **mtime avança em TODOS os artefatos do objeto** num build **com** mudança (até nos de conteúdo estável, `<obj>.class`/`.java`), enquanto no build **sem** mudança **nada** é tocado (Q5a). Logo um gate **por mtime** (`.class` de objeto ≥ início do build) é **viável e correto**.
- **Não-determinismo na reversão:** ao remover o `msg` e rebuildar, o `_impl.class` **não** voltou ao hash inicial (recompilação não byte-a-byte determinística). Consequência: o gate deve detectar frescor **por mtime vs início-do-build**, **não** por hash-vs-golden.

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

## Triagem de alvo de deploy (parte C — cláusula de momento)

Snapshot **no instante da decisão**, da KB de **dev `wsEducacaoSpTeste`** (não da KB de aterramento `EBTECH`), por evidência do `kb-source-metadata.md` + `model.ini`:

- Alvo de deploy atual: `deployment_environment_name = NETFrameworkSQLServer`, `deployment_hosting_kind = dotnet-framework-iis` — há env **.NET ativo** como alvo de deploy.
- O env Java (`JavaPostgreSQL208`) é **separado**, nunca o alvo de deploy.
- **Classificação: `e-mantém`** — o .NET continua o alvo; Java fica em environment separado. Declarar `deployment_hosting_kind=java-tomcat` nesta KB **desabilitaria o gate .NET** (regressão, pois o deploy real é .NET). Para esta KB, Java permanece environment de estudo; a metadata **não** deve ser virada para `java-tomcat`.

Ressalva: a evidência de topologia/frescor acima veio da KB `EBTECH` (a máquina de dev não tem licença Java); a triagem de alvo de deploy é da `wsEducacaoSpTeste` e vale para o instante em que foi lida — a cláusula de momento admite que uma decisão futura de migrar o alvo .NET→Java reabra a classificação.

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
8. **Geração GeneXus é content-aware; build Java = Gradle** (confirmado no re-teste decisivo de 2026-07-04, ver Q5). Uma mudança que gera código **idêntico** (no-op eliminado por DCE) não propaga nada; uma mudança **real** regenera o `_impl.java`, o Gradle recompila o `_impl.class` e o deploy o publica — e o **mtime avança em todos os artefatos do objeto** (build sem mudança não toca nada). Um gate de frescor Java **por mtime** (`.class` de objeto ≥ início do build) é **viável e correto**; deve comparar **mtime vs início-do-build**, **não** hash-vs-golden (a recompilação não é byte-determinística — ver Q5).
9. **Frescor por objeto = `<obj>_impl.class`, não `<obj>.class`** (achado do re-teste decisivo). Em Java o objeto se divide em stub (`<obj>.class`/`.java`, estável) + lógica (`<obj>_impl.class`/`_impl.java`, onde o código do evento vive e o conteúdo muda). O motor de frescor da Fase 3 considera o **conjunto** de `.class` do objeto (todos ganham mtime novo no build com mudança), com o `_impl.class` como portador do delta de conteúdo.

Nada disso reabre as decisões (a)–(e) nem a cláusula no-bridge; é o replanejamento da Fase 3 já autorizado pela cláusula de Plano B.

---

## Fase 5 parcial (2026-07-07)

Coleta empírica recebida de agente na máquina da colega, sobre a KB `EBTECH`, `GeneXus 18.0.14.187820+9bf4f24502457696deb48c507d5729eccba7c817`, environment `Prototipo_18U14`, sabor `JAKARTA_EE`, Tomcat `11.0.11`, JDK `21.0.8`.

**Ambiente observado.**

- KB paralela: `C:\Applications\PastasPararelasGenexus\GX_18U14_EBTECH`
- KB nativa: `C:\Applications\GeneXus\18U14\EBTECH`
- `model.ini`: `C:\Applications\GeneXus\18U14\EBTECH\model.ini`
- `TargetFullPath`: `C:\Applications\GeneXus\18U14\EBTECH\Data054`
- Raiz Java usada na medição: `C:\Applications\GeneXus\18U14\EBTECH\Prototipo_18U14\web\src\main\java`
- Raiz local de classes: `C:\Applications\GeneXus\18U14\EBTECH\Prototipo_18U14\web\build\classes\java\main`
- Pacote da app: `com\ebtech`
- `SERVLET_DIR` no `model.ini`: `C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHVersion6Prototipo_18U14\WEB-INF\classes`
- Publicação real observada: `C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHPrototipo_18U14\WEB-INF\classes`

**Achado de metadata.** Nesta coleta, o `SERVLET_DIR` configurado no `model.ini` não existia, enquanto a publicação real estava em outro webapp (`EBTECHPrototipo_18U14`). Portanto, a futura auto-população de `kb_environment_servlet_dirs` pelo `xpz-kb-parallel-setup` não deve copiar cegamente o `SERVLET_DIR`: deve validar existência, topologia `WEB-INF\classes`, sentinela irmã `WEB-INF\lib\GeneXus.jar` e tratar divergência como auditoria/decisão humana.

**Perguntas da Fase 5.**

1. **`Rebuild All`/clean-build forçado produz `Lf=∅, Pf≠∅`?** Negado nesta amostra: a rodada observada teve `Lf=379`, `Pf=624`, `Pf\Lf=245`, `Lf\Pf=0`. Como a própria coleta registra que não executou um novo Rebuild All com frase exata após o pedido e o wrapper terminou com falha operacional por log bloqueado, isso é evidência contra a hipótese, mas não fechamento absoluto.
2. **Latência fim-Gradle -> fim-deploy.** Parcial, amostra única: `compileJava` terminou por volta de `2026-07-07T12:21:12Z`; classes publicadas ficaram entre `2026-07-07T12:22:11.5408214Z` e `2026-07-07T12:22:13.1288486Z`; `BUILD SUCCESSFUL` em `2026-07-07T12:22:18Z`. Observação: cerca de 61s entre fim de `compileJava` e último `.class` publicado; cerca de 1,6s dentro da janela de mtimes das classes publicadas.
3. **Ator da cópia ao `WEB-INF\classes`.** Confirmado: quem publica no Tomcat é o Gradle chamado pelo Build All GeneXus/MSBuild, por tarefas `cleanTomcat`, `copyTomcatLib`, `copyTomcatPackageResources`, `copyTomcatResources`, `copyTomcatStatic`, `copyTomcatClasses`, `copyTomcatWebInf`, `copyTomcat`.
4. **Sabor `javax`.** Não medido: a KB/ambiente desta coleta é Jakarta/Tomcat 11/JDK 21 (`JAKARTA_EE`), não `JAVA_EE`/`javax`.
5. **Sufixos por tipo.** Para stem/stub-base de arquivo, o conjunto observado foi `<base>`, `_impl`, `__default`, `__gam`: `local-java` 624/234/0/0, `local-class` 624/234/225/91, `published-class` 624/234/225/91. Para agrupar sob objeto GeneXus de origem, há stems derivados (`_bc`, `ww*`, `RESTInterfaceIN/OUT`, `services_rest`, `Sdt*`, `StructSdt*`, `StructSdtCol*`); não houve `__ww`, houve `ww` como continuação do nome-base e `_bc`.

**Limitações.**

- A rodada teve sucesso Gradle/deploy observado (`BUILD SUCCESSFUL in 2m 14s`), mas o wrapper reportou `falha operacional`, `exitCode=90`, por leitura de `msbuild.stdout.log` bloqueada por outro processo.
- Há uma única amostra de latência, insuficiente para definir p50/pior caso confiável.
- `javax` segue não medido.
- A pergunta `Rebuild All -> Lf=∅, Pf≠∅` segue pendente de rodada dedicada, se a frente exigir fechamento absoluto.

---

## Fase 5 rodada 2 (2026-07-07)

Segunda coleta empírica recebida de agente na máquina da colega, com evidências brutas preservadas em `C:\Applications\PastasPararelasGenexus\GX_18U14_EBTECH\Temp\phase5-java-tomcat-round2-20260707-obs`.

**Rebuild All/clean build dedicado.** A rodada válida executou `C:\Applications\GeneXus\18U14\EBTECH\Prototipo_18U14\web\gradlew.bat clean build --console=plain --info` e fechou empiricamente, para EBTECH/Jakarta, o caso `Lf=∅, Pf≠∅`:

| Rodada | `buildStartedAt` UTC | Resultado | `Lf` | `Pf` | `Pf\Lf` | `Lf\Pf` |
|---|---|---|---:|---:|---:|---:|
| clean build corrigido | `2026-07-07T19:16:29.6298569Z` | `exit=0`, `BUILD SUCCESSFUL` | 0 | 624 | 624 | 0 |
| build sem mudança | `2026-07-07T19:21:20.9414677Z` | `exit=0`, `BUILD SUCCESSFUL` | 0 | 624 | 624 | 0 |
| build instrumentado | `2026-07-07T19:22:41.0707928Z` | `exit=0`, `BUILD SUCCESSFUL` | 0 | 624 | 624 | 0 |

**Latência.** Uma amostra instrumentada mostrou que `deployBinTimeSlackSeconds=5` cobre a janela interna da cópia, mas não cobre a distância entre fim de compilação Java e último `.class` publicado:

| Rodada | `compileJavaEndAt` | `copyTomcatClassesStartAt` | `copyTomcatClassesEndAt` | `lastPublishedClassMTime` | `compile->last` | `copyStart->last` | `first->last` |
|---|---|---|---|---|---:|---:|---:|
| build instrumentado | `2026-07-07T19:23:14.076336500Z` | `2026-07-07T19:23:36.297752600Z` | `2026-07-07T19:23:38.323366300Z` | `2026-07-07T19:23:38.1217719Z` | 24.045s | 1.824s | 1.792s |

Conclusão operacional: a âncora empírica correta para a janela superior é o fim da publicação/cópia (`copyTomcatClasses`/`copyTomcat*`, ou um futuro `DeployStepCompletedAt` equivalente), não o fim de `compileJava`. Se algum fluxo usar `compileJavaEndAt` como marco, margem conservadora observada precisa exceder 30s.

**Destino efetivo de publicação.** A divergência da primeira coleta foi explicada por seleção de bloco/environment. O bloco atual do `model.ini` continha `SERVLET_DIR=C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHPrototipo_18U14\WEB-INF\classes`, enquanto o bloco `Version6/Data054` continha `EBTECHVersion6Prototipo_18U14`. O caminho efetivo também apareceu em `C:\Applications\GeneXus\18U14\EBTECH\Prototipo_18U14\web\gradle.properties`:

```text
WEBAPP_NAME=EBTECHPrototipo_18U14
TOMCAT_WEBAPP_PATH=C:\\Program Files\\Apache Software Foundation\\Tomcat 11\\webapps\\EBTECHPrototipo_18U14
TOMCAT_STATIC_PATH=C:\\Program Files\\Apache Software Foundation\\Tomcat 11\\webapps\\EBTECHPrototipo_18U14\\static
JAVA_PLATFORM=jakartaEE
SERVLET_VERSION=6
ISREBUILD=true
```

Sentinelas: `EBTECHVersion6Prototipo_18U14` não tinha `WEB-INF\classes` nem `WEB-INF\lib\GeneXus.jar`; `EBTECHPrototipo_18U14` tinha ambos. Regra para setup: `model.ini` é evidência útil só quando o environment/bloco correto foi resolvido e validado; quando houver Gradle, `gradle.properties` (`TOMCAT_WEBAPP_PATH`) é evidência efetiva do alvo publicado e deve concordar com a metadata sugerida ou prevalecer como alerta/auditoria.

**`javax`.** Não medido. Foi encontrado um environment com `JAVA_PLATFORM_SUPPORT=JAVA_EE`/`TOMCAT_VERSION=TOMCAT_8_9`, mas sem Tomcat 8/9 e JDK 8 acessíveis; os webapps lidos estavam sob Tomcat 11 e continham jars Jakarta. Não há inferência de `javax` clássico a partir dessa amostra.

**Sufixos e stems derivados.** Fechado de forma conservadora: manter o strip do co-gate limitado a `{_impl,__default,__gam}`. `_bc`, `ww*`, `Sdt*`, `StructSdt*` e `StructSdtCol*` permanecem stems próprios. Exemplo decisivo: `mb_bbtoken_bc__default` e `mb_bbtoken_bc__gam` agrupam em `mb_bbtoken_bc`; colar `_bc` em `mb_bbtoken` criaria vínculo por convenção de nome, não por evidência de stub-base.

---

## Fase 5 JavaEE/javax (2026-07-07)

Medição empírica do novo environment `JavaEE` criado pelo usuário na KB `EBTECH`, com evidências brutas preservadas em `C:\Applications\PastasPararelasGenexus\GX_18U14_EBTECH\Temp\javax-measurement-20260707T205111Z`.

**O que foi medido.** Environment GeneXus `JavaEE`, seção `[MODEL 056]`/`[PREFERENCES 056]`, `TargetFullPath=C:\Applications\GeneXus\18U14\EBTECH\JavaEE`, `GeneratorType=JavaWeb`, `JAVA_PLATFORM_SUPPORT=JAVA_EE`, `TOMCAT_VERSION=TOMCAT_10_1`, `TOMCAT_PATH=C:\Program Files\Apache Software Foundation\Tomcat 11`, `SERVLET_DIR=C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHJavaEE\WEB-INF\classes`, `JDK_DIR_JAVA=C:\Program Files\Java\jdk-21`. Em `C:\Applications\GeneXus\18U14\EBTECH\JavaEE\web\gradle.properties`: `WEBAPP_NAME=EBTECHJavaEE`, `JAVA_PLATFORM=javaEE`, `SERVLET_VERSION=6`, `JAVA_PACKAGE_NAME_FOLDER=com\\ebtech`, `org.gradle.java.home=C:\\Program Files\\Java\\jdk-21`.

**O que não foi medido.** Este environment não representa o stack clássico antigo Tomcat 8/9 + JDK 8 nem classpath puramente `javax`. O webapp publicado tinha sinais reais de Java EE/`javax`, mas também jars `jakarta.*`.

**Sinais `javax`/Java EE observados.**

- `WEB-INF\web.xml` publicado com namespace `http://java.sun.com/xml/ns/javaee`, schema `web-app_3_0.xsd` e parâmetro `javax.ws.rs.Application`.
- Jars `javax`/wrapper: `gxwrapperjavax-4.10.2.jar`, `javax.servlet-api-3.1.0.jar`, `javax.ws.rs-api-2.1.jar`, `javax.activation-api-1.2.0.jar`.
- Jars `jakarta` também presentes: `jakarta.ws.rs-api-2.1.6.jar`, `jakarta.activation-api-2.1.3.jar`, `jakarta.annotation-api-1.3.5.jar`, `jakarta.mail-api-2.1.3.jar`, `jakarta.xml.bind-api-3.0.1.jar`.
- Sentinelas/topologia: `WEB-INF\classes`, `WEB-INF\web.xml`, `WEB-INF\lib\GeneXus.jar` e pacote da app sob `WEB-INF\classes\com\ebtech` existentes.

**Build controlado.** Foi executado `Build All` com `ForceRebuild=true`, autorizado pelo usuário. Resultado operacional observado: `MSBuild exit code=0`, `wrapperExitCode=0`, `BuildAllDone=true`, `__BUILDALL_DONE__=true`, `BUILD SUCCESSFUL`, `0` erros classificados. Ressalvas: `142` warnings GeneXus, `msbuild.stderr.log` não vazio, mensagens de acesso negado em arquivos da instalação GeneXus e falha interna de pós-processamento do wrapper (`$operationalSubStateBuild` não definido). Portanto, build e publicação concluíram, mas não são "limpos sem ressalvas".

**Medição Lf/Pf.** Cutoff `2026-07-07T21:05:33.7684485Z`; local source `C:\Applications\GeneXus\18U14\EBTECH\JavaEE\web\src\main\java\com\ebtech`; publicado `C:\Program Files\Apache Software Foundation\Tomcat 11\webapps\EBTECHJavaEE\WEB-INF\classes\com\ebtech`.

| Métrica | Valor |
|---|---:|
| `.java` frescos sob package root | 852 |
| `.class` publicados frescos | 1168 |
| `Lf` object stems | 618 |
| `Pf` object stems | 618 |
| `Pf - Lf` | 0 |
| `Lf - Pf` | 0 |

Sufixos observados: em `.java`, `<base>` 618 e `_impl` 234; em `.class`, `<base>` 618, `_impl` 234, `__default` 225 e `__gam` 91. A normalização permaneceu a mesma: strip apenas de `_impl`, `__default`, `__gam`; `_bc`, `ww*`, `Sdt*`, `StructSdt*` e `StructSdtCol*` permanecem stems próprios.

**Latência.** Primeira classe publicada `2026-07-07T21:22:49.3772797Z`, última `2026-07-07T21:22:52.9739171Z`, `BUILD SUCCESSFUL` `2026-07-07T21:22:53.0000000Z`. Janela de escrita das classes publicadas: `3.597s`; última classe publicada até `BUILD SUCCESSFUL`: `0.026s`. O log só continha timestamp único para `:copyTomcatClasses`, sem marcador de fim.

**Veredito.** O co-gate Lf/Pf foi validado também no environment GeneXus `JAVA_EE`/`javaEE` medido (`Lf=618`, `Pf=618`, diferenças zero). Isso valida a opção GeneXus disponível com sinais `javax` reais, mas não prova compatibilidade universal com Java EE clássico puro em Tomcat 8/9 + JDK 8.

---

## Eixos B/C — fonte Java e runtime-freshness EBTECH (2026-07-09)

Coletas empíricas recebidas de agente na máquina da colega sobre a KB `EBTECH`, sem edição no repositório de skills e sem alteração na KB nativa. A pasta paralela `C:\Applications\PastasPararelasGenexus\GX_18U14_EBTECH` estava com gate de índice OK (`inventory_validation_status=OK`, `extractor_signature_version=8`). O Tomcat observado era compartilhado com outras aplicações, e a KB nativa `C:\Applications\GeneXus\18U14\EBTECH` não estava autorizada para gravação por agentes; por isso não houve alteração de objeto, build, clean/rebuild, restart de Tomcat nem teste de transição controlada.

**Environments medidos.** Foram lidos os environments Java `Prototipo_18U14` (`JAKARTA_EE`, `JAVA_PLATFORM=jakartaEE`), `JavaEE` (`JAVA_EE`, `JAVA_PLATFORM=javaEE`) e, na triagem de runtime-freshness, também `Producao_18U14` como environment local com `web\src\main\java`. Todos continuam no stack real Tomcat 11/JDK 21; Java EE clássico puro Tomcat 8/9 + JDK 8 segue não medido.

### Eixo B — fonte `.java` gerado

**Raiz e package.** A raiz real de fonte Java é `<TargetFullPath>\web\src\main\java`:

- `Prototipo_18U14`: `C:\Applications\GeneXus\18U14\EBTECH\Prototipo_18U14\web\src\main\java`
- `JavaEE`: `C:\Applications\GeneXus\18U14\EBTECH\JavaEE\web\src\main\java`

Em ambos, o package raiz da aplicação é `com\ebtech`, coerente com `JAVA_PACKAGE_NAME_FOLDER=com\\ebtech` em `gradle.properties`. Subpackages imediatos observados sob `com\ebtech`: `gam`, `general`, `gestaomail`, `grpc`, `workwithplus`, `wwpbaseobjects`.

**Módulos GeneXus viram subpackages.** O objeto `GestaoMail.Email` aparece em `com\ebtech\gestaomail`, não diretamente em `com\ebtech`. Portanto, um resolvedor de Eixo B não pode presumir apenas `<packageRoot>\<objectNameLower>.java`; precisa considerar nome GeneXus qualificado/módulo e subpackage.

**Contagens em `com\ebtech` direto, sem recursão em subpackages:**

| Environment | `.java` diretos | nomes não-lowercase | `_impl` | `_bc` | `RESTInterface*` | `Sdt*` | `StructSdt*` | `StructSdtCol*` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `Prototipo_18U14` | 512 | 130 | 129 | 4 | 52 | 24 | 24 | 24 |
| `JavaEE` | 506 | 124 | 129 | 4 | 52 | 22 | 22 | 22 |

Nomes não-lowercase observados incluem auxiliares/runtime (`GXApplication.java`, `GXcfg.java`, `GxFullTextSearchReindexer.java`, `GxObjectCollection.java`, `GxWebStd.java`) e derivados (`*_RESTInterfaceIN/OUT.java`). Para os objetos GeneXus autorais amostrados, os nomes de arquivo foram lowercase do objeto normalizado.

**Amostras por objeto.**

| Objeto | Tipo | Achado de fonte |
|---|---|---|
| `BBExtratoImportar` | Procedure | `bbextratoimportar.java` existe em `Prototipo_18U14` e `JavaEE`; não foi encontrado `bbextratoimportar_impl.java`. Logo, Procedure não deve ser presumida como sempre tendo `_impl.java`. |
| `MB_BBToken` | Transaction | `mb_bbtoken.java`, `mb_bbtoken_impl.java` e `mb_bbtoken_bc.java` existem. `_bc` permanece stem derivado completo, não sufixo de stub-base. |
| `EBT_Login` | WebPanel | `ebt_login.java` e `ebt_login_impl.java` existem nos dois environments. |

**Evidência negativa.** `web\src\main\resources` não existia em `Prototipo_18U14` nem em `JavaEE`. Para `GestaoMail.Email`, busca textual direta por `email*` em `com\ebtech` é perigosa porque retorna uma família de objetos (`emailoutbox`, `emailrecipient`, `emailtemplate`, `emailtracking`); o resolvedor futuro deve usar mapeamento de nome qualificado/subpackage, não só prefixo textual no package raiz.

**Conclusão de Eixo B.** O resolvedor Java deve partir de `TargetFullPath\web\src\main\java`, usar `JAVA_PACKAGE_NAME_FOLDER` quando disponível, suportar subpackages derivados de módulos GeneXus e não presumir `_impl.java` para todo tipo/objeto. Stems derivados (`_bc`, `RESTInterface*`, `Sdt*`, `StructSdt*`, `StructSdtCol*`, `ww*`) devem ser tratados como nomes completos derivados; o strip conservador de co-gate do Eixo A continua limitado a `{_impl,__default,__gam}`.

### Eixo C — runtime-freshness Java

**Estado observado.** `nav_objs.xml` existe em `C:\Applications\GeneXus\18U14\EBTECH\nav_objs.xml`, com `LastWriteTime` `2026-07-07 18:11:47`. A captura read-only de 2026-07-09 encontrou:

| `ObjStatus` | Qtde |
|---|---:|
| `genreq` | 395 |
| `nogenspc` | 40 |
| `nogenreq` | 0 |

Tipos identificados por `ObjCls`/GUID:

| `ObjCls` | Tipo GeneXus | Qtde |
|---:|---|---:|
| `0` | `Transaction` | 39 |
| `1` | `Procedure` | 207 |
| `13` | `WebPanel` | 180 |
| `33` | `DataProvider` | 9 |

Resultado agregado contra fontes Java locais:

| Status / Tipo / Java local | Qtde |
|---|---:|
| `genreq`, `Transaction`, com Java | 39 |
| `genreq`, `Procedure`, com Java | 169 |
| `genreq`, `WebPanel`, com Java | 180 |
| `genreq`, `DataProvider`, com Java | 7 |
| `nogenspc`, `Procedure`, sem Java | 38 |
| `nogenspc`, `DataProvider`, sem Java | 2 |

Não foi encontrado objeto `genreq` sem fonte Java local em pelo menos um environment, nem objeto `nogenspc` com fonte Java local. Portanto, nesta KB, `genreq` **não** significa "fonte Java ausente"; a semântica observada é mais compatível com "requer geração/specification pendente ou estado de navegação" e precisa ser interpretada junto com `ObjNavig` e timestamps de artefatos locais.

**Amostras de `nav_objs.xml`.**

| Objeto | Tipo | `ObjStatus` | `ObjNavig` | Evidência Java local |
|---|---|---|---|---|
| `WorkWithPlus.DynamicForms.WWP_DF_EmptyWC` | WebPanel | `genreq` | existe, LWT `2026-07-07 18:06:51` | `wwp_df_emptywc.java` e `wwp_df_emptywc_impl.java` nos 3 envs |
| `WWPBaseObjects.EditBookmark` | WebPanel | `genreq` | existe, LWT `2026-07-07 18:06:57` | `editbookmark.java` e `editbookmark_impl.java` nos 3 envs |
| `GAM_ConvertErrorsToMessages` | Procedure | `genreq` | existe, LWT `2026-07-07 18:07:19` | `gam_converterrorstomessages.java` nos 3 envs |
| `General.UI.SidebarItemsDP` | DataProvider | `genreq` | existe, LWT `2026-07-07 18:07:15` | `sidebaritemsdp.java` nos 3 envs |
| `MS_Company` | Transaction | `genreq` | existe, LWT `2026-07-07 18:08:48` | `ms_company.java` e `ms_company_impl.java` nos 3 envs |
| `GAM_BuildAppURL` | Procedure | `nogenspc` | existe, LWT `2026-07-07 18:07:19` | nenhum `.java` local |
| `WWPBaseObjects.SetWWPContext` | Procedure | `nogenspc` | existe, LWT `2026-07-07 18:07:22` | nenhum `.java` local |
| `MS_Company_DP` | DataProvider | `nogenspc` | existe, LWT `2026-07-07 18:07:16` | nenhum `.java`; existe `web\private\Interfaces\MS_Company_DP.xml` |
| `WorkWithPlus.DynamicForms.WWP_DS_SaveData` | Procedure | `nogenspc` | existe, LWT `2026-07-07 18:07:55` | nenhum `.java` local |

**Artefatos locais úteis observados para Eixo C.** Sem usar Tomcat externo como critério principal, a coleta identificou como candidatos: `nav_objs.xml`, `GXSPC056\GEN12\NVG\...\*.xml` via `ObjNavig`, `<Environment>\web\src\main\java\...\*.java`, `<Environment>\web\build\classes\java\main\...\*.class`, `<Environment>\web\js\...\*.js` (especialmente WebPanel/Transaction) e `<Environment>\web\private\Interfaces\*.xml` (observado em DataProvider). `WEB-INF\classes` apareceu em alguns casos locais, por exemplo GAM, mas permanece contexto de Eixo A/deploy-bin quando se trata do Tomcat externo.

**Diferença JavaEE/Jakarta em fonte local.**

| Environment | Arquivos `.java` com `javax.` | Arquivos `.java` com `jakarta.` |
|---|---:|---:|
| `JavaEE` | 369 | 0 |
| `Producao_18U14` | 0 | 334 |
| `Prototipo_18U14` | 0 | 372 |

**Experimento controlado em KB descartável/de teste.** Em rodada posterior no mesmo dia, a KB `C:\Applications\GeneXus\18U14\EBTECH` foi confirmada pelo usuário como descartável/de teste para este experimento, com restrição explícita de não usar `Producao_18U14`. O objeto escolhido foi `WebPanel:TestWP` (`ObjCls=13`, `ObjId=173`), no environment `Prototipo_18U14` (`GeneXus 18.0.14.56748`, `GeneratorType=JavaWeb`, `JAKARTA_EE`, `TOMCAT_10_1`, JDK 21). A alteração foi feita por tarefa oficial MSBuild (`SetObjectProperty`, propriedade `Description`), sem edição manual de `nav_objs.xml`, XMLs de navegação, artefatos Java ou banco `GX_KB_*`.

| Etapa | `nav_objs.xml` | Entrada `TestWP` | Artefatos locais específicos |
|---|---|---|---|
| T0 antes da alteração | LWT `2026-07-07T18:11:47.6886209-03:00`, hash `710021C3...` | `ObjStatus=genreq`, `ObjNavig=GXSPC056\GEN12\NVG\TestWP.xml` | `.java`, `.class` e `web\js\testwp.js` já existiam; sem `private\Interfaces\testwp*` |
| T1 depois de salvar `Description`, antes do build | inalterado | `ObjStatus=genreq`, `ObjNavig` inalterado | `.java`, `.class`, `.js` e XML apontado por `ObjNavig` inalterados |
| T2 depois de `BuildOneObject` | LWT `2026-07-09T16:06:36.3236469-03:00`, hash `EE86637C...`, tamanho reduziu para `521` | `ObjStatus=genreq`, `ObjNavig=GXSPC002\GEN12\NVG\TestWP.xml` | XML de navegação, `testwp.java`, `testwp_impl.java`, `testwp.js`, `testwp.class` e `testwp_impl.class` foram regravados/tocados |
| T3 segundo build sem nova alteração | inalterado desde T2 | `ObjStatus=genreq`, `ObjNavig` inalterado | artefatos específicos de `TestWP` inalterados; log registrou `Nenhum objeto para especificar` e `compileJava UP-TO-DATE`, apesar de etapas comuns de generation/deploy |

O XML apontado por `ObjNavig` mudou de `GXSPC056\GEN12\NVG\TestWP.xml` para `GXSPC002\GEN12\NVG\TestWP.xml` depois do build no environment `Prototipo_18U14`; o arquivo novo foi criado/regravado com LWT `2026-07-09T16:06:20.8525685-03:00`. O build com alteração tocou os `.java`, compilou os `.class` e regravou `web\js\testwp.js`. O build sem alteração não tocou os artefatos específicos do objeto, embora tarefas comuns do Gradle/Tomcat tenham rodado.

**Conclusão de Eixo C.** `nav_objs.xml` é candidato real para o diagnóstico Java equivalente ao runtime-freshness .NET, mas `ObjStatus` é apenas informativo: `ObjStatus=genreq` permaneceu antes da alteração, depois do build bem-sucedido e depois de build sem alteração. Logo, `ObjStatus=genreq` **não** deve ser usado isoladamente como critério de fonte Java ausente, classe ausente, specification pendente ou freshness local. O núcleo operacional do futuro motor deve cruzar: `ObjNavig` apontando para o `GXSPC` do environment esperado, existência/frescor do XML de navegação/specification, `.java` específicos em `<TargetFullPath>\web\src\main\java`, `.class` específicos em `<TargetFullPath>\web\build\classes\java\main`, e `.js`/`private\Interfaces` quando aplicável. Tomcat externo e tarefas `copyTomcat*` permanecem contexto de deploy/Eixo A, não prova primária de freshness do objeto.

---

## Itens abertos

- **Java EE clássico puro:** foi medido um environment GeneXus `JAVA_EE`/`javaEE` com sinais `javax` reais, mas no stack Tomcat 11/JDK 21/Servlet 6 e com jars `jakarta.*` também presentes. Não foi medido um stack clássico puro Tomcat 8/9 + JDK 8 com classpath exclusivamente/majoritariamente `javax`.
- **Eixo C Java — repetição por fluxo visual/evento:** a transição controlada foi medida em KB descartável/de teste com alteração de `Description` via MSBuild oficial e build do objeto. Isso derruba `ObjStatus` como critério isolado e valida o cruzamento `ObjNavig` + artefatos locais. Ainda falta, como reforço, repetir com alteração visual/literal/evento pela IDE para aproximar o fluxo humano e confirmar se o mesmo padrão se mantém.
- **Amostragem de latência:** a rodada instrumentada fechou a direção (`copyTomcatClasses` cabe em 5s; `compileJavaEndAt` não), mas não produz percentis. Se o default de slack for recalibrado estatisticamente, coletar mais rodadas com timestamps por tarefa.
- **Auto-população de metadata Java pelo setup:** futura automação deve resolver o environment ativo, validar topologia/sentinela/pacote da app e, quando houver Gradle, confrontar `model.ini` com `gradle.properties` (`TOMCAT_WEBAPP_PATH`). Divergência deve virar auditoria, não escrita cega.
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
