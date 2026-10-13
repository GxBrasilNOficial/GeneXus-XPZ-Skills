# Plano de execução — Detecção de comment-based help inconsistente / ajuda invisível no inventário de wrappers

- **Skill alvo:** `xpz-kb-parallel-setup`.
- **Repositório:** `C:\Dev\Knowledge\GeneXus-XPZ-Skills` (branch `main`).
- **Estado:** **implementado** em 2026-10-12 — commits materiais `6772a94` (motor + self-tests + docs) e `7538e62` (dedup de achados), correções doc `91a6e1b`/`2e4b92a` e registro no `999` em `d70a3fc`. Plano **congelado** que guiou a execução; mantido na raiz como registro da frente (§10).
- **Fechamento:** pré-push executada (mecânica + semântica) **sem push**; `VEREDICTO: nenhum gap confirmado`. Nota de rollout: alterar os dois motores muda a assinatura de setup → pastas paralelas entram em `AUDIT_REQUIRED`, e wrapper com o defeito-alvo flipa para não-limpo até correção (§6).
- **Origem:** defeito apontado por revisor externo numa pasta paralela real; plano validado por revisão por pares multi-modelo (recibo na §9).
- **Para a nova sessão:** ler `README.md` e `AGENTS.md` da raiz antes de agir; manter tudo em `main`; apresentar o que será alterado e aguardar aprovação antes de gravar (a execução foi pré-aprovada em bloco, mas confirmar escopo com o usuário no início da sessão).

---

## 1. Problema

O motor `scripts/Test-XpzWrapperInventory.ps1` audita wrappers locais de uma pasta paralela de KB contra os moldes canônicos `xpz-kb-parallel-setup/examples/*.example.ps1`. Ele valida a superfície `param()`/`ValidateSet`, o motor compartilhado chamado, a diretiva `#requires` e alguns sinais textuais — **mas não interpreta o comment-based help**. Consequências observadas:

1. Um wrapper local tinha, no bloco `.EXAMPLE`, uma flag (`-AsJson`) que **não existe** no seu `param()`; copiar o exemplo lança «A parameter cannot be found that matches parameter name 'AsJson'». A autoditoria classificou o wrapper como conforme e **não** sinalizou.
2. `#requires -Version 7.4` **colado** ao `<#` (sem linha em branco) torna o bloco de ajuda invisível ao `Get-Help`. Medido numa pasta paralela real: **22 de 24** wrappers invisíveis, 1 visível, 1 sem `.SYNOPSIS`.

Os moldes canônicos foram corrigidos (linha em branco após `#requires`) em 2026-10-12, mas os wrappers **já materializados** nas pastas paralelas **não** foram propagados.

**Impacto de assinatura:** `scripts/Test-XpzWrapperInventory.ps1` e `scripts/XpzWrapperEngineParamSupport.ps1` estão em `xpz-kb-parallel-setup/setup-contract.manifest.json` (linhas 13-14). Alterá-los **muda a assinatura de setup** e pode exigir reauditoria das pastas paralelas.

---

## 2. Objetivo

Fazer a autoditoria completa (`Test-XpzWrapperInventory.ps1`, via `Test-XpzSetupAudit.ps1`) detectar essa classe de defeito em vez de classificá-la como conforme, **sem quebrar wrappers conformes** e **sem sobre-engenharia**.

---

## 3. Design congelado

Novo helper `Get-XpzHelpSurfaceFinding` em `scripts/XpzWrapperEngineParamSupport.ps1`.

### 3.1 Assinatura sugerida

```
Get-XpzHelpSurfaceFinding -WrapperPath <path> [-AlternateSelfLeaf <string[]>] [-MoldePath <path>]
  -> [pscustomobject]@{ Blocking = @(@{Reason;Detail}); Advisory = @(@{Reason;Detail}); EngineDiagnostics = @(@{Reason;Detail}) }
```

