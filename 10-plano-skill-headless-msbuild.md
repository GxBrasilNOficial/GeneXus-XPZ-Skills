# Plano Provisório - Skill Experimental De Importação/Exportação Headless Via MSBuild

## Status

Documento provisório de planejamento.

Já existe um `SKILL.md` contratual materializado em `xpz-msbuild-import-export/SKILL.md`, ainda em status experimental e sem implementação dos futuros `.ps1`.

Este plano ainda não define a implementação final da skill, não altera o comportamento das skills `xpz-*` existentes e não oficializa uma nova trilha operacional.

## Objetivo

Registrar as diretrizes iniciais para uma futura skill experimental dedicada à chamada efetiva de importação e exportação de `XPZ` do GeneXus por automação headless baseada em `MSBuild`, sem depender da operação manual pela IDE.

## Escopo Pretendido

- validar um caminho operacional real para abrir a `Knowledge Base`
- validar seleção de versão e `Environment`
- validar exportação headless de `XPZ`
- validar importação headless de `XPZ`
- registrar evidências operacionais, logs, códigos de saída e limitações

## Fora De Escopo Nesta Fase

- alterar qualquer uma das skills `xpz-*` atuais
- promover a futura skill a dependência das demais
- substituir o fluxo oficial atual da trilha paralela da KB
- depender de GeneXus Server como requisito operacional da futura skill
- prometer sucesso funcional de importação, build, reorg ou consistência sem validação externa
- implementar agora `.ps1` ou integração com as skills existentes

## Princípios De Segurança

- tratar a futura skill como experimental até haver evidência suficiente
- não inferir automaticamente caminhos, versão ativa, `Environment` ou comportamento da KB
- exigir parametrização explícita para cada operação relevante
- separar sucesso operacional da chamada de `MSBuild` de sucesso funcional dentro do GeneXus
- registrar logs e artefatos de forma rastreável
- manter possibilidade clara de aborto antes de operações sensíveis, em especial importação real

### Riscos Operacionais Descobertos

- `ImportKBInformation` está documentado como capaz de importar propriedades de `KB`, `Version` e `Environment`, com default documentado `true`
- `AllowCreateParentObjects` e `AllowCreateModuleObject` aparecem nas definições internas de importação como possibilidades de criação implícita
- a futura skill não deve assumir que defaults internos do GeneXus são seguros para esta frente; parâmetros sensíveis devem ser tratados explicitamente
- a instalação do host `MSBuild` sugere rastros laterais de log e trace, o que reforça a necessidade de controlar diretório de trabalho, captura de saída e destino dos logs
- a futura skill deve tratar qualquer efeito colateral fora dos artefatos esperados como risco operacional relevante, mesmo quando a chamada principal reportar sucesso

## Restrição Operacional De Leitura

Para esta frente de trabalho, a árvore `C:\Program Files (x86)` deve ser tratada pelo agente como estritamente somente leitura.

Isso inclui explicitamente `C:\Program Files (x86)\GeneXus\GeneXus18` e qualquer subpasta dessa instalação oficial.

Regras aplicáveis:

- leitura técnica é permitida quando útil à frente
- é proibido incluir arquivos nessa árvore
- é proibido alterar arquivos nessa árvore
- é proibido excluir arquivos nessa árvore
- é proibido sobrescrever arquivos nessa árvore
- é proibido gerar temporários, logs, cache, saídas intermediárias ou qualquer outra gravação nessa árvore

## Camadas De Validação

### 1. Descoberta De Ambiente

- localizar instalação do GeneXus
- localizar `MSBuild`
- validar existência dos arquivos `Genexus.Tasks.targets` e equivalentes necessários
- validar caminhos de KB informados

### 2. Acesso À KB

- abrir a `Knowledge Base`
- validar seleção de versão
- validar seleção de `Environment`

### 2A. Capacidades Oficiais Úteis Para Validação

- usar `GetActiveVersion` para confirmar a versão ativa antes de operar
- usar `GetActiveEnvironment` para confirmar o `Environment` ativo antes de operar
- usar `CaptureOutput` quando útil para processar programaticamente a saída das tasks
- privilegiar `PreviewMode` em importação quando o objetivo for inspeção e não alteração real
- considerar `UpdateFile` como artefato útil para análise de impacto antes de importação efetiva
- considerar `IncludeItems` e `ExcludeItems` como mecanismos de recorte fino para cenários controlados

### 3. Operações Headless

- exportar `XPZ` simples
- importar `XPZ` simples em ambiente controlado

