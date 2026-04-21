---
name: xpz-doc-builder
description: Gera e atualiza documentação Markdown a partir de acervo XML GeneXus/XPZ e moldes sanitizados, usando scripts locais do repositório ativo
---

# xpz-doc-builder

Gera, recompõe e atualiza documentação Markdown a partir do acervo XML do repositório e de moldes sanitizados. Usa scripts locais do repositório ativo e evita depender de caminhos absolutos privados.

---

## GUIDELINE

Identificar a raiz do repositório pelo contexto, localizar os scripts documentais em `scripts\`, resolver caminhos de entrada e saída a partir do cenário atual e delegar a geração ou atualização aos scripts apropriados. Evitar edição manual de `.md` longos quando houver fluxo automatizável. Ao documentar acervo XML, distinguir snapshot oficial de artefato local de trabalho.

Se a documentação depender da pasta paralela da KB e essa estrutura ainda não estiver montada ou validada, parar e usar `xpz-kb-parallel-setup` antes de gerar ou atualizar documentação.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- Usuário quer gerar inventário documental da KB a partir do acervo XML
- Usuário quer produzir documentação analítica ou matrizes a partir dos XMLs
- Usuário quer recompor uma seção Markdown com moldes sanitizados completos
- Usuário quer atualizar documentação a partir de exemplos reais de uma KB
- Usuário quer manter a base documental que alimenta humanos e outras skills
- Usuário quer gerar documentação a partir de fonte técnica validada do KB Intelligence, preservando a distinção entre evidência direta e inferência

Do NOT use this skill for:
- Sincronizar XMLs a partir de um XPZ exportado pela IDE (use `xpz-sync`)
- Analisar um XML isolado sem intenção de atualizar a documentação (use `xpz-reader`)
- Gerar ou clonar objetos XPZ para empacotamento (use `xpz-builder`)
- Tratar o SQLite do KB Intelligence como fonte normativa no lugar dos XMLs oficiais

---

## MODOS

| Modo | Quando usar |
|---|---|
| `inventory` | Gerar inventário bruto do acervo XML |
| `advanced-docs` | Produzir documentação analítica, matrizes e catálogos estruturais |
| `update-section` | Recriar ou atualizar uma seção Markdown com exemplos XML completos |

O KB Intelligence pode alimentar documentação em fase posterior, mas o índice SQLite é artefato derivado. Ao usá-lo, rotule a origem como índice técnico derivado e preserve links para XML oficial e evidência quando possível.

---

## SCRIPTS ESPERADOS

O repositório deve conter em `<repo_root>\scripts\`:

| Script | Papel |
|---|---|
| `generate-kb-inventory.ps1` | Gera inventário bruto da KB a partir do acervo XML |
| `generate-kb-advanced-docs.ps1` | Gera documentação analítica a partir do acervo XML |
| `Update-XpzDocSection.ps1` | Recompõe uma seção Markdown com exemplos XML e notas editoriais |

Se o repositório ainda mantiver wrappers especializados, eles devem ser tratados como compatibilidade transitória, não como interface principal da skill.

---

## LOCALIZAÇÃO DO REPOSITÓRIO

1. Usar o diretório de trabalho atual como ponto de partida
2. Se necessário, subir até encontrar a raiz Git (`git rev-parse --show-toplevel`)
3. Localizar `scripts\`
4. Confirmar que os scripts documentais esperados existem
5. Se não existirem, relatar o problema antes de tentar alternativa manual

---

## PARÂMETROS COMUNS

### Geração de inventário
- `-SourceRoot` *(obrigatório)* — raiz do acervo XML
- `-OutputPath` *(obrigatório)* — arquivo Markdown de saída

### Geração analítica
- `-SourceRoot` *(obrigatório)* — raiz do acervo XML
- `-OutputRoot` *(obrigatório)* — pasta onde os Markdown serão gerados

### Atualização de seção
- `-TargetMarkdown` *(obrigatório)* — arquivo Markdown a atualizar
- `-SectionTitle` *(obrigatório)* — título exato da seção a recompor
- `-IntroLines` *(opcional)* — linhas introdutórias da seção
- `-XmlExamplePaths` *(obrigatório)* — lista de XMLs que serão incorporados
- `-ExampleTitles` *(opcional)* — títulos por exemplo
- `-ExampleNotes` *(opcional)* — notas por exemplo

---

## WORKFLOW

1. Identificar se o pedido é `inventory`, `advanced-docs` ou `update-section`
2. Se a pasta paralela da KB ainda não estiver montada, validada ou mapeada para este repositório → **ABORT** e usar `xpz-kb-parallel-setup`
3. Resolver a raiz do repositório pelo contexto
4. Localizar `scripts\` e confirmar a existência do script adequado
5. Confirmar ou derivar caminhos de entrada e saída
6. Executar o script com parâmetros explícitos
7. Se a documentação citar XML vindo de `ObjetosGeradosParaImportacaoNaKbNoGenexus`, rotular isso como artefato de trabalho e não como snapshot oficial
8. Quando a documentação gerar ou preservar links de linha para XML GeneXus, rotular o papel do trecho citado: `Source efetivo`, `Rules/parm`, `metadado XML`, `chamada no chamador` ou `assinatura no chamado`
9. Se a documentação afirmar que objeto A chama objeto B, validar que o link de linha aponta para o `Source` efetivo de A ou para metadado explícito de chamada em A; linha de `parm(...)` em B deve ser descrita apenas como assinatura do chamado
10. Se usar saída do KB Intelligence, declarar que a fonte imediata é índice técnico derivado e que a fonte normativa continua sendo o XML oficial em `ObjetosDaKbEmXml`
11. Reler o início do arquivo gerado ou alterado, a seção modificada e a transição seguinte
12. Reportar o que foi criado, atualizado ou substituído

---

## CONSTRAINTS

- NUNCA assumir caminhos absolutos privados
- NUNCA gerar documentação operacional dependente da pasta paralela da KB enquanto essa estrutura ainda estiver indefinida ou não validada
- NUNCA editar `.md` longos manualmente se houver script apropriado
- NUNCA reescrever uma seção sem identificar corretamente o título-alvo
- NUNCA esconder que o conteúdo foi gerado a partir de XMLs sanitizados ou acervo real quando isso for relevante
- NUNCA tratar `ObjetosGeradosParaImportacaoNaKbNoGenexus` como se fosse snapshot oficial da KB sem rotulagem explícita
- NUNCA documentar uma linha de `parm(...)` do objeto chamado como se fosse o ponto de chamada no objeto chamador
- NUNCA tratar o SQLite do KB Intelligence como prova funcional ou runtime; ele é índice técnico derivado de evidências extraídas
- Se o script esperado não existir, reportar o problema antes de improvisar uma edição manual ampla
