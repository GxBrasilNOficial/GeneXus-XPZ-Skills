# 02 - Regras Operacionais e Runtime
## Papel do documento
operacional

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md, 03-risco-e-decisao-por-tipo.md

## Usado por
04-webpanel-familias-e-templates.md, 05-transaction-familias-e-templates.md, 08-guia-para-agente-gpt.md

## Objetivo
Consolidar regras de geracao, clonagem conservadora, materializacao, serializacao XPZ e uma camada explicita de ligacao entre estrutura XML observada e comportamento provavel de runtime GeneXus.

## Fontes consolidadas
- 02-genexus-xpz-generation-rules.md
- 20-guia-de-clonagem-segura.md
- 24-resumo-operacional-para-gerador-xpz.md
- documentacao oficial GeneXus usada de forma complementar e controlada

## Premissas operacionais

- `Evidência direta`: esta base continua sendo centrada em XML extraido de `XPZ`, nao em logs completos de especificacao, importacao, build ou execucao.
- `Regra documentada`: conceitos como `Base Table`, `Extended Table`, navegacao de `For each`, `Load`, `Refresh` e `Refresh Grid` pertencem ao runtime/especificacao do GeneXus e nao podem ser inferidos apenas da forma do XML.
- `Inferência forte`: certos sinais estruturais do XML permitem falar em risco runtime relativo, desde que a fala seja qualificada e nao prometa comportamento real sem teste.
- `Hipótese`: quanto mais denso o objeto em `events`, `grid`, `Level`, `AttributeProperties`, `parent`, `pattern` e links contextuais, maior tende a ser a sensibilidade a navegacao, carga de dados e comportamento nao trivial em execucao.

## Achados empiricos da trilha experimental via MSBuild

- `Evidência direta`: na instalacao validada nesta frente, a task `Genexus.MsBuild.Tasks.Import` expos publicamente `PreviewMode`, `IncludeItems` e `ExcludeItems`.
- `Evidência direta`: na mesma instalacao, a task `Import` nao expos `UpdateFile` nem `ImportKBInformation` como propriedades publicas configuraveis.
- `Regra operacional`: em automacao headless via `MSBuild`, o agente nao deve assumir que parametros documentados offline estao disponiveis na task efetivamente carregada; deve validar a assinatura real antes de emitir parametros sensiveis.
- `Regra operacional`: quando a base compartilhada ganhar um parametro operacional relevante, isso nao autoriza presumir que wrappers locais ou adaptadores da pasta paralela da KB ja o exponham; a exposicao local e decisao separada e pode estar defasada
- `Regra operacional`: ao encontrar essa defasagem local, o agente deve tratar o caso como oportunidade de adaptacao local, sinalizar a sugestao ao usuario e aguardar aprovacao explicita; a ausencia de exposicao local nao e erro por si so
- `Regra operacional`: wrapper recomendado para fluxo local de geracao/empacotamento, como `Test-*KbSourceSanity.ps1`, nao vira automaticamente wrapper minimo universal de materializacao oficial ou de `KbIntelligence`; a obrigatoriedade depende do fluxo realmente adotado pela pasta paralela da KB
- `Evidência direta`: `PreviewMode` foi validado operacionalmente com `XPZ` real nesta frente, sem alteracao real da KB.
- `Evidência direta`: `IncludeItems` e `ExcludeItems` tiveram efeito operacional observavel em `PreviewMode` nesta instalacao.
- `Regra operacional`: quando `IncludeItems` ou `ExcludeItems` receberem multiplos recortes, o wrapper deve normalizar a entrada como lista e serializar no formato aceito operacionalmente pela task carregada, em vez de repassar uma unica string composta.
- `Regra operacional`: quando houver diagnostico estruturado de preview headless, `importedItems` deve permanecer lista mesmo quando so um item for retornado.
- `Regra operacional`: quando a task `Genexus.MsBuild.Tasks.Import` nao expuser `UpdateFile` nem `ImportKBInformation`, o wrapper deve bloquear cedo esses parametros quando explicitamente pedidos.
- `Regra operacional`: wrappers e scripts permanentes ficam em `scripts`; artefatos efemeros de execucao, logs auxiliares e diretorios temporarios de rodada devem preferir `Temp`.
- `Regra operacional`: em trilha `MSBuild`, distinguir sempre `sucesso operacional da chamada`, `preview apenas` e `confirmacao funcional posterior na IDE`.
- `Evidência direta`: a IDE do GeneXus permite selecionar objetos modificados depois de uma data/hora antes de exportar, mas o `XPZ` resultante nao preserva a condicao do filtro; ele contem apenas os objetos selecionados e seus `lastUpdate`.
- `Evidência direta`: na instalacao validada, a task `Export` expos publicamente `ExportAtTimestamp`, mas chamadas headless com esse parametro falharam dentro da task, enquanto exportacoes equivalentes por `Objects` explicito concluiram com sucesso e geraram o mesmo conjunto de objetos observado no `XPZ` parcial da IDE.
- `Regra operacional`: ate haver evidencia contraria, a exportacao headless via `MSBuild` nao deve ser tratada como capaz de filtrar objetos por data de modificacao; para exportacao parcial, o caminho validado e fornecer explicitamente a lista de objetos em `Objects`/`ObjectList`.
- `Regra operacional`: depois que os recortes passarem a funcionar de forma confiavel, erro residual de `Source`, `Specification` ou referencia nao resolvida em objeto importado deve ser tratado como problema de conteudo da KB/`XPZ`, nao como problema de envelope ou do wrapper, salvo evidencia contraria.

## Metadado da KB no sync parcial

- `Regra operacional`: um `XPZ` parcial pode ser valido para sync de objetos mesmo quando `Source` vier vazio, incompleto ou ausente.
- `Regra operacional`: esse mesmo `XPZ` pode ser insuficiente para refresh completo de `kb-source-metadata.md`; nesses casos, o fluxo deve preservar os valores estaveis previamente conhecidos em vez de sobrescrever campos com vazio.
- `Regra operacional`: campos vazios ou incompletos do pacote novo nao podem apagar `Source/@kb`, `Source/@username`, `Source/@UNCPath`, `Source/Version/@guid` ou `Source/Version/@name` quando houver baseline estavel anterior.
- `Regra operacional`: se o pacote novo trouxer todos esses valores completos e validos, o refresh de metadado pode seguir normalmente.
- `Regra operacional`: o caso deve produzir warning claro separando `sync de objetos aceito` de `refresh de metadado parcial`.
- `Regra operacional`: `kb-source-metadata.md` deve expor `last_xpz_materialization_run_at` como horario da ultima solicitacao/processamento de materializacao XPZ/XML, mesmo quando nao houver mudanca material nos XMLs.

## Frescor do indice derivado da KB

- `Regra operacional`: `KbIntelligence\kb-intelligence.sqlite` deve expor `last_index_build_run_at` na tabela `metadata` como horario da ultima solicitacao/processamento de geracao do indice, mesmo quando o conteudo resultante for equivalente ao anterior.
- `Regra operacional`: todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize ou atualize XMLs em `ObjetosDaKbEmXml` deve acionar compulsoriamente a regeneracao/validacao do indice derivado logo depois da materializacao.
- `Regra operacional`: quando a pasta paralela adotar `KbIntelligence`, o agente so deve considerar o fluxo de `sync` normal como compativel se houver evidencia clara, na documentacao local ou no proprio wrapper local, de que o wrapper de materializacao encadeia esse refresh compulsorio do indice.
- `Regra operacional`: na ausencia dessa evidencia clara, o agente deve tratar o caso como compatibilidade operacional pendente da pasta paralela, bloquear o `sync` normal e oferecer atualizacao via setup antes de seguir.
- `Regra operacional`: o indice esta apto para triagem ampla quando `last_index_build_run_at` for igual ou posterior a `last_xpz_materialization_run_at` lido nominalmente em `kb-source-metadata.md`.
- `Regra operacional`: quando `AGENTS.md` ou `README.md` locais declararem timestamps, estado operacional ou observacoes de frescor da pasta paralela da KB, esses campos devem ser tratados como memoria auxiliar e precisam permanecer coerentes com `kb-source-metadata.md`, com `-Query index-metadata` do wrapper local e com o gate efetivo; drift documental local e pendencia operacional real, nao detalhe cosmetico
- `Regra operacional`: se o indice estiver ausente, sem metadado, mais antigo que a ultima materializacao XPZ/XML, se `kb-source-metadata.md` estiver ausente ou se esse arquivo nao expuser literalmente `last_xpz_materialization_run_at`, o agente nao deve consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, e tambem nao deve gerar objetos para importacao na KB pela IDE.
- `Regra operacional`: o agente nao deve substituir `last_xpz_materialization_run_at` por data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatorio ou outro metadado aproximado.
- `Regra operacional`: indice ausente ou defasado e excecao operacional, tipicamente de pasta paralela ainda sem wrappers XPZ atualizados ou de falha fortuita; o agente deve bloquear pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML oficial de objeto e geracao, oferecendo ao usuario a atualizacao do indice antes de seguir.
- `Regra operacional`: em pasta que adota `KbIntelligence`, o agente nao deve apresentar `sync` seguido de regeneracao manual separada do indice como fluxo normal; esse desenho so e aceitavel como etapa consciente de reparo/compatibilidade aprovada pelo usuario.
- `Regra operacional`: com gate de indice bloqueado, leitura pontual so e aceitavel para diagnostico minimo da incompatibilidade em documentacao local, estrutura, wrappers e metadados operacionais; nao montar, testar existencia, listar ou abrir caminho de XML oficial de objeto para responder pergunta de negocio.
- `Regra operacional`: o gate do indice deve ser sequencial e atomico; nao testar, listar ou abrir caminho filho de uma camada antes de validar a camada pai, como `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`.
- `Regra operacional`: se o wrapper local documentado de consulta do indice estiver ausente, nao listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup.

## Evidencia complementar de gerador local