### 4. Resultado Operacional

- código de saída
- log gerado
- artefato esperado produzido ou consumido

### 5. Resultado Funcional

- confirmação posterior em ambiente de teste controlado
- sem extrapolar sucesso operacional para sucesso funcional global

## Estratégia Inicial De Testes

- começar por cenários de menor risco
- teste 1: abrir a KB com captura de saída e validar sucesso operacional mínimo
- teste 2: ler versão ativa e `Environment` ativo antes de qualquer operação sensível
- teste 3: validar `PreviewMode` de importação com pacote simples e controlado
- teste 4: gerar `UpdateFile` para inspecionar impacto esperado antes de importação efetiva
- teste 5: validar exportação simples com parâmetros explícitos e artefato conferível
- teste 6: só depois validar importação simples real em ambiente controlado
- teste 7: reabrir a KB na IDE após os testes para observar warning, marca de versão ou outro efeito colateral
- deixar cenários mais complexos para fases posteriores

## Definição De Ambiente Controlado

Para esta frente, "ambiente controlado" não significa apenas uma KB disponível. Significa um contexto em que o risco está limitado, a observação posterior é viável e a reversão operacional não depende de improviso.

Condições mínimas:

- KB de teste explicitamente destinada a experimentos desta frente, e não KB de trabalho cotidiano sem isolamento
- conhecimento explícito de qual versão e qual `Environment` devem estar ativos antes do teste
- pacote `XPZ` simples, conhecido e de baixo impacto para os primeiros experimentos
- possibilidade real de reabrir a KB na IDE oficial logo após o teste
- possibilidade de comparar o estado antes e depois, nem que seja por observação dirigida e logs
- ausência de dependência de `GeneXus Server` para viabilizar o fluxo
- diretório de trabalho e destino dos artefatos de teste definidos fora de `C:\Program Files (x86)`

Condições desejáveis:

- KB descartável, cópia de laboratório ou cenário que aceite repetição
- objeto de teste com escopo reduzido e facilmente verificável
- possibilidade de repetir o mesmo teste mais de uma vez
- trilha clara de logs e artefatos produzidos

Condições que descaracterizam ambiente controlado:

- KB de produção
- KB de homologação compartilhada sem janela clara para experimento
- dúvida sobre versão ativa ou `Environment` ativo
- pacote `XPZ` grande ou mal compreendido como primeiro caso de teste
- impossibilidade de reabrir rapidamente na IDE para inspeção
- ausência de clareza sobre onde a execução pode gerar arquivos auxiliares ou logs

## Protocolo De Testes Por Fase

### Teste 1. Abrir KB Com Captura De Saída

- pré-condições:
  - caminho da KB informado explicitamente
  - instalação do GeneXus localizada
  - `MSBuild` localizado
  - `Genexus.Tasks.targets` validado
- ação prevista:
  - abrir a KB por `OpenKnowledgeBase`
  - habilitar `CaptureOutput`
- evidência a coletar:
  - `exitCode`
  - saída capturada da task
  - log principal da execução
- critério de aprovação:
  - KB abre sem erro operacional
  - saída capturada indica sucesso coerente com a abertura
- critério de aborto:
  - falha de host
  - falha de autenticação
  - falha de abertura da KB

### Teste 2. Ler Versão E Environment Ativos

- pré-condições:
  - teste 1 aprovado
- ação prevista:
  - consultar `GetActiveVersion`
  - consultar `GetActiveEnvironment`
- evidência a coletar:
  - nomes retornados
  - saída capturada
  - consistência com o que o usuário esperava para o ambiente de teste
- critério de aprovação:
  - valores retornados são legíveis e coerentes
- critério de aborto:
  - task retorna vazio inesperado
  - task falha
  - contexto ativo diverge de forma insegura do esperado

### Teste 3. Preview De Importação

- pré-condições:
  - testes 1 e 2 aprovados
  - `XPZ` de teste simples disponível
- ação prevista:
  - executar `Import` com `PreviewMode`
  - evitar importação real
- evidência a coletar:
  - lista de itens candidatos
  - mensagens, warnings e erros reportados
  - artefatos auxiliares produzidos, se houver
- critério de aprovação:
  - preview executa sem alterar a KB
  - resultado permite entender o que seria importado
- critério de aborto:
  - tentativa de alteração real fora do esperado
  - erros estruturais graves no pacote

### Teste 4. Gerar UpdateFile

- pré-condições:
  - teste 3 aprovado
