---
name: xpz-sync
description: Executa sincronização ou conferência de XPZ de uma KB GeneXus chamando os scripts locais do repositório ativo
---

# xpz-sync

Invoca os scripts locais do repositório GeneXus ativo para sincronizar XMLs individuais a partir de um XPZ exportado pela IDE, ou para conferir um export completo da KB.

---

## GUIDELINE

Identificar a raiz do repositório pelo contexto, localizar os scripts de sincronização na pasta `scripts\`, montar o comando correto e executá-lo via Bash. Reportar o resultado de forma clara. Não alterar arquivos manualmente — delegar tudo ao script.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.

---

## TRIGGERS

Use esta skill para:
- Usuário quer processar um `.xpz` exportado da IDE
- Usuário quer atualizar o acervo de XMLs a partir de um XPZ
- Usuário quer conferir se um export full da KB está completo
- Usuário quer rodar o script de sincronização ou de snapshot

---

## SCRIPTS ESPERADOS

O repositório deve conter em `<repo_root>\scripts\` dois wrappers:

| Propósito | Quando usar |
|---|---|
| **Atualização diária** — extrai e materializa XMLs no acervo a partir de um XPZ parcial | XPZ do dia a dia exportado pela IDE |
| **Conferência full** — verifica completude do acervo contra um export completo da KB, sem regravar nada | Novo export full da KB |

Os nomes exatos dos wrappers são definidos por cada repositório. Consulte o `README.md` local para identificá-los.

---

## LOCALIZAÇÃO DO REPOSITÓRIO

1. Usar o diretório de trabalho atual como ponto de partida
2. Se necessário, subir até encontrar a raiz Git (`git rev-parse --show-toplevel`)
3. Listar `scripts\` e identificar os dois wrappers pelo `README.md` local
4. Se não encontrados, perguntar ao usuário onde fica a raiz do repositório antes de prosseguir

---

## PARÂMETROS COMUNS

Os wrappers seguem esta convenção de parâmetros:

### Wrapper de atualização diária
- `-InputPath` *(obrigatório)* — caminho para `.xpz`, XML ou pasta contendo o XML
- `-VerifyOnly` *(switch)* — só confere, não regrava
- `-FullSnapshot` *(switch)* — compara snapshot completo do acervo
- `-ReportPath` *(opcional)* — salva relatório JSON
- `-KeepReport` *(switch)* — mantém relatório mesmo sem erro
- `-NoGitSummary` *(switch)* — suprime resumo Git no final

### Wrapper de conferência full
- `-InputPath` *(obrigatório)* — caminho para `.xpz`, XML ou pasta
- `-ReportPath` *(opcional)* — salva relatório JSON
- `-KeepReport` *(switch)* — mantém relatório mesmo sem erro

---

## WORKFLOW

1. Identificar se é atualização diária ou conferência de full snapshot
2. Resolver a raiz do repositório pelo contexto
3. Ler o `README.md` local para identificar os nomes dos wrappers
4. Confirmar o `InputPath` com o usuário se não foi fornecido
5. Montar o comando com os parâmetros corretos
6. Executar via Bash com `pwsh -File ...`
7. Reportar: objetos criados, atualizados, ignorados, resíduos removidos e resumo Git

---

## CONSTRAINTS

- NUNCA editar XMLs manualmente — todo o trabalho é delegado ao script
- NUNCA assumir caminhos absolutos privados — sempre derivar da raiz do repositório
- NUNCA assumir os nomes dos wrappers sem consultar o `README.md` local
- NUNCA mover arquivos entre pastas de trabalho e acervo — responsabilidade do fluxo oficial
- Se o script não for encontrado na raiz resolvida, reportar o erro e perguntar ao usuário antes de tentar qualquer alternativa
