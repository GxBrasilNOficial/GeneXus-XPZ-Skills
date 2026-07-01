# Handoff — frente "API from-spec + GAM" nas skills XPZ (Fase 0 completa → fases documentais A3/A4/B)

Data: 2026-07-01. Sessão anterior: Fase 0 empírica + início das fases documentais. **Design congelado — não reabrir arquitetura.**

## Onde está o contexto canônico

- **Plano congelado + resultados empíricos:** entrada «Criar/alterar objeto GeneXus do tipo `API` (from-spec, com segurança GAM) nas skills XPZ» em `999-ideias-pendentes.md`, incluindo o bloco final **«Resultados da Fase 0 empírica — EXECUTADA 2026-07-01»**. Ler de lá primeiro.
- **Memória:** `project_api_from_spec_gam_plan`.
- KB de teste: `C:\Dev\Test\Gx_wsEducacaoSpTeste` (paralela; qualquer trabalho ali exige invocar `xpz-kb-parallel-setup` antes). App deployado/rodando em `http://localhost/wsEducacaoSpTesteNETFrameworkSQLServer` (web real: `C:\KBs\wsEducacaoSpTeste\NETFrameworkSQLServer004\web`; env ativo da KB é `NETPostgreSQL`). Versões: **KMW 4.0.187794 + GAM 3.15.78**.

## Achados empíricos da Fase 0 (todos os fatos são datados nas versões acima)

1. **D3:** `[SecurityLevel(Authorize)]` é **REJEITADO** pelo parser (`mismatched input 'Authorize' expecting {ModeNone, ModeAuthorization, ModeAuthentication}`). Válidos: `None`/`Authentication`/`Authorization`. Molde usa `Authorization`. **nexa `object-api.md` (seção SecurityLevel) tem bug** — lista `Authorize`.
2. **preview ≠ validação real:** o preview de import dá `importTaskSuccess:true` para API inválida; só o **import real** valida gramática/referências. Validar API from-spec por import real, nunca preview.
3. **H2 (dep-order):** `API => Proc` é validado no **import real** (não no build — a hipótese "resolvido no build" está errada). Rejeita se o Proc está ausente do lote **E** da KB; resolve intra-lote (API+Proc no mesmo pacote) ou contra KB pré-existente. É **doc-gap** (o import resolve; a 9-IDO não modela `API→Proc` mas não precisa); regra: empacotar API+Proc juntos ou staging do Proc antes.
4. **Enforcement reversível PROVADO:** anônimo→401; com papel→200; **papel revogado→403** (`code 139`). GAM checa autorização por requisição.
5. **C# mapping:** `None→SecurityNone`, `Authentication→SecurityLow`, `Authorization→SecurityHigh`.
6. **0b "autocontido" resolvido:** molde mínimo = tríade `API`→`Procedure`→`SDT`; única `ATTCUSTOMTYPE` externa = `sdt:` próprios; **exclui** `exo:GAMSession` (4º modo, auth via evento) e `sdt:Messages,GeneXus.Common` (opcional).

## O que já foi GRAVADO nesta sessão (commit desta rodada)

- **A1** `xpz-builder/responsibilities-by-type/api.md` — elevado: SecurityLevel/GAM, `[SecurityPermission]`↔`*_Services_*`, dep-order/import real, preview≠validação, OpenAPI≠segurança, checklist, refs.
- **B1** `xpz-builder/responsibilities-by-type/api-gam-runtime.md` — NOVO satélite: Face 2 (pré-condição runtime GAM), smoke 2 fases + reversibilidade, erros OAuth (542/116/232/79), body-envelope, PUT→404, multi-env, sub-estado.
- **A2** `01e-moldes-sanitizados-core.md` — «Molde sanitizado de API 2 - tríade mínima autocontida» (SDT+Proc+API sanitizados) inserido após o `APIExemploIntegracao` (linha ~1556).
- `999-ideias-pendentes.md` — bloco «Resultados da Fase 0 empírica».