- `Evidência direta`: a pasta local `C:\Dev\Test\from-anywhere-to-GeneXus` contem um gerador simplificado que monta XML de importacao GeneXus usando um envelope com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: nesse gerador local, o `README` e o script principal apontam para geracao de `import_file.xml` e importacao direta do XML, nao para empacotamento `.xpz` zipado real.
- `Inferência forte`: essa fonte local serve como confirmacao secundaria de envelope minimo plausivel e do formato de `ObjectIdentity`, mas nao como autoridade principal para valores concretos de producao.
- `Inferência forte`: o gerador local reforca a decisao de manter `KnowledgeBase` e `Settings` fora do formato normal de objetos.
- `Hipótese`: valores hardcoded dessa fonte local, como `Build=0`, `username="root"`, `SampleKB`, `BusinessLogic`, `parentGuid` fixo e `moduleGuid` fixo, podem levar o agente para caminho errado se forem tratados como regra geral.
- `Evidência direta`: um `.xpz` minimo de `Procedure`, montado nesta trilha com `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, foi importado com sucesso no GeneXus quando `Source/@kb` e `Source/Version/@guid` estavam em formato GUID valido.

## Envelope XPZ observado em export real

- `Evidência direta`: no export real inspecionado nesta trilha, o arquivo `.xpz` continha um unico XML principal com raiz `<ExportFile>`.
- `Evidência direta`: no export full observado, os blocos de primeiro nivel foram `KMW`, `Source`, um bloco especial de KB, `Objects`, `Attributes` e `Dependencies`, nessa ordem.
- `Evidência direta`: o bloco `KMW` observado continha `MajorVersion`, `MinorVersion` e `Build`.
- `Evidência direta`: em um export completo observado nesta trilha, o bloco top-level `<Objects>` continha `7219` nos `<Object>`.
- `Regra editorial`: esse `7219` descreve aquele envelope/export observado e nao deve ser lido automaticamente como total do inventario publico atual, cuja rastreabilidade agregada fica em `09-inventario-e-rastreabilidade-publica.md`.
- `Evidência direta`: apos o fechamento do bloco top-level `<Objects>`, o envelope observado seguiu com `<Attributes>`, depois `<Dependencies>`, e por fim `</ExportFile>`.
- `Inferência forte`: para esta base, a forma mais segura de pensar um XPZ e "envelope `<ExportFile>` com secoes top-level recorrentes", e nao "arquivo `Objects.xml` isolado" sem prova local.
- `Evidência direta`: no lote amplo de `.xpz` reais, o formato normal mais frequente nao traz bloco especial de KB; esse bloco aparece apenas em exportacoes especiais/full e em variacoes antigas de mudanca de versao.
- `Hipótese`: outros formatos de export GeneXus 18 podem existir; esta base so prova o envelope observado acima.
- `Evidência direta`: no lote amplo de `.xpz` reais, tambem apareceu pacote valido sem itens exportaveis materializaveis no acervo final.
- `Regra operacional`: pacote sem itens exportaveis nao deve ser classificado automaticamente como falha de leitura; a interpretacao correta depende do recorte de export efetivamente aceito pela IDE.
- `Regra operacional`: quando houver relatorio de execucao, distinguir explicitamente entre `no-exportable-items` e erro real de leitura, mapeamento ou verificacao.
- `Evidência direta`: no acervo amplo analisado, todos os XMLs individualizados continham `lastUpdate` presente e parseavel no elemento raiz.
- `Regra operacional`: quando o acervo individualizado e o pacote processado tiverem `lastUpdate` valido, usar esse campo como protecao contra regressao de ordem de processamento.
- `Regra operacional`: item vindo de pacote mais antigo nao deve sobrepor em disco um XML individualizado com `lastUpdate` mais novo; nesse caso, o processamento deve marcar o item como ignorado por obsolescencia, nao como falha de leitura.
- `Evidência direta`: em importacao real de `Attribute`, a KB preservou o `lastUpdate` do XML como `Modified Date`, independentemente do `Import Date`.
- `Regra operacional`: ao gerar ou alterar XML de objeto GeneXus, preencher `lastUpdate` com o instante real da gravacao, obtido do relogio local atualizado do ambiente que produz o XML.
- `Regra operacional`: toda regravacao de XML gerado localmente deve atualizar `lastUpdate` para o instante real da ultima escrita.
- `Regra operacional`: quando o XML serializar `lastUpdate` em UTC com sufixo `Z`, converter corretamente a partir do horario local real; nao reutilizar timestamp antigo, aproximado ou herdado de rodada anterior.
- `Regra operacional`: em pacote de importacao, somente o objeto efetivamente alterado deve receber `lastUpdate` novo; objetos apenas reenviados para fechamento de dependencias devem manter o `lastUpdate` original do XML da KB.
- `Regra operacional`: em XMLs GeneXus parecidos, nao assumir que a mesma insercao vai casar em todos os objetos; confirmar o trecho exato em cada arquivo antes de aplicar a mesma edicao.
- `Regra operacional`: depois de regravar XML local, validar no arquivo final tanto o `lastUpdate` quanto a presenca real dos nos inseridos no ponto esperado.
- `Regra operacional`: em XMLs GeneXus com blocos repetidos ou muito parecidos, localizar e validar cada ocorrencia antes de aplicar a mesma edicao.
- `Regra operacional`: depois de editar XML local, validar nao so se o XML abre, mas se os nos novos aparecem em todos os pontos funcionais esperados do objeto, especialmente em `Transaction` e `WorkWithWeb`.

### Gravacao segura de XML grande

- `Regra operacional`: XML GeneXus grande, especialmente `Procedure` com `Source` extenso ou blocos `CDATA`, nao deve ser tratado como valido apenas porque o comando de escrita terminou sem erro fatal.
- `Regra operacional`: depois de gerar XML grande, reler cabecalho, cauda do arquivo e bloco funcional afetado antes de qualquer empacotamento.
- `Regra operacional`: a validacao minima e: XML bem-formado, raiz esperada fechada (`</Object>` ou `</ExportFile>`), `lastUpdate` conferido quando aplicavel, `CDATA` encerrado e ausencia de linha final truncada.
- `Regra operacional`: se a geracao usar heredoc, here-string ou mecanismo equivalente e o stderr indicar delimitador encerrado por EOF, como `here-document ... delimited by end-of-file`, o artefato deve ser tratado como corrompido e descartado para regeneracao controlada.
- `Regra operacional`: para XML grande, preferir serializacao estruturada, script dedicado ou gravacao em arquivo temporario seguida de validacao e troca atomica; escrita em blocos so e aceitavel quando a validacao final do arquivo completo for obrigatoria.
- `Regra operacional`: quando houver tamanho, quantidade de linhas ou fechamento estrutural esperado por molde comparavel, usar esses sinais como alerta de truncamento; divergencia relevante bloqueia empacotamento ate reinspecao.

### Gate de sanidade do `Source` GeneXus antes do empacotamento

- `Regra operacional`: antes de gerar `import_file.xml` ou outro pacote importavel, diferenciar explicitamente `XML bem-formado` de `objeto provavelmente importavel`.
- `Regra operacional`: `XML bem-formado` cobre parse XML, raiz fechada, `CDATA` encerrado, `lastUpdate` conferido quando aplicavel e ausencia de truncamento evidente.
- `Regra operacional`: `objeto provavelmente importavel` exige tambem um gate minimo de sanidade do `Source` GeneXus para objetos cujo comportamento principal vive no `Source`, especialmente `Procedure`, `DataProvider` e casos comparaveis.
- `Regra operacional`: o gate minimo de sanidade do `Source` deve conferir pelo menos o balanceamento estrutural basico dos pares realmente tocados pela mudanca, como `Sub/EndSub`, `For each/EndFor`, `Do Case/EndCase` e `If/EndIf`.
- `Regra operacional`: quando a mudanca inserir ou mover bloco em `Source` grande, revisar o trecho alterado junto com algumas linhas antes e depois, incluindo os fechamentos ao redor.
- `Regra operacional`: em objeto grande ou sensivel, preferir delta minimo, sintaxe conservadora e reaproveitamento do estilo sintatico ja dominante no proprio objeto.
- `Regra operacional`: se o bloco novo tiver analogia local clara no mesmo objeto, comparar com esse bloco irmao para copiar forma sintatica, distribuicao de quebras de linha e padrao de fechamento, sem transformar o estilo local em regra funcional universal.
- `Regra operacional`: quando a mudanca inserir novo `Case` em um `Do Case` de `Source` que dependa materialmente de `parm(...)`, revisar os `Case` irmaos do mesmo bloco antes de aceitar o delta.
- `Regra operacional`: nessa revisao de `Do Case`, conferir se os parametros de entrada relevantes, esperados pelo padrao local do bloco, aparecem de forma coerente no novo ramo; ausencia de parametro comparavelmente esperado exige justificativa explicita.
- `Regra operacional`: se o novo `Case` divergir do padrao local dos ramos irmaos sem justificativa explicita, bloquear o delta em vez de aceitar branch hardcoded ou sustentado apenas por analogia fraca.
- `Regra operacional`: sinais como `elseif`, `iif(...)`, condicao nova excessivamente densa ou chamada de funcao/procedure dentro da condicao devem entrar como alerta consultivo de conservadorismo, nao como erro funcional universal.
- `Regra operacional`: quando um alerta consultivo aparecer em trecho novo e a base metodologica nao sustentar claramente aquela forma, preferir reescrever para a forma mais conservadora documentada antes do empacotamento.
- `Regra operacional`: falha em balanceamento estrutural basico do `Source` bloqueia empacotamento.
- `Regra operacional`: alerta consultivo isolado nao bloqueia automaticamente, mas deve ser registrado como risco e resolvido quando o trecho ainda estiver sustentado apenas por plausibilidade.
- `Regra operacional`: cheque automatizado leve de `Source`, quando existir no repositório, deve ser tratado como apoio de triagem e nao como prova completa de importabilidade.

### Conferencia auditavel de `lastUpdate`

- `Regra operacional`: gravou ou regravou XML local de objeto, releia o arquivo salvo antes de seguir.
- `Regra operacional`: a conferencia minima obrigatoria e: cabecalho final lido, `lastUpdate` confirmado e decisao registrada entre `objeto alterado` versus `objeto nao alterado`.
- `Regra operacional`: objeto realmente alterado deve sair com `lastUpdate` novo do instante real da ultima escrita.
- `Regra operacional`: objeto reenviado apenas por dependencia ou composicao de pacote deve preservar o `lastUpdate` oficial do XML da KB.
- `Regra operacional`: empacotamento nao deve prosseguir enquanto o `lastUpdate` do arquivo final nao tiver sido conferido no proprio XML salvo.

## Topologia operacional do workspace

- `Regra operacional`: a pasta nativa da KB e area proibida para gravacao por agentes; leitura e permitida apenas quando o fluxo operacional explicito realmente exigir.
- `Regra operacional`: `ObjetosDaKbEmXml` e o snapshot oficial da KB e deve ser tratado como somente leitura para agentes.
- `Regra operacional`: agente nunca pode criar, alterar, mover, renomear ou sobrescrever arquivos em `ObjetosDaKbEmXml`.
- `Regra operacional`: a unica origem oficial de atualizacao de `ObjetosDaKbEmXml` e o script `.ps1` do fluxo de sincronizacao alimentado por `XPZ` exportado pela IDE.
- `Regra operacional`: `KbIntelligence` e a pasta do indice SQLite derivado e regeneravel a partir de `ObjetosDaKbEmXml`; ela serve para triagem e nao substitui o snapshot oficial.
- `Regra operacional`: XML gerado, clonado ou ajustado localmente nunca deve ser tratado como se ja fosse snapshot oficial da KB.
- `Regra operacional`: `ObjetosGeradosParaImportacaoNaKbNoGenexus` e a area de trabalho para XMLs gerados, clonados, ajustados ou preservados para importacao manual na IDE.
- `Regra operacional`: `PacotesGeradosParaImportacaoNaKbNoGenexus` e a area de saida para `import_file.xml` e demais pacotes gerados localmente.
- `Regra operacional`: na area ativa de `ObjetosGeradosParaImportacaoNaKbNoGenexus`, os XMLs candidatos do lote devem ficar juntos na raiz da subpasta ativa da frente, sem subpastas por tipo, salvo regra local explicita do repositorio.
- `Regra operacional`: agente nunca deve criar subpastas por tipo automaticamente em `ObjetosGeradosParaImportacaoNaKbNoGenexus`.
- `Regra operacional`: agente nunca deve mover XMLs para `ArquivoMorto` sem pedido explicito do usuario.
- `Regra operacional`: quando houver conflito entre habito anterior do agente e documentacao local do repositorio, a documentacao local prevalece.
- `Regra operacional`: ao referenciar qualquer objeto GeneXus do acervo local, identificar sempre `tipo + nome`; nunca operar apenas pelo nome isolado.
- `Regra operacional`: o tipo do objeto determina a pasta esperada no acervo (`Procedure`, `Transaction`, `WebPanel`, `Attribute` e correlatas) e deve ser confirmado antes de qualquer leitura, comparacao, clonagem, ajuste ou empacotamento.
- `Regra operacional`: o mesmo nome pode existir simultaneamente em tipos diferentes; antes de agir sobre um objeto, confirmar em qual pasta o arquivo realmente existe no acervo local.
- `Regra operacional`: agente nao deve inferir tipo de objeto apenas por contexto funcional, nome parecido ou conversa anterior; a pasta real e a evidência direta minima para localizar o artefato correto.
- `Regra operacional`: ao concluir o setup inicial da pasta paralela da KB, o agente deve distinguir explicitamente `estrutura pronta` de `snapshot oficial ainda nao materializado`.
- `Regra operacional`: ao concluir o setup inicial, o agente deve oferecer `A)` exportacao de `.xpz` full pela IDE para `XpzExportadosPelaIDE` ou `B)` geracao do `.xpz` full a partir da pasta nativa da KB via trilha `MSBuild`, seguida de materializacao dos XMLs.
- `Regra operacional`: no fechamento do setup inicial, `A)` deve ser apresentado como caminho preferencial e normalmente mais rapido; `B)` deve ser apresentado como caminho possivel, porem mais lento por depender da trilha via `MSBuild`.

## Compatibilidade de `Source`

- `Regra operacional`: validar compatibilidade de funcao, assinatura e tipo primeiro pela metodologia desta trilha e pela semantica GeneXus consolidada em `nexa`; a KB local entra como reforco apenas quando os exemplos metodologicos nao cobrirem o caso.
- `Regra operacional`: nao exigir busca ampla no acervo inteiro da KB como padrao para validar um `Source`; se a base metodologica ja cobrir o padrao, ela prevalece.
- `Regra operacional`: quando a cobertura vier apenas de melhor esforco, declarar explicitamente que a compatibilidade nao esta garantida e elevar o risco metodologico.

### Gramatica operacional para `Procedure` de relatorio

- `Regra operacional`: em `Procedure` de relatorio simples, o fluxo primario deve partir de molde sanitizado documentado da trilha antes de escalar para XML real comparavel.
- `Regra operacional`: a cobertura primaria barata desta trilha vale para relatorio simples das familias `F2` e `F3`, desde que o shape completo esteja documentado em molde sanitizado suficiente e marcado como `molde pronto` na trilha.
- `Regra operacional`: em `Procedure` de relatorio, separar sempre tres camadas antes de corrigir ou gerar: `Source`, `Rules` e layout.
- `Regra operacional`: `Source` e a camada de fluxo procedural; nela entram `Header`, `Footer`, `For each`, `print printBlock...`, `Output_file` e logica de preparacao de variaveis.
- `Regra operacional`: `Rules` e a camada de assinatura/regra; nela entram `parm(...)` e regras proprias dessa camada, nao `print`, `For each`, `Header`, `Footer` nem shape de layout.
- `Regra operacional`: o layout do `Part` `c414ed00-8cc4-4f44-8820-4baf93547173` e a camada estrutural de `Bands`, `PrintBlock`, `ReportLabel` e `ReportAttribute`; nao deve receber pseudo-`Source` procedural.
- `Regra operacional`: `RPT_INTERNAL_NAME`, identificadores de `PrintBlock` e referencias usadas em `print printBlock...` devem permanecer coerentes entre `Source` e layout.
- `Regra operacional`: em relatorio simples, a falta de XML real da KB nao bloqueia o primeiro prototipo quando a trilha ja oferecer molde sanitizado canonico suficiente.
- `Regra operacional`: escalar para XML real comparavel apenas quando o pedido fugir da cobertura simples, quando a tentativa inicial mais um unico corretivo estrutural curto falharem, ou quando surgir sinal de dialeto/localismo da KB.
- `Regra operacional`: em `Procedure` de relatorio, `;` faltando em `Rules` deve ser tratado como erro da camada `Rules`; `;` rejeitado em `Source` deve ser tratado como erro de dialeto/sintaxe de `Source`.
- `Regra operacional`: nao inventar `GXML`, controles, propriedades ou shape alternativo para o `Part c414...` sem ancoragem em molde documentado ou XML real comparavel.

### Revisao por blocos em `Procedure`

- `Regra operacional`: em `Procedure`, nao presumir `Source` como bloco inicial universal; a revisao fina deve declarar antes qual e o bloco primario do sintoma atual.
- `Regra operacional`: os blocos canonicos de revisao em `Procedure` sao `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container` e, quando aplicavel, `Report layout`.
- `Regra operacional`: `Source` cobre fluxo procedural, filtros, atribuicoes, navegacao, condicoes e chamadas feitas no corpo.
- `Regra operacional`: `Rules/parm` cobre assinatura declarativa e contrato de parametros; nao deve ser tratado como prova de call site.
- `Regra operacional`: `Variables` cobre existencia, tipo, coerencia de nome e classificacao de colecao vs simples quando isso for relevante ao caso.
- `Regra operacional`: `Calls and dependencies` cobre procedures chamadas, objetos auxiliares e a cadeia funcional imediata necessaria para justificar a conclusao.
- `Regra operacional`: `Identity and container` cobre `name`, `fullyQualifiedName`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Regra operacional`: `Report layout` so existe como bloco proprio quando a `Procedure` for de relatorio e houver `Bands`, `PrintBlock`, `ReportLabel` ou `ReportAttribute` em jogo.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional explicita; transicao sem motivo declarado reintroduz leitura difusa do objeto.
- `Regra operacional`: em `Procedure`, as transicoes mais comuns e justificadas sao `Rules/parm -> Variables`, `Rules/parm -> Source`, `Source -> Variables`, `Source -> Calls and dependencies` e `Report layout -> Source`.
- `Regra operacional`: parar a expansao quando a hipotese ja estiver sustentada; nao reabrir a `Procedure` inteira por reflexo.

### Escalada para corpus real

- `Regra operacional`: quando a trilha ja cobrir o caso comum por molde sanitizado forte, o corpus real da KB nao deve ser exigido como primeiro passo.
- `Regra operacional`: depois de uma tentativa inicial e no maximo um corretivo estrutural curto, o agente deve parar de iterar por analogia e escalar para XML real comparavel.
- `Regra operacional`: enquanto o caso continuar coberto pelo molde forte da trilha sem necessidade de escalada, rotular a base usada como `molde sanitizado`.
- `Regra operacional`: ao escalar, registrar explicitamente se a base usada passa a ser `XML real da KB atual` ou `XML real de outra KB`.
- `Regra operacional`: se a resposta ainda estiver sustentada apenas por tentativa plausivel sem molde documentado nem XML real comparavel, classificar como `hipotese` e bloquear consolidacao.

## Citacao de linhas em XML GeneXus

- `Regra operacional`: ao citar linha de XML GeneXus como evidencia, classificar explicitamente o papel do trecho citado: `Source efetivo`, `Rules/parm`, `metadado XML`, `chamada no chamador` ou `assinatura no chamado`.
- `Regra operacional`: em `Procedure`, uma linha no `Part` de `Rules/parm` do objeto chamado prova apenas a assinatura ou regra de parametros desse proprio objeto; ela nao prova que outro objeto chamou essa `Procedure`.
- `Regra operacional`: para afirmar que objeto A chama objeto B, a evidencia deve estar no `Source` efetivo de A, na linha em que B aparece como chamada, ou em metadado de chamada explicitamente materializado no objeto A.
- `Regra operacional`: se a linha citada pertence ao XML de B e mostra `parm(...)`, descreve-la como `assinatura no chamado`, nunca como ponto de chamada a partir de A.
- `Regra operacional`: quando a analise envolver cadeia de chamadas, registrar separadamente arquivo/linha do chamador e arquivo/linha da assinatura do chamado, sem colapsar as duas evidencias em um unico link.

## Identidade de frente e identidade de pacote

- `Regra operacional`: distinguir explicitamente `mesmo objeto` de `mesma frente`.
- `Regra operacional`: o agente nao deve reaproveitar `NomeCurto`, GUID da frente, data de abertura da frente ou contador `nn` apenas porque o objeto alvo e o mesmo.
- `Regra operacional`: o agente so pode reutilizar a identidade de uma frente anterior quando o usuario declarar continuidade da mesma frente ou quando houver evidencia direta suficiente no repositorio para fechar essa continuidade sem ambiguidade relevante.
- `Regra operacional`: reuso de precedente estrutural de pacote e decisao separada do reuso da identidade nominal da frente.
- `Regra operacional`: envelope, `Dependencies`, `ObjectsIdentityMapping` e demais elementos estruturais podem herdar de precedente validado quando o caso for comparavel.
- `Regra operacional`: identidade nominal da frente nao deve herdar automaticamente do pacote anterior por analogia, recencia, coincidencia de objeto ou habito operacional.
- `Regra operacional`: quando a continuidade da frente nao estiver explicitamente confirmada nem diretamente evidenciada, o agente deve bloquear a heranca automatica da identidade anterior e tratar a decisao como pendente ou como abertura explicita de frente nova, conforme a documentacao local aplicavel.

## Delta estrito

- `Regra operacional`: antes de empacotar, classificar cada mudanca candidata como `mudanca pedida`, `mudanca auxiliar necessaria` ou `mudanca extra nao pedida`.
- `Regra operacional`: se a mudanca for apenas metadado, reserializacao ou ruido, ela deve ser classificada como `mudanca extra nao pedida`, salvo quando houver justificativa objetiva de dependencia obrigatoria.
- `Regra operacional`: mudanca extra nao pedida deve ser sinalizada explicitamente antes do empacotamento.
- `Regra operacional`: o agente nao deve absorver mudanca extra nao pedida no pacote apenas porque ela apareceu no XML ativo, no diff local ou na reserializacao.
- `Regra operacional`: o delta deve ser estrito pelo conteudo do pacote, nao por `git diff` abstrato.

## Fechamento tecnico e Git

- `Regra operacional`: concluir `sync`, importacao, exportacao, materializacao, validacao ou build gera apenas o estado `validado_tecnicamente`; isso nao autoriza automaticamente `git add`, `commit` ou `push`.
- `Regra operacional`: o agente pode sugerir proximos passos de Git e publicacao quando isso for oportuno, mas sugestao nao equivale a execucao.
- `Regra operacional`: qualquer acao de fechamento ou publicacao em Git so pode ser executada com autorizacao explicita do usuario.
- `Regra operacional`: enquanto houver frente tecnicamente validada sem decisao de publicacao, o estado operacional preferido e `aguardando_decisao_de_fechamento`.
- `Regra operacional`: a documentacao local da pasta de trabalho pode declarar override mais especifico para fechamento e publicacao, mas a regra padrao desta base permanece em vigor ate essa override ser explicitada.

## Gate visual de `Source`

- `Regra operacional`: quando houver edicao de `Source`, releia o trecho salvo antes do empacotamento.
- `Regra operacional`: se a mudanca introduzir `if/endif`, `do case/endcase`, deslocamento de bloco, reindentacao relevante ou novo aninhamento, conferir explicitamente identacao, fechamento visual e legibilidade local.
- `Regra operacional`: comentarios estruturais humanos ja existentes, como `//if`, devem ser preservados quando ajudam a leitura do bloco; nao tratar esse apoio como sujeira cosmetica.
- `Regra operacional`: em `Source` grande, revisar o contorno visual do bloco afetado e algumas linhas antes e depois; isso e uma heuristica de escalada, nao uma regra metodologica central para toda edicao.
- `Regra operacional`: esse gate reduz erro humano em XML e `Source` grandes e nao substitui validacao semantica GeneXus.

## Ruido conhecido de `WorkWithWeb`

- `Evidência direta`: em casos comprovados desta frente, houve ruido nao funcional em `WorkWithWeb` associado a `Load Code` no atributo de `Selection` e/ou em tabs de `View`.
- `Regra operacional`: esse ruido deve ser tratado como inevitavel apenas nesses pontos comprovados, sem generalizar para todo `WorkWithWeb`.
- `Regra operacional`: quando esse ruido aparecer, registrar no manifesto como nao funcional para triagem de comparacao; nao orientar correcao manual como se fosse defeito de estrutura.

## Contaminacao de workspace e isolamento de lote

