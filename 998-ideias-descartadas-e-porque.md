# Ideias Descartadas — e Por Quê

Registro de tasks, funcionalidades ou abordagens que foram avaliadas e descartadas
explicitamente, com o motivo documentado para evitar reavaliação desnecessária no futuro.

---

## BulkCopyKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild que gera um arquivo no formato BCP (SQL Server Bulk Copy) com
os dados da KB. O GeneXus Server usa esse formato para transferir KBs entre instâncias.

**Por que foi descartada:**

O público-alvo desta skill não dispõe de GeneXus Server. O arquivo gerado por
`BulkCopyKnowledgeBase` é projetado para ser consumido pelo GeneXus Server no destino.
Sem ele, o caminho de restauração headless não está validado e provavelmente não é
trivial — exigiria conhecimento do esquema interno da KB do GeneXus, que não é
documentado publicamente.

Para o problema concreto que a task pretendia resolver (snapshot de segurança antes de
importação arriscada), alternativas mais simples já estão disponíveis sem implementação
adicional: cópia da pasta da KB (LocalDB) ou backup `.bak` via SQL Server (rede).

**Não reavaliar salvo** evidência de que o formato BCP pode ser restaurado sem GeneXus
Server por caminho documentado e testado.

---

## UpdateWorkingModel

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild sem parâmetros que sincroniza o working model com o design
model. A documentação oficial avisa: uma vez executada, o GeneXus "esquece" todas as
alterações de design feitas; se essas alterações exigiam mudança no banco de dados,
elas não serão aplicadas.

**Por que foi descartada:**

Utilidade baixa demais para justificar implementação como script headless. Quando o
usuário precisa executar essa operação, a IDE do GeneXus já a expõe diretamente, com
feedback visual imediato. Embrulhar isso em wrapper MSBuild não adiciona valor prático
e ainda consumiria tokens em documentação e manutenção.

O risco documentado existe, mas o motivo principal do descarte é pragmático: a IDE
resolve sem custo de implementação nesta skill.

**Não reavaliar** — não há caso de uso em automação headless de XPZ que justifique
retomar.

---

## CreateKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild oficial para criar KBs programaticamente, com parâmetros de
template, banco de dados e credenciais.

**Por que foi descartada:**

A IDE do GeneXus cria KBs sem dificuldade. Quando uma KB de teste é necessária, criar
pela IDE uma vez é barato e sem risco. Implementar um wrapper headless traria
complexidade de configuração SQL Server/LocalDB por ganho marginal.

**Não reavaliar** salvo surgimento de caso concreto em que criação de KB por script
seja requisito de automação, não apenas conveniência.

---

## ConvertKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task registrada na DLL do GeneXus MSBuild, ausente da documentação oficial.
Parâmetros e comportamento desconhecidos. Provavelmente converte KBs de versões
anteriores para a versão atual.

**Por que foi descartada:**

Quando uma KB precisa de conversão, a IDE do GeneXus conduz o processo com feedback
visual. Fazer isso headless traria risco de comportamento imprevisível em task sem
documentação oficial, por ganho marginal frente à alternativa simples de abrir pela IDE.

**Não reavaliar** salvo surgimento de caso concreto em que a conversão headless seja
requisito de automação e a task seja documentada oficialmente.

---

## Delay de estabilização pós-abertura da KB

**Origem:** avaliação feita durante construção da skill `xpz-msbuild-import-export`.

**O que era:** parâmetro de espera configurável entre `OpenKnowledgeBase` e a operação
seguinte, com a hipótese de que KBs grandes poderiam estar em estado transiente logo
após a abertura.

**Por que foi descartada:**

`OpenKnowledgeBase` não é chamado pelo PowerShell diretamente — é uma task dentro do
arquivo `.msbuild` gerado dinamicamente, rodando no mesmo processo MSBuild,
sequencialmente encadeada com a operação seguinte. Um `Start-Sleep` no PowerShell antes
de invocar o MSBuild atuaria na camada errada: o processo ainda não teria sido iniciado
e a KB ainda não teria sido aberta. O motor do MSBuild já garante a sequência
`OpenKnowledgeBase → operação → CloseKnowledgeBase` de forma síncrona e interna.

O cenário de KB grande e execução longa está coberto pela regra empírica de timeout do
invocador. Um parâmetro configurável de timeout no `Start-Process` seria
conceitualmente mais correto que um delay pré-chamada, mas não foi implementado por
ausência de caso concreto que o justifique.

**Não reavaliar** — a arquitetura MSBuild torna o delay pré-chamada estruturalmente
ineficaz.

---

## ExportAtTimestamp (parâmetro de Export)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** propriedade pública `ExportAtTimestamp` do tipo `System.DateTime` confirmada
por reflexão do assembly na task `Genexus.MsBuild.Tasks.Export`. Equivalente headless
ao filtro visual "Modified = After Date/time" da IDE.

**Por que foi descartado:**

Testado com dois formatos de data em chamadas headless:

- `ExportAtTimestamp="2026-03-24T23:59:00"` — aceito pelo MSBuild, KB abriu, mas a
  task `Export` falhou internamente com `Referência de objeto não definida para uma
  instância de um objeto` (NullReferenceException).
- `ExportAtTimestamp="24/03/2026 23:59:00"` — rejeitado pelo MSBuild como valor inválido
  para `System.DateTime`.
- Testado também combinado com `Objects` explícito — mesma falha.

Conclusão: filtro por data não é funcional via MSBuild headless nesta instalação.
O caminho validado para exportação parcial é fornecer a lista de objetos explicitamente
em `Objects`/`ObjectList`.

**Não reavaliar** salvo evidência de que o comportamento mudou em versão posterior do
GeneXus 18 ou que existe sintaxe de data alternativa não testada.

---

## UpdateFile (parâmetro de Import)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** parâmetro documentado oficialmente na task `Import` (`35599.html`). Gera um
arquivo de relatório descrevendo o que seria alterado na KB antes da importação real.

**Por que foi descartado:**

A reflexão do assembly `Genexus.MsBuild.Tasks.dll` nesta instalação mostrou que a task
`Genexus.MsBuild.Tasks.Import` não expõe `UpdateFile` como propriedade pública
configurável. O parâmetro existe na documentação offline mas não está acessível via
MSBuild headless na versão instalada.

**Não reavaliar** salvo confirmação empírica de que uma atualização do GeneXus 18 passou
a expor `UpdateFile` como propriedade pública da task carregada.

---

## ImportKBInformation (parâmetro de Import)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** parâmetro documentado oficialmente na task `Import`. Controla se propriedades
da KB, Version e Environment são importadas junto com os objetos do XPZ. Default
documentado: `true` — o que o torna potencialmente perigoso se não explicitado.

**Por que foi descartado:**

Mesma situação que `UpdateFile`: a reflexão do assembly nesta instalação mostrou que
`ImportKBInformation` não está exposto como propriedade pública da task carregada.
Parâmetro documentado mas inacessível via MSBuild headless na versão instalada.

**Não reavaliar** salvo confirmação empírica de exposição em versão posterior.

---

## ImportCSSOnTheme

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que importa um arquivo CSS para dentro de um objeto Tema existente na
KB. Parâmetros funcionais: `CSSFilePath` (obrigatório), `ObjectName` (obrigatório).

**Por que foi descartada:**

Cenário de uso restrito a customização visual de temas — situação rara no contexto da
skill XPZ, que trata de migração e sincronização de objetos GeneXus. Quando necessário,
a IDE do GeneXus executa essa operação com feedback visual imediato. Implementar wrapper
headless não adiciona valor prático para o caso de uso central desta skill.

**Não reavaliar** salvo surgimento de caso concreto em que importação de CSS em tema
seja requisito de automação recorrente neste contexto.

---

## ImportExternalObject

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que registra um objeto externo na KB. Parâmetros funcionais: `Name`,
`Type`, `URL` (nenhum marcado como obrigatório na reflexão).

**Por que foi descartada:**

Objetos externos são registros de integrações com sistemas de terceiros — cenário
específico e raro no fluxo de migração XPZ. A IDE do GeneXus gerencia esse registro
com validação visual. Semântica dos parâmetros não documentada oficialmente, o que
aumenta o risco de uso incorreto em automação headless.

**Não reavaliar** salvo surgimento de caso concreto documentado de automação de registro
de objetos externos.

---

## ImportTranslations

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que importa traduções de mensagens GeneXus a partir de arquivo externo.
Parâmetros funcionais: `FileName` (obrigatório), `AddNewMsg` (Boolean), `Override`
(Boolean).

**Por que foi descartada:**

Fluxo de tradução de mensagens é separado do fluxo principal de migração de objetos via
XPZ. Quando necessário, a IDE conduz a importação com validação e feedback. A superfície
técnica é simples, mas o caso de uso não se enquadra no escopo central da skill.

**Não reavaliar** salvo surgimento de caso concreto em que importação de traduções seja
requisito de automação recorrente neste contexto — especialmente em KBs multilíngues com
ciclo de tradução externo.

---

## ExportTranslations

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que exporta traduções de mensagens da KB para arquivo externo. Rica em
filtros: `FileName` (obrigatório), `FilterText`, `IncludeXRef`, `Languages`,
`OnlyReferencedMessages`, `OnlyUntranslatedMessages`, `OnlyUserMessages`, `UsedInObjects`.

**Por que foi descartada:**

Mesmo raciocínio de `ImportTranslations`: fora do escopo central da skill. A superfície
técnica é a mais rica das 6 tasks investigadas, com filtros granulares úteis em cenários
multilíngues. Porém, sem caso de uso concreto identificado neste contexto, implementar
wrapper headless não se justifica.

**Não reavaliar** salvo surgimento de caso concreto em que exportação de traduções com
filtro por idioma seja requisito de automação — aí a superfície desta task tem valor real.

---

## ConvertExportFile

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
e documentação offline (`60737.html`) confirmaram propósito e parâmetros.

**O que é:** task que converte um arquivo XPZ de versões anteriores do GeneXus para o
formato GeneXus 18. Requer KB aberta (usa a KB para converter referências a objetos
comuns como o SDT `Messages`). Disponível a partir do GeneXus 18 Upgrade 14.
Parâmetros: `File` (obrigatório), `OutputFile` (saída).

**Por que foi descartada:**

Cenário de uso limitado a migração pontual de XPZ legado — situação rara e de execução
única. Quando necessário, a IDE do GeneXus conduz a conversão. Implementar wrapper
headless para operação pontual de migração não justifica o custo de implementação e
manutenção.

**Não reavaliar** salvo surgimento de volume recorrente de conversões de XPZ legado que
torne a automação headless mais eficiente que a IDE.

---

## CreateExportForImages

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que exporta imagens da KB para um arquivo XPZ. Parâmetros funcionais:
`Folder` (obrigatório — pasta de origem das imagens), `OutputFile` (obrigatório — XPZ
de saída), `Filter`, `Parent`, `RenderingMode`.

**Por que foi descartada:**