- ação prevista:
  - executar fluxo que produza `UpdateFile`
- evidência a coletar:
  - caminho do `UpdateFile`
  - existência física do arquivo
  - conteúdo suficiente para análise de impacto
- critério de aprovação:
  - `UpdateFile` é gerado e pode ser inspecionado
- critério de aborto:
  - arquivo não é gerado
  - arquivo é gerado em local inadequado
  - conteúdo não ajuda a discriminar impacto

### Teste 5. Exportação Simples

- pré-condições:
  - testes 1 e 2 aprovados
  - objeto simples escolhido explicitamente
- ação prevista:
  - executar `Export` com parâmetros explícitos
- evidência a coletar:
  - `XPZ` gerado
  - tamanho do arquivo
  - log da execução
  - parâmetros usados
- critério de aprovação:
  - arquivo `XPZ` é gerado de forma conferível
  - execução fecha sem erro operacional
- critério de aborto:
  - arquivo ausente
  - erro operacional
  - exportação com escopo inesperado

### Teste 6. Importação Simples Real

- pré-condições:
  - testes 1 a 5 aprovados
  - ambiente controlado explicitamente confirmado para teste real
- ação prevista:
  - executar `Import` real em pacote simples
- evidência a coletar:
  - `exitCode`
  - log
  - mensagens, warnings e erros
  - evidência mínima de efeito observado depois
- critério de aprovação:
  - importação conclui com sucesso operacional
  - efeito esperado mínimo pode ser conferido
- critério de aborto:
  - warnings ou erros que indiquem risco alto
  - sinais de alteração fora do escopo previsto
  - qualquer comportamento inesperado na KB

### Teste 7. Reabertura Na IDE

- pré-condições:
  - pelo menos um teste operacional relevante executado
- ação prevista:
  - reabrir a KB na IDE oficial
  - observar warnings, marcas de versão e comportamento geral
- evidência a coletar:
  - relato do comportamento observado
  - warning ou ausência de warning
  - qualquer indício de efeito colateral de host
- critério de aprovação:
  - KB reabre normalmente
  - não há warning novo relevante
- critério de aborto:
  - warning novo relevante
  - comportamento anômalo após a execução headless

## Critério Para Confiar Na Futura Skill

A futura skill só poderá deixar o status experimental quando houver evidência mínima repetível, com registro de:

- pré-requisitos validados
- chamadas executadas com sucesso operacional
- logs consistentes
- artefatos gerados conforme esperado
- limitações conhecidas documentadas
- pelo menos um conjunto de testes controlados de importação e exportação analisado com calma

## Regra De Publicação

Antes de ler a nova fonte adicional mencionada pelo usuário, este documento serve apenas como plano base.

Nenhuma implementação deve ser promovida para menções nas skills atuais antes de:

- consolidar este processo seguro
- ler a nova fonte
- revisar o plano à luz dessa fonte
- validar empiricamente a trilha proposta

## Seção Reservada Para A Nova Fonte

Quando a nova fonte for apresentada, ela deverá ser incorporada aqui como insumo de revisão do plano, e não como atalho para pular a etapa de validação.

## Síntese Da Fonte Lida Em `C:\Dev\Fork\FBgx18MCP`

A leitura filtrada do repositório `C:\Dev\Fork\FBgx18MCP`, ignorando a arquitetura de `MCP` como solução-alvo desta frente, reforçou o seguinte:

- o caminho mais seguro para automação operacional do GeneXus não é hospedar o SDK em executável arbitrário como base principal
- `MSBuild` aparece como host suportado e pragmaticamente mais estável para operações sobre a `Knowledge Base`
- a estratégia prática observada é:
  - localizar `MSBuild.exe`
  - gerar arquivo `.msbuild` temporário por execução
  - importar `Genexus.Tasks.targets`
  - abrir a `Knowledge Base`
  - executar a task desejada
  - fechar a `Knowledge Base`
  - capturar `stdout`, `stderr` e `exitCode`
- a fonte lida reforça a necessidade de separar:
  - sucesso operacional da chamada
  - sucesso funcional observado depois no GeneXus
- a leitura integral também sugere um risco adicional de contexto de execução:
  - um host inadequado pode deixar efeitos colaterais de versão ou instalação percebida pela KB
  - isso pode aparecer depois como warning ou comportamento incômodo ao reabrir a KB na IDE