- `-WrapperPath`: o wrapper local.
- `-AlternateSelfLeaf`: nomes alternativos que contam como «o próprio script» (o inventário passa o nome-base do molde, ex.: `Query-KbIntelligence.ps1`), além do leaf real do arquivo. **Item absorvido do P0 da revisão (§9).**
- `-MoldePath`: opcional; habilita a paridade de molde.

### 3.2 Canais e razões

| Canal | Rótulo/saída | Quando |
|---|---|---|
| Bloqueante | `INVENTORY_CUSTOMIZED(reason=help_example_undeclared_param:-<flag>)` | flag, numa invocação **do próprio script** no `.EXAMPLE`, fora do conjunto aceito; **só** em script **advanced** com `param()` de topo. Reporta o nome **canônico** resolvido. |
| Advisory | `INVENTORY_HELP_ADVISORY(reason=help_invisible)` | tem `.SYNOPSIS` mas `Get-Help -Full` não devolve o texto documentado. |
| Advisory | `INVENTORY_HELP_ADVISORY(reason=help_parameter_orphan:-<x>)` | `.PARAMETER x` sem `$x` declarado (pulado se não há `param()` de topo). |
| Advisory | `INVENTORY_HELP_ADVISORY(reason=help_example_unknown_flag_simple_script:-<flag>)` | flag desconhecida no `.EXAMPLE` de script **simple** (não-advanced): cai em `$args`, não bloqueia. |
| Infra | `INVENTORY_ENGINE_DIAGNOSTIC(reason=help_query_failed)` | `Get-Help` lançou/indisponível (não é defeito do wrapper). |
| Infra | `INVENTORY_ENGINE_DIAGNOSTIC(reason=help_molde_<...>)` | achado **no molde** (paridade): defeito da referência. |

`INVENTORY_HELP_ADVISORY` fica **fora** do regex de 4 tokens de pendência do agregador (`Test-XpzSetupAudit.ps1`, linha ~409) — mesmo precedente de `INVENTORY_ENGINE_DIAGNOSTIC`/`INVENTORY_SURFACE_ADVISORY`.

**Critério de severidade (explícito).** O discriminador é «bloqueia só o que **quebra o comando documentado**»: `.EXAMPLE` órfão quebra a execução (script advanced → o binder lança) → **bloqueante**; `.PARAMETER` órfão apenas descreve mal → **advisory**. Mesma família («o help cita algo que não existe»), **consequências** diferentes — a assimetria é intencional, não descuido.

**Roteamento e grau de remediação.** O achado bloqueante entra como `INVENTORY_CUSTOMIZED(reason=help_example_undeclared_param:-<flag>)` — a mesma rota de bloqueio-com-motivo do `surface_mismatch` (não existe — nem se cria — token bloqueante próprio; **não** ampliar o regex do agregador). Para **não** sobrecarregar o significado «wrapper divergiu do molde»: a remediação de `help_example_undeclared_param` é **determinística e barata** — realinhar o exemplo ao `param()` preservando defaults locais, **não** o menu A/B/C/D de wrapper customizado. Normatizar essa exceção na `SKILL.md` (8.c), no mesmo espírito da exceção determinística do `Get-*KbMetadata.ps1` (8.a.iii).

### 3.3 Regras

- **Conjunto aceito (advanced)** = nomes de `param()` ∪ `[Alias]` (canonicalizados por parâmetro) ∪ `CommonParameters` ∪ **prefixo não-ambíguo de um único parâmetro distinto**.
  - **Fonte normativa:** alias e common parameters vêm de **`Get-Command.Parameters`** (como já faz o helper, `XpzWrapperEngineParamSupport.ps1:390-452`), **nunca** de lista hardcoded. *(Item absorvido do P1 da revisão.)*
  - Prefixo: `-Pref` é aceito se casar **um único parâmetro distinto** (várias grafias/aliases do mesmo parâmetro não contam como ambiguidade). Flag realmente desconhecida mantém a **grafia encontrada** (não há nome canônico).
