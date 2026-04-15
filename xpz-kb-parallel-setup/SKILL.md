---
name: xpz-kb-parallel-setup
description: Prepara e valida a estrutura inicial da pasta paralela da KB para carga inicial, sync de XPZ e geracao de artefatos de importacao
---

# xpz-kb-parallel-setup

Define e valida a estrutura inicial da pasta paralela da KB usada ao redor de uma Knowledge Base GeneXus. Essa estrutura nao substitui a pasta nativa da KB; ela concentra os `XPZ` exportados pela IDE, os XMLs materializados pelo fluxo oficial e os artefatos locais preparados para importacao posterior.

---

## GUIDELINE

Usar esta skill quando o trabalho exigir preparar, explicar, validar ou corrigir a estrutura inicial da pasta paralela da KB. O agente deve separar claramente a pasta nativa da KB da pasta paralela e aplicar os nomes padrao quando o usuario nao informar alternativas.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- Carga Inicial de uma KB usando repositorio paralelo
- Preparar a estrutura inicial de pastas para fluxos com `XPZ`
- Validar se a pasta paralela da KB esta pronta para `sync`, geracao de XML ou empacotamento
- Explicar a diferenca entre pasta da KB e pasta paralela da KB
- Confirmar nomes padrao das subpastas quando o usuario nao informou alternativas

Do NOT use this skill for:
- Sincronizar `XPZ` especifico no acervo oficial (use `xpz-sync`)
- Gerar ou empacotar objetos XML (use `xpz-builder`)
- Analisar estrutura de objeto XML individual (use `xpz-reader`)

---

## RESPONSABILIDADES

- Explicar que a pasta nativa da KB e diferente da pasta paralela da KB
- Assumir o termo principal `pasta paralela da KB`
- Quando o usuario nao informar nomes alternativos, assumir estas subpastas padrao:
  - `ObjetosDaKbEmXml`
  - `XpzExportadosPelaIDE`
  - `scripts`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- Explicar que os nomes acima sao apenas padroes sugeridos; a funcao de cada pasta prevalece sobre o nome literal
