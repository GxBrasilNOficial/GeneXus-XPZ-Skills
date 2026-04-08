---
name: xpz-doc-builder
description: Gera e atualiza documentação Markdown a partir de acervo XML GeneXus/XPZ e moldes sanitizados, usando scripts locais do repositório ativo
---

# xpz-doc-builder

Gera, recompõe e atualiza documentação Markdown a partir do acervo XML do repositório e de moldes sanitizados. Usa scripts locais do repositório ativo e evita depender de caminhos absolutos privados.

---

## GUIDELINE

Identificar a raiz do repositório pelo contexto, localizar os scripts documentais em `scripts\`, resolver caminhos de entrada e saída a partir do cenário atual e delegar a geração ou atualização aos scripts apropriados. Evitar edição manual de `.md` longos quando houver fluxo automatizável.

---

## TRIGGERS

Use esta skill para:
- Usuário quer gerar inventário documental da KB a partir do acervo XML
- Usuário quer produzir documentação analítica ou matrizes a partir dos XMLs
- Usuário quer recompor uma seção Markdown com moldes sanitizados completos
- Usuário quer atualizar documentação a partir de exemplos reais de uma KB
- Usuário quer manter a base documental que alimenta humanos e outras skills

Do NOT use this skill for:
- Sincronizar XMLs a partir de um XPZ exportado pela IDE (use `xpz-sync`)
- Analisar um XML isolado sem intenção de atualizar a documentação (use `xpz-reader`)
- Gerar ou clonar objetos XPZ para empacotamento (use `xpz-builder`)

---

## MODOS

| Modo | Quando usar |
|---|---|
| `inventory` | Gerar inventário bruto do acervo XML |
| `advanced-docs` | Produzir documentação analítica, matrizes e catálogos estruturais |
| `update-section` | Recriar ou atualizar uma seção Markdown com exemplos XML completos |

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
2. Resolver a raiz do repositório pelo contexto
3. Localizar `scripts\` e confirmar a existência do script adequado
4. Confirmar ou derivar caminhos de entrada e saída
5. Executar o script com parâmetros explícitos
6. Reler o início do arquivo gerado ou alterado, a seção modificada e a transição seguinte
7. Reportar o que foi criado, atualizado ou substituído

---

## CONSTRAINTS

- NUNCA assumir caminhos absolutos privados
- NUNCA editar `.md` longos manualmente se houver script apropriado
- NUNCA reescrever uma seção sem identificar corretamente o título-alvo
- NUNCA esconder que o conteúdo foi gerado a partir de XMLs sanitizados ou acervo real quando isso for relevante
- Se o script esperado não existir, reportar o problema antes de improvisar uma edição manual ampla
