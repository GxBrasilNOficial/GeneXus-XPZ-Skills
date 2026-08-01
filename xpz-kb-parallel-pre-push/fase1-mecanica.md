# Fase 1 — mecânica (contrato do orquestrador)

Satélite de [`SKILL.md`](SKILL.md). Documenta o contrato do orquestrador compartilhado `scripts\Invoke-XpzKbParallelPrePushPhase1.ps1`, que consolida os gates mecânicos da rotina pré-push de **pasta paralela de KB**. Fonte de verdade é o próprio motor; este satélite espelha o contrato para o agente consumidor.

> **Esta é a Fase 1 da pré-push de pasta paralela — não é o documento [`13`](../13-revisao-pre-push.md)** (a pré-push do repositório de skills).

## Invocação

```text
pwsh -File <repo-skills>\scripts\Invoke-XpzKbParallelPrePushPhase1.ps1 -RepoRoot <pasta-paralela-da-KB>
```

- **`-RepoRoot`** *(default: diretório corrente)* — raiz da pasta paralela da KB a validar.
- **`-BaseRef`** *(default: `origin/main`)* — referência git base; o intervalo avaliado é `BaseRef..HEAD`.
- **`-ConfigPath`** *(default: `<RepoRoot>\kb-parallel-pre-push.config.json`)* — config local (wrappers K8/K9 + tokens de camada).
- **`-SkipFetch`** *(switch)* — pula `git fetch origin`; usa a `BaseRef` local atual **conscientemente** (ver `fetchStatus` abaixo).
- **`-AsText`** *(switch)* — saída humana em vez do JSON padrão. **`-AsJson` é no-op** (JSON já é o default).

## Contrato de saída

JSON de máquina por padrão no stdout, com os campos: `range`, `baseRef`, `repoRoot`, `pushReadiness`, `fetchStatus`, `configFound`, `commitsAhead`, `commitsBehind`, `gates[]` (cada gate: `id`, `status`, `message`, `detail`).

- **`fetchStatus`**: `skipped` (com `-SkipFetch`) | `ok` (fetch bem-sucedido) | `failed` (fetch falhou → gate G0 `unknown`). `skipped` e `ok` **não** são erro e não adicionam gate G0.
- **`configFound`**: `true`/`false` — se o `kb-parallel-pre-push.config.json` foi lido.

### Severidade consolidada (`pushReadiness`)

Os gates emitem `ok` / `warn` / `block` / `unknown`. A consolidação é **fail-closed**:

| Há algum `block`? | Há algum `unknown`? | Há algum `warn`? | `pushReadiness` | exit |
|---|---|---|---|---|
| sim | — | — | `blocked` | **1** |
| não | sim | — | `blocked` | **1** |
| não | não | sim | `warn` | **2** |
| não | não | não | `ready` | **0** |

**`unknown` ⇒ `blocked`** (nunca tratar como "ok"): um gate que não conseguiu decidir (falha de git, `BaseRef` inválido, exceção ao invocar motor) bloqueia o push em vez de deixar passar um `ready` falso. Os exit codes `0/2/1` seguem a mesma convenção do documento `13`, mas aqui `2`=warn **não** é erro.

## Tabela de gates

| Gate | Severidade | O que valida | Notas de contrato |
|---|---|---|---|
| **G0** fetch | `unknown` se falhar | `git fetch origin` (a menos de `-SkipFetch`) | só adiciona gate quando o fetch **falha**; `fetchStatus` registra `skipped`/`ok`/`failed` |
| **G1** commitsBehind | `block` (>0) · `unknown` (BaseRef inválido) | remoto à frente | `rev-list` falho (ex.: `BaseRef` inexistente) → `unknown`, `commitsBehind=null`; `commitsBehind>0` → `block` |
| **G2** branch | `warn` | branch ≠ `main` | detached HEAD → `branch=''` → `warn` (guarda StrictMode) |
| **G3** working tree | `warn` | mudanças não commitadas | **ignora só `<indexDirName>/` (default `KbIntelligence/`) quando UNTRACKED** (`?? KbIntelligence/`); arquivo do índice rastreado/modificado ainda alerta |
| **G4** diff --check | `block` · `warn` (override) · `unknown` | whitespace no `BaseRef..HEAD` | roda `git diff --no-renames --check` e classifica linhas parseadas por caminho; hits sob `<acervoDirName>/` (default `ObjetosDaKbEmXml/`) → `warn`; hits sob `<frontDirName>/` (default `ObjetosGeradosParaImportacaoNaKbNoGenexus/`) em arquivo adicionado no range → `warn`; hits sob a frente em arquivo rastreado/modificado ou em qualquer outro caminho → `block`; exit≠0 sem linha parseável → `unknown` (BaseRef/range inválido); linhas parseáveis sem nenhuma classificação conhecida → `unknown` defensivo. No JSON, `detail[]` preserva linhas de `git diff --check` como objetos `{ path, line, message, classification }`; linhas não parseáveis usam `path`/`line` nulos e `classification='unparsed'`. `warn` não autoriza limpeza global: corrigir só linhas novas/editadas; o 9-FD decide trim forte quando houver baseline por GUID único. |
| **G5** parse PS | `block` | parse dos `*.ps1` **LOCAIS** | parseia os `.ps1` em **`<RepoRoot>\scripts`** (wrappers da **pasta paralela**), não os scripts do repo de skills; erro de parse → `block` |
| **K1/K2** paths perigosos | `block` · `unknown` | `Test-XpzKbDangerousPaths.ps1` | motor com `status=unknown` (ex.: git falho) → gate `unknown` (**anti-fail-open**: lê o status top-level para o gate não sumir da consolidação — sumir é que seria fail-open; com ele o `unknown` propaga e consolida em `blocked`, fail-closed) |
| **K3/K4** camadas | `warn` · `unknown` | `Test-XpzKbLayerDiff.ps1` | camada derivada/oficial; severidade do motor mapeada `warn`/`unknown`/→`ok` |
| **K8** auditoria de setup | `warn` · `block` | wrapper local + `Test-XpzSetupAudit.ps1 -AsJson` | contrato estruturado; ver "Estados de K8" abaixo |
| **K9** gate de índice | `block` se não OK | wrapper local + `Test-XpzKbIndexGate.ps1 -AsJson` | `status='OK'` → `ok`; senão → `block` com `reason` |
| **K11** antipattern not-not | `block` · `unknown` | `Test-XpzNotNotIsAntipattern.ps1` | achados de `not not X.IsXxx()` no acervo → `block`; git falho → `unknown` |

