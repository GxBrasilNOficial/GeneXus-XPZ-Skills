# Revisao estatica do dist - 0.13.0

Data: 2026-11-09. Pacote: `@jkudish/jev-mcp@0.13.0`. Fonte: tarball do npm com
integrity `sha512-0fFOAJwlsntMdHu4+t40H4BObOowfqVsZdMnU1tbqIHojbWotRia8quh8/SjEtwpC0CbemZF9TpBDbFNBhnRGw==`.
Commit do tag `v0.13.0`: `5e0ca5cacd1556dc0b8c227648843d3ebf5bdc93` (proveniencia,
nao equivalencia demonstrada).

## Pontos verificados

- `dist/index.js` sobe stdio por padrao (`serveStdio`); HTTP somente com `--http`
  ou `JEV_MCP_TRANSPORT=http`. O launcher nao passa `--http` nem define
  `JEV_MCP_TRANSPORT`.
- `dist/provider.js` no modo `compatible` usa `JEV_API_BASE_URL` como URL
  completa do POST, `Authorization: Bearer $JEV_API_KEY`, corpo
  `{model,state,questions}` e exige `answers` objeto na resposta. Nao ha outra
  chamada de rede nesse caminho.
- `JEV_MCP_MODEL` default `jev-latest`; o preset Command Code fixa
  `typesafe/jev`.
- `package.json` declara `engines.node >=22` e `scripts.prepare`; a skill usa
  `npm ci --ignore-scripts` e o `dist` pre-compilado.
- `LICENSE` MIT integral copiada para `LICENSE`.
- Boot sem chave: o servidor sobe e responde ao `initialize`; a ausencia de
  credencial valida NAO e detectada no boot (ver `boot-initialize.txt`).
- Encerramento: o servidor sai no fim do stdin; com stdin aberto, o processo
  permanece vivo (orfao e risco aceito da v1).

## Limites declarados

- Esta revisao e estatica + boot. Nao valida credencial, endpoint, modelo,
  egresso contido nem comportamento E2E.
- A contencao de rede nao foi demonstrada nesta maquina; o protocolo opt-in de
  Windows Sandbox esta no Anexo B.4.6 do design.
- O wire do modo `compatible` segue como hipotese; o host
  `https://api.commandcode.ai/provider/v1/systemone` foi medido com chamada
  autenticada em 2026-11-09.