Exportação de imagens é cenário separado do fluxo principal de migração de objetos via
XPZ. A IDE do GeneXus conduz essa exportação com seleção visual. Sem caso de uso
concreto identificado neste contexto.

**Não reavaliar** salvo surgimento de caso concreto em que exportação recorrente de
imagens em lote seja requisito de automação neste contexto.

## Book (parâmetro de OpenKnowledgeBase)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** atributo `Book=` observado em fonte externa de código como alternativa ao
parâmetro `Directory=` em `OpenKnowledgeBase`.

**Por que foi descartado:**

A investigação não encontrou `Book` em nenhuma superfície oficial da instalação do
GeneXus 18:

- ausente da documentação offline instalada (`35862.html` — OpenKnowledgeBase MSBuild Task)
- ausente do assembly `Genexus.MsBuild.Tasks.dll` (reflexão de propriedades públicas da task)
- ausente do arquivo `Genexus.Tasks.targets`
- ausente de qualquer `.targets` ou `.msbuild` da instalação oficial

Conclusão: `Book` é provável erro de digitação em fonte externa, sem correspondência na
superfície real da task. `Directory` e `MDFPath` são os únicos parâmetros de abertura
oficialmente confirmados.

**Não usar nos wrappers desta skill.**

---

## BuildOne

**Origem:** levantamento feito durante construção da skill `xpz-msbuild-import-export`.

**O que é:** task MSBuild oficial (`Genexus.Tasks.targets`, documentação `3908.html`).
Executa specify + generate + compile do objeto informado e de tudo que ele chama.
Reorg ocorre automaticamente se necessário — sem parâmetro para suprimir. É build real,
não simulação.

Propriedades públicas confirmadas por reflexão do assembly:

- `ObjectName` (`String`) — obrigatório
- `ForceRebuild` (`Boolean`) — default `false`
- `BuildCalled` (`Boolean`) — controla compilação dos objetos chamados
- `DetailedNavigation` (`Boolean`) — default `false`
- `CaptureOutput` (`Boolean`)
- `TaskOutput` (`String`)

**Por que foi descartada (sem wrapper implementado):**

`ObjectName` exige objeto com `Main = true`. A maioria dos objetos em um XPZ típico —
Procedures, Transactions auxiliares, SDTs, Domains — não tem `Main = true` e não pode
ser passada a `BuildOne`. Para XPZs cirúrgicos, que são o caso mais comum, `BuildOne`
é inaplicável. A confirmação funcional nesses casos depende de `BuildAll` headless ou
reabertura manual na IDE.

O reorg automático sem parâmetro de supressão também exigiria aviso explícito e
confirmação interativa antes de qualquer execução.

**Não reavaliar** salvo caso concreto em que o XPZ importado contém objeto `Main = true`
e o usuário precisa de smoke test de compilação sem abrir a IDE, combinado com
confirmação de que o reorg automático é aceitável naquele ambiente.

---

## Run

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06.

**O que é:** task MSBuild oficial (`3908.html`). Executa specify + generate + compile do
objeto informado e de tudo que ele referencia, e em seguida executa o objeto. Parâmetros:
`ObjectName` (obrigatório, exige `Main = true`), `ForceRebuild`, `Build`, `BuildCalled`,
`DetailedNavigation`, `Parameters`.

**Por que foi descartada:**

Mesma restrição central de `BuildOne`: `ObjectName` exige objeto com `Main = true`,
inaplicável para a maioria dos XPZs cirúrgicos. Além disso, `Run` executa o objeto após
o build — comportamento inadequado em automação headless de KB de teste, onde executar
a aplicação não é o objetivo e pode ter efeitos colaterais imprevisíveis.

**Não reavaliar** — a combinação de exigência de `Main = true` com execução real do objeto
não tem caso de uso no contexto desta skill.

---

## RebuildArtifacts

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Documentação oficial: `3908.html` (breve menção, sem parâmetros).

**O que é:** task sem parâmetros que reconstrói os artefatos físicos do ambiente — os
arquivos de saída gerados e compilados pela KB — sem repetir o ciclo completo de
specify + generate + compile. Disponível a partir do GeneXus 16 Upgrade 3.

**Por que foi descartada:**

Caso de uso restrito a cenários em que os artefatos físicos ficaram desincronizados do
que o GeneXus compilou (ex.: limpeza manual de pasta de deploy ou falha de gravação).
A IDE do GeneXus cobre essa situação com feedback visual. Implementar wrapper headless
para operação de manutenção rara, sem parâmetros e sem diagnóstico, não agrega valor
prático neste contexto.

**Não reavaliar** salvo surgimento de cenário recorrente em que artefatos de KB de teste
precisem ser reconstruídos headless sem novo ciclo de build.

---

## CustomBuild

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Documentação oficial: `3908.html`.

**O que é:** task que executa um Custom Build previamente definido na IDE via
`Tools > Options > Build > Custom Build`. Parâmetros: `Name` (nome do Custom Build,
obrigatório), `ObjectName` (obrigatório quando o Custom Build é sobre um objeto com
`Main = true`).

**Por que foi descartada:**

Depende de configuração prévia e nomeada na IDE. Em automação headless, não há garantia
de que o Custom Build configurado na IDE de origem existe com o mesmo nome na KB de
destino. A task falha silenciosamente ou com erro genérico se o Custom Build não existir.
Esse acoplamento à configuração visual torna a task inadequada como base de wrapper
headless portável.

**Não reavaliar** salvo caso em que a KB de destino tenha Custom Builds nomeados e
documentados como parte do contrato de deploy, tornando a configuração previsível.

---

## SpecifyOneOnly

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Registrada em `Genexus.Tasks.targets`; sem documentação oficial offline.

**O que é:** equivalente objeto-a-objeto do `SpecifyAll`. Especifica apenas os objetos
nomeados explicitamente, sem gerar código. O `Genexus.msbuild` usa-a com parâmetros
`ObjectNames` e `Options`.

**Por que foi descartada:**

Sem caso de uso identificado no contexto desta skill. Especificar um subconjunto de
objetos sem gerar é uma etapa intermediária de pipeline muito controlado — cenário que
não ocorre no fluxo de validação pós-import desta frente. `SpecifyAll` ou `BuildAll`
cobrem os casos relevantes. Ausência de documentação oficial agrava o risco de
comportamento imprevisível.

**Não reavaliar** salvo surgimento de pipeline headless que precise especificar objetos
individuais sem geração, com documentação oficial da task.

---

## SpecifyOpenAPI

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Registrada em `Genexus.Tasks.targets`; sem documentação oficial offline.

**O que é:** task de especificação específica para o gerador OpenAPI do GeneXus. Parte
do pipeline de publicação de APIs REST com especificação OpenAPI.

**Por que foi descartada:**

Fora do escopo desta skill. O contexto de XPZ desta frente não inclui projetos de API
REST com publicação de especificação OpenAPI. Sem documentação oficial e sem caso de uso
identificado neste contexto.

**Não reavaliar** salvo surgimento de projeto com pipeline headless de API REST GeneXus
que exija especificação OpenAPI automatizada.

Ressalva 2026-07-24: a regra documental de ler YAML OpenAPI já gerado como evidência complementar pós-build do contrato público observado não reabre esta frente. Reabrir `SpecifyOpenAPI` continua exigindo o critério acima: pipeline headless que precise especificação OpenAPI automatizada.

---

## GenerateChatbot

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Registrada em `Genexus.Tasks.targets`; sem documentação oficial offline da
task em si.

**O que é:** task que força a geração dos artefatos do gerador de chatbots do GeneXus —
equivalente headless da opção de menu "Force Chatbot Generation". Aplica-se apenas a
projetos que usam o gerador de chatbots GeneXus (integração com plataformas como
Facebook Messenger, web e mobile via NLP).

**Por que foi descartada:**

Produto específico (gerador de chatbots GeneXus) fora do escopo desta skill de XPZ.
O público-alvo desta frente não opera projetos de chatbot GeneXus. Sem caso de uso
identificado.

**Não reavaliar** — fora de escopo por definição do público-alvo desta frente.

---

## GenerateOpenAPI

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Uso confirmado em `DeploymentTargets/Common/common.targets`.

**O que é:** task que gera o arquivo de especificação OpenAPI a partir dos objetos GeneXus
REST com propriedade `Generate OpenAPI Interface = Yes`. Chamada no pipeline de deploy
de APIs REST, não no build normal. Parâmetros confirmados em uso: `ObjectList`,
`ConfigFlags`, `OutputFile`.

**Por que foi descartada:**

Específica do pipeline de deploy de APIs REST com publicação de especificação OpenAPI.
Fora do escopo desta skill de XPZ, que trata de migração e sincronização de objetos.
O público-alvo desta frente não opera pipelines de publicação OpenAPI headless.

**Não reavaliar** salvo surgimento de projeto com deploy headless de REST API GeneXus
com geração de especificação OpenAPI como requisito de automação.

Ressalva 2026-07-24: a regra documental de ler YAML OpenAPI já gerado como evidência complementar pós-build do contrato público observado não reabre esta frente. Reabrir `GenerateOpenAPI` continua exigindo o critério acima: deploy headless de REST API GeneXus com geração OpenAPI como requisito de automação.

---

## IdeWebBuildAndDeploy / IdeWebCreateDB / IdeWebImpactDB

**Origem:** inventário de tasks MSBuild do GeneXus 18, avaliação do domínio build pipeline,
2026-05-06. Registradas em `Genexus.Tasks.targets`; sem documentação oficial offline.

**O que são:** tasks relacionadas ao serviço **GeneXus Cloud Services** — que permitia
hospedar e operar a própria IDE do GeneXus em modo web/cloud. `IdeWebBuildAndDeploy`
fazia o build e deploy da IDE web; `IdeWebCreateDB` criava o banco de dados necessário;
`IdeWebImpactDB` aplicava alterações nesse banco.

**Por que foram descartadas:**

O serviço GeneXus Cloud Services foi **descontinuado no GeneXus 18** — a opção
`Build > Deploy to GeneXus Cloud Services` foi removida da IDE e os serviços associados
encerrados (confirmado na documentação offline `53520.html`, release notes do GeneXus 18).
As tasks permanecem registradas no assembly por compatibilidade, mas não têm uso ativo.
São código morto de feature descontinuada.

**Não reavaliar** — feature descontinuada pelo próprio GeneXus.

---

## Compile (como script isolado na skill xpz-msbuild-build)

**Origem:** avaliação do domínio build pipeline durante construção da skill
`xpz-msbuild-build`, 2026-05-06.

**O que é:** task MSBuild oficial (`3908.html`). Com `ObjectName` compila o objeto
indicado; sem `ObjectName` compila o Developer Menu. Propriedade pública confirmada por
reflexão do assembly: `ObjectName` (`String`), opcional.

**Por que foi descartada como script independente:**

