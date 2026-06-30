# Hook `PreToolUse` positivo (auto-allow) do Claude Code — spec de design

> **ESCOPO — Claude Code apenas.** Esta solução é **exclusiva do Claude Code**: depende do hook
> `PreToolUse` com `permissionDecision: allow`, recurso que **não existe** em Codex/Cursor/OpenCode.
> O classificador (lógica de "comando read-only seguro?") é agnóstico de agente e poderia ser
> reusado **se** outra ferramenta expuser um gancho equivalente — hoje nenhuma expõe. O "fio" (a
> entrada de hook em `~/.claude/settings.json`) é **máquina-local** e não viaja como config.
>
> **Status:** design **congelado** (v4) após 3 rodadas de revisão por pares (3 famílias:
> `anthropic`/Opus, `openai`/Codex gpt-5.5, `ollama-cloud` deepseek-v4-pro/glm-5.2/kimi-k2.7-code) +
> Fase 0 confirmada na doc oficial. A polaridade **negativa** (barrar comando não-atômico) foi
> descartada — ver `998-ideias-descartadas-e-porque.md`. Esta é a spec que a implementação segue.
> Itens marcados **[self-test]** são requisitos de prova do corpus adversarial.
>
> **Estado de implementação:** Fase 1–2 do **caminho Bash** implementadas e cobertas por self-test
> (`scripts/Invoke-ClaudeCodePreToolUseSafeAllow.ps1`, `scripts/ClaudeCodePreToolUseSafeAllowSupport.ps1`,
> `scripts/Get-ClaudeCodeBashSafeSegments.py`, `scripts/Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1`;
> sentinela `OK: Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1`). O caminho **PowerShell retorna
> `defer`** (fail-closed) até a Fase 0 do campo de input PS ser confirmada empiricamente. Fases 3–5
> pendentes (ver `999-ideias-pendentes.md`).
>
> **Latência medida (2026-06-22):** ~**520 ms** por comando no caminho comum (fast-path, só `pwsh`) e
> ~**570 ms** no candidato a `allow` (sobe `python`). O custo é dominado pelo **startup do `pwsh` por
> chamada**, não pela lógica — **5× o orçamento p95 ≤ 100ms**. Conclusão: o enforce inline é inviável;
> o **daemon** (dissidência do kimi) é pré-requisito da Fase 4.

## 1. Objetivo

Hook `PreToolUse` do Claude Code que **auto-aprova** (`permissionDecision: allow`) comandos read-only
que a allowlist literal não expressa (sobretudo compostos read-only, ex.: `git log | head`), para
reduzir prompts de autorização. Em tudo o mais retorna **`defer`** (fluxo normal de permissão).
**Nunca** retorna `deny`.

## 2. Arquitetura travada

1. **Só `allow` ou `defer`, nunca `deny`.** Pior caso do `defer` = prompt como hoje.
2. **`allow` é risco ADITIVO** — roda antes da allowlist e a **bypassa inteira** (confirmado na
   Fase 0). Logo a gramática é **estreita** e **derivada da allowlist existente**: só `allow` se
   **todo segmento** for um verbo que já tem entrada atômica aprovada.
3. **Qualquer dúvida de parse → `defer`.** Gramática incompleta é intencional/conservadora.
4. **Parser de verdade, não regex:** `shlex` (Python) para Bash; AST nativo
   (`System.Management.Automation.Language.Parser`) para PowerShell. Tabelas E splitter **separados
   por ferramenta** — no PowerShell `&` é call operator legítimo (padrão `& "<repo>\scripts\*"`),
   não background.
5. **Allowlisting POSITIVO por (sub)verbo E flag** para os verbos de superfície pequena
   (`head`/`tail`/`rg`/`date`). Para `git` (superfície enorme) usa-se **allowlist de subcomandos
   read-only + reject-list de flags perigosas** (config/exec/escrita) — compromisso conservador
   declarado. Flag/token desconhecido em verbo de lista positiva → `defer`.
6. **Gate de segurança real = self-test ADVERSARIAL**, não o modo observação (que mede cobertura,
   não segurança).
7. **Fail-closed para `defer`** em qualquer exceção/timeout/saída inesperada/ambiguidade.

## 3. Fase 0 — resultado (confirmado na doc oficial)

- Input do hook (topo): `session_id`, `transcript_path`, `cwd`, `permission_mode`,
  `hook_event_name`, `tool_name`, `tool_input`.
- **Bash:** `tool_input.command` = **string crua** (não tokenizada) → o lexer é necessário.
- **`cwd` presente** → habilita o escopo (2c).
- **Decisão:** `allow` bypassa `permissions.allow`; `defer`/sem-decisão = allowlist aplica normal.
- **Residuais empíricos (falham seguro):** estrutura de `tool_input` do **PowerShell não documentada**
  → caminho PS retorna `defer` até confirmar o nome do campo; `tool_name` identifica a ferramenta;
  encadeamento de múltiplos hooks `PreToolUse` **não documentado** (como nunca damos `deny`, pior
  caso = nosso `allow` ignorado, seguro).

## 4. Gramática v1

### 4.1 Composição
Parsear o comando inteiro com o parser da ferramenta. Falha/constructo desconhecido → `defer`.
Quebrar em segmentos no nível superior (Bash: `|`/`||`/`&&`/`;`). **`allow` só se TODOS os
segmentos passam.** Qualquer redireção (`>`/`>>`/`*>`/`2>&1`/`<`/`<<`), subshell `(`/`)`, background
`&`, substituição `$()`/crase, expansão `$`/`${}`/`{}` → `defer` (tratado no helper Bash).

