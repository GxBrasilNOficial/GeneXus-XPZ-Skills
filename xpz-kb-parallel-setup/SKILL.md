---
name: xpz-kb-parallel-setup
description: Prepara e valida a estrutura inicial da pasta paralela da KB para carga inicial, sync de XPZ, indice derivado e artefatos de importacao
---

# xpz-kb-parallel-setup

Define e valida a estrutura inicial da pasta paralela da KB usada ao redor de uma Knowledge Base GeneXus. Essa estrutura nao substitui a pasta nativa da KB; ela concentra os `XPZ` exportados pela IDE, os XMLs materializados pelo fluxo oficial, o indice derivado para triagem e os artefatos locais preparados para importacao posterior.

---

## GUIDELINE

Usar esta skill quando o trabalho exigir preparar, explicar, validar, atualizar ou corrigir a estrutura da pasta paralela da KB. O agente deve separar claramente a pasta nativa da KB da pasta paralela e aplicar os nomes padrao quando o usuario nao informar alternativas.

Quando o usuario usar linguagem ambigua como "refazer", "reiniciar", "recriar" ou equivalente em pasta que ja tem historico real, nao assumir `modo_criacao` automaticamente. Clarificar explicitamente se o usuario quer recriar do zero — destruindo dados existentes — ou apenas incorporar scripts novos preservando o historico. Apresentar as duas opcoes com consequencias claras antes de qualquer acao.

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
- Atualizar wrappers de pasta paralela com historico de uso para incorporar novos scripts previstos pela base metodologica compartilhada
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
- Se o agente verificar a existencia da pasta nativa da KB, declarar o resultado no handoff; se ela nao existir ou nao estiver acessivel, registrar o caminho informado, manter a regra de nao gravacao e fechar o setup com ressalva operacional explicita
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
- Quando a inspecao local da pasta contradisser contexto indireto do ambiente, da sessao ou de hooks, confiar primeiro na inspecao local e seguir com verificacao curta e objetiva, sem narrativa longa de especulacao
- Explicar a funcao de cada subpasta
- Tratar `ObjetosDaKbEmXml` como snapshot oficial somente leitura para agentes
- Tratar `XpzExportadosPelaIDE` como pasta de entrada onde o usuario grava os `.xpz` exportados pela IDE
- Tratar `Temp` como destino preferencial para artefatos efemeros, temporarios de execucao, relatorios descartaveis e copias temporarias de SQLite
- Tratar `KbIntelligence` como pasta do indice SQLite derivado e regeneravel, normalmente `KbIntelligence\kb-intelligence.sqlite`, mais relatorios de validacao quando o repositorio local adotar esse fluxo
- Tratar `kb-source-metadata.md` como metadado operacional da materializacao XPZ/XML; ele deve expor `last_xpz_materialization_run_at` quando o fluxo oficial tiver processado um insumo da IDE
- Tratar qualquer memoria local de setup que diga `ainda nao materializada`, `aguardando primeiro XPZ` ou equivalente como estado provisório; depois da primeira materializacao oficial bem-sucedida, esse estado nao deve continuar sendo apresentado como atual
- Tratar `KbIntelligence\kb-intelligence.sqlite` como dono do metadado `last_index_build_run_at` na tabela `metadata`; esse horario deve ser igual ou posterior a `last_xpz_materialization_run_at` para permitir triagem ampla e geracao de objetos de importacao
- Explicar que o fluxo oficial de materializacao XPZ/XML deve chamar a regeneracao/validacao do indice derivado compulsoriamente apos atualizar `ObjetosDaKbEmXml`
- Explicar que, apos processamento bem-sucedido, um `.xpz` em `XpzExportadosPelaIDE` pode ser renomeado para `processado_<nome-original>.xpz`
- Tratar `ObjetosGeradosParaImportacaoNaKbNoGenexus` como area de trabalho para XMLs temporarios destinados a importacao manual na IDE
- Tratar `PacotesGeradosParaImportacaoNaKbNoGenexus` como area de saida para `import_file.xml` e, quando aplicavel, `XPZ`
- Por padrao, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` nao precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteudo, tratar isso como decisao de politica do repositorio e pedir aprovacao explicita
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
- Quando a pasta paralela da KB for inicializada do zero para operar com fluxo oficial de materializacao XPZ/XML, tratar a camada minima de wrappers locais em `scripts` como parte do bootstrap tecnico esperado, nao como pendencia para a etapa seguinte
- Nao declarar `setup inicial concluido`, `estrutura pronta` ou equivalente final se a pasta ainda nao tiver a camada minima de wrappers locais necessaria para materializacao oficial e, quando adotado, para `KbIntelligence`
- Se a pasta paralela ja estiver versionada em Git, tratar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte esperada do setup inicial padrao
- Se a pasta paralela ainda nao estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional de apoio; a decisao pertence ao usuario
- Nao executar `git init` por conta propria no setup inicial
- Se o usuario aceitar versionamento Git local e o ambiente nao tiver Git funcional, o agente pode oferecer instalar ou orientar a instalacao antes de prosseguir com o bootstrap Git
- Alterar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisao de politica do repositorio; o agente pode diagnosticar e propor opcoes, mas nao deve mudar essa politica automaticamente so para concluir o fechamento
- Reutilizar o fluxo oficial previsto nas skills e no motor compartilhado antes de considerar qualquer script novo
- Gerar `kb-source-metadata.md` inicial em formato compativel com o motor compartilhado, preservando desde o setup o campo nominal `last_xpz_materialization_run_at`
- Nao salvar memoria operacional fora da propria pasta paralela da KB sem autorizacao explicita do usuario; `AGENTS.md`, `README.md` e arquivos operacionais locais sao a camada preferencial de memoria do setup
- Ao concluir o setup inicial, declarar explicitamente que a pasta paralela esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
- Quando o setup inicial tiver registrado memoria local provisoria de que `ObjetosDaKbEmXml` ainda nao foi materializada, exigir refresh dessa memoria local depois da primeira materializacao oficial bem-sucedida, para evitar handoff com estado desatualizado
- Ao concluir o setup inicial, oferecer dois proximos passos:
  - `A)` o usuario exporta o `.xpz` full pela IDE do GeneXus para `XpzExportadosPelaIDE` e o agente materializa os XMLs depois
  - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
- Ao oferecer `A)` e `B)`, dizer explicitamente que `A)` e o caminho preferencial e normalmente mais rapido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
- Ao orientar o caminho `A)`, preferir descricao funcional estavel como `export full da KB pela IDE` em vez de depender de rotulos exatos de menu, tela ou botao do GeneXus como se fossem universais; se citar caminho de menu, apresentá-lo depois da instrucao principal e marcado explicitamente como exemplo opcional de navegacao, nunca como passo normativo principal
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
  - execucao do gate de frescor (`Test-*KbGate.ps1`): chama o wrapper de consulta local com `-Query index-metadata`, le `kb-source-metadata.md`, compara timestamps e retorna `GATE_OK` ou lanca `BLOCK: <motivo>`; depende de `Query-*KbIntelligence.ps1` na mesma pasta; deve ser o unico ponto de execucao do gate de frescor
  - leitura de campos chave de `kb-source-metadata.md` (`Get-*KbMetadata.ps1`): elimina o padrao recorrente de `Select-String + regex` inline nos chamadores; expoe ao menos `last_xpz_materialization_run_at`, `kb_name` e `source_guid`
  - verificacao de estrutura da pasta paralela (`Test-*KbStructure.ps1`): relatorio de presenca/ausencia de pastas, scripts e artefatos esperados; retorna `STRUCTURE_OK` ou lista componentes ausentes; usado no setup e em diagnostico antes de qualquer operacao
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
  - [Test-KbGate.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Test-KbGate.example.ps1)
  - [Get-KbMetadata.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Get-KbMetadata.example.ps1)
  - [Test-KbStructure.example.ps1](C:/Dev/Knowledge/GeneXus-XPZ-Skills/xpz-kb-parallel-setup/examples/Test-KbStructure.example.ps1)
- Esses `.example.ps1` sao exemplos metodologicos importantes para bootstrap tecnico e reconstrucao assistida dos wrappers locais finais.
- Quando os wrappers locais precisarem nascer do zero no setup inicial, preferir adaptar os exemplos sanitizados completos desta skill como base do bootstrap tecnico, em vez de improvisar wrappers curtos ou parciais que ainda exijam correcao na etapa seguinte.
- Esses `.example.ps1` nao substituem o wrapper local real da pasta paralela da KB e nao devem virar fallback automatico de execucao no fluxo normal.
- Wrapper local derivado de `.example.ps1` so conta como wrapper de bootstrap valido depois que o agente validar parse do `.ps1` e ausencia de placeholders sanitizados em valores executaveis, configuracao efetiva, caminhos padrao, parametros default ou chamadas reais.
- Exemplos em comentario ou blocos de ajuda, como `.EXAMPLE`, nao bloqueiam o bootstrap apenas por conterem caminhos ilustrativos; se forem mantidos, nao podem ser citados como evidencia de configuracao local validada.
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

## ESTADOS DE CONCLUSAO DO SETUP

Ao fechar um setup ou handoff de pasta paralela da KB, usar um estado operacional explicito, sem promover o status por inferencia:

- `estrutura_criada`: pastas e documentos basicos existem, mas wrappers locais, materializacao ou indice ainda nao foram validados.
- `bootstrap_incompleto`: a estrutura existe, mas falta camada minima de wrappers locais para o fluxo oficial adotado, ou falta compatibilidade obrigatoria com `KbIntelligence`.
- `pronto_para_primeira_materializacao`: estrutura, documentos e wrappers locais minimos foram criados ou validados, sem placeholders sanitizados pendentes em configuracao efetiva dos wrappers, mas `ObjetosDaKbEmXml` ainda nao recebeu materializacao oficial.
- `materializado_e_indice_validado`: houve materializacao oficial bem-sucedida e, quando `KbIntelligence` for adotado, o indice derivado foi regenerado/validado com `last_index_build_run_at >= last_xpz_materialization_run_at`.
- `wrappers_atualizados`: pasta ja em producao recebeu scripts ausentes previstos pela base metodologica; scripts com personalizacao foram preservados ou substituidos com aprovacao explicita do usuario; `ObjetosDaKbEmXml`, `kb-source-metadata.md` e `kb-intelligence.sqlite` intactos.

Nao usar `setup concluido`, `estrutura pronta` ou expressao equivalente sem dizer qual desses marcos ja foi efetivamente cumprido. Criar pastas vazias ou gravar memoria local inicial nao basta para declarar a pasta pronta para `sync` normal, pesquisa ampla ou geracao de objetos.

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
- Se a existencia da pasta nativa da KB foi verificada, declarar no fechamento se ela existe/acessou corretamente ou se ficou como ressalva operacional

---

## WORKFLOW

1. Confirmar se o usuario esta falando da pasta nativa da KB ou da pasta paralela da KB
2. Se o caminho da pasta nativa da KB nao vier informado, pedir esse caminho ao usuario antes de concluir o setup inicial
3. Se o caminho da pasta nativa da KB vier informado, verificar existencia/acesso quando isso for seguro e barato; se nao existir ou nao estiver acessivel, nao gravar nem tentar corrigir a pasta nativa, apenas registrar a ressalva no handoff
4. Se o usuario nao informar nomes alternativos, assumir as subpastas padrao
5. Se o usuario informar nomes alternativos, registrar o mapeamento entre nome real e funcao da pasta em `AGENTS.md` da pasta paralela da KB e, quando ajudar humanos, tambem em `README.md`
6. Registrar em `AGENTS.md` da pasta paralela o caminho confirmado da pasta nativa da KB e a regra de que essa pasta e somente leitura para agentes, com gravacao proibida
7. Quando houver `README.md` local na pasta paralela, registrar ali tambem a identificacao da pasta nativa da KB e a regra de somente leitura em linguagem clara
8. Detectar o contexto operacional da pasta paralela antes de qualquer escrita:
   - `modo_criacao`: pasta inexistente, vazia, sem `ObjetosDaKbEmXml` materializado e sem `kb-source-metadata.md` com timestamps reais → criar primeiro a estrutura base e so aprofundar exploracao se surgir bloqueio concreto; prosseguir para o passo 9
   - `modo_atualizacao`: pasta com historico real — qualquer combinacao de `ObjetosDaKbEmXml` materializado, `kb-source-metadata.md` com timestamps reais ou `kb-intelligence.sqlite` com dados → executar o BLOCO DE ATUALIZACAO a seguir antes de prosseguir para o passo 9
   - Se o usuario usou linguagem ambigua como "refazer", "reiniciar", "recriar" ou equivalente e a pasta tem sinais de historico real: parar, nao assumir modo, e clarificar com o usuario apresentando as duas opcoes e suas consequencias:
     - Opcao 1 — atualizar (modo_atualizacao): incorporar scripts novos, preservar tudo que ja existe
     - Opcao 2 — recriar do zero (modo_criacao): estrutura e dados existentes sao descartados
   - Aguardar escolha explicita antes de prosseguir
--- BLOCO DE ATUALIZACAO (executar somente em modo_atualizacao) ---

8.a Inspecionar `scripts/` e categorizar cada script previsto pela base metodologica em uma de tres classes:
    - AUSENTE: script previsto que ainda nao existe localmente
    - EQUIVALENTE: script que existe e cuja logica e equivalente ao exemplo correspondente; diferencas apenas de nome KB (ex: `FabricaBrasil` no lugar do nome generico) sao toleradas e nao constituem divergencia
    - CUSTOMIZADO: script que existe com diferencas de logica, parametros adicionais, fluxo alterado ou qualquer mudanca alem da substituicao de nome KB

8.b Para cada script AUSENTE: preparar criacao a partir do exemplo correspondente; apresentar ao usuario o script que sera criado e aguardar aprovacao explicita antes de gravar

8.c Para cada script CUSTOMIZADO: evidenciar objetivamente a divergencia (quais secoes diferem, quais parametros foram adicionados, qual logica foi alterada) e apresentar ao usuario quatro opcoes claras; aguardar decisao explicita antes de qualquer escrita:
    - A) Manter versao local intacta — script customizado fica como esta; nenhuma escrita
    - B) Substituir pelo exemplo atual — personalizacao local e descartada; script volta ao estado canonico
    - C) Revisar e incorporar seletivamente — usuario decide o que do exemplo incorporar; agente aplica apenas o que o usuario confirmar explicitamente
    - D) Pular este script por agora — nenhuma escrita; continuar com os demais scripts da lista

8.d Nao tocar `kb-source-metadata.md` em modo_atualizacao; o arquivo contem timestamps operacionais reais que o gate de frescor depende e nao devem ser sobrescritos pelo agente

8.e Para `.claude\settings.json` existente: ler entradas presentes e inserir apenas os padroes que ainda nao constarem; nao remover nem sobrescrever entradas ja existentes

8.f Ao concluir o bloco de atualizacao, declarar o estado `wrappers_atualizados` e listar explicitamente: scripts adicionados, scripts mantidos (EQUIVALENTES), scripts substituidos com aprovacao e scripts pulados

--- FIM DO BLOCO DE ATUALIZACAO ---

9. Validar a existencia da estrutura nesta ordem:
   - `scripts`
   - `Temp`
   - `XpzExportadosPelaIDE`
   - `ObjetosDaKbEmXml`
   - `KbIntelligence`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus`