`Compile` com `ObjectName` exige `Main = true` — mesma restrição de `BuildOne` e `Run`,
inaplicável para Procedures, SDTs, Domains e Transactions auxiliares que compõem a
maioria dos XPZs cirúrgicos. `Compile` sem `ObjectName` compila o Developer Menu, que
não toca diretamente nos objetos importados quando esses não têm `Main = true`.

Portanto, `Compile` isolado não cobre a lacuna de validação pós-import que esta skill
precisa resolver. Essa lacuna é coberta por `BuildAll`, que compila todos os objetos
incluindo os importados, independentemente de terem `Main = true`.

Usar `Compile` antes de `SpecifyAll + GenerateOnly` é estruturalmente incorreto: compila
com especificação anterior ao import, podendo mascarar erros reais. Usar `Compile` após
`SpecifyAll + GenerateOnly` sem `BuildAll` é caso tão específico (quer compilar mas não
quer reorg) que não justifica script dedicado neste contexto.

**Não reavaliar** salvo surgimento de XPZ com objeto `Main = true` em que a compilação
isolada faça sentido como etapa separada do BuildAll.

---

## CreateDatabase / CreateDatabaseOnly

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.
Propriedades públicas confirmadas por reflexão do assembly.

**O que são:**

`CreateDatabase` cria os objetos de banco de dados (tabelas, índices, constraints) exigidos
pela KB aberta. Parâmetro `ExecuteCreate` (Boolean) controla se apenas gera o script ou
também executa.

`CreateDatabaseOnly` é uma variante por modelo: parâmetros `Model` (Int32) e `FromModel`
(Int32) permitem especificar de qual modelo a criação parte. Sem documentação oficial no
índice `3908.html`; registrada no assembly e em `Genexus.Tasks.targets`.

**Por que foram descartadas:**

Ambas são operações de setup inicial de banco — executadas uma vez quando a KB é criada
ou migrada. A IDE do GeneXus conduz esse processo com feedback visual e sem risco de
interpretação incorreta dos parâmetros de modelo.

`CreateDatabaseOnly` tem parâmetros `Model` e `FromModel` sem documentação oficial, o que
aumenta o risco de comportamento imprevisível em automação headless.

Em nenhum dos dois casos o ganho de automatizar supera o risco e a complexidade frente à
alternativa trivial de usar a IDE para criação inicial.

**Não reavaliar** salvo surgimento de caso concreto em que a criação de banco seja
requisito de automação recorrente em pipeline headless — não apenas setup pontual.

---

## Set*/Reset* de propriedades em KB/Version/Environment/Generator/DataStore

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou as 10 tasks: `SetKnowledgeBaseProperty`, `SetVersionProperty`,
`SetEnvironmentProperty`, `SetGeneratorProperty`, `SetDataStoreProperty` e os
correspondentes `Reset*`.

**O que são:** tasks de escrita e restauração de propriedades nos níveis KB, Version,
Environment, Generator e DataStore. Interfaces confirmadas por reflexão:

- Set*: `Name` (String), `Value` (String); Generator e DataStore aceitam também nome do
  target (`Generator` ou `DataStore`, opcional, default "Default")
- Reset*: `Name` (String); Generator e DataStore aceitam também o nome do target

**Por que foram descartadas:**

O usuário pode alterar essas propriedades diretamente na IDE do GeneXus sem risco
operacional adicional. Fazer isso via script headless introduz risco de efeito colateral
não documentado (precedência entre níveis, interação com build pipeline) sem benefício
concreto identificado. Não há caso de uso específico desta frente que exija alterar
propriedades de KB, Version, Environment, Generator ou DataStore programaticamente.

**Não reavaliar** salvo surgimento de caso concreto de automação em que o usuário
não possa ou não deva abrir a IDE para ajustar essas propriedades.

---

## SetObjectProperty / ResetObjectProperty

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou ambas as tasks.

**O que são:** tasks de escrita e restauração de propriedade de um objeto específico da
KB. Interface confirmada: `Object` (String, nome do objeto), `Name` (String, nome da
propriedade), `Value` (String, para Set). `ResetObjectProperty` usa apenas `Object` e
`Name`.

**Por que foram descartadas:**

Objetos importados via XPZ já carregam suas propriedades do arquivo de origem. Se uma
propriedade precisar ser corrigida após import, o problema está no pacote — e a
correção correta é ajustar o XPZ de origem, não sobrescrever via script pós-import.
Além disso, alterar propriedades de objeto headless sem saber o estado atual é operação
cega que pode sobrescrever configurações deliberadas.

Não há caso de uso concreto identificado nesta frente que exija ajustar propriedades de
objeto headless. A IDE do GeneXus resolve isso com feedback visual imediato.

**Não reavaliar** salvo surgimento de caso documentado em que uma propriedade de objeto
precise ser definida programaticamente como parte do pipeline de import e o ajuste no
XPZ de origem não for viável.

---

## SetCredential

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou a task com parâmetros: `UserName` (String), `UserPassword`
(String), `TargetName` (String), `Persist` (Boolean), `AccessToken` (String).

**O que é:** task que registra ou atualiza credenciais associadas à KB, possivelmente
para GeneXus Server ou outros serviços integrados.

**Por que foi descartada:**

Manipular senhas e tokens de acesso em scripts automatizados é risco de segurança
explícito. Além disso, o público-alvo desta frente não usa GeneXus Server, que é o
consumidor principal dessas credenciais. A presença de `UserPassword` em texto simples
como parâmetro da task reforça que essa operação não deve ser automatizada
indiscriminadamente.

**Não reavaliar** — fora de escopo por razão de segurança e por ausência de GeneXus
Server no ambiente desta frente.

---

## SetCatalog

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou a task com parâmetro: `FilePath` (String).

**O que é:** task que aponta a instalação do GeneXus para um arquivo de catálogo
alternativo. Opera no nível do produto GeneXus, não da KB — a reflexão confirmou a
ausência das propriedades `KB`, `KBHandle` e `KBPath` que todas as tasks KB-escopadas
carregam.

**Por que foi descartada:**

Altera configuração da instalação do GeneXus como um todo, não de uma KB específica.
Esse nível de configuração é gerenciado pela IDE do GeneXus e não tem caso de uso no
fluxo de importação/exportação de XPZ desta frente.

**Não reavaliar** salvo surgimento de cenário em que troca de catálogo headless seja
requisito documentado de automação neste contexto.

---

## SetProductInfo

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou a task com parâmetros: `Info` (String), `DefaultRWDTheme`
(String), `DefaultStyle` (String).

**O que é:** task que define informações de produto para a instalação do GeneXus — tema
RWD padrão e estilo padrão. Opera no nível do produto, não da KB (mesma evidência que
`SetCatalog`: ausência das propriedades KB-escopadas na reflexão).

**Por que foi descartada:**

Não tem relação com o fluxo de importação/exportação de XPZ. A IDE do GeneXus gerencia
essas configurações de produto sem necessidade de automação headless neste contexto.

**Não reavaliar** — fora de escopo por definição do domínio desta frente.

---

## SetConversationalFlowsProperty

**Origem:** avaliação do domínio de gerenciamento de propriedades, 2026-05-07. Reflexão
do assembly confirmou a task com parâmetros: `ObjectName` (String), `PropertyName`
(String), `PropertyValue` (String).

**O que é:** task que define propriedades de objetos do gerador de conversational flows
(chatbots/assistentes) do GeneXus. Parâmetros confirmados por reflexão.

**Por que foi descartada:**

Específica do gerador de conversational flows — fora do escopo desta skill de XPZ, que
trata de migração e sincronização de objetos GeneXus genéricos. O público-alvo desta
frente não opera projetos de conversational flows GeneXus.

**Não reavaliar** — fora de escopo por definição do público-alvo desta frente.

---

## Domínio Deploy (Deploy.msbuild, docker.msbuild, CreateCloudPackage.msbuild e demais)

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, domínio Deploy,
2026-05-06. Arquivos `.msbuild` confirmados como presentes na instalação oficial em todas
as versões avaliadas.

**O que são:** arquivos `.msbuild` permanentes entregues pela instalação do GeneXus para
publicação de aplicações compiladas em ambientes de servidor. Abrangem:

- `Deploy.msbuild` — deploy para application server; documentação oficial na wiki (id 42073)
- `CreateCloudPackage.msbuild` — empacotamento para deploy em nuvem
- `CreateFrontendPackage.msbuild` — empacotamento de frontend
- `docker.msbuild` — geração de imagem Docker
- `GXDeployProjects.msbuild` — deploy de múltiplos projetos
- `MobileAndroidDeploy` — deploy para Android
- Subpastas com targets por plataforma: `DeploymentTargets\`, `gxnet\`, `gxnetcore\`,
  `ApplicationServers\Templates\`, `GenExtensions\SmartDevices\`

Diferente das operações de import/export/build, que exigem gerar `.msbuild` dinamicamente,
esses arquivos já existem na instalação e podem ser invocados diretamente com parâmetros —
o que confirma que deploy headless é um cenário oficialmente previsto e suportado pelo
GeneXus.

**Por que foram descartados:**

Deploy de aplicação é uma preocupação de infraestrutura, não de movimentação de objetos
entre KBs. O escopo declarado das skills XPZ cobre o ciclo `import → build → validar`:
o deploy começa exatamente onde esse ciclo termina. O público-alvo dessas skills é o
desenvolvedor que trabalha com objetos GeneXus, não o operador que publica a aplicação em
servidor.

Adicionalmente, vários cenários de deploy dependem do GeneXus Server como requisito
operacional — critério de exclusão já estabelecido nesta base (ver `BulkCopyKnowledgeBase`).

**Não reavaliar** salvo surgimento de caso concreto em que o ciclo de validação pós-import
inclua deploy como etapa necessária para o desenvolvedor de objetos — por exemplo, um
ambiente de teste que exija publicação headless automatizada como parte do gate de aceite
do XPZ. Nesse caso, a implementação seria invocar o `Deploy.msbuild` existente com
parâmetros explícitos, não gerar `.msbuild` dinamicamente.

---

## MergeVersions

**Origem:** avaliação de inventário de tasks MSBuild — domínio Team Development, 2026-05-07.

**O que é:** task MSBuild do domínio Team Development que mescla alterações de uma versão
derivada para outra versão da KB. Operação destinada a fluxos em que equipes desenvolvem
em versões paralelas e precisam consolidar o trabalho numa versão comum.

Parâmetros não documentados no índice local `3908.html`. Não verificada no assembly.

**Por que foi descartada:**

Ausência de caso de uso no perfil de KB local com versões-checkpoint. O público-alvo
desta trilha usa versões como pontos de restauração de segurança, não como ramificações
de desenvolvimento paralelo. Sem Team Development ativo com versões concorrentes, merge
de versão não aparece no horizonte das skills XPZ.

**Não reavaliar** salvo surgimento de caso concreto com Team Development ativo e versões
paralelas de desenvolvimento que precisem ser consolidadas por automação headless.

---

## CreateEnvironment

**Origem:** avaliação de prompt externo sobre domínio Environment (MSBuild Tasks), 2026-05-07.

**O que é:** task MSBuild oficial que cria um novo environment na versão ativa ou especificada
da KB. Parâmetros: `Name` (obrigatório), `Template` (obrigatório — um dos templates de KB:
`CSharp.KBTemplate`, `NetCore.KBTemplate`, `Java.KBTemplate`). Documentada no índice `3908.html`.

**Por que foi descartada:**

O domínio Environment é essencialmente coberto pelas operações já implementadas:
`SetActiveEnvironment` (via `-EnvironmentName` em todos os wrappers) e `GetActiveEnvironment`
(capturado e declarado em `Open-GeneXusKbHeadless.ps1`). `CreateEnvironment` só agregaria valor
em dois cenários:

1. Pipeline totalmente headless de criação de KB de teste — descartado pelo mesmo motivo que
   `CreateKnowledgeBase`: a IDE cria KB e environments sem dificuldade, sem custo de configuração
   SQL Server/LocalDB e sem risco de template incorreto.
2. Criação de environment adicional em KB existente — operação de setup pontual que a IDE
   resolve em segundos, sem justificar wrapper headless.

O `Template` obrigatório introduz decisão de generator + DBMS que pertence ao setup inicial da
KB, não ao fluxo de importação e exportação de XPZ. Quando a KB já existe com seus environments
(cenário operacional desta frente), `SetActiveEnvironment` e `GetActiveEnvironment` cobrem tudo
que o fluxo precisa.

**Não reavaliar** salvo surgimento de pipeline headless de criação de KB de teste em que
environments precisem ser criados programaticamente como parte do contrato de automação.

---

## PackageModule / PublishModule

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` da instalação local.

