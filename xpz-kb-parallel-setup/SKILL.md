---
name: xpz-kb-parallel-setup
description: Prepara e valida a estrutura inicial da pasta paralela da KB para carga inicial, sync de XPZ, indice derivado e artefatos de importacao
---

# xpz-kb-parallel-setup

Define e valida a estrutura inicial da pasta paralela da KB usada ao redor de uma Knowledge Base GeneXus. Essa estrutura nao substitui a pasta nativa da KB; ela concentra os `XPZ` exportados pela IDE, os XMLs materializados pelo fluxo oficial, o indice derivado para triagem e os artefatos locais preparados para importacao posterior.

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
- Preparar a pasta paralela da KB para uso de indice derivado em `KbIntelligence`
- Explicar a diferenca entre pasta da KB e pasta paralela da KB
- Confirmar nomes padrao das subpastas quando o usuario nao informou alternativas

Do NOT use this skill for:
- Sincronizar `XPZ` especifico no acervo oficial (use `xpz-sync`)
- Gerar ou empacotar objetos XML (use `xpz-builder`)
- Analisar estrutura de objeto XML individual (use `xpz-reader`)
- Consultar o indice derivado como etapa analitica principal (use `xpz-index-triage`)
- Regenerar o indice como objetivo principal da tarefa; esta skill prepara a estrutura e os wrappers locais

---

## RESPONSABILIDADES

- Explicar que a pasta nativa da KB e diferente da pasta paralela da KB
- Assumir o termo principal `pasta paralela da KB`
- Se o caminho da pasta nativa da KB nao vier no prompt, pedir esse caminho ao usuario antes de concluir o setup inicial
- Se o caminho da pasta nativa da KB vier no prompt, reutilizar esse valor sem pedir novamente
- Quando o usuario nao informar nomes alternativos, assumir estas subpastas padrao:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- Explicar que os nomes acima sao apenas padroes sugeridos; a funcao de cada pasta prevalece sobre o nome literal
- Se o usuario informar nomes diferentes, registrar esse mapeamento em `AGENTS.md` e, quando fizer sentido para humanos, tambem em `README.md` dentro da propria pasta paralela da KB
- Registrar em `AGENTS.md` da pasta paralela o caminho confirmado da pasta nativa da KB
- Registrar em `AGENTS.md` da pasta paralela que a pasta nativa da KB e terreno proibido para gravacao por agentes, com leitura permitida apenas quando o fluxo operacional explicito realmente exigir
- Quando houver `README.md` local para humanos na pasta paralela, espelhar ali a identificacao da pasta nativa da KB e a regra de somente leitura em linguagem clara
- Em setup inicial padrao sem nomes alternativos, sem conflito estrutural e com pasta nativa da KB ja informada, evitar exploracao ampla do motor compartilhado e dos exemplos antes de criar a estrutura base; explorar mais so se surgir bloqueio concreto
- Explicar a funcao de cada subpasta
- Tratar `ObjetosDaKbEmXml` como snapshot oficial somente leitura para agentes
- Tratar `XpzExportadosPelaIDE` como pasta de entrada onde o usuario grava os `.xpz` exportados pela IDE
- Tratar `Temp` como destino preferencial para artefatos efemeros, temporarios de execucao, relatorios descartaveis e copias temporarias de SQLite
- Tratar `KbIntelligence` como pasta do indice SQLite derivado e regeneravel, normalmente `KbIntelligence\kb-intelligence.sqlite`, mais relatorios de validacao quando o repositorio local adotar esse fluxo
- Tratar `kb-source-metadata.md` como metadado operacional da materializacao XPZ/XML; ele deve expor `last_xpz_materialization_run_at` quando o fluxo oficial tiver processado um insumo da IDE
- Tratar `KbIntelligence\kb-intelligence.sqlite` como dono do metadado `last_index_build_run_at` na tabela `metadata`; esse horario deve ser igual ou posterior a `last_xpz_materialization_run_at` para permitir triagem ampla e geracao de objetos de importacao
- Explicar que o fluxo oficial de materializacao XPZ/XML deve chamar a regeneracao/validacao do indice derivado compulsoriamente apos atualizar `ObjetosDaKbEmXml`
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
- Explicar que o indice em `KbIntelligence` so pode ser gerado depois que `ObjetosDaKbEmXml` existir e contiver o snapshot oficial materializado
- Explicar que `KbIntelligence` nao substitui `ObjetosDaKbEmXml`; ele e uma camada derivada para triagem e deve ser regeneravel a partir do snapshot oficial
- Explicar que, se `last_index_build_run_at` estiver ausente ou anterior a `last_xpz_materialization_run_at`, o agente nao deve pesquisar o acervo em massa nem gerar objetos para importacao; deve tratar isso como excecao operacional e oferecer a regeneracao/validacao do indice antes de seguir
- Prever wrappers locais `.ps1` na pasta `scripts` quando a pasta paralela da KB precisar reconstruir o fluxo operacional local sobre o motor compartilhado
- Tratar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte esperada do setup inicial padrao quando a pasta paralela estiver versionada em Git
- Reutilizar o fluxo oficial previsto nas skills e no motor compartilhado antes de considerar qualquer script novo
- Gerar `kb-source-metadata.md` inicial em formato compativel com o motor compartilhado, preservando desde o setup o campo nominal `last_xpz_materialization_run_at`
- Nao salvar memoria operacional fora da propria pasta paralela da KB sem autorizacao explicita do usuario; `AGENTS.md`, `README.md` e arquivos operacionais locais sao a camada preferencial de memoria do setup
- Ao concluir o setup inicial, declarar explicitamente que a pasta paralela esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
- Ao concluir o setup inicial, oferecer dois proximos passos:
  - `A)` o usuario exporta o `.xpz` full pela IDE do GeneXus para `XpzExportadosPelaIDE` e o agente materializa os XMLs depois
  - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