- `Regra operacional`: antes de empacotar, listar os XMLs ativos na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus` e tratar esse conjunto como lote candidato.
- `Regra operacional`: se houver mais de um lote plausivel na pasta de geracao, o agente deve bloquear o empacotamento por contaminacao de workspace.
- `Regra operacional`: o agente nao deve inferir o lote correto apenas por recencia se houver risco de mistura de frentes.
- `Regra operacional`: o agente nao deve fechar pacote por inferencia quando houver mais de um lote plausivel no workspace.
- `Regra operacional`: a ordem obrigatoria antes de empacotar e: isolar lote, classificar raizes, validar `lastUpdate`, validar BOM, validar manifesto e so entao serializar o pacote.
- `Regra operacional`: manifesto deve ser tratado primeiro como saida estruturada na propria conversa, e nao como arquivo fisico por padrao.
- `Regra operacional`: nome de pacote local gerado para importacao na IDE deve priorizar clareza humana e separacao de frentes paralelas, preferindo o padrao `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`.
- `Regra operacional`: nesse padrao, `NomeCurto` e uma descricao curta, legivel e semanticamente forte da frente; `GUID` e o identificador aberto para aquela frente; `YYYYMMDD` e a data de abertura da frente; `nn` e apenas o contador curto e incremental da rodada daquela frente.
- `Regra operacional`: `nn` nao representa versao semantica profunda nem historico de release; ele representa somente o candidato curto daquela frente.
- `Regra operacional`: antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` em `PacotesGeradosParaImportacaoNaKbNoGenexus`, verificar se ja existe arquivo com o mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn`.
- `Regra operacional`: se ja existir pacote com o mesmo prefixo de frente e o mesmo `nn`, abortar a gravacao; nao sobrescrever silenciosamente a rodada.
- `Regra operacional`: quando houver colisao de `nn`, retornar erro explicito com sugestao do proximo `nn` livre para aquela frente, mas sem autoincrementar nem gravar automaticamente com o valor sugerido.
- `Regra operacional`: nao usar como padrao nome so com assunto, nome so com data ou hora, descricao excessivamente longa da conversa ou sobrescrita recorrente do mesmo nome de pacote.
- `Regra operacional`: se um pacote anterior perder validade por mudanca de direcao da frente, ele deve ser marcado como provisório ou obsoleto e deixar de ser tratado como candidato principal.

## Protocolo para alteracoes indevidas no snapshot oficial

- `Regra operacional`: se o agente detectar alteracoes locais preexistentes em `ObjetosDaKbEmXml`, deve presumir erro de processo ate esclarecimento em contrario.
- `Regra operacional`: nesse cenario, o fluxo seguro e preservar esses XMLs em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, restaurar `ObjetosDaKbEmXml` para a versao oficial do Git e registrar manifesto dos itens preservados; esse manifesto pode ficar na conversa, mas deve virar arquivo quando a rastreabilidade local do incidente for necessaria.
- `Regra operacional`: o agente nao deve empacotar diretamente a partir de `ObjetosDaKbEmXml` alterado.

## Mudanca paralela legitima vinda da KB

- `Regra operacional`: quando um `XPZ` oficial exportado da KB trouxer objetos adicionais alem do foco imediato da frente atual, isso pode representar mudanca paralela legitima feita diretamente na IDE do GeneXus.
- `Regra operacional`: no `sync` de retorno oficial da KB, o padrao e materializar o que a KB devolveu oficialmente, mesmo quando houver itens que o agente nao estava esperando.
- `Regra operacional`: o agente deve sinalizar os itens inesperados sem presumir, por si so, erro de processo, contaminacao indevida ou violacao da trilha.
- `Regra operacional`: a distincao minima obrigatoria e entre `artefato da frente atual`, `mudanca paralela legitima vinda da KB/IDE` e `mudanca lateral indevida do proprio agente fora do escopo`.
- `Regra operacional`: regras de contaminacao, incidente de processo e restauracao do snapshot oficial se aplicam a alteracao lateral indevida do agente ou a edicao manual indevida do acervo, nao ao simples fato de um `XPZ` oficial trazer retorno adicional da KB.
- `Regra operacional`: quando o contexto da frente estiver disponivel, o `sync` pode comparar opcionalmente um conjunto esperado de itens contra o retorno oficial da KB, classificando `esperados que voltaram`, `esperados que nao voltaram` e `retorno oficial adicional da KB`.
- `Regra operacional`: essa classificacao comparativa e complementar; ela nao substitui nem bloqueia a materializacao oficial do que veio no `XPZ`.

## Checklist obrigatorio antes do empacotamento

- `Regra operacional`: antes de empacotar, classificar cada XML ativo como `alterado na rodada` ou `reenviado sem mudanca por dependencia obrigatoria`.
- `Regra operacional`: se o objeto foi realmente modificado nesta rodada, o `lastUpdate` deve refletir o instante real da ultima gravacao.
- `Regra operacional`: se o objeto nao foi modificado e entrou apenas para dependencia obrigatoria ou composicao minima do pacote, o `lastUpdate` oficial anterior deve ser preservado.
- `Regra operacional`: o empacotamento deve abortar quando houver divergencia entre a classificacao do item e o `lastUpdate` materializado.
- `Regra operacional`: antes de empacotar, classificar a raiz top-level de cada XML ativo em `Object`, `Attribute` ou `outro tipo`.
- `Regra operacional`: `Object` top-level deve entrar em `<Objects>`.
- `Regra operacional`: `Attribute` top-level deve entrar em `<Attributes>`.
- `Regra operacional`: nunca colocar `Attribute` top-level dentro de `<Objects>`.
- `Regra operacional`: se surgir raiz top-level nao suportada pelo fluxo atual, o empacotamento deve abortar ou exigir tratamento explicito.
- `Regra operacional`: XML gerado localmente deve ser salvo em UTF-8 sem BOM.
- `Regra operacional`: antes de empacotar, verificar presenca de BOM UTF-8 no inicio de todos os XMLs ativos.
- `Regra operacional`: se houver BOM, remover e registrar a correcao como higiene operacional.
- `Regra operacional`: antes de gerar `import_file.xml` ou `.xpz`, produzir ou validar manifesto do lote, preferencialmente na propria conversa, com frente ou descricao curta do lote, origem do lote, quantidade total de XMLs, quantidade de `Objects`, quantidade de `Attributes`, lista ou resumo dos arquivos incluidos, `lastUpdate` aplicado ou preservado, pacote gerado, pacote anterior substituido quando houver e observacoes de risco ou pendencia.
- `Regra operacional`: salvar manifesto em arquivo nao e o comportamento padrao; isso so deve ocorrer quando houver incidente de processo envolvendo `ObjetosDaKbEmXml`, substituicao de pacote com necessidade real de rastreabilidade local, pedido explicito do usuario ou necessidade concreta de retomada futura fora da conversa imediata.
- `Regra operacional`: esse manifesto deve servir para conferencia humana e para bloquear mistura de frentes.
- `Regra operacional`: quando houver pacote anterior da mesma frente com risco real de confusao, o prefixo `OBSOLETO_` pode ser usado como ferramenta de contencao; isso nao faz parte da convencao principal de nome do pacote.

### Exemplo sanitizado do envelope observado

```xml
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>4</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <Build>BUILD_OBSERVADO</Build>
  </KMW>
  <Source kb="GUID_SANITIZED" username="SANITIZED\\USER" UNCPath="\\\\SANITIZED\\KBPATH">
    <Version guid="GUID_SANITIZED" name="KB_SANITIZED" />
  </Source>
  <BlocoEspecialDaKB name="KB_SANITIZED" type="GUID_TIPO_KB" description="Descricao sanitizada" user="SANITIZED\\USER">
    <Properties />
    <Version guid="GUID_SANITIZED" versionDate="0001-01-01T00:00:00.0000000" checksum="CHECKSUM_SANITIZED" server_checksum="">
      <Properties />
    </Version>
    <Environments />
  </BlocoEspecialDaKB>
  <Objects>
    <Object ... />
  </Objects>
  <Attributes>
    <Attribute ... />
  </Attributes>
  <Dependencies>
    <Reference ... />
  </Dependencies>
</ExportFile>
```

- Evidência direta: `Attributes` e um bloco adicional comum no formato normal, mas nao invariavel
- Inferência forte: para geracao conservadora de objetos comuns, este envelope minimo continua sendo referencia util, mas nao deve ser promovido a formato universal para qualquer pacote misto
- Evidência direta: esse envelope minimo ja sustentou uma importacao bem-sucedida de um `Procedure` de teste nesta trilha, desde que os GUIDs de `Source` fossem sintaticamente validos
- Evidência direta: em frente posterior desta mesma trilha, um pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure` so passou quando foi remontado como pacote embutido, tomando export real comparavel da IDE como molde.

- `Evidência direta`: em teste real de `Import File Load`, um arquivo contendo apenas `<Object>` falhou com `Invalid format, MajorVersion not found`.
- `Evidência direta`: nesta trilha, `import_file.xml` foi validado como artefato operacional de importacao pela IDE, nao como sinonimo exato do `XPZ` completo observado em export real.
- `Regra operacional`: para `Load/Import` pela IDE, nao assumir que XML individualizado de objeto seja suficiente; quando o objetivo for carga na KB, empacotar em `import_file.xml` com `ExportFile`, `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`.
- `Regra operacional`: quando a frente atual alterar apenas um subconjunto de objetos, preferir pacote minimo contendo so os objetos realmente mudados, para reduzir ruido, risco de regressao e retrabalho de validacao.
- `Regra operacional`: se um objeto nao foi alterado, ele nao deve entrar no pacote apenas por conveniencia; so entra quando for necessario para fechar dependencias obrigatorias do objeto realmente modificado.
- `Regra operacional`: ao embutir XML individualizado de objeto dentro de `<Objects>` no `import_file.xml`, remover a declaracao `<?xml ...?>` do objeto; essa declaracao deve existir apenas no topo do arquivo do pacote.
- `Regra operacional`: ao documentar ou raciocinar sobre formato, separar explicitamente `XPZ observado em export real` de `envelope de importacao pela IDE`; ambos compartilham a raiz `ExportFile`, mas nao devem ser tratados como o mesmo artefato sem qualificacao.
- `Evidência direta`: em teste real de renomeacao de objeto, a importacao preservou historico apenas quando o pacote manteve o mesmo `Object/@guid` do objeto existente.
- `Regra operacional`: se existir export real comparavel da IDE para a mesma composicao de objetos, esse export deve prevalecer como molde estrutural do pacote sobre qualquer envelope leve hipotetico.
- `Regra operacional`: para pacote misto de `Transaction + WorkWithForWeb + Procedure`, o caminho validado nesta trilha foi pacote embutido com objetos completos em `<Objects>`, reaproveitando `Dependencies` e `ObjectsIdentityMapping` contextuais de export real comparavel.
- `Regra operacional`: renomeacao, mudanca de propriedades, `source`, `rules`, `variables` ou `folder` de um objeto existente devem preservar o mesmo `guid`; trocar o `guid` significa criar outro objeto.

## Aprendizados com pacotes de importacao na IDE

- `Regra operacional`: pacote minimo deve ser a referencia padrao; se uma frente alterou apenas alguns objetos, nao reenviar XMLs nao tocados apenas para "completar" a rodada.
- `Regra operacional`: `lastUpdate` novo deve existir so no objeto realmente alterado; objeto reenviado sem mudanca precisa conservar o `lastUpdate` original do XML da KB.
- `Regra operacional`: ao embutir XMLs em `import_file.xml`, remover declaracao `<?xml ...?>` interna do objeto e manter a declaracao apenas no topo do pacote.
- `Regra operacional`: quando o pacote envolver `WorkWithForWeb`, validar o `CDATA` interno do `Data` como XML completo, porque erros de fechamento de `selection`, `tab`, `view` ou `variable` costumam aparecer so no `Load`.
- `Regra operacional`: ao alterar `WorkWithForWeb`, desencorajar substituicoes textuais amplas em tags repetidas, especialmente `<actions>`; localizar estruturalmente a `Selection` alvo dentro do XML interno antes de inserir, remover ou alterar uma action.
- `Regra operacional`: em `WorkWithForWeb`, uma action nova so deve ser considerada materializada quando estiver no `Selection` correto, com identificador/nome esperado, e aparecer exatamente uma vez naquele escopo.
- `Regra operacional`: se houver mais de um `<actions>` plausivel, ou se a mesma action aparecer em escopos diferentes sem justificativa documental, bloquear o pacote ate reinspecao estrutural do XML interno.
- `Regra operacional`: se o `Selection` do `WorkWithWeb` usar ordenacao sensivel a volume, conferir se a `Table` tem indice exato para a mesma sequencia de campos e direcoes.
- `Evidência direta`: em importacoes reais desta KB, a frente de `CompraRevenda` ficou com cobertura exata de ordenacao; outros casos fiscais da mesma trilha exigiram anotacao especifica para avaliacao de indice composto.
- `Exemplo sanitizado`: `TRN + WorkWithWeb + Attributes + Procedures` pode importar com sucesso quando o pacote leva so o fecho minimo e preserva um `lastUpdate` real por objeto.
- `Exemplo sanitizado`: tambem houve sucesso real, nesta trilha, com pacote embutido de `4` `Transaction`, `4` `WorkWithForWeb` e `3` `Procedure`, passando por `Import File Load`, `Import`, `Updating table information` e `Pattern generation`.
- `Exemplo sanitizado`: um `WorkWithWeb` com filtros fiscais, acao de planilha e `IconeUpdate` deve ser validado por partes, comparando o XML gerado com o artefato equivalente da KB antes do `Load`.
- `Referencia privada`: os casos completos, sem sanitizacao, ficam mapeados em `C:\\Dev\\Knowledge\\GeneXus-XPZ-PrivateMap`; a raiz publica deve manter apenas o aprendizado resumido e os exemplos anonimizados.

## Leitura operacional de logs de importacao

- `Regra operacional`: ler log de importacao por etapa, nao por linha isolada.
- `Regra operacional`: classificar cada mensagem em uma destas categorias: `erro estrutural de XML/pacote`, `erro de identidade/serializacao do objeto`, `erro de sintaxe/semantica do Source`, `erro lateral da IDE`, `warning nao bloqueante`, `sucesso terminal`.
- `Regra operacional`: a conclusao final deve usar a etapa terminal relevante do log e o conjunto das mensagens bloqueantes.
- `Regra operacional`: falha lateral da IDE antes, durante ou depois do import nao deve ser promovida automaticamente a falha estrutural do pacote.
- `Regra operacional`: se o pacote abriu, mas o `Source` falhou, classificar como falha de `Source`, nao de envelope.
- `Regra operacional`: se alguns objetos entraram e outros nao, classificar o resultado como parcial e registrar o objeto ou etapa afetada.
- `Regra operacional`: warning ou erro lateral coexistente com `Import` bem-sucedido deve gerar `sucesso com ressalva`, nao `falha total`.
- `Regra operacional`: ao gerar pacote corretivo depois de falha parcial, relatar explicitamente: pacote original, objetos importados com sucesso, objetos falhos, causa provavel por objeto ou etapa, e novo pacote corretivo.
- `Regra operacional`: pacote corretivo deve conter apenas o delta necessario para corrigir os objetos falhos ou dependencias estritamente necessarias; nao reenviar automaticamente todos os objetos do pacote original.

### Playbook de diagnostico para `Procedure` de relatorio

- `src0212 invalid control`: suspeitar primeiro do layout; revisar o shape do `Part c414ed00-8cc4-4f44-8820-4baf93547173`, `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute` e a coerencia entre bloco impresso e bloco materializado.
- `src0201 output_file invalid type`: suspeitar primeiro de `Source` ou de mistura de camadas; revisar assinatura usada em `Output_file`, tipo dos parametros e se o comando ficou realmente no `Source`.
- `src0119 ';' not longer supported`: suspeitar primeiro de `Source`; revisar transplante indevido de sintaxe de `Rules`, legado de dialeto ou terminador herdado.
- `src0056 Missed ';' at the end of the rule`: suspeitar primeiro de `Rules`; revisar fechamento de `parm(...)` e demais regras, sem deslocar o diagnostico para o layout.
- erro citando `printBlock`, `ReportLabel`, `ReportAttribute` ou `invalid control`: suspeitar primeiro do layout.
- erro citando `parm`, `rule`, `end of the rule` ou assinatura: suspeitar primeiro de `Rules`.
- erro citando `For each`, `Header`, `Footer`, `Output_file` ou comando procedural: suspeitar primeiro de `Source`.
- `Regra operacional`: classificar esses casos como `erro de sintaxe/semantica do Source` ou `erro estrutural de XML/pacote` conforme a camada realmente afetada; nao colapsar tudo como defeito de envelope.
- `Regra operacional`: depois da tentativa inicial mais um unico corretivo estrutural curto nesse playbook, bloquear nova iteracao por analogia e exigir XML real comparavel.

### Procedimento auditavel de leitura

- `Regra operacional`: identificar primeiro a etapa de cada mensagem: `Import File Load`, `Import`, `Updating table information`, `Pattern generation`, `Specification`, `backup` ou equivalente.
- `Regra operacional`: para cada mensagem, registrar `etapa`, `categoria`, `bloqueia objeto`, `bloqueia pacote` e `conclusao parcial`.
- `Regra operacional`: concluir o estado final a partir da etapa terminal relevante do caso, e nao da linha mais alarmante do log.
- `Regra operacional`: quando houver falha parcial, registrar separadamente o estado final do pacote e o estado final por objeto.

### Validacao separada em `WebPanel` e pacote delta

- `Regra operacional`: tratar `WebPanel` como objeto de revisao por blocos funcionais, nao como massa unica de XML, sempre que a duvida envolver comportamento, filtro, evento, dependencia ou diagnostico fino.
- `Regra operacional`: os blocos canonicos de revisao em `WebPanel` sao `layout`, `events`, `variables`, `metadado funcional serializado`, `identidade e contêiner` e `dependencias`.
- `Regra operacional`: antes de aprofundar a leitura, declarar um bloco primario para o sintoma atual; se o agente ainda nao souber qual e o bloco primario, ele ainda nao esta pronto para revisao fina.
- `Regra operacional`: abrir bloco adjacente apenas por dependencia funcional declarada; transicao sem motivo explicito degrada a revisao e reintroduz mistura de camadas.
- `Regra operacional`: `metadado funcional serializado` e camada funcional propria de `WebPanel`; ele orbita o layout, mas nao deve ser reduzido a mera apresentacao visual.
- `Regra operacional`: em `WebPanel`, nao assumir que o `Conditions` visivel na IDE venha automaticamente de um `Part` fixo; antes de concluir shape, localizar no XML real onde aquele tipo de controle persiste o filtro.
- `Regra operacional`: quando a duvida for "onde a IDE realmente persiste esta propriedade?", decidir a partir de XML exportado pela propria IDE para objetos comparaveis da mesma KB; nao decidir por analogia com outro controle, outro `Part` ou outra familia de `WebPanel`.
- `Regra operacional`: tratar `Conditions` materializado, `Defaults` de template (`ViewConditions.dkt`, `TabGridConditions.dkt`) e metadado serializado de layout como camadas distintas; a mera presenca textual da palavra `Conditions` nao prova filtro persistido.
- `Regra operacional`: em `WebPanel`, `ControlWhere`, `ControlBaseTable`, `ControlOrder` e `ControlUnique` devem ser procurados primeiro no `Source` do `Part` de layout, normalmente dentro de `PATTERN_ELEMENT_CUSTOM_PROPERTIES`; so tratar outro `Part` como origem quando houver evidencia direta no XML real.
- `Regra operacional`: `WebUserControlProperties` e `PATTERN_ELEMENT_CUSTOM_PROPERTIES` devem ser lidos como metadado serializado de controle no layout, e nao como propriedades planas do objeto.
- `Regra operacional`: em `Prompt`, `Selection List`, `Dynamic Combo` e variantes com grid, confirmar por familia se o filtro operacional esta no `Part` de `Conditions`, no layout, ou nos dois lugares; nao promover padrao localizado a regra universal.
- `Evidência direta`: em `FreeStyleGrid`, ja houve caso em que o filtro navegou em runtime, mas a mesma forma nao foi aceita pelo parser estrutural da IDE.
- `Regra operacional`: tratar `Load`, `Import` e `Specification` como validacoes separadas; sucesso em uma camada nao prova sucesso nas outras.
- `Regra operacional`: `Import File Load` e apenas a etapa de listagem e preview do pacote na IDE — o objeto NAO entra na KB nessa etapa; a importacao real so ocorre quando o usuario confirma explicitamente na etapa subsequente `Import`. Mensagem `Success: Import File Load` significa que o pacote foi parseado e listado com sucesso, nao que o objeto foi importado.
- `Regra operacional`: ao ajustar `ControlWhere` no XML, preferir a sintaxe aceita pelo editor estrutural da IDE; navegacao em runtime, sozinha, nao basta como criterio de materializacao segura.
- `Evidência direta`: declarar `controlName` explicito em `<data>` pode reduzir ambiguidade estrutural no XML, mas isso nao garante que o nome fique disponivel como identificador manipulavel no source do objeto.
- `Regra operacional`: em pacote delta GeneXus, quando ja existir pacote equivalente validado na IDE, reaproveitar o envelope completo desse pacote como molde; nao simplificar cabecalho, `Dependencies` ou `ObjectsIdentityMapping` por inferencia.