- **Formas de invocação reconhecidas** (para o próprio script):
  1. `.\<leaf>.ps1` (caminho literal);
  2. `& (Join-Path <raiz> '<...>\<leaf>.ps1')` — extrair o **leaf literal** reusando `Get-XpzAstJoinPathLeaf` (já existente no helper). Cobre o wrapper local de K9.
  - **«Self» = leaf `-ieq` a** `<nomeRealDoArquivo>` **OU** a qualquer `-AlternateSelfLeaf` (nome-base do molde). Isso cobre genérico-não-reescrito **e** prefixado-atualizado.
  - `pwsh`/`powershell -File`: **fora de escopo** (documentado). O molde `Update-KbFromXpz` já tem outras invocações `.\X.ps1` cobertas.
  - Invocação por `$var`/splat/pipeline: **fora de escopo** (FN consciente).
- **`dynamicparam`** → exemplo **pulado** (inconclusivo). **Sem `param()` de topo** → exemplo **pulado**; `help_parameter_orphan` também pulado.
- **Visibilidade:** `help_invisible` só quando há `.SYNOPSIS`; invisível sse a sinopse de `Get-Help -Full` é vazia/auto-gerada. Comparar o texto do `.SYNOPSIS` da fonte com a sinopse runtime via `IndexOf(..., OrdinalIgnoreCase)` — **nunca** `-like` (a crase é escape de curinga; dá falso positivo). Script sem bloco de ajuda algum não gera `help_invisible`.
- **Supressão por molde (paridade):** suprime **apenas** o bloqueio de (motivo, flag) **idêntico** achado no molde, com chave normalizada **case-insensitive**. **Nunca** suprimir bloqueio local por molde com ajuda invisível, erro de `Get-Help` ou parse quebrado (isso vira `INVENTORY_ENGINE_DIAGNOSTIC`).

### 3.4 Spec do parser de `.EXAMPLE`

- Percorrer as seções `.EXAMPLE` (podem ser várias), encerrando em `#>` ou no próximo keyword de ajuda (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/...).
- Juntar continuação por crase; `;` separa comandos (analisar cada `CommandAst` separadamente).
- Analisar **apenas** comandos cujo alvo casa as formas da §3.3.
- Extrair flags por `CommandParameterAst.ParameterName` (`-Param:$v` → `Param`, sem o `:valor`).
- Tratar: `-Param $v`, switch, `Tipo:Nome` e caminhos com/sem aspas, comentários `#`.
- Pular (conservador): splat `@f`, alvo `$var`, `pwsh`/`powershell`, o que não parseia.
- Nome do molde esperado = arquivo **sem o sufixo `.example`**; nome local = nome real do arquivo.

### 3.5 Não-objetivos (anti-sobre-engenharia — manter)

- Sem resolvedor de fluxo de dados para `.EXAMPLE`.
- **Um só** mecanismo de visibilidade (`Get-Help` runtime); **sem** detector estático paralelo.
- Sem expansão de splat.
- Reuso da extração existente (não redesenhar alias/superfície).
- Sem remap genérico de prefixo KB (o caso K9 local resolve-se pela forma `Join-Path`; a paridade do molde K9 fica fora, documentada).

---

## 4. Mudanças por arquivo

