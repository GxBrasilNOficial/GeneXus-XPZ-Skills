---
name: xpz-sync
description: Executa sincronização ou conferência de XPZ de uma KB GeneXus chamando os scripts locais do repositório ativo
---

# xpz-sync

Invoca os scripts locais do repositório GeneXus ativo para sincronizar XMLs individuais a partir de um XPZ exportado pela IDE, ou para conferir um export completo da KB.

---

## GUIDELINE

Identificar a raiz do repositório pelo contexto, localizar os scripts de sincronização na pasta `scripts\`, montar o comando correto e executá-lo via Bash. Reportar o resultado de forma clara. Não alterar arquivos manualmente — delegar tudo ao script. Tratar `ObjetosDaKbEmXml` como snapshot oficial somente leitura para agentes e não antecipar manualmente nenhuma promoção para esse acervo. Distinguir sempre a pasta nativa da KB da pasta paralela da KB. Se houver edição detectada ou pretendida em `ObjetosDaKbEmXml` para delta ainda não reexportado oficialmente pela KB, tratar isso como erro explícito de processo.

- `ObjetosDaKbEmXml` é o snapshot oficial da KB e nunca deve ser alterado manualmente pelo agente.
- `ObjetosDaKbEmXml` só pode ser atualizado pelo fluxo oficial de `sync`, a partir de `XPZ` exportado pela IDE do GeneXus.
- XML gerado localmente para importação, mesmo após preview ou importação bem-sucedida, nunca deve ser promovido manualmente para `ObjetosDaKbEmXml`.
- Enquanto o delta ainda não tiver retornado em `XPZ` oficial da KB, o trabalho deve permanecer em `ObjetosGeradosParaImportacaoNaKbNoGenexus`.

Quando o mesmo `XPZ` for reprocessado após atualização do arquivo exportado, tratar o novo resultado como um novo snapshot daquele insumo, não como repetição irrelevante do processamento anterior. A classificação `updated` versus `unchanged` pertence ao resultado daquele processamento específico.

Os nomes das pastas são apenas padrões sugeridos quando o usuário não informar outros. O que manda é a função da pasta no fluxo.

Quando a base compartilhada ganhar um parâmetro operacional relevante, isso
significa apenas que a capacidade existe no motor compartilhado. A exposição em
wrappers locais continua sendo decisão local e pode estar defasada. Nesses
casos, o agente deve reconhecer a defasagem como oportunidade de adaptação
local, propor a mudança ao usuário e aguardar aprovação explícita; não deve
alterar wrappers locais por conta própria.

A superfície do wrapper local também pode ficar temporariamente à frente, atrás
ou levemente desalinhada em relação ao motor compartilhado efetivo daquela pasta
paralela da KB. Quando a falha atingir apenas um parâmetro opcional de
conferência/comparação e o sync principal continuar viável, tratar o caso como
divergência wrapper/engine: rerodar sem o opcional, registrar o incidente no
relato e não classificar isso automaticamente como bloqueio da operação
principal.

Os `.example.ps1` da base metodológica podem servir como referência para
consertar ou reconstruir wrappers locais finais, mas não substituem o wrapper
local real e não devem ser usados como fallback automático de execução no fluxo
normal da pasta paralela da KB.

Se a pasta paralela da KB ainda não estiver montada, validada ou mapeada, parar e usar `xpz-kb-parallel-setup` antes do `sync`.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- Usuário quer processar um `.xpz` exportado da IDE
- Usuário quer atualizar o acervo de XMLs a partir de um XPZ
- Usuário quer conferir se um export full da KB está completo
- Usuário quer rodar o script de sincronização ou de snapshot

Do NOT use this skill para:
- Gerar ou construir pacotes XPZ para importação manual na IDE (use `xpz-builder`)
- Analisar estrutura interna de um XML isolado (use `xpz-reader`)
- Instalar ou gerenciar monitoramento automático de pastas XPZ (use `xpz-daemon`)
- Localizar objetos no acervo da KB por nome ou tipo (usar `xpz-index-triage` quando houver índice KbIntelligence disponível)
- Preparar, explicar ou validar a estrutura inicial da pasta paralela da KB (use `xpz-kb-parallel-setup`)

---

## SCRIPTS ESPERADOS

O repositório deve conter em `<repo_root>\scripts\` dois wrappers:

| Propósito | Quando usar |
|---|---|
| **Atualização diária** — extrai e materializa XMLs no acervo a partir de um XPZ parcial | XPZ do dia a dia exportado pela IDE |
| **Conferência full** — verifica completude do acervo contra um export completo da KB, sem regravar nada | Novo export full da KB |

Os nomes exatos dos wrappers são definidos por cada repositório. Consulte o `README.md` local para identificá-los.

## PASTAS PADRÃO PARA CARGA INICIAL

Quando o usuário não informar nomes alternativos, adotar estas subpastas na raiz da KB:

- `ObjetosDaKbEmXml`: acervo oficial somente leitura para agentes (editar o acervo esperando que o pacote use essa versão é anti-padrão; ver `02-regras-operacionais-e-runtime.md`, anti-padrão "editar acervo esperando que o pacote pegue")
- `XpzExportadosPelaIDE`: entrada dos `.xpz` exportados pela IDE
- `scripts`: wrappers `.ps1` que tratam `XPZ`
- `Temp`: destino de artefatos efêmeros de execução, como diretórios temporários de wrappers, logs auxiliares e saídas intermediárias
- `KbIntelligence`: pasta do índice SQLite derivado e regenerável, quando esse fluxo estiver adotado na KB
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: saída de XMLs temporários para importação manual, organizada por frente em subpastas `NomeCurto_GUID_YYYYMMDD`; essa subpasta é a unidade ativa da frente
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: saída de pacotes `.xml` e, quando necessário, `.xpz`
- após processamento bem-sucedido, o `.xpz` consumido pode ser renomeado para `processado_<nome-original>.xpz`
- por padrão, novos fluxos devem ignorar arquivos com prefixo `processado_`
- se o usuário apontar explicitamente como entrada da rodada um arquivo com prefixo `processado_`, tratar isso como alerta operacional de naming inconsistente, pedir confirmação antes de seguir e deixar o `InputPath` informado prevalecer se o usuário confirmar
- se alguma subpasta ainda não existir, criar nesta ordem:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- se `XpzExportadosPelaIDE` ainda não existir, perguntar onde o usuário quer salvar os `.xpz`
- se `ObjetosDaKbEmXml` ainda não existir, parar e tratar a KB como ainda não materializada

---

## MAPEAMENTO INTENÇÃO -> FUNÇÃO DA PASTA

- Se a intenção for materializar `XPZ` exportado pela IDE para consulta futura do agente:
  - usar a pasta com função de acervo materializado da KB
  - essa pasta recebe XMLs individuais por objeto após a quebra do `full.xml`
- Se a intenção for atualizar acervo materializado com `XPZ` parcial:
  - usar a mesma pasta com função de acervo materializado da KB
  - nunca usar a pasta de geração para importação como destino dessa materialização
- Se a intenção for gerar XML novo ou cópia alterada para importar na IDE:
  - usar a pasta com função de geração para importação
  - essa pasta recebe apenas XMLs novos ou cópias alteradas geradas pelo agente
  - cada frente deve usar sua própria subpasta `NomeCurto_GUID_YYYYMMDD`
- Se a intenção for guardar `XPZ` exportado pela IDE:
  - usar a pasta com função de entrada de `XPZ`
  - essa pasta não é acervo materializado nem área de geração de XML

---

## REGRAS DE NAMING

- Ao materializar acervo vindo de `XPZ`, organizar os arquivos em subpastas por tipo amigável de objeto GeneXus
- Ao materializar acervo vindo de `XPZ`, usar nomes amigáveis dos objetos como nome principal dos XMLs
- Não usar GUID como nome principal de pasta ou arquivo da materialização
- GUID, `parentGuid`, `parentType` e `moduleGuid` servem como metadados de apoio, não como eixo principal de organização

---

## EXPORTS LEGADOS (KB ANTIGA)

- `Evidência direta`: versões antigas do GeneXus (ex.: GX9) podem exportar `ExportFile` com `GXObject`/`GXAtt` em vez de `Objects/Object` e `Attributes/Attribute`.
- O motor `Sync-GeneXusXpzToXml.ps1` detecta esse perfil e delega a `scripts/GeneXusLegacyExportFileSupport.ps1`.
- Interpretações de sucesso: `legacy-export-adapted` (itens materializados) — distinto de `no-exportable-items` (pacote moderno vazio) e de erro de leitura.
- Cada XML gravado usa envelope moderno (`Object`/`Attribute` + `lastUpdate`) com `dataSource="gx-legacy-export"` e payload original em `GxLegacyPayload`.
- O acervo legado materializado não carrega `guid` de identidade estável; em `-FullSnapshot`, esses itens não participam da reconciliação por GUID (`RenamedByGuid`/`RenameResidualsDetected`). Renames futuros desse material legado devem ser tratados por nome/contexto humano, não como rename GUID-aware.
- Mapeamento de elementos legados → tipo canônico: `scripts/gx-legacy-export-element-map.json`; tipos sem entrada geram warning consultivo, não bloqueio automático do sync.
- `Get-GeneXusImportPackageObjectInventory.ps1` inventaria o mesmo perfil (`legacyFormatDetected=true`).
- `KbIntelligence`: inventário e gate estrutural costumam funcionar; `who-uses`, `impact-basic` e trilhas semânticas sobre o payload interno permanecem limitadas até extrator dedicado.
- Não confundir com conversão MSBuild `ConvertXpz` (GeneXus 18+): adaptação aqui é para pasta paralela e triagem, não round-trip importável sem revisão humana.
- Quando houver GeneXus moderno disponível, export atualizado pela IDE continua sendo o caminho preferencial.

---

## LOCALIZAÇÃO DO REPOSITÓRIO

1. Usar o diretório de trabalho atual como ponto de partida
2. Se necessário, subir até encontrar a raiz Git (`git rev-parse --show-toplevel`)
3. Listar `scripts\` e identificar os dois wrappers pelo `README.md` local
4. Se não encontrados, perguntar ao usuário onde fica a raiz do repositório antes de prosseguir

---

## PARÂMETROS COMUNS

Os wrappers seguem esta convenção de parâmetros:

### Wrapper de atualização diária
- `-InputPath` *(obrigatório)* — caminho para `.xpz`, XML ou pasta contendo o XML
- `-VerifyOnly` *(switch)* — só confere, não regrava
- `-FullSnapshot` *(switch)* — compara snapshot completo do acervo
- sob `-FullSnapshot`, o motor reconcilia o acervo pela identidade estável do nó raiz (`guid`), não só pelo nome lógico: quando o mesmo `guid` aparece no acervo sob nome de arquivo diferente, trata como **rename** e renomeia o arquivo existente (`Move-Item` antigo → novo) em vez de criar-novo + abandonar-antigo; o resultado é um arquivo só (nome novo) e o git detecta rename por similaridade. Cobre `Attribute` e `Object`. Em `-VerifyOnly`, o motor apenas **classifica** o resíduo de rename no relatório (`RenameResidualsDetected`), sem tocar o disco
- `XPZ` full define apenas o insumo; não define, por si só, o modo de verificação
- para materialização normal, inclusive carga inicial por `XPZ` full vindo da IDE ou por export headless via `MSBuild`, não presumir `-FullSnapshot` como padrão implícito nem como atalho ergonômico
- usar `-FullSnapshot` somente em um destes casos: pedido explícito do usuário por conferência full, uso do wrapper específico de conferência full, ou exigência nominal da documentação local do repositório
- `-ReportPath` *(opcional)* — salva relatório JSON
- `-KeepReport` *(switch)* — mantém relatório mesmo sem erro
- quando houver primeira materialização seguida de reprocessamento confirmatório ou conferência full, não sobrescrever silenciosamente o relatório principal da primeira materialização com o relatório da segunda passagem
- nesses casos, usar caminhos separados para cada relatório ou deixar explícito no handoff qual arquivo corresponde a `materializacao` e qual corresponde a `confirmacao`/`conferencia`
- `-ExpectedItems` *(opcional)* — lista de itens esperados da frente atual no formato `Tipo:Nome`, usada apenas para classificação comparativa entre foco esperado e retorno oficial da KB
- o motor compartilhado aceita `-ExpectedItems` como lista normal de PowerShell
  ou como string única separada por vírgula, ponto e vírgula ou quebra de linha;
  ao invocar via `pwsh -File` a partir de Bash/CMD, preferir a string única
  separada por vírgula para evitar ambiguidade de parser entre shells
- a disponibilidade desse parâmetro no motor compartilhado não autoriza presumir
  que wrappers locais da pasta paralela da KB já o exponham; se o wrapper local
  ainda não o aceitar, tratar isso como oportunidade de atualização local,
  mencionar ao usuário e aguardar aprovação explícita antes de qualquer ajuste
- se o wrapper local aceitar `-ExpectedItems`, mas a execução falhar no motor
  compartilhado efetivo por incompatibilidade restrita a esse opcional
  comparativo, tratar como divergência wrapper/engine e não como bloqueio
  automático do sync principal
- quando a falha ficar restrita a esse opcional, rerodar sem `-ExpectedItems`,
  concluir a materialização se o restante do fluxo estiver são e registrar no
  handoff que a comparação esperada x retorno oficial ficou indisponível naquela
  rodada por incompatibilidade do engine
- se a falha atribuída a `-ExpectedItems` revelar quebra da materialização,
  contrato principal do wrapper, refresh obrigatório do índice ou outro impacto
  central no fluxo oficial, continuar tratando o caso como bloqueio real
- `-KbMetadataPath` *(opcional)* — salva metadados da KB em formato Markdown
- `-ParallelKbRoot` *(opcional)* — raiz da pasta paralela; resolve `scripts/gx-object-type-catalog.override.json`
- `-CatalogOverridePath` / `-DiscoveryReportPath` *(opcionais)* — override local e relatório JSON quando o pacote tiver GUID não mapeado
- se esse parâmetro estiver ativo no wrapper local, `kb-source-metadata.md` faz parte normal do fluxo; o motor `scripts/Sync-GeneXusXpzToXml.ps1` (via `scripts/XpzKbSourceMetadataEditSupport.ps1`) atualiza **cirurgicamente** somente campos de materialização (`updated`, `last_xpz_materialization_run_at`, `source_xpz`, `source_refresh_status` e tabelas `KMW`/`Source`/`Source/Version`), preservando `last_setup_audit_run_at`, `setup_contract_signature_*`, demais frontmatter e seções fora do escopo, com EOL dominante via `scripts/XpzTextFileEolSupport.ps1`
- quando `kb-source-metadata.md` for atualizado pelo sync, ele deve registrar `last_xpz_materialization_run_at` como horário do processamento XPZ/XML solicitado, mesmo quando nenhum XML tiver mudança material
- se o `XPZ` vier com `Source` vazio, incompleto ou ausente, o wrapper deve preservar valores estáveis conhecidos e emitir warning de refresh parcial; isso não invalida o sync de objetos
- depois de materialização XPZ/XML bem-sucedida em `ObjetosDaKbEmXml`, o wrapper local deve acionar compulsoriamente a regeneração/validação do índice derivado por wrapper local de `KbIntelligence`
- rebuild do índice via `scripts/Build-KbIntelligenceIndex.ps1` exige **Python 3.x utilizável** no `PATH` (`scripts/GeneXusPythonPrerequisite.ps1`; stub da Microsoft Store em `WindowsApps` não conta). Ausência bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE` — **rigor**: sync normal **não** terminou; a materialização XPZ/XML pode já ter concluído, mas isso **não** equivale a sucesso do fluxo oficial nem autoriza triagem ampla sem índice. Não tratar como falha do pacote exportado; instalar Python 3.x e rerodar o rebuild (`Rebuild-*KbIntelligenceIndex.ps1`). Ver `README.md`, `02-regras-operacionais-e-runtime.md` e molde `Update-KbFromXpz.example.ps1`
- evidência clara desse encadeamento significa declaração local explícita no `README.md`/`AGENTS.md` ou chamada observável no próprio wrapper local; não presumir essa capacidade apenas porque a base compartilhada a exige
- se o wrapper local de regeneração do índice estiver ausente ou defasado, ou se o wrapper de materialização não encadear esse refresh, tratar como bloqueio operacional do sync normal e oferecer ao usuário atualização via `xpz-kb-parallel-setup` antes de seguir
- não apresentar `sync` seguido de regeneração manual separada do índice como fluxo normal em pasta que adota `KbIntelligence`
- `-NoGitSummary` *(switch)* — suprime resumo Git no final