#### Exemplos sanitizados minimos

- `Exemplo sanitizado`: em um `WebPanel` de prompt com `simplegrid`, o layout expunha o controle com `controlName`, mas o filtro pesquisavel ficou materializado em outro `Part`, como linhas de condicao no `Source`; isso prova que o ponto real de persistencia precisa ser confirmado no XML antes de atribuir o `Conditions` a um bloco fixo.
- `Exemplo sanitizado`: em outro `WebPanel` com `grid class="FreeStyleGrid"`, o mesmo criterio de filtro apareceu tanto no `ControlWhere` do layout quanto em `Part` estrutural separado; esse tipo de duplicidade explica por que `Load`, `Import` e `Specification` precisam continuar sendo validados como camadas distintas.
- `Exemplo sanitizado`: em `WPExemploGridEstruturalA`, um grid tradicional persistiu `ControlBaseTable`, `ControlOrder`, `ControlWhere` e `ControlUnique` no layout, dentro de `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, sem depender de propriedade plana no objeto.
- `Exemplo sanitizado`: em `WPExemploComboDinamicoA`, o `Dynamic Combo Box` persistiu `ControlWhere` no layout e configuracao complementar em `WebUserControlProperties`; isso mostra que filtro de combo dinamico nao deve ser confundido com `Conditions` materializado.
- `Exemplo sanitizado`: em pacotes delta reais com um unico objeto, o envelope completo continuou incluindo `KMW`, `Source`, `Objects`, `Dependencies` e `ObjectsIdentityMapping`, mesmo quando os dois blocos finais estavam vazios; por isso, a forma segura e clonar o pacote equivalente validado, nao podar o fecho por "limpeza" manual.
- `Exemplo sanitizado`: em uma pasta paralela de KB de teste, dois pacotes unitarios de `Domain` gerados para importacao manual mantiveram o objeto completo embutido em `<Objects>`, `Dependencies` vazio e `ObjectsIdentityMapping` contendo apenas o modulo raiz; isso reforca que pacote pequeno nao deve ser reduzido a XML individual de objeto nem promovido manualmente ao acervo oficial.

### Modos de falha observados e correcoes

- `Erro sanitizado`: declaracao `<?xml ...?>` duplicada dentro de `<Objects>` no `import_file.xml`.
  `Correção`: manter a declaracao XML apenas no topo do pacote; o XML embutido no objeto deve entrar sem prologo.
- `Erro sanitizado`: `Unexpected XML declaration` ou parse quebrado no meio do pacote.
  `Correção`: localizar a declaracao interna repetida ou ruido de concatenacao antes do `Load`.
- `Erro sanitizado`: `Data` de `WorkWithForWeb` terminando com fechamento invalido de `variable`, `selection` ou `tab`.
  `Correção`: validar o XML interno do `CDATA` como documento completo, nao apenas o envelope externo.
- `Erro sanitizado`: `Unknown function 'IsEmpty'` em `Procedure` importada.
  `Correção`: comparar a `Procedure` com um molde valido da KB e ajustar o `Source` e o bloco de `Variables` para a assinatura real do objeto.
- `Erro sanitizado`: `Guid should contain 32 digits with 4 dashes` durante Import File Load causado por `ObjectIdentity/@Type` com valor inteiro (ex.: `Type="1"` ou `Type="8"`).
  `Correção`: substituir o valor inteiro pelo GUID real do tipo correspondente, derivado do campo `Object/@parentType` do XML de origem do objeto empacotado.
- `Erro sanitizado`: `Cannot insert Folder ... already exists in this model`.
  `Correção`: revisar `parentGuid` e `ObjectsIdentityMapping`; nao usar identidade de contêiner errada nem reaproveitar container inexistente no destino.
- `Erro sanitizado`: `lastUpdate` novo aplicado a objeto apenas reenviado.
  `Correção`: preservar `lastUpdate` do XML original para objetos nao modificados e atualizar apenas o que foi realmente alterado.
- `Erro sanitizado`: pacote grande com objetos nao tocados atrasando importacao sem ganho funcional.
  `Correção`: reter somente o fecho minimo da frente atual e excluir artefatos sem mudança efetiva.
- `Erro sanitizado`: `Import File Load` falhando com `Value cannot be null. Parameter name: g` em pacote misto montado com envelope leve por `FilePath`.
  `Correção`: parar de ajustar `ObjectsIdentityMapping` por hipotese e comparar primeiro com export real da IDE para a mesma composicao; no caso validado nesta trilha, a correcao foi remontar o pacote como embutido em `<Objects>`.
- `Exemplo sanitizado ligado à privada`: os casos completos de `EntradaDeTerceiro`, `EntradaDoIndustrializador` e dos pacotes associados ficam referenciados na pasta privada `C:\\Dev\\Knowledge\\GeneXus-XPZ-PrivateMap`; nesta raiz publica ficam apenas os sintomas resumidos e as correcoes operacionais.

## Vocabulario operacional de fonte e molde

- `Molde bruto comparavel`: XML bruto real do mesmo `Object/@type` e de familia estrutural proxima, usado para materializacao final quando a base ainda nao tem anexo completo suficiente.
- `Molde sanitizado documentado`: XML completo e sanitizado embutido nesta base, preservando estrutura suficiente para leitura e, em casos suportados, para geracao controlada sem recorrer ao acervo bruto.
- `Envelope XPZ observado`: estrutura externa `<ExportFile>` documentada acima, derivada de export real inspecionado nesta trilha.
- `Resumo textual`: tabelas, frequencias, heuristicas e explicacoes. Serve para decidir; sozinho nao substitui um molde XML completo.

## Politica para compatibilidade de `Source`

- `Regra operacional`: `Source` GeneXus plausivel nao deve ser tratado como `Source` pronto apenas por parecer sintaticamente valido.
- `Regra operacional`: a base primaria para aceitar novo `Source` nesta trilha e a propria documentacao metodologica, em duas formas: regra explicita e exemplo sanitizado ou molde documentado.
- `Regra operacional`: o corpus real da KB, quando existir, entra como reforco, confirmacao ou desempate; ele nao substitui a base metodologica da trilha.
- `Regra operacional`: isso vale tambem para KB nova ou pouco povoada; a camada metodologica da trilha deve bastar para orientar a geracao conservadora sem depender de corpus rico.
- `Regra operacional`: antes de consolidar um `Source` novo ou alterado, materializar explicitamente os itens novos introduzidos pela mudanca em quatro grupos: `operadores`, `funcoes`, `conversoes` e `padroes string/numerico`.
- `Regra operacional`: cada item novo desses grupos deve apontar pelo menos uma base metodologica desta trilha: regra explicita, exemplo sanitizado ou molde documentado.
- `Regra operacional`: se um item novo estiver sustentado apenas por intuicao, memoria generica de GeneXus ou ocorrencia isolada do corpus local sem amparo metodologico da trilha, o `Source` nao deve ser consolidado.
- `Regra operacional`: quando nao houver base metodologica suficiente para um item essencial do `Source`, o agente deve reescrever a solucao usando padrao ja documentado ou abortar a consolidacao.
- `Regra operacional`: `XML` bem-formado, envelope correto, `Load` parcial ou `runtime` plausivel nao substituem validacao de compatibilidade do dialeto de `Source` aceito nesta trilha.

### Decisao operacional para `Source`

- `Prosseguir`: todos os itens novos do `Source` estao ancorados em regra explicita, exemplo sanitizado ou molde documentado desta trilha.
- `Prosseguir com ressalva`: a trilha cobre o padrao principal e o corpus local apenas confirma ou desempata a escolha.
- `Hipotese`: permitido apenas para analise; nao autoriza consolidar `Source` final nem empacotar.
- `Abortar`: item essencial do `Source` sem base metodologica suficiente na trilha e sem reescrita para padrao documentado.

## Ligacao estrutural com runtime GeneXus

- `Evidência direta`: no acervo desta KB, `Transaction` aparece em 183 objetos, todos com `parent`, todos com `Level`, e 177/183 com `AttributeProperties`.
- `Evidência direta`: `WebPanel` aparece em 1196 objetos; 1195/1196 possuem `parent`; 437/1196 mostram sinal estrutural de eventos; 25/1196 exibem sinal textual de `grid`.
- `Evidência direta`: `Procedure` aparece em 2281 objetos, todos com `parent`; `DataProvider` em 24, todos com `parent`; `API` em 1, com `parent`; `WorkWithForWeb` em 183, todos com `parent`, `Level` e marca de pattern no bloco `<Data Pattern=\"...\">`.
- `Regra documentada`: em GeneXus, a determinacao de `Base Table` e a navegacao associada dependem dos atributos usados, do `For each`, da `Base Transaction clause`, da estrutura do objeto e dos eventos envolvidos.
- `Inferência forte`: por isso, a estrutura XML permite detectar objetos mais ou menos propensos a joins implicitos, dependencia contextual e carga extra, mas nao substituir o relatorio de navegacao nem a especificacao real da IDE.
- `Regra operacional`: ao editar `WorkWithForWeb`, nao validar apenas o envelope externo do pacote; validar tambem o XML interno reconstruido do `CDATA` em `Data`, porque erros de fechamento em `variable`, `attributes`, `filter`, `tab` ou `view` podem surgir so no `Load/Import` pela IDE.

## Regras documentadas de runtime

### Base Table e Extended Table

- `Regra documentada`: a `Base Transaction clause` declara a intencao de navegacao e pode ser usada em `For each` e em grupos de `Data Provider` para definir a tabela base com mais clareza e reduzir ambiguidade de especificacao.
- `Regra documentada`: quando um `For each` declara uma `Base Transaction`, a tabela associada passa a ser a `Base Table`, e atributos usados no corpo, filtros e ordens precisam estar na `Extended Table` correspondente.
- `Regra documentada`: GeneXus tambem pode determinar a `Base Table` implicitamente a partir dos atributos presentes, inclusive em grids e eventos `Load`.
- `Inferência forte`: logo, objetos com muitos atributos de diferentes contextos, FKs paralelas ou multiplos niveis tendem a ser mais sensiveis a efeitos de `Extended Table`, filtros condicionais e custo de navegacao.
- `Regra operacional`: em `For each`, a analise pratica e sempre sobre a `Base Table` determinada, seja ela explicita no cabeçalho ou implicita pelo conjunto de atributos usados no bloco.
- `Regra operacional`: se a `Base Table` for implicita, o conjunto coerente de atributos do corpo, `Where`, `Order` e demais referencias que participam da navegacao determina a tabela base; atributos fora dessa tabela ou fora do contexto coerente de `Extended Table`/subtype nao devem ser aceitos no bloco.
- `Regra operacional`: ao revisar um `For each`, checar primeiro a tabela base real e so depois validar se cada atributo pertence a essa base ou ao contexto coerente da navegacao.

### Navegacao, filtros e loops

- `Regra documentada`: `For each` e grupos de `Data Provider` sao pontos centrais de navegacao; filtros, ordens e atributos fora da tabela base podem alterar joins, subselects e forma de acesso.
- `Regra documentada`: quando ha `Load` sobre grid ou painel com base implicita, um `For each` escrito dentro do evento pode ficar aninhado em uma navegacao implicita ja existente.
- `Inferência forte`: isso aumenta o risco relativo de padroes do tipo `N+1`, carga repetida por linha e custo dificil de perceber olhando apenas o XML final.
- `Hipótese`: em objetos com muito codigo de evento e muitos controles ligados a dados, a ausencia de relatorio de navegacao detalhado torna prudente assumir performance potencialmente sensivel ate prova em contrario.
- `Regra operacional`: ao alterar filtro de identidade, unicidade, contagem, existencia, selecao candidata ou ambiguidade em um `for each`, procurar no mesmo `Source` outros blocos proximos ou semanticamente relacionados sobre a mesma tabela/base.
- `Regra operacional`: tratar pares como `count/then-copy`, `exists/then-load`, `validate/then-apply` e `select-candidate/then-materialize` como unidade logica quando um bloco define o conjunto candidato e outro materializa, copia, carrega ou aplica o registro selecionado.
- `Regra operacional`: classificar esses blocos irmaos, por exemplo como `candidate/count query`, `existence/validation query`, `materialization/copy query` ou `load/apply query`, e validar que os criterios de identidade do registro permanecem coerentes.
- `Regra operacional`: se a mudanca afetar a identidade do registro candidato, ajustar ou reconciliar todos os blocos irmaos relacionados; alterar apenas um bloco exige justificativa explicita antes de empacotar.

### WebPanel, Refresh e Grid

- `Regra documentada`: o `Refresh event` e o `Refresh Grid event` sao executados antes da carga/re-carga dos dados exibidos, e o `Load event` pode ser executado para cada linha quando ha grid com base de navegacao.
- `Regra documentada`: em Web, os eventos de refresh usam ciclo Ajax; isso melhora a troca com o cliente, mas nao elimina custo server-side de navegacao e carga de dados.
- `Evidência direta`: em `WebPanel`, declarar `Event &Variavel.ControlValueChanged()` mesmo vazio registra roundtrip Ajax implicito para a variavel, em vez de funcionar como marcador inofensivo.
- `Regra operacional`: remover `ControlValueChanged` vazio deve ser lido como ajuste de performance e previsibilidade, nao apenas como limpeza cosmetica de codigo.
- `Regra operacional`: nao posicionar `SetFocus()` em `Event Refresh` quando o foco desejado depender de uma acao especifica; por ser escopo global de refresh Ajax, esse evento tende a reaplicar foco em momentos laterais e produzir salto inesperado.
- `Regra operacional`: quando houver necessidade real de reposicionar foco em `WebPanel`, preferir `Event Start`, `Event Enter`, `Event Click` ou `Sub` chamado por evento explicitamente controlado.
- `Inferência forte`: `WebPanel` com `events` + `grid` + acoes + `parent` contextual tende a merecer cautela runtime maior que uma casca minima sem eventos.
- `Inferência forte`: `WebPanel` gerado por pattern/defaults ou acoplado a `MasterPage` e seguranca integrada tende a depender mais do contexto da KB do que um painel isolado e pequeno.

### Procedure, Data Provider, Transaction e API

- `Regra documentada`: `Procedure` e `Data Provider` podem disparar navegacoes a partir de `For each`, grupos e atributos usados; o runtime relevante depende mais do codigo e da base implicita do que do simples inventario de `Part`.
- `Regra documentada`: `Transaction` descreve estrutura transacional e niveis; sua sensibilidade runtime cresce quando ha subniveis, relacoes pai-filho e maior densidade de atributos relacionais.
- `Inferência forte`: `Transaction` com multiplos `Level` sugere maior probabilidade de joins implicitos, contexto pai-filho e custo de manutencao/performance superior ao de `Transaction` de um nivel.
- `Inferência forte`: `API` com bloco `Service`, `RestMethod`, eventos `.Before/.After` e chamadas a `Procedure` sugere camada de orquestracao server-side; o XML nao prova custo, mas indica dependencia de codigo interno e contexto de seguranca/sessao.
- `Hipótese`: `DataProvider` pequeno e direto, com poucos filtros e saida simples, tende a ser menos arriscado em runtime do que `Procedure` ou `WebPanel` com eventos cruzados e composicao de tela.

## Politicas especificas para tipos contextuais

### Politica para `Transaction`

- `Evidência direta`: o teste isolado com `Transaction 'TRNExemploMinBancoA'`, seus `Attribute` top-level reais, `SDT 'Context'` e `SDT 'TransactionContext'` importou com sucesso.
- `Evidência direta`: nesse mesmo teste houve geracao de pattern bem-sucedida para `WWExemploMinBancoA`.
- `Evidência direta`: em teste controlado separado, um pacote contendo apenas `Transaction` falhou com erro do tipo `Attribute 'X' in 'Transaction Y' does not exist` quando os atributos referenciados no `<Level>` nao existiam na KB de destino.
- `Evidência direta`: no mesmo cenario, ao incluir no mesmo pacote os `Attribute` top-level correspondentes, a importacao passou a reconhecer os atributos e avancou para a validacao estrutural da `Transaction`.
- `Evidência direta`: apos ajuste do shape do `Level` e dos `Part`, o pacote contendo `Attribute + Transaction` foi importado com sucesso completo, incluindo atualizacao de tabela.
- `Inferência forte`: quando o molde de `Transaction` usa `Context`, `TrnContext` ou `TrnContextAtt`, os SDTs de contexto correspondentes deixam de ser detalhe auxiliar e passam a ser dependencias de primeira classe do pacote.
- `Inferência forte`: quando a KB de destino nao contem previamente os atributos referenciados pela `Transaction`, o pacote minimo precisa inclui-los como `Attribute` top-level, e nao apenas como referencias inline no `Level`.
- `Regra operacional`: antes de materializar `Transaction`, validar nesta ordem: familia estrutural correta, atributos reais do `Level`, `SDT 'Context'`, `SDT 'TransactionContext'` e so depois regras/eventos mais especificos.
- `Regra operacional`: ao gerar pacote minimo de `Transaction`, verificar primeiro se os atributos do `Level` ja existem na KB de destino; se nao existirem, incluir `Attributes` top-level correspondentes no mesmo pacote.
- `Regra operacional`: erro em `ATTCUSTOMTYPE` de `sdt:Context`, `sdt:TransactionContext` ou `sdt:TransactionContext.Attribute` deve ser lido como falta de dependencia contextual, nao como falha do envelope XML.
- `Regra operacional`: nao confiar que o GeneXus criara automaticamente atributos implicitos a partir do `Level`; no caso validado, a ausencia explicita levou a erro de validacao.
- `Evidência direta`: em trilha posterior validada na IDE, um pacote misto com `4` `Attribute` top-level, `1` `Transaction` e `1` `WorkWithForWeb` importou com sucesso e concluiu tambem a geracao do pattern associado.
- `Regra operacional`: quando a alteracao de `Transaction` impactar atributos exibidos, filtros, abas ou navegacao do pattern web, revisar tambem o `WorkWithForWeb` associado antes de considerar a frente fechada.

### Politica para `API`