- a fonte lida não entregou, até este ponto, um fluxo pronto e validado de `ExportXPZ` e `ImportXPZ`
- o valor principal da fonte, portanto, está na validação da arquitetura de execução e não em uma receita final já concluída para `XPZ`

## Refinamento Do Plano A Partir Da Nova Fonte

Com base nessa leitura, este plano passa a assumir explicitamente que:

- a futura skill experimental deve ter como fundamento principal `PowerShell` orquestrando `MSBuild`
- a futura skill não deve depender, como base metodológica principal, de carregar o SDK do GeneXus em host arbitrário
- a futura skill deve tratar projeto temporário `.msbuild`, parâmetros explícitos, captura de saída e validação de artefatos como elementos centrais do fluxo
- a futura skill deve continuar separada das skills `xpz-*` atuais até validação empírica suficiente

## Aprendizados Metodológicos Da Evolução Recente De `FBgx18MCP`

Uma leitura adicional dos commits mais recentes de `FBgx18MCP` não trouxe evidência nova direta sobre `MSBuild` para `XPZ`, mas trouxe padrões metodológicos reaproveitáveis para esta frente:

- distinguir claramente alteração apenas encenada em memória de alteração efetivamente persistida e verificada
- não confiar apenas no sucesso nominal da operação; fazer leitura posterior do estado persistido
- admitir retries curtos de verificação quando o GeneXus puder refletir mudanças com atraso
- tratar fallback de persistência como evento explícito de diagnóstico, e não como detalhe silencioso
- invalidar ou desconsiderar cache de leitura antes da etapa de verificação posterior
- devolver erros estruturados por categoria, em vez de concentrar tudo em uma mensagem genérica de falha
- exigir coerência entre a chamada executada, o artefato gerado e o efeito observável depois

Consequências para esta frente:

- a futura skill de `XPZ` headless deve distinguir "execução concluída" de "efeito confirmado"
- `exitCode` isolado não deve ser tratado como evidência suficiente de sucesso funcional
- a fase de verificação deve reler artefatos e estado observável em vez de depender de memória de execução
- quando houver comportamento tardio ou ambíguo, a estratégia preferida deve ser retry curto com leitura posterior, e não inferência otimista

## Restrição De Escopo Sobre GeneXus Server

O público-alvo destas skills de `XPZ` não dispõe de `GeneXus Server`, portanto a futura skill desta frente não deve assumir `GeneXus Server` como componente disponível nem como trilha operacional pretendida.

Regras aplicáveis:

- `Genexus.Server.Tasks.targets` não é base operacional da futura skill
- tasks de `GeneXus Server` não devem virar pré-requisito de uso
- referências a `GeneXus Server` podem ser aproveitadas apenas como aprendizado indireto sobre convenções, mensagens, padrões de `MSBuild` ou comportamento de importação/exportação
- quando houver alternativa entre trilha local e trilha dependente de `GeneXus Server`, a trilha local deve prevalecer

## Evidências Da Instalação Oficial Do GeneXus 18

A leitura da instalação oficial em `C:\Program Files (x86)\GeneXus\GeneXus18`, em modo estritamente somente leitura, confirmou evidências diretas relevantes para esta frente:

- `Genexus.Tasks.targets` expõe oficialmente as tasks:
  - `OpenKnowledgeBase`
  - `CloseKnowledgeBase`
  - `Export`
  - `Import`
  - `SetActiveVersion`
  - `SetActiveEnvironment`
- essas tasks são carregadas com `Architecture="x86"`
- a instalação inclui exemplos reais de `.msbuild` usando esse modelo, como:
  - `Genexus.msbuild`
  - `CompressKB.msbuild`
  - `GXtest.msbuild`
- a documentação offline instalada confirma a superfície suportada:
  - `3908.html`: índice de `MSBuild Tasks`, incluindo `Export`, `SetActiveVersion` e `SetActiveEnvironment`
  - `35599.html`: `Import MSBuild Task`
  - `35862.html`: `OpenKnowledgeBase MSBuild Task`
  - `35636.html`: sintaxe de lista de itens para `IncludeItems` e `ExcludeItems`
  - `1922.html`: definição de `XPZ`

## Parâmetros Oficiais Confirmados Na Instalação

Com base na documentação offline da instalação oficial, ficam confirmados para esta frente:

- `Export`
  - `File`
  - `Objects`
  - `DependencyType`
  - `ReferenceType`
  - `IncludeGXMessages`
  - `IncludeUntranslatedMessages`
  - `OnlyStructuresForTransactions`
  - `ExportKBInfo`
  - `ExportAll`
