---
name: xpz-index-triage
description: Usa indice derivado da KB para triagem inicial e orienta o chamador a abrir apenas os XMLs oficiais realmente necessarios
---

# xpz-index-triage

Usa um indice derivado da KB GeneXus como etapa inicial de descoberta e triagem. Ajuda o agente chamador a encontrar rapidamente por onde comecar, reduzindo abertura ampla do acervo XML oficial e preservando `ObjetosDaKbEmXml` como fonte normativa final.

---

## GUIDELINE

Usar o indice derivado da KB como trilha inicial de triagem antes de expandir a leitura do acervo XML oficial. A skill executa a consulta inicial no indice e orienta o chamador a reduzir a abertura de XML ao conjunto minimo necessario.

O indice e artefato derivado. Ele nao substitui os XMLs oficiais e nao autoriza conclusao funcional automatica.

Antes de usar o indice como base de triagem, executar obrigatoriamente o gate via `Test-*KbGate.ps1`. O gate verifica em sequencia: estrutura da pasta paralela via `Test-*KbStructure.ps1`, existencia da pasta `KbIntelligence`, do SQLite, frescor via `index-metadata`, existencia de `kb-source-metadata.md` e `last_xpz_materialization_run_at`, e compara timestamps. Nao fazer verificacao manual de frescor ou estrutura — ambas as verificacoes sao encapsuladas no gate script, que e o unico ponto de execucao autorizado.

- se o gate retornar `GATE_OK`, o indice esta apto para triagem inicial
- se o gate retornar `BLOCK: <motivo>`, tratar o indice como defasado/incompatível

Indice defasado, `last_xpz_materialization_run_at` ausente ou wrapper local sem suporte a `index-metadata` e gate de bloqueio para pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML de objeto e geracao de objetos de importacao. Esse estado deve ser tratado como excecao operacional, normalmente sinal de pasta paralela ainda sem wrappers XPZ atualizados ou de falha fortuita. O agente deve oferecer ao usuario atualizacao via `xpz-kb-parallel-setup` antes de seguir. Nesse estado, o agente pode executar apenas diagnostico minimo para explicar a incompatibilidade, restrito a documentacao local, estrutura, wrappers e metadados operacionais; nao deve compensar com leitura manual de JSON, SQLite direto, `kb-source-metadata.md` isolado, datas de arquivo, `updated`, `generated_at`, `source_xpz`, XML oficial de objeto, caminho pontual deduzido em `ObjetosDaKbEmXml` ou varredura em `ObjetosDaKbEmXml`.

Se a pasta paralela da KB ainda nao estiver montada, validada ou mapeada, parar e usar `xpz-kb-parallel-setup` antes de depender de caminhos locais.

O gate deve ser executado como checagens atomicas e sequenciais. A primeira etapa atomica e a verificacao de estrutura via `Test-*KbStructure.ps1`. Cada etapa so pode consultar o artefato daquela etapa depois que a etapa anterior tiver sido aprovada. Em particular, nao testar, listar ou abrir caminhos filhos como `KbIntelligence\kb-intelligence.sqlite` antes de confirmar que a estrutura esta `STRUCTURE_OK`. Se a estrutura falhar, relatar apenas esse primeiro bloqueio e encerrar a pergunta de negocio. Se o wrapper local documentado estiver ausente, nao procurar variantes, backups ou nomes parecidos; relatar apenas o wrapper esperado ausente e oferecer atualizacao via `xpz-kb-parallel-setup`.