- `Evidência direta`: a base observa apenas `1` `API` real nesta KB.
- `Evidência direta`: esse caso corresponde a uma construcao manual/local da KB, sem evidencia nesta trilha de ferramenta complementar de automacao de `API`.
- `Evidência direta`: o teste isolado com `APIExemploIntegracaoA` e seus SDTs reais resolveu a camada de erro em `ATTCUSTOMTYPE`.
- `Evidência direta`: depois disso, a `API` passou a falhar por `Procedure` ausente (`PRCExemploListaA`) e por contexto de negocio (`DomainExemploTipoA`, `TRNExemploProdutoA`).
- `Evidência direta`: o export real `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos e mostrou que a `API` desta KB ja sai da IDE acompanhada por uma subarvore funcional grande.
- `Inferência forte`: por haver apenas um caso real, a leitura operacional de `API` nesta base deve permanecer ancorada em estudo de caso da KB, e nao em suposta familia ampla de APIs GeneXus manuais ou automatizadas.
- `Inferência forte`: a hierarquia de validacao de `API` nesta trilha e: primeiro `ATTCUSTOMTYPE`/SDTs, depois `Procedure`, e por fim atributos, dominios ou contexto de negocio usados no codigo/eventos.
- `Inferência forte`: para `API`, o melhor recorte operacional deixa de ser o objeto isolado e passa a ser uma familia funcional contendo pelo menos `Procedure`, `SDT`, `Domain`, e possivelmente `Transaction`, `Table` e `DataProvider`.
- `Regra operacional`: nao regenerar `API` “igual” apos erro de `ATTCUSTOMTYPE`; primeiro materializar os SDTs reais e reexecutar. Se o erro remanescente migrar para `Procedure` ou atributo de negocio, tratar a camada semantica seguinte.

### Politica para `Attribute` em export combinado

- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades.
- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Evidência direta`: nesses dois recortes, a IDE serializou `Attributes` como bloco top-level proprio no mesmo `.xpz` que tambem carrega `Objects`.
- `Inferência forte`: quando a familia funcional inclui `Attribute` real, `Transaction`, `Domain` e `SubtypeGroup`, o formato normal observado fica mais forte com `Objects` + `Attributes`, e nao apenas com `Objects`.
- `Regra operacional`: ao analisar ou materializar pacote centrado em `Attribute` top-level, preservar a separacao entre `Objects` e `Attributes`; nao rebaixar `Attribute` real para pseudo-objeto dentro de `<Objects>`.
- `Evidência direta`: no caso publico validado de pacote misto, `Transaction` e `WorkWithForWeb` coexistiram em `<Objects>`, enquanto os atributos novos coexistiram em `<Attributes>`.
- `Regra operacional`: em pacote misto com `Transaction`, `WorkWithForWeb` e atributos novos, manter `Transaction` e `WorkWithForWeb` em `<Objects>` e os atributos top-level em `<Attributes>`.
- `Regra operacional`: se o pacote misto incluir `WorkWithForWeb`, preservar no bloco `Dependencies` a referencia de `Pattern` correspondente.
- `Evidência direta`: no acervo extraido para filesystem Windows, apareceu ao menos um caso real de nome logico invalido como nome de arquivo (`ThemeClass` com `name="ImageHandCenter:hover"`), materializado em disco como `ImageHandCenter_hover.xml`.
- `Regra operacional`: quando o nome logico do objeto ou atributo contiver caractere invalido para o filesystem alvo, aplicar normalizacao minima, deterministica e rastreavel apenas no nome do arquivo em disco, preservando o `name` interno do XML sem alteracao.
- `Regra operacional`: na auditoria de completude entre o XML total e o acervo extraido, comparar por `tipo + nome logico` e considerar explicitamente a camada de normalizacao de filename quando houver caractere invalido para o filesystem.

### Politica para `Theme`

- `Evidência direta`: o `Theme 'ThemeExemploMobileA'` falhou isoladamente mesmo sendo objeto real, com ausencia de `Theme class 'TableDetail'`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: quando essas tres `ThemeClass` reais foram importadas junto, o `Theme 'ThemeExemploMobileA'` importou com sucesso.
- `Evidência direta`: o export real `XPZExemploTemaA.xpz` mostrou a pilha visual exportada como familia combinada.
- `Inferência forte`: nesta trilha, `Theme` deve ser tratado como dependente de `ThemeClass` materializadas na KB, e nao apenas do XML do proprio tema.
- `Inferência forte`: quando a meta for engenharia reversa da camada visual, `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` devem ser lidos como familia conjunta.
- `Regra operacional`: antes de materializar `Theme`, levantar as `ThemeClass` referenciadas pelo grafo minimo do tema e inclui-las no pacote.
- `Regra operacional`: falha “Theme class X does not exist” deve ser tratada como dependencia faltante de `ThemeClass`, nao como prova de erro no `Theme` principal.

### Politica para `PatternSettings`

- `Evidência direta`: o teste sintetico inicial resultou em `was not changed`, mas o teste posterior com `Pattern Settings 'WorkWith'` real importou com sucesso.
- `Inferência forte`: `PatternSettings` deixa de ser pendencia estrutural aberta e passa a depender principalmente de pattern real compativel com o ambiente.
- `Regra operacional`: sempre preferir `PatternSettings` reais do pattern alvo; se o log disser `pattern nao registrado`, tratar como incompatibilidade do ambiente, nao como erro do envelope.
- `Evidência direta`: no par minimo `XPZExemploTRNWWComparacaoSemWW.xpz` e `XPZExemploTRNWWComparacaoComWW.xpz`, a inclusao de `WWExemploMinPaisA` elevou o pacote de `25` para `49` identidades em `ObjectsIdentityMapping`, mesmo acrescentando apenas um objeto top-level.
- `Inferência forte`: para `WorkWithForWeb`, o aumento de risco operacional nao esta apenas no XML do pattern; ele tambem aparece como ampliacao do grafo de identidades e dependencias de contexto.
- `Regra operacional`: ao montar pacote minimo com `WorkWithForWeb`, comparar sempre a lista de `ObjectsIdentityMapping` com a versao sem `WW`; o delta de identidades ajuda a separar dependencia real do pattern de ruido do contêiner.

### Politica para `Table` e `Index`

- `Evidência direta`: nesta trilha, `Table` aparece como familia top-level propria e `Index` aparece embutido dentro de `Table`.
- `Evidência direta`: o export isolado de `Index` veio vazio, enquanto `Table + Index` repetiu a mesma serializacao top-level de `Table`.
- `Evidência direta`: pacotes combinados com `Transaction` mostraram `Table` convivendo no mesmo `.xpz` com `Transaction`, `WorkWithForWeb`, `PatternSettings` e `DataSelector`.
- `Evidência direta`: comparacao privada posterior com pares reais da KB de origem confirmou repeticao da correspondencia nominal entre `Transaction` e `Table`, tanto em caso simples quanto em caso mais denso.
- `Evidência direta`: na mesma comparacao privada, a chave do primeiro `Level` da `Transaction` coincidiu com o bloco `<Key>` da `Table`, inclusive em casos de chave composta.
- `Evidência direta`: na mesma amostra, cada `Table` comparada apresentou `1` indice `Unique` automatico para a chave e um conjunto variavel de indices `Duplicate` `Automatic` e `User`.
- `Evidência direta`: na mesma amostra privada, todos os membros de indices `Automatic` observados ja existiam como atributos do primeiro `Level` da `Transaction` correspondente.
- `Evidência direta`: nesta KB, prefixo `I` identifica indice automaticamente criado pelo GeneXus a partir de PK ou FK definidas pelo modelador.
- `Evidência direta`: nesta KB, prefixo `U` identifica indice criado manualmente pelo operador humano.
- `Evidência direta`: quando um indice automatico `I...` recebe nome mais amigavel, a alteracao e apenas no nome; campos, ordem e natureza do indice permanecem os mesmos.
- `Evidência direta`: o naming default do GeneXus para indices automaticos e pouco descritivo, normalmente derivado do nome da `Table` com numeracao incremental a partir do segundo indice.
- `Evidência direta`: nos indices automaticos de FK, os campos seguem a mesma ordem estabelecida pelo modelador na `Transaction` e refletida na `Table`.
- `Evidência direta`: na mesma amostra, os indices `Automatic` `Duplicate` apareceram principalmente como atributo unico `...Id` ou como par `...EmpresaId + ...Id|...Codigo`.
- `Evidência direta`: na mesma investigacao privada, varios atributos `...Id` e `...Codigo` do primeiro `Level` nao reapareceram em indices `Automatic`, inclusive em objetos mais densos.
- `Evidência direta`: os nomes amigaveis de varios indices `Duplicate` observados nesta KB devem ser lidos como convencao local da KB, e nao como naming default do GeneXus.
- `Evidência direta`: abreviacoes e nomes descritivos observados em indices desta KB decorrem da renomeacao humana para manutencao, log e diagnostico; nao devem ser tratados como naming automatico do GeneXus nem como comportamento normal diante de limite de 63 caracteres.
- `Evidência direta`: numa ampliacao posterior da amostra privada para o conjunto local de `Table`, o formato mais recorrente de indice `Automatic` `Duplicate` foi o par `...EmpresaId + ...Id|...Codigo`, seguido por indices unicos de auditoria de usuario e por `...EmpresaId` isolado.
- `Evidência direta`: na mesma ampliacao, parte relevante das `Table` locais acumulou ao mesmo tempo indices automaticos de relacionamento principal e de auditoria de usuario, mas esse padrao nao cobriu todo o conjunto.
- `Evidência direta`: numa releitura posterior do conjunto local completo com parse direto do bloco `<Indexes>`, `143/228` `Table` apresentaram pelo menos um indice `User`, enquanto `85/228` nao apresentaram nenhum `User`.
- `Evidência direta`: nesse mesmo recorte, entre as `Table` sem `User`, `69/85` ficaram com apenas `1` ou `2` indices `Automatic` `Duplicate`; entre as `Table` com `User`, `124/143` ficaram na faixa de `1` a `3` indices `User`.
- `Evidência direta`: a releitura ampla encontrou apenas `3` `Table` sem qualquer indice `Automatic` `Duplicate`: `OperacaoFiscal`, `Pais` e `TipoDocumento`; nas tres, ainda assim havia pelo menos um indice `User`.
- `Evidência direta`: no mesmo recorte amplo, o acervo totalizou `429` indices `User`; `239/429` continham pelo menos um `Member` em `Descending`, e `229/429` terminavam com o ultimo `Member` em `Descending`.
- `Evidência direta`: no mesmo recorte, `190/429` indices `User` ficaram totalmente em `Ascending`, mostrando que nem todo indice manual desta KB existe para ordenacao descendente; parte deles cobre busca ou navegacao por combinacoes especificas de negocio.
- `Inferência forte`: para engenharia reversa da camada fisica, a unidade minima util nao e `Index` solto, e sim `Table` comparavel, preferencialmente junto da `Transaction` correspondente.
- `Inferência forte`: indices automaticos de auditoria devem ser lidos, nesta KB, como indices de FK automaticamente criados pelo GeneXus e depois eventualmente renomeados de forma amigavel.
- `Inferência forte`: indice `User` deve ser lido como tuning manual empirico, criado quando a ordenacao real de grid, relatorio ou procedure nao e bem atendida pelos indices automaticos e o volume esperado justifica um indice dedicado.
- `Inferência forte`: um caso recorrente de indice `User` e reaproveitar quase a mesma composicao de um indice automatico, mas com direcao `Descending` no ultimo campo para acelerar busca do registro mais recente.
- `Inferência forte`: a familia residual mais comum fora das `Table` com varios `User` nao e ausencia total de indice, e sim `Table` que permanece suficiente com PK e poucos `Automatic` `Duplicate`.
- `Inferência forte`: os casos sem `Automatic` `Duplicate` formam excecao pequena e simples; neles, o `User` tende a cumprir papel unico de busca ou ordenacao por atributo de negocio.
- `Inferência forte`: `OperacaoFiscal`, `Pais` e `TipoDocumento` devem ser tratados nesta trilha como excecoes locais da KB, potencialmente sujeitas a revisao de modelagem, e nao como moldes preferenciais para inferencia da camada fisica.
- `Regra operacional`: nao classificar `Index` como objeto top-level independente nesta trilha sem nova evidencia estrutural externa.
- `Regra operacional`: ao materializar ou revisar `Table`, preservar o bloco de chave e o bloco `<Indexes>` integralmente, incluindo ordem dos `TableIndex`, `Index/@Type`, `Index/@Source` e ordem dos `Member`.
- `Regra operacional`: quando a leitura exigir ponte com a camada logica, validar primeiro a correspondencia nominal e estrutural entre `Transaction` e `Table`; so depois analisar os `Index` embutidos.
- `Regra operacional`: quando a pergunta for sobre chave fisica basica, usar como primeira leitura conservadora a chave do primeiro `Level` da `Transaction` e conferir se ela reaparece integralmente no bloco `<Key>` da `Table`.
- `Regra operacional`: quando a pergunta for sobre origem de indice `Automatic`, conferir primeiro se os `Members` ja pertencem ao primeiro `Level` da `Transaction`, antes de supor regra extra de runtime ou metadata externa.
- `Regra operacional`: quando a pergunta for sobre autoria do indice nesta KB, tratar prefixo `I` como automatico do GeneXus e prefixo `U` como criacao manual humana, salvo evidencia privada muito forte em contrario.
- `Regra operacional`: se um indice `I...` tiver nome descritivo, assumir primeiro renomeacao editorial do nome, e nao alteracao de composicao, ordem ou tipo.
- `Regra operacional`: na ausencia de evidencia mais forte, tratar como candidatos recorrentes a indice `Automatic` adicional os formatos `...Id` unico e `...EmpresaId + ...Id|...Codigo`, sempre confirmando no molde comparavel antes de concluir.
- `Regra operacional`: nao inferir indice `Automatic` apenas porque o atributo termina em `Id` ou `Codigo`; o criterio mais seguro continua sendo a repeticao em `Table` comparavel do mesmo grupo estrutural.
- `Regra operacional`: quando houver muitos candidatos possiveis no primeiro `Level`, priorizar primeiro a inspeção de pares `...EmpresaId + ...Id|...Codigo`, depois campos de auditoria de usuario, e so depois `...EmpresaId` ou outros `...Id` isolados.
- `Regra operacional`: nao inferir que toda `Table` relevante precise de indice `User`; a ausencia de `U...` pode ser decisao consciente de custo/beneficio quando o volume esperado e pequeno.
- `Regra operacional`: tratar decisao sobre indice `User` como tuning empirico de performance e ordenacao, e nao como regra estrutural previsivel apenas pelo XML.
- `Regra operacional`: se a `Table` comparavel cair fora do nucleo mais carregado de `User`, testar primeiro a hipotese mais conservadora: PK + poucos `Automatic` `Duplicate` ja suficientes, sem `User` adicional.
- `Regra operacional`: so promover hipotese de `User` novo quando houver evidencia comparavel de ordenacao ou busca de negocio nao coberta pelos indices automaticos existentes.
- `Regra operacional`: tratar como excecao rara os casos sem `Automatic` `Duplicate`; quando aparecerem, verificar se o papel do `User` observado e busca simples por descricao/nome ou ordenacao basica por `Id Descendente`.
- `Regra operacional`: nao usar `OperacaoFiscal`, `Pais` ou `TipoDocumento` como molde preferencial para inferir ausencia de `Automatic` `Duplicate` em novas `Table`.
- `Regra operacional`: no acervo operacional atual, materializar esses objetos fisicos em pasta `Table`; se surgir pasta `Index` em algum contexto antigo, tratar isso como legado de extracao, e nao como prova de tipo top-level diferente.
- `Regra operacional`: se o caso concreto depender de afirmar reassociacao fisica exata entre `Transaction`, `Table` e navegacao real da IDE, responder com cautela e separar explicitamente estrutura observada de comportamento runtime inferido.

### Politica para `Folder`

- `Evidência direta`: os exemplos reais de `Folder` usam shape minimo e estavel com `Object/@type=\"00000000-0000-0000-0000-000000000006\"`.
- `Evidência direta`: a IDE importou o caso de teste como `Category`, e as capturas de `New Object` mostraram `Category` como agrupador visual da UI, nao como tipo XML de objeto.
- `Inferência forte`: `Folder` fica encerrado como tipo estrutural simples; a divergencia residual e apenas de nomenclatura exibida pela IDE/importador.
- `Regra operacional`: ao relatar resultado de `Folder`, separar sempre tipo estrutural XML (`Folder`) do rotulo de UI reconhecido no log (`Category`, quando for o caso).

## Ponte estrutura -> runtime por tipo e familia

### Transaction

- `Evidência direta`: 162/183 `Transaction` observadas possuem exatamente 1 `Level`; 12/183 possuem 2 `Level`; 9/183 possuem 3 ou mais `Level`.
- `Inferência forte`: familias simples de 1 nivel tendem a ter risco runtime relativo menor para navegacao do que familias mestre-detalhe e multinivel.
- `Inferência forte`: alta densidade de `AttributeProperties` e muitos atributos referenciais no mesmo nivel sugerem maior sensibilidade a `Extended Table`, filtros e relacoes implicitas.
- `Hipótese`: quando a clonagem altera atributos-chave, `DescriptionAttribute` ou distribuicao entre niveis, o risco runtime cresce junto com o risco estrutural.

### WebPanel

- `Evidência direta`: o recorte estrutural mostra familias com casca minima, casca gerada por defaults/pattern, navegacional com eventos, formulario com acao, lista com grid e combinacoes mais densas.
- `Inferência forte`: familias com `grid` e `events` sao mais sensiveis a carga, refresh e navegacao implicita do que familias de menu/home ou casca simples.
- `Inferência forte`: familias geradas com marcas de `Defaults`, `IsGeneratedObject`, `parent` contextual e elementos de pattern tendem a depender mais do runtime/KB de origem.
- `Hipótese`: quanto maior o numero de controles, links, actions e codigo de evento, maior a chance de existir comportamento nao trivial de autorizacao, refresh, carga condicional ou dependencia de master page.

### Procedure, DataProvider, API e objetos dependentes de pattern

