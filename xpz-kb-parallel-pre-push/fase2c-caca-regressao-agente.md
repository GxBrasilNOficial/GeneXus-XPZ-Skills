# Fase 2c — caça a regressão óbvia (triagem de agente)

Satélite de [`SKILL.md`](SKILL.md). A Fase 2c é um **checklist do agente principal** executado após a Fase 2b e refletido no relatório da rodada. **Não** é script, **não** é gate mecânico, **não** altera `pushReadiness` e **não** prova ausência de regressão.

> A Fase 2c **não** desloca a autoridade do regime «lógica de negócio»: continua sendo o **teste funcional** ([`fase2b-classificador-de-regime.md`](fase2b-classificador-de-regime.md)). A 2c apenas torna **visível no relatório** o que a leitura barata do diff de Source mostra. Não é prova, não é selo, não bloqueia.

Distinta da pré-push do repositório de skills ([`13-revisao-pre-push.md`](../13-revisao-pre-push.md) / [`14`](../14-revisao-pre-push-reforcada.md)).

## Entrada: saída da Fase 2b

Candidatos = entradas do JSON de `Compare-XpzChecksums.ps1` com status ≠ `SAME` (e, quando F1 = `unknown`/exit 3, a seção 2c do relatório fica `indisponível — F1 unknown`, sem inventar triagem).

Para cada candidato, **herdar** o regime/roteamento da 2b:

| Regime / rótulo 2b | Tratamento 2c |
|---|---|
| **aditivo computado** | item **N/A — regime 2b** (não reabrir) |
| **lógica de negócio** | checklist + triagem; autoridade = teste funcional |
| **`suspeito-por-omissão`** | **não** reclassificar como “nada óbvio / sem regressão” |
| demais | seguir autoridade da 2b; 2c só se houver Source elegível e valor de leitura |

## Source relevante e WebPanel / layout

“Source relevante” = conteúdo em `<Source>` (tipicamente CDATA) em Procedure / WebPanel / DataSelector e equivalentes com código.

**WebPanel / layout:** se a mudança no `<Source>` for **exclusiva** (ou dominante) de layout embutido — tipicamente `GxMultiForm` / `InnerHtml` em CDATA de linha única — classificar como **estrutural-visual**, não forçar “reescreveu ramo / condição invertida / aditivo de código”. O checklist de código barato aplica-se a diffs de **eventos**, `parm` e lógica em Source de Procedure (e trechos de evento em WebPanel). Mudança só de layout: registrar como estrutural-visual; regressão visual fica fora da estática barata (revisão humana / teste na UI).

**Ponte canônica:** para separar events vs layout no WebPanel, usar `scripts/Search-GeneXusXmlSourceBlock.ps1` (`-Block events` para evento/chamada/fluxo; `-Block layout` para visual/binding). Match bruto em `GxMultiForm` inline **não** prova code-behind — alinhado a `02`, `08` e `xpz-reader`. Não cria script novo.

Expansão a SDT / WorkWith estrutural fora de Source **não** faz parte desta fase (follow-up).

## Elegibilidade por classificação F1

| F1 | Tratamento 2c |
|---|---|
| `DIFF` com Source | Checklist: aditivo vs reescreveu ramo vs ruído/lastUpdate (ou estrutural-visual) |
| `NEW` com Source | Sem “ramo antigo”; foco em contrato (`parm`, `Chamador`), ramos iniciais, padrões baratos |
| `DELETED` | Em geral **N/A** para Source do removido; registrar remoção; seguir nota 2b (delete) + build |
| `SAME` | Fora do filtro de leitura 2c. **Não** concluir ausência de impacto na cabeça associada — nuance em [`fase2a-estrutural.md`](fase2a-estrutural.md) / 2b |

## Insumo mecânico (sem script novo)

```text
git -C <pasta-paralela> diff <BaseRef>..HEAD -- <caminho-do-XML>
```

Antes de rotular **suspeita**: consultar o **catálogo de padrões aceitos por-KB** (molde `examples/kb-parallel-pre-push-accepted-patterns.example.json`). Padrão catalogado → não vira suspeita; não catalogado → candidato a inspeção (não é erro automático).

## Orçamento de leitura

- Nome: **orçamento de leitura** (objetos alterados a inspecionar), default **20**.
- Distinto do limiar 2b “>~20 **dependentes** → rotear ao build”.
- Prioridade: Procedure/WebPanel com Source não-`SAME`; Domain/Table só se o regime 2b pedir.
- Cobertura **parcial** exige listar **nominalmente** o que ficou de fora.

## Checklist (agente)

1. Classificar conforme F1 (aditivo / reescreveu / ruído / estrutural-visual / NEW-contrato / DELETED-N/A / regime-2b-N/A).
2. Padrões baratos (código): condição invertida; `Case`/exceção no banco/objeto errado; remoção/encurtamento de ramo (DIFF); mudança de contrato.
3. Buckets: correção explícita / decisão consciente de adiar / **suspeita** (após catálogo).
4. Rubrica no relatório: **triagem** (nunca “veredito de regressão”) — `nada óbvio` \| `suspeitas` \| `precisa teste manual/caso real`.

## Anti-selo

- “Nada óbvio” **não** é ausência de regressão e **não** libera push.
- A linha **Push:** do relatório deriva **somente** de `pushReadiness` (Fase 1) + decisão explícita do usuário.
- Mesmo com Fase 1 `blocked`/`warn`, a 2c pode correr como diagnóstico se 2a/2b rodarem; não desbloqueia push.
- A seção 2c **sempre** aparece no molde (conteúdo `N/A` quando não houver elegíveis).

## O que a Fase 2c entrega

Uma **triagem apresentada** no relatório — cobertura, classificações, suspeitas e necessidade de manual/caso real — para decisão consciente. Não substitui build (`FailIfReorg`), teste funcional nem a Fase 1.