Depois de `index-metadata` passar, validar `kb-source-metadata.md` em duas etapas atomicas: primeiro confirmar que o arquivo existe; somente depois procurar o campo literal `last_xpz_materialization_run_at`. Se o arquivo estiver ausente, bloquear por arquivo ausente sem procurar campo. Se o campo estiver ausente, bloquear por campo ausente sem inferir por outros metadados. Nao intercalar `Get-Date` entre etapas internas do gate; timestamp operacional basta antes de updates/respostas ao usuario.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositorio.
- Toda referencia `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e nao do diretorio de trabalho corrente.
- Na pratica, `../` aponta para a base metodologica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- pergunta sobre impacto tecnico direto de um objeto
- pergunta sobre quem usa ou o que um objeto usa
- pergunta sobre evidencia de relacao entre objetos GeneXus
- pergunta funcional curta que precise de triagem inicial antes da leitura do XML oficial
- necessidade de decidir quais XMLs oficiais devem ser abertos primeiro
- necessidade de reduzir varredura ampla do acervo `ObjetosDaKbEmXml`

Do NOT use this skill for:
- leitura estrutural de XML bruto isolado sem depender do indice
- geracao, clonagem ou empacotamento de XML/XPZ
- sincronizacao de `XPZ`
- documentacao como objetivo principal
- manutencao, regeneracao ou evolucao do indice como foco principal
- conclusao funcional completa sem leitura do XML oficial quando a pergunta exigir semantica GeneXus

---

## RESPONSIBILITIES

- Detectar se a KB ativa expoe `KbIntelligence\kb-intelligence.sqlite`
- Ler `README.md` e `AGENTS.md` locais do repositorio alvo antes de depender do indice
- Localizar, pela documentacao local do repositorio, o wrapper de consulta do indice no ambiente ativo
- Verificar `last_index_build_run_at` contra `last_xpz_materialization_run_at` antes da primeira consulta substantiva
- Preferir `index-metadata` no wrapper local quando disponivel para ler metadados do SQLite
- Se `index-metadata` existir, mas falhar, retornar vazio ou nao expuser `last_index_build_run_at`, tratar como indice sem metadado valido; nao prosseguir com triagem substantiva antes de oferecer regeneracao/validacao
- Se `kb-source-metadata.md` nao expuser literalmente `last_xpz_materialization_run_at`, tratar como metadado de materializacao incompatível; nao inferir frescor por data de arquivo, `updated`, `generated_at`, `source_xpz` ou outros campos
- Se o wrapper local nao aceitar `index-metadata`, declarar essa defasagem precisamente como falta de exposicao no wrapper local, nao como falta do motor compartilhado; abortar a pergunta de negocio e oferecer atualizacao via `xpz-kb-parallel-setup`
- Traduzir a pergunta do usuario para a consulta mais util no indice
- Escolher entre consultas como:
  - `object-info`
  - `search-objects`
  - `who-uses`
  - `what-uses`
  - `show-evidence`
  - `impact-basic`
  - `functional-trace-basic`
- Executar a triagem inicial apropriada
- Nao executar consulta substantiva do indice antes de `GATE_OK`; `search-objects`, `object-info`, `who-uses`, `what-uses`, `show-evidence`, `impact-basic` e `functional-trace-basic` so podem rodar depois que o gate terminar liberado
- Depois de `GATE_OK`, ir direto para a consulta substantiva minima necessaria; nao abrir `scripts/README-kb-intelligence.md`, nao listar `scripts` e nao reinspecionar o wrapper local se a pergunta ja puder ser atendida com consulta simples como `search-objects` ou `object-info`
- Em pergunta simples de existencia/localizacao nominal, considerar a propria skill suficiente para escolher a consulta minima; usar os parametros documentados em **QUERY PARAMETER REFERENCE**; nao abrir o wrapper so para "confirmar assinatura" antes de chamar `search-objects` ou `object-info`
- Devolver leitura tecnica curta, auditavel e limitada ao recorte do indice
- Orientar o chamador a reduzir a abertura de XML ao conjunto minimo necessario
- Indicar quais XMLs oficiais devem ser lidos depois, quando a triagem nao bastar sozinha
- Preservar a distincao entre indice derivado e fonte normativa em `ObjetosDaKbEmXml`
- Quando a pergunta for funcional curta, manter a separacao entre:
  - `Evidencia direta`
  - `Leitura adicional do XML`
  - `Inferencia forte`
  - `Hipotese`
- Explicitar o limite metodologico quando a triagem nao cobrir a semantica necessaria
- Reconhecer quando a KB local ainda nao expoe wrapper compativel com a capacidade desejada e tratar isso como adaptacao local pendente, nao como falha metodologica do indice

---

## COMMUNICATION

- Responder no mesmo idioma do usuario
- Obter horario local imediatamente antes de cada update ou resposta ao usuario; nao reutilizar timestamp anterior nem inferir horario pela sequencia da conversa
- Comecar pelo resultado da triagem, nao pelo historico do indice
- Quando o gate de frescor/compatibilidade tiver sido relevante no fluxo, declarar brevemente a decisao do gate na resposta ou no handoff:
  - se liberado, informar que `last_index_build_run_at >= last_xpz_materialization_run_at`
  - se bloqueado, informar qual campo/capacidade faltou ou qual timestamp ficou defasado
- Quando o gate bloquear depois de `index-metadata`, nao dizer que "nao devo consultar o indice"; dizer que a consulta de metadados do gate foi feita, mas a triagem substantiva pelo indice esta bloqueada
- Dizer explicitamente quando a resposta ainda depende de leitura do XML oficial
- Quando o gate estiver bloqueado, dizer explicitamente que nao sera aberto XML oficial de objeto nem feita varredura em `ObjetosDaKbEmXml` para responder a pergunta de negocio
- Quando o comando do gate for negado, cancelado ou interrompido pelo usuario, dizer explicitamente que (a) nenhuma busca alternativa sera feita ate o gate ser liberado e (b) o caminho operacional e revisar a regra de permissao em `settings.json` e/ou rodar `xpz-kb-parallel-setup`; nao prometer "tentar de outro jeito"
- Abrir XML oficial de objeto somente depois de o gate ter sido liberado; com gate bloqueado, nao usar leitura pontual de XML para responder pergunta de negocio
- Quando o indice devolver caminho nominal do XML oficial, manter esse caminho completo e consistente na resposta; nao encurtar depois para apenas o nome do arquivo
- Separar o que veio do indice do que e inferencia do agente
- Em pergunta funcional, manter a classificacao:
  - `Evidencia direta`
  - `Leitura adicional do XML`
  - `Inferencia forte`
  - `Hipotese`
- Nao prometer impacto runtime completo
- Nao prometer conclusao funcional fechada quando o indice apenas apontar trilha de leitura

---

## STRUCTURE

Reference files and when to load them:

Esta tabela prioriza contratos e guias de uso corrente da skill. Nao incluir por padrao contratos historicos de fase ja condensados em referencias operacionais mais diretas, nem registros de verificacao pontual ja absorvidos pelo contrato ativo; esses materiais so devem ser carregados quando houver duvida metodologica especifica que a tabela atual nao cubra.

| Reference | Load when |
|-----------|-----------|
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Depois do gate estrutural inicial, quando for necessario interpretar frescor, metadados, limite operacional ou relacao entre artefato derivado e fonte normativa |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Depois do gate estrutural inicial, quando for necessario orientar uso do KB Intelligence, escalada para XML oficial ou decisao operacional |
| [17-kb-intelligence-fase-6-contrato.md](../17-kb-intelligence-fase-6-contrato.md) | Quando a pergunta envolver resposta funcional curta |
| [18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md](../18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md) | Quando a pergunta for funcional e o agente precisar do roteiro passo a passo de investigacao |
| [19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md](../19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md) | Quando forem necessarios exemplos reais do roteiro funcional, incluindo a terminologia `via edicao web` e `via BC` |
| [21-kb-intelligence-fase-6-checklist-operacional-agente.md](../21-kb-intelligence-fase-6-checklist-operacional-agente.md) | Quando a pergunta envolver roteiro operacional do agente |
| [22-kb-intelligence-fase-6-contrato-functional-trace-basic.md](../22-kb-intelligence-fase-6-contrato-functional-trace-basic.md) | Quando a consulta candidata for `functional-trace-basic` |
| [23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md](../23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md) | Quando a consulta candidata for `functional-trace-basic` e exemplos operacionais forem necessarios |
| [27-kb-intelligence-fase-6-primeira-resposta-funcional.md](../27-kb-intelligence-fase-6-primeira-resposta-funcional.md) | Quando for necessario um modelo canonico de resposta funcional completa |
| [scripts/README-kb-intelligence.md](../scripts/README-kb-intelligence.md) | Depois do gate estrutural inicial, quando a skill precisar escolher consulta, interpretar cobertura, executar comando do indice ou distinguir validadores |

Para economizar contexto, nao carregue referencias longas da tabela acima antes do gate estrutural inicial (`KbIntelligence`, SQLite e wrapper local). Se o gate bloquear em uma dessas tres checagens, responda com a primeira falha e ofereca `xpz-kb-parallel-setup` sem abrir referencias adicionais.

Mesmo com o gate liberado, continue economico: para pergunta simples de existencia/localizacao nominal de objeto, use primeiro `search-objects` ou `object-info` e so abra `scripts/README-kb-intelligence.md` ou releia o wrapper local quando a cobertura da consulta estiver realmente ambigua.

---

## QUERY PARAMETER REFERENCE (consultas minimas)

Para `search-objects` e `object-info` — as consultas mais frequentes em perguntas simples de existencia/localizacao — o wrapper `Query-*KbIntelligence.ps1` aceita os seguintes parametros (alem de `-IndexPath` e `-Format`, comuns a todas as consultas):

- **search-objects**: `-ObjectName` (obrigatorio, aceita substring parcial com wildcard `*`, ex: `"*planilha*"`), `-Limit` (opcional)
- **object-info**: `-ObjectType` (obrigatorio, tipo exato, ex: `Procedure`), `-ObjectName` (obrigatorio, nome exato do objeto)

A documentacao completa de todas as consultas e seus parametros esta em [scripts/README-kb-intelligence.md](../scripts/README-kb-intelligence.md).

---

## GATE MINIMO RECOMENDADO

Chamar `Test-*KbGate.ps1` pelo nome provisionado na pasta `scripts` da pasta paralela da KB. O script encapsula toda a logica do gate: verifica sequencialmente pasta `KbIntelligence`, `kb-intelligence.sqlite`, wrapper local de consulta, metadado de build via `-Query index-metadata`, `kb-source-metadata.md` e comparacao de timestamps. Retorna `GATE_OK` em stdout quando o indice esta apto, ou lanca excecao com `BLOCK: <motivo>` quando nao esta.

Substitua `<caminho-absoluto-do-script>` pelo caminho absoluto literal do script lido da documentacao local da pasta paralela (ex: `C:\Dev\Prod\Gx_FabricaBrasil\scripts\Test-FabricaBrasilKbGate.ps1`). Nao usar variavel nem `Join-Path`: o caminho literal e obrigatorio para que o sistema de permissoes consiga validar estaticamente o comando e dispensar prompts manuais. Nao acrescentar linhas, saidas auxiliares, parsing ou comandos ao bloco; toda a logica de gate esta encapsulada no script.

Executar este bloco usando o tool `PowerShell` (nao `Bash`). A sintaxe `& "..."` e PowerShell pura; o Bash nao consegue parsea-la e o sistema de permissoes acaba sem padrao estavel para registrar (sem opcao de "Sempre permitir"). Alem disso, a regra de permissao usa prefixo `PowerShell(...)` e nao casa quando o comando entra via tool `Bash`.

O comentario `#gate` no fim do bloco e proposital: e apenas comentario PowerShell (zero efeito em execucao), mas garante que o comando termine com conteudo apos o caminho. Isso permite usar o padrao de permissao `PowerShell(& "<caminho-absoluto-do-script>" *)` (espaco + curinga), que e o mesmo padrao dos demais scripts ja registrados no `settings.json`. Foi observado em Claude Desktop Windows que match exato sem curinga (`PowerShell(& "<caminho>")`) nao dispensa o prompt mesmo quando registrado, comportamento aparentemente bugado de descasamento entre matcher e registrador; o `#gate` evita esse caminho problematico.

