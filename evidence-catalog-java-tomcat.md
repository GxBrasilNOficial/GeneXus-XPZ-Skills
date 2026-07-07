# Evidence catalog — GeneXus Java/Tomcat (Fase 0, aterramento empírico)

> **Status:** Fase 0 **concluída** (Q5b **confirmado** pelo re-teste controlado decisivo de 2026-07-04, rota manual pela IDE; ver Q5). **VEREDITO: Plano B acionado** — a topologia real do deploy Java/Tomcat é **externa** à árvore de output, invalidando a hipótese *in-place* que o design congelou para o motor da Fase 3 (ver [`java-tomcat-paridade-gerador-design.md`](java-tomcat-paridade-gerador-design.md), seção "Congelamento vale para a hipótese in-place"). O resto do design **não** reabre.
>
> **Fase 5 parcial (2026-07-07):** nova medição na KB `EBTECH` (GX18U14, Jakarta/Tomcat 11/JDK 21) confirmou o ator da publicação (`gradlew`/Gradle chamado pelo Build All, tarefas `copyTomcat*`) e trouxe uma amostra de latência e sufixos; não fechou `javax` nem o caso exato `Rebuild All -> Lf=∅, Pf≠∅`. Ver seção "Fase 5 parcial".
>
> **Data da coleta:** 2026-07-04. **Registro-resumo:** [`999-ideias-pendentes.md`](999-ideias-pendentes.md).

## Fonte da evidência

- Coleta feita por um agente numa **máquina de terceiro** (a máquina de dev **não tem licença Java**; build local impossível). Modo **read-only** na coleta inicial; os re-testes de frescor (Q5, rota manual pela IDE) **rodaram builds** na máquina da colega — Q4/Q5 fechados.
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

## Itens abertos

- **Dois sabores Java (Jakarta vs javax):** a evidência segue restrita ao sabor `JAKARTA_EE`/`jakarta.*`. O sabor `JAVA_EE`/`javax.*` (ex.: env Java da `wsEducacaoSpTeste`, Tomcat 8/9, JDK 8) tem nomes de jar de runtime distintos. A família `java-tomcat` deve ser namespace-agnóstica ou cobrir os dois. A coleta de Fase 5 de 2026-07-07 também foi Jakarta; `javax` permanece aberto.
- **`Rebuild All -> Lf=∅, Pf≠∅`:** a coleta de Fase 5 de 2026-07-07 trouxe evidência contra (`Lf=379`, `Pf=624`), mas não fechou a pergunta como rodada dedicada porque reutilizou rodada existente e o wrapper reportou falha operacional por log bloqueado.
- **Auto-população de metadata Java pelo setup:** o `SERVLET_DIR` do `model.ini` divergiu da publicação real observada na Fase 5 parcial; futura automação deve validar topologia/sentinela e exigir auditoria quando o caminho configurado não existir ou não coincidir com o deploy efetivo.
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
