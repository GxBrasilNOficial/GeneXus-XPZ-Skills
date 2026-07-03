---
name: xpz-index-triage
description: Usa índice derivado da KB para triagem inicial e orienta o chamador a abrir apenas os XMLs oficiais realmente necessários
---

# xpz-index-triage

Usa um índice derivado da KB GeneXus como etapa inicial de descoberta e triagem. Ajuda o agente chamador a encontrar rapidamente por onde começar, reduzindo abertura ampla do acervo XML oficial e preservando `ObjetosDaKbEmXml` como fonte normativa final.

---

## GUIDELINE

Usar o índice derivado da KB como trilha inicial de triagem antes de expandir a leitura do acervo XML oficial. A skill executa a consulta inicial no índice e orienta o chamador a reduzir a abertura de XML ao conjunto mínimo necessário.

O índice é artefato derivado. Ele não substitui os XMLs oficiais e não autoriza conclusão funcional automática.

Em fluxos acionados por botão, link, action ou event, nome plausível de WebPanel ou popup não é evidência suficiente de que ele é o alvo executado pelo fluxo real. O caller deve ser resolvido antes de qualquer leitura ou edição do objeto-alvo.

Antes de usar o índice como base de triagem, executar obrigatoriamente o gate via `Test-*KbIndexGate.ps1`. O gate verifica em sequência: estrutura da pasta paralela via `Test-*KbStructure.ps1`, existência da pasta `KbIntelligence`, do SQLite, semântica de inventário e frescor via `index-metadata`, existência de `kb-source-metadata.md` e `last_xpz_materialization_run_at`, compara timestamps e valida `extractor_signature_version`/`extractor_signature_hash` na metadata do SQLite contra o motor compartilhado (`scripts/GeneXusKbIntelligenceExtractorContract.ps1` + `scripts/Build-KbIntelligenceIndex.py` no repositório ativo). Não fazer verificação manual de frescor, semântica, assinatura do extrator ou estrutura — todas as verificações são encapsuladas no gate script, que é o único ponto de execução autorizado. Se `Test-*KbIndexGate.ps1` não existir em `scripts/`, tratar isso como bloqueio estrutural equivalente a `BLOCK:` do próprio script — encerrar a pergunta de negócio e oferecer atualização via `xpz-kb-parallel-setup`; não compensar com verificação manual, consulta direta ao índice ou qualquer outra alternativa.

- se o gate retornar `GATE_OK`, o índice está apto para triagem inicial
- se o gate retornar `BLOCK: <motivo>`, tratar o índice como defasado/incompatível

O gate é obrigatório inclusive para perguntas simples de existência — um índice defasado pode retornar falso negativo ou falso positivo mesmo para `search-objects`; a simplicidade da pergunta não elimina o risco de resposta errada.

Índice defasado, `last_xpz_materialization_run_at` ausente ou wrapper local sem suporte a `index-metadata` é gate de bloqueio para pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML de objeto e geração de objetos de importação. Esse estado deve ser tratado como exceção operacional, normalmente sinal de pasta paralela ainda sem wrappers XPZ atualizados ou de falha fortuita. O agente deve oferecer ao usuário atualização via `xpz-kb-parallel-setup` antes de seguir. Nesse estado, o agente pode executar apenas diagnóstico mínimo para explicar a incompatibilidade, restrito a documentação local, estrutura, wrappers e metadados operacionais; não deve compensar com leitura manual de JSON, SQLite direto, `kb-source-metadata.md` isolado, datas de arquivo, `updated`, `generated_at`, `source_xpz`, XML oficial de objeto, caminho pontual deduzido em `ObjetosDaKbEmXml` ou varredura em `ObjetosDaKbEmXml`.

Se a pasta paralela da KB ainda não estiver montada, validada ou mapeada, parar e usar `xpz-kb-parallel-setup` antes de depender de caminhos locais.

O gate deve ser executado como checagens atômicas e sequenciais. A primeira etapa atômica é a verificação de estrutura via `Test-*KbStructure.ps1`. Cada etapa só pode consultar o artefato daquela etapa depois que a etapa anterior tiver sido aprovada. Em particular, não testar, listar ou abrir caminhos filhos como `KbIntelligence\kb-intelligence.sqlite` antes de confirmar que a estrutura está `STRUCTURE_OK`. Se a estrutura falhar, relatar apenas esse primeiro bloqueio e encerrar a pergunta de negócio. Se o wrapper local documentado estiver ausente, não procurar variantes, backups ou nomes parecidos; relatar apenas o wrapper esperado ausente e oferecer atualização via `xpz-kb-parallel-setup`.

