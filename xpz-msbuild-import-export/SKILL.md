---
name: xpz-msbuild-import-export
description: Skill para importação e exportação de XPZ via MSBuild, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates (pontos de liberação ou bloqueio) de segurança
---

# xpz-msbuild-import-export

Skill para operações de importação e exportação de `XPZ` do GeneXus por `MSBuild`, em execução sem interface gráfica.

Esta skill não substitui o fluxo oficial atual da trilha paralela da KB, não depende de `GeneXus Server` e não trata sucesso operacional como evidência suficiente de sucesso funcional.

No estado atual, o mecanismo central desta skill já foi validado operacionalmente em múltiplas KBs. O próximo passo desta frente não é mais provar exportação, `PreviewMode` e importação real como capacidade basal, e sim deixar explícitos:

- o que conta como prontidão operacional estável
- quais limites conhecidos ainda exigem uso controlado
- como classificar exceções sem confundi-las com defeito central do wrapper

Exceções já mapeadas que a skill deve tratar explicitamente:

- conteúdo inconsistente da KB/`XPZ`, como `KB_Teste_A`
- validação funcional incompleta por `GeneXus Server` ou licença, como `KB_Teste_E`
- execução longa em KB grande, como `KB_Teste_Grande_A`
- warning estrutural por extensão ausente, como `WebPanelDesigner`/`K2B Object Designer`

Critério atual de prontidão operacional desta skill:

- probe (sondagem técnica inicial), abertura headless, exportação, `PreviewMode` e importação real já validados em KBs de teste controladas
- classificação explícita entre sucesso operacional, validação funcional incompleta e problema de conteúdo da KB/`XPZ`
- logs, artefatos e parâmetros sensíveis rastreáveis
- limites conhecidos já documentados e não tratados como surpresa operacional

Uso mais amplo desta skill ainda depende de:

- critério estável para KBs com dependência externa, licença ou extensão ausente
- interpretação madura de execução longa em KB grande
- confiança suficiente para uso fora de ambiente de experimento controlado

---

## GUIDELINE

Orquestre operações de `XPZ` via `MSBuild` com parâmetros explícitos, coleta rastreável de evidências e aborto seguro antes de operações sensíveis. Priorize descoberta de ambiente, `PreviewMode`, `UpdateFile` quando suportado pela task carregada, `IncludeItems`/`ExcludeItems` para recortes controlados e validação posterior. Nunca trate importação real como padrão.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Se a skill estiver publicada por symlink, junction ou outro reparse point, resolva primeiro a pasta real da skill e só então interprete referências relativas como `../arquivo.md`.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- planejar ou executar validação de ambiente para GeneXus via `MSBuild`
- abrir a `Knowledge Base` por `OpenKnowledgeBase`
- confirmar versão ativa e `Environment` ativo
- executar preview de importação com `PreviewMode`
- gerar `UpdateFile`, quando suportado pela task carregada, para análise prévia de impacto
- exportar `XPZ` com parâmetros explícitos
- importar `XPZ` apenas em fase explicitamente autorizada de teste controlado
- classificar resultado em sucesso operacional versus confirmação funcional pendente

Do NOT use esta skill para:
- substituir o fluxo oficial atual da trilha paralela da KB
- cenários que dependam de `GeneXus Server` como requisito operacional
- KB de produção ou homologação compartilhada sem janela clara para experimento
- inferir silenciosamente `KbPath`, versão, `Environment` ou parâmetros sensíveis
- afirmar sucesso funcional apenas porque a chamada via `MSBuild` terminou sem erro

---

## RESPONSIBILITIES

- Usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como base principal desta frente
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`, `LogPath` e `Genexus.Tasks.targets`
- Tratar `Test-GeneXusMsBuildSetup.ps1` como probe (sondagem técnica inicial) não invasivo, anterior a qualquer abertura de KB
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de `C:\Program Files (x86)`
- Permitir auto-criação apenas do `WorkingDirectory` explicitamente informado, depois de validado como seguro e fora das áreas proibidas
- Preferir `Temp` como destino de artefatos efêmeros de execução e manter `scripts` como pasta de wrappers permanentes
- Distinguir claramente:
  - sucesso operacional da chamada
  - efeito funcional observado depois no GeneXus
- Exigir que o probe (sondagem técnica inicial) devolva diagnóstico estruturado com `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`
- Preferir `JSON` como formato canônico inicial desse diagnóstico
- Registrar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` temporário e caminho do log
- Validar a assinatura efetiva do wrapper e da task antes de assumir formato de parâmetro sensível de exportação ou importação
- Privilegiar `PreviewMode` e, quando suportado pela task carregada, `UpdateFile` antes de importação real
- Tratar `ImportKBInformation`, `UpdateFile` e defaults internos de importação/exportação como sensíveis e dependentes da assinatura efetiva da task `Import`
- Normalizar recortes multiplos de `IncludeItems` e `ExcludeItems` como lista antes de serializar para a task carregada
- Preservar `importedItems` como lista em qualquer diagnóstico JSON, mesmo quando houver apenas um item
- Quando a task carregada não expuser `UpdateFile` nem `ImportKBInformation`, o wrapper de preview deve bloquear esses parâmetros cedo
- Quando recortes sucessivos isolarem erro residual de `Source`, `Specification` ou referência não resolvida em objeto importado, tratar a continuação como frente de conteúdo da KB/`XPZ`, não como ajuste adicional presumido do wrapper
- Quando um teste controlado com `Source` global preenchido e outro teste controlado com ajuste isolado de `Pattern Settings` nao mudarem o padrao principal do log, registrar explicitamente que essas diferencas deixaram de ser suspeitas fortes e estreitar a hipotese para conteudo da KB/`XPZ`
- Exigir confirmação explícita antes de importação real
- Recomendar reabertura da KB na IDE oficial após testes relevantes para observar warning, marca de versão ou outro efeito colateral