- Ao oferecer `A)` e `B)`, dizer explicitamente que `A)` e o caminho preferencial e normalmente mais rapido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
- Se o usuario escolher `B)`, encaminhar a geracao do `.xpz` full pela skill `xpz-msbuild-import-export` em vez de improvisar exportacao fora dessa trilha

---

## MAPEAMENTO INTENCAO -> FUNCAO DA PASTA

- Se a intencao for consultar o acervo materializado da KB:
  - usar a pasta com funcao de acervo materializado
  - essa pasta recebe XMLs individuais extraidos do `XPZ` exportado pela IDE
  - essa pasta pode usar subpastas por tipo amigavel de objeto GeneXus
- Se a intencao for consultar relacoes, impacto tecnico ou trilha funcional curta por indice derivado:
  - usar a pasta `KbIntelligence` como destino do SQLite derivado e dos relatorios de validacao
  - usar wrappers locais em `scripts` para consultar ou regenerar o indice
  - manter `ObjetosDaKbEmXml` como fonte normativa e origem de regeneracao do indice
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

- A pasta `scripts` deve prever pelo menos dois wrappers locais quando a pasta paralela da KB operar com fluxo oficial de materializacao XML sobre o motor compartilhado:
  - wrapper de atualizacao diaria a partir de `.xpz`, XML exportado ou pasta contendo o XML do pacote
  - wrapper de conferencia full que reutiliza o wrapper diario em modo `VerifyOnly + FullSnapshot`
- Quando a pasta paralela da KB adotar `KbIntelligence`, a pasta `scripts` tambem deve prever wrappers locais finos para:
  - consulta do indice derivado em `KbIntelligence\kb-intelligence.sqlite`
  - regeneracao e validacao do indice a partir de `ObjetosDaKbEmXml`