1. **`scripts/XpzWrapperEngineParamSupport.ps1`** — novo helper `Get-XpzHelpSurfaceFinding` (§3) + atualizar `.SYNOPSIS`/`.DESCRIPTION` do arquivo.
2. **`scripts/Test-XpzWrapperInventory.ps1`** — no ramo `$standardExists`, chamar o helper passando `-WrapperPath $standardPath -AlternateSelfLeaf @($baseName+'.ps1') -MoldePath $examplePath`; rotear `Blocking`→`INVENTORY_CUSTOMIZED(reason=...)`, `Advisory`→`INVENTORY_HELP_ADVISORY`, `EngineDiagnostics`→`INVENTORY_ENGINE_DIAGNOSTIC`. Atualizar o bloco `.DESCRIPTION`/`.OUTPUTS` (novo rótulo).
3. **`scripts/Test-XpzSetupAudit.ps1`** — **não** alterar o regex de bloqueio (linhas ~403-409); atualizar apenas o comentário inline citando o novo rótulo consultivo.
4. **`scripts/Test-XpzWrapperInventorySelfTest.ps1`** — casos de unidade + e2e + estender a guarda-regressão do regex (linhas ~631-645) para `INVENTORY_HELP_ADVISORY`.
5. **`scripts/Test-XpzWrapperEngineParamSupportSelfTest.ps1`** — casos do helper.
6. **`scripts/Test-XpzWrapperEngineParamMoldesSelfTest.ps1`** — asserção de recorrência: todo molde tem ajuda visível e **0** órfão em `.EXAMPLE` (para os que têm invocação do próprio nome).
7. **`xpz-kb-parallel-setup/SKILL.md`** — 8.a.ii (razões `help_*`); 8.a.i; 8.c (exceção determinística do exemplo órfão, §3.2); tabela de rótulos (~121); handoff (~878-882); proibições (~1104-1106); tabela 8.h; descrição de `wrappers/inventario` (~53, ~82). **Obrigatório:** normatizar que a linha `INVENTORY_HELP_ADVISORY:` é **reproduzida literalmente** no handoff e que o agente **não** declara estado limpo ignorando os achados — espelhando o tratamento já dado a `INVENTORY_SURFACE_ADVISORY` (senão a classe «ajuda invisível» pode voltar a passar em silêncio, que é a outra metade do furo original).
8. **`09-inventario-e-rastreabilidade-publica.md`** — atualizar ponteiros de 1 linha de `XpzWrapperEngineParamSupport.ps1` (linha ~77) e `Test-XpzWrapperInventory.ps1` (linha ~96).
9. **`02-regras-operacionais-e-runtime.md`** — na regra do `#requires` (~linha 59), acrescentar que a diretiva deve ter **linha em branco** antes do bloco de ajuda — **necessária, mas não suficiente** (há exceções registradas no `999`).
10. **`CHANGELOG.md`** — entrada trilíngue.
11. **`999-ideias-pendentes.md`** — registrar a subfrente «prevenção» como implementada (mover o resíduo para o histórico mensal conforme a política do arquivo).
12. **`setup-contract.manifest.json`** — sem arquivo novo; a assinatura muda pelos itens 1-2.

---

## 5. Self-tests (casos mínimos)

**Unidade (`Get-XpzHelpSurfaceFinding`):**
- `.EXAMPLE` com flag inexistente em script advanced → `help_example_undeclared_param`.
- `[Alias]` usado no `.EXAMPLE` → **não** acusa.
- Prefixo não-ambíguo (`-Pref`) de um único parâmetro → **não** acusa; prefixo ambíguo entre **dois parâmetros distintos** → acusa.
- Prefixo de **alias** (`-Fo` para o alias `Foo`) → **não** acusa: o PowerShell liga prefixo de alias e o prefixo casa qualquer grafia do **mesmo** parâmetro (aliases do mesmo parâmetro não contam como ambiguidade).
- Seção `.EXAMPLE` que **não parseia** → **pulada**, sem finding (conservador).
- Common parameter (`-Verbose`/`-ErrorVariable`) → **não** acusa (fonte `Get-Command.Parameters`).
- Invocação de **outro** script no `.EXAMPLE` → não acusa.
- Script **simple** com flag desconhecida → advisory, **não** blocking.
- `dynamicparam` / sem `param()` de topo → pulado, sem finding.
- `.EXAMPLE` com `;`, crase, `-Param:$v`, comentário `#`, `Tipo:Nome` → parse correto.
- Invocação via `& (Join-Path ... '<leaf>.ps1')` → analisada.
- `.PARAMETER` sem `$x` → `help_parameter_orphan`.
- Ajuda invisível (`#requires` colado) → `help_invisible`.
- **Obrigatório — caso `-AlternateSelfLeaf`:** wrapper local prefixado cujo `.EXAMPLE` invoca o **nome genérico do molde** (`.\Query-KbIntelligence.ps1`) deve ser analisado como «self»; invocação a um **terceiro** script continua fora. É o P0 do dissidente da v3 (sem isso o gate é vácuo no fluxo de bootstrap).
- **Dois bugs de protótipo a travar em teste:** (a) retorno de `HashSet` de função é **enumerado** pelo pipeline → usar `return ,$set`; (b) `-like`/`-notlike` com crase → usar `IndexOf(OrdinalIgnoreCase)`.