## Descoberta de wrapper local (K8/K9)

Os gates **K8** e **K9** delegam a **wrappers locais** da pasta paralela, resolvidos por `Resolve-LocalWrapper` nesta ordem, com 4 desfechos possíveis (`resolvedBy`):

1. **`config`** — o campo da config (`setupAuditWrapper` para K8, `indexGateWrapper` para K9) aponta um arquivo em `<RepoRoot>\scripts`. Se o arquivo **existe** → `ok=true`, `resolvedBy='config'`. Se o arquivo **não existe** → `ok=false`, **ainda** `resolvedBy='config'` (não há um literal `'config-inexistente'`) → gate `block`.
2. **`convention`** — sem config, procura pela convenção (`Test-*KbSetupAudit.ps1` / `Test-*KbIndexGate.ps1`) em `<RepoRoot>\scripts`. **Exatamente 1** candidato → `ok=true`, `resolvedBy='convention'`.
3. **`none`** — sem config e **nenhum** candidato pela convenção → `ok=false`, `resolvedBy='none'` → gate `block` (fail-closed).
4. **`ambiguous`** — sem config e **≥2** candidatos → `ok=false`, `resolvedBy='ambiguous'` → gate `block` (declare o wrapper em `kb-parallel-pre-push.config.json`).

> Os valores literais de `resolvedBy` são apenas **`config | convention | none | ambiguous`**. Um self-test ou consumidor que esperar `'config-inexistente'` está errado: o caso "config aponta arquivo inexistente" é `resolvedBy='config'` com `ok=$false`.

Se o wrapper resolve mas **não emite contrato estruturado** (`-AsJson` falha / não retorna JSON), K8/K9 caem em `block` com "setup desatualizado" → corrigir via `xpz-kb-parallel-setup`.

## Estados de K8 (contrato compartilhado com `xpz-kb-parallel-setup`)

K8 lê `estado_operacional_sugerido` do `Test-XpzSetupAudit.ps1 -AsJson` e mapeia:

- **verdes → `ok`**: `materializado_e_indice_validado`, `wrappers_atualizados`, `pronto_para_primeira_materializacao`.
- **vermelhos → `block`** (fail-closed): `runtime_powershell_bloqueado`, `auditoria_incompleta`.
- **qualquer outro estado → `warn`**.

K9 lê `status`/`reason` do `Test-XpzKbIndexGate.ps1 -AsJson`: `status='OK'` → `ok`; senão → `block` com o `reason`.

> Esses literais (`estado_operacional_sugerido` de K8; `status`/`reason` de K9) são **contrato compartilhado** com `xpz-kb-parallel-setup` (que materializa e mantém os wrappers locais). Renomeá-los lá quebra K8/K9 aqui — alterar nos dois lados juntos.

## Tokens de camada (parametrização por config)

O orquestrador lê tokens de camada do `kb-parallel-pre-push.config.json` (bloco `layerTokens`), com fallback para os defaults da casa, e os repassa aos motores K1–K4:

| Token | Default | Usado em |
|---|---|---|
| `tempDirNames` | `["Temp"]` | K1/K2 (paths perigosos) |
| `nativeKbRootPattern` | `(?i)(^|[\\/])GxModels[\\/]` | K1/K2 (raiz da KB nativa) |
| `indexDirName` | `KbIntelligence` | G3 (untracked ignorado), K3/K4 |
| `acervoDirName` | `ObjetosDaKbEmXml` | G4 (override de whitespace), K3/K4, K11 |
| `frontDirName` | `ObjetosGeradosParaImportacaoNaKbNoGenexus` | G4 (override de whitespace em XML novo/adicionado da frente) |
| `metadataFileName` | `kb-source-metadata.md` | K3/K4 (evidência de camada/sync) |

Só declarar `layerTokens` na config quando a pasta paralela usar nomes **não-padrão**; caso contrário os defaults bastam (ver `examples/kb-parallel-pre-push.config.json.example`).