**O que são:**

`PackageModule(ModuleName, Rebuild?, OutputDirectory?, Environments?)` cria um arquivo `.opc`
(Open Packaging Convention — ZIP) contendo binários e arquivos de definição do módulo.
`PublishModule(ModuleName, Server, OpcFile?, User?, Password?)` publica o `.opc` em um servidor
de módulos (Directory, Nexus-Maven ou Nexus-NuGet).

**Por que foram descartadas:**

São o lado produtor do ecossistema de módulos. Quem usa as skills XPZ é consumidor de objetos
e funcionalidades — importa, valida e usa. Criar e distribuir módulos para terceiros consumirem
é uma atividade de library author, não de desenvolvedor de KB. O fluxo de movimentação de
objetos desta frente (export XPZ → import XPZ → build → validar) não tem equivalência com o
fluxo produtor de módulos (PackageModule → PublishModule → servidor).

A granularidade também é incompatível: XPZ permite selecionar objetos individuais com controle
cirúrgico; um módulo é uma unidade de distribuição com contrato de interface público — criar um
módulo pressupõe decisão de design que vai além do escopo de automação headless desta frente.

**Não reavaliar** salvo surgimento de caso concreto em que o público-alvo desta frente precise
publicar módulos GeneXus como parte do pipeline de distribuição de objetos.

---

## UpdateUserControls

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`.

**O que é:** task que atualiza user controls (extensões visuais UCW/GX Control) instalados
na KB. Não faz parte do domínio de módulos de objetos GeneXus — trata de extensões visuais
(componentes de terceiros que aparecem na toolbox da IDE).

**Por que foi descartada:**

User controls são extensões da IDE para design visual de telas, não objetos GeneXus movimentáveis
via XPZ. A atualização dessas extensões é gerenciada pela IDE do GeneXus ou pela instalação de
pacote de extensão, não pelo fluxo de importação de objetos. Sem caso de uso identificado no
contexto de migração e sincronização de objetos via XPZ.

**Não reavaliar** — fora de escopo por definição do domínio desta frente.

---

## Domínio Testes (ExecuteTests / RunAndroidUITests / RunIOSUITests)

**Origem:** avaliação de prompt externo sobre domínio Testes (MSBuild Tasks / GXtest), 2026-05-07.
Arquivo `GXtest.msbuild` presente na instalação oficial do GeneXus 18; tasks `RunAndroidUITests`
e `RunIOSUITests` registradas em `Genexus.Tasks.targets`.

**O que são:**

`ExecuteTests` — task do `GXtest.msbuild` que executa testes automatizados (UI, Unit ou All)
contra a KB. Parâmetros: `KBPath`, `KBVersion`, `TestType`, `Browser`, `BaseURL`,
`ScreenshotMode`, entre outros. Requer licença `GXtest` ativa.

`RunAndroidUITests` / `RunIOSUITests` — tasks de execução de testes de interface em dispositivos
ou emuladores Android e iOS, respectivamente. Exigem aplicação já buildada e deployada, SDK da
plataforma e device/emulador ativo.

**Por que foram descartadas:**

Dois bloqueios independentes, qualquer um suficiente para descartar:

1. **Dependência de `Genexus.Server.Tasks.targets`**: o `GXtest.msbuild` importa explicitamente
   `Genexus.Server.Tasks.targets`. A restrição de escopo sobre GeneXus Server já está estabelecida
   nesta base: `Genexus.Server.Tasks.targets` não é base operacional da skill e tasks que dependem
   dele não devem virar pré-requisito de uso. O domínio Testes cruza essa fronteira na própria
   infraestrutura de execução.

2. **Licença `GXtest` obrigatória**: `KB_Teste_E` confirmou empiricamente o bloqueio: `exitCode = 0`,
   `importedItems` vazio, tentativa de contato com GeneXus Server, exigência de credenciais e
   ausência de licença `GXtest` válida. O público-alvo desta frente não dispõe de GeneXus Server
   nem de licença `GXtest` ativa.

Adicionalmente, `RunAndroidUITests` e `RunIOSUITests` exigem infraestrutura de device ou emulador
móvel (Android SDK, Xcode/simulador iOS) e aplicação já deployada — escopo de CI mobile dedicado,
completamente fora do domínio de validação pós-import de XPZ.

**Nota sobre padrão de string matching sem ExitCode (FBgx18MCP):** a fonte externa avaliada usa
string matching no stdout (`"Tests execution succeeded"` ou `"Passed: 1"`) sem verificar `ExitCode`
como critério de sucesso. Esse padrão contradiz as regras empíricas consolidadas nesta base —
`ExitCode` + varredura obrigatória de stdout/stderr são exigidos antes de classificar qualquer
operação como bem-sucedida. O padrão do FBgx18MCP não foi adotado.

**Não reavaliar** salvo evidência de que o GXtest passou a operar sem `Genexus.Server.Tasks.targets`
e sem licença própria, e que o público-alvo desta frente passou a dispor de licença GXtest ativa.

---

## Domínio Daemons (SpecifierDaemon, GeneratorDaemon, BuildWait)

**Origem:** avaliação de prompt externo sobre domínio Daemons (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; `SpecifierDaemon` e `GeneratorDaemon` referenciados
no `Genexus.msbuild` canônico da instalação oficial.

**O que são:**

`SpecifierDaemon` e `GeneratorDaemon` são processos persistentes de especificação e geração
que ficam residentes dentro de uma sessão MSBuild com a KB já aberta em memória, reespecificando
e regenerando objetos sob demanda sem o custo de reabertura a cada ciclo. São aceleradores do
pipeline de build contínuo — o `Genexus.msbuild` canônico os inicia antes de `SpecifyAll` e
`Generate`, mantendo-os vivos enquanto a sessão durar.

`BuildWait` é um mecanismo de sincronização: faz um processo MSBuild aguardar a conclusão de
builds em andamento na mesma sessão antes de prosseguir.

**Por que foram descartados:**

Bloqueio arquitetural: os daemons são aceleradores *intra-sessão*. Eles operam como workers
dentro de um processo MSBuild que já tem a KB aberta e o handle em memória. Quando aquele
processo termina, os daemons morrem junto — não ficam ouvindo para uma próxima invocação.

A skill usa `/nodeReuse:false` em todos os wrappers para garantir processo limpo a cada
chamada — o oposto do que os daemons precisam para ter valor. Além disso, um import muda
a KB no disco; qualquer estado em memória de um daemon anterior seria stale após a importação.

`BuildWait` tampouco tem aplicação: sem concorrência entre invocações (cada wrapper roda
isolado com processo limpo), não há builds em paralelo a sincronizar.

O caso `KB_Teste_Grande_A` — MSBuild continuando por longo período após timeout do wrapper —
também não é explicado pelos daemons. A causa já está documentada: importação de grande
porte em KB volumosa; o processo MSBuild filho continua até concluir, independentemente do
timeout do invocador PowerShell.

**Não reavaliar** salvo surgimento de pipeline monolítico de sessão contínua (uma única
invocação MSBuild cobrindo abertura, import, specify, generate e fechamento da KB) onde
specify+generate sejam o gargalo dominante — cenário que exigiria reforma estrutural do
modelo de wrappers isolados adotado nesta frente.

---

## Profile

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que é:** task de perfilamento de execução/tempo das operações MSBuild do GeneXus.
Função presumida: medir duração de etapas internas do pipeline.

**Por que foi descartada:**

Sem caso de uso concreto no contexto de migração e sincronização de objetos via XPZ. Os
logs gerados por `/verbosity:minimal` do MSBuild e o `exitCode` já fornecem informação de
tempo e resultado suficiente para diagnóstico operacional. Implementar wrapper de perfilamento
não agrega valor prático neste contexto. Ausência de documentação oficial agrava o risco de
comportamento imprevisível.

**Não reavaliar** — sem caso de uso identificado e sem documentação oficial.

---

## AddExternalFile

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que é:** task que adiciona um arquivo externo (imagens, recursos) à KB GeneXus.
Função presumida baseada no nome.

**Por que foi descartada:**

Adição de recursos externos à KB é cenário raro no fluxo de migração de objetos via XPZ.
Quando necessário, a IDE do GeneXus conduz essa operação com seleção visual e validação.
Ausência de documentação oficial e de parâmetros confirmados por reflexão de assembly
aumenta o risco de comportamento imprevisível em automação headless. Sem caso de uso
concreto identificado neste contexto.

**Não reavaliar** salvo surgimento de caso concreto em que adição recorrente de arquivos
externos à KB seja requisito de automação neste contexto, combinado com confirmação
empírica dos parâmetros da task no assembly.

---

## CreateFromGxml

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que é:** task que cria objetos GeneXus a partir de GXML — formato de serialização
interna do GeneXus, distinto do formato XPZ. Função presumida baseada no nome.

**Por que foi descartada:**

GXML é um formato interno do GeneXus, distinto do XPZ que é o objeto de trabalho desta
frente. Sem documentação oficial, parâmetros desconhecidos e sem caso de uso identificado
no fluxo de migração e sincronização de objetos via XPZ. A IDE do GeneXus exporta e
importa GXML quando necessário. Implementar wrapper headless para formato interno não
documentado introduz risco sem ganho prático identificado.

**Não reavaliar** — fora de escopo por definição do domínio desta frente e por ausência
de documentação oficial da task.

---

## MergeSource / MergeXml

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que são:** tasks de merge de arquivos de source code ou XML — presumivelmente úteis
em cenários de versionamento e resolução de conflitos entre objetos GeneXus.

**Por que foram descartadas:**

Mesma barreira central de `MergeVersions` (já descartada): o público-alvo desta frente
não opera com Team Development ativo e versões concorrentes de desenvolvimento. Sem esse
perfil, merge de source ou XML não aparece no horizonte do fluxo de XPZ. Ausência de
documentação oficial dos parâmetros agrava o risco de uso incorreto. A IDE do GeneXus
conduz esse processo com feedback visual quando necessário.

**Não reavaliar** salvo surgimento de caso concreto com Team Development ativo e conflitos
de merge que precisem ser resolvidos por automação headless, combinado com documentação
oficial das tasks.

---

## HelpGenerator

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que é:** task que gera documentação de ajuda da aplicação GeneXus. Função presumida
baseada no nome.

**Por que foi descartada:**

Geração de documentação de ajuda é etapa de publicação da aplicação, completamente fora
do escopo de migração e sincronização de objetos via XPZ. A IDE do GeneXus conduz essa
operação. Sem documentação oficial, parâmetros desconhecidos e sem caso de uso identificado
neste contexto.

**Não reavaliar** — fora de escopo por definição do domínio desta frente.

---

## NavigationOnly

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets` e referenciada no target `Navigation` do
`Genexus.msbuild` canônico da instalação oficial.