- `Evidência direta`: `Procedure` e `DataProvider` frequentemente expõem blocos `Source`, `Parm` e `Variables`; `API` expõe `Service`, `RestMethod` e eventos `.Before/.After`; `WorkWithForWeb` carrega pattern e parent transacional em 183/183 casos.
- `Inferência forte`: objetos com `pattern`, `parentType` forte e blocos de codigo gerado merecem leitura runtime mais cautelosa porque parte da navegacao e da expectativa funcional vem do contexto de geracao.
- `Inferência forte`: `WorkWithForWeb` e derivados patternizados devem ser tratados como de risco operacional/runtime alto mesmo quando a estrutura parece recorrente.
- `Evidência direta`: no experimento `.md`-only, `Work With for Web 'WorkWithWebTrnTesteMdF1'` importou com sucesso quando o pattern usou o convenio real de atributo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Inferência forte`: para `WorkWithForWeb`, a referencia de atributo do pattern deve ser tratada como convenio estrutural fixo do pattern, e nao como GUID do `Attribute` top-level ou do atributo inline do `Level`.
- `Hipótese`: `API` pequena pode ter runtime simples, mas a presenca de multiplos metodos e eventos de pre/pós-processamento sugere custo invisivel ao olhar apenas o contrato externo.

## Regras de decisao operacional com impacto runtime

- `Quando falar com mais confianca`:
  - `Regra documentada`: quando a conclusao vier diretamente de conceito oficial de GeneXus, como `Base Table`, `Extended Table`, `Load`, `Refresh` ou `Refresh Grid`.
  - `Evidência direta`: quando a estrutura XML mostrar claramente sinais repetidos, como `Level`, `Pattern`, `events`, `grid`, `parent` ou densidade de `AttributeProperties`.
- `Quando falar com cautela`:
  - `Inferência forte`: quando o XML sugere navegacao nao trivial, mas sem relatorio de navegacao ou sem codigo suficiente para confirmar custo e cardinalidade.
  - `Hipótese`: quando a conclusao depender de supor joins, roundtrips ou custo de banco sem prova direta.
- `Quando exigir molde mais proximo`:
  - `Inferência forte`: em `WebPanel` com `grid` + `events` + `parent` ou marcas de objeto gerado.
  - `Inferência forte`: em `Transaction` com 2+ `Level` ou densidade alta de atributos relacionais.
  - `Inferência forte`: em `WorkWithForWeb`, `Panel` gerado por pattern e `API` com eventos server-side relevantes.
- `Quando abortar`:
  - `Inferência forte`: quando a mudanca exigir alterar estrutura e, ao mesmo tempo, houver alto acoplamento com runtime implicito, pattern ou contexto pai-filho nao reproduzivel.
  - `Hipótese`: quando o caso exigir garantir performance, importacao ou comportamento em producao sem validacao externa.

## Limites do que a base ainda nao prova

- `Evidência direta`: esta trilha nao contem relatorios completos de navegacao gerados pela IDE nem medições reais de performance.
- `Regra documentada`: os conceitos oficiais ajudam a interpretar risco, mas nao substituem especificacao nem teste do objeto concreto na KB.
- `Inferência forte`: a base agora consegue responder melhor sobre sensibilidade runtime relativa.
- `Hipótese`: ela ainda nao permite afirmar, sem teste, que um clone vai importar, buildar, navegar bem ou performar de forma aceitavel.

## Referencias oficiais complementares

- `Regra documentada`: `Base Transaction clause` - [docs.genexus.com/en/wiki?25418,Base+Transaction+clause](https://docs.genexus.com/en/wiki?25418,Base+Transaction+clause)
- `Regra documentada`: `Base Transaction in For each command` - [docs.genexus.com/en/wiki?23945,Base+Transaction+in+For+each+command](https://docs.genexus.com/en/wiki?23945,Base+Transaction+in+For+each+command)
- `Regra documentada`: `Load event` - [wiki.genexus.com/commwiki/wiki?8188,Load+event](https://wiki.genexus.com/commwiki/wiki?8188,Load+event)
- `Regra documentada`: `Refresh Grid event` - [wiki.genexus.com/commwiki/wiki?8187,Refresh+Grid+event](https://wiki.genexus.com/commwiki/wiki?8187,Refresh+Grid+event)
- `Regra documentada`: `Web Form Refresh` - [wiki.genexus.com/commwiki/wiki?6566,Web+Form+Refresh](https://wiki.genexus.com/commwiki/wiki?6566,Web+Form+Refresh)

## Heurísticas operacionais acionáveis

### Heurística H01 - Transaction simples de 1 nivel

#### Sinais observáveis
- `Transaction` da familia simples de 1 nivel em `05-transaction-familias-e-templates.md`
- 1 `Level`
- sem subnivel
- baixa ou moderada densidade de `AttributeProperties`

#### Leitura técnica
- `Evidência direta`: 162/183 `Transaction` observadas possuem exatamente 1 `Level`.
- `Regra documentada`: navegacao transacional tende a ser menos sensivel quando o contexto estrutural e mais simples e local.
- `Inferência forte`: esse e o melhor ponto de partida para clonagem controlada de `Transaction`.
- `Hipótese`: a chance de erro runtime relativo e menor do que em familias com detalhe ou muitos atributos relacionais.

#### Ação do agente
- responder com cautela controlada, nao com otimismo
- preservar `Level`, `DescriptionAttribute`, `parent*`, `moduleGuid` e todos os `Part`
- nao prometer importacao, build ou comportamento de navegacao final
- escalar o risco se surgir FK adicional, alteracao de contexto ou mudanca de `DescriptionAttribute`

#### Exemplos de aplicação
- nova `Transaction` simples de cadastro basico deve partir de molde da familia simples de 1 nivel e nao de familia mestre-detalhe

### Heurística H02 - Transaction com 2+ niveis

#### Sinais observáveis
- `Transaction` com 2 ou mais `Level`
- relacao pai-filho explicita
- estrutura mestre-detalhe ou multinivel

#### Leitura técnica
- `Evidência direta`: 21/183 `Transaction` observadas possuem 2 ou mais `Level`.
- `Regra documentada`: multiplos niveis ampliam sensibilidade a contexto transacional e navegacao.
- `Inferência forte`: o risco estrutural e runtime relativo sobe quando ha distribuicao de atributos entre niveis.
- `Hipótese`: mudancas entre niveis podem afetar navegacao, joins implicitos e comportamento nao trivial na KB.

#### Ação do agente
- exigir molde interno muito proximo
- preservar hierarquia inteira e evitar mover atributos entre niveis
- nao prometer simplicidade de manutencao ou boa performance
- abortar se a mudanca exigir redesenho de niveis sem paralelo bruto

#### Exemplos de aplicação
- pedido com itens deve partir de familia mestre-detalhe equivalente, e nao de um molde de 1 nivel

### Heurística H03 - Transaction com alta densidade de AttributeProperties

#### Sinais observáveis
- muitos blocos `AttributeProperties`
- varios atributos referenciais ou de controle no mesmo `Level`
- XML significativamente mais denso que a familia enxuta

#### Leitura técnica
- `Evidência direta`: 177/183 `Transaction` observadas possuem `AttributeProperties`, com densidade variavel.
- `Regra documentada`: atributos fora do contexto imediato podem aumentar sensibilidade a `Extended Table` e navegacao.
- `Inferência forte`: densidade alta de `AttributeProperties` sugere mais pontos de dependencia estrutural e funcional.
- `Hipótese`: a chance de vazamento do molde-base e de erro por coerencia interna cresce junto com a densidade.

#### Ação do agente
- responder com cautela
- preservar atributos, propriedades e referencias internas com diff estrutural rigoroso
- nao tratar remocao de atributos como edicao trivial
- exigir molde mais proximo se houver muitos atributos relacionais ou flags internos

#### Exemplos de aplicação
- `Transaction` com dezenas de `AttributeProperties` nao deve ser usada como casca de edicao agressiva sem familia equivalente

### Heurística H04 - WebPanel casca minima

#### Sinais observáveis
- familia de casca minima em `04-webpanel-familias-e-templates.md`
- layout pequeno
- sem `grid`
- sem eventos relevantes

#### Leitura técnica
- `Evidência direta`: existem familias de `WebPanel` com casca minima e baixa variabilidade interna.
- `Regra documentada`: ausencia de `grid` e de eventos reduz superficie de comportamento server-side observavel.
- `Inferência forte`: esse e o caso menos arriscado dentro de `WebPanel`.
- `Hipótese`: ainda pode haver dependencia externa de `parent`, `MasterPage` ou seguranca.

#### Ação do agente
- responder com confianca relativa, mas ainda conservadora
- preservar `layout`, `Part type`, `parent*` e bindings existentes
- nao prometer que o painel sera totalmente isolado do contexto
- escalar o risco se surgirem actions, links, componentes customizados ou seguranca integrada

#### Exemplos de aplicação
- tela de menu/home simples pode partir de uma casca minima sem tentar herdar familia com grid e eventos

### Heurística H05 - WebPanel gerado por pattern/defaults

#### Sinais observáveis
- marcas como `Defaults`, `IsGeneratedObject`, `WEB_COMP=Yes`
- `parent` contextual
- assinatura recorrente de objeto gerado

#### Leitura técnica
- `Evidência direta`: ha familias de `WebPanel` com sinais explicitos de defaults/pattern no acervo.
- `Regra documentada`: objetos gerados tendem a depender mais do contexto de geracao e navegacao da KB.
- `Inferência forte`: isso aumenta o risco operacional e runtime relativo.
- `Hipótese`: parte do comportamento esperado pode estar fora do XML isolado, em pattern, master page ou objeto pai.

#### Ação do agente
- exigir molde interno mais proximo
- preservar marcas estruturais e contexto de `parent`
- nao responder com linguagem otimista do tipo “casca simples”
- abortar se o caso exigir descolar o objeto do contexto gerado sem paralelo bruto

#### Exemplos de aplicação
- `WebPanel` vindo de familia gerada por defaults nao deve ser reaproveitado como molde generico para tela livre

### Heurística H06 - WebPanel com events

#### Sinais observáveis
- bloco `Events` com codigo real
- actions, chamadas de objetos ou regras condicionais
- variaveis ligadas a fluxo de tela

#### Leitura técnica
- `Evidência direta`: 437/1196 `WebPanel` mostram sinal estrutural de eventos.
- `Regra documentada`: eventos em Web podem acionar refresh, carga Ajax e logica server-side adicional.
- `Inferência forte`: a presenca de eventos aumenta a chance de comportamento contextual nao trivial.
- `Hipótese`: o custo real depende do codigo e da navegacao que nao aparecem integralmente so pela assinatura superficial.

#### Ação do agente
- responder com cautela
- preservar eventos, nomes de controles referenciados e variaveis envolvidas
- nao prometer que editar texto ou layout sera suficiente
- escalar o risco se os eventos chamarem procedimentos, seguranca, validacoes ou navegacao indireta

#### Exemplos de aplicação
- painel com `Event Start` e eventos de botao deve ser tratado como painel comportamental, nao apenas visual

### Heurística H07 - WebPanel com grid + events

#### Sinais observáveis
- familia com `grid`
- bloco `Events`
- possivel `Load`, `Refresh` ou filtros/acoes associados

#### Leitura técnica
- `Evidência direta`: ha `WebPanel` com assinatura estrutural de `grid` e eventos no acervo, embora sejam minoria relativa.
- `Regra documentada`: grid com base de navegacao pode executar `Load` por linha; eventos e refresh aumentam sensibilidade de runtime.
- `Inferência forte`: esta e uma das combinacoes mais sensiveis para custo, carga repetida e dependencia de contexto.
- `Hipótese`: sem relatorio de navegacao, o risco de leitura incompleta do runtime continua alto.

#### Ação do agente
- exigir molde interno muito proximo
- preservar estrutura de grid, eventos, filtros, bindings e ordem dos blocos
- nao tratar como casca simples nem autorizar simplificacao agressiva
- abortar se a familia estrutural equivalente nao estiver clara

#### Exemplos de aplicação
- lista com grid filtravel e eventos de acao deve partir de familia de lista/grid equivalente e nao de menu simples

### Heurística H08 - Procedure/DataProvider com sensibilidade de navegacao

#### Sinais observáveis
- codigo `Source` com consultas, filtros, ordens ou mapeamentos
- `Parm` e `Variables` conectados a atributos
- saida estruturada em `DataProvider` ou logica procedural em `Procedure`

#### Leitura técnica
- `Evidência direta`: `Procedure` e `DataProvider` expõem blocos de codigo, parametros e variaveis no acervo.
- `Regra documentada`: navegacao nesses objetos depende de `For each`, grupos, atributos usados e base implicita/explicita.
- `Inferência forte`: esses objetos podem parecer simples no XML externo, mas carregar sensibilidade alta de navegacao no codigo.
- `Hipótese`: custo e qualidade de especificacao podem variar muito conforme filtros, ordens e atributos usados.

#### Ação do agente
- responder com cautela
- preservar assinatura de parametros, blocos de codigo e relacao entre variaveis e atributos
- nao falar de `For each` ou performance sem considerar `Base Table` e navegacao
- exigir molde mais proximo se o codigo tocar consulta de dados relevante

#### Exemplos de aplicação
- `DataProvider` com filtros e mapeamento de SDT deve ser clonado a partir de outro `DataProvider` com forma de consulta comparavel

### Heurística H09 - Dependencia forte de parent/pattern

#### Sinais observáveis
- `parent`, `parentGuid`, `parentType` presentes
- `Pattern=` ou marcas de objeto gerado
- contexto estrutural amarrado a objeto pai

#### Leitura técnica
- `Evidência direta`: `WorkWithForWeb` aparece com `parent` e `pattern` em 183/183 casos; varios outros tipos dependem fortemente de `parent`.
- `Regra documentada`: objetos dependentes de contexto gerado ou pai tendem a trazer comportamento e navegacao herdados da KB.
- `Inferência forte`: esse e um forte sinal de cautela operacional e runtime.
- `Hipótese`: remover ou trocar esse contexto pode quebrar comportamento esperado mesmo que o XML permaneça bem-formado.

#### Ação do agente
- exigir molde muito proximo ou contexto completo
- preservar todos os vinculos de `parent*`, `moduleGuid` e marcas de pattern
- nao autorizar “generalizacao” do objeto
- abortar se o objetivo for desacoplar o objeto do pai/pattern sem base real equivalente

#### Exemplos de aplicação
- `WorkWithForWeb` deve ser tratado como altamente dependente do objeto pai transacional e do pattern de origem

### Heurística H10 - Quando exigir molde mais proximo ou abortar

#### Sinais observáveis
- mistura de familias
- blocos raros/opacos
- evento + grid + contexto pai
- multinivel transacional
- pattern sem equivalente claro

#### Leitura técnica
- `Evidência direta`: a base ja documenta familias, riscos e dependencias contextuais para os tipos mais sensiveis.
- `Regra documentada`: runtime e navegacao nao podem ser garantidos apenas por semelhanca superficial de XML.
- `Inferência forte`: quando sinais de alta sensibilidade se acumulam, a postura correta deixa de ser “seguir” e passa a ser “exigir molde” ou “abortar”.
- `Hipótese`: insistir em clonagem nessas condicoes aumenta bastante a chance de erro estrutural ou runtime.

#### Ação do agente
- exigir molde mais proximo quando ainda houver caminho estrutural comparavel
- abortar quando nao houver familia equivalente ou quando a mudanca pedir invencao de estrutura
- nao prometer importacao, build, navegacao correta ou performance
- deixar explicito o motivo do aborto

#### Exemplos de aplicação
- `WebPanel` com grid, eventos, parent gerado e controles raros sem familia equivalente deve ser abortado em vez de improvisado

## Anti-patterns operacionais

- nunca inferir boa performance so pelo XML
- nunca responder “vai buildar” ou “vai importar” sem evidencia externa
- nunca tratar `grid + events` como casca simples
- nunca responder sobre `For each` sem considerar `Base Table`, navegacao e contexto de atributos
- nunca autorizar edicao agressiva em `Transaction` multinivel sem molde equivalente
- nunca usar entusiasmo estrutural para atropelar heuristica que mandou exigir molde ou abortar
- nunca gerar bloco especial de KB (`KnowledgeBase`, `Settings` ou elemento top-level com o nome da KB) em `.xpz` normal de objetos

## Origem incorporada - 02-genexus-xpz-generation-rules.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
01-base-empirica-geral.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
02-regras-operacionais-e-runtime.md, 02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Registrar regras conservadoras para qualquer tentativa futura de geração de XPZ.
Explicitar o que a base já sustenta e o que ainda permanece apenas heurístico.

## Premissa

Este arquivo não assume que a geração sintética de `XPZ` já esteja provada para qualquer cenário. Ele traduz apenas o que pode ser sustentado pelo inventário bruto e pelos XMLs extraídos desta KB.

## Regras com classificação explícita

### Regra 1

- `Evidência direta`: os objetos extraídos são compostos por um nó `<Object ...>` com metadados e, em muitos casos, múltiplos blocos `<Part type="...">`.
- `Inferência forte`: qualquer geração futura de `XPZ` deve preservar essa forma básica por objeto, em vez de tentar reduzir tudo a um XML simplificado de campos soltos.

### Regra 2

- `Evidência direta`: objetos do mesmo diretório extraído compartilham o mesmo GUID em `Object/@type`.
- `Inferência forte`: ao gerar objetos, o `Object/@type` precisa ser coerente com o grupo/tipo que se deseja representar.
- `Hipótese`: um `Object/@type` incorreto pode até importar em alguns cenários, mas a chance de inconsistência estrutural é alta.

### Regra 3

- `Evidência direta`: vários objetos dependem de `parent`, `parentGuid`, `parentType` e `moduleGuid`.
- `Inferência forte`: uma geração segura deve manter esses vínculos quando o objeto observado os utiliza.
- `Hipótese`: omitir esses vínculos pode causar importação parcial, reposicionamento inesperado na KB ou perda de associação lógica.

### Regra 4

- `Evidência direta`: o acervo mostra conjuntos recorrentes de `Part type` por grupo como `Procedure`, `WebPanel`, `Transaction`, `SDT` e `SubTypeGroup`.
- `Inferência forte`: a geração deve partir de objetos-modelo reais do mesmo tipo, e não de um conjunto de `Part type` inventado.

### Regra 5

- `Evidência direta`: `WorkWithForWeb` contém `parentType` apontando para `Transaction` e carrega `<Data Pattern="...">`.
- `Inferência forte`: objetos gerados por pattern parecem depender mais do contexto do objeto pai do que objetos isolados como `Domain` simples.
- `Hipótese`: gerar pattern objects sem o contexto correspondente pode resultar em imports frágeis ou semanticamente incompletos.

### Regra 6

- `Evidência direta`: o inventário bruto trabalha no nível de objeto extraído, sem registrar alterações globais de KB, versão ou ambiente.
- `Inferência forte`: uma política conservadora de geração deve priorizar pacotes focados em objetos, evitando expandir o escopo para metadados globais sem necessidade comprovada.
- `Hipótese`: esse recorte mínimo tende a reduzir efeito colateral, mas isso ainda precisa de teste de importação controlado.

### Regra 7

- `Evidência direta`: o inventário atual conseguiu ler `7219` XMLs sem erros estruturais.
- `Inferência forte`: antes de empacotar qualquer geração, é razoável exigir ao menos XML bem-formado e consistência interna dos atributos observados.
- `Hipótese`: uma validação adicional por diff estrutural contra objetos-modelo do mesmo tipo deve aumentar a taxa de sucesso de importação.

## Política prática sugerida

- `Inferência forte`: para um primeiro gerador, começar pelos tipos com estrutura mais legível no acervo, como `Domain`, `SDT`, `Procedure` e talvez `WebPanel` simples.
- `Inferência forte`: tratar `Transaction`, `WorkWithForWeb`, `ThemeClass`, `SubTypeGroup` e objetos de pattern como classes de maior risco estrutural.
- `Hipótese`: objetos com menos `Part type`, menos relacionamentos aparentes e menos dependência de pattern devem ser os melhores candidatos iniciais para geração automatizada.

## O que este acervo ainda não prova

- `Evidência direta`: o inventário bruto não registra testes de importação, build ou execução.
- `Hipótese`: portanto, qualquer regra de geração aqui ainda é preparatória e não conclusiva.


## Origem incorporada - 20-guia-de-clonagem-segura.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Traduzir a análise empírica em orientação prudente para clonagem conservadora de objetos.
Indicar o que preservar, o que exige molde bruto comparável e onde o risco cresce.

Este guia e operacional, mas conservador.

- Evidência direta: ele se baseia em recorrencia de atributos, Part type, parent/module e blocos textuais observados.
- Inferência forte: pode alterar aqui significa bom candidato para clonagem controlada, nao garantia de importacao.

## API

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 36e32e2d-023e-4188-95df-d13573bac2e0.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 9f577ec2-27f4-4cf4-8ad5-f3f50c9d69b5; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: objetos com parent: 1/1; com pattern: 0/1.

## DataProvider

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 2a9e9aba-d2de-4801-ae7f-5e3819222daf.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 1d8aeb5a-6e98-45a7-92d2-d8de7384e432; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; e4c4ade7-53f0-4a56-bdfd-843735b66f47.
- Evidência direta: objetos com parent: 24/24; com pattern: 0/24.

## DesignSystem

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 78b3fa0e-174c-4b2b-8716-718167a428b5.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: medio.
- Evidência direta: Part type mais recorrentes: 36982745-cb77-47a3-bc04-9d0d764ff532; 75e52d99-6edd-4bad-a1d7-dcc9b7f000ef; babf62c5-0111-49e9-a1c3-cc004d90900a; c6b14574-4f5f-4e35-aaa7-e322e88a9a10.
- Evidência direta: objetos com parent: 1/2; com pattern: 0/2.

## PackagedModule

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c88fffcd-b6f8-0000-8fec-00b5497e2117.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: alto.
- Evidência direta: Part type mais recorrentes: babf62c5-0111-49e9-a1c3-cc004d90900a; ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc; a5e6a251-2df0-44d8-adab-1da237574326.
- Evidência direta: objetos com parent: 2/16; com pattern: 0/16.

## Panel

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = d82625fd-5892-40b0-99c9-5c8559c197fc.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: b4378a97-f9b2-4e05-b2f8-c610de258402; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 7/7; com pattern: 7/7.

## Procedure

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 84a12160-f59b-4ad7-a683-ea4481ac23e9.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 528d1c06-a9c2-420d-bd35-21dca83f12ff; 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c414ed00-8cc4-4f44-8820-4baf93547173.
- Evidência direta: objetos com parent: 2281/2281; com pattern: 0/2281.

## SDT

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 447527b5-9210-4523-898b-5dccb17be60a.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 591/594; com pattern: 0/594.

## Theme

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c804fdbd-7c0b-440d-8527-4316c92649a6.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: alto.
- Evidência direta: Part type mais recorrentes: 43b86e51-163f-44af-ac5a-e101541b1a71; babf62c5-0111-49e9-a1c3-cc004d90900a; c31007a6-01d3-4788-95b3-425921d47758.
- Evidência direta: objetos com parent: 0/7; com pattern: 0/7.

## Transaction

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 1db606f2-af09-4cf9-a3b5-b481519d28f6.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 264be5fb-1b28-4b25-a598-6ca900dd059f; 4c28dfb9-f83b-46f0-9cf3-f7e090b525d5; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa.
- Evidência direta: objetos com parent: 183/183; com pattern: 0/183.

## WebPanel

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = c9584656-94b6-4ccd-890f-332d11fc2c25.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: 763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9; 9b0a32a3-de6d-4be1-a4dd-1b85d3741534; ad3ca970-19d0-44e1-a7b7-db05556e820c; babf62c5-0111-49e9-a1c3-cc004d90900a; c44bd5ff-f918-415b-98e6-aca44fed84fa; d24a58ad-57ba-41b7-9e6e-eaca3543c778.
- Evidência direta: objetos com parent: 1195/1196; com pattern: 0/1196.

## WorkWithForWeb

- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = 78cecefe-be7d-4980-86ce-8d6e91fba04b.
- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.
- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.
- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e exigem molde bruto comparável antes de alteracao.
- Nivel de confianca atual da clonagem: baixo.
- Evidência direta: Part type mais recorrentes: a51ced48-7bee-0001-ab12-04e9e32123d1; babf62c5-0111-49e9-a1c3-cc004d90900a.
- Evidência direta: objetos com parent: 183/183; com pattern: 183/183.



## Origem incorporada - 24-resumo-operacional-para-gerador-xpz.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md

## Usado por
02-genexus-xpz-generation-rules.md, 26-guia-para-agente-gpt.md

## Objetivo
Concentrar as instruções práticas mais curtas para um gerador GPT orientado por clonagem conservadora.
Funcionar como resumo decisório sem esconder os limites da evidência.

## Premissa

- Evidência direta: este resumo deriva apenas do acervo XML extraído e dos relatórios `10` a `16`.
- Inferência forte: ele serve para reduzir tentativa e erro por clonagem conservadora.
- Hipótese: ele nao substitui validacao real por importacao, abertura na IDE e build.

## Algoritmo sugerido de geracao por clonagem

1. Escolher o tipo alvo e localizar um molde XML completo do mesmo diretório e do mesmo `Object/@type`.
2. Preferir template do mesmo contexto estrutural do alvo:
   mesmo uso de `parent`, mesmo uso de `pattern`, mesma familia de objeto.
3. Preservar integralmente `Object/@type`, `guid`, `parent`, `parentGuid`, `parentType`, `moduleGuid` e todos os `Part type` recorrentes do template.
4. Alterar primeiro apenas nomes, descricoes e blocos textuais claramente recorrentes.
5. Rejeitar a clonagem se surgir qualquer bloco raro, opaco ou ausente no molde comparavel.
6. So empacotar depois de validar XML bem-formado e diff estrutural contra o molde-base.

## Quando abortar a geracao

- Inferência forte: abortar quando o tipo estiver em risco `alto` ou `muito alto` e nao houver molde suficientemente proximo.
- Inferência forte: abortar quando o objeto alvo exigir `pattern` ou contexto de `parent` nao representado no molde.
- Inferência forte: abortar quando o molde comparavel tiver mais de um bloco raro/exclusivo que ainda nao foi entendido.
- Hipótese: abortar tambem quando a mudanca pretendida exigir alterar blocos nao textuais pouco recorrentes.

## Quando exigir molde bruto comparável

- Evidência direta: exigir molde bruto comparável muito proximo para tipos ainda sem anexo XML completo equivalente nesta base.
- Evidência direta: exigir molde bruto comparável tambem para `DesignSystem`, por causa da amostra muito pequena.
- Inferência forte: para `Theme` e `PackagedModule`, um molde bruto comparável proximo continua sendo a opcao mais segura, mesmo quando a estrutura pareca menos agressiva.
- Hipótese: `Domain` agora ja pode partir dos anexos sanitizados desta base tanto em casos escalares quanto enumerados, desde que o clone preserve `ATTCUSTOMTYPE`, limites e `IDEnumDefinedValues` quando existirem.
- Hipótese: `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` agora ja contam com moldes sanitizados completos representativos; mesmo assim, `DesignSystem` continua pedindo cuidado extra quando houver imports, tokens e regras visuais extensas, `ThemeClass` continua pedindo preservacao rigorosa da cadeia `parent` quando houver variantes derivadas, `ThemeColor` e `ColorPalette` continuam extremamente declarativos mas ainda devem preservar identidade nominal e organizacao tematica, `Image` continua pedindo preservacao cuidadosa do binario em `base64`, dos `ImageItem` e das referencias de tema, `Index` continua pedindo preservacao rigorosa da ordem dos `Members`, do `Type` e do `Source` de cada indice, `PatternSettings` continua pedindo cuidado com referencias internas de seguranca/contexto, `DataStore` segue bastante declarativo, `Dashboard` segue sensivel a referencias internas de objetos analiticos, `DeploymentUnit` segue dependente da lista completa de `Member`, `Generator` segue bastante declarativo mas ainda pede preservacao de flags como `IsUser`, `IsDefaultCategory`, `IsReorg` e `DefaultType`, `Language` pede preservacao integral do bloco de `Translations`, `Folder` segue simples e declarativo, `Stencil` pede cuidado alto com `CDATA`, screenshots embutidos, controles e referencias visuais textuais, e `File` pede preservacao rigorosa do `base64Binary`, do nome extraido e dos caminhos de extracao.
- Hipótese: `ExternalObject`, `UserControl`, `Module` e `SubTypeGroup` agora tambem contam com moldes sanitizados completos representativos; dentro desse grupo, `ExternalObject` e `UserControl` merecem cautela extra quando carregarem contratos externos, scripts ou eventos mais densos, enquanto `SubTypeGroup` segue mais declarativo, mas ainda sensivel a nomes residuais e mapeamentos de subtype/supertype.
- Hipótese: `SDT` agora ja pode partir dos anexos sanitizados desta base em cenarios pequenos e medios, mas casos com metadata externa muito especifica ainda merecem comparacao com molde bruto mais proximo.

## Politica para Transaction

- Evidência direta: existem 183 `Transaction` no acervo.
- Inferência forte: usar padrao estrutural inferido da propria base em vez de bloquear execucao por falta de exemplo.
- Inferência forte: escolher uma familia simples e estruturalmente proxima do alvo.
- Evidência direta: a bateria de importacao mostrou que `Transaction` pode manter envelope coerente e ainda falhar por atributos inexistentes e tipos de contexto nao resolvidos na KB de destino.
- Inferência forte: para `Transaction`, a ordem correta de validacao e `familia estrutural -> atributos reais do Level -> tipos de contexto -> regras e eventos`.
- Inferência forte: nao abortar so por ausencia de template externo; a referencia principal passa a ser molde interno da propria base.
- Hipótese: os erros por objeto devem ser tratados incrementalmente para refinar os documentos.

## Politica para API

- Evidência direta: o acervo desta trilha traz apenas `1` `API` real, e a consulta a esse caso confirmou uso pesado de `ATTCUSTOMTYPE`, `EXO`, `SDT` e chamadas a `Procedure`.
- Evidência direta: esse caso real deve ser lido como construcao manual/local da KB, sem evidencia nesta trilha de automacao complementar de terceiros.
- Evidência direta: a bateria de importacao mostrou que `API` pode falhar sem erro de envelope, apenas por `ATTCUSTOMTYPE` nao conversivel ou tipo inexistente no destino.
- Inferência forte: para `API`, a ordem correta de validacao e `molde estrutural -> ATTCUSTOMTYPE valido -> EXO e SDT existentes -> Procedure e eventos chamados`.
- Inferência forte: em `API`, trocar nomes e codigo sem fechar primeiro a camada de tipos tende a produzir falha semantica imediata.
- Hipótese: os erros por API tambem devem ser tratados incrementalmente, priorizando tipos e referencias antes de mexer em regras ou eventos.

## Politica para Theme

- Evidência direta: a consulta ao acervo real confirmou que `Theme` simples valido preserva `PredefinedTypes`, `Styles` e classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- Evidência direta: a bateria de importacao mostrou que `Theme` pode falhar mesmo com envelope correto quando o pacote perde classes visuais referenciadas internamente.
- Inferência forte: para `Theme`, a ordem correta de validacao e `molde estrutural -> PredefinedTypes e Styles -> classes base existentes -> referencias internas entre classes`.
- Inferência forte: em `Theme`, podar classe "aparentemente sobrando" antes de mapear as referencias internas e a forma mais comum de quebrar o import.
- Hipótese: os erros por `Theme` devem ser tratados por reconstrucao do grafo minimo de classes, nao por simplificacao progressiva do XML.

## Politica para PatternSettings

- Evidência direta: a consulta ao acervo real confirmou que `PatternSettings` embute configuracao em `CDATA` com `Pattern="..."`, `ContextVariable`, `LoadProcedure`, `Security` e outros elementos do pattern.
- Evidência direta: a bateria de importacao mostrou que `PatternSettings` pode ser lido pela IDE e ainda assim resultar em `was not changed`, com aviso de pattern nao registrado.
- Inferência forte: para `PatternSettings`, a ordem correta de validacao e `Pattern registrado -> contexto e procedures do pattern -> seguranca e referencias auxiliares -> detalhe declarativo interno`.
- Inferência forte: em `PatternSettings`, editar apenas o XML interno sem garantir pattern e contexto reais tende a produzir objeto estruturalmente aceitavel, mas operacionalmente inutil.
- Hipótese: os erros por `PatternSettings` devem ser tratados como falta de contexto do pattern no ambiente, e nao como problema principal de serializacao.

## Politica para Folder

- Evidência direta: a consulta ao acervo real confirmou que `Folder` usa um shape XML minimo e estavel, com `Object/@type="00000000-0000-0000-0000-000000000006"` e poucos metadados.
- Evidência direta: na bateria de importacao, o caso de teste entrou, mas a IDE o exibiu como `Category`, nao como `Folder`.
- Evidência direta: as capturas da janela `New Object` da IDE mostram que `Category` nomeia o agrupador visual da lista de tipos criaveis, e nao o tipo XML do objeto.
- Evidência direta: nas mesmas capturas, um mesmo tipo pode aparecer sob mais de uma `Category` da UI, portanto `Category` nao se comporta como identidade estrutural unica de objeto.
- Inferência forte: para `Folder`, a ordem correta de validacao e `shape minimo correto -> parent/module coerentes quando existirem -> leitura semantica da IDE`.
- Inferência forte: aqui o risco principal nao e quebrar o XML, e sim confundir `Category` da UI com tipo estrutural de objeto.
- Inferência forte: para esta trilha, `Folder` deve ser lido como tipo XML estruturalmente aceito, enquanto `Category` deve ser lido como rotulo de agrupamento/exibicao da IDE.
- Hipótese: o importador pode estar reutilizando o mesmo vocabulário visual da IDE ao relatar `Category`, sem implicar mudanca real do tipo estrutural importado.

## Politica para identidade estrutural de objeto sob Folder ou Module

- Evidência direta: no acervo real desta KB, `Procedure` em `Folder` aparece com `fullyQualifiedName` igual ao nome do objeto, enquanto a pasta aparece em `parent` e `parentGuid`.
- Evidência direta: no acervo real desta KB, `WebPanel` em `Folder` segue o mesmo padrao: `fullyQualifiedName` sem prefixo da pasta, e `parent`/`parentGuid` apontando para o contêiner.
- Evidência direta: no acervo real desta KB, objetos sob `Module` podem trazer qualificacao em `fullyQualifiedName`, como `General.Services.DirectionsServiceRequest`.
- Evidência direta: tambem existe caso em que o objeto esta sob `Folder` dentro de `Module`; nesse perfil, o nome do modulo permanece em `fullyQualifiedName`, mas o nome da pasta continua restrito a `parent`.
- Regra operacional: antes de serializar identidade de objeto, classificar primeiro o contêiner por `parentType`.
- Regra operacional: se `parentType="00000000-0000-0000-0000-000000000008"`, tratar o contêiner como `Module/Folder` (Pasta/Módulo do usuário); o nome da pasta nao deve ser promovido automaticamente para `fullyQualifiedName`.
- Regra operacional: se `parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117"`, tratar o contêiner como `PackagedModule` (Módulo instalado); a qualificacao em `fullyQualifiedName` so pode ser mantida ou introduzida quando houver exemplar comparavel da mesma KB confirmando esse padrao.
- Regra operacional: validar sempre em conjunto `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid`; nao validar esses campos isoladamente.
- Regra operacional: `fullyQualifiedName` nao deve ser derivado por concatenacao textual de `parent + "." + name`.
- Regra operacional: se a trilha nao conseguir decidir, por exemplar comparavel, se o contêiner real e `Folder` ou `Module`, a geracao deve abortar antes da serializacao.
- Regra operacional: em clonagem ou criacao a partir de XML existente, validar identidade interna ampliada antes de empacotar: `Object/@name`, `fullyQualifiedName`, `guid`, propriedade `Name`, `Description`, `Source`, `Rules/parm`, chamadas internas, dependencias e `ObjectsIdentityMapping`.
- Regra operacional: toda ocorrencia residual do nome, descricao, GUID ou chamada do objeto molde deve ser classificada como `intencional`, `dependencia necessaria` ou `erro de clonagem`; ocorrencia nao classificada bloqueia o pacote.
- Regra operacional: para objeto novo, `guid` novo nao basta; nomes internos, propriedades nominais, assinatura, chamadas e dependencias tambem precisam deixar de apontar indevidamente para o objeto de origem.