Depois de `index-metadata` passar, validar `kb-source-metadata.md` em duas etapas atômicas: primeiro confirmar que o arquivo existe; somente depois procurar o campo literal `last_xpz_materialization_run_at`. Se o arquivo estiver ausente, bloquear por arquivo ausente sem procurar campo. Se o campo estiver ausente, bloquear por campo ausente sem inferir por outros metadados. Não intercalar `Get-Date` entre etapas internas do gate; timestamp operacional basta antes de updates/respostas ao usuário.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- pergunta sobre impacto técnico direto de um objeto
- pergunta sobre quem usa ou o que um objeto usa
- pergunta sobre evidência de relação entre objetos GeneXus
- pergunta funcional curta que precise de triagem inicial antes da leitura do XML oficial
- necessidade de decidir quais XMLs oficiais devem ser abertos primeiro
- necessidade de reduzir varredura ampla do acervo `ObjetosDaKbEmXml`
- identificar qual objeto é efetivamente aberto ou executado por uma ação, botão, link ou evento em tela GeneXus ("qual popup esse botão abre?", "qual objeto é chamado pelo evento X?", "o que abre ao clicar em Y?")

Do NOT use this skill for:
- leitura estrutural de XML bruto isolado sem depender do índice
- geração, clonagem ou empacotamento de XML/XPZ
- sincronização de `XPZ`
- documentação como objetivo principal
- manutenção, regeneração ou evolução do índice como foco principal
- conclusão funcional completa sem leitura do XML oficial quando a pergunta exigir semântica GeneXus

---

## RESPONSIBILITIES

- Detectar se a KB ativa expõe `KbIntelligence\kb-intelligence.sqlite`
- Ler `README.md` e `AGENTS.md` locais do repositório alvo antes de depender do índice
- Localizar, pela documentação local do repositório, o wrapper de consulta do índice no ambiente ativo
- Verificar `last_index_build_run_at` contra `last_xpz_materialization_run_at` antes da primeira consulta substantiva
- Preferir `index-metadata` no wrapper local quando disponível para ler metadados do SQLite
- Se `index-metadata` existir, mas falhar, retornar vazio, não expuser `last_index_build_run_at` ou não expuser `inventory_validation_status`, tratar como índice sem metadado válido; não prosseguir com triagem substantiva antes de oferecer regeneração/validação
- Se `kb-source-metadata.md` não expuser literalmente `last_xpz_materialization_run_at`, tratar como metadado de materialização incompatível; não inferir frescor por data de arquivo, `updated`, `generated_at`, `source_xpz` ou outros campos
- Se o wrapper local não aceitar `index-metadata`, declarar essa defasagem precisamente como falta de exposição no wrapper local, não como falta do motor compartilhado; abortar a pergunta de negócio e oferecer atualização via `xpz-kb-parallel-setup`
- Traduzir a pergunta do usuário para a consulta mais útil no índice
- Escolher entre consultas como:
  - `object-info`
  - `attribute-info`
  - `search-objects`
  - `list-by-type`
  - `transaction-attributes`
  - `transaction-writable-attributes`
  - `who-uses`
  - `what-uses`
  - `show-evidence`
  - `impact-basic`
  - `functional-trace-basic`
  - `css-classes`
  - `css-class-usage`
- Quando a pergunta ou solicitação de edição vier ancorada em fluxo de navegação ("nesta tela clico em X", "o popup aberto por Y", "o objeto chamado pelo evento Z"), executar sub-fluxo obrigatório de resolução de alvo antes de liberar leitura ou edição:
  1. Identificar o objeto caller citado pelo usuário
  2. Localizar o evento ou ação real no XML do caller (`Event`, `Action`, `Link`, `Window.Object`, `Create(...)`, `formatLink`, `context.NewWindow`, URL gerada)
  3. Resolver o objeto efetivamente aberto ou executado
  4. Quando houver mais de um alvo plausível, declarar a ambiguidade explicitamente e confirmar o alvo com o usuário antes de prosseguir
  5. Produzir o bloco de handoff auditável de resolução de alvo (ver COMMUNICATION) antes de liberar leitura ou edição

### Localização com índice e desambiguação de candidatos