### Wrapper de conferência full
- `-InputPath` *(obrigatório)* — caminho para `.xpz`, XML ou pasta
- `-ReportPath` *(opcional)* — salva relatório JSON
- `-KeepReport` *(switch)* — mantém relatório mesmo sem erro

---

## WORKFLOW

1. Identificar se é atualização diária ou conferência de full snapshot
2. Se a pasta paralela da KB ainda não estiver montada, validada ou mapeada para este repositório → **ABORT** e usar `xpz-kb-parallel-setup`
3. Resolver a raiz do repositório pelo contexto
4. Ler o `README.md` local para identificar os nomes dos wrappers
5. Distinguir explicitamente as áreas operacionais locais:
   - `ObjetosDaKbEmXml` = snapshot oficial da KB, materializado em XMLs individuais por objeto e atualizado apenas pelo fluxo oficial do script
   - `XpzExportadosPelaIDE` = entrada dos `.xpz` exportados pela IDE
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = área de trabalho para XML local de importação manual, organizada por frente em subpastas `NomeCurto_GUID_YYYYMMDD`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus` = área de pacotes gerados localmente, mantida plana sem subpastas por frente
   - `scripts` = wrappers `.ps1` que tratam os `XPZ`
   - se o objeto ainda não voltou da KB por export oficial, o trabalho deve permanecer em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
6. Se o usuário informou nomes alternativos para as pastas, reportar na conversa o mapeamento entre nome real e função
   - documentar isso em arquivo somente quando a documentação local exigir ou quando o usuário pedir
7. Se detectar alterações locais indevidas em `ObjetosDaKbEmXml`, reportar isso como incidente de processo:
   - Preservar o material de trabalho em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
   - Restaurar `ObjetosDaKbEmXml` para a versão oficial do Git
   - Apresentar na conversa um manifesto estruturado dos itens preservados antes de retomar o fluxo normal
   - Salvar esse manifesto em arquivo apenas quando a rastreabilidade local do incidente exigir isso
   - Abortar imediatamente o fluxo normal até a restauração do snapshot oficial e a abertura do incidente de processo
   - Não tratar esse caso como detalhe operacional; ele bloqueia o fluxo até saneamento explícito do snapshot oficial
   - Se o usuário estiver em frente de delta ainda não reexportado pela KB, orientar explicitamente que o trabalho continue em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, não no acervo oficial
7b. **Lembrete de override de catálogo (cada sessão):** se a pasta paralela tiver `scripts/gx-object-type-catalog.override.json`, executar `Test-XpzCatalogOverrideSessionReminder.ps1 -ParallelKbRoot <raiz> -AsJson` e repetir ao usuário a mensagem quando `reminderRequired=true` (falta alinhar GeneXus-XPZ-Skills).
7c. **Pré-varredura antes de materialização longa:** para `XPZ` full ou primeira carga, rodar `Get-GeneXusImportPackageObjectInventory.ps1` com `-FailOnUnknownTypes` e `-ParallelKbRoot` (a saída de máquina é JSON por padrão no stdout, sem `-AsJson`). Se bloquear (`exit 3` / `UNKNOWN_TYPES_BLOCKED`), não chamar sync até resolver o tipo.
7d. **Tipo desconhecido detectado:** seguir `02` / `08` (seção tipo desconhecido): parar; perguntar se o usuário autoriza consulta **recomendável** a `nexa` + wiki oficial; oferecer registro local com `-UserApproved` (`Register-GeneXusObjectTypeCatalogOverride.ps1`) e prompt ao mantenedor (`New-GeneXusUnknownTypeMaintainerPrompt.ps1`). Usar `-DiscoveryReportPath` no sync para JSON de triagem em `Temp`.
8. Confirmar o `InputPath` com o usuário se não foi fornecido
9. Quando o fluxo envolver materialização de `XPZ` completo:
   - quebrar o `full.xml` em XMLs individuais por objeto
   - gravar a saída na pasta com função de acervo materializado
   - organizar por tipo amigável de objeto GeneXus
   - usar nomes amigáveis de objeto como nome principal dos XMLs
10. Quando o fluxo envolver `XPZ` parcial:
    - atualizar a mesma pasta com função de acervo materializado
    - não desviar a materialização para a pasta de geração para importação
    - se o mesmo arquivo `XPZ` for reexportado/atualizado e reprocessado, tratar o novo processamento pelo conteúdo e pelo `lastUpdate` resultante, não pela memória do processamento anterior
    - se houver `-ExpectedItems`, usar esse contexto apenas para comparar foco esperado versus retorno oficial; a materialização continua seguindo tudo que a KB devolveu oficialmente
11. Se a pasta adota `KbIntelligence`, validar que o wrapper local de materialização encadeia refresh compulsório do índice após sync bem-sucedido que não seja `VerifyOnly`
    - considerar evidência clara apenas quando isso estiver documentado explicitamente no repositório local ou observável no código do próprio wrapper local
    - se o wrapper não tiver essa capacidade, bloquear o sync normal antes de executar e oferecer atualização via `xpz-kb-parallel-setup`
    - não executar sync normal esperando corrigir o índice manualmente depois
    - não usar o wrapper antigo para atualizar `kb-source-metadata.md` e depois regenerar o índice manualmente como substituto da correção de compatibilidade
    - não usar `.example.ps1` da base compartilhada como substituto temporário do wrapper local real ausente
12. Montar o comando com os parâmetros corretos
    - para materialização normal do `XPZ` em `ObjetosDaKbEmXml`, não acrescentar `-FullSnapshot` por conta própria
    - não reinterpretar `XPZ` full como autorização implícita para `-FullSnapshot`; export full e conferência full são coisas diferentes
    - usar `-FullSnapshot` apenas quando o usuário pedir conferência full, quando o wrapper específico de conferência for o escolhido ou quando a documentação local tornar isso requisito explícito
    - tratar nome iniciado por `processado_` como heurística forte de artefato já consumido, não como verdade absoluta sobre o conteúdo do arquivo
    - se o `InputPath` explicitamente informado pelo usuário apontar para arquivo com prefixo `processado_`, emitir alerta curto, pedir confirmação e prosseguir somente se o usuário confirmar esse arquivo como insumo correto da rodada atual
    - se houver opcional comparativo como `-ExpectedItems`, lembrar que a
      exposição no wrapper local não prova compatibilidade integral do motor
      compartilhado efetivo; se a primeira execução falhar apenas nesse ponto,
      preparar rerun sem o opcional antes de concluir bloqueio do sync
13. Executar via Bash com `pwsh -File ...`
    - se a execução falhar com indício claro de divergência wrapper/engine
      restrita a opcional de comparação, rerodar uma vez sem o parâmetro
      opcional antes de classificar o caso como bloqueio
    - se o rerun sem opcional concluir a materialização e os gates obrigatórios,
      registrar sucesso do sync principal com incidente em capability opcional
    - se o rerun sem opcional repetir falha central ou expuser problema fora do
      escopo comparativo, tratar como bloqueio real do sync
14. Se a materialização XPZ/XML em `ObjetosDaKbEmXml` foi concluída com sucesso e não era `VerifyOnly`, confirmar na saída do wrapper ou em evidência local clara que o refresh compulsório do índice derivado também foi executado
    - se o rebuild falhar com `PREREQUISITO AUSENTE` / exit `8` do motor Python, declarar **fluxo incompleto** (XMLs possivelmente atualizados, índice pendente); não fechar como sync OK nem como defeito do XPZ
    - em pasta que adota `KbIntelligence`, ausência de evidência do refresh deve ser tratada como falha ou defasagem operacional do wrapper local
    - não compensar essa ausência com rebuild manual separado do índice como se fosse fluxo normal
    - se o wrapper não produzir evidência suficiente do refresh, encerrar com bloqueio de compatibilidade e oferecer atualização via `xpz-kb-parallel-setup`
15. Se o processamento foi concluído com sucesso, permitir renomear o `.xpz` consumido para `processado_<nome-original>.xpz`
16. Reportar: objetos criados, atualizados, ignorados, resíduos removidos, refresh do índice e resumo Git
    - se o resumo do wrapper expuser `MaterializationInterpretation`, usar esse campo como leitura principal do resultado em vez de inferir pela combinação solta de `Created`, `Updated` e `Unchanged`
    - quando o sync em `-FullSnapshot` reconciliar rename por `guid`, reportar `RenamedByGuid` (arquivos renomeados no acervo ou órfãos de mesmo `guid` removidos); em `-VerifyOnly`, reportar `RenameResidualsDetected` (renames detectados sem mover); esses números explicam por que um nome antigo deixou de existir no acervo e devem ser lidos como rename reconhecido, não como deleção cega
    - o resultado do wrapper/motor é uma **única linha JSON de máquina no stdout** (`Kind = "xpz-sync-result"`, `SchemaVersion = 1`, serializada com `-Compress`); todo texto humano (resumo de contadores, resumo Git, avisos) sai no **stderr**, nunca no stdout. Consumir o resultado como objeto (`ConvertFrom-Json`), não parsear o texto humano. Atenção: em processo filho (`pwsh -File`), `Write-Host`/`Write-Warning`/`Write-Information` vazam para o stdout capturado — por isso o contrato exige stderr para diagnóstico
    - o motor expõe **listas nominais prontas**, eliminando a necessidade de `git diff` para nomear os objetos: `CreatedNames`, `UpdatedNames`, `UnchangedNames`, `SkippedOlderLastUpdateNames` (formato `"Tipo:Nome"`) e `RenamedByGuidItems` (`{Guid, FolderType, OldName, NewName, Action}`). Cada lista é consistente com o contador homônimo (`len(UpdatedNames) == Updated`, etc.). Em `-VerifyOnly` as listas de writes vêm vazias por construção (não por ausência de dado); `NormalizedFileNames` permanece só como contador (é nome de arquivo, não nome lógico)
    - ao apresentar as listas nominais ao usuário, aplicar a regra de tamanho **por categoria**: até 10 itens, listar os nomes; acima de 10, mostrar o contador + amostra curta (primeiros 3 + "… e mais N") e **oferecer** imprimir a lista completa no chat (o resultado JSON já está em mãos — não precisa de arquivo nem de `git diff`)
    - explicar que `updated` significa que o wrapper materializou conteúdo mais novo/relevante para o acervo naquele processamento
    - explicar que `unchanged` significa que o item já tinha no acervo oficial conteúdo compatível ou mais novo, tipicamente com `lastUpdate` igual ou superior ao XML vindo do `XPZ`
    - explicar que `updated`/`unchanged` pertencem ao processamento do `XPZ` contra o arquivo materializado atual, não ao estado Git do repositório
    - nunca afirmar `primeira carga` ou equivalente quando `Created = 0` e `Unchanged > 0`; essa combinação, sozinha, não comprova primeira materialização e normalmente indica snapshot já existente confirmado contra o insumo atual
    - explicar que um item pode aparecer como `unchanged` no sync porque o arquivo local já está igual ao conteúdo vindo do `XPZ`, mesmo que esse mesmo arquivo ainda tenha diff pendente no Git contra o último commit
    - quando houver resumo Git, apresentar essa camada separadamente como comparação do worktree contra o commit atual, sem reclassificar o resultado do sync
    - se o mesmo `XPZ` tiver sido reprocessado após atualização do arquivo, deixar explícito que a comparação relevante é com o conteúdo do insumo reprocessado e com o estado atual do acervo, não com o relatório antigo
    - se `kb-source-metadata.md` tiver sido atualizado cirurgicamente pelo wrapper (campos de materialização), tratar isso como artefato normal do fluxo, não como evidência automática de mudança funcional na frente
    - se a pasta ainda carregar memória local provisória do setup dizendo que `ObjetosDaKbEmXml` não foi materializada, `aguardando primeiro XPZ` ou equivalente, atualizar ou neutralizar esse estado quando a primeira materialização oficial tiver sido concluída com sucesso
    - só afirmar conteúdo específico de `kb-source-metadata.md`, como versão do GeneXus, build, GUID da KB, usuário ou caminho `Source`, quando esse metadado tiver aparecido explicitamente na saída real do wrapper ou quando o próprio `kb-source-metadata.md` tiver sido aberto e lido nominalmente na rodada atual
    - quando nenhuma dessas duas fontes aceitáveis tiver mostrado o metadado, limitar o resumo ao que o wrapper efetivamente retornou
    - se o pacote tiver `Source` parcial, separar claramente `sync de objetos aceito` de `refresh de metadado parcial` e preservar os valores estáveis já conhecidos
    - se houver relatório da primeira materialização e outro de reprocessamento confirmatório ou conferência full, não misturar os papéis no handoff; identificar explicitamente qual arquivo representa a criação/atualização do acervo e qual arquivo representa apenas verificação posterior
    - se o `XPZ` oficial da KB trouxer objetos adicionais fora do foco imediato da frente, reportar isso como inesperado para a frente atual, mas tratar como possível mudança paralela legítima vinda da IDE/KB até evidência em contrário
    - quando o resumo Git ou `git diff --check` apontar whitespace em `ObjetosDaKbEmXml`, distinguir whitespace herdado literalmente do export oficial da IDE de whitespace introduzido antes pelo agente em XML/pacote local; o sync não deve reformatar automaticamente o snapshot oficial só para limpar ruído histórico
    - quando o contexto da conversa identificar uma frente ativa com objetos-foco conhecidos (usuário declarou quais objetos está trabalhando ou o contexto da frente é claro), perguntar ou confirmar os objetos esperados antes de executar o sync quando essa informação ainda não tiver sido declarada na conversa; após o sync, estruturar sempre o handoff com as três partes, independentemente de `-ExpectedItems` estar disponível no wrapper: `objetos-foco que voltaram`, `objetos-foco que não voltaram` e `retorno oficial adicional da KB`
    - se `-ExpectedItems` tiver sido informado, classificar explicitamente `itens esperados que voltaram`, `itens esperados que não voltaram` e `retorno oficial adicional da KB`
    - quando `-ExpectedItems` foi informado, as listas `ExpectedReturnedNames`, `ExpectedMissingNames` e `AdditionalOfficialNames` (listas `"Tipo:Nome"` achatadas no resultado JSON) são a **fonte nominal direta** das três partes — respectivamente `objetos-foco que voltaram`, `não voltaram` e `retorno oficial adicional`. As listas por status (`CreatedNames`/`UpdatedNames`/...) são eixo **ortogonal**: dizem o que foi escrito no acervo, não o que era esperado pela frente; sem `-ExpectedItems`, as três partes vêm do julgamento do agente sobre os objetos-foco, não de `*Names`
    - se `-ExpectedItems` tiver sido informado, emitir também um resumo humano curto no console/handoff, sem alarmismo e sem tratar adicionais oficiais ou esperados ausentes como falha automática
    - se a rodada tiver precisado rerun sem `-ExpectedItems` por divergência
      wrapper/engine, separar explicitamente `sync principal concluído` de
      `comparação opcional indisponível nesta rodada`
17. Quando um objeto voltar da KB via `xpz` e for materializado no acervo oficial, tratar esse XML do acervo como a fonte mais confiável para alterações futuras; não reutilizar cópia intermediária/delta sem comparar com o acervo atualizado
18. Ao preparar commit ou handoff após o `sync`, separar explicitamente:
    - artefato da frente atual = resultado que o processamento atual confirmou como pertencente à frente em curso
    - mudança paralela legítima vinda da KB/IDE = item devolvido oficialmente pela KB no `XPZ`, ainda que fora do foco imediato da frente
    - mudança lateral indevida = alteração feita pelo agente fora do escopo da fase ou fora do fluxo oficial esperado
    - não agrupar no mesmo commit da frente atual mudanças paralelas sem decisão explícita, mas não tratar automaticamente o retorno oficial adicional da KB como erro
19. O handoff técnico mínimo deve declarar:
    - comando/wrapper executado e `InputPath` usado
    - se a rodada foi materialização normal, reprocessamento confirmatório ou conferência full
    - relatório principal usado para a conclusão e, quando houver, relatório separado de verificação posterior
    - `MaterializationInterpretation` quando o wrapper expuser esse campo; caso contrário, limitar a leitura aos contadores e warnings reais
    - evidência usada para afirmar refresh do índice ou bloqueio que impediu essa conclusão
    - se `kb-source-metadata.md` foi lido nominalmente na rodada atual ou apenas atualizado cirurgicamente pelo wrapper (campos de materialização)
    - se houve falha de opcional comparativo por divergência wrapper/engine,
      declarar o parâmetro afetado, o rerun sem ele e que isso não bloqueou o
      sync principal
    - quando o contexto identificar uma frente ativa, declarar explicitamente: `objetos-foco que voltaram`, `objetos-foco que não voltaram` e `retorno oficial adicional da KB` — mesmo quando `-ExpectedItems` não foi passado ou não está disponível no wrapper
20. O resumo Git do item anterior é apenas informativo; não autoriza `git add`, `commit` ou `push`
21. Se o usuário não pedir fechamento Git de forma explícita, o fluxo deve terminar no handoff técnico e, no máximo, sugerir próximos passos sem executar publicação

---

## EXEMPLO CURTO DE ESTRUTURA MATERIALIZADA ESPERADA

```text
PastaParalelaDaKb/
  XpzExportadosPelaIDE/
    KBCompleta_20260413.xpz
    processado_AjustesFinanceiro_20260413.xpz
  ObjetosDaKbEmXml/
    Transaction/
      Cliente.xml
      Pedido.xml
    Procedure/
      GeraBoleto.xml
    WebPanel/
      WPClienteConsulta.xml
  ObjetosGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414/
      ClienteNovo.xml
      PedidoAjustado.xml
  PacotesGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414_01.import_file.xml
  scripts/
    Sync-GeneXusXpzToXml.ps1
  kb-source-metadata.md