---

## COMMUNICATION

- Responda no idioma do usuário
- Seja direto sobre estado operacional, riscos e limites
- Declare quando o resultado é apenas operacional e ainda depende de confirmação funcional
- Quando houver ambiguidade de contexto, interrompa a execução e peça definição explícita
- Não use linguagem otimista para sugerir segurança que ainda não foi validada empiricamente
- Quando a exportação headless gerar um `.xpz` para alimentar a pasta paralela da KB, declarar explicitamente o marco `XPZ gerado`
- Se a geração do `.xpz` fizer parte do caminho `B` do setup inicial, diferenciar explicitamente a fase `exportação headless concluída` da fase posterior `materialização em ObjetosDaKbEmXml`
- Se o pedido do usuário for apenas gerar o `.xpz`, parar no artefato gerado; só prosseguir para materialização quando o pedido for seguir com o setup ou com a materialização

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|-----------|-----------------|
| [README.md](../README.md) | Sempre - regras editoriais e posicionamento da base |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais, precedência e restrições da trilha XPZ |
| [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) | Sempre - base operacional, riscos conhecidos e interface vigente |

---

## EXPECTED INTERFACE

Esta skill assume, como interface operacional, scripts pequenos e explicitamente parametrizados. `Test-GeneXusMsBuildSetup.ps1`, `Open-GeneXusKbHeadless.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1` e `Invoke-GeneXusXpzImport.ps1` já foram materializados nesta fase; os demais não devem ser tratados como já implementados sem confirmação explícita.

Estado atual da materialização:

- `Test-GeneXusMsBuildSetup.ps1`: implementado como probe (sondagem técnica inicial) não invasivo
- `Open-GeneXusKbHeadless.ps1`: implementado para abertura e fechamento controlados da KB, com contexto ativo e sem import/export
- `Test-GeneXusXpzImportPreview.ps1`: implementado para `PreviewMode` de importação e já validado nesta conversa com XPZ real
- `Invoke-GeneXusXpzExport.ps1`: implementado para exportação headless de XPZ com parâmetros explícitos e diagnóstico JSON
- `Invoke-GeneXusXpzImport.ps1`: implementado para importação real de XPZ com parâmetros explícitos e diagnóstico JSON
- os demais scripts permanecem apenas como contrato

Scripts nesta frente:

- `Test-GeneXusMsBuildSetup.ps1`
  - status atual: implementado como probe (sondagem técnica inicial) não invasivo
- `Open-GeneXusKbHeadless.ps1`
  - status atual: implementado para abertura e fechamento controlados da KB
- `Test-GeneXusXpzImportPreview.ps1`
  - status atual: implementado para `PreviewMode` sem importação real, com `IncludeItems` e `ExcludeItems` validados nesta instalação
- `Invoke-GeneXusXpzExport.ps1`
  - status atual: implementado para exportação headless de XPZ com parâmetros explícitos e validação da task carregada
- `Invoke-GeneXusXpzImport.ps1`

Contrato inicial específico de `Test-GeneXusMsBuildSetup.ps1`:

- obrigatórios: `-WorkingDirectory`, `-LogPath`
- opcionais: `-GeneXusDir`, `-MsBuildPath`, `-KbPath`, `-VerboseLog`
- regra de contrato: `-WorkingDirectory` continua explícito; quando o caminho seguro ainda não existir, o probe pode criar exatamente essa pasta e registrar isso no diagnóstico
- códigos de saída contratuais:
  - `0` para `apto para prosseguir`
  - `10` a `16` para bloqueios operacionais esperados com diagnóstico estruturado
  - `90` para falha interna do script antes de diagnóstico completo