- Se o usuario informar nomes diferentes, registrar esse mapeamento em `AGENTS.md` e, quando fizer sentido para humanos, tambem em `README.md` dentro da propria pasta paralela da KB
- Explicar a funcao de cada subpasta
- Tratar `ObjetosDaKbEmXml` como snapshot oficial somente leitura para agentes
- Tratar `XpzExportadosPelaIDE` como pasta de entrada onde o usuario grava os `.xpz` exportados pela IDE
- Explicar que, apos processamento bem-sucedido, um `.xpz` em `XpzExportadosPelaIDE` pode ser renomeado para `processado_<nome-original>.xpz`
- Tratar `ObjetosGeradosParaImportacaoNaKbNoGenexus` como area de trabalho para XMLs temporarios destinados a importacao manual na IDE
- Tratar `PacotesGeradosParaImportacaoNaKbNoGenexus` como area de saida para `import_file.xml` e, quando aplicavel, `XPZ`
- Exigir que cada frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus` use sua propria subpasta `NomeCurto_GUID_YYYYMMDD`
- Explicar que `NomeCurto_GUID_YYYYMMDD` combina nome curto, GUID criado na abertura da frente e data de criacao da frente; `YYYYMMDD` representa a data de criacao da frente, nao a data do pacote
- Explicar que a subpasta `NomeCurto_GUID_YYYYMMDD` e a unidade ativa da frente
- Exigir reuso da mesma subpasta quando a frente ja existir e estiver sendo retomada
- Exigir que `PacotesGeradosParaImportacaoNaKbNoGenexus` permaneça plano, sem subpastas por frente
- Explicar que novos `XPZ` completos podem ser usados a qualquer momento para reatualizar `ObjetosDaKbEmXml`
- Distinguir Carga Inicial, atualizacao incremental e empacotamento local
- Explicar que materializar um `XPZ` completo da IDE inclui quebrar o `full.xml` em XMLs individuais por objeto
- Explicar que o acervo materializado deve ser organizado em subpastas por tipo amigavel de objeto GeneXus
- Explicar que os XMLs materializados devem usar nomes amigaveis dos objetos, nao GUID como nome principal
- Explicar que `guid`, `parentGuid`, `parentType` e `moduleGuid` sao metadados de apoio para consistencia e rastreabilidade, nao o eixo principal de organizacao
- Prever wrappers locais `.ps1` na pasta `scripts` quando a pasta paralela da KB precisar reconstruir o fluxo operacional local sobre o motor compartilhado
- Reutilizar o fluxo oficial previsto nas skills e no motor compartilhado antes de considerar qualquer script novo

---

## MAPEAMENTO INTENCAO -> FUNCAO DA PASTA

- Se a intencao for consultar o acervo materializado da KB:
  - usar a pasta com funcao de acervo materializado
  - essa pasta recebe XMLs individuais extraidos do `XPZ` exportado pela IDE
  - essa pasta pode usar subpastas por tipo amigavel de objeto GeneXus
- Se a intencao for gerar XML novo ou copia alterada para futura importacao na IDE:
  - usar a pasta com funcao de geracao para importacao
  - essa pasta recebe apenas XMLs novos ou copias alteradas geradas pelo agente
  - cada frente ativa deve usar sua propria subpasta `NomeCurto_GUID_YYYYMMDD`
- Se a intencao for guardar `XPZ` exportado pela IDE:
  - usar a pasta com funcao de entrada de `XPZ`
  - essa pasta nao e acervo materializado nem area de geracao de XML
- Se a intencao for guardar pacote final de importacao:
  - usar a pasta com funcao de saida de pacotes
  - essa pasta recebe `import_file.xml` e, quando aplicavel, `XPZ`

---

## REGRAS DE NAMING

- Para acervo materializado, preferir subpastas por tipo amigavel de objeto GeneXus, por exemplo `Transaction`, `Procedure`, `WebPanel`
- Para acervo materializado, preferir nome amigavel do objeto como nome do XML, por exemplo `Cliente.xml`, `GeraBoleto.xml`
- Nao usar GUID como nome principal de pasta ou arquivo do acervo materializado
- Se houver colisao rara de nome, o GUID pode aparecer apenas como apoio de desambiguacao, nunca como eixo principal da organizacao
- GUID, `parentGuid`, `parentType` e `moduleGuid` servem como metadados de apoio, nao como estrutura principal de saida
- Para frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, usar a subpasta `NomeCurto_GUID_YYYYMMDD`
- Para pacote final em `PacotesGeradosParaImportacaoNaKbNoGenexus`, usar o formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa apenas a rodada curta do pacote naquela frente; nao representa versao semantica
- no pacote final, o vinculo com a frente existe apenas pelo prefixo `NomeCurto_GUID_YYYYMMDD` somado ao `nn`

---

## WRAPPERS LOCAIS ESPERADOS

- A pasta `scripts` deve prever pelo menos dois wrappers locais quando a pasta paralela da KB operar com fluxo oficial sobre o motor compartilhado:
  - wrapper de atualizacao diaria a partir de `.xpz`, XML exportado ou pasta contendo o XML do pacote
  - wrapper de conferencia full que reutiliza o wrapper diario em modo `VerifyOnly + FullSnapshot`
- Um helper local de notificacao pode existir como apoio operacional, mas nao substitui os wrappers principais
- O wrapper local deve ser fino:
  - resolver caminhos da pasta paralela da KB
  - apontar para o motor compartilhado
  - repassar parametros
  - opcionalmente produzir resumo Git, relatorio e metadados da KB
- O wrapper local nao deve reimplementar o motor compartilhado se o fluxo oficial ja existir
- Para reconstruir wrappers locais, usar como referencia os exemplos sanitizados desta skill antes de improvisar um fluxo novo:
  - [Update-KbFromXpz.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Update-KbFromXpz.example.ps1)
  - [Test-KbFullSnapshot.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Test-KbFullSnapshot.example.ps1)
  - [Notify-TaskComplete.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Notify-TaskComplete.example.ps1)

---

## COMMUNICATION

- Responder na lingua do usuario
- Liderar com a diferenca entre pasta da KB e pasta paralela da KB
- Quando houver risco de ambiguidade, usar sempre a expressao completa `pasta paralela da KB`
- Se a estrutura nao existir, dizer explicitamente o que falta
- Nao tratar a estrutura da pasta nativa da KB como se fosse a mesma coisa que o repositorio paralelo

---

## WORKFLOW

1. Confirmar se o usuario esta falando da pasta nativa da KB ou da pasta paralela da KB
2. Se o usuario nao informar nomes alternativos, assumir as cinco subpastas padrao
3. Se o usuario informar nomes alternativos, registrar o mapeamento entre nome real e funcao da pasta em `AGENTS.md` da pasta paralela da KB e, quando ajudar humanos, tambem em `README.md`
4. Validar a existencia da estrutura nesta ordem:
   - `scripts`
   - `XpzExportadosPelaIDE`
   - `ObjetosDaKbEmXml`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus`
