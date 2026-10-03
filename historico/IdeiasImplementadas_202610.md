# Ideias Implementadas — 2026-10

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

## Cobertura da assinatura do extrator no gate de rastreabilidade

### Registro de origem

- **Importância** — baixa (risco de falso-negativo restrito a um gate consultivo, com a revisão semântica como backstop). `scripts/Test-PrePushTraceabilityCoverageSelfTest.ps1` cobria `PUBLIC_TRACEABILITY_VERBOSE_LINE`, mas não os ramos que resolvem a assinatura do extrator e detectam referências documentais antigas. A mudança da constante de `Build-KbIntelligenceIndex.py` para `GeneXusKbIntelligenceExtractorSignature.py` expôs a dependência do consumidor em relação ao local da versão; o caso real foi corrigido, mas ainda não tinha regressão permanente. O ramo sem fonte resolvível emite `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` como aviso; faltava fixar esse comportamento em teste.
- **Maturidade** — pronta para implementar. Criar fixtures com repositório Git temporário e fontes sintéticas para cobrir: (1) formato legado, com a versão declarada em `Build-KbIntelligenceIndex.py`; (2) formato atual, com `Build-KbIntelligenceIndex.py` importando `GeneXusKbIntelligenceExtractorSignature.py`, bump da versão e referência anterior em documento, que deve gerar `EXTRACTOR_SIGNATURE_STALE_DOC_REF`; e (3) ausência de versão resolvível no estado atual ou base, que deve gerar `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` em vez de passar silenciosamente. Incluir também o acionamento quando apenas o módulo de assinatura estiver entre os arquivos alterados. Preservar o caráter consultivo (`warn`, `exit 0`).
- **Origem** — área não coberta identificada na revisão do commit `e03fa3d` (2026-10-02); relacionada ao item sobre propagação de tokens de self-test, mas com cenário e comportamento distintos.

### Resultado da implementação

Implementado em 2026-10-03. `Test-PrePushTraceabilityCoverage.ps1` agora compara afirmações explícitas de versão corrente com a assinatura atual do extrator e detecta instrução de próximo bump numérico já consumido. A detecção relaciona os termos de atualidade à afirmação sobre o extrator; uma palavra como “atualmente” ligada a outro fato numa referência datada não dispara sozinha. A busca continua limitada a Markdown rastreado ou não ignorado pelo Git, fora de `historico/` e `.git/`.

O self-test cobre a fonte de assinatura no módulo atual, a fonte legada em `Build-KbIntelligenceIndex.py`, o acionamento quando apenas o módulo de assinatura muda, afirmações correntes em português e inglês, próximo bump obsoleto, menções históricas sem afirmação corrente, menção datada de atualidade referente a Domains, exclusão de `Temp/` ignorado e `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` quando não há fonte resolvível.

O complemento material de `4693d33` aceita números entre crases ou aspas nas afirmações correntes, reconhece `EXTRACTOR_SIGNATURE_VERSION atual` e a constante com `=` ou `:` nos contextos operacionais documentados, além do contrato `schema_version / extrator` com verbo de indexação. Antes de normalizar os delimitadores, desconsidera o trecho de contrato introduzido por `Registro de AAAA-MM-DD:` e a citação delimitada após “O manual antigo dizia”, com formas correspondentes em espanhol e inglês. Essas exclusões são específicas; não representam interpretação geral de conteúdo histórico. O self-test cobre as seis formas normativas antes não detectadas, versões corretas, os dois falsos avisos históricos reproduzidos e afirmações vigentes incompatíveis antes ou depois desses trechos, inclusive na mesma frase.

### Rastreabilidade

- Commit material: `d4dca9f` (Refina avisos de versão do extrator e amplia testes de rastreabilidade).
- Commit material: `4693d33` (Corrige detecção de versões documentais e citações históricas do extrator).
- Arquivos materiais: `scripts/Test-PrePushTraceabilityCoverage.ps1`, `scripts/Test-PrePushTraceabilityCoverageSelfTest.ps1`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `13-revisao-pre-push.md`, `CHANGELOG.md` e `999-ideias-pendentes.md`.