**Verificações de visibilidade:** usar `Get-Help -Full`; medir custo (~0,6 s/24 wrappers).

**e2e (`Test-XpzWrapperInventorySelfTest.ps1`):**
- Wrapper conforme permanece conforme; wrapper com defeito-alvo sai `INVENTORY_CUSTOMIZED`.
- Advisory-só **não** vira `INVENTORY_CUSTOMIZED` e **não** gera `INVENTORY_OK`.
- Guarda-regressão: o regex do agregador **não** casa `INVENTORY_HELP_ADVISORY`.

**Parse:** `[System.Management.Automation.Language.Parser]::ParseFile` sem erros nos scripts alterados.

---

## 6. Rollout e reauditoria

- **Sequência obrigatória:** publicar o motor **primeiro**, depois normalizar as pastas paralelas (nunca o inverso).
- Tocar o motor muda a **assinatura de setup** → as pastas paralelas entram em `AUDIT_REQUIRED` até reauditar.
- **Efeito pretendido (não é regressão):** após publicar o motor, qualquer pasta paralela cujo wrapper tenha o `.EXAMPLE` órfão **flipa para não-limpo** (`INVENTORY_CUSTOMIZED`) até o wrapper local ser corrigido. É o objetivo — força o fix do `-AsJson` — e deve estar **previsto no handoff** para não ser lido como regressão.
- Registrar isso na `SKILL.md` (Frente 3, §7).

---

## 7. Frente 3 (documental — não executar daqui)

Descrever na `SKILL.md` um passo **opcional** de normalização dos wrappers **já materializados** nas pastas paralelas (aplicado pelo **agente da pasta**, com aprovação):
- inserir a **linha em branco** após `#requires` (recupera a ajuda);
- corrigir o exemplo órfão (remover a flag inexistente).
- A correção do exemplo órfão **não** é opcional para declarar estado limpo.
- **Este** repositório **não** grava em pasta paralela; apenas expõe o comando/instrução.

---

## 8. Evidência reproduzível

- Varredura dos **24** moldes `xpz-kb-parallel-setup/examples/*.example.ps1`: **20** têm invocação literal do próprio nome no `.EXAMPLE` e **0** achados; **4** fora de escopo (`Get-KbLastUpdate`, `New-KbFront`, `Notify-TaskComplete`, `Test-KbIndexGate` — o último invoca via `& (Join-Path … 'Test-FabricaBrasilKbIndexGate.ps1')`).
- Protótipo (fora do repo, PowerShell 7.6.6) contra pasta paralela real: **1** bloqueio (`help_example_undeclared_param:-AsJson` em `Copy-…KbAcervoToFront.ps1`) + **21** `help_invisible`, 0 `help_parameter_orphan` naquele momento.
- Método: por arquivo, extrair `.EXAMPLE` até `#>`, reconstituir a linha (crase), `Parser::ParseInput`, casar o leaf (formas §3.3), comparar com `param()`∪alias∪common; visibilidade por `Get-Help -Full`.
- **Limite declarado:** as medições não foram anexadas ao repo; a sessão de execução **deve reproduzi-las, obrigatoriamente**, com o método acima e **travar os números** nos self-tests. Medição não reproduzida permanece como resíduo aberto — não declarar prova.