- `Import`
  - `File`
  - `AutomaticBackup`
  - `ImportType`
  - `LanguageTranslations`
  - `RedefineExternalPrograms`
  - `ImportKBInformation`
  - `IncludeItems`
  - `ExcludeItems`
  - `PreviewMode`
  - `UpdateFile`
- `OpenKnowledgeBase`
  - `Directory`
  - `MDFPath`
  - `TargetModelId`
  - `DatabaseUser`
  - `DatabasePassword`
  - `CaptureOutput`
- `SetActiveVersion`
  - `VersionName`
- `SetActiveEnvironment`
  - `EnvironmentName`

## Pontos Abertos Que Exigem Experimento Controlado

- não assumir sem teste a relação exata entre `ExportKBInfo` documentado e `ExportKBProperties` exposto na definição interna
- não assumir que os defaults internos de importação e exportação são adequados para esta frente sem validação prática
- verificar em ambiente controlado o efeito real de `ImportKBInformation` sobre propriedades de `KB`, `Version` e `Environment`
- verificar se `PreviewMode` e `UpdateFile` entregam evidência suficiente para uma fase segura de inspeção antes de importação real
- verificar se a execução via `MSBuild` deixa rastros laterais relevantes no diretório de trabalho ou em arquivos de log associados ao host
- verificar se a KB continua abrindo normalmente na IDE após operações headless, sem warning ou marcas indesejadas de host

## Checklist Inicial De Requisitos Da Futura Skill

- usar `MSBuild` como host principal da execução operacional
- gerar arquivo `.msbuild` temporário por execução
- localizar `MSBuild.exe` por estratégia explícita de fallback e registrar qual caminho foi usado
- validar a existência da instalação do GeneXus e de `Genexus.Tasks.targets`
- validar previamente o caminho da `Knowledge Base`
- separar claramente as operações de:
  - abrir KB
  - selecionar versão
  - selecionar `Environment`
  - exportar `XPZ`
  - importar `XPZ`
  - fechar KB
- tratar importação real como operação sensível e nunca implícita
- capturar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` gerado e caminho do log
- distinguir no resultado:
  - sucesso operacional da chamada
  - sucesso funcional posterior no GeneXus
- incluir verificação pós-teste de reabertura da KB na IDE para detectar warning, marca de versão ou efeito colateral de host
- evitar placeholders esquecidos, caminhos hardcoded como regra e valores presumidos silenciosamente
- começar os testes por descoberta de ambiente e abertura da KB
- validar exportação simples antes de validar importação simples
- manter a skill em status experimental até haver evidência repetível suficiente

## Interface Proposta Dos Futuros Scripts `.ps1`

Nesta fase, a proposta é evitar um script monolítico e trabalhar com operações pequenas, explicitamente parametrizadas.

Scripts propostos:

- `Test-GeneXusMsBuildSetup.ps1`
  - objetivo: validar host, instalação, paths e pré-requisitos sem alterar a KB
- `Open-GeneXusKbHeadless.ps1`
  - objetivo: abrir KB, posicionar versão e `Environment`, capturar saída e confirmar contexto ativo
- `Test-GeneXusXpzImportPreview.ps1`
  - objetivo: executar preview de importação e, quando aplicável, gerar `UpdateFile`
- `Invoke-GeneXusXpzExport.ps1`
  - objetivo: exportar `XPZ` com parâmetros explícitos
- `Invoke-GeneXusXpzImport.ps1`
  - objetivo: executar importação real apenas em fase já autorizada de teste controlado

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

Saídas esperadas dos scripts:

- código de saída confiável
- resumo objetivo da operação
- caminho do log gerado
- caminho do `.msbuild` temporário gerado
- artefatos produzidos, quando houver
- indicação explícita de:
  - sucesso operacional
  - falha operacional
  - operação apenas em preview
  - operação concluída, porém ainda pendente de confirmação funcional

Restrições de desenho:

- não gravar nada em `C:\Program Files (x86)`
- não depender de valores hardcoded como regra
- não inferir silenciosamente versão, `Environment` ou pacote
- não esconder fallback, retry ou mudança de estratégia durante a execução
- não tratar importação real como comportamento padrão

## Próximo Marco Esperado

Revisar este plano após leitura da nova fonte e, só então, detalhar:

- critérios de entrada e saída por fase
- formato do futuro `SKILL.md`
- formato e escopo dos futuros scripts `.ps1`
- protocolo de testes
- critérios de promoção futura