- Para localizar objeto, dependência ou ponto de leitura inicial, preferir consultas do índice (`search-objects`, `object-info`, `who-uses`, `what-uses`, etc.) depois de `GATE_OK`; o índice existe para reduzir abertura ampla de XML e erro de caminho.
- Para análise de impacto, callers, callees e referências entre objetos, não usar `rg`/`grep` bruto como base de conclusão quando o índice estiver apto. O fluxo obrigatório é `impact-basic`/`who-uses`/`what-uses` e, para uma relação específica, `show-evidence` ou leitura do XML oficial em bloco correto.
- Antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catálogo efetivo (`scripts/gx-object-type-catalog.json` + override local) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, o query devolve exit `11` e `blocked=true` — **não** tratar como “zero dependências”; usar `object-info`, `search-objects`, `list-by-type` ou XML pontual (lista no JSON).
- Tipos com `queryableByKbIntelligence=true` e grafo assimétrico (`API`, `DataSelector`, `WorkWithForWeb`, `ExternalObject`): ver `scripts/README-kb-intelligence.md` — `impact-basic` com só saídas ou entradas esparsas pode ser resposta válida.
- Em `ExternalObject`, distinguir referência declarativa por `ATTCUSTOMTYPE` de uso efetivo por chamada de método em variável `exo:<ExternalObject>`; quando a pergunta for "quem toca/usa este objeto externo", preferir `who-uses` e conferir `extractor_rule`/`show-evidence` antes de concluir o tipo de uso.
- O índice não substitui leitura de XML quando a pergunta depender de conteúdo não representado no índice (trecho literal de `Source`/`Rules`, mensagem de erro exata, semântica GeneXus no XML). Nesses casos, após a consulta mínima ao índice quando ela ainda ajudar, pode-se usar busca textual pontual no acervo oficial — somente com `GATE_OK` e sem varredura ampla desnecessária.
- Para busca textual pontual em XML de `WebPanel`, evitar `rg`/`grep` bruto quando a pergunta for sobre evento, chamada, validação, filtro ou fluxo; primeiro usar `scripts\Search-GeneXusXmlSourceBlock.ps1 -Block events` ou extração estruturada equivalente para não confundir match em `GxMultiForm` de layout com code-behind.
- Quando o agente já souber nome e caminho nominal do XML oficial e a tarefa for apenas ler ou editar esse arquivo, não é obrigatório repetir `search-objects`; ainda assim, se a busca textual por trecho literal retornar mais de um arquivo, aplicar desambiguação antes de abrir um único XML.
- Quando o índice ou a busca textual pontual retornar **mais de um** candidato plausível, listar **todos**, cruzar com pistas do usuário (action, botão, evento, Procedure/WebPanel citados, tokens no nome do arquivo, fluxo declarado), declarar **recomendação explícita com motivo** e **confirmar com o usuário** antes de abrir XML ou responder como se o alvo estivesse fechado.