---

## 9. Recibo da revisão por pares

**Metodologia:** `xpz-llm-delegate/SKILL.md` + `15-revisao-por-pares.md`. **Painel (curadoria opencode):** `commandcode/meta/muse-spark-1.3-contributor` (meta), `openai/gpt-6.1-sol` (openai), `commandcode/stealth/space-bunny-alpha` (stealth, **error** — não conta), `anthropic/claude-opus-5-5` (`skippedByHumanDecision` — Opus ignorado a pedido). **Piso:** `panelReady` (meta + openai = 2 famílias). Payload `public`. <!-- backend-parity: ignore -->

| Rodada | RoundId | Vereditos | Fechamento |
|---|---|---|---|
| v1 | `helphlp-v1-20261012-1751` | meta: revisar (3 P0); openai: revisar (4 gaps) | `notProduced` |
| v2 | `helphlp-v2-20261012-1828` | meta: revisar (2 P0); openai: revisar (2 P1) | `notProduced` |
| v3 | `helphlp-v3-20261012-1841` | meta: **rejeita** (1 P0: leaf prefixado); openai: **concorda, sem gap relevante** | `resubmissionDeclinedByHuman` |

- **Convergência formal não atingida** na v3 (1 dissidente). O P0 do dissidente foi **aceito como válido e absorvido** (§3.3, `-AlternateSelfLeaf`); o outro revisor aprovou o desenho. Por decisão humana (última rodada), a versão consolidada **não** foi re-submetida; a prova migra para implementação/self-test. Estado registrado: `vNextState=resubmissionDeclinedByHuman`, `closeoutReady=true`, `diversityState=panelReady`.
- Pareceres brutos (fora do repo): `%LOCALAPPDATA%\Temp\xpz-llm-panel-dispatch\helphlp-v1-20261012-1751\`, `...\helphlp-v2-20261012-1828\`, `...\helphlp-v3-20261012-1841\`. Manuscritos em `%LOCALAPPDATA%\Temp\opencode\peerreview\`.

---

## 10. Checklist de execução (nova sessão)

1. Ler `README.md`, `AGENTS.md`, e este plano; confirmar escopo com o usuário.
2. Implementar o helper (§3) em `XpzWrapperEngineParamSupport.ps1`.
3. Integrar no inventário (§4.2) e comentário no agregador (§4.3).
4. Escrever os self-tests (§5) — incluindo casos negativos e os 2 bugs de protótipo.
5. Rodar: parse (`Test-PsScriptsParse.ps1` quando existir) + os 3 self-tests + `Test-XpzWrapperInventorySelfTest.ps1`.
6. Reproduzir a evidência (§8) e travar os números.
7. Documentação: `SKILL.md`, `09`, `02`, `CHANGELOG` trilíngue, `999` (§4.7-4.11).
8. Conferir paridade motor↔doc (referência `13-revisao-pre-push.md`) e que nenhum texto antigo contradiz a nova regra.
9. Rodar a rotina pré-push do repo (mecânica + fase semântica) antes de commit; só commitar com aprovação explícita.

**Critério de aceite:** autoditoria sobre estado equivalente ao da pasta paralela descrita produz achado explícito para (a) `-AsJson` órfão **bloqueante** e (b) ajuda invisível **advisory**; (c) o caso `-AlternateSelfLeaf` reconhece o exemplo de **nome genérico** num wrapper prefixado (senão o gate é vácuo no bootstrap); sem quebrar wrappers conformes (`Test-…KbPowerShellRuntime` permanece conforme) e com a linha `INVENTORY_HELP_ADVISORY:` **reproduzida no handoff**.

**Fora de escopo:** corrigir a pasta paralela a partir deste repo; alterar os moldes (já corretos); eliminar globalmente o uso de `-AsJson` (frente própria no `999`).