```powershell
& "<caminho-absoluto-do-script>" #gate
```

Se o script retornar `GATE_OK`, encerrar o comando do gate; qualquer proxima acao deve ser decidida e executada em comando separado, conforme a consulta substantiva necessaria.

Se qualquer `BLOCK:` ocorrer, encerrar a pergunta de negocio e oferecer `xpz-kb-parallel-setup`. Nao executar etapas posteriores do gate em comandos separados para "completar diagnostico".

---

## WORKFLOW

1. Identificar o repositorio ativo e reler `README.md` e `AGENTS.md` locais
2. Se a pasta paralela da KB ainda nao estiver montada, validada ou mapeada para este repositorio -> **ABORT** e usar `xpz-kb-parallel-setup`
3. A PRIMEIRA acao substantiva desta skill em qualquer sessao deve ser executar o gate. Nenhuma consulta ao indice, leitura de XML, varredura de `ObjetosDaKbEmXml` ou comando `Query-*KbIntelligence.ps1` pode ocorrer antes de `Test-*KbGate.ps1` retornar `GATE_OK`. Isso vale inclusive para perguntas simples de existencia/localizacao nominal — `search-objects` e `object-info` estao proibidos antes do gate.
4. Executar o gate em ordem sequencial e parar no primeiro bloqueio; nao investigar camadas internas ate a camada externa estar valida
5. Verificar se existe `Test-*KbGate.ps1` em `scripts\`; se ausente, bloquear como defasagem da pasta paralela e oferecer atualizacao via `xpz-kb-parallel-setup`
6. Executar `Test-*KbGate.ps1`; o script verifica sequencialmente: estrutura da pasta paralela via `Test-*KbStructure.ps1`, pasta `KbIntelligence`, `kb-intelligence.sqlite`, wrapper local de consulta com `-Query index-metadata`, `kb-source-metadata.md` e comparacao de timestamps; qualquer `BLOCK:` encerra a pergunta de negocio
   - se a execucao do comando do gate for negada, cancelada ou interrompida pelo usuario, tratar como gate nao liberado: encerrar a pergunta de negocio, relatar a situacao ao usuario, oferecer revisao da regra de permissao em `settings.json` e/ou `xpz-kb-parallel-setup`; NUNCA contornar o gate com varredura, leitura pontual ou consulta indireta
7. Se qualquer etapa do gate falhar, bloquear pesquisa ampla, triagem substantiva, consulta substantiva ao acervo oficial de objetos, leitura de XML oficial de objeto e geracao de objetos para importacao, relatar a primeira excecao operacional encontrada e oferecer atualizacao via `xpz-kb-parallel-setup` antes de seguir
8. Com gate bloqueado, encerrar a pergunta de negocio antes de resolver o objeto pedido para caminho de XML; nao montar, testar existencia, listar ou abrir caminhos deduzidos como `ObjetosDaKbEmXml\<Tipo>\<Nome>.xml`
9. Classificar a pergunta do usuario em uma destas naturezas:
   - localizacao de objeto
   - impacto tecnico
   - dependentes e dependencias
   - evidencia de relacao especifica
   - triagem funcional curta
10. Escolher a consulta do indice mais adequada
11. So depois de `GATE_OK`, executar a consulta substantiva minima necessaria sem leitura lateral de `scripts`, `scripts/README-kb-intelligence.md` ou reinspecao do wrapper quando a pergunta ja couber em `search-objects` ou `object-info`
    - para pergunta simples de existencia/localizacao nominal, usar diretamente `search-objects` ou `object-info` conforme a pergunta, usando os parametros documentados em **QUERY PARAMETER REFERENCE**; nao abrir o wrapper para confirmar assinatura
12. Resumir o resultado da triagem de forma curta e auditavel
13. Decidir se a triagem ja basta para responder no nivel tecnico pedido
14. Se nao bastar, indicar ao chamador apenas o conjunto minimo de XMLs oficiais a abrir
15. Se a pergunta for funcional:
    - usar o indice apenas para orientar a ordem de leitura
    - manter explicitamente `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
