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

Se a pasta paralela da KB ainda nao estiver montada, validada ou mapeada, parar e usar `xpz-kb-parallel-setup` antes de depender de caminhos locais.

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
- Comecar pelo resultado da triagem, nao pelo historico do indice
- Dizer explicitamente quando a resposta ainda depende de leitura do XML oficial
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

| Reference | Load when |
|-----------|-----------|
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Sempre - regras de precedencia operacional e relacao entre artefato derivado e fonte normativa |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Sempre - regra de uso do KB Intelligence e escalada para XML oficial |
| [17-kb-intelligence-fase-6-contrato.md](../17-kb-intelligence-fase-6-contrato.md) | Quando a pergunta envolver resposta funcional curta |
| [21-kb-intelligence-fase-6-checklist-operacional-agente.md](../21-kb-intelligence-fase-6-checklist-operacional-agente.md) | Quando a pergunta envolver roteiro operacional do agente |
| [22-kb-intelligence-fase-6-contrato-functional-trace-basic.md](../22-kb-intelligence-fase-6-contrato-functional-trace-basic.md) | Quando a consulta candidata for `functional-trace-basic` |
| [scripts/README-kb-intelligence.md](../scripts/README-kb-intelligence.md) | Sempre que a skill precisar escolher consulta, interpretar cobertura ou distinguir validadores |

---

## WORKFLOW

1. Identificar o repositorio ativo e reler `README.md` e `AGENTS.md` locais
2. Se a pasta paralela da KB ainda nao estiver montada, validada ou mapeada para este repositorio -> **ABORT** e usar `xpz-kb-parallel-setup`
3. Verificar se a KB expoe `KbIntelligence\kb-intelligence.sqlite`
4. Verificar se existe wrapper local de consulta do indice
5. Classificar a pergunta do usuario em uma destas naturezas:
   - localizacao de objeto
   - impacto tecnico
   - dependentes e dependencias
   - evidencia de relacao especifica
   - triagem funcional curta
6. Escolher a consulta do indice mais adequada
7. Executar a consulta local apropriada
8. Resumir o resultado da triagem de forma curta e auditavel
9. Decidir se a triagem ja basta para responder no nivel tecnico pedido
10. Se nao bastar, indicar ao chamador apenas o conjunto minimo de XMLs oficiais a abrir
11. Se a pergunta for funcional:
    - usar o indice apenas para orientar a ordem de leitura
    - manter explicitamente `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
12. Se a semantica GeneXus exigida estiver fora do recorte atual do indice, escalar para XML oficial e declarar o limite do indice
13. Se o wrapper local nao expuser uma capacidade ja disponivel no motor compartilhado:
    - relatar a defasagem
    - tratar o caso como oportunidade de adaptacao local
    - aguardar aprovacao explicita antes de propor alteracao local

---

## CONSTRAINTS

- NUNCA tratar o indice como fonte normativa final
- NUNCA substituir `ObjetosDaKbEmXml`
- NUNCA concluir funcionalidade sozinho apenas pelo indice
- NUNCA abrir XML em massa por padrao
- NUNCA substituir `nexa`
- NUNCA substituir `xpz-reader`
- NUNCA assumir que toda capacidade nova do motor compartilhado ja esta exposta no wrapper local da KB
- NUNCA tratar ausencia de wrapper local compativel como defeito da base metodologica
- NUNCA escolher executor de validacao do KB Intelligence apenas pelo numero da fase; o formato do caso continua definindo o executor
- Se o indice local nao existir, relatar isso explicitamente antes de cair para leitura ampla do acervo
- Se a pergunta estiver fora do recorte coberto pelo indice, declarar isso antes de prosseguir para XML oficial