## Politica para WebPanel

- Evidência direta: existem 1196 `WebPanel` no acervo.
- Inferência forte: identificar primeiro a familia estrutural antes de gerar.
- Inferência forte: escolher o molde interno mais proximo, sem generalizar `WebPanel` como tipo homogeneo.
- Inferência forte: manter todos os `Part type` recorrentes do molde escolhido.
- Hipótese: abortar apenas quando nao houver familia estrutural identificavel ou quando a proximidade do molde continuar ambigua.

## Quando aceitar apenas experimento conservador

- Inferência forte: `PackagedModule` e `Theme` sao os melhores candidatos relativos do recorte, mas apenas para experimento muito controlado.
- Inferência forte: `SDT` pode entrar nessa mesma trilha somente quando houver molde muito proximo e preservacao rigorosa de `parent`.
- Inferência forte: `Transaction` e `WebPanel` ficam desbloqueados para execucao controlada usando a propria base como fonte de moldes internos.
- Hipótese: nenhum tipo deste acervo deveria ser liberado para geracao automatica ampla sem uma rodada externa de validacao.

## Validacoes minimas antes de empacotar

- XML bem-formado.
- `Object/@type` coerente com o tipo clonado.
- `Part type` recorrentes preservados.
- `parent*` e `moduleGuid` preservados quando presentes no template.
- `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid` conferidos em conjunto contra exemplar comparavel.
- Revisao manual dos campos textuais alterados.
- Diff estrutural curto entre molde-base e clone.