- Executar a triagem inicial apropriada
- Não executar consulta substantiva do índice antes de `GATE_OK`; `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes`, `transaction-writable-attributes`, `who-uses`, `what-uses`, `show-evidence`, `impact-basic`, `functional-trace-basic`, `css-classes` e `css-class-usage` só podem rodar depois que o gate terminar liberado
- Depois de `GATE_OK`, ir direto para a consulta substantiva mínima necessária; não abrir `scripts/README-kb-intelligence.md`, não listar `scripts` e não reinspecionar o wrapper local se a pergunta já puder ser atendida com consulta simples como `search-objects`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes`
- Em pergunta simples de existência/localização nominal, listagem por tipo ou consulta pontual de atributo (`attribute-info`) ou gravabilidade materializada (`transaction-attributes`, `transaction-writable-attributes`), considerar a própria skill suficiente para escolher a consulta mínima; usar os parâmetros documentados em **QUERY PARAMETER REFERENCE**; não abrir o wrapper só para "confirmar assinatura" antes de chamar `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes`
- Devolver leitura técnica curta, auditável e limitada ao recorte do índice
- Orientar o chamador a reduzir a abertura de XML ao conjunto mínimo necessário
- Indicar quais XMLs oficiais devem ser lidos depois, quando a triagem não bastar sozinha
- Preservar a distinção entre índice derivado e fonte normativa em `ObjetosDaKbEmXml`
- Quando a pergunta for funcional curta, manter a separação entre:
  - `Evidência direta`
  - `Leitura adicional do XML`
  - `Inferência forte`
  - `Hipótese`
- Explicitar o limite metodológico quando a triagem não cobrir a semântica necessária
- Reconhecer quando a KB local ainda não expõe wrapper compatível com a capacidade desejada e tratar isso como adaptação local pendente, não como falha metodológica do índice
- Quando a busca no índice for motivada por warning de GeneXus sobre provider ausente, item desconhecido, designer ou metadado de extensão: classificar o item citado antes de interpretar o resultado — (a) objeto GeneXus exportável comum; (b) metadado interno ou part; (c) designer/provider de extensão; (d) tipo desconhecido. Resultado negativo do índice para item tipo (b), (c) ou (d) deve ser reportado como conclusão limitada: "não encontrado no índice derivado nem no XPZ/XML" — nunca "não existe na KB". Consultar regra conceitual em `02-regras-operacionais-e-runtime.md` seção "Limite do XPZ/XML frente a providers e extensões GeneXus".

---

## COMMUNICATION

- Responder no mesmo idioma do usuário
- Obter horário local imediatamente antes de cada update ou resposta ao usuário; não reutilizar timestamp anterior nem inferir horário pela sequência da conversa
- Começar pelo resultado da triagem, não pelo histórico do índice
- Quando o gate de frescor/compatibilidade tiver sido relevante no fluxo, declarar brevemente a decisão do gate na resposta ou no handoff:
  - se liberado, informar que `last_index_build_run_at >= last_xpz_materialization_run_at` e `inventory_validation_status=OK`
  - se bloqueado, informar qual campo/capacidade faltou ou qual timestamp ficou defasado
- Quando o gate bloquear depois de `index-metadata`, não dizer que "não devo consultar o índice"; dizer que a consulta de metadados do gate foi feita, mas a triagem substantiva pelo índice está bloqueada
- Dizer explicitamente quando a resposta ainda depende de leitura do XML oficial
- Quando o gate estiver bloqueado, dizer explicitamente que não será aberto XML oficial de objeto nem feita varredura em `ObjetosDaKbEmXml` para responder a pergunta de negócio
- Quando o comando do gate for negado, cancelado ou interrompido pelo usuário, dizer explicitamente que (a) nenhuma busca alternativa será feita até o gate ser liberado e (b) o caminho operacional é revisar a regra de permissão em `settings.json` e/ou rodar `xpz-kb-parallel-setup`; não prometer "tentar de outro jeito"
- Abrir XML oficial de objeto somente depois de o gate ter sido liberado; com gate bloqueado, não usar leitura pontual de XML para responder pergunta de negócio
- Quando o índice devolver caminho nominal do XML oficial, manter esse caminho completo e consistente na resposta; não encurtar depois para apenas o nome do arquivo
- Separar o que veio do índice do que é inferência do agente
- Em pergunta funcional, manter a classificação:
  - `Evidência direta`
  - `Leitura adicional do XML`
  - `Inferência forte`
  - `Hipótese`
- Quando o sub-fluxo de resolução de alvo tiver sido executado, produzir bloco de handoff auditável antes de liberar leitura ou edição:
  ```
  Caller confirmado: <nome do objeto caller>
  Evento/Ação: <nome do evento ou ação no caller>
  Alvo resolvido: <nome do objeto efetivamente aberto/executado>
  Evidência: <trecho do XML do caller que aponta para o alvo>
  ```
- Não prometer impacto runtime completo
- Não prometer conclusão funcional fechada quando o índice apenas apontar trilha de leitura

---

## STRUCTURE

Reference files and when to load them:

| Reference | Load when |
|-----------|-----------|
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Depois do gate estrutural inicial, quando for necessário interpretar frescor, metadados, limite operacional ou relação entre artefato derivado e fonte normativa |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Depois do gate estrutural inicial, quando for necessário orientar uso do KB Intelligence, escalada para XML oficial ou decisão operacional |
| [kb-intelligence-guia-metodologico-agente.md](../kb-intelligence-guia-metodologico-agente.md) | Quando a resposta precisar de roteiro de investigação funcional, modelo de resposta (evidência / leitura adicional / inferência / hipótese), `functional-trace-basic` como trilha narrativa, ou terminologia `via edição web` / `via BC` — não para escolher consulta do índice (`search-objects`, `attribute-info`, etc.); isso fica na skill e em **QUERY PARAMETER REFERENCE** |
| [scripts/README-kb-intelligence.md](../scripts/README-kb-intelligence.md) | Depois do gate estrutural inicial, quando a **QUERY PARAMETER REFERENCE** da skill não bastar: cobertura ambígua do índice, comando não listado na skill, ou distinção entre validadores (`Test-KbIntelligenceQueries` vs gates de geração em `xpz-builder`) |

Para economizar contexto, não carregue referências longas da tabela acima antes do gate estrutural inicial (`KbIntelligence`, SQLite e wrapper local). Se o gate bloquear em uma dessas três checagens, responda com a primeira falha e ofereça `xpz-kb-parallel-setup` sem abrir referências adicionais.

Mesmo com o gate liberado, continue econômico: para pergunta simples de existência/localização nominal de objeto, use primeiro `search-objects` ou `object-info`; para sinais leves de um atributo use `attribute-info`; para gravabilidade transacional materializada use `transaction-attributes` ou `transaction-writable-attributes`; só abra `scripts/README-kb-intelligence.md` ou releia o wrapper local quando a cobertura da consulta estiver realmente ambígua.

---

## QUERY PARAMETER REFERENCE (consultas mínimas)

Para as consultas mais frequentes, o wrapper `Query-*KbIntelligence.ps1` aceita os seguintes parâmetros (além de `-IndexPath` e `-Format`, comuns a todas as consultas):

- **search-objects**: `-ObjectName` (obrigatório, aceita substring parcial com wildcard `*`, ex: `"*planilha*"`), `-ObjectType` (opcional, filtra por tipo), `-Generated`/`-Authored` (opcional, mutuamente exclusivos: só objetos gerados por Pattern x só autorais), `-Limit` (opcional); a saída de cada objeto inclui `is_generated_object`/`pattern_object_id`/`instance_key`
- **list-by-type**: `-ObjectType` (obrigatório, tipo exato, ex: `Procedure`), `-Generated`/`-Authored` (opcional, mutuamente exclusivos: gerados por Pattern x autorais), `-Limit` (opcional); lista todos os objetos de um tipo sem necessidade de nome — use quando o usuário perguntar "quais são os X da KB"
- **object-info**: `-ObjectType` (obrigatório, tipo exato, ex: `Procedure`), `-ObjectName` (obrigatório, nome exato do objeto); a saída inclui `is_generated_object` (0/1), `pattern_object_id` e `instance_key` — sinal determinístico gerado-por-Pattern x autoral, preferível à heurística de nome (`ww*`/`*WC`/`*General`/`*Selection`) para auditoria autoral x gerado
- **attribute-info**: `-ObjectName` (obrigatório, nome exato do atributo); retorna sinais leves como `Formula` e `idBasedOn` sem varrer o acervo inteiro
- **who-uses** / **what-uses** em `Procedure` (e alvos resolvidos em `Formula` de `Attribute`): o índice inclui dependências via `Property Formula` quando o padrão de chamada coincide com `Source` efetivo; para semântica da expressão ou funções não indexadas, abrir o XML do atributo
- **transaction-writable-attributes**: classificação completa materializada no índice (paridade com `Test-GeneXusTransactionWritability.ps1`, que delega ao núcleo Python); use para triagem e impacto de `New` em atributos; `unclassified-*` exige XML; blocos `New` em `Procedure` ainda passam por `Test-GeneXusNewWritableTargets.ps1`
- **transaction-attributes** / **transaction-writable-attributes**: `-ObjectName` (obrigatório, nome exato da Transaction); lista atributos por Level com classificação materializada; para empacote com atribuições ou blocos `New`, use os gates completos da skill `xpz-builder`
- **css-classes**: catálogo de classes CSS (tabela `css_class`, estilo-inventário; não exige `queryableByKbIntelligence`). `-Model` (opcional: `legacy-theme` | `design-system`), `-Origin` (opcional: `kb-authored` | `packaged-module`), `-IncludeImported` (opcional, inclui libs importadas na visão sem lookup), `-ObjectName` (opcional, lookup nominal **case-sensitive** de uma classe; nunca filtra origem, para não dar falso "não existe" de classe importada), `-Limit`. `legacy-theme` sai marcado `deprecated=true` (candidato a migração para DesignSystem)
- **css-class-usage**: onde uma classe é usada (relações `uses_css_class`/`uses_css_class_dynamic`). `-ObjectName` (opcional: classe específica; sem ele devolve overview com totais e a lista de **usadas mas não catalogadas**), `-Limit`. Declara cobertura honesta: `dynamic_uses_total` = atribuições `.Class=` dinâmicas (variável/`Format()`) não atribuíveis a uma classe; `found_in_catalog=false` = classe usada mas não catalogada, **não** inexistente. Para operação destrutiva (renomear/remover classe), conferir por busca literal no XML antes de agir

A documentação completa de todas as consultas e seus parâmetros está em [scripts/README-kb-intelligence.md](../scripts/README-kb-intelligence.md).

---

## GATE MÍNIMO RECOMENDADO

Chamar `Test-*KbIndexGate.ps1` pelo nome provisionado na pasta `scripts` da pasta paralela da KB. O script encapsula toda a lógica do gate: verifica sequencialmente pasta `KbIntelligence`, `kb-intelligence.sqlite`, wrapper local de consulta, metadado de build via `-Query index-metadata`, `kb-source-metadata.md` e comparação de timestamps. Retorna `GATE_OK` em stdout quando o índice está apto, ou lança exceção com `BLOCK: <motivo>` quando não está.

Substitua `<caminho-absoluto-do-script>` pelo caminho absoluto literal do script lido da documentação local da pasta paralela (ex: `C:\Dev\Prod\Gx_FabricaBrasil\scripts\Test-FabricaBrasilKbIndexGate.ps1`). Não usar variável nem `Join-Path`: o caminho literal é obrigatório para que o sistema de permissões consiga validar estaticamente o comando e dispensar prompts manuais. Não acrescentar linhas, saídas auxiliares, parsing ou comandos ao bloco; toda a lógica de gate está encapsulada no script.

Executar este bloco usando o tool `PowerShell` (não `Bash`). A sintaxe `& "..."` é PowerShell pura; o Bash não consegue parseá-la e o sistema de permissões acaba sem padrão estável para registrar (sem opção de "Sempre permitir"). Além disso, a regra de permissão usa prefixo `PowerShell(...)` e não casa quando o comando entra via tool `Bash`.

O comentário `#gate` no fim do bloco é proposital: é apenas comentário PowerShell (zero efeito em execução), mas garante que o comando termine com conteúdo após o caminho. Isso permite usar o padrão de permissão `PowerShell(& "<caminho-absoluto-do-script>" *)` (espaço + curinga), que é o mesmo padrão dos demais scripts já registrados no `settings.json`. Foi observado em Claude Desktop Windows que match exato sem curinga (`PowerShell(& "<caminho>")`) não dispensa o prompt mesmo quando registrado, comportamento aparentemente bugado de descasamento entre matcher e registrador; o `#gate` evita esse caminho problemático.