10. Se a pasta paralela ja estiver versionada em Git, criar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte do bootstrap padrao
11. Se a pasta paralela ainda nao estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local; nao executar `git init` sem aprovacao explicita do usuario
12. Se o usuario aceitar versionamento Git local e o Git nao estiver funcional no ambiente, oferecer instalar ou orientar a instalacao antes do bootstrap Git
13. Se `kb-source-metadata.md` ainda nao existir, criar com o campo nominal `last_xpz_materialization_run_at`, sem inventar formato paralelo desconectado do motor compartilhado; se ja existir, nao tocar — o arquivo contem timestamps operacionais reais que o gate de frescor depende
14. Nao salvar memoria externa do agente fora da pasta paralela da KB sem autorizacao explicita do usuario
15. Explicar o papel de cada pasta:
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
16. Se `ObjetosDaKbEmXml` ainda nao existir, tratar o acervo como ainda nao materializado
17. Se `ObjetosGeradosParaImportacaoNaKbNoGenexus` nao estiver organizado por frentes em subpastas `NomeCurto_GUID_YYYYMMDD`, tratar isso como desvio operacional e orientar correcao
18. Se `XpzExportadosPelaIDE` estiver ausente e o fluxo depender de `XPZ`, pedir ao usuario o caminho pretendido ou criar a pasta padrao quando a politica do repositorio permitir
19. Se a pasta `scripts` existir sem wrappers locais minimos, orientar a reconstruir:
   - wrapper de atualizacao diaria sobre o motor compartilhado
   - wrapper de conferencia full reaproveitando o wrapper diario
   - wrapper de consulta do indice derivado, se a KB local adotar `KbIntelligence`
   - wrapper de regeneracao e validacao do indice derivado, se a KB local adotar `KbIntelligence`
   - `Test-*KbGate.ps1`, se a KB local adotar `KbIntelligence`
   - `Get-*KbMetadata.ps1`, se a KB local adotar `KbIntelligence`
   - `Test-*KbStructure.ps1`, se a KB local adotar `KbIntelligence`
   - helper local opcional de notificacao, se houver necessidade operacional
