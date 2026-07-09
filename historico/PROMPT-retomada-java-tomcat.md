# Prompt de Retomada — Paridade de gerador Java/Tomcat nas skills XPZ

Use este prompt para abrir uma nova conversa (qualquer agente: Claude Code, Codex, Cursor, OpenCode) com contexto limpo. Tudo abaixo é derivado de arquivos **versionados** no repo — não depende de memória de nenhuma ferramenta.

```text
Retomar a frente "paridade de gerador Java/Tomcat nas skills XPZ" em C:\Dev\Knowledge\GeneXus-XPZ-Skills.
Rode `git fetch origin` no início e reconfirme o estado do remoto antes de afirmar o que está/não pushado
(o `origin/main` avança por OUTRAS frentes não-relacionadas; não fixe hash — o trabalho java-tomcat até a
Fase 5 já está em `origin/main`). Trabalhar direto na main.

ESTADO: Fases 0, 1, 2, 3, 4-docs e 5 FEITAS e PUSHADAS.
- Fase 0 = aterramento empírico (topologia externa; frescor por mtime do `.class` no `WEB-INF\classes`).
- Fases 1/2 = registro-fonte-única + guardas de família dos 3 eixos.
- Fase 3 = MOTOR do Eixo A (deploy-bin) = co-gate Java por família (4 quadrantes, skew bidirecional,
  split per-eixo, §9 allowlist-invertida). Regressão .NET provada por golden byte-a-byte.
- Fase 4 = documentação em paridade (02/08/09/10/README trilíngue/SKILLs).
- Fase 5 = validação empírica DOCS-ONLY (o motor foi validado, sem mudança de código).

O QUE FALTA (nada bloqueia o que já está no ar — o Eixo A é fail-safe e usável):
1. Pós-v1 — MOTORES dos Eixos B (fonte gerado `.java`) e C (runtime-freshness `.java`). Hoje B/C só têm
   guarda-de-família (pulam/skip para KB Java); a paridade TOTAL com .NET exige esses dois motores
   (gêmeos de `Resolve-GeneXusGeneratedCsPath`/`Find-CsAttributeAssignments`). NÃO precisa de KB Java para
   projetar; precisa dela para validar. Ver a fase "Pós-v1" no design congelado.
2. Eventual automação além do assistente read-only de metadata Java, se algum dia for aprovada sem perder a
   confirmação explícita. Hoje `Resolve-XpzJavaTomcatMetadataSuggestion.ps1` sugere
   `kb_environment_servlet_dirs`/`_app_package`/`_servlet_flavor` a partir de `model.ini`/`gradle.properties`,
   valida topologia/sentinelas/pacote e deixa a gravação opt-in para `Set-XpzKbSourceMetadataDeployment.ps1`.
   A Fase 5 achou que `SERVLET_DIR` do `model.ini` pode divergir da publicação real → continua proibido copiar
   cegamente; qualquer automação futura deve preservar validação e decisão humana em divergência.
3. Dois resíduos empíricos (dependem de KB Java):
   a. Sabor Java EE CLÁSSICO PURO (Tomcat 8/9 + JDK 8) NÃO foi medido (não havia ambiente; o que se mediu
      foi um env `JAVA_EE`/`javax` porém rodando em Tomcat 11/JDK 21/Servlet 6).
   b. DECISÃO em aberto: um clean/rebuild DEDICADO publicou `.class` sem geração local no recorte
      (`Lf=∅, Pf≠∅`; medido `Lf=0, Pf=624`) → classificado como `unexpected-publication` (gate FALHA). É o
      fail-safe projetado — NÃO uma prova de que todo "Rebuild All" em qualquer contexto caia aí. O design
      (glm A1) previa avaliar um estado "última publicação bem-sucedida" se o caso for frequente. Manter
      conservativo vs relaxar = decisão humana.
4. Follow-up: remover os aliases legados (`runsFreshnessEngine`/`freshnessSupportState`/`freshnessSkipStatus`/
   `unsupportedReason`) do registro no PRÓXIMO ciclo de release, após confirmar que consumidores externos
   migraram aos campos per-eixo (ver a entrada de follow-up no 999).

DUAS NATUREZAS DE TRABALHO (para não confundir o que precisa da colega):
- EMPÍRICO → precisa da KB Java da colega (a máquina de dev NÃO tem licença Java). Faz-se por TROCA DE DADOS:
  você gera um prompt copiável para o agente que roda na máquina dela, ele mede, você processa o resultado
  aqui. PROIBIDO inventar resultado empírico. Cabe aqui: resíduo 3a (e re-medições que faltarem).
- DESIGN/CÓDIGO (sem KB Java) → Pós-v1 (motores B/C), eventual automação além do assistente read-only de
  metadata (item 2), e a decisão do item 3b. Segue o processo normal do repo (design → revisão por pares se
  abrir arquitetura → self-tests).

LEIA PRIMEIRO, nesta ordem (fontes-verdade versionadas; NÃO reprocessar o que já foi feito):
1. AGENTS.md local (convenções do repo: rotina pré-push, git na main, gates de segurança, idioma).
2. 999-ideias-pendentes.md → entrada "## Paridade de gerador Java/Tomcat nas skills XPZ" (status completo de
   todas as fases + os follow-ups acima + os bullets detalhados da Fase 5).
3. java-tomcat-paridade-gerador-design.md (design CONGELADO: contrato do registro, decisões (a)–(e), a lista
   de Fases incluindo "Pós-v1", cláusula no-bridge). NÃO reabrir sem revisão por pares.
4. java-tomcat-fase3-checklist-implementacao.md → §B (as 5 perguntas da Fase 5, agora com as respostas
   empíricas registradas) + §A/§C.
5. evidence-catalog-java-tomcat.md (fonte-verdade empírica da Fase 0 e da Fase 5).
6. java-tomcat-fase3-replano.md (spec congelada do co-gate do Eixo A).
7. CHANGELOG.md → entradas "Java/Tomcat" (Fases 0–5, trilíngue PT/ES/EN).

SE A TAREFA FOR TROCA DE DADOS COM A MÁQUINA DA COLEGA: o entregável é um prompt copiável, pronto, para o
agente dela executar as medições (com o que capturar em cada uma). Confirme o formato com o usuário antes de
considerar concluído.

RESTRIÇÕES:
- Não reabrir o design congelado (só revisão por pares reabre). O co-gate do Eixo A JÁ funciona fail-safe.
- PROIBIDO inventar resultado empírico. Claim factual sobre comportamento (frescor/mtime/o que o Gradle
  recompila / se `DeployStepCompletedAt` existe no timing do MSBuild / sabor javax clássico) deve ser
  ANCORADO no evidence-catalog ou MEDIDO na máquina da colega — nunca presumido.
- git fetch origin no início; reconfirmar o remoto antes de afirmar o que está/não pushado.
- Toda alteração de repo só após aprovação explícita do usuário. Respostas em português BR.
FIM DO PROMPT
```
