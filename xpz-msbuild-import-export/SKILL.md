---
name: xpz-msbuild-import-export
description: Skill experimental para importação e exportação de XPZ via MSBuild, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates de segurança
---

# xpz-msbuild-import-export

Skill experimental para operações de importação e exportação de `XPZ` do GeneXus por `MSBuild`, em execução sem interface gráfica.

Esta skill não substitui o fluxo oficial atual da trilha paralela da KB, não depende de `GeneXus Server` e não trata sucesso operacional como evidência suficiente de sucesso funcional.

---

## GUIDELINE

Orquestre operações de `XPZ` via `MSBuild` com parâmetros explícitos, coleta rastreável de evidências e aborto seguro antes de operações sensíveis. Priorize descoberta de ambiente, `PreviewMode`, `UpdateFile` e validação posterior. Nunca trate importação real como padrão.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- planejar ou executar validação de ambiente para GeneXus via `MSBuild`
- abrir a `Knowledge Base` por `OpenKnowledgeBase`
- confirmar versão ativa e `Environment` ativo
- executar preview de importação com `PreviewMode`
- gerar `UpdateFile` para análise prévia de impacto
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

- Usar [10-plano-skill-headless-msbuild](../10-plano-skill-headless-msbuild.md) como base principal desta frente
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`, `LogPath` e `Genexus.Tasks.targets`
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de `C:\Program Files (x86)`
- Distinguir claramente:
  - sucesso operacional da chamada
  - efeito funcional observado depois no GeneXus
- Registrar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` temporário e caminho do log
- Privilegiar `PreviewMode` e `UpdateFile` antes de importação real
- Tratar `ImportKBInformation` e defaults internos de importação/exportação como sensíveis
- Exigir confirmação explícita antes de importação real
- Recomendar reabertura da KB na IDE oficial após testes relevantes para observar warning, marca de versão ou outro efeito colateral

---

## COMMUNICATION

- Responda no idioma do usuário
- Seja direto sobre estado experimental, riscos e limites
- Declare quando o resultado é apenas operacional e ainda depende de confirmação funcional
- Quando houver ambiguidade de contexto, interrompa a execução e peça definição explícita
- Não use linguagem otimista para sugerir segurança que ainda não foi validada empiricamente

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|-----------|-----------------|
| [README.md](../README.md) | Sempre - regras editoriais e posicionamento da base |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais, precedência e restrições da trilha XPZ |
| [10-plano-skill-headless-msbuild.md](../10-plano-skill-headless-msbuild.md) | Sempre - contrato experimental, fases, riscos e interface proposta |

---

## EXPECTED INTERFACE

Esta skill assume, como interface operacional futura, scripts pequenos e explicitamente parametrizados. Eles não devem ser tratados como já implementados sem confirmação explícita.

Scripts esperados:

- `Test-GeneXusMsBuildSetup.ps1`
- `Open-GeneXusKbHeadless.ps1`
- `Test-GeneXusXpzImportPreview.ps1`
- `Invoke-GeneXusXpzExport.ps1`
- `Invoke-GeneXusXpzImport.ps1`

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

## WORKFLOW

1. Reler a documentação local aplicável e usar [10-plano-skill-headless-msbuild](../10-plano-skill-headless-msbuild.md) como referência principal
2. Validar se o cenário é compatível com uso experimental e ambiente controlado
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Validar:
   - `KbPath`
   - `GeneXusDir`
   - `MsBuildPath`
   - `WorkingDirectory`
   - `LogPath`
   - existência de `Genexus.Tasks.targets`
5. Localizar `MSBuild.exe` por estratégia explícita de fallback e registrar qual caminho foi usado
6. Abrir a KB e confirmar versão ativa e `Environment` ativo quando aplicável
7. Se o objetivo for inspeção, priorizar:
   - `PreviewMode`
   - `UpdateFile`
8. Se o objetivo for exportação, executar com parâmetros explícitos e conferir o artefato gerado
9. Se o objetivo for importação real, exigir autorização explícita e ambiente controlado
10. Capturar e relatar:
   - `exitCode`
   - resumo de `stdout`
   - resumo de `stderr`
   - caminho do `.msbuild`
   - caminho do log
   - artefatos gerados ou consumidos
11. Classificar o resultado como:
   - `sucesso operacional`
   - `falha operacional`
   - `preview apenas`
   - `operação concluída, porém pendente de confirmação funcional`
12. Recomendar o próximo passo seguro, incluindo reabertura da KB na IDE quando o teste exigir observação posterior

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como experimental
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram explicitados
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