20. Se os scripts `Test-*KbGate.ps1`, `Get-*KbMetadata.ps1` e `Test-*KbStructure.ps1` forem criados ou confirmados durante o setup ou atualizacao, registrar os padroes de allowlist correspondentes em `.claude\settings.json` da pasta paralela da KB:
   - Para cada script, adicionar uma entrada no array `permissions.allow` no formato `PowerShell(& "<caminho-absoluto-do-script>" *)`
   - Usar o nome real do script no caminho (ex: `Test-FabricaBrasilKbGate.ps1`), nao o nome sanitizado do exemplo
   - Se `.claude\settings.json` ainda nao existir, criar com estrutura minima
   - Se `.claude\settings.json` ja existir, ler o conteudo atual, verificar quais padroes ja estao presentes e inserir apenas os ausentes; nao remover nem sobrescrever entradas ja existentes
   - Tratar essa etapa como parte do bootstrap ou da atualizacao, nao como pendencia manual posterior; o agente deve executar isso antes de declarar o estado de conclusao
21. Se `KbIntelligence` estiver ausente, orientar sua criacao como pasta de artefatos derivados antes de instalar wrappers de indice
22. Se `ObjetosDaKbEmXml` ainda nao contiver snapshot materializado, nao tentar gerar `kb-intelligence.sqlite`; preparar apenas a pasta e os wrappers locais
23. Se a pasta adotar `KbIntelligence`, validar o gate de compatibilidade operacional antes de permitir pesquisa ampla, triagem substantiva ou geracao de objetos
24. Se o gate falhar, oferecer atualizacao da pasta paralela/wrappers/indice e nao responder a pergunta de negocio por fallback manual
25. Antes de declarar o setup como concluido, validar se a camada minima de wrappers locais esperados em `scripts` ja existe para o fluxo oficial adotado por essa pasta paralela
26. Quando os wrappers locais forem derivados dos `.example.ps1`, validar que eles nao mantem placeholders sanitizados em configuracao efetiva antes de classifica-los como wrappers minimos existentes
27. Se a estrutura de pastas e documentos estiver pronta, mas a camada minima de wrappers locais ainda nao existir ou ainda mantiver placeholders sanitizados em configuracao efetiva, reportar isso como `estrutura parcial` ou `bootstrap incompleto`, nao como setup concluido
28. Ao concluir o setup inicial, deixar explicito que a estrutura esta pronta, mas `ObjetosDaKbEmXml` ainda nao foi materializada
29. Se a primeira materializacao oficial ocorrer depois do setup, atualizar ou neutralizar a memoria local provisoria criada no setup que ainda afirme `ObjetosDaKbEmXml` nao materializada, `aguardando primeiro XPZ` ou equivalente
30. Ao concluir o setup inicial, oferecer os proximos passos:
   - `A)` o usuario exporta o `.xpz` full pela IDE para `XpzExportadosPelaIDE`, e o agente materializa os XMLs depois
   - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
