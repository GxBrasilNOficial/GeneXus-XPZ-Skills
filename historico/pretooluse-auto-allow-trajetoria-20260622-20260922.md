# Trajetória do hook PreToolUse de auto-aprovação do Claude Code (2026-06-22 a 2026-09-22)

## Papel do documento

Registro de rastreabilidade técnica ("como chegamos aqui") da frente do hook `PreToolUse` de auto-aprovação (auto-allow) do Claude Code. O que vale **agora** não está aqui: estado vivo na entrada «Hook PreToolUse positivo (auto-allow) do Claude Code — Fases 3–5» do `999-ideias-pendentes.md`; ponteiros no `09-inventario-e-rastreabilidade-publica.md`; contrato em `claude-code-pretooluse-auto-allow-design.md`, `claude-code-pretooluse-daemon-design.md` e `claude-code-pretooluse-implementacao-v1-plan.md`; medições brutas em `historico/passo0-daemon-pretooluse-medicao-20260628/` e `historico/passoF-daemon-pretooluse-medicao-20260630/`.

Consolidado em 2026-09-22 a partir das notas de sessão do agente, para que decisões, achados e lições que só existiam fora do repositório fiquem versionados.

## Linha do tempo

| Data | Etapa | Resultado | Commits materiais |
|---|---|---|---|
| 2026-06-22 | Polaridade negativa (barrar comando) | Descartada (`998`) | `ec99b73` |
| 2026-06-22 | Design v4 + Fases 1–2 (decisor in-process, Bash) | Self-test verde; **latência ~520–570 ms/comando** (startup do `pwsh`) torna o enforce inline inviável → daemon vira pré-requisito | `2793bad` |
| 2026-06-27 | Design do daemon | Congelado após 4 rodadas de revisão por pares (3 famílias) | `1f88238` |
| 2026-06-28 | Passo 0 (medição, protótipos descartáveis) | Mediana ~520 → ~28 ms; p95 ~180 ms = piso de criação de processo do cliente (irredutível); escolha: NativeAOT + named pipe + python persistente | `25ffc7e`, `3124b19` |
| 2026-06-29 | Plano de implementação v1 | Congelado na v2.22 após convergência estrita (5 linhagens) | `4f73e7d` |
| 2026-06-29 | Passos A–D | Fonte única; `.cs` de canonicalização compilado em EXE e DLL; `buildContractPin`; identidade SID+repo+roots; daemon `pwsh`; cliente NativeAOT dispara-e-sai | `2764231`, `7497820`, `058848b`, `6b69156`, `e90bbd7`, `dfba783`, `4c3c491`, `1572f65`, `f3b202d`, `259a817`, `6c27afd`, `4cc2e63`, `f07f85e` |
| 2026-06-30 | Passo E (gate §8 adversarial) | Revelou 2 bugs reais (ver abaixo) | `a8a9152`…`700c95c`, `601386b`, `34562ba` |
| 2026-06-30 | Passo F (medição do fio real) | Overhead e2e−floor ~20–34 ms: **reprova** o gate literal de 5 ms do §9-0e; fio aprovado no mérito por decisão datada do autor | `ff0e5b5`, `5db5734`, `d8b04c8`, `d212120` |
| 2026-06-30 / 07-01 | Passo G (observe, install, wire) | Modo observe no fio real; instalador com deploy e `-Wire`; correção da saída §3.1 (abster = não emitir nada) | `ddc0b89`, `cc8306a`, `74a34b9`, `5c04745`, `eb6b705`, `fe5cd37`, `1e4b8a6` |
| 2026-07-01 a 09-22 | Fase 3 (observe em uso real) | 1406 medições em 2 dias (10.322 até 09-22): zero `busy`, p50 2,4 ms / p95 5,4 ms no fio quente, 14% dos comandos Bash seriam auto-aprovados, 0 erros | `0e8f3a6` |
| 2026-09-22 | Fase 4 (`enforce`) | Ligada e validada ao vivo nas duas direções; §8 verde quando rodado isolado; paridade `09`/`CHANGELOG` | `73a8fb5`, `20ff8fd`, `df92376` |

