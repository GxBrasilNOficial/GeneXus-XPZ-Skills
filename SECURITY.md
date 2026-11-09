# Política de Segurança

## Português (BR)

Este repositório contém documentação, scripts e exemplos metodológicos para trabalho com XPZ/XML de GeneXus. Relatos de segurança devem proteger pessoas, clientes, KBs reais e artefatos privados.

### Como reportar

Se você encontrar uma vulnerabilidade, vazamento acidental de informação sensível ou risco operacional que possa afetar usuários do projeto:

- use um canal privado do repositório quando ele estiver disponível;
- se não houver canal privado configurado, contate o mantenedor pelo canal já usado para coordenação do projeto ou por `for-genexus-community@frigobyte.com` antes de publicar detalhes sensíveis;
- não abra uma issue pública com credenciais, nomes sensíveis de clientes, conteúdo de KB real ou passos exploráveis.
- não envie credenciais, XPZ real ou conteúdo de KB real por e-mail sem combinação prévia.

### Escopo

São relevantes para esta política:

- exposição de credenciais, dados de cliente ou artefatos não sanitizados;
- scripts que possam gravar fora do escopo documentado;
- instruções que induzam alteração insegura de KB, banco de dados ou pacote XPZ;
- falhas que permitam falso positivo crítico em validações de segurança operacional.

Relatos de bug comum, erro de documentação sem impacto sensível ou sugestão de melhoria podem seguir o fluxo normal de issues ou pull requests.

### Cofre do `xpz-mcp-integrations-setup`

- A chave do componente MCP externo opcional fica em blob **DPAPI `CurrentUser`** sob `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, com ACL só-dono e **sem roaming**.
- A chave nunca é gravada no config do cliente, em log, prompt ou mensagem. O launcher lê do cofre e monta o ambiente do filho por allowlist.
- A importação de `opencode auth export`/`auth.json` é bootstrap único e **não altera** o `auth.json`.
- A contenção de rede do componente vendorizado **não foi demonstrada** nesta máquina (Windows Sandbox indisponível em 2026-11-09); o gate do F1 é revisão estática do `dist` + boot sem chave.
- Relatos de exposição de chave, leitura indevida do cofre ou gravação em config de cliente seguem o canal privado desta política.

## Español

Este repositorio contiene documentación, scripts y ejemplos metodológicos para trabajar con XPZ/XML de GeneXus. Los reportes de seguridad deben proteger personas, clientes, KBs reales y artefactos privados.

### Cómo reportar

Si encuentras una vulnerabilidad, filtración accidental de información sensible o riesgo operativo que pueda afectar a usuarios del proyecto:

- usa un canal privado del repositorio cuando esté disponible;
- si no hay un canal privado configurado, contacta a la persona mantenedora por el canal ya usado para coordinar el proyecto o por `for-genexus-community@frigobyte.com` antes de publicar detalles sensibles;
- no abras una issue pública con credenciales, nombres sensibles de clientes, contenido de KB real o pasos explotables.
- no envíes credenciales, XPZ real o contenido de KB real por correo electrónico sin acuerdo previo.

### Alcance

Son relevantes para esta política:

- exposición de credenciales, datos de clientes o artefactos no sanitizados;
- scripts que puedan escribir fuera del alcance documentado;
- instrucciones que induzcan alteración insegura de KB, base de datos o paquete XPZ;
- fallas que permitan falsos positivos críticos en validaciones de seguridad operativa.

Reportes de bugs comunes, errores de documentación sin impacto sensible o sugerencias de mejora pueden seguir el flujo normal de issues o pull requests.

### Cofre de `xpz-mcp-integrations-setup`

- La clave del componente MCP externo opcional vive en un blob **DPAPI `CurrentUser`** bajo `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, con ACL solo-dueño y **sin roaming**.
- La clave nunca se escribe en la config del cliente, en logs, prompts ni mensajes. El launcher la lee del cofre y arma el ambiente del hijo por allowlist.
- La importación de `opencode auth export`/`auth.json` es bootstrap único y **no modifica** el `auth.json`.
- La contención de red del componente vendorizado **no fue demostrada** en esta máquina (Windows Sandbox no disponible en 2026-11-09); el gate del F1 es revisión estática del `dist` + boot sin clave.
- Reportes de exposición de clave, lectura indebida del cofre o escritura en config de cliente siguen el canal privado de esta política.

## English

This repository contains documentation, scripts, and methodological examples for working with GeneXus XPZ/XML. Security reports should protect people, clients, real KBs, and private artifacts.

### How to Report

If you find a vulnerability, accidental sensitive information leak, or operational risk that may affect project users:

- use a private repository channel when available;
- if no private channel is configured, contact the maintainer through the channel already used for project coordination or at `for-genexus-community@frigobyte.com` before publishing sensitive details;
- do not open a public issue with credentials, sensitive client names, real KB content, or exploitable steps.
- do not send credentials, real XPZ files, or real KB content by email without prior agreement.

### Scope

This policy covers:

- exposure of credentials, client data, or non-sanitized artifacts;
- scripts that may write outside the documented scope;
- instructions that induce unsafe changes to a KB, database, or XPZ package;
- failures that allow critical false positives in operational safety validations.

Common bug reports, documentation errors without sensitive impact, or improvement suggestions may follow the regular issue or pull request flow.

### `xpz-mcp-integrations-setup` vault

- The optional external MCP component key lives in a **DPAPI `CurrentUser`** blob under `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, with an owner-only ACL and **no roaming**.
- The key is never written to client config, logs, prompts, or messages. The launcher reads it from the vault and builds the child environment by allowlist.
- Import from `opencode auth export`/`auth.json` is a one-time bootstrap and **does not modify** `auth.json`.
- Network containment of the vendored component was **not demonstrated** on this machine (Windows Sandbox unavailable on 2026-11-09); the F1 gate is static review of `dist` + boot without a key.
- Key exposure, improper vault reads, or writes to client config are handled through this policy's private channel.