16. Se a semantica GeneXus exigida estiver fora do recorte atual do indice, escalar para XML oficial e declarar o limite do indice
17. Se o wrapper local nao expuser uma capacidade ja disponivel no motor compartilhado:
    - relatar a defasagem
    - tratar o caso como bloqueio de compatibilidade da pasta paralela para aquela triagem
    - oferecer atualizacao via `xpz-kb-parallel-setup`
    - aguardar aprovacao explicita antes de alterar wrappers locais

---

## CONSTRAINTS

- NUNCA tratar o indice como fonte normativa final
- NUNCA substituir `ObjetosDaKbEmXml`
- NUNCA concluir funcionalidade sozinho apenas pelo indice
- NUNCA abrir XML em massa por padrao; a triagem pelo indice existe para reduzir leitura, abrir em massa anula o proposito da skill
- NUNCA consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, quando o gate de compatibilidade/frescor estiver bloqueado; gate bloqueado significa que o indice nao esta confiavel, e qualquer resposta baseada em leitura direta de XMLs pode estar desatualizada ou inconsistente
- NUNCA tratar recusa de permissao, cancelamento ou interrupcao do comando `Test-*KbGate.ps1` como autorizacao para fallback; trata-se de gate nao liberado e exige a mesma postura de bloqueio que `BLOCK:` da propria saida do script
- NUNCA usar `Grep`, `Select-String`, `Get-ChildItem`, `find`, varredura de pasta ou leitura pontual em `ObjetosDaKbEmXml` para responder pergunta de negocio quando o gate nao retornou `GATE_OK` por qualquer motivo, incluindo recusa de permissao, comando cancelado, interrupcao ou timeout
- NUNCA fazer pesquisa ampla no acervo nem gerar objetos para importacao quando o indice estiver defasado em relacao a ultima materializacao XPZ/XML
- NUNCA gastar diagnostico em camadas internas do gate quando uma camada externa ja falhou; parar no primeiro bloqueio e oferecer atualizacao
- NUNCA testar, listar ou abrir caminho filho de uma camada do gate antes de confirmar a camada pai; por exemplo, nao testar `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- NUNCA listar `scripts` ou procurar wrappers alternativos quando o wrapper local documentado estiver ausente; isso e defasagem da pasta paralela, nao descoberta de fallback
- NUNCA continuar a triagem substantiva quando `index-metadata` falhar, retornar vazio ou nao trouxer timestamp de build do indice
- NUNCA executar `search-objects`, `object-info`, `who-uses`, `what-uses`, `show-evidence`, `impact-basic` ou `functional-trace-basic` antes de `GATE_OK`
- NUNCA procurar `last_xpz_materialization_run_at` antes de confirmar que `kb-source-metadata.md` existe como arquivo
- NUNCA intercalar `Get-Date` entre etapas internas do gate; usar horario local apenas para updates/respostas ao usuario ou registro operacional necessario
- NUNCA descrever bloqueio pos-`index-metadata` como proibicao total de consultar o indice; `index-metadata` e consulta de gate, o bloqueio impede triagem substantiva
- NUNCA acrescentar parsing, saidas auxiliares, impressao de timestamps ou comandos ao bloco de chamada do gate; toda logica esta encapsulada em `Test-*KbGate.ps1`
- NUNCA, depois de `GATE_OK`, abrir `scripts/README-kb-intelligence.md`, listar `scripts` ou reinspecionar o wrapper local quando a pergunta puder ser resolvida diretamente por `search-objects` ou `object-info`
- NUNCA, em pergunta simples de existencia/localizacao nominal, abrir o wrapper local apenas para confirmar assinatura antes de chamar `search-objects` ou `object-info`; os parametros estao documentados em **QUERY PARAMETER REFERENCE**
- NUNCA encurtar ou reescrever de forma inconsistente o caminho nominal do XML oficial retornado pelo indice
- NUNCA reutilizar timestamp anterior em update ou resposta ao usuario; obter horario local imediatamente antes de cada mensagem
- NUNCA compensar falha de `index-metadata` ou ausencia de `last_xpz_materialization_run_at` lendo manualmente JSON de validacao, SQLite direto, `kb-source-metadata.md` isolado, datas de arquivo, `updated`, `generated_at`, `source_xpz` ou XML oficial para responder a pergunta de negocio
- NUNCA abrir XML oficial de objeto para responder pergunta de negocio quando o gate de compatibilidade/frescor estiver bloqueado
- NUNCA normalizar trabalho sem indice como alternativa economica quando o repositorio adota `KbIntelligence`; indice ausente ou defasado exige oferta de atualizacao
- NUNCA substituir `nexa`
- NUNCA substituir `xpz-reader`
- NUNCA tratar declaracao de estado em `AGENTS.md` local (ex: `materializado_e_indice_validado`) como autorizacao para pular a verificacao estrutural do gate quando `Test-*KbGate.ps1` estiver ausente ou quando a skill detectar ausencia objetiva de scripts. O `AGENTS.md` pode estar desatualizado; a inspecao objetiva da pasta paralela prevalece sobre declaracao de estado
- NUNCA assumir que toda capacidade nova do motor compartilhado ja esta exposta no wrapper local da KB
- NUNCA tratar ausencia de wrapper local compativel como defeito da base metodologica
- NUNCA escolher executor de validacao do KB Intelligence apenas pelo numero da fase; o formato do caso continua definindo o executor
- Se o indice local nao existir, relatar isso explicitamente, bloquear a pergunta de negocio e oferecer atualizacao via `xpz-kb-parallel-setup`
- Se a pergunta estiver fora do recorte coberto pelo indice e o gate ja tiver sido liberado, declarar isso antes de prosseguir para XML oficial
