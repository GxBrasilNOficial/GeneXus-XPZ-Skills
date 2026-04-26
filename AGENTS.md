# AGENTS.md

## Leitura obrigatória

- Ler primeiro o `README.md` local antes de agir.
- Reler a documentação local quando o contexto da conversa ficar longo, ambíguo ou perder aderência às convenções da raiz.

## Interpretação de prompts de terceiros

- Quando o usuário indicar que o texto seguinte é um prompt com sugestões de outro agente, tratar esse texto como insumo de avaliação.
- Neste repositório, o foco é **melhorar as skills XPZ**, não usá-las — então o workflow é:
  1. **Estude a documentação** das skills afetadas para entender sua metodologia
  2. **Estude o prompt** do outro agente para entender a solicitação
  3. **Avalie criticamente**: o que faz sentido, o que conflita, o que precisa ajuste
  4. **Apresente um plano** ao usuário: claramente o que será alterado, por quê e onde
  5. **Aguarde aprovação explícita** antes de fazer qualquer mudança
- Não invoque as skills como ferramentas (via `Skill` tool) — elas são o objeto do seu trabalho, não suporte para ele.

## README trilíngue

- A seção `Português (BR)` do `README.md` é a fonte editorial primária.
- Toda alteração de conteúdo, estrutura, regra operacional ou nomenclatura feita na seção `Português (BR)` deve ser refletida também nas seções `Español` e `English`.
- Não concluir edição do `README.md` com traduções parciais, defasadas ou estruturalmente inconsistentes sem apontar a pendência de forma explícita.

## Escopo da raiz

- Esta raiz é a base metodológica e operacional compartilhada das skills de `XPZ`/XML de GeneXus.
- Regras locais desta raiz devem ser tratadas como regras do repositório; não promovê-las automaticamente a regra universal fora desta base sem evidência documental correspondente.

## Trabalho nas skills XPZ

- Esta raiz contém a documentação metodológica de múltiplas skills (xpz-reader, xpz-builder, xpz-sync, xpz-doc-builder) e outros artefatos compartilhados.
- Ao trabalhar na melhoria de uma skill, estudar sua documentação de forma crítica e compreender seu propósito antes de propor mudanças.
- Quando receber um prompt de outro agente solicitando mudança em uma skill, não invoque essa skill como ferramenta — consulte sua documentação, analise o impacto e apresente um plano.

## Edição segura de Markdown

- Em `.md` longos ou estruturados, preferir edições pequenas, locais e ancoradas por seção.
- Após cada gravação, reler o início do arquivo, a seção alterada e a transição para a seção seguinte.
- Se uma edição automática produzir resultado inesperado, parar e voltar para uma estratégia mais localizada.

## Alinhamento entre documentos

- Ao alterar nomenclatura, fluxo ou regra operacional, verificar impacto pelo menos em `README.md`, `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md` e nas skills afetadas.
- Não deixar convenções conflitantes entre a base compartilhada e as skills quando a mudança fizer parte da mesma frente.

## Rastreabilidade privada de moldes sanitizados

- Quando uma frente criar, fortalecer, recombinar ou ampliar cobertura de molde sanitizado publicável, o agente deve avaliar explicitamente se existe anotação correspondente a registrar no `GeneXus-XPZ-PrivateMap`.
- Essa avaliação faz parte do fechamento metodológico da frente, mesmo quando nenhuma edição for feita imediatamente no repositório privado.
- Se houver necessidade de atualização no `GeneXus-XPZ-PrivateMap`, tratar isso como outro contexto operacional e sinalizar claramente ao usuário antes de editar fora desta base pública.

## Idioma

- Responder ao usuário em português, salvo pedido explícito em outro idioma.
- Quando citar conteúdo técnico originalmente em inglês, traduzir ao explicar sempre que isso melhorar a compreensão.
