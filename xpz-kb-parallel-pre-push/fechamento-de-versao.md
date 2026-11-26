# Revisão de fechamento de versão da KB

Quando o responsável pedir explicitamente a revisão de fechamento de uma versão da KB, apresente o relatório da pré-push de pasta paralela e conduza as duas etapas abaixo. A pré-push comum termina no relatório. Cumpra a [precondição de setup](../xpz-kb-parallel-setup/SKILL.md) antes de trabalhar na pasta paralela. Se o setup bloquear, resolva a precondição antes de iniciar a revisão. Se a Fase 1 da pré-push indicar `blocked`, o push fica proibido e a revisão pode prosseguir como diagnóstico com os insumos válidos.

## Primeira passada no delta

- Siga as Fases 1, 2a, 2b e 2c do [fluxo da skill](SKILL.md). Use o fetch padrão do orquestrador e registre o `fetchStatus` e os hashes completos da `BaseRef` e do `HEAD` logo após a Fase 1. Se usar `-SkipFetch` por escolha consciente, identifique a referência como local. Reaproveite uma rodada quando as referências e os insumos locais relevantes ainda corresponderem ao estado avaliado. Se mudarem ou houver dúvida sobre o estado avaliado, repita as verificações afetadas.
- Identifique a versão pelo pedido ou pela convenção da KB. Se o escopo da versão diferir de `BaseRef..HEAD` da pré-push, combine com o responsável o commit que serve de base para a comparação e o commit final da versão. Use `git diff <base-da-versão>..<fim-da-versão>` para a leitura estática do que ficou fora da rodada. Use a base da pré-push nas verificações mecânicas e, na Fase 2b, use no comparador a mesma `BaseRef` e o mesmo acervo da Fase 1, com `-BaseRef` e `-AcervoDirName` quando divergirem dos padrões.
- F1 e K11 selecionam caminhos pelo intervalo Git e leem o conteúdo atual desses arquivos no disco. A Fase 2a também lê o disco. Quando mudanças locais relevantes afetarem uma verificação, vincule seu resultado ao estado local e revalide antes de atribuí-lo ao commit da versão. A 2c ajuda a priorizar a leitura dos objetos e arquivos relevantes.

A primeira passada serve para você formar seu próprio parecer sobre possíveis lacunas, erros e regressões. Ler as conclusões anteriores primeiro pode concentrar sua atenção nos problemas que outros revisores já levantaram e fazer passar despercebido um problema novo.

Antes de abrir o registro anterior, examine o conteúdo dos diffs selecionados. A listagem de arquivos, o `git diff --stat` e a classificação por checksum ajudam a escolher o que ler. Identifique a versão pelo pedido e o intervalo pelo Git; se a base da versão estiver ambígua, pergunte ao responsável. Se o corpo do registro já tiver sido exibido, informe isso e trate a passada como assistida pelo histórico.

Entregue ao responsável o parecer da primeira passada, com o intervalo revisado, os objetos e arquivos efetivamente lidos, o que ficou de fora e as dúvidas ou suspeitas encontradas. Se a lista de suspeitas estiver vazia, informe isso. Termine a resposta perguntando: «Posso agora consultar o registro anterior e confrontar as decisões com esta primeira passada?» Aguarde a confirmação antes de abrir as perguntas e respostas.

## Confrontar com o registro anterior

Após a confirmação, retome cada dúvida da primeira passada. Para cada uma, apresente o que foi perguntado, a evidência ou decisão anterior relacionada e explique se ela responde ao ponto no estado revisado. Indique o que foi esclarecido e o que continua pendente. Se o responsável decidir encerrar com uma pendência, registre essa decisão junto ao item.

Uma evidência pode cobrir o ponto indiretamente, desde que esse vínculo seja demonstrado. Uma resposta sobre intenção não comprova, por si só, a cobertura de um build. Uma contagem igual não comprova que as ocorrências de um aviso sejam as mesmas. Leve ao responsável as questões ainda abertas, uma por vez e com a evidência da dúvida.

## Decidir sobre whitespace do acervo

Quando o G4 emitir `warn`, confira o `detail[]` na saída JSON. Proponha o aceite específico se os diagnósticos forem exclusivamente de whitespace no fim de linha em XMLs sob `acervoDirName` e houver evidência da origem oficial, como a mesma linha no XML exportado ou no commit de materialização correspondente. Linhas `unparsed` que apenas reproduzem o trecho de um diagnóstico identificado podem ser reconhecidas como contexto. Se sobrar uma linha sem explicação ou houver outro tipo de ocorrência, siga a [triagem normal de G4](fase1-mecanica.md#tabela-de-gates). Isso inclui avisos em XML novo da frente.

Registre o aceite explícito do responsável para a rodada. Preserve o acervo e o resultado `warn`. Se houver suspeita de alteração funcional, trate-a pelo fluxo oficial da KB.

## Registrar as decisões

Siga a convenção da KB. Na falta dela, proponha `Revisoes/Revisao-Fechamento-<versaoKB>-Perguntas-e-Respostas.md` na pasta paralela, com identificador válido para nome de arquivo. Obtenha aprovação para criar a pasta ou gravar o registro. O responsável decide se o arquivo será versionado.

Exemplo de registro:

```markdown
# Revisão de fechamento da KB <versão>

- Relatório da rodada, intervalo e hashes da pré-push
- Escopo efetivamente revisado e exclusões, com a base e a ponta da versão quando distintas
- Perguntas, objetos afetados, respostas e encaminhamentos
- Itens relevantes revisados sem pergunta
- Estado operacional, pendências e decisão sobre a revisão
- Builds e testes confirmados, com ambiente, resultado e estado coberto, se conhecido
```

O registro aponta para o estado revisado. Enquanto pendente, pode causar `warn` no G3. Se for commitado, entra no diff e erros de whitespace no Markdown podem causar `block` no G4. Quando só o registro mudar, confira o delta documental e revalide a aptidão para push, preservando a referência ao código revisado.

Correções, limpeza da Fase 2a, commit e push exigem autorização explícita própria. O responsável decide sobre o fechamento da revisão e sobre a publicação. O relatório da pré-push registra as condições para publicar.