```powershell
& "<caminho-absoluto-do-script>" #gate
```

Se o script retornar `GATE_OK`, encerrar o comando do gate; qualquer próxima ação deve ser decidida e executada em comando separado, conforme a consulta substantiva necessária.

Se qualquer `BLOCK:` ocorrer, encerrar a pergunta de negócio e oferecer `xpz-kb-parallel-setup`. Não executar etapas posteriores do gate em comandos separados para "completar diagnóstico".

### ERROS COMUNS DE CHAMADA

- executar o bloco do gate em `Bash` em vez de `PowerShell`
- trocar o caminho absoluto literal do script por variável, `Join-Path` ou montagem indireta
- acrescentar parsing, `Write-Host`, `Get-Date`, saídas auxiliares ou comandos extras ao mesmo bloco do gate
- tratar recusa de permissão, cancelamento ou interrupção do gate como licença para fallback manual
- depois de `GATE_OK`, reinspecionar o wrapper local ou abrir `scripts/README-kb-intelligence.md` sem necessidade quando a pergunta já cabe em `search-objects`, `list-by-type` ou `object-info`
- em pergunta simples de existência/localização nominal, abrir o wrapper apenas para confirmar assinatura antes de usar os parâmetros já documentados em **QUERY PARAMETER REFERENCE**