## O que FALTA (fazer na nova sessão)

**ATUALIZAÇÃO 2026-07-01 (sessão seguinte): A3, A4 e B COMPLETOS e gravados em `main` (não commitados nesta sessão).** Falta só: pré-push reforçada (13/14) + paridade conferida + commit/push (autorização do usuário). Resíduos na KB de teste seguem (ver `## Resíduos / pendências do usuário`).

- **A3 — FEITO** (`03-risco-e-decisao-por-tipo.md`): distinguido `API (cadeia)` de `API (from-spec)` em texto e nas 2 tabelas de risco (linhas ~175 e ~326), com micro-notas de recalibração (bullet na Tabela 1 / linha-nota in-grid na Tabela 2), `StructuralRisk = medio-contextual`, célula `ParentModuleDependency` = `parent nomeado presente (pasta PastaExemploApi, neutralizada no molde)` — **correção de revisão por pares**: a v5 dizia erroneamente `0 sem parent nomeado`, mas o molde `01e` tem `parent="PastaExemploApi"`; só o Codex, lendo o `01e`, pegou (4 revisores passaram). Revisão por pares: 6 versões, 3 famílias (anthropic nativo, openai/gpt-5.5, ollama-cloud deepseek/kimi/glm); recibo/closeout `closeoutReady=true`.
- **A4 — FEITO**: `02-regras-operacionais-e-runtime.md` (Politica para API + dimensão GAM/runtime: from-spec, import real≠preview, falso-positivo de enforcement), `08-guia-para-agente-gpt.md` (`### API`), `10-base-operacional-msbuild-headless.md` (achado empírico: preview reporta sucesso p/ API inválida, só import real valida). **README: sem edição** — é índice de alto nível, não carrega conteúdo por tipo nem afirmação stale sobre API; forçar parágrafo API/GAM trilíngue seria ruído (decisão registrada; usuário pode redirecionar).
- **B — FEITO**: `xpz-builder/SKILL.md:52` passou a expor `responsibilities-by-type/api-gam-runtime.md` na enumeração de satélites (a cadeia SKILL→`api.md`→`api-gam-runtime.md` fica amarrada; `api.md` já apontava o sub-satélite e o `quality-checklist.md:52` já cobre genericamente "carregar o satélite de cada tipo do lote"). B2/B3 de conteúdo já estavam cristalizados no `api-gam-runtime.md` (critério de aceite + contrato).

## Resíduos / pendências do usuário

- KB de teste: `zzApiBatchTest` + `procFase0BatchDep` foram importados (deletar pela IDE). Papel `ProdutoApiConsumidor` foi **revogado** do usuário `api_produto_teste` (restaurar se quiser a ProdutoApi utilizável). Divergência à parte: `kb_environment_web_dirs` registra `NETFrameworkSQLServer/web`, real é `NETFrameworkSQLServer004/web`.
- Git: esta rodada foi **commitada, NÃO pushada**. Há outras frentes não pushadas na branch (não são desta). Antes de push, rotina pré-push reforçada (doc 13/14) + paridade.

## Como retomar operações empíricas (se A3/A4 precisarem re-testar)

- Gate: `xpz-kb-parallel-setup` antes de qualquer ação na KB paralela.
- Import real (valida API): `scripts/Invoke-GeneXusXpzImport.ps1 -KbPath C:\KBs\wsEducacaoSpTeste -InputPath <pacote> -WorkingDirectory <temp> -LogPath <temp>\msbuild.stdout.log`. Preview NÃO valida.
- Empacotar: `New-wsEducacaoSpTesteKbImportPackage.ps1 -FrontName <front> -NN 01 -TemplatePackagePath <pacote-comparável>`.
- Revisão por pares (se surgir decisão nova): `xpz-llm-delegate` + `preferred-reviewers.json` (5 revisores/3 famílias já configurados; o painel desta frente aprovou o pacote empírico).