**O que é:** task que executa apenas a etapa de navegação entre objetos do GeneXus —
parte interna do pipeline de specify que analisa referências e dependências entre objetos,
sem gerar código.

**Por que foi descartada:**

Etapa intermediária do pipeline interno de build do GeneXus. Sem caso de uso isolado em
wrapper headless — `SpecifyAll` e `BuildAll` cobrem os cenários relevantes de verificação
pós-import, incluindo a navegação como subetapa implícita. Executar apenas a navegação
sem specify ou generate não produz evidência útil adicional para o fluxo de validação desta
frente. Sem documentação oficial de parâmetros.

**Não reavaliar** — etapa interna do pipeline sem caso de uso isolado identificado neste
contexto.

---

## HasDataStore / HasGenerator

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que são:** tasks utilitárias de verificação de existência — `HasDataStore` verifica
se a KB tem um DataStore configurado; `HasGenerator` verifica se tem um Generator ativo.
Funções presumidas baseadas nos nomes.

**Por que foram descartadas:**

O fluxo operacional desta frente confirma DataStore e Generator via `GetActiveEnvironment`
e pelos parâmetros explícitos passados nos wrappers (`-EnvironmentName`). As tasks `Get*Property`
já cobertas pela skill `xpz-msbuild-import-export` (`GetDataStoreProperty`, `GetGeneratorProperty`)
oferecem diagnóstico mais rico que uma verificação binária de existência. Sem documentação
oficial e sem caso de uso concreto que justifique wrapper separado.

**Não reavaliar** — diagnóstico de DataStore e Generator já coberto por `Get*Property`.

---

## SketchToGxmlTask

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Task registrada em `Genexus.Tasks.targets`; sem documentação oficial em `3908.html`.

**O que é:** task que converte um sketch (esboço de interface) para o formato GXML do
GeneXus. Faz parte do fluxo de design visual assistido do GeneXus — transformação de
wireframes ou esboços em objetos GeneXus.

**Por que foi descartada:**

Produto específico do fluxo de design visual assistido do GeneXus, completamente fora do
escopo de migração e sincronização de objetos via XPZ. O público-alvo desta frente não
opera esse fluxo. Sem documentação oficial e sem caso de uso identificado.

**Não reavaliar** — fora de escopo por definição do público-alvo desta frente.

---

## KnowledgeMatrix* (6 tasks comentadas)

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks identificadas no `Genexus.Tasks.targets` da instalação oficial, porém **comentadas**
no arquivo.

**O que são:** `KnowledgeMatrixNPreview`, `KnowledgeMatrixNPreviewDN`, `KnowledgeMatrixPreview`,
`KnowledgeMatrixPreviewDN`, `KnowledgeMatrixNRelease`, `KnowledgeMatrixRelease` — 6 tasks
com prefixo `KnowledgeMatrix` registradas mas desativadas no `.targets`.

**Por que foram descartadas:**

Tasks comentadas no arquivo `.targets` oficial indicam produto ou licença separada
(`KnowledgeMatrix`) não disponível na instalação padrão do GeneXus 18. Não há documentação
oficial correspondente em `3908.html`. O fato de estarem comentadas — e não apenas ausentes
— sugere que fazem parte de uma feature opcional ou descontinuada que a instalação padrão
não expõe.

**Não reavaliar** salvo evidência de que o produto `KnowledgeMatrix` passou a estar
disponível na instalação padrão do GeneXus 18 com as tasks descomentadas e documentadas.

## Validador de payload textual — acentuação degradada em e-mail/HTML

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** gate pré-empacotamento que verificaria, em partes de objetos com payload textual destinado a humano (templates de e-mail, mensagens, conteúdo HTML), se palavras que deveriam estar acentuadas aparecem sem acento — `Contribuicao` no lugar de `Contribuição`, `Nao` no lugar de `Não`, `usuario` no lugar de `usuário`, etc. Diferente do gate de mojibake (entrada própria em 999), que detecta bytes corrompidos por interpretação dupla de encoding, este gate detectaria perda silenciosa de acentos — caractere acentuado convertido a ASCII sem sinal visível de defeito.

**Por que foi descartada:**

Depende de conhecimento específico da KB. O gate só funciona com uma lista de tokens esperados acentuados, calibrada por KB ou por template — vocabulário próprio do projeto. KB em inglês não precisa do gate. KB em português pode ter `configuracao` intencional em identificador no meio de texto. Sem essa lista calibrada por contexto, o gate vira ruído de falso positivo.

As skills XPZ deste repositório cuidam da movimentação de objetos GeneXus via XPZ/XML e são deliberadamente agnósticas ao conteúdo semântico do que está sendo movido. Mojibake cabe porque é defeito estrutural de bytes detectável sem conhecer a KB. Degradação de acentos não cabe porque exige conhecer o que aquela KB específica espera ver — responsabilidade natural do agente local que conhece os templates da KB, ou de camada de QA do projeto (revisão de templates antes do empacotamento, validação runtime do conteúdo gerado, testes funcionais).

Forçar isso para dentro das skills XPZ exigiria ponto de extensão por KB (lista de tokens), quebrando a agnosticidade ao conteúdo, e abriria precedente para outras validações de domínio (formato de documento, presença de cláusulas legais, etc.) que pertencem ao agente local, não às skills compartilhadas.

**Não reavaliar** salvo evidência de que existe um mecanismo de detecção genérico (independente de vocabulário específico de KB) para distinguir acento perdido por defeito de acento ausente por intenção — sem o que o falso positivo torna o gate inutilizável.

**Nota 2026-06-11 — não confundir com o medidor interno do repositório.** Nesta data foi criado `scripts/Measure-PtBrAccentDegradation.ps1` (inventariado no `09`; baseline em `999-ideias-pendentes.md`), que mede acentuação degradada nos `.md`/`.ps1` **do próprio repositório de skills**. Não reabre este descarte: o corpus dele é único e conhecido (o repo), com lista curada fixa de palavras inequívocas mais supressão de código/identificador — não é o gate por-KB sobre payload de objeto que esta entrada rejeitou, nem o mecanismo genérico independente de vocabulário de KB que o parágrafo acima exigiria. São escopos distintos que coexistem.

## Encadeamento obrigatório SpecifyGenerate → BuildAll como fluxo padrão

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** proposta de forçar a sequência "Specify+Generate primeiro, BuildAll só depois quando a fase leve passar" como fluxo padrão da skill `xpz-msbuild-build`. A ideia subjacente: falhar cedo na fase leve evita o custo de um BuildAll completo que vai falhar de qualquer forma; em tese, economia de tempo, tokens e logs.

**Por que foi descartada:**

Avaliação dupla — uma parte já está implementada, e a parte que faltaria tem contraindicação documentada.

**Já implementado:** a separação em duas fases existe como dois scripts disponíveis em `xpz-msbuild-build` — `Invoke-GeneXusKbSpecifyGenerate.ps1` (fase leve) e `Invoke-GeneXusKbBuildAll.ps1` (fase completa). O GUIDELINE da skill orienta explicitamente quando usar cada um: SpecifyGenerate para verificação pós-import cirúrgico, BuildAll para validação completa. O WORKFLOW passo 4 faz o agente escolher entre os dois conforme o objetivo. Esta parte da proposta externa já está coberta — a skill apenas não força sequência obrigatória.

**Contraindicação para encadear:** a própria SKILL.md documenta comportamento crítico — `SpecifyAll` **não é leve quando há alterações estruturais pendentes**, porque a task executa internamente Database Impact Analysis, geração de script de reorganização e **reorganização real de banco**. `SpecifyAll` não expõe `FailIfReorg` nem equivalente, ao contrário de `BuildAll`. A skill exige confirmação por frase exata antes de SpecifyGenerate quando há sinal de alteração estrutural no import recente.

Forçar o encadeamento obrigatório implicaria: todo BuildAll teria de passar antes pelo gate de confirmação de reorg da SpecifyGenerate — inclusive quando o usuário só quer validação completa em KB sem alteração estrutural pendente. Pior: criaria caminhos de execução onde SpecifyGenerate dispara reorg, BuildAll não é nem chamado, e o objetivo original ("validar build completo") fica em estado parcial sem que o usuário tenha pedido para tocar no banco.

A escolha atual da skill — manter os dois scripts disponíveis sem encadear — é intencional e fundamentada nessa contraindicação.

**Não reavaliar** salvo evidência de que `SpecifyAll` passou a expor mecanismo equivalente a `FailIfReorg`, eliminando o risco de reorg implícita disparada pela fase leve.

## Bloco de verificação pós-import (reexport, delta verification, diagnóstico de assimilação) como frente própria

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** bloco de quatro facetas proposto pelo agente externo como reforço da skill `xpz-msbuild-import-export`:

1. **Verificação pós-import** — depois do import, checar se a KB ativa realmente assimilou os objetos; não confiar só em `exitCode=0`
2. **Reexport controlado de confirmação** — importar, reexportar os mesmos objetos, comparar com a frente local; "XML certo na frente, KB ainda errada"
3. **Modo delta verification** — confirmar que apenas os objetos esperados foram importados/alterados
4. **Diagnóstico de assimilação** — classificar resultado em "importou e assimilou" vs "importou mas KB manteve shape antigo" vs "importou parcialmente"

**Por que foi descartado como frente própria:**

Avaliação tripla, cada motivação fechando uma das pontas do bloco:

**Reexport controlado (faceta 2):** descartado por custo de tempo. Reexportar logo depois de importar, apenas para conferir a importação, gasta tempo demais para o ganho de garantia oferecido. Cada reexport em KB de tamanho médio/grande custa minutos de MSBuild adicional para apenas confirmar algo que outras técnicas (checksum, consulta SQL no banco interno da KB) podem confirmar a custo menor.