## Mudanças de entendimento

- **Abster ≠ `defer` ≠ `ask` na saída do hook.** No modo interativo, `permissionDecision: "defer"` é headless-only e produz erro interno (o resultado da ferramenta se perde); `"ask"` força prompt **mesmo** sobre comando que a allowlist do usuário já aprovaria (regressão medida com uma sonda). O único "não opino" correto é sair com código 0 **sem** emitir `permissionDecision`. A primeira versão concluiu `ask` por inferência, sem testar "emitir nada"; um revisor apontou e a sonda confirmou. `defer` ficou como token **interno** (protocolo, lógica, gate §8).
- **Critério (i) do §9-0e (overhead ≤ 5 ms sobre o piso).** Reprovou no Passo F. O painel de revisão (5 vozes, 3 famílias) aceitou a tese de que o critério mede contra a grandeza errada (o que o fio elimina é o clique humano de ~1,5–10 s e o hook `pwsh` de ~466 ms), mas rejeitou a **forma** "gate vira alvo porque reprovou". Registro honesto: o (i) sempre foi alvo de eficiência, não gate de segurança; ficou uma meta datada (≤ 10 ms para o processamento do daemon) e a regra de que uma 3ª alteração do §9-0e exige novo painel.
- **Concorrência (P0 do painel).** O teste de rajada sintética mostrou comportamento fail-closed, mas **auto-contendia** (os clientes do teste e os daemons perdedores competiam entre si), então o número absoluto não servia. A resposta operacional veio da Fase 3 em uso real: zero enfileiramento.
- **§8 "vermelho" em 2026-09-05 e nas rodadas de 2026-09-22.** Não era bug: com o `enforce` vivo, todo comando Bash de qualquer sessão do Claude Code sobe o daemon, e isso contende com o gate. Isolado, passa verde (130 asserções).

## Bugs reais revelados por gate ou verificação

- **Hang do `Write-PtuFrame`** (Passo E): pipe com `outBuffer=0` + escrita síncrona sem timeout → um cliente que conecta, envia e não drena pendurava o daemon singleton (fail-closed, mas negação de disponibilidade). Correção C+A: `outBuffer` 4096 + `WriteAsync` com timeout. Escolha validada por experimento (baseline trava; C, A e C+A sobrevivem) e por painel de 5 famílias.
- **Enumeração de `.Name` sob StrictMode**: `$obj.PSObject.Properties.Name -contains 'x'` **lança** quando `$obj` é um PSCustomObject vazio (`'{}' | ConvertFrom-Json`). Trocado pelo indexer `.Properties['x']` nos 4 pontos da frente. O mesmo padrão existe em scripts de outras frentes, com risco baixo (objetos não vazios).
- **Re-dot-source dentro de função** (Passo C): `. $support` dentro de uma função define as funções no escopo filho, que é descartado; o recarregamento por staleness não tinha efeito. Passou a sinalizar e rodar o dot-source no escopo de script.
- **Número errado no relatório do passo 0**: "~16% negativos pareados" era um subconjunto; o conjunto inteiro dava 21,8/21,2%. Pego por recompute independente do CSV durante a revisão.
- **CSV do Passo F com vírgula decimal pt-BR**: quebrava `Import-Csv`; reparsado e harness fixado em `InvariantCulture`.

## Lições do host (Windows, PowerShell 7, .NET)

Úteis a quem mantiver o produto; várias também estão em comentários do código.