---

## WORKFLOW

1. Identificar o repositório ativo e reler `README.md` e `AGENTS.md` locais; ao reler o `AGENTS.md`, verificar se contém a seção `## Triagem Por Indice` — se ausente em pasta que adota `KbIntelligence`, tratar como estrutura desatualizada e rotear para `xpz-kb-parallel-setup` antes de qualquer triagem
2. Se a pasta paralela da KB ainda não estiver montada, validada ou mapeada para este repositório -> **ABORT** e usar `xpz-kb-parallel-setup`
3. A PRIMEIRA ação substantiva desta skill em qualquer sessão deve ser executar o gate. Nenhuma consulta ao índice, leitura de XML, varredura de `ObjetosDaKbEmXml` ou comando `Query-*KbIntelligence.ps1` pode ocorrer antes de `Test-*KbIndexGate.ps1` retornar `GATE_OK`. Isso vale inclusive para perguntas simples de existência/localização nominal, listagem por tipo ou consulta pontual de atributo/gravabilidade — `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes` e `transaction-writable-attributes` estão proibidos antes do gate.
4. Executar o gate em ordem sequencial e parar no primeiro bloqueio; não investigar camadas internas até a camada externa estar válida
5. Verificar se existe `Test-*KbIndexGate.ps1` em `scripts\`; se ausente, bloquear como defasagem da pasta paralela e oferecer atualização via `xpz-kb-parallel-setup`
6. Executar `Test-*KbIndexGate.ps1`; o script verifica sequencialmente: estrutura da pasta paralela via `Test-*KbStructure.ps1`, pasta `KbIntelligence`, `kb-intelligence.sqlite`, wrapper local de consulta com `-Query index-metadata`, `inventory_validation_status`, `kb-source-metadata.md` e comparação de timestamps; qualquer `BLOCK:` encerra a pergunta de negócio
   - se a execução do comando do gate for negada, cancelada ou interrompida pelo usuário, tratar como gate não liberado: encerrar a pergunta de negócio, relatar a situação ao usuário, oferecer revisão da regra de permissão em `settings.json` e/ou `xpz-kb-parallel-setup`; NUNCA contornar o gate com varredura, leitura pontual ou consulta indireta
7. Se qualquer etapa do gate falhar, bloquear pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML oficial de objeto e geração de objetos para importação, relatar a primeira exceção operacional encontrada e oferecer atualização via `xpz-kb-parallel-setup` antes de seguir
8. Com gate bloqueado, encerrar a pergunta de negócio antes de resolver o objeto pedido para caminho de XML; não montar, testar existência, listar ou abrir caminhos deduzidos como `ObjetosDaKbEmXml\<Tipo>\<Nome>.xml`
9. Classificar a pergunta do usuário em uma destas naturezas:
   - localização de objeto
   - impacto técnico
   - dependentes e dependências
   - evidência de relação específica
   - triagem funcional curta
   - resolução de alvo de navegação (pergunta ou solicitação de edição ancorada em ação, botão, link ou evento: "qual popup esse botão abre?", "o objeto chamado pelo evento X", "nesta tela clico em Y")
9a. Se a natureza for resolução de alvo de navegação, executar o sub-fluxo obrigatório de resolução de alvo (ver RESPONSIBILITIES) antes de prosseguir: identificar caller, localizar evento/ação no XML do caller, resolver objeto efetivamente aberto, confirmar alvo com o usuário se houver ambiguidade e produzir o bloco de handoff auditável; só então continuar para o step 10
10. Escolher a consulta do índice mais adequada
    - para afirmação "X chama/usa/referencia Y", usar `show-evidence` quando a relação específica precisar ser auditada; `rg`/`grep` textual pode servir apenas como sondagem pontual depois de `GATE_OK`, nunca como evidência final de chamada entre objetos
10a. Se houver mais de um candidato (índice ou busca textual pontual com `GATE_OK`), executar desambiguação: listar candidatos, recomendar um com motivo, confirmar com o usuário; não abrir um único XML nem fechar resposta enquanto a ambiguidade persistir
11. Só depois de `GATE_OK`, executar a consulta substantiva mínima necessária sem leitura lateral de `scripts`, `scripts/README-kb-intelligence.md` ou reinspeção do wrapper quando a pergunta já couber em `search-objects`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes`
    - para pergunta simples de existência/localização nominal, listagem por tipo ou consulta pontual de atributo (`attribute-info`) ou gravabilidade materializada (`transaction-attributes`, `transaction-writable-attributes`), usar diretamente `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes` conforme a pergunta, usando os parâmetros documentados em **QUERY PARAMETER REFERENCE**; não abrir o wrapper para confirmar assinatura