**Verificação pós-import e diagnóstico de assimilação (facetas 1 e 4):** investigação técnica já encaminhada em entrada própria de 999 — "CalculateChecksums + AreObjectsEqual — diagnóstico de integridade de objeto pré/pós-operação". Aquela entrada cobre o mesmo problema central (gap entre "import executado" e "objeto mudou da forma esperada") com meio técnico concreto a ser validado empiricamente. Duplicar como frente própria criaria duas entradas com sobreposição editorial sem agregar conteúdo novo.

**Taxonomia de cenários de assimilação isolada (faceta 4 sem meio técnico):** a classificação conceitual "importou e assimilou totalmente" vs "importou parcialmente" vs "KB resistiu" tem valor de comunicação ao usuário, mas sozinha — sem meio técnico que a alimente — não é frente. Quando algum meio técnico for implementado (checksum via `CalculateChecksums`, consulta SQL no banco interno da KB conforme entrada própria em 999, ou parsing estruturado do log de import), a taxonomia entra como refinamento de classificação na skill `xpz-msbuild-import-export` no momento da implementação. Não precisa de entrada própria em 999 enquanto isso.

**Delta verification (faceta 3):** depende dos mesmos meios técnicos (checksum ou consulta SQL); é caso particular da verificação geral, não frente paralela.

**Não reavaliar** salvo evidência de que: (a) reexport controlado passou a ter custo aceitável por algum mecanismo novo (export incremental real, comparação parcial sem reexport completo), **ou** (b) algum meio técnico distinto dos já cobertos em 999 emergir como abordagem viável para verificação imediata pós-import.

## Consulta pronta de callers como capacidade nova de xpz-index-triage

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** proposta de adicionar à skill `xpz-index-triage` consulta para responder perguntas como "quem chama a procedure X?" e "quais call sites ainda usam o objeto antigo?".

**Por que foi descartado:**

A capacidade já existe na skill. `xpz-index-triage/SKILL.md` documenta explicitamente as consultas `who-uses`, `what-uses`, `impact-basic` e `functional-trace-basic`, expostas pelo wrapper `Query-*KbIntelligence.ps1`. Há ainda sub-fluxo obrigatório de **resolução de alvo de navegação** — quando a pergunta vem ancorada em "qual objeto é aberto por este botão" ou "o popup chamado pelo evento Y", a skill resolve caller→alvo antes de qualquer leitura ou edição.

Mapeamento direto das duas perguntas do agente externo:

- "quem chama a procedure X?" → `who-uses Procedure:X`
- "quais call sites ainda usam o objeto antigo?" → operacionalmente o mesmo `who-uses` aplicado ao nome antigo durante uma migração; o estado atual do índice já responde quem ainda referencia o nome a substituir

Provável origem do gap percebido pelo agente externo: a proposta foi redigida sem inspecionar a skill atual.

**Leitura ambiciosa não coberta — não justifica entrada nova:**

Existe uma leitura mais ambiciosa de "objeto antigo" que de fato não está coberta: comparar dois snapshots históricos da KB para descobrir callers que **antes** referenciavam o objeto antigo e ainda não foram migrados, com versionamento histórico do índice. Essa interpretação é forçada — a frase mais natural é "callers que ainda referenciam o objeto antigo", que `who-uses` já responde olhando o estado atual. Sem sinal concreto de demanda por versionamento histórico de callers, essa capacidade não vira frente — exigiria escopo bem maior (histórico no índice) por ganho marginal frente ao estado atual.

**Não reavaliar** salvo surgimento de caso concreto que exija comparação de callers entre snapshots históricos distintos da KB, justificando versionamento histórico do índice como capacidade nova.

## Consulta de migração (Origem → Destino) como capacidade própria

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** proposta de adicionar a `xpz-index-triage` consulta que, dado um par (Origem, Destino) de objetos GeneXus, listaria os callers da Origem para o agente saber quem precisa ser editado para passar a chamar Destino.

**Por que foi descartada na forma original:**

A consulta de dados subjacente é literalmente `who-uses Origem`, capacidade já existente no índice e exposta pelo wrapper `Query-*KbIntelligence.ps1`. O par "Origem → Destino" não muda o que o índice retorna — é apenas **intenção operacional** declarada pelo usuário, fora do índice. A diferença frente a 4.1 é puramente cosmética (formato de apresentação com linguagem de migração).

**Ângulo que sobreviveu como entrada nova em 999:**

Durante a avaliação ficou claro que existe uma evolução real adjacente, distinta da cosmética: registrar no SQLite **o local exato** de cada referência (qual part, qual bloco nominal, linha aproximada, contexto curto) durante o build do índice. Isso transforma `who-uses` em "te referenciam aqui, aqui e aqui", permitindo edição cirúrgica em lote sem abrir os XMLs dos callers. Frente registrada como "Expansão do índice SQLite para fingerprint de call site" em 999.

**Não reavaliar** na forma original — a consulta de migração é só `who-uses` com rótulo de intenção; o ângulo estrutural sobrevive na entrada de fingerprint em 999.

## Consulta de família funcional como capacidade nova de xpz-index-triage

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** proposta de adicionar a `xpz-index-triage` consultas como "objetos de composição de e-mail", "objetos de parâmetros", "bridges de envio" — busca por agrupamento semântico/funcional em linguagem natural, sem depender de nome exato ou tipo estrutural.

**Por que foi descartada como capacidade própria:**

A classe de pergunta proposta é exatamente a que a entrada legada em 999 "LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual" já cobre como caso de uso central. Ambas dependem da mesma infraestrutura (camada vetorial de embeddings sobre o acervo XML), respondem a mesma classe de pergunta (intenção semântica em linguagem natural → conjunto de candidatos relevantes) e têm o mesmo limite (não substituem leitura do XML para conclusão funcional).

A diferença de redação entre os dois prompts não esconde diferença de conteúdo. Os exemplos do agente externo ("objetos de composição de e-mail", "bridges de envio") seriam atendidos pelo mesmo mecanismo previsto na entrada vetorial — embedding da pergunta, busca por similaridade no vector store, retorno dos candidatos com maior aderência semântica.

**Por que não foi ampliada na entrada vetorial existente:**

A entrada vetorial em 999 está com `FALTA AVALIAR` em ambos os campos (Importância e Maturidade). Acrescentar exemplos novos ali agora misturaria duas tarefas distintas — expandir conteúdo e avaliar prioridade — que esta sessão decidiu manter separadas. A sessão dedicada de inventário de entradas legadas, quando ocorrer, pode incorporar os exemplos do agente externo na entrada vetorial junto com a avaliação de prioridade.

**Não reavaliar** como capacidade própria. Se a entrada vetorial em 999 virar frente de implementação, esta classe de consulta entra automaticamente no escopo dela.

## Playbooks operacionais e casos reais sanitizados como frentes próprias

**Origem:** avaliação de prompt externo em 2026-05-11.

**O que era:** proposta de adicionar à documentação das skills XPZ duas categorias de conteúdo:

- **Playbooks** — roteiros passo-a-passo para situações operacionais específicas: "quando desconfiar de codificação de caracteres", "quando importou mas a KB parece antiga", "quando um atributo mudou de tipo".
- **Casos reais sanitizados** — exemplos concretos documentados: mojibake em templates de e-mail, drift de tipagem em WB_Parametros, migração de chamadores entre procedures.

**Por que foram descartados como frentes próprias:**

Ambas as categorias são **complementos naturais** das frentes técnicas já registradas em 999, não frentes independentes. Cada roteiro e cada caso real depende da ferramenta correspondente existir:

- roteiro "desconfiar de codificação" depende do gate de mojibake (entrada própria em 999, "Gate de mojibake/UTF-8 por bytes em XML pré-empacotamento")
- roteiro "atributo mudou de tipo" depende do detector de drift de tipagem (entrada própria em 999, "Drift de tipagem entre delta empacotado e snapshot oficial")
- roteiro "import passou mas KB parece antiga" depende dos meios técnicos de verificação pós-import (entrada própria em 999, "CalculateChecksums + AreObjectsEqual — diagnóstico de integridade de objeto pré/pós-operação")
- caso real "mojibake em e-mails" só vira material útil quando o gate de mojibake estiver implementado
- caso real "drift em WB_Parametros" só vira material útil quando o detector de drift estiver implementado
- caso real "caller migration de procedures" já é parcialmente coberto pela consulta `who-uses` existente em `xpz-index-triage`; documentar é trivial quando houver demanda

Sem as ferramentas técnicas, roteiros viram especulativos e casos reais não têm trilha para reprodução. Quando uma frente técnica em 999 virar trabalho real, o roteiro correspondente e o caso real correspondente nascem junto como parte do mesmo escopo — não fazem frente separada.

A base compartilhada já tem onde encaixar esse conteúdo quando ele existir: `08-guia-para-agente-gpt.md` para roteiros operacionais; `01h-moldes-sanitizados-metadados-e-artefatos.md` para casos sanitizados. A infraestrutura editorial está pronta; só falta a substância técnica que as frentes em 999 vão produzir.

**Não reavaliar** como frentes independentes. Quando uma frente técnica em 999 virar implementação, incluir roteiro e caso real no escopo dela.

---

## Índice geral em `scripts/` (README agregado)

**Origem:** avaliação de prompt externo em 2026-05-16, sobre revisão pré-push da frente de extração dos gates determinísticos do `xpz-builder` (Sub-fases 1.1 a 1.5).

**O que era:** proposta de criar `scripts/README.md` agregando inventário curto dos scripts da pasta (gates `Test-GeneXus*`, wrappers `Build/Invoke/Sync-GeneXus*`, etc.) para servir como ponto único de descoberta a partir da pasta `scripts/`.

**Por que foi descartada:**

A pasta `scripts/` é apoio operacional, não fonte normativa. Regra explícita do `README.md` raiz: "a pasta `scripts/` existe como apoio operacional, analítico e editorial compartilhavel, mas nao e fonte normativa da documentacao consolidada da raiz". Cada script tem dono lógico em uma skill:

- `Test-GeneXus*.ps1` de empacotamento → contratos em `xpz-builder/SKILL.md` e satélites `xpz-builder/responsibilities-by-type/*.md`
- `Sync-GeneXusXpzToXml.ps1`, `Invoke-GeneXusXpz*.ps1` → `xpz-sync` e `xpz-msbuild-import-export`
- `Build-KbIntelligenceIndex.{ps1,py}`, `Query-KbIntelligenceIndex.{ps1,py}` → já cobertos por `scripts/README-kb-intelligence.md` (README dedicado da trilha)
- `Build-GeneXusImportFileEnvelope.ps1`, `New-XpzImportPackage.{ps1,py}` → `xpz-builder` e `xpz-msbuild-import-export`