- Um helper local de notificacao pode existir como apoio operacional, mas nao substitui os wrappers principais
- O wrapper local deve ser fino:
  - resolver caminhos da pasta paralela da KB
  - apontar para o motor compartilhado
  - repassar parametros
  - opcionalmente produzir resumo Git, relatorio e metadados da KB
- O wrapper local de materializacao deve passar caminho de `kb-source-metadata.md` para que `last_xpz_materialization_run_at` seja gravado mesmo quando nao houver mudanca material nos XMLs
- O wrapper local de materializacao deve chamar o wrapper local de regeneracao/validacao do indice depois de sync bem-sucedido que nao seja `VerifyOnly`
- O wrapper local de regeneracao do indice deve preservar os metadados produzidos pelo motor compartilhado, incluindo `last_index_build_run_at`
- Quando o motor compartilhado ganhar parametros operacionais relevantes, isso
  nao significa automaticamente que os wrappers locais ja os exponham
- Se o wrapper local estiver defasado em relacao ao motor compartilhado, tratar
  isso como oportunidade de atualizacao local, mencionar ao usuario e aguardar
  aprovacao explicita; nao corrigir automaticamente
- O wrapper local nao deve reimplementar o motor compartilhado se o fluxo oficial ja existir
- Para reconstruir wrappers locais, usar como referencia os exemplos sanitizados desta skill antes de improvisar um fluxo novo:
  - [Update-KbFromXpz.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Update-KbFromXpz.example.ps1)
  - [Test-KbFullSnapshot.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Test-KbFullSnapshot.example.ps1)
  - [Query-KbIntelligence.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Query-KbIntelligence.example.ps1)
  - [Update-KbIntelligenceIndex.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Update-KbIntelligenceIndex.example.ps1)
  - [Notify-TaskComplete.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Notify-TaskComplete.example.ps1)
- Esses `.example.ps1` sao exemplos metodologicos importantes para bootstrap tecnico e reconstrucao assistida dos wrappers locais finais.
- Esses `.example.ps1` nao substituem o wrapper local real da pasta paralela da KB e nao devem virar fallback automatico de execucao no fluxo normal.
- Os exemplos sanitizados de wrappers incorporam uma trilha real de pasta paralela da KB com:
  - metadados da KB gravados em `kb-source-metadata.md`
  - `last_xpz_materialization_run_at` atualizado a cada processamento XPZ/XML solicitado
  - refresh compulsorio do indice derivado apos materializacao XPZ/XML bem-sucedida
  - resumo Git limitado ao acervo oficial quando houver mudanca material
  - limpeza localizada de residuos de objeto renomeado por `guid`, preservando o XML com nome atual e `lastUpdate` mais confiavel
  - repasse opcional de `ExpectedItems` para distinguir foco esperado e retorno oficial adicional
  - indice derivado em `KbIntelligence\kb-intelligence.sqlite`
  - `last_index_build_run_at` gravado na tabela `metadata` do SQLite e espelhado no relatorio de validacao
  - consulta e regeneracao do indice por wrappers locais, sem reimplementar o motor compartilhado

---

## GATE DE COMPATIBILIDADE OPERACIONAL

Antes de trabalho substantivo em uma pasta paralela da KB que declare uso de `KbIntelligence`, validar tres camadas:

- Estrutura: pastas funcionais esperadas, `README.md`, `AGENTS.md`, `kb-source-metadata.md`, `ObjetosDaKbEmXml` e `KbIntelligence`.
- Wrappers: scripts locais mínimos em `scripts`, incluindo consulta do indice com suporte a `index-metadata`, regeneracao/validacao do indice e materializacao XPZ/XML com refresh compulsorio do indice.
- Frescor: `last_index_build_run_at` obtido pelo wrapper local de consulta deve ser igual ou posterior a `last_xpz_materialization_run_at`, lido nominalmente em `kb-source-metadata.md`.

Executar o gate em ordem sequencial e parar no primeiro bloqueio. Nao investigar camadas internas enquanto a camada externa estiver invalida; no maximo, mencionar que outras verificacoes podem ser necessarias depois da primeira correcao.