5. Explicar o papel de cada pasta:
   - `ObjetosDaKbEmXml` = snapshot oficial extraido via fluxo oficial do `.ps1`
   - `ObjetosDaKbEmXml` = materializacao do `XPZ` completo ou parcial da IDE, quebrando `full.xml` em XMLs individuais por objeto
   - `ObjetosDaKbEmXml` = organizacao por subpastas de tipo amigavel e nomes amigaveis de objeto
   - `XpzExportadosPelaIDE` = entrada dos `.xpz` gravados pelo usuario na IDE
   - `XpzExportadosPelaIDE` = arquivos ja consumidos podem receber o prefixo `processado_` apos sucesso no fluxo oficial
   - `scripts` = wrappers `.ps1` e utilitarios operacionais
   - `scripts` = quando a pasta paralela da KB for inicializada do zero, os wrappers locais devem ser reconstruidos a partir do fluxo oficial e dos exemplos sanitizados desta skill
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = XMLs temporarios gerados pelo agente para importacao manual, organizados por frente em subpastas `NomeCurto_GUID_YYYYMMDD`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = nao recebe materializacao do acervo vindo de `XPZ`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus` = pacote final de importacao pela IDE, mantido plano sem subpastas por frente
6. Se `ObjetosDaKbEmXml` ainda nao existir, tratar o acervo como ainda nao materializado
7. Se `ObjetosGeradosParaImportacaoNaKbNoGenexus` nao estiver organizado por frentes em subpastas `NomeCurto_GUID_YYYYMMDD`, tratar isso como desvio operacional e orientar correcao
8. Se `XpzExportadosPelaIDE` estiver ausente e o fluxo depender de `XPZ`, pedir ao usuario o caminho pretendido ou criar a pasta padrao quando a politica do repositorio permitir
9. Se a pasta `scripts` existir sem wrappers locais minimos, orientar a reconstruir:
   - wrapper de atualizacao diaria sobre o motor compartilhado
   - wrapper de conferencia full reaproveitando o wrapper diario
   - helper local opcional de notificacao, se houver necessidade operacional

---

## EXEMPLO CURTO DE ESTRUTURA MATERIALIZADA

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
```

---

## CONSTRAINTS

- NUNCA confundir a pasta nativa da KB com a pasta paralela da KB
- NUNCA gravar manualmente em `ObjetosDaKbEmXml`
- NUNCA tratar `XpzExportadosPelaIDE` como area de saida de pacotes ou XMLs gerados
- NUNCA aplicar o prefixo `processado_` antes de sucesso claro no processamento do `.xpz`
- NUNCA manter o lote ativo diretamente na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus`; usar a subpasta da frente `NomeCurto_GUID_YYYYMMDD`
- NUNCA criar subpastas por frente em `PacotesGeradosParaImportacaoNaKbNoGenexus`; essa area deve permanecer plana
- NUNCA materializar `XPZ` completo ou parcial da IDE dentro da pasta de geracao para importacao
- NUNCA usar GUID como nome principal de pasta ou arquivo do acervo materializado
- NUNCA usar `guid`, `parentGuid`, `parentType` ou `moduleGuid` como eixo principal de navegacao da pasta paralela da KB
- NUNCA criar script novo se ja houver fluxo oficial previsto nas skills ou em `scripts/` do repositorio
- NUNCA presumir que a ausencia de `ObjetosDaKbEmXml` significa snapshot vazio; significa estrutura ainda nao materializada
- NUNCA esconder do usuario quando a estrutura padrao foi assumida por falta de nomes alternativos