- APIs de ACL disponíveis no PS7: `NamedPipeServerStreamAcl`, `MutexAcl`, `FileSystemAclExtensions`. `[System.IO.File]::SetAccessControl` **não existe** no .NET Core → `[System.IO.FileSystemAclExtensions]::SetAccessControl([FileInfo], $acl)`.
- Inspeção de DACL: pipe via cliente conectado (`PipesAclExtensions::GetAccessControl`); mutex via `MutexAcl::OpenExisting(name, ReadPermissions)` (o overload de `Mutex::OpenExisting` mudou no .NET 9).
- DLL carregada pelo CoreCLR pode ser **renomeada** (abre com `FILE_SHARE_DELETE`), mas não modificada nem apagada no lugar → substituição = renomear a antiga e gravar a nova no mesmo caminho.
- `(Get-ChildItem '\\.\pipe\').Name` lança sob StrictMode (pipe transitório sem nome) → `[System.IO.Directory]::GetFiles('\\.\pipe\')`.
- Junction de diretório é criável sem admin; remover com `[System.IO.Directory]::Delete($link, $false)` — `Remove-Item -Recurse` numa junction pode apagar o conteúdo do alvo.
- Spawn do daemon pelo cliente com `UseShellExecute=true` + janela oculta: assim o filho **não herda** os std-handles do cliente; herdando o stdout, o hook ficaria pendurado depois de o cliente sair.
- O publish NativeAOT deixa ~15 processos `dotnet` órfãos (~1,7 GB) que contendem com o gate §8; `dotnet build-server shutdown` não os pega → o instalador mata por diferença de snapshot de processos.
- Builds MSBuild travando com reuso de nodes → `-nodeReuse:false -p:UseSharedCompilation=false`. `--no-incremental` não vale para `dotnet publish` → limpar `bin/obj`.
- `cmd.exe /c "...bat"` chamado pelo Git Bash sofre mangling de caminho (`/c` → `C:/`) e não roda o `.bat` → publicar o AOT pela ferramenta PowerShell.
- `ForEach-Object -Parallel` cria um runspace por iteração (~500 ms), mascara latência e pode vazar memória em loop longo → disparar processos diretamente. Scriptblock não atravessa runspaces (`& $using:fb` lança).
- Medição numa estação de trabalho ativa: não usar prioridade High (rouba CPU do usuário e cria artefato de contenção); preferir medição **diferencial** (piso intercalado, e2e − piso), que cancela a carga compartilhada. `Write-Host` fica em buffer e se perde se o processo for morto por timeout → marcadores de diagnóstico em stderr.
- Ao procurar processos por `CommandLine`, excluir o próprio comando de inspeção, senão ele casa consigo mesmo.
- Sob `historico/`, o `.gitignore` reabre tudo (`!/historico/**`) → adicionar arquivos de fonte explicitamente, nunca `git add -A` (entrariam centenas de binários).

## Lições de condução

- **Família de destino ≠ linhagem do modelo.** DeepSeek, Moonshot/Kimi e Zhipu/GLM servidos pelo mesmo provedor contam como uma família de destino para o gate mecânico, mas são 3 linhagens para diversidade cognitiva. Cortá-los por "mesma família" removeu diversidade real.
- **Mudar um comportamento exige varrer os termos antigos em todos os tipos de arquivo** (`.md`, `.ps1`, `.cs`, `.py`). A troca "defer na saída → abster" precisou de ~8 levas de correção na revisão pré-push reforçada, quase todas de propagação incompleta.
- **A revisão pré-push dos revisores não audita lógica de código.** O único gap restante (limitação de formato do merge textual do `-Wire`) só apareceu na verificação empírica.
- **Teste de validação com falso positivo:** `git log --oneline -5 | cat` "passou sem prompt" porque as duas partes já estavam na allowlist. Validar com um comando **fora** da allowlist (`git rev-parse HEAD`) e forçando a ferramenta Bash; modelos menores tendem a escolher a ferramenta PowerShell, que o hook não cobre.
- **Erro registrado (2026-09-22):** o `enforce` foi ligado sem antes reconferir o §8 vermelho de 2026-09-05, com o argumento equivocado de que o observe já o exercitava (o observe se abstém sempre e não exercita o gate). O §8 foi reconferido em seguida e passou isolado.
