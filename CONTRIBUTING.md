# Guia de Contribuição

## Português (BR)

Obrigado por considerar uma contribuição. Este repositório é uma base metodológica e operacional pública para skills XPZ/XML de GeneXus; contribuições devem preservar rigor técnico, rastreabilidade e cuidado com dados reais.

Antes de abrir uma alteração:

- leia `README.md`, `AGENTS.md` e a documentação diretamente relacionada ao tema;
- consulte `999-ideias-pendentes.md` e `998-ideias-descartadas-e-porque.md` para evitar reavaliar frentes já registradas;
- mantenha exemplos e evidências sanitizados, sem credenciais, dados de clientes ou artefatos privados;
- prefira mudanças pequenas, locais e fáceis de revisar;
- preserve o compromisso trilíngue quando alterar conteúdo que já exista em português, espanhol e inglês.

### Revisão antes do push

Antes de propor publicação, compare sua alteração com `origin/main..HEAD`, execute as verificações mecânicas documentadas em `13-revisao-pre-push.md` e faça a busca semântica de coerência descrita ali. A revisão pré-push é relatório primeiro: correções decorrentes do relatório devem ser discutidas antes de novas edições quando o fluxo local assim exigir.

Durante essa revisão, avalie também se a mudança precisa ser registrada em `CHANGELOG.md`. Mudanças de comportamento público, contrato operacional, scripts, skills, governança, segurança ou fluxo de contribuição devem atualizar o changelog ou trazer justificativa explícita para a omissão.

### Issues

Buraco de script, sugestão, diagnóstico e prompt de agente sobre a metodologia pública vão para https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills/issues.

Antes de abrir, tire credencial, dado de cliente, nome sensível de KB e artefato não autorizado. Relato de vulnerabilidade, vazamento ou risco operacional sensível vai para o `SECURITY.md`, não para a issue pública.

A issue descreve:

- o problema observado;
- o objetivo da melhoria sugerida;
- a skill, o script ou o documento afetado;
- o que não pode entrar no texto público.

O agente redige a issue na conversa e só a abre depois do ok de quem conduz a sessão. O mantenedor pode resolvê-la como mudança, item do `999-ideias-pendentes.md` ou discussão.

### Pull requests e contribuições estruturadas

Ao abrir um pull request, descreva:

- o problema resolvido;
- os arquivos principais alterados;
- quais verificações foram executadas;
- se `CHANGELOG.md` foi atualizado ou por que não se aplica;
- riscos conhecidos, pendências e áreas não cobertas.

## Español

Gracias por considerar una contribución. Este repositorio es una base metodológica y operativa pública para skills XPZ/XML de GeneXus; las contribuciones deben preservar rigor técnico, trazabilidad y cuidado con datos reales.

Antes de abrir un cambio:

- lee `README.md`, `AGENTS.md` y la documentación directamente relacionada con el tema;
- consulta `999-ideias-pendentes.md` y `998-ideias-descartadas-e-porque.md` para evitar reevaluar frentes ya registradas;
- mantén ejemplos y evidencias sanitizados, sin credenciales, datos de clientes ni artefactos privados;
- prefiere cambios pequeños, locales y fáciles de revisar;
- preserva el compromiso trilingüe cuando alteres contenido que ya exista en portugués, español e inglés.

### Revisión antes del push

Antes de proponer publicación, compara tu cambio con `origin/main..HEAD`, ejecuta las verificaciones mecánicas documentadas en `13-revisao-pre-push.md` y realiza la búsqueda semántica de coherencia descrita allí. La revisión previa al push es primero un informe: las correcciones derivadas del informe deben discutirse antes de nuevas ediciones cuando el flujo local así lo exija.

Durante esa revisión, evalúa también si el cambio debe registrarse en `CHANGELOG.md`. Cambios de comportamiento público, contrato operativo, scripts, skills, gobernanza, seguridad o flujo de contribución deben actualizar el changelog o traer una justificación explícita para la omisión.

### Issues

Hueco de script, sugerencia, diagnóstico y prompt de agente sobre la metodología pública van a https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills/issues.

Antes de abrir, quita credencial, dato de cliente, nombre sensible de KB y artefacto no autorizado. Un reporte de vulnerabilidad, filtración o riesgo operativo sensible va a `SECURITY.md`, no a la issue pública.

La issue describe:

- el problema observado;
- el objetivo de la mejora sugerida;
- la skill, el script o el documento afectado;
- qué no puede entrar en el texto público.

El agente redacta la issue en la conversación y solo la abre después del ok de quien conduce la sesión. La persona mantenedora puede resolverla como cambio, ítem de `999-ideias-pendentes.md` o discusión.

### Pull requests y contribuciones estructuradas

Al abrir un pull request, describe:

- el problema resuelto;
- los archivos principales modificados;
- qué verificaciones fueron ejecutadas;
- si `CHANGELOG.md` fue actualizado o por qué no aplica;
- riesgos conocidos, pendientes y áreas no cubiertas.

## English

Thank you for considering a contribution. This repository is a public methodological and operational base for GeneXus XPZ/XML skills; contributions should preserve technical rigor, traceability, and care with real data.

Before opening a change:

- read `README.md`, `AGENTS.md`, and the documentation directly related to the topic;
- check `999-ideias-pendentes.md` and `998-ideias-descartadas-e-porque.md` to avoid reevaluating already recorded work;
- keep examples and evidence sanitized, with no credentials, client data, or private artifacts;
- prefer small, local changes that are easy to review;
- preserve the trilingual commitment when changing content that already exists in Portuguese, Spanish, and English.

### Pre-Push Review

Before proposing publication, compare your change with `origin/main..HEAD`, run the mechanical checks documented in `13-revisao-pre-push.md`, and perform the semantic consistency search described there. Pre-push review is report-first: corrections derived from the report should be discussed before new edits when the local flow requires it.

During that review, also evaluate whether the change should be recorded in `CHANGELOG.md`. Changes to public behavior, operational contracts, scripts, skills, governance, security, or contribution flow should update the changelog or include an explicit justification for omitting it.

### Issues

A script gap, suggestion, diagnostic, or agent prompt about the public methodology goes to https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills/issues.

Before opening it, remove credentials, client data, sensitive KB names, and unauthorized artifacts. A report of a vulnerability, a leak, or a sensitive operational risk goes to `SECURITY.md`, not to a public issue.

The issue describes:

- the observed problem;
- the goal of the suggested improvement;
- the affected skill, script, or document;
- what must not appear in the public text.

The agent drafts the issue in the conversation and opens it only after the person running the session says so. The maintainer may resolve it as a change, an item in `999-ideias-pendentes.md`, or a discussion.

### Pull Requests and Structured Contributions

When opening a pull request, describe:

- the problem solved;
- the main files changed;
- which checks were run;
- whether `CHANGELOG.md` was updated or why it does not apply;
- known risks, pending work, and uncovered areas.