### 4.2 Verbos Bash aceitos
- **`git`** (subcomando read-only + reject de flags perigosas):
  - subcomando ∈ {`status`, `log`, `show`, `diff`, `rev-parse`, `branch`}.
  - `branch` só com **zero argumento posicional** OU flag de listagem (`--list`/`-a`/`--all`/`-v`/
    `-vv`/`-r`/`--show-current`); **qualquer posicional → `defer`** (senão `git branch <nome>` cria).
  - **Rejeitar sempre** (qualquer posição): `-c`, `--exec-path`, `--config-env`, `--ext-diff`,
    `--upload-pack`, `--receive-pack`, `--output[=]`, `-O`, `--open-files-in-pager`.
  - `-C <path>`/`--git-dir`/`--work-tree` consomem o argumento seguinte (mudam alvo, não executam).
  - Pager: no Bash tool do Claude Code o stdout é **não-tty** (pipe), então `git` **não** invoca o
    pager — por isso não se exige `--no-pager`. [Se algum dia rodar com stdout tty, exigir `-P`.]
- **`head`/`tail`** — rejeitar `-f`/`-F`/`--follow`/`--retry`/`--pid` (penduram); senão `allow`.
- **`rg`** — rejeitar `--pre`/`--pre-glob`/`--hostname-bin` (executam programa); senão `allow`.
- **`date`** — `allow` só se não houver argumento posicional que não comece com `+` (evita o set de
  relógio `date MMDDhhmm`).
- **`cat`, `wc`, `ls`** — read-only sem flag de escrita/exec; `allow`.

### 4.3 Fora da v1
`sed`, `awk`, `perl`, `find`, `pwsh -c`/`bash -c`/`sh -c`, `git fetch`, e os verbos PowerShell
(`Get-Content`/`Select-String`/`Get-ChildItem`/`Test-Path`/`Measure-Object`/`Get-Command`) enquanto
o caminho PS estiver em `defer`. Candidatos para depois: `git ls-files`/`git grep`/`git remote -v`/
`git config --get`, `sort`/`uniq`/`cut`/`tr`.

### 4.4 Fast-path (latência) — implementado
Pré-filtro barato in-process (`Get-PtuBashFastPath`): se o **primeiro token** do comando não é um
verbo read-only conhecido (`git`/`head`/`tail`/`rg`/`date`/`cat`/`wc`/`ls`), ou há newline, ou o
primeiro token traz `$`/crase, decide **`defer` na hora — sem subir `python`**. Só **escala** ao
parser pesado (shlex + tabelas) quando o comando é candidato a `allow`. O fast-path **só** produz
`defer` ou "escala" — **nunca `allow` direto** (invariante coberto por self-test; senão
`git branch topic`/`rg --pre` escapariam). Assim o caso comum (comando que não começa por verbo
read-only) custa sub-ms; o `python` só roda no caminho candidato. A medição de latência efetiva
(p95) continua sendo objetivo da Fase 3.

## 5. Escopo e fases

- **Escopo (2c):** lista configurável de raízes; default `["C:\Dev\Knowledge\GeneXus-XPZ-Skills"]`,
  sobrescrita por `PTU_SAFE_ALLOW_ROOTS` (separador `;`). `cwd` fora das raízes → `defer`.
- **Fase 1–2 (feito, Bash):** decisor + self-test adversarial (o gate). **Fase 3:** modo `-Observe`
  (sempre `defer`, mede cobertura + latência separando PS-only de Bash; orçamento **p95 do caminho
  quente ≤ 100ms**, senão daemon). **Fase 4:** ligar `-Enforce` só com self-test verde **E** observe
  sem `allow` inesperado. **Fase 5:** ligar Bash primeiro, PowerShell depois (confirmar antes o campo
  de input PS); `xpz-skills-setup` grava o path por máquina e valida existência + self-test antes de
  instalar o fio (fail-closed); documentar como desligar rápido e reportar falso-allow.

> **ATUALIZADO (reconciliação pós-Passo F, 2026-06-30 — fonte canônica: «Passo G» do
> `claude-code-pretooluse-implementacao-v1-plan.md`):** a descrição da **Fase 3 como modo `-Observe`
> in-process** acima é **anterior ao daemon**. Com o daemon, o observe da Fase 3 roda pelo **FIO REAL**
> (hook → cliente NativeAOT → daemon decide → mede latência; cliente sempre devolve `defer`), pois só ele
> caracteriza a **latência de concorrência** — condição pendente para liberar o enforce. O `-Observe`
> in-process fica restrito a medir **cobertura** offline, não é o observe do fio.

## 6. Limitação conhecida assumida (decisão consciente da v1)

Como `allow` bypassa a allowlist, o hook vira também **guardião do "ler o quê"**: verbos read-only
por path absoluto leem **fora do cwd** (ex.: `cat C:\...\secrets.txt`). Dentro do escopo read-only
isso é **aceitável na v1** e fica **registrado como limitação**, não defeito. Restringir operandos
de path à raiz configurada é evolução possível (fora da v1).

## 7. Dissidências registradas (reavaliação futura)

- **deepseek — escopo global (2a)** em vez de (2c): o atrito ocorre em qualquer pasta e o risco do
  global é baixo dada a gramática estreita + `defer` + nunca-`deny` + self-test adversarial. Base
  para alargar as raízes depois.
- **kimi — daemon (1c) já na v1** se o p95 passar de ~100ms: fallback pronto, não otimização
  prematura.
