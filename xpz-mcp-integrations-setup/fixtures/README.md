# Fixtures da skill xpz-mcp-integrations-setup

Todos os arquivos sao sanitizados: sem caminho de perfil real, sem chave, sem
conteudo de KB ou dado de cliente. Placeholders usados nos fixtures:

- `__LAUNCHER__`: caminho absoluto da copia emitida do launcher.
- `__BASE_URL__`: base URL publica do preset/config de teste.
- `__MODEL__`: modelo publico de teste.

## `dist/0.13.0/`

Evidencia do artefato vendorizado, commitada com proveniencia:

- `provider-compatible.excerpt.js`: trecho sanitizado de `dist/provider.js`
  (resolucao de provedor e transporte `compatible`).
- `package-metadata.excerpt.json`: `engines.node`, `scripts.prepare`, `bin`,
  licenca e dependencias.
- `boot-initialize.txt`: transcricao do `initialize` MCP sem chave e exit 0.
- `eof-exit.txt`: comportamento de encerramento no fim do stdin e risco de orfao.
- `LICENSE`: MIT integral do pacote.
- `STATIC-REVIEW.md`: revisao estatica + boot (gate do F1).
- `PROVENANCE.json`: origem, integrity, tag/commit, data e limites.

## `opencode/`

Fixtures JSONC para o adaptador OpenCode: forma canonica, forma legada, as duas
coexistindo, `disabled`/`enabled:false`, `mcp` ausente/outro servidor, entrada
desconhecida, chave duplicada e armadilha de comentario.

## `codex/`

Fixtures TOML para o adaptador Codex: config sem a entrada, entrada manual no
cabecalho canonico, grafias equivalentes (aspa simples, chave pontilhada,
tabela inline, subtable, cabecalho com espacos), bloco entre marcadores,
marcadores desbalanceados, tabela alheia entre marcadores e TOML invalido.

## `auth-export/`

Fixtures sanitizadas de `opencode auth export` e `auth.json`: uma credencial,
varias, duplicada, ausente (`[]`), ativa e inativa. `auth-json-one.json` e
`auth-json-inactive.json` usam o formato real do OpenCode V2 (`type: api` em
`.local\share\opencode\auth.json`); `auth-json-key.json` cobre o legado
`type: key` em `.config\opencode\auth.json`; `auth-json-other-providers.json`
cobre o diagnostico de provedores sem `commandcode`.

## Rastreabilidade privada

As fixtures de `dist/` sao molde publicavel derivado do tarball. A anotacao
correspondente no `GeneXus-XPZ-PrivateMap` deve ser avaliada em contexto
operacional separado; a fonte publicada continua sendo este repositorio.