Detectar defasagem de wrappers antes de executar a tarefa de negocio:

- Wrapper de consulta: deve aceitar `index-metadata` pelo proprio wrapper local; se a chamada falhar por parametro desconhecido, `ValidateSet` antigo ou ausencia de saida com `last_index_build_run_at`, bloquear.
- Wrapper de regeneracao: deve existir, aceitar validacao com `-FailOnValidationFailure` e gravar `last_index_build_run_at` no indice gerado.
- Wrapper de materializacao XPZ/XML: se a pasta adota `KbIntelligence`, deve chamar o wrapper de regeneracao/validacao do indice apos sync bem-sucedido que nao seja `VerifyOnly`; se nao houver evidencia clara desse encadeamento, bloquear proximo sync normal e oferecer atualizacao.
- A existencia de `.example.ps1` na base metodologica nao reduz esse bloqueio: enquanto o wrapper local real estiver ausente, o fluxo normal deve permanecer bloqueado.
- Evidencia clara de encadeamento significa declaracao local explicita em `README.md`/`AGENTS.md` ou chamada observavel no proprio wrapper local; nao presumir compatibilidade so porque a base compartilhada ja exige esse comportamento.
- Metadado de materializacao: `kb-source-metadata.md` deve expor o campo nominal `last_xpz_materialization_run_at`; se o campo nao existir, bloquear. Nao aceitar como substituto data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatorio ou qualquer outro metadado aproximado.

Quando o gate falhar por wrapper de materializacao defasado, a correcao de compatibilidade deve atualizar o wrapper local antes de qualquer novo sync normal. Nao usar o wrapper antigo para "consertar" `kb-source-metadata.md` e depois regenerar o indice manualmente como caminho normal; isso mascara a incompatibilidade que o gate deve tornar visivel.

Se qualquer camada falhar, tratar a pasta paralela como defasada ou incompatível com a versão operacional atual das skills:

- bloquear pesquisa ampla, triagem substantiva e geracao de objetos para importacao;
- permitir apenas diagnostico minimo para explicar o que falta;
- nao compensar com leitura manual de `kb-intelligence-validation.json`, SQLite direto, `kb-source-metadata.md` isolado, XML oficial de objeto ou varredura em `ObjetosDaKbEmXml`;
- nao executar sync normal por wrapper antigo como etapa de reparo de compatibilidade quando o proprio wrapper de sync estiver defasado;
- nao executar fluxo normal por `.example.ps1` da base metodologica como substituto do wrapper local real ausente;
- nao orientar `sync` seguido de rebuild manual separado do indice como fluxo normal quando a pasta adota `KbIntelligence`;
- oferecer ao usuario a atualizacao da estrutura/wrappers/indice usando esta skill.

O objetivo do bloqueio e tornar visivel que uma pasta paralela ainda precisa receber atualizacao operacional, especialmente em ambientes comunitarios com pastas em diferentes estagios de adocao.

---

## COMMUNICATION

- Responder na lingua do usuario
- Liderar com a diferenca entre pasta da KB e pasta paralela da KB
- Quando houver risco de ambiguidade, usar sempre a expressao completa `pasta paralela da KB`
- Se a estrutura nao existir, dizer explicitamente o que falta
- Em setup inicial padrao bem delimitado, preferir fechamento curto e objetivo em vez de narrar exploracao desnecessaria
- Se o gate de compatibilidade falhar, explicar a falha como defasagem operacional da pasta paralela e oferecer atualizacao antes de responder a pergunta de negocio
- Nao tratar a estrutura da pasta nativa da KB como se fosse a mesma coisa que o repositorio paralelo
- Ao fechar um setup inicial bem-sucedido, diferenciar explicitamente `estrutura pronta` de `snapshot oficial ainda nao materializado`
- No fechamento do setup inicial, apresentar `A)` e `B)` como opcoes de proximo passo e informar o tradeoff de tempo entre elas

