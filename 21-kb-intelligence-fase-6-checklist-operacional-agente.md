# 21 - KB Intelligence Fase 6 - Checklist Operacional para Agente

## Papel do documento
checklist operacional

## Nivel de confianca predominante
medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md, scripts/README-kb-intelligence.md, 08-guia-para-agente-gpt.md

## Usado por
agentes que forem responder perguntas funcionais curtas usando o KB Intelligence como triagem tecnica, sem substituir a leitura do XML oficial

## Objetivo
Transformar o piloto da Fase 6 em um checklist pratico para uso recorrente por agentes.

Este checklist nao cria nova semantica de extracao e nao autoriza conclusao funcional automatica. Ele apenas organiza a ordem minima de consulta, leitura e resposta.

## Checklist antes de responder

- confirmar a pasta paralela da KB em uso
- ler `README.md` e `AGENTS.md` locais quando entrar em uma pasta de KB diferente da raiz metodologica
- confirmar o objeto sempre por `tipo + nome`
- localizar `KbIntelligence\kb-intelligence.sqlite`
- tratar `KbIntelligence\kb-intelligence.sqlite` como artefato canonico estavel da pasta paralela da KB
- tratar o SQLite como indice derivado, nao como fonte normativa
- se a triagem funcional sugerir que o canonico esta defasado em relacao ao comportamento esperado do indice, nao regenerar durante a propria investigacao
- tratar regeneracao do canonico como acao operacional separada, explicita e validada
- usar `ObjetosDaKbEmXml` como fonte normativa quando a pergunta depender de semantica GeneXus
- nao usar `ArquivoMorto`, salvo pedido explicito de analise historica
- nao tocar em `logs/` locais, salvo pedido explicito

## Ordem minima de triagem

1. executar `object-info` para confirmar existencia e caminho do objeto
2. se o nome ou tipo ainda estiver incerto, executar `search-objects`
3. executar `impact-basic` para obter dependentes e dependencias diretas
4. escolher apenas as relacoes que mudam a trilha de leitura
5. executar `show-evidence` nessas relacoes
6. abrir o XML oficial somente nos pontos necessarios
7. responder separando evidencia direta, leitura adicional, inferencia forte e hipotese

## Quando parar no indice

Parar no indice quando a pergunta pedir apenas:

- onde revisar primeiro
- quais objetos cercam tecnicamente um objeto
- qual relacao tecnica justifica abrir determinado XML
- qual trilha minima de leitura deve ser seguida

Nesses casos, a resposta deve declarar que se trata de triagem tecnica direta, nao de prova funcional completa.

## Quando abrir o XML oficial

Abrir o XML oficial quando a pergunta depender de:

- `Source` efetivo
- `Rules`
- `parm(...)`
- eventos
- formulas
- propriedades com efeito semantico
- cadeia imediata de chamadas
- tipo de variavel, `ATTCUSTOMTYPE`, BC, `SDT`, `Domain` ou `ExternalObject`
- interpretacao de efeito funcional, validacao, persistencia, navegacao ou regra de negocio

## Estrutura obrigatoria da resposta funcional

### Evidencia direta

Registrar somente o que veio do indice ou da evidencia armazenada:

- comando usado
- objeto origem e destino com `tipo + nome`
- arquivo relativo
- linha registrada
- regra de extracao
- trecho tecnico curto

### Leitura adicional do XML

Registrar o que foi confirmado no XML oficial:

- arquivo oficial lido
- trecho ou bloco consultado
- papel do trecho na investigacao
- limite do que a leitura confirmou

### Inferencia forte

Usar somente quando houver sinais convergentes, por exemplo:

- relacao tecnica direta no indice
- evidencia ancorada em linha
- XML oficial confirmando o contexto do trecho
- tipo ou variavel resolvida com seguranca

Mesmo nesses casos, nao transformar a inferencia em garantia runtime.

### Hipotese

Usar para o que ainda depende de leitura adicional, teste externo, build, execucao ou conhecimento funcional fora do recorte lido.

## Frases a evitar

- "o sistema certamente faz"
- "isso prova a regra de negocio"
- "o impacto funcional completo e"
- "basta olhar o indice"
- "nao precisa abrir o XML"
- "a procedure salva sempre"
- "o SDT e o payload completo"
- "a tela depende sempre dessa procedure"

## Frases preferidas

- "o indice mostra evidencia tecnica direta"
- "o XML oficial confirma este trecho"
- "a inferencia forte e"
- "permanece como hipotese"
- "para fechar a regra funcional completa, a leitura precisa seguir para"
- "isto e triagem tecnica, nao prova runtime completa"

## Comandos base

### Localizar objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName NomeDoObjeto `
  -Format json
```

### Triagem de impacto tecnico direto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName NomeDoObjeto `
  -Limit 20 `
  -Format json
```

### Auditar evidencia especifica

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType Procedure `
  -SourceName NomeOrigem `
  -TargetType Transaction `
  -TargetName NomeDestino `
  -Format json
```

## Gate de qualidade da resposta

Antes de responder, confirmar:

- o objeto foi tratado por `tipo + nome`
- a evidencia direta nao foi misturada com inferencia
- a leitura do XML foi citada separadamente
- toda conclusao funcional tem limite declarado
- hipoteses nao foram escritas como fatos
- o indice nao foi descrito como fonte normativa
- o XML oficial prevalece quando houver tensao interpretativa

## Proxima automacao possivel

Uma automacao futura pode empacotar a coleta de triagem, por exemplo `functional-trace-basic`, desde que:

- use o indice apenas para organizar a trilha
- retorne evidencias e caminhos de XML
- nao produza conclusao funcional automatica
- obrigue o agente a declarar limite de confianca
- preserve a separacao entre evidencia direta, leitura adicional, inferencia forte e hipotese