12. Resumir o resultado da triagem de forma curta e auditável
13. Decidir se a triagem já basta para responder no nível técnico pedido
14. Se não bastar, indicar ao chamador apenas o conjunto mínimo de XMLs oficiais a abrir
15. Se a pergunta for funcional:
    - usar o índice apenas para orientar a ordem de leitura
    - manter explicitamente `Evidência direta`, `Leitura adicional do XML`, `Inferência forte` e `Hipótese`
16. Se a semântica GeneXus exigida estiver fora do recorte atual do índice, escalar para XML oficial e declarar o limite do índice
17. Se o wrapper local não expuser uma capacidade já disponível no motor compartilhado:
    - relatar a defasagem
    - tratar o caso como bloqueio de compatibilidade da pasta paralela para aquela triagem
    - oferecer atualização via `xpz-kb-parallel-setup`
    - aguardar aprovação explícita antes de alterar wrappers locais

---

## CONSTRAINTS

- NUNCA tratar o índice como fonte normativa final
- NUNCA substituir `ObjetosDaKbEmXml`
- NUNCA concluir funcionalidade sozinho apenas pelo índice
- NUNCA abrir XML em massa por padrão; a triagem pelo índice existe para reduzir leitura, abrir em massa anula o propósito da skill
- NUNCA consultar o acervo oficial de objetos para responder pergunta de negócio, nem por varredura ampla nem por caminho pontual deduzido, quando o gate de compatibilidade/frescor estiver bloqueado; gate bloqueado significa que o índice não está confiável, e qualquer resposta baseada em leitura direta de XMLs pode estar desatualizada ou inconsistente
- NUNCA tratar recusa de permissão, cancelamento ou interrupção do comando `Test-*KbIndexGate.ps1` como autorização para fallback; trata-se de gate não liberado e exige a mesma postura de bloqueio que `BLOCK:` da própria saída do script
- NUNCA usar `Grep`, `Select-String`, `Get-ChildItem`, `find`, varredura de pasta ou leitura pontual em `ObjetosDaKbEmXml` para responder pergunta de negócio quando o gate não retornou `GATE_OK` por qualquer motivo, incluindo recusa de permissão, comando cancelado, interrupção ou timeout
- NUNCA fazer pesquisa ampla no acervo nem gerar objetos para importação quando o índice estiver defasado em relação à última materialização XPZ/XML
- NUNCA gastar diagnóstico em camadas internas do gate quando uma camada externa já falhou; parar no primeiro bloqueio e oferecer atualização
- NUNCA testar, listar ou abrir caminho filho de uma camada do gate antes de confirmar a camada pai; por exemplo, não testar `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- NUNCA listar `scripts` ou procurar wrappers alternativos quando o wrapper local documentado estiver ausente; isso é defasagem da pasta paralela, não descoberta de fallback
- NUNCA continuar a triagem substantiva quando `index-metadata` falhar, retornar vazio ou não trouxer timestamp de build do índice
- NUNCA executar `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes`, `transaction-writable-attributes`, `who-uses`, `what-uses`, `show-evidence`, `impact-basic`, `functional-trace-basic`, `css-classes` ou `css-class-usage` antes de `GATE_OK`
- NUNCA procurar `last_xpz_materialization_run_at` antes de confirmar que `kb-source-metadata.md` existe como arquivo
- NUNCA intercalar `Get-Date` entre etapas internas do gate; usar horário local apenas para updates/respostas ao usuário ou registro operacional necessário
- NUNCA descrever bloqueio pós-`index-metadata` como proibição total de consultar o índice; `index-metadata` é consulta de gate, o bloqueio impede triagem substantiva
- NUNCA acrescentar parsing, saídas auxiliares, impressão de timestamps ou comandos ao bloco de chamada do gate; toda lógica está encapsulada em `Test-*KbIndexGate.ps1`
- NUNCA, depois de `GATE_OK`, abrir `scripts/README-kb-intelligence.md`, listar `scripts` ou reinspecionar o wrapper local quando a pergunta puder ser resolvida diretamente por `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes`
- NUNCA, em pergunta simples de existência/localização nominal, listagem por tipo ou consulta pontual de atributo/gravabilidade no índice, abrir o wrapper local apenas para confirmar assinatura antes de chamar `search-objects`, `list-by-type`, `object-info`, `attribute-info`, `transaction-attributes` ou `transaction-writable-attributes`; os parâmetros estão documentados em **QUERY PARAMETER REFERENCE**
- NUNCA encurtar ou reescrever de forma inconsistente o caminho nominal do XML oficial retornado pelo índice
- NUNCA reutilizar timestamp anterior em update ou resposta ao usuário; obter horário local imediatamente antes de cada mensagem
- NUNCA acessar `kb-intelligence.sqlite` diretamente por qualquer linguagem ou ferramenta — Python, sqlite3 CLI, PowerShell inline, Bash, ou qualquer outro meio — sem passar pelo gate e pelo wrapper local; acesso direto ao SQLite é equivalente a bypass do gate independente do resultado obtido
- NUNCA compensar falha de `index-metadata` ou ausência de `last_xpz_materialization_run_at` lendo manualmente JSON de validação, SQLite direto, `kb-source-metadata.md` isolado, datas de arquivo, `updated`, `generated_at`, `source_xpz` ou XML oficial para responder a pergunta de negócio
- NUNCA abrir XML oficial de objeto para responder pergunta de negócio quando o gate de compatibilidade/frescor estiver bloqueado
- NUNCA normalizar trabalho sem índice como alternativa econômica quando o repositório adota `KbIntelligence`; índice ausente ou defasado exige oferta de atualização
- NUNCA editar ou liberar edição de objeto-alvo de fluxo ancorado em ação ou evento ("nesta tela clico em X", "o popup aberto por Y", "o objeto chamado pelo evento Z") com base apenas em similaridade nominal — evidência do caller real é obrigatória antes da primeira edição
- NUNCA, com múltiplos candidatos do índice ou da busca textual pontual no acervo oficial, abrir silenciosamente o primeiro resultado nem responder como certeza sem listar os demais, recomendar com motivo e confirmar com o usuário quando a escolha não for inequívoca pelo contexto já fornecido
- NUNCA substituir `nexa`
- NUNCA substituir `xpz-reader`
- NUNCA executar `Query-*KbIntelligence.ps1` ou chamar qualquer consulta ao índice sem ter verificado primeiro que `Test-*KbIndexGate.ps1` existe em `scripts/` e executado o gate com retorno `GATE_OK`; ausência do gate script é bloqueio estrutural, não licença para consultar o índice diretamente
- NUNCA tratar declaração de estado em `AGENTS.md` local (ex: `materializado_e_indice_validado`) como autorização para pular a verificação estrutural do gate quando `Test-*KbIndexGate.ps1` estiver ausente ou quando a skill detectar ausência objetiva de scripts. O `AGENTS.md` pode estar desatualizado; a inspeção objetiva da pasta paralela prevalece sobre declaração de estado
- NUNCA assumir que toda capacidade nova do motor compartilhado já está exposta no wrapper local da KB
- NUNCA tratar ausência de wrapper local compatível como defeito da base metodológica
- NUNCA escolher executor de validação do KB Intelligence apenas pelo número da fase; o formato do caso continua definindo o executor
- Se o índice local não existir, relatar isso explicitamente, bloquear a pergunta de negócio e oferecer atualização via `xpz-kb-parallel-setup`
- Se a pergunta estiver fora do recorte coberto pelo índice e o gate já tiver sido liberado, declarar isso antes de prosseguir para XML oficial