---

## WORKFLOW

1. Confirmar se o usuario esta falando da pasta nativa da KB ou da pasta paralela da KB
2. Se o caminho da pasta nativa da KB nao vier informado, pedir esse caminho ao usuario antes de concluir o setup inicial
3. Se o usuario nao informar nomes alternativos, assumir as subpastas padrao
4. Se o usuario informar nomes alternativos, registrar o mapeamento entre nome real e funcao da pasta em `AGENTS.md` da pasta paralela da KB e, quando ajudar humanos, tambem em `README.md`
5. Registrar em `AGENTS.md` da pasta paralela o caminho confirmado da pasta nativa da KB e a regra de que essa pasta e somente leitura para agentes, com gravacao proibida
6. Quando houver `README.md` local na pasta paralela, registrar ali tambem a identificacao da pasta nativa da KB e a regra de somente leitura em linguagem clara
7. Se o caso for setup inicial padrao e a pasta paralela estiver praticamente vazia, criar primeiro a estrutura base e so aprofundar exploracao se surgir bloqueio concreto
8. Validar a existencia da estrutura nesta ordem:
   - `scripts`
   - `Temp`
   - `XpzExportadosPelaIDE`
   - `ObjetosDaKbEmXml`
   - `KbIntelligence`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus`
9. Quando a pasta paralela estiver versionada em Git, criar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte do bootstrap padrao
10. Criar `kb-source-metadata.md` inicial com o campo nominal `last_xpz_materialization_run_at`, sem inventar formato paralelo desconectado do motor compartilhado
11. Nao salvar memoria externa do agente fora da pasta paralela da KB sem autorizacao explicita do usuario
12. Explicar o papel de cada pasta:
   - `ObjetosDaKbEmXml` = snapshot oficial extraido via fluxo oficial do `.ps1`
   - `ObjetosDaKbEmXml` = materializacao do `XPZ` completo ou parcial da IDE, quebrando `full.xml` em XMLs individuais por objeto
   - `ObjetosDaKbEmXml` = organizacao por subpastas de tipo amigavel e nomes amigaveis de objeto
   - `KbIntelligence` = indice SQLite derivado e regeneravel a partir de `ObjetosDaKbEmXml`
   - `XpzExportadosPelaIDE` = entrada dos `.xpz` gravados pelo usuario na IDE
   - `XpzExportadosPelaIDE` = arquivos ja consumidos podem receber o prefixo `processado_` apos sucesso no fluxo oficial
   - `Temp` = area local para temporarios, logs auxiliares e copias efemeras de SQLite
   - `scripts` = wrappers `.ps1` e utilitarios operacionais
   - `scripts` = quando a pasta paralela da KB for inicializada do zero, os wrappers locais devem ser reconstruidos a partir do fluxo oficial e dos exemplos sanitizados desta skill
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = XMLs temporarios gerados pelo agente para importacao manual, organizados por frente em subpastas `NomeCurto_GUID_YYYYMMDD`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = nao recebe materializacao do acervo vindo de `XPZ`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus` = pacote final de importacao pela IDE, mantido plano sem subpastas por frente
13. Se `ObjetosDaKbEmXml` ainda nao existir, tratar o acervo como ainda nao materializado
14. Se `ObjetosGeradosParaImportacaoNaKbNoGenexus` nao estiver organizado por frentes em subpastas `NomeCurto_GUID_YYYYMMDD`, tratar isso como desvio operacional e orientar correcao
15. Se `XpzExportadosPelaIDE` estiver ausente e o fluxo depender de `XPZ`, pedir ao usuario o caminho pretendido ou criar a pasta padrao quando a politica do repositorio permitir
16. Se a pasta `scripts` existir sem wrappers locais minimos, orientar a reconstruir:
   - wrapper de atualizacao diaria sobre o motor compartilhado
   - wrapper de conferencia full reaproveitando o wrapper diario
   - wrapper de consulta do indice derivado, se a KB local adotar `KbIntelligence`
   - wrapper de regeneracao e validacao do indice derivado, se a KB local adotar `KbIntelligence`
   - helper local opcional de notificacao, se houver necessidade operacional