Parâmetros transversais esperados:

- `-KbPath`
- `-GeneXusDir`
- `-MsBuildPath`
- `-VersionName`
- `-EnvironmentName`
- `-WorkingDirectory`
- `-LogPath`
- `-VerboseLog`

Parâmetros específicos de exportação:

- `-XpzPath`
- `-ObjectList`
- `-DependencyType`
- `-ReferenceType`
- `-ExportKbInfo`
- `-ExportAll`

Parâmetros específicos de importação:

- `-XpzPath`
- `-PreviewMode`
- `-UpdateFilePath`
- `-IncludeItems`
- `-ExcludeItems`
- `-AutomaticBackup`
- `-ImportType`
- `-ImportKbInformation`

---

## WORKFLOW (fluxo de trabalho)

1. Reler a documentação local aplicável e usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como referência principal
2. Validar se o cenário é compatível com uso controlado e ambiente controlado
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Executar primeiro um probe (sondagem técnica inicial) não invasivo para validar:
   - `KbPath`
   - `GeneXusDir`
   - `MsBuildPath`
   - `WorkingDirectory`
   - `LogPath`
   - existência de `Genexus.Tasks.targets`
   Se `WorkingDirectory` estiver em caminho seguro e ainda não existir, o probe pode auto-criar exatamente essa pasta.
5. Resolver `GeneXusDir` e `MsBuildPath` por ordem explícita de precedência e fallback, registrando origem e descarte de candidatos quando aplicável
6. Classificar o resultado do probe (sondagem técnica inicial) como `apto para prosseguir` ou `não apto para prosseguir`
   O diagnóstico deve incluir `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`.
   O diagnóstico deve distinguir `WorkingDirectory` já existente de `WorkingDirectory` auto-criado no caminho explícito e seguro.
   Preferir `JSON` como formato canônico inicial.
7. Só depois abrir a KB e confirmar versão ativa e `Environment` ativo quando aplicável
8. Se o objetivo for inspeção, priorizar:
   - `PreviewMode`
   - `UpdateFile`, quando suportado pela task carregada
9. Se o objetivo for exportação, executar com parâmetros explícitos e conferir o artefato gerado
   Antes de emitir parâmetro sensível de exportação, validar a assinatura efetiva do wrapper e da task carregada para evitar sintaxe presumida incorreta.
10. Se o objetivo for importação real, exigir autorização explícita e ambiente controlado
11. Capturar e relatar:
   - `exitCode`
   - resumo de `stdout`
   - resumo de `stderr`
   - caminho do `.msbuild`
   - caminho do log
   - artefatos gerados ou consumidos
12. Classificar o resultado como:
   - `não apto para prosseguir`
   - `sucesso operacional`
   - `falha operacional`
   - `preview apenas`
   - `operação concluída, porém pendente de confirmação funcional`
13. Recomendar o próximo passo seguro, incluindo reabertura da KB na IDE quando o teste exigir observação posterior
14. Se a exportação gerou um `.xpz` full para a pasta paralela da KB, declarar explicitamente:
   - caminho do artefato gerado
   - status operacional da exportação
   - warnings estruturais relevantes
   - se a execução para no `.xpz` gerado ou se seguirá para materialização
15. Se o pedido do usuário for seguir com o setup depois da exportação full, anunciar a mudança de fase para materialização em `ObjetosDaKbEmXml` antes de sair da trilha `MSBuild`

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como capacidade operacional validada, com uso controlado
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] O probe (sondagem técnica inicial) não invasivo ocorreu antes de qualquer abertura de KB
- [ ] O probe (sondagem técnica inicial) devolveu diagnóstico estruturado completo
- [ ] O probe (sondagem técnica inicial) respeitou o contrato de parâmetros obrigatórios, opcionais e `exitCode`
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram explicitados
- [ ] O probe só auto-criou `WorkingDirectory` quando o caminho explícito era seguro e permaneceu bloqueando caminhos proibidos, inválidos ou ambíguos
- [ ] `GeneXusDir` e `MsBuildPath` foram resolvidos por precedência e fallback rastreáveis
- [ ] `Genexus.Tasks.targets` foi validado
- [ ] `PreviewMode` foi priorizado quando a intenção era inspeção
- [ ] Importação real só ocorreu com autorização explícita
- [ ] `stdout`, `stderr`, `exitCode`, `.msbuild` e log foram registrados
- [ ] O resultado foi separado entre sucesso operacional e confirmação funcional

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER assumir defaults internos de importação ou exportação como seguros sem validação prática
- NEVER tratar importação real como comportamento implícito
- NEVER depender de `GeneXus Server` como base operacional desta skill
- ABORT se `KbPath`, versão, `Environment`, pacote ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
- ABORT se a operação não puder produzir trilha rastreável de logs e artefatos