```

O arquivo `kb-source-metadata.md`, quando exposto pelo wrapper local via
`-KbMetadataPath`, é artefato normal de processamento e recebe atualizacao
cirurgica em cada sync (não regeneracao total do arquivo). O motor preserva
`last_setup_audit_run_at` (autoridade de `xpz-kb-parallel-setup`), demais
frontmatter fora do escopo do sync e seções extras; atualiza valores estaveis de
`Source`/`KMW` quando o `XPZ` atual vier com metadados vazios ou parciais.

Esse arquivo também é o local esperado de `last_xpz_materialization_run_at`
(autoridade desta skill).
Esse horário representa a última solicitação/processamento de materialização
XPZ/XML, não apenas a última mudança material detectada nos XMLs.

---

## CONSTRAINTS

- NUNCA editar XMLs manualmente — todo o trabalho é delegado ao script
- NUNCA assumir caminhos absolutos privados — sempre derivar da raiz do repositório
- NUNCA assumir os nomes dos wrappers sem consultar o `README.md` local
- NUNCA executar `sync` normal enquanto a pasta paralela da KB ainda estiver indefinida, não montada ou não validada
- NUNCA mover arquivos entre pastas de trabalho e acervo — responsabilidade do fluxo oficial
- NUNCA criar ou mover automaticamente `.xpz` para dentro de `XpzExportadosPelaIDE` como se essa pasta fosse saída do agente; ela é a entrada gravada pelo usuário/IDE
- NUNCA renomear o `.xpz` para `processado_<nome-original>.xpz` antes de sucesso claro no processamento
- NUNCA selecionar por padrão um arquivo já marcado com prefixo `processado_`
- NUNCA tratar XML local gerado para importação manual como se já fosse snapshot oficial da KB
- NUNCA materializar `XPZ` completo ou parcial na pasta de geração para importação
- NUNCA tratar XML local de referência, exemplo, template ou molde em `ObjetosGeradosParaImportacaoNaKbNoGenexus` como snapshot oficial ou como lote ativo de importação
- NUNCA usar GUID como estrutura principal de saída da materialização
- NUNCA organizar o acervo materializado com `guid`, `parentGuid`, `parentType` ou `moduleGuid` como eixo principal de navegação
- NUNCA criar, alterar, mover, renomear ou sobrescrever arquivos em `ObjetosDaKbEmXml` fora do fluxo oficial do script `.ps1`
- NUNCA encerrar sync XPZ/XML bem-sucedido sem refresh compulsório do índice derivado quando a KB adotar `KbIntelligence`
- NUNCA executar sync normal em pasta que adota `KbIntelligence` se o wrapper local de materialização ainda não encadeia refresh compulsório do índice; oferecer atualização via `xpz-kb-parallel-setup`
- NUNCA descrever `sync` seguido de rebuild manual separado do índice como fluxo normal em pasta que adota `KbIntelligence`
- NUNCA usar sync por wrapper antigo para reparar metadado de materialização quando o próprio wrapper está defasado; primeiro atualizar/validar wrappers pela trilha de setup
- NUNCA selecionar automaticamente por padrão um arquivo com prefixo `processado_` quando houver outros candidatos plausíveis para a rodada atual
- NUNCA tratar prefixo `processado_` como bloqueio absoluto quando o usuário tiver apontado explicitamente o `InputPath`; primeiro emitir alerta operacional e exigir confirmação explícita
- NUNCA antecipar atualização manual de `ObjetosDaKbEmXml`
- NUNCA prosseguir com sync normal quando `ObjetosDaKbEmXml` estiver dirty fora do fluxo oficial; primeiro preserve, restaure e trate como incidente de processo
- NUNCA tratar edição detectada ou pretendida em `ObjetosDaKbEmXml` para delta ainda não reexportado oficialmente pela KB como detalhe operacional; isso é erro explícito de processo
- NUNCA assumir a raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus` como lote ativo de importação; o lote ativo deve viver na subpasta da frente `NomeCurto_GUID_YYYYMMDD`
- NUNCA criar subpastas por frente dentro de `PacotesGeradosParaImportacaoNaKbNoGenexus`; essa area de pacotes deve permanecer plana
- NUNCA reutilizar automaticamente artefato de importação/delta como base de nova alteração se o mesmo objeto já tiver voltado da KB e sido materializado no acervo oficial
- NUNCA criar script novo se o repositório já tiver fluxo oficial previsto nas skills ou em `scripts/`
- Antes de gerar novo delta de objeto já retornado da KB, comparar a cópia intermediária com o XML atual do acervo e rebasear no acervo se houver defasagem
- Se o script não for encontrado na raiz resolvida, reportar o erro e perguntar ao usuário antes de tentar qualquer alternativa
- NUNCA tratar reprocessamento do mesmo `XPZ` atualizado como se o resultado anterior ainda fosse autoritativo
- NUNCA tratar atualização cirúrgica de `kb-source-metadata.md` pelo wrapper (campos de materialização) como mudança funcional automática da frente atual
- NUNCA deixar `kb-source-metadata.md` perder valores estáveis conhecidos porque o `XPZ` veio com `Source` vazio ou incompleto
- NUNCA apagar ou sobrescrever `last_setup_audit_run_at` nem outros campos de frontmatter fora da autoridade do sync; a gravacao desse campo pertence a `xpz-kb-parallel-setup` (`Set-*KbSetupAuditTimestamp.ps1` / `scripts/Set-XpzSetupAuditTimestamp.ps1`)
- NUNCA reformatar ou normalizar `ObjetosDaKbEmXml` durante sync para remover whitespace herdado de export oficial; se o ruído tiver sido introduzido por XML/pacote local gerado pelo agente, a correção deve acontecer na etapa de geração em `ObjetosGeradosParaImportacaoNaKbNoGenexus` antes da importação, não como limpeza posterior do snapshot oficial
- NUNCA classificar automaticamente como erro de processo, contaminação indevida ou violação da trilha o simples fato de um `XPZ` oficial vindo da KB trazer objetos adicionais além do foco da frente
- NUNCA materializar `XPZ` com tipo desconhecido no catálogo efetivo (compartilhado + override aprovado)
- NUNCA registrar override local ou consultar `nexa`/wiki sem consentimento explícito do usuário
- NUNCA omitir lembrete de override pendente upstream quando `Test-XpzCatalogOverrideSessionReminder.ps1` exigir
- NUNCA editar `GeneXus-XPZ-Skills` a partir da pasta paralela para “fechar” tipo novo sem troca de contexto
- NUNCA misturar no mesmo commit da frente atual mudanças paralelas sem decisão explícita só porque aparecem no mesmo workspace
- NUNCA omitir a estrutura de três partes (`objetos-foco que voltaram`, `objetos-foco que não voltaram`, `retorno oficial adicional da KB`) no handoff quando o contexto da conversa identificar uma frente ativa com objetos-foco conhecidos — isso é obrigatório independentemente de `-ExpectedItems` estar disponível no wrapper