Um README agregado em `scripts/` duplicaria descrições já documentadas nas skills consumidoras, criando três caminhos para a mesma informação driftar: skill → README agregado → cabeçalho do próprio script. O custo de manutenção supera o ganho de descoberta para o público-alvo, que carrega skill primeiro e desce ao script depois.

Para descoberta a partir da raiz, `07-open-points-e-checklist.md` lista os gates determinísticos da Fase 9 do xpz-builder por nome de script, apontando o contrato de uso para a skill `xpz-builder`. Esse já é o ponto de entrada agregado mínimo, sem criar README terciário.

**Não reavaliar** salvo aparição de scripts órfãos sem skill consumidora documentando-os, ou mudança de público (consumo externo direto da pasta `scripts/` por agente que não carrega skill XPZ).

---

## Self-test de regressão com GUIDs Evo1 no catálogo compartilhado

**Origem:** avaliação de prompts externos (KB Evo1, GeneXus 18 U13, pasta paralela remota), 2026-05-30.

**O que era:** estender `Test-GeneXusUnknownTypeDiscoverySelfTest.ps1` (ou script irmão) com XML mínimo contendo os três `Object/@type` descobertos na Evo1 (`DataView`, `SmartDevicesApplication`, `SmartDevicesPlus`) e assert de que `Get-GeneXusUnknownObjectTypesFromExportFile` retorna zero tipos desconhecidos contra `scripts/gx-object-type-catalog.json` — regressão explícita do desbloqueio de sync XPZ/XML daquela KB.

**Por que foi descartada:**

O pedido operacional legítimo do agente remoto era **registrar tipos estáveis no catálogo upstream** (`gx-object-type-catalog.json`, linha em `01a-catalogo-e-padroes-empiricos.md`). Isso já foi atendido (commit `1866c52` e documentação associada). O self-test Evo1 seria camada diferente: fixture **acoplada a uma KB cliente** dentro de base metodológica **genérica** compartilhada.

Precedente do repositório: self-tests em `scripts/` validam **mecanismo e contrato** (ex.: detecção de tipo desconhecido com GUID fictício, override local, schema de `gx-platform-objects.json`), não replay de pacotes reais de KB específica. Evidência Evo1 permanece em `01a` e `09-inventario-e-rastreabilidade-publica.md`; não vira fixture permanente em código.

O risco que o teste Evo1 mitigaria — remoção acidental de entrada no JSON — é erro de **edição do catálogo**, não de lógica de descoberta (já coberta pelo self-test genérico). Um teste genérico de integridade do catálogo (GUIDs únicos, parse JSON, paridade opcional `01a`↔JSON) seria frente distinta e não KB-específica; não foi aberta nesta avaliação.

**Não reavaliar** na forma Evo1-fixture. **Reavaliar apenas** se surgir frente genérica de integridade do catálogo compartilhado (sem nomes de KB, sem snippets de pacote cliente) ou se o mesmo GUID estável reaparecer como bloqueio em **segunda KB independente** após regressão confirmada no upstream.

---

## Enfileiramento automático de MSBuild por KB

**Origem:** avaliação de prompt externo sobre múltiplas rodadas importação → build em pasta paralela de KB GeneXus, 2026-06-02.

**O que era:** substituir o bloqueio preventivo simples de concorrência por uma espera automática, retentativa em loop ou fila persistente para serializar execuções `MSBuild.exe` que tentem abrir a mesma KB.

**Por que foi descartada:**

O bloqueio preventivo simples já evita o risco principal: contenção de lock da KB quando outra execução MSBuild da mesma KB está ativa. O wrapper retorna `exitCode=46`, diagnostica o processo conflitante e preserva rastreabilidade suficiente para o agente decidir a próxima tentativa.

Espera automática com timeout ainda prenderia a sessão por tempo indefinido em KB grande e criaria novos estados operacionais para explicar à comunidade. Fila persistente exigiria daemon, lock próprio, recuperação de falhas e limpeza de jobs, aumentando bastante a superfície de manutenção para um caso que hoje se resolve melhor com parada clara e nova tentativa explícita.

**Não reavaliar** salvo evidência recorrente de múltiplas sessões independentes disputando a mesma KB com perda real de produtividade que não seja resolvida pelo bloqueio preventivo e pelo wrapper importação → build já existente.

---

## `config.sample.json` versionado + `config.json` no `.gitignore`

**Origem:** ideia importada por analogia com FBgx18MCP, onde havia `config.json`
versionado e ele foi substituído por `config.sample.json`.

**O que era:** separar configuração padrão versionada (`*.sample.json`) de
configuração local ignorada (`config.json`) para evitar commit acidental de
credenciais, strings de conexão ou caminhos sensíveis.

**Por que foi descartada:**

A investigação não encontrou `config.json` local versionado nem arquivo de
configuração sensível usado diretamente pelo repositório. Os `.json` versionados em
`scripts/` são catálogos ou fixtures.

O MCP de instruções globais do Cursor referencia `config.json`, mas esse arquivo é
gerado pelo instalador fora do repositório, em
`~/.cursor/xpz-global-instructions-mcp/config.json`, junto da cópia instalada de
`server.py`. O `server.py` canônico em `scripts/cursor-global-instructions-mcp/`
espera essa configuração apenas no diretório de instalação.

O `.gitignore` em whitelist já reduz commits acidentais na raiz, embora `scripts/`
continue aceitando JSONs versionados por design. Como não existe configuração local
sensível dentro da árvore versionada, a prática `config.sample.json` + `config.json`
ignorado não tem objeto concreto neste repositório.

**Não reavaliar salvo** criação futura de script ou serviço deste repositório que
passe a exigir arquivo de configuração local dentro da árvore versionada.

---

## CheckAndInstallDatabase

**Origem:** referência encontrada em fonte externa de código como sinônimo de Reorg,
avaliação de domínio Database, 2026-05-06.

**O que era:** task MSBuild citada como `<CheckAndInstallDatabase />`, sem parâmetros,
aparentemente equivalente headless da operação de Reorg, com semântica sugerida de
"verificar se o banco precisa de alterações e instalar somente se necessário".

**Por que foi descartada:**

Na instalação GeneXus 18 local investigada, `Genexus.MsBuild.Tasks.CheckAndInstallDatabase`
não existe no assembly `Genexus.MsBuild.Tasks.dll`. A task também não aparece nos
`UsingTask` de `Genexus.Tasks.targets` nem na reflexão do assembly.

As hipóteses restantes não sustentam uma frente implementável nesta base: pode ser
uma task de GeneXus Server, um target MSBuild não exposto como task de DLL, algo de
outra versão/extensão instalada, ou apenas um nome/alias externo sem correspondência
com task pública acessível.

**Não reavaliar salvo** se for identificado que a task existe em caminho acessível sem
GeneXus Server e se a semântica "check before install" for confirmada empiricamente
como diferente de `Reorganize` puro.

---

## CreateOfflineDatabase

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.

**O que era:** task MSBuild para gerar o banco SQLite local usado por aplicativos
Native Mobile com `Connectivity Support = Offline`. O SQLite gerado é artefato do
app/dispositivo e não altera o banco central da aplicação.

**Por que foi descartada:**

A necessidade é específica de KBs com Native Mobile Offline e pipeline headless de
build/deploy mobile. Para uso eventual, ou quando a geração/publicação mobile já passa
pela IDE do GeneXus, a opção da IDE atende sem exigir novo wrapper, nova documentação
e manutenção adicional nesta base XPZ.

O caso também não melhora o fluxo central deste repositório: importação/exportação
XPZ, empacotamento, validação de objetos e build web pós-import. O risco técnico da
task é contido, pois o SQLite é regenerável e não toca o banco servidor, mas o ganho
prático é baixo sem demanda concreta de automação mobile offline.

**Não reavaliar salvo** surgimento de KB concreta com Native Mobile Offline em que a
automação headless do build/deploy seja requisito real, ou solicitação explícita de
cobertura desse pipeline.

---

## Gate de lint para a regra UTF-8 sem BOM (02-regras-operacionais) na pré-push

**Origem:** bateria de teste de harnesses sobre a frente dos gates pré-push, 2026-06-06. Uma execução GPT-5.5 apontou que self-tests novos usavam `New-Object System.Text.UTF8Encoding($false)` inline em vez de `Get-Utf8NoBomEncoding`, contrariando a regra de reuso registrada em `02-regras-operacionais-e-runtime.md:1075` (com ponteiro no `09-inventario-e-rastreabilidade-publica.md`). Cogitou-se mecanizar essa checagem como gate consultivo "regra-de-doc ↔ implementação", no espírito de `Test-PrePushMsBuildProbeDocParity.ps1`.

**Por que foi descartada:**

Distinguir o **contexto de escrita** (deve usar o helper) do **contexto isento** que a própria regra permite (leitura/detecção de encoding, BOM deliberado, validação estrita de bytes) não é grep determinístico — exige rastrear a variável de encoding até seu uso (data-flow), frágil em PowerShell. Um lint ingênuo (flag em todo construtor) dispararia nos usos isentos legítimos → ruído.

O alvo também é o **meio**, não o **fim**: a regra existe para evitar BOM indevido em arquivo do repo. A violação concreta que motivou a ideia tinha impacto ~zero (self-tests escrevem fixtures em `Temp` descartáveis) e baixa frequência. Mecanizar o **fim** (BOM em arquivo commitado) seria mais preciso, mas a base já é amplamente consciente de BOM — provável redundância.

Decisão: corrigir os self-tests para usar `Get-Utf8NoBomEncoding` (feito) e **não** criar gate. Princípio geral: mecanizar só onde a fonte-de-verdade é derivável do código (caso do gate de paridade de enumeração), não convenções de fronteira de detecção suja.

**Não reavaliar salvo** evidência de recorrência frequente da violação em arquivos que produzam artefato commitado (não temp), caso em que um check de BOM-no-fim — não um lint do meio — seria a abordagem.

---

## Endurecer a mecânica da pré-push para garantir veredito correto de um revisor LLM único

**Origem:** cadeia de experimentos sobre o gate de propagação de termo novo (`Test-PrePushNewTokenPropagation.ps1`), 2026-06-07. Um gap real de propagação (lista de parâmetros gêmea que divergiu) passou por três passadas do mesmo modelo (Opus); um modelo distinto (MiniMax) o pegou por leitura.

**O que é:** a hipótese de que, refinando a mecânica do gate/orquestrador, dá para fazer um revisor LLM único (uma passada de um modelo) chegar ao veredito correto de forma confiável na fase semântica.

**O que foi tentado — entrou no repo, é útil, mas não resolve o veredito:**

- `mentionClass`: classificar cada candidata por forma (prose / param-list-item / param-table-cell / command-example), para o revisor não descartar lista-gêmea de parâmetros como se fosse prosa.
- Truncamento ciente de classe: não-prosa nunca truncada, para o sinal chegar completo mesmo numa frente que inunda a raiz de prosa.
- Bloco coercitivo (`nonProseVerdictRequired`) + livro-razão item a item obrigatório no `agentSemanticChecklist`, proibindo justificativa coletiva das não-prosa.