13. Se `KbIntelligence` estiver ausente, orientar sua criacao como pasta de artefatos derivados antes de instalar wrappers de indice
14. Se `ObjetosDaKbEmXml` ainda nao contiver snapshot materializado, nao tentar gerar `kb-intelligence.sqlite`; preparar apenas a pasta e os wrappers locais
15. Se a pasta adotar `KbIntelligence`, validar o gate de compatibilidade operacional antes de permitir pesquisa ampla, triagem substantiva ou geracao de objetos
16. Se o gate falhar, oferecer atualizacao da pasta paralela/wrappers/indice e nao responder a pergunta de negocio por fallback manual
17. Ao concluir o setup inicial, deixar explicito que a estrutura esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
18. Ao concluir o setup inicial, oferecer os proximos passos:
   - `A)` o usuario exporta o `.xpz` full pela IDE para `XpzExportadosPelaIDE`, e o agente materializa os XMLs depois
   - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
19. Ao oferecer `A)` e `B)`, declarar que `A)` e o caminho preferencial e normalmente mais rapido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
20. Se o usuario escolher `B)`, usar a skill `xpz-msbuild-import-export` e nao improvisar fluxo alternativo de exportacao

---

## EXEMPLO CURTO DE ESTRUTURA MATERIALIZADA

```text
PastaParalelaDaKb/
  scripts/
    Update-KbFromXpz.ps1
    Test-KbFullSnapshot.ps1
    Query-KbIntelligence.ps1
    Update-KbIntelligenceIndex.ps1
  Temp/
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
  KbIntelligence/
    kb-intelligence.sqlite
    kb-intelligence-validation.json
  ObjetosGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414/
      ClienteNovo.xml
      PedidoAjustado.xml
  PacotesGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414_01.import_file.xml
```

---

## CONSTRAINTS

- NUNCA confundir a pasta nativa da KB com a pasta paralela da KB
- NUNCA gravar na pasta nativa da KB; essa pasta e somente leitura para agentes, salvo leitura operacional controlada quando realmente necessaria
- NUNCA gravar manualmente em `ObjetosDaKbEmXml`
- NUNCA tratar `XpzExportadosPelaIDE` como area de saida de pacotes ou XMLs gerados
- NUNCA aplicar o prefixo `processado_` antes de sucesso claro no processamento do `.xpz`
- NUNCA manter o lote ativo diretamente na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus`; usar a subpasta da frente `NomeCurto_GUID_YYYYMMDD`
- NUNCA criar subpastas por frente em `PacotesGeradosParaImportacaoNaKbNoGenexus`; essa area deve permanecer plana
- NUNCA materializar `XPZ` completo ou parcial da IDE dentro da pasta de geracao para importacao
- NUNCA usar GUID como nome principal de pasta ou arquivo do acervo materializado
- NUNCA usar `guid`, `parentGuid`, `parentType` ou `moduleGuid` como eixo principal de navegacao da pasta paralela da KB
- NUNCA tratar `KbIntelligence` como fonte normativa; o indice e derivado de `ObjetosDaKbEmXml`
- NUNCA gerar `kb-intelligence.sqlite` antes de existir snapshot oficial materializado em `ObjetosDaKbEmXml`
- NUNCA criar script novo se ja houver fluxo oficial previsto nas skills ou em `scripts/` do repositorio
- NUNCA presumir que a ausencia de `ObjetosDaKbEmXml` significa snapshot vazio; significa estrutura ainda nao materializada
- NUNCA esconder do usuario quando a estrutura padrao foi assumida por falta de nomes alternativos