31. Ao oferecer `A)` e `B)`, declarar que `A)` e o caminho preferencial e normalmente mais rapido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
32. Se o usuario escolher `B)`, usar a skill `xpz-msbuild-import-export` e nao improvisar fluxo alternativo de exportacao

---

## EXEMPLO CURTO DE ESTRUTURA MATERIALIZADA

```text
PastaParalelaDaKb/
  scripts/
    Update-KbFromXpz.ps1
    Test-KbFullSnapshot.ps1
    Query-KbIntelligence.ps1
    Update-KbIntelligenceIndex.ps1
    Test-KbGate.ps1
    Get-KbMetadata.ps1
    Test-KbStructure.ps1
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
- NUNCA sobrescrever script existente em `scripts/` sem antes comparar com o exemplo correspondente, evidenciar objetivamente a divergencia ao usuario e obter aprovacao explicita para substituicao
- NUNCA gravar em `kb-source-metadata.md` se o arquivo ja existir com timestamps reais; apos a primeira materializacao oficial esse arquivo e somente leitura para o agente
- NUNCA classificar uma pasta como `bootstrap_incompleto` por ausencia de um script novo quando os scripts existentes ja funcionam e a pasta tem historico de uso real; a ausencia de script novo e caso de `modo_atualizacao`, nao de bootstrap incompleto
- NUNCA assumir `modo_criacao` em pasta com historico real apenas porque o usuario usou "refazer", "reiniciar", "recriar" ou expressao similar sem declarar explicitamente que quer destruir e recriar do zero; clarificar a intencao antes de qualquer acao