**Por que foi descartada (continuar endurecendo a mecânica):**

Cada passo tornou o sinal mais completo e mais forçado, mas o revisor único continuou falhando — e o modo de falha apenas se deslocou:

1. Antes da classe: descarte em lote (passadas Opus varreram a candidata legítima junto com a prosa, sob justificativa coletiva).
2. Com classe + sem truncamento: omissão por saliência (o Opus pegou um `param-list-item` saliente e nem mencionou outro igualmente sinalizado em subpasta).
3. Com o livro-razão coercitivo: **racionalização** — o Opus confrontou as não-prosa uma a uma (processo correto) mas se convenceu de «justificado» em cada, inclusive **revertendo** um veredito antes correto. Resultado pior: 0 gaps confirmados.

Forçar exaustividade num único modelo desloca a falha de *omitir* para *confrontar-e-racionalizar* — mais difícil de detectar porque parece diligência. A camada mecânica fez o que podia (sinal completo, ledger forçado, fail-safe que recomenda diversidade), mas não há como mecanicamente obrigar um único LLM a um veredito correto: ele produz justificativas plausíveis. **A diversidade de modelo é o backstop real** — só um modelo distinto pegou os gaps. Por isso a salvaguarda de diversidade do `13` foi promovida de reserva para recomendada-acima-de-limiar, e a engenharia mecânica foi encerrada por decisão nesta frente.

**Não reavaliar salvo** evidência de uma técnica mecânica que comprovadamente eleve a *correção do veredito* (não apenas a exaustividade do processo) de um revisor de modelo único. A direção produtiva é operacionalizar a diversidade de modelo, não refinar mais o gate.

---

## Surfaçar `Edit-GeneXusXmlSurgical` na skill `xpz-msbuild-import-export`

**Origem:** prompt de agente externo de pasta paralela de KB (relato de adicionar botões e remover marcadores de teste no source de eventos de um `WebPanel`), avaliado na sessão 2026-06-08. O pedido original era surfaçar `scripts/Edit-GeneXusXmlSurgical.ps1` como caminho canônico de edição cirúrgica de source "nas skills `xpz-builder` **e** `xpz-msbuild-import-export`".

**O que é:** documentar/referenciar o helper de edição cirúrgica de source dentro da skill `xpz-msbuild-import-export`, para o agente não cair em edição ad-hoc por número de linha ao precisar ajustar o `Source` de um objeto.

**Por que foi descartada (apenas a parte do `xpz-msbuild-import-export`):**

Editar `Source`, `Rules` ou `CDATA` de um objeto de KB pertence ao escopo do `xpz-builder` — a skill que cria e edita o XML do objeto antes do empacotamento. Lá o helper já está surfaçado como caminho padrão, com a explicação de por que não usar a ferramenta Edit do harness em XML longo. A `xpz-msbuild-import-export` orquestra import/export de pacotes XPZ via `MSBuild`; não edita source de objeto — quando ela entra em cena, o pacote já foi montado pelo `xpz-builder`. Surfaçar o helper ali significaria a skill se meter no escopo de outra.

Há ainda colisão terminológica: a `xpz-msbuild-import-export` já usa "cirúrgico" para designar export seletivo nominal (`-ObjectList`, "pacote cirúrgico"). Introduzir o "helper de edição cirúrgica de source" na mesma skill faria a palavra significar duas coisas distintas, com risco concreto de confusão para o público-alvo (usuários GeneXus que dependem do bom comportamento do agente).

**O que foi feito em vez disso (Opção 2a da avaliação):** acrescentou-se uma única linha de fronteira no bloco `Do NOT use esta skill para` do `xpz-msbuild-import-export`, demarcando que editar/ajustar o `Source`, `Rules` ou `CDATA` de um objeto pertence ao `xpz-builder` — sem documentar o "como" e sem usar a palavra "cirúrgico". A `xpz-builder` permanece a sede única do `Edit-GeneXusXmlSurgical`.

**Não reavaliar salvo** evidência de um fluxo real em que a edição de source precise ocorrer dentro da própria orquestração de import/export — o que hoje não é o caso, já que o pacote chega ao import-export já montado pelo `xpz-builder`.

## Preflight único — um script que roda todos os gates de empacotamento de uma vez

**Origem:** avaliação do lote de 4 gaps do relato CPJAPP (2026-06-10), recomendação 3 ("criar um preflight único de pacote para frentes GeneXus com Source: SourceSanity + ObjectVariableDelta + BatchDependencyOrdering + PackageInventory + busca de padrões rejeitados pela KB"). Era a "Frente C" do lote.

**O que era:** um único script orquestrador que rodasse, numa só chamada, o subconjunto de gates determinísticos relevantes para uma frente com `Source`, em vez de o agente invocar cada gate separadamente. Dor declarada: o agente pode esquecer de rodar algum gate.

**Por que foi descartada:**

1. **O WORKFLOW do `xpz-builder` já é o preflight.** Os gates da Fase 9 (`9-BC`, `9-WW`, `9-TWS`, `9-TXW`, `9-PNW`, `9-IDO`, `9-FD`) já estão sequenciados com gatilho condicional por delta ("run before any packaging **when** the batch contains X"), com invocação exata e tratamento pass/warn/fail. Um agente que segue a skill já roda exatamente o subconjunto certo. O risco "esquecer um gate" é, no essencial, questão de seguir o WORKFLOW — não falta de ferramenta.

2. **Risco de drift por duplicação da lógica condicional.** Cada gate só se aplica a certos deltas (Transaction, Procedure, 2+ objetos, etc.). Um runner que "roda tudo" ou geraria ruído de `not-applicable`, ou teria que replicar a tabela de gatilhos do WORKFLOW — passando a existir a mesma regra em dois lugares (skill + script), que mais cedo ou mais tarde divergem. É o mesmo motivo da entrada "Índice geral em `scripts/` (README agregado)" descartada acima: `scripts/` é apoio operacional, não fonte normativa; a sede da regra é a skill consumidora.

3. **Contratos heterogêneos dos gates.** Os gates pedem entradas não-uniformes (`-FrontFolder`+`-CorpusFolder`, `-InputPath` por arquivo, `-TransactionPath`, `-VariableName`, iteração por XML). Um orquestrador único precisaria de uma camada de tradução/marshaling complexa para pouco ganho sobre a chamada direta guiada pelo WORKFLOW.

**Relação com o "Manifesto semântico de pacote" (999):** a ideia *sancionada* de "agregar os gates" é o manifesto — mas é o lado **output** (artefato de auditoria que consolida os resultados estruturados dos gates), não um runner que os executa, e está bloqueado até haver gate upstream em uso e decisões editoriais fechadas. Se um dia fizer sentido um braço de execução, ele nasce como mecanismo do manifesto, não como orquestrador separado.

**Não reavaliar salvo** aparição de um fluxo real de **wrapper local de KB** em que o agente **não** carregue a skill `xpz-builder` (e portanto não tenha o WORKFLOW como roteiro), tornando um runner fino local útil para reduzir comandos compostos — caso em que ele seria um wrapper local recomendado pelo `xpz-kb-parallel-setup`, não um script compartilhado novo.

---

## Hook `PreToolUse` que barra comando não-atômico (enforcement negativo)

**Origem:** sessão de 2026-06-22 sobre redução de prompts de autorização. Proposta de outro
agente, follow-on do item URGENTE «Reduzir as variações de chamada dos adapters» (resíduo (b2) em
`999`). Avaliada e **descartada por revisão por pares** — painel de 5 revisores, 3 famílias
(Claude/Opus nativo, Codex/gpt-5.5, ollama-cloud `deepseek-v4-pro`/`glm-5.2`/`kimi-k2.7-code`),
convergência **unânime** pelo descarte.

**O que era:** um hook `PreToolUse` em `~/.claude/settings.json` que interceptasse comandos
Bash/PowerShell e **barrasse** (`deny`) ou **avisasse** (`ask`) os não-atômicos (pipe `|`, `;`,
`&&`/`||`, substituição `$()`/`(Get-Content)`, heredoc) **antes** do matcher da allowlist —
enforcement mecânico **negativo** da disciplina de invocação atômica.

**Escopo do descarte (preservar na redação):** descarta-se **a polaridade NEGATIVA/bloqueadora**,
não o mecanismo `PreToolUse` em si nem a ideia de reduzir prompts. A **polaridade POSITIVA** — um
hook que **auto-aprova** comandos read-only seguros, reduzindo prompts — segue **viva** como frente
própria (ver `999`, «Hook PreToolUse positivo (auto-allow)» e
`claude-code-pretooluse-auto-allow-design.md`). Citar sempre "hook negativo / `deny` de comando
não-atômico", nunca "hook PreToolUse" genérico — `deny` e `allow` saem do **mesmo** mecanismo.

**Por que foi descartada:**

1. **Não cumpre o objetivo real.** O objetivo é reduzir prompts; um `deny` não reduz — bloqueia a
   chamada e força o agente a reformular e tentar de novo, trocando um prompt por um turno perdido.
   Pior: o agente tende a reatentar com variação cosmética, multiplicando turnos.

2. **Maior risco de falso-positivo, com evidência concreta.** A allowlist do Claude Code já contém
   **compostos legítimos** mantidos de propósito pelo usuário (ex.: entrada com `&&` para
   `git -C "C:/Dev/Prod/Gx_*" add * && git*`). Um barrador cego de compostos quebraria configuração
   curada. Para evitar a colisão, a regra negativa teria que reimplementar a allowlist dentro do
   hook — duplicação acoplada e frágil.

3. **Dor já mitigada na origem.** As partes (a) `-MessagePath` e (b1) forma canônica documentada já
   endereçaram a deriva de comandos compostos onde importa (delegação via adapters). O resíduo (b2)
   é housekeeping local, classificado como baixo/opcional no `999`. Enforcement negativo para
   resíduo opcional é desproporcional.

4. **Acoplamento ruim, não viaja.** O hook viveria em `~/.claude/settings.json` (máquina-local,
   fora de qualquer repositório git — confirmado empiricamente na sessão). Não se propaga para
   Codex/Cursor/OpenCode nem para outras máquinas; não é solução de repositório de skills.

5. **A polaridade útil é a positiva.** `permissionDecision: allow` reduz prompts de forma alinhada
   ao objetivo; `deny` faz o oposto. A sub-variante **"avisa/`ask`"** também foi avaliada e
   descartada: não reduz prompt (adiciona ruído) e é redundante com a frente positiva, que já cobre
   o caso comum (o resíduo ambíguo continua caindo no prompt normal da allowlist).

**Não reavaliar salvo** surgimento de um objetivo distinto de "reduzir prompts" — por exemplo, uma
necessidade explícita de **auditoria/treinamento** de disciplina de comando (modo diagnóstico
não-bloqueante), que seria uma frente diferente (observabilidade local), não bloqueio operacional —
e mesmo nesse caso o ponto de observação já existiria no hook positivo.
