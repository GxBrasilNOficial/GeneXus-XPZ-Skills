# Java/Tomcat pós-v1: frentes futuras

## Escopo

Este documento registra as frentes futuras que ficaram fora da v1 prática de suporte a KB GeneXus `java-tomcat` nas skills XPZ.

A v1 prática está encerrada para metadata/setup e para o gate de deploy-bin do Eixo A. O objetivo aqui é manter os próximos passos retomáveis sem inflar o `999-ideias-pendentes.md`.

Referências principais:

- [`999-ideias-pendentes.md`](999-ideias-pendentes.md): índice vivo das pendências.
- [`evidence-catalog-java-tomcat.md`](evidence-catalog-java-tomcat.md): catálogo de evidência empírica Java/Tomcat.
- [`java-tomcat-paridade-gerador-design.md`](java-tomcat-paridade-gerador-design.md): design congelado original.
- [`java-tomcat-fase3-replano.md`](java-tomcat-fase3-replano.md): replano do co-gate Java/Tomcat do Eixo A.

## Estado encerrado da v1 prática

Já está coberto:

- `deployment_hosting_kind=java-tomcat` é representável em metadata.
- `xpz-kb-parallel-setup` tem assistente read-only/opt-in para sugerir metadata Java a partir de `model.ini`/`gradle.properties`, validando topologia, sentinelas e pacote da aplicação antes de qualquer gravação.
- O Eixo A (`deploy-bin`) roda co-gate Java/Tomcat por conjunto de artefatos no `WEB-INF\classes` externo do Tomcat.
- Os Eixos B/C fazem skip explícito/fail-safe em KB Java; não fingem suporte .NET.
- `ObjStatus=genreq` não é critério isolado de pendência de runtime Java.

## Frente 1: motor Java do Eixo B

Objetivo: implementar diagnóstico de fonte gerado Java, equivalente conceitual ao resolvedor de `.cs` no .NET.

Direção técnica inicial:

- partir de `<TargetFullPath>\web\src\main\java`;
- usar `JAVA_PACKAGE_NAME_FOLDER` quando disponível;
- suportar subpackages derivados de módulos GeneXus;
- não presumir `_impl.java` para todo tipo/objeto;
- manter stems derivados como nomes próprios quando aplicável (`_bc`, `RESTInterface*`, `Sdt*`, `StructSdt*`, `StructSdtCol*`, `ww*`).

Fonte empírica: `evidence-catalog-java-tomcat.md`, seção "Eixos B/C - fonte Java e runtime-freshness EBTECH (2026-07-09)".

## Frente 2: motor Java do Eixo C

Objetivo: implementar runtime-freshness Java real para substituir o skip atual do Eixo C em KB `java-tomcat`.

Direção técnica inicial:

- cruzar `nav_objs.xml`;
- seguir `ObjNavig` para XMLs de navegação/specification;
- comparar artefatos locais `.java`, `.class` e `.js`;
- tratar `ObjStatus=genreq` como sinal insuficiente isoladamente;
- preservar a separação entre runtime local do Eixo C e deploy publicado do Eixo A.

O experimento controlado com `WebPanel:TestWP` mostrou que `ObjStatus=genreq` permaneceu antes/depois de build com alteração e depois de build sem alteração. Portanto, o motor Java do Eixo C precisa de evidência composta.

## Frente 3: stack clássico Tomcat 8/9 + JDK 8

Objetivo: aferir, se algum dia houver ambiente disponível, um stack Java EE clássico puro ou majoritariamente `javax` em Tomcat 8/9 + JDK 8.

Estado atual:

- Jakarta/Tomcat 11/JDK 21 foi medido.
- Um environment GeneXus `JAVA_EE`/Gradle `javaEE` foi medido com sinais reais `javax`, mas ainda em Tomcat 11/JDK 21/Servlet 6 e com jars `jakarta.*` também presentes.
- Isso valida o environment disponível, mas não prova compatibilidade universal com Tomcat 8/9 + JDK 8.

Esta frente depende de ambiente externo; não é bloqueador da v1 prática.

## Frente 4: retirada dos aliases legados do registro

Objetivo: remover os aliases de compatibilidade depois de um ciclo de release, quando consumidores externos já tiverem migrado para os campos por eixo.

Aliases a remover:

- `runsFreshnessEngine`
- `freshnessSupportState`
- `freshnessSkipStatus`
- `unsupportedReason`

Também remover a guarda de migração-compat do `Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1` que verifica alias derivado do Eixo A.

Precondição: confirmar que wrappers de pasta paralela e demais consumidores externos usam `runsDeployBinEngine`, `runsSourceEngine` e `runsRuntimeEngine`.

## Frente 5: automação futura de metadata Java

Objetivo: avaliar automação além do assistente read-only/opt-in atual, se houver demanda real.

Restrições que não devem ser perdidas:

- `model.ini` e `GeneratorType` não viram autoridade sozinhos;
- `SERVLET_DIR` não deve ser copiado cegamente;
- divergência entre `model.ini`, `gradle.properties`, sentinelas e pacote da aplicação exige auditoria;
- gravação de metadata continua exigindo confirmação explícita.

Esta frente é opcional. O assistente atual já cobre a v1 prática com postura segura.