## Estrategia incremental recomendada

- Inferência forte: comecar por provas de conceito extremamente pequenas.
- Inferência forte: manter o escopo por tipo e por molde, sem misturar familias estruturais diferentes.
- Inferência forte: para `Transaction` e `WebPanel`, priorizar execucao controlada e retroalimentar a base com os erros observados.
- Inferência forte: so depois de casos externos bem-sucedidos vale endurecer linguagem como "obrigatorio", "editavel com baixo risco" ou "apto para geracao conservadora".

## Ajuste no algoritmo

- Inferência forte: `Transaction` nao deve abortar apenas por ausencia de template externo.
- Inferência forte: `WebPanel` deve abortar apenas quando nao houver familia estrutural identificavel ou molde interno suficientemente proximo.

## Regras de materializacao

- Evidência direta: a materializacao final de `Transaction` e `WebPanel` pode partir de um molde XML completo desta base ou de XML bruto real do mesmo `Object/@type`, desde que a estrutura usada seja completa e comparavel.
- Inferência forte: nunca montar um objeto do zero a partir de descricao em markdown; sempre partir de um molde XML completo e editar o clone.
- Regra operacional: ao materializar um acervo de XMLs individualizados para versionamento, manter serializacao textual consistente entre todos os arquivos do lote.
- Regra operacional: quando o pipeline controlar a escrita desses arquivos, preferir declaracao XML explicita com `encoding="utf-8"` como convencao operacional do acervo, sem tratar isso como prova de exigencia universal do GeneXus para qualquer XML interno.
- Regra operacional: a checagem pos-extracao deve validar nao so completude estrutural, mas tambem consistencia de declaracao XML e encoding declarado entre os arquivos materializados.
### Transaction

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid` e inventario completo de `Part` do molde-base
- nao remover `Part` recorrente nem trocar a ordem dos blocos
- alterar apenas campos textuais, nomes e trechos internos que tenham paralelo claro em outros `Transaction` da mesma familia
- validar antes do empacotamento que cada atributo declarado em `Level` exista de fato na KB alvo
- validar que `DescriptionAttribute` e `AttributeProperties` continuem apontando para atributos presentes no mesmo objeto
- validar explicitamente `Context`, `TrnContext` e `TrnContextAtt` quando existirem, incluindo seus `ATTCUSTOMTYPE`
- se um atributo do no `<Object>` nao existir no molde usado, nao inventar esse atributo no clone
- se o caso exigir inventar atributo, `sdt:Context`, `sdt:TransactionContext` ou `sdt:TransactionContext.Attribute` inexistentes no destino, abortar
- se surgir referencia a `parent`, modulo ou pattern que nao exista no molde comparavel, abortar
- `Evidência direta`: em bateria recente de importacao real, uma `Transaction` minima com `1 Level`, `2` atributos, `DescriptionAttribute` e `AttributeProperties` foi aceita com sucesso quando os `Attribute` top-level estavam no pacote e o `Part` principal seguia o shape esperado da familia.
- `Evidência direta`: nessa mesma bateria, `AttributeProperties` funcionou isoladamente e tambem combinado com `DescriptionAttribute`.
- `Evidência direta`: `DescriptionAttribute` foi aceito no caso minimo expandido quando apontava para atributo existente no mesmo `Level`.
- `Evidência direta`: o erro `Level is empty` voltou a aparecer em tentativa com atributos presentes quando o shape estrutural do `Part` principal nao seguia o template esperado.
- `Inferência forte`: nos casos minimos validados, a aceitacao do `Level` dependeu tanto da disponibilidade real dos atributos quanto da preservacao do shape estrutural do `Part` onde o `Level` foi inserido.
- Regra operacional: `Attribute` inline em `Level` nao substitui `Attribute` top-level no pacote.
- Regra operacional: se os atributos do `Level` nao existirem previamente na KB de destino, a composicao minima segura e inclui-los como `Attribute` top-level no mesmo pacote da `Transaction`.
- Regra operacional: `DescriptionAttribute` e opcional no caso minimo, mas quando presente deve apontar para atributo do mesmo `Level`.
- Regra operacional: `AttributeProperties` e opcional no caso minimo e ja foi validado tanto isoladamente quanto combinado com `DescriptionAttribute`.
- Regra operacional: para primeiro pacote minimo de `Transaction`, continuar preferindo validar antes a variante mais enxuta, e so depois enriquecer com `DescriptionAttribute`, `AttributeProperties` ou contexto adicional.

### API

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, inventario de `Part` e blocos estruturais de `Service`, `RestMethod`, `Variables` e eventos do molde-base
- validar antes do empacotamento cada `ATTCUSTOMTYPE` presente no molde ou introduzido na edicao
- aceitar apenas `ATTCUSTOMTYPE` comprovado no destino como tipo base suportado, `EXO` existente ou `SDT` existente
- validar que cada `Procedure` chamada em `Source`, eventos ou metadados exista de fato na KB alvo
- nao inventar nomes de `EXO`, `SDT` ou `Procedure` para "completar" a API
- se o caso exigir tipos ou procedures inexistentes no destino, abortar em vez de simplificar o XML arbitrariamente

### Theme

- preservar `Object/@type`, `guid`, inventario de `Part`, `PredefinedTypes`, `Styles` e a organizacao geral do molde-base
- validar antes do empacotamento que cada classe visual referenciada por outra classe continue existindo no objeto final
- tratar `TableDetail`, `TableSection`, `TextBlockGroupCaption` e classes equivalentes do molde como candidatas fortes a compor o grafo minimo
- nao remover classe apenas porque ela nao parece ser usada diretamente pela tela alvo; primeiro validar referencias indiretas no proprio tema
- se a edicao exigir reduzir o tema abaixo do grafo minimo de classes referenciadas, abortar em vez de simplificar o XML arbitrariamente

### PatternSettings

- preservar `Object/@type`, `guid`, inventario de `Part` e o bloco `<Data Pattern="..."><![CDATA[...]]></Data>` do molde-base
- validar antes do empacotamento se o `Pattern` referenciado no bloco existe de fato no ambiente de destino
- validar que `ContextVariable`, `LoadProcedure`, `Security`, `NotAuthorized` e referencias equivalentes apontem para objetos reais do destino
- nao inventar `Pattern`, `LoadProcedure`, contexto de seguranca ou procedures auxiliares para "completar" o objeto
- se o ambiente nao reconhecer o pattern ou os objetos referenciados, abortar em vez de tratar o XML como autocontido

### Table e Index

- tratar `Table` como objeto top-level da camada fisica e `Index` como estrutura interna embutida
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, bloco de chave e inventario de `Part` do molde-base
- preservar integralmente o bloco `<Indexes>`, sem reordenar `TableIndex`, `Index`, `Members` ou trocar `Type="Automatic|User|Unique|Duplicate"` por conveniencia
- nao tentar materializar `Index` como objeto top-level isolado nesta trilha; quando o caso pedir indice, usar `Table` comparavel que ja o contenha
- quando o objetivo for ponte com a camada logica, validar junto a `Transaction` correspondente em vez de analisar a `Table` como se fosse familia totalmente autonoma
- se a mudanca exigir inferir indice inexistente, chave fisica nova ou correspondencia fisica nao visivel no molde comparavel, abortar

### Folder

- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid` e o inventario minimo de `Part` do molde-base
- preferir o molde mais simples quando a necessidade for apenas organizacao logica de objetos
- nao inflar `Folder` com propriedades extras sem paralelo claro no molde real
- registrar separadamente o tipo estrutural do XML (`Folder`) e o rotulo exibido pela IDE/importador (`Category`, quando ocorrer)
- nao reinterpretar `Category` da UI como prova de outro tipo XML concorrente sem evidencia estrutural adicional
- se o objetivo depender da distincao funcional exata entre `Folder` e o rotulo `Category` na interface, tratar o caso como diferenca de nomenclatura da IDE ate prova contraria, e nao como falha de envelope
- ao gerar objeto dentro de `Folder`, manter o nome da pasta em `parent`/`parentGuid`; nao inserir o nome da pasta em `fullyQualifiedName` sem evidencia direta de corpus

### WebPanel

- escolher primeiro a familia estrutural e so depois o molde interno completo
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, quantidade de `Part` e a ordem dos blocos
- manter `layout`, `events`, `variables` e todos os `Part type` recorrentes do molde selecionado
- nao substituir controles, bindings ou componentes raros por texto livre; se nao houver equivalente estrutural no molde, abortar
- quando houver anexo sanitizado completo e explicitamente preservado nesta base, ele pode servir como molde de partida para prototipo controlado; na falta disso, recorrer ao XML bruto correspondente

## Regras de serializacao XPZ

- Evidência direta: o XML do objeto deve continuar com raiz unica `<Object>` e permanecer bem-formado apos qualquer edicao
- Evidência direta: cada `Part` deve manter seu atributo `type` e seu conteudo no mesmo bloco estrutural do molde-base
- Inferência forte: quando o molde usado trouxer `<![CDATA[...]]>` em `Source` ou `InnerHtml`, o clone deve manter `CDATA`; nao converter esses blocos em texto escapado
- Inferência forte: o objeto pode ser incluido em `<Objects>` usando o envelope XPZ observado e documentado nesta base, desde que o prototipo preserve a mesma hierarquia externa conhecida; nao inventar estrutura fora do que o envelope observado ja demonstra
- Evidência direta: `KMW`, `Source` e `Dependencies` aparecem em todos os `.xpz` validos lidos nesta amostra ampla; `Objects` aparece no formato normal de export de objetos e pode ser substituido por `Attributes` em exportacoes parciais focadas em atributos
- Evidência direta: nos exports normais de objetos com `ObjectsIdentityMapping`, o bloco usa elementos `<ObjectIdentity Type=\"...\" Name=\"...\" parent=\"...\">` contendo `<Guid>...</Guid>`; nao aparece como espelho 1:1 dos objetos exportados
- Evidência direta: em amostra ampla de exports normais, `Object/@guid` nao reaparece em `ObjectsIdentityMapping`; o papel observado do bloco e descrever identidades de contexto, especialmente pais, modulos e referencias auxiliares
- Evidência direta: `ObjectIdentity/@Name`, `ObjectIdentity/@Type` e `ObjectIdentity/Guid` vieram preenchidos nos exports normais lidos; `Source/Version/@name` tambem veio preenchido nesses casos
- Evidência direta: no teste de importacao bem-sucedida desta trilha, `Source/@kb` e `Source/Version/@guid` precisaram estar em formato GUID valido; placeholders textuais causaram erro de parse antes da importacao
- Evidência direta: nos exports normais lidos, `Object/@name` tambem veio sempre preenchido; `Dependency/Properties/@Name` e `Dependency/Properties/@PackageName`, quando presentes, vieram preenchidos
- Evidência direta: campos de nome opcionais existem, mas nao se comportam como invariantes: `Object/@description` apareceu vazio em minoria dos casos e `ObjectIdentity/@parent` apareceu majoritariamente vazio
- Inferência forte: se o objeto exportado tiver `parentGuid` ou `moduleGuid` apontando para contexto externo relevante, o `.xpz` normal fica mais coerente quando `ObjectsIdentityMapping` trouxer a identidade correspondente com o mesmo `Guid`
- Inferência forte: `Dependencies` descreve principalmente metamodelo, parts e pacotes, nao o mapeamento principal de identidade entre objetos exportados e contexto
- Inferência forte: para geracao de `.xpz` de objetos, o bloco especial de KB (`KnowledgeBase` ou elemento top-level com nome literal da KB) deve ser tratado como proibido
- Hipótese forte: o erro `Fail creating backup: Empty name is not allowed.` esta mais ligado ao bloco especial de KB em exports full/especiais, sobretudo quando `KnowledgeBase/@name` falta, do que ao formato normal de `ObjectsIdentityMapping`
- Inferência forte: antes de empacotar, validar parse XML do objeto clonado e validar que o envelope XPZ continua contendo o mesmo padrao estrutural do molde usado
- Hipótese: checksum, datas e outros metadados externos so devem ser recalculados se houver processo real de exportacao que faca isso; na ausencia desse processo, preservar o padrao do molde usado

### Campos de nome invariantes no formato normal

- Evidência direta: `Source/Version/@name` nao apareceu vazio nos exports normais lidos
- Evidência direta: `Object/@name` nao apareceu vazio nos exports normais lidos
- Evidência direta: `ObjectIdentity/@Name` nao apareceu vazio nos exports normais lidos
- Evidência direta: `ObjectIdentity/@Type` e `ObjectIdentity/Guid` tambem vieram sempre preenchidos nos exports normais lidos
- Regra operacional: `ObjectIdentity/@Type` deve ser um GUID valido, derivado do campo `Object/@parentType` do XML de origem do objeto sendo empacotado; nunca usar valor inteiro (como `"1"` ou `"8"`) — valor inteiro causa erro `Guid should contain 32 digits with 4 dashes` no GeneXus durante Import File Load
- Evidência direta: `Source/@kb` e `Source/Version/@guid` precisam ser GUIDs sintaticamente validos para que o GeneXus ao menos aceite o parse inicial do `.xpz`
- Evidência direta: `Dependency/Properties/@Name` e `Dependency/Properties/@PackageName`, quando o no `Properties` existe, vieram preenchidos
- Inferência forte: entre os campos de nome do formato normal, os candidatos mais fortes a obrigatoriedade estrutural sao `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name`
- Hipótese forte: como esses campos vieram consistentes no formato normal, o erro `Empty name is not allowed` fica mais plausivelmente associado ao bloco especial `KnowledgeBase/@name` em variantes especiais do que a um campo nominal do envelope normal

### Coerencia entre `Objects` e `ObjectsIdentityMapping`

- Evidência direta: `ObjectsIdentityMapping` nao repete automaticamente cada objeto de `<Objects>`
- Evidência direta: a correspondencia observada e contextual, principalmente por `parentGuid` e, em muitos pacotes, por `moduleGuid`
- Evidência direta: em amostra ampla de exports normais com `Objects` + `ObjectsIdentityMapping`, a resolucao de `parentGuid` em `Objects` ou `ObjectsIdentityMapping` ocorreu na grande maioria dos casos; para `moduleGuid`, a cobertura foi parcial e frequentemente ligada ao `Root Module`
- Inferência forte: a regra mais segura para serializacao normal de objetos e manter no `ObjectsIdentityMapping` todas as identidades externas realmente referenciadas pelo objeto, sem tentar transformar o bloco em inventario completo de tudo que existe na KB
- Inferência forte: se `parentGuid` ou `moduleGuid` apontarem para um GUID externo que nao exista nem em `<Objects>` nem em `<ObjectsIdentityMapping>`, o pacote fica estruturalmente mais fraco e merece cautela extra

### Pares observados validos

- Evidência direta: em `AJRS_MOSTRA_URL.xpz`, o objeto `PRCExemploMostraUrlA` usa `moduleGuid=afa47377-41d5-4ae8-9755-6f53150aa361` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"Root Module\"` com o mesmo `Guid`
- Evidência direta: em `AJRSgxIonicZip.xpz`, o objeto `DotNetZip` usa `parentGuid=65ff024e-84e1-4042-9321-cd3a230317d6` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"ZipUnzip\"` com o mesmo `Guid`
- Evidência direta: em `AJRS_ConcatenaPdfEouPoeMarcaDagua-2.xpz`, o objeto `ZipFile` usa `parentGuid=9f21f62d-2d18-4f8d-8ec3-8399f3485298` e o `ObjectsIdentityMapping` contem `ObjectIdentity Name=\"DotNetZip\"` com o mesmo `Guid`

### Modelo minimo correto de `.xpz` normal de objetos

```xml
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>4</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <Build>...</Build>
  </KMW>
  <Source kb="GUID_DA_KB" username="USUARIO" UNCPath="\\\\HOST\\CAMINHO">
    <Version guid="GUID_DA_VERSAO" name="NOME_DA_KB" />
  </Source>
  <Objects>
    <Object ... />
  </Objects>
  <Dependencies>
    <Reference ... />
  </Dependencies>
  <ObjectsIdentityMapping>
    <ObjectIdentity Type="..." Name="..." parent="...">
      <Guid>...</Guid>
    </ObjectIdentity>
  </ObjectsIdentityMapping>
</ExportFile>
```

- Evidência direta: `Attributes` e um bloco adicional comum no formato normal, mas nao invariavel
- Inferência forte: para geracao conservadora de objetos comuns, este envelope minimo continua sendo referencia util, mas nao deve ser promovido a formato universal para qualquer pacote misto
- Evidência direta: esse envelope minimo ja sustentou uma importacao bem-sucedida de um `Procedure` de teste nesta trilha, desde que os GUIDs de `Source` fossem sintaticamente validos
- Evidência direta: em frente posterior desta mesma trilha, um pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure` so passou quando foi remontado como pacote embutido, tomando export real comparavel da IDE como molde.

## Regras de fonte

- Fonte valida: XML bruto extraido do acervo ou de export XPZ real comparavel
- Fonte valida: molde sanitizado documentado nesta base, quando o anexo embutir XML completo suficiente para o tipo e a familia alvo e estiver marcado como `molde pronto`
- Fonte invalida: markdown meramente descritivo, sem XML completo
- Fonte invalida: reconstrucoes feitas so por resumo textual, tabela, frequencia ou memoria do agente
- Fonte invalida: tentativa de sintetizar `KnowledgeBase`, `Settings` ou bloco top-level com nome da KB em `.xpz` gerado para objetos comuns
- Inferência forte: `04-webpanel-familias-e-templates.md` ja contem moldes sanitizados completos para familias de `WebPanel`
- Inferência forte: `05-transaction-familias-e-templates.md` agora tambem contem moldes sanitizados completos para familias representativas de `Transaction` (`F1`, `F2`, `F5` e `F6`)
- Inferência forte: a serie `01` agora distribui moldes sanitizados completos representativos de `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Index`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em `01e` ate `01h`
- Hipótese: mesmo com anexos representativos, `WorkWithForWeb` continua entre os tipos mais sensiveis a `pattern`, `parent` transacional e contexto gerado; por isso, casos muito distantes do molde documentado ainda podem pedir paralelo bruto mais proximo
- Hipótese: as familias `F3` e `F4` de `Transaction` ainda ficam mais seguras com molde bruto comparavel adicional, por terem densidade estrutural maior e ainda nao terem anexo completo proprio
- Inferência forte: para o envelope externo do XPZ observado, a especificacao desta propria base ja e suficiente para evitar inventar `Objects.xml` isolado ou hierarquia externa sem prova local
