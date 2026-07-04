# KB Intelligence Scripts

## Papel do documento
guia operacional

## Escopo atual

Estes scripts implementam o índice técnico KB Intelligence com suporte a inventario, relacoes semanticas e triagem funcional assistida por agentes.

O comando `impact-basic` resume dependentes e dependencias diretas do objeto. O comando `functional-trace-basic` monta trilha funcional inicial para perguntas curtas, mas não produz conclusao funcional automática.

Catalogo técnico canonico de tipos:

- `scripts/gx-object-type-catalog.json`
- `Regra operacional`: catalogo **efetivo** = base compartilhada + `scripts/gx-object-type-catalog.override.json` na pasta paralela quando existir (override prevalece por tipo canonico); `Build-KbIntelligenceIndex.py` e `Query-KbIntelligenceIndex.py` mesclam via `scripts/GeneXusObjectTypeCatalogCore.py`, com `--parallel-kb-root` / `--catalog-override-path` (build: deteccao automática quando `--source-root` termina em `ObjetosDaKbEmXml`; query: deteccao quando o SQLite está em `KbIntelligence/`)
- `Regra operacional`: esse JSON e a fonte técnica canonica para `Object/@type`, `rootKind`, pasta esperada e elegibilidade de inventario; os `.md` seguem como explicacao editorial e histórica
- `Regra operacional`: esse catalogo cobre só tipos modernos por GUID. Elementos de export **legado GeneXus 9** (`<GXObject><Elemento>` por nome, sem GUID de tipo) ficam no registro proprio `scripts/gx-legacy-export-element-registry.json` (doc-dono `01k-registro-elementos-legados.md`), não neste catalogo nem como objeto indexado/consultavel no KbIntelligence. O **motor/parser de export legado já existe** (`scripts/GeneXusLegacyExportFileSupport.ps1`) e está integrado ao sync/inventário (`Sync-GeneXusXpzToXml.ps1` materializa o ramo legado; `Get-GeneXusImportPackageObjectInventory.ps1` inventaria itens `known-legacy`; pacote misto fail-closed). O `Build-KbIntelligenceIndex.py` é, por sua vez, **registry-aware** quanto ao acervo materializado: carrega o registro e reconhece pastas órfãs (`Report`/`Menubar`) e `Object/@type` `gxlegacy/*` como known-legacy, pulando-as no build **sem** `raise SystemExit` nem `status=BLOCK` e auditando o skip no campo `legacy_orphan_directories_skipped` do `inventory_semantics` (órfão pulado não é indexado para query — consequência conhecida)
- `Regra operacional`: `Attribute` só deve ser classificado como tipo canonico do arquivo quando a raiz real for `<Attribute ...>`; ocorrências inline de `<Attribute>` dentro de `Transaction`, `Table` ou outros XMLs não redefinem o tipo do objeto

### Flags `inventoryEligible` e `queryableByKbIntelligence`

- `inventoryEligible=true`: o tipo entra no inventario do índice (objeto listavel em `object-info`, `search-objects`, `list-by-type`) quando houver XML em subpasta de `ObjetosDaKbEmXml`.
- `queryableByKbIntelligence=true`: consultas semânticas do índice (`who-uses`, `what-uses`, `impact-basic`, `functional-trace-basic`) são **aptas** para o tipo com o extrator atual — o grafo tende a refletir dependencias tecnicas reais no acervo.
- `queryableByKbIntelligence=false`: o objeto pode estar no inventario, mas **não** usar as consultas semânticas acima como prova de impacto ou dependencia; o motor atual não extrai relacoes desse tipo (respostas vazias parecem “sem impacto”). Preferir `object-info`, `search-objects` ou leitura pontual do XML. Lista canônica: cada entrada em `scripts/gx-object-type-catalog.json` (amostra multi-KB: `scripts/Invoke-ParallelKbEnvelopeScan.ps1`; grafo zero: consulta a `kb-intelligence.sqlite`).
- `Query-KbIntelligenceIndex.py` recusa `who-uses`, `what-uses`, `impact-basic` e `functional-trace-basic` quando o tipo tem `queryableByKbIntelligence=false` no **catalogo efetivo** (base + override): JSON com `blocked=true`, `reason=QUERY_NOT_SEMANTIC_FOR_TYPE`, exit `11`. Wrappers devem repassar `-ParallelKbRoot` / `-CatalogOverridePath` como no build.

### Tipos com grafo assimétrico (`queryableByKbIntelligence=true`)

Estes tipos **permanecem** aptos a consultas semânticas; o grafo pode ser só de saída, só de entrada ou esparso — **não** reclassificar como `false` só porque `incoming_relations=0` ou `outgoing_relations=0` em um lado.

| Tipo | Comportamento típico no índice atual | Uso de `impact-basic` |
| --- | --- | --- |
| `API` | Quase sempre **origem** (chamadas em `Source`); raramente destino | Informa o que o API dispara |
| `DataSelector` | Idem `API`, volume menor | Idem |
| `WorkWithForWeb` | Forte **origem** (actions, links, transação); quase nunca `target_type` WorkWith | Informa dependências que o WW referencia |
| `ExternalObject` | Pode receber entrada via `ATTCUSTOMTYPE` resolvido e por chamada de método em variável `exo:<ExternalObject>` no `Source` efetivo; esparsa por KB | `who-uses` pode achar referencias declarativas e usos efetivos; grafo vazio em KB pequena não prova ausencia global |

Não confundir com tipos `false` (ex.: `Image`, `Theme`, `SubTypeGroup`), em que o extrator **nunca** cria arestas para esse `target_type`.

Escopo de inventario atual:

- todos os tipos marcados como `inventoryEligible=true` no catalogo técnico e presentes com XML em subpastas imediatas de `ObjetosDaKbEmXml`

Escopo de extracao de relacoes atual:

- origens por `Source` efetivo: `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector`
- destinos por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- a varredura de `Source` cobre também `Source` serializado em XML estruturado (ex: `<Property><Name>ControlWhere</Name><Value>procXxx(...)</Value></Property>` em layouts de WebPanel), não apenas `Source` em CDATA com código GeneXus livre
- criacao de WebComponent em `Source` efetivo: `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector` para `WebPanel` a partir de `<WebPanel>.Create(...)`, quando o alvo existir no inventario local de `WebPanel`
- origem por action: `WorkWithForWeb`
- destino por action: `Procedure` ou `WebPanel`
- vinculacao explicita: `WorkWithForWeb` para `Transaction`
- link explicito: `WorkWithForWeb` para `WebPanel`
- prompt explicito: `WorkWithForWeb` para `WebPanel`
- condição explicita: `WorkWithForWeb` para `Procedure`
- atributo de condição: `WorkWithForWeb` para `Procedure`
- alvo literal por propriedade: `CustomType:<valor>` a partir de `ATTCUSTOMTYPE`
- alvo resolvido por propriedade: `SDT`, `Domain` ou `ExternalObject` a partir de `ATTCUSTOMTYPE`, quando o objeto existir no inventario e a regra aprovada resolver o prefixo com seguranca
- origem atual de `ATTCUSTOMTYPE` indexado: `Procedure`, `WebPanel`, `DataProvider`, `API`, `DataSelector`, `Domain`, `SDT`, `WorkWithForWeb` e `Transaction`
- chamada efetiva de método em ExternalObject: `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector` para `ExternalObject` a partir de `&Variavel.Metodo(...)` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `exo:<ExternalObject>` resolvido no inventario local
- dominio base de atributo: `Attribute` para `Domain` a partir de `idBasedOn`, quando o dominio existir no inventario local
- chamada em atributo calculado: `Attribute` para `Procedure`, `WebPanel` ou `DataProvider` a partir de `Property Formula`, quando o alvo existir no inventario local e o padrão de chamada for o mesmo usado em `Source` efetivo (`proc...(...)`, `Nome.Call(...)`, `Nome.Link(...)`, `Nome.Create(...)`, chamada direta a `DataProvider`)
- atributo estrutural de transacao: `Transaction` para `Attribute` a partir de `<Level>/<Attribute>`, quando o atributo existir no inventario local
- tabela estrutural de transacao: `Transaction` para `Table` a partir de `Type` em `<Level>`, quando a tabela existir no inventario local
- atributo chave de tabela: `Table` para `Attribute` a partir de `<Key>/<Item>`, quando o atributo existir no inventario local
- atributo membro de índice de tabela: `Table` para `Attribute` a partir de `<Index>/<Part>/<Members>/<Member>`, quando o atributo existir no inventario local
- tipo de item de SDT: `SDT` para `SDT` a partir de `ATTCUSTOMTYPE` em `<Item>`, quando o valor tiver prefixo `sdt:` e o SDT existir no inventario local
- tabela navegada explicitamente: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>` em `Source` efetivo, quando a tabela existir no inventario local
- prefixo de tabela em navegacao qualificada: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>.<Membro>` em `Source` efetivo, quando `<Nome>` existir como tabela no inventario local
- carga de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Load(...)` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- persistencia de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Save()` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- exclusao de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Delete()` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- validação de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Check()` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- insercao/atualizacao de Business Component simples: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Insert()` ou `&Variavel.Update()` em `Source` efetivo, quando a variável tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local e não tiver `AttCollection=True`
- relacoes: chamadas diretas em `Source efetivo`, criacao de WebComponent por `<WebPanel>.Create(...)`, actions `gxobject` resolvidas, vinculacoes explicitas de `Transaction`, links e prompts explicitos de `WebPanel` em `WorkWithForWeb`, condições por tag e atributo de `WorkWithForWeb` chamando `Procedure`, propriedades `ATTCUSTOMTYPE`, chamadas de método em variável `exo:<ExternalObject>`, `idBasedOn` e `Formula` de `Attribute`, atributos e tabelas estruturais de `Transaction`, atributos chave e membros de índice de `Table`, tipos internos resolvidos de `SDT`, tabelas declaradas em `for each` explicito, prefixos de tabela em `for each` qualificado e chamadas `.Load(...)`/`.Save()`/`.Delete()`/`.Check()`/`.Insert()`/`.Update()` de BC resolvidas para `Transaction`
- artefato principal: SQLite derivado

A extracao básica cobre `DataProvider` como origem e como destino de chamada direta, `<WebPanel>.Create(...)` em `Source` efetivo, actions de `WorkWithForWeb` com `gxobject` resolvido para `Procedure` ou `WebPanel`, vinculacao explicita de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condições por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e `ATTCUSTOMTYPE` como `CustomType` literal. Ela não cobre semantica completa de `Transaction`, semantica de `WorkWithForWeb` além dos recortes já cobertos. A extracao semantica ampliou `for each`, `.Load(...)`, resolucao de `CustomType` para `SDT`, `Domain` e `ExternalObject`, e chamada efetiva de método em variável `exo:<ExternalObject>`.

Eles não substituem o acervo XML em `ObjetosDaKbEmXml` e não provam comportamento runtime.

## Pre-requisito Python

- rebuild do índice exige **Python 3.x utilizavel** no `PATH` (resolucao em `scripts/GeneXusPythonPrerequisite.ps1`, chamado por `Build-KbIntelligenceIndex.ps1`)
- stub `WindowsApps` da Microsoft Store não conta; ausencia retorna exit `8` com mensagem `PREREQUISITO AUSENTE`
- falha do motor Python propaga stderr/saida capturada no `throw` do wrapper PowerShell
- **rigor**: sync XPZ/XML oficial **não** termina sem índice regenerado — a materialização em `ObjetosDaKbEmXml` pode já ter concluido; declarar **fluxo incompleto**, não sync OK nem falha do pacote exportado; não autorizar triagem ampla sem índice; ver `README.md`, `08-guia-para-agente-gpt.md` e `xpz-sync`

## Gerar índice

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-basic.json" `
  -FailOnValidationFailure
```

Para outra KB, troque `-SourceRoot`, `-OutputPath` e, se aplicavel, `-ValidationCasesPath`.

Para validar extracao estendida em `KBExemplo`, use:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-extended.json" `
  -FailOnValidationFailure
```

O local operacional padrão dentro da pasta paralela da KB e `KbIntelligence\kb-intelligence.sqlite`. Este banco e derivado e regeneravel; a fonte normativa continua sendo `ObjetosDaKbEmXml`.

## Frescor operacional do índice

O índice só deve ser usado para triagem ampla quando estiver em dia com a última materialização XPZ/XML do acervo oficial.

- `last_xpz_materialization_run_at` fica no `kb-source-metadata.md` da raiz da pasta paralela da KB
- `last_index_build_run_at` fica na tabela `metadata` de `KbIntelligence\kb-intelligence.sqlite`
- `last_index_build_run_at` também e espelhado em `KbIntelligence\kb-intelligence-validation.json` quando o relatório de validação e gerado
- `inventory_validation_status` fica na tabela `metadata` do SQLite e deve estar `OK`
- `generated_at` não faz mais parte do contrato operacional do índice; se aparecer em artefato antigo, trate esse índice como legado/incompativel e regenere
- todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize ou atualize XMLs em `ObjetosDaKbEmXml` deve chamar a regeneracao/validacao do índice logo depois
- se `last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e `extractor_signature_version`/`extractor_signature_hash` na metadata coincidirem com o motor atual em `scripts/Build-KbIntelligenceIndex.py` (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1`), o índice está apto para triagem inicial
- ausencia de `extractor_signature_version` ou `extractor_signature_hash` na metadata, ou divergencia em relacao ao motor compartilhado, significa índice gerado por extrator antigo mesmo quando os timestamps parecem frescos — `Test-*KbIndexGate.ps1` bloqueia com `BLOCK:` e a resposta correta e rebuild do índice
- se o índice estiver ausente, sem metadado, mais antigo que a última materialização ou se `kb-source-metadata.md` não expuser literalmente `last_xpz_materialization_run_at`, o agente não deve consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, e também não deve gerar objetos para importação na KB pela IDE
- se `inventory_validation_status` estiver ausente, `BLOCK` ou diferente de `OK`, tratar o índice como semanticamente incompativel com o snapshot oficial e oferecer rebuild/atualizacao antes da triagem ampla
- nesse estado defasado, o agente deve tratar a situacao como exceção operacional, oferecer regeneracao/validacao do índice ao usuário e não seguir para varredura ampla, triagem substantiva, caminho pontual deduzido, leitura de XML oficial de objeto ou geração
- leitura pontual com gate bloqueado só deve ocorrer para diagnostico mínimo da incompatibilidade em documentação local, estrutura, wrappers e metadados operacionais; não montar, testar existência, listar ou abrir caminho de XML oficial de objeto como fallback para responder pergunta de negocio
- o gate deve ser sequencial e atômico; não testar caminho filho antes da camada pai, por exemplo `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- se o wrapper local documentado de consulta do índice estiver ausente, não listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup
- não substituir `last_xpz_materialization_run_at` por data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatório ou outro metadado aproximado

Para ler os metadados do índice pelo wrapper:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query index-metadata `
  -Format text
```

Se `index-metadata` falhar, retornar vazio ou não expor `last_index_build_run_at` ou `inventory_validation_status`, trate o índice como legado/incompativel ou sem metadado valido. Não siga para triagem substantiva, pesquisa ampla, caminho pontual deduzido em `ObjetosDaKbEmXml`, leitura de XML oficial de objeto ou geração de objetos; ofereca regeneracao/validacao do índice ao usuário.

Quando a validação do índice for parte relevante da resposta ou handoff, registre a decisão de forma curta. Em caso apto, informe `last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e assinatura do extrator alinhada; em caso bloqueado, informe o campo/capacidade ausente, qual timestamp ficou defasado, assinatura do extrator ausente/defasada ou qual incompatibilidade semantica de inventario foi detectada.

## Assinatura do extrator (`extractor_signature_*`)

O motor `Build-KbIntelligenceIndex.py` grava na tabela `metadata`:

- `extractor_signature_version` — incrementada quando a cobertura ou regras do indexador mudam de forma material
- `extractor_signature_hash` — SHA-256 dos bytes do próprio `Build-KbIntelligenceIndex.py` usado no build

Contrato compartilhado: `scripts/GeneXusKbIntelligenceExtractorContract.ps1`. Verificacao: `scripts/Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.ps1` (sentinela `KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK`).

O gate `Test-*KbIndexGate.ps1` (molde em `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1`) compara a metadata do índice com o motor do repositório ativo. Índices antigos sem esses campos passam no teste de timestamp mas falham neste passo — comportamento esperado após evolucoes como ampliacao de `INDEXED_SOURCE_TYPES`.

## Schema e versionamento

O índice armazena `schema_version` na tabela `metadata`. O valor atual e `"4"` (inclui a tabela `transaction_attribute_writability` com `writability_rule_version`, a tabela `css_class` do catalogo de classes CSS e as colunas `is_generated_object`/`pattern_object_id`/`instance_key` na tabela `objects`).

O design e deliberado: o índice e artefato derivado e sempre regeneravel. Por isso não existe caminho de migracao de schema — qualquer mudanca estrutural no motor exige rebuild completo.

Consequencias operacionais:

- todo índice gerado antes da introducao de `schema_version` e tratado automaticamente como incompativel e bloqueia qualquer consulta com mensagem explicita de rebuild
- a cada evolucao de schema (`"1"` → `"2"` → `"3"` → `"4"`), todo índice em versão anterior bloqueia da mesma forma — comportamento esperado, não bug
- o erro de schema version e detectado pelo próprio `Query-KbIntelligenceIndex.py` antes de qualquer query, incluindo `index-metadata`; portanto o gate `Test-*KbIndexGate.ps1` também falha com `BLOCK:` em índices incompativeis
- a resposta correta a qualquer bloqueio por schema e rebuild via `Build-KbIntelligenceIndex.ps1`, nunca contorno por leitura direta do SQLite ou dos XMLs

## Objetos gerados por Pattern (autoral x gerado)

A tabela `objects` traz três colunas para separar objetos GERADOS por Pattern (WorkWith For Web) de AUTORAIS **de forma determinística**, sem heurística de nome (`ww*`/`*WC`/`*General`/`*Selection`):

- `is_generated_object` (`INTEGER NOT NULL DEFAULT 0`): `1` quando o objeto tem a propriedade de nível-objeto `IsGeneratedObject=True`; `0` caso contrário (autoral ou derivado).
- `pattern_object_id` (`TEXT`, nulável): o papel no Pattern (ex.: `TabGrid`, `TabTabular`, `View`, `Selection` em WebPanel; `ExportSelection`, `ExportTabGrid` em Procedure).
- `instance_key` (`TEXT`, nulável): a instância dona — `<type-GUID do WorkWithForWeb>-<nome da instância WorkWith>`. Pode ser nulo mesmo com `is_generated_object=1` (ex.: alguns Procedures gerados).
- `instance_name` (campo **derivado**, não é coluna): o nome da instância extraído de `instance_key` pelo motor de query, em `object-info`/`search-objects`/`list-by-type` (não em `attribute-info`, nem em `transaction-attributes`/`transaction-writable-attributes`). Sempre presente na saída, `null` quando não derivável (`instance_key` nulo ou não-canônico). Derivação ancorada no GUID canônico (`8-4-4-4-12`) + primeiro hífen; nunca `split` cego (hífens internos do nome são preservados). O mapeamento `pattern_object_id → forma-do-nome` (`Selection`=`WW<nome>`, `TabTabular`=`<nome>General`, etc.) é **convenção GeneXus, não contrato do repositório**.

A extração é **escopada ao `<Properties>` do objeto RAIZ** (parse XML por bytes; fallback regex do último bloco `<Properties>` só em XML malformado), nunca de `<Object>` aninhado em tipo-contêiner (`PackagedModule`, que empacota uma lib com objetos internos marcados). Os três campos aparecem no JSON de `object-info`/`search-objects`/`list-by-type`; no `--format text`, `object-info` mostra os três mais `instance_name`; `search-objects`/`list-by-type` mostram `generated=0/1` e, quando derivável, `instance_name=<nome>` (saída de lista compacta). A metadata do índice traz `generated_objects_count`.

Filtro determinístico (`--generated` / `--authored`, mutuamente exclusivos, em `search-objects` e `list-by-type`; switches `-Generated`/`-Authored` no wrapper `.ps1`):

- `Query-KbIntelligenceIndex.ps1 -IndexPath <sqlite> -Query list-by-type -ObjectType WebPanel -Generated` — só gerados
- `Query-KbIntelligenceIndex.ps1 -IndexPath <sqlite> -Query list-by-type -ObjectType WebPanel -Authored` — só autorais

### Reverse lookup por instância (`-InstanceKey`)

`search-objects` aceita `-InstanceKey` (`--instance-key`) para listar os objetos gerados por uma instância WorkWithForWeb. O motor **auto-detecta** a forma do argumento (regra de contrato):

- **nome plano** da instância (ex.: `WorkWithWebVolume`) → correspondência **exata, ignorando caixa** (`casefold`) contra o `instance_name` derivado;
- **chave completa** `<GUID canônico 8-4-4-4-12>-<nome>` → correspondência **exata, ignorando caixa** (`LOWER` do SQLite) contra `instance_key`;
- `<GUID>-` sem nome → **erro** (chave incompleta); GUID puro sem hífen → cai em nome (nenhum objeto casa).

A correspondência é sempre **exata, nunca parcial** (`WorkWithWebFoo` não casa `WorkWithWebFooBar`). Combina com `-ObjectType`, `-Generated`/`-Authored` e `-Limit`; com `-ObjectName`, os dois filtros combinam em **AND**. `search-objects` passa a exigir **pelo menos um** entre `-ObjectName` e `-InstanceKey`. `-InstanceKey` **só** vale em `search-objects` (em outra consulta → erro `--instance-key is only valid with search-objects.`).

- `Query-KbIntelligenceIndex.ps1 -IndexPath <sqlite> -Query search-objects -InstanceKey WorkWithWebVolume` — objetos gerados pela instância (por nome)
- `Query-KbIntelligenceIndex.ps1 -IndexPath <sqlite> -Query search-objects -InstanceKey <GUID>-WorkWithWebVolume` — idem (por chave completa)

**Nota de caixa (ASCII):** a comparação sem caixa da **chave completa** usa `LOWER()` do SQLite (ASCII); a do **nome** usa `casefold()` do Python (Unicode). A diferença só importa para nome de instância não-ASCII — a convenção GeneXus é ASCII.

**Nota de desempenho:** no modo nome sem `-ObjectName`/`-ObjectType`, a consulta varre a tabela e deriva o nome de cada linha; o `-Limit` recorta **após** o filtro (não reduz a varredura).

## Triagem exploratoria no PowerShell

Use consultas curtas e auditaveis quando precisar medir massa de padrão antes de propor novo incremento. Em Windows, prefira etapas pequenas a um one-liner longo.

Ordem sugerida de triagem:

1. contar ocorrências brutas
2. agrupar por valor ou prefixo relevante
3. abrir amostra curta de casos reais positivos e negativos
4. medir quantos casos realmente resolvem contra o inventario local

Se um agrupamento ou regex retornar zero de forma inesperada, não concluir ausencia de sinal de imediato. Primeiro abra uma ocorrência real no XML da KB para conferir o formato efetivo da propriedade e só depois ajuste o extrator.

Depois de separar por prefixo, não tratar prefixo promissor como relacao resolvida. Antes de propor incremento, medir quantos casos daquele prefixo realmente apontam para objeto existente no inventario local. Prefixos textual ou semanticamente próximos, como `exo:` e `ext:`, podem ter comportamentos metodologicos diferentes e não devem ser fundidos por intuicao.

Contar ocorrências textuais de `ATTCUSTOMTYPE` no acervo:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE' |
  Measure-Object
```

Agrupar valores de `ATTCUSTOMTYPE` por prefixo observavel:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { ($_.Groups[1].Value -split ':', 2)[0].ToLower() } |
  Group-Object |
  Sort-Object Count -Descending
```

Abrir amostra curta de valores reais antes de decidir contrato:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { $_.Groups[1].Value } |
  Select-Object -First 30
```

Evitar:

- one-liner longo com muitas interpolacoes, `:` e subexpressoes na mesma linha
- decidir incremento novo apenas por ocorrência textual bruta
- pular da contagem direta para alteracao de contrato sem amostra real

## Buscar objetos por nome

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query search-objects `
  -ObjectName "*PlanilhaVolume*" `
  -Limit 10 `
  -Format text
```

## Localizar um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Format text
```

## Consultar atributo e gravabilidade transacional

Para consulta leve de atributo, sem varrer XMLs em massa:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query attribute-info `
  -ObjectName ClienteTotal `
  -Format text
```

Para listar atributos de uma Transaction com classificação **materializada** de gravabilidade (paridade com o gate; exige índice `schema_version>=2`):

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query transaction-writable-attributes `
  -ObjectName Cliente `
  -Format text
```

As consultas `transaction-attributes` e `transaction-writable-attributes` leem a classificação **materializada** no build (`transaction_attribute_writability`), com paridade obrigatória contra `Test-GeneXusTransactionWritability.ps1` (`Test-GeneXusKbIntelligenceWritabilityParity.ps1`). Esse gate e `Test-GeneXusNewWritableTargets.ps1` são fachadas PowerShell que delegam ao nucleo canonico `GeneXusTransactionWritabilityCore.py` via `GeneXusTransactionWritabilitySupport.ps1`. Atributos `unclassified-*` (`writable=null`) exigem leitura adicional do XML antes de `New` ou atribuicoes. Para validar assignments dentro de blocos `New` em `Procedure`, use `Test-GeneXusNewWritableTargets.ps1`.

As consultas `attribute-info`, `transaction-attributes` e `transaction-writable-attributes` dependem do `source_root` gravado no `index-metadata` e leem no disco os XMLs apontados pelo índice. Se o snapshot materializado foi movido, apagado ou regenerado fora desse caminho, a consulta pode falhar com `Indexed XML file not found`; nesse caso, restaurar o snapshot no caminho esperado ou regenerar o índice a partir do `ObjetosDaKbEmXml` atual antes de repetir a consulta.

## Validar consultas de atributo e gravabilidade transacional

Depois de gerar ou localizar um índice SQLite com `source_root` valido, snapshot materializado no caminho esperado e `schema_version>=2`, valide `attribute-info` (leve), `transaction-attributes` e `transaction-writable-attributes` (materializadas) com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-writability.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-writability.json" `
  -FailOnValidationFailure
```

Esses casos conferem dispatch, inexistencia e leitura file-backed pontual. `attribute-info` não substitui gates de gravabilidade. `transaction-writable-attributes` reflete classificação materializada com paridade ao gate, mas blocos `New` em `Procedure` ainda exigem `Test-GeneXusNewWritableTargets.ps1` antes de empacotar.

Como esses casos validam consultas e trazem `query`, eles pertencem ao executor `Test-KbIntelligenceQueries.ps1`, não ao fluxo de regeneracao via `Build-KbIntelligenceIndex.ps1`.

## Consultar quem usa um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query who-uses `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

## Consultar o que um objeto usa

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query what-uses `
  -ObjectType WebPanel `
  -ObjectName wpRelatoriosDeMovimentosDeVolumes `
  -Limit 10 `
  -Format text
```

## Consultar evidencia

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento `
  -Format text
```

## Triagem de impacto básico

O comando `impact-basic` resume dependentes diretos e dependencias diretas do objeto, ainda sem alterar o escopo de extracao.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

Para auditar uma relacao específica retornada por `impact-basic`, use `show-evidence`.

Essa consulta representa impacto técnico direto baseado no índice. Ela não prova impacto runtime completo.

## Triagem funcional básica

O comando `functional-trace-basic` monta uma trilha inicial para perguntas funcionais curtas:

- localiza o objeto principal
- combina dependentes e dependencias diretas
- prioriza objetos resolvidos e locais antes de literais `CustomType`
- oculta literais `CustomType` redundantes quando houver relacao resolvida equivalente na mesma linha
- indica XMLs oficiais que o agente deve abrir
- devolve trilha estruturada para resposta funcional curta

Ele não abre XML automaticamente, não interpreta regra de negocio e não substitui a leitura do XML oficial.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType Procedure `
  -ObjectName procAjustaCompraGadoIdDeAnimais `
  -Limit 20 `
  -Format text
```

## Catalogo e uso de classes CSS (`css-classes`, `css-class-usage`)

O índice cataloga as classes CSS da KB (tabela `css_class`) e rastreia onde são usadas (relacoes `uses_css_class` / `uses_css_class_dynamic` em `relations`/`evidence`), cobrindo as duas falhas de falso "não existe": o inventario incompleto (classes do `DesignSystem` não viram objeto) e o uso invisivel (atribuicao por código `Controle.Class = ...`, não só `class="..."` no layout).

Camada 1 — catalogo. `css_class` unifica os dois modelos de tema, com `model` (`legacy-theme` de objetos `ThemeClass` | `design-system` de SCSS em `DesignSystem`) e `origin` (`kb-authored` | `packaged-module` de libs importadas). `legacy-theme` e marcado `deprecated=true` (candidato a migracao para DesignSystem). A visao padrão lista só `kb-authored`; um lookup nominal (`-ObjectName`) **nunca** filtra origem, para não produzir falso "não existe" de classe importada.

```powershell
# catalogo autoral (kb-authored); use -IncludeImported ou -Origin packaged-module para libs
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query css-classes -Model design-system -Format text

# lookup de uma classe especifica (case-sensitive; acha tambem importada)
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query css-classes -ObjectName AttributeAvisos -Format text
```

Camada 2 — uso. `css-class-usage -ObjectName <classe>` lista os usos resolviveis (layout em `class`/`cellClass`/`rowClass`/`formClass`; código em `Controle.Class = "..." | 'A B' | StyleClass:x | ThemeClass:y`) com **localizador = objeto + snippet** (no layout tudo vem numa linha só, entao `line` e pouco útil). Sem `-ObjectName`, devolve um overview com os totais e a lista de classes **usadas mas não catalogadas** (cross-check da regra de ouro). A saida declara honestamente a cobertura: `dynamic_uses_total` conta as atribuicoes `.Class=` dinamicas (variável `&v` / `Format()`) que **não** são atribuiveis a uma classe por nome. `found_in_catalog=false` significa classe usada mas não catalogada (ex.: importada não varrida), **não** inexistente.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query css-class-usage -ObjectName AttributeAvisos -Format text
```

Salvaguarda: a tabela e acelerador de triagem com frescor por gate, não verdade exaustiva. Para operacao destrutiva (renomear/remover classe), conferir por busca literal no XML antes de agir.

## Validar consultas de impacto básico

Depois de gerar ou localizar um índice SQLite, valide o comportamento operacional de `impact-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-impact.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-impact.json" `
  -FailOnValidationFailure
```

Esses casos conferem comportamento de consulta. Eles não regeneram o índice nem substituem as baterias de extracao.

Escolha o executor pelo formato do caso. Casos com campo `query` pertencem a validação de consultas; casos com `source`, `target` e `expected_rule` pertencem a validação de extracao/geracao.

## Cuidado com validacoes SQLite no Windows

Depois de gerar um SQLite temporario novo, prefira executar validacoes em sequência contra esse arquivo. Evite rodar validacoes paralelas contra o mesmo banco recem-gerado.

Se houver necessidade real de paralelizar, use copias temporarias independentes do SQLite para cada validação.

Falhas transitorias de acesso, lock ou tabela ainda não visivel no Windows devem ser reexecutadas primeiro em sequência antes de serem tratadas como falha real de contrato ou regressao do índice.

## Validar inventario ampliado de tipos

Depois de regenerar o índice, valide a presenca de tipos ampliados com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-inventory-extended.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-inventory-extended.json" `
  -FailOnValidationFailure
```

Esses casos conferem inventario de objetos e comportamento conservador de `impact-basic` para tipos sem relacoes extraidas.

Cobertura mínima adicional recomendada para evitar falso verde de inventario:

- pelo menos um caso positivo de `Transaction` em `object-info`
- um caso de tipo com envelope próprio, como `Attribute`
- um caso de tipo recentemente acrescentado ao catalogo, quando houver

## Validar relacoes semanticas

Depois de regenerar o índice, valide a resolucao semantica aprovada com:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-semantic.json" `
  -FailOnValidationFailure
```

Esses casos conferem relacoes semanticas. Eles devem ser executados junto com as baterias de extracao quando houver rodada oficial.

Para validar especificamente a extracao de criacao de WebComponent por `<WebPanel>.Create(...)`, use a bateria dedicada da KB paralela que tiver esse caso real. Exemplo em FabricaBrasil:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-fabricabrasil-webcomponent-create.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-fabricabrasil-webcomponent-create-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.validation-extraction-webcomponent-create.json" `
  -FailOnValidationFailure
```

Essa bateria cobre `webpanel_dot_create` e deve ser tratada como validação de extracao/geracao, não como validação de consulta.

Self-test local (não depende de KBExemplo) para `Property Formula` em `Attribute`:

```powershell
.\scripts\Test-KbIntelligenceAttributeFormulaExtractionSelfTest.ps1
```

Self-test local (não depende de KBExemplo) para chamada de método em variável `exo:<ExternalObject>` e protecao contra falso positivo por substring em chamada direta de `Procedure`:

```powershell
.\scripts\Test-KbIntelligenceExternalObjectMethodExtractionSelfTest.ps1
```

Self-test local (não depende de KBExemplo) para o sinal determinístico gerado-por-Pattern (`IsGeneratedObject`/`PatternObjectId`/`InstanceKey`) na tabela `objects`, com guarda contra marcadores de `<Object>` aninhado em `PackagedModule` e o caminho de fallback regex para XML malformado:

```powershell
.\scripts\Test-KbIntelligenceGeneratedObjectExtractionSelfTest.ps1
```

Casos positivos de `Property Formula` em KBs de producao ficam catalogados em `kb-intelligence-kbexemplo.validation-extraction-semantic.json` (ids `phase5-case-65..68`) e em baterias dedicadas por KB: `kb-intelligence-fabricabrasil.validation-extraction-attribute-formula.json`, `kb-intelligence-wseducacaospteste.validation-extraction-attribute-formula.json`. Validar cada bateria no rebuild da pasta paralela correspondente; o arquivo semantic completo continua orientado ao KBExemplo e inclui esses casos apenas como catalogo compartilhado.

Esses casos usam `source`, `target` e `expected_rule`, entao devem rodar no gerador/indexador. Se forem enviados por engano para `Test-KbIntelligenceQueries.ps1`, o resultado deve ser tratado primeiro como executor incompativel, não como regressao real da regra.

## Validar triagem funcional básica

Depois de localizar ou regenerar o índice canonico, valide `functional-trace-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-functional-trace.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-functional-trace.json" `
  -FailOnValidationFailure
```

Esses casos conferem apenas a montagem da trilha funcional básica. Eles não provam comportamento runtime nem substituem leitura do XML oficial.

Como esses casos validam consultas e trazem `query`, eles pertencem ao executor `Test-KbIntelligenceQueries.ps1`, não ao fluxo de regeneracao via `Build-KbIntelligenceIndex.ps1`.

### Amostra de envelope XML (Properties vs Part)

- `scripts/Invoke-ParallelKbEnvelopeScan.ps1`: varre pastas paralelas com `ObjetosDaKbEmXml` sob `C:\Dev\Test` e `C:\Dev\Prod` (ou `-KbRoots` explicitos) e classifica amostra por tipo (`only_properties_in_sample`, `has_part_in_sample`, `absent`). Uso tipico antes de alterar `queryableByKbIntelligence` no catalogo.

## Saidas

- `json`: formato padrão para consumo por agentes e automacoes
- `text`: formato curto para leitura rápida em conversa ou terminal

## Regras de uso por agente

- consultar por `tipo + nome`, nunca apenas nome
- procurar primeiro por `KbIntelligence\kb-intelligence.sqlite` na pasta paralela da KB
- ignorar pastas `ArquivoMorto`, salvo pedido explicito do usuário para análise histórica
- tratar o SQLite como derivado e regeneravel
- manter o XML oficial como fonte normativa
- antes de alterar objeto GeneXus coberto pelo índice, executar `impact-basic` apenas quando o tipo tiver `queryableByKbIntelligence=true`; para tipos com flag `false`, usar `object-info` e leitura XML (o query semantico retorna exit `11`)
- tratar `impact-basic` como impacto técnico direto, não como prova funcional completa
- para perguntas funcionais curtas, `functional-trace-basic` pode reduzir a coleta inicial, mas a resposta final ainda deve separar `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- usar a linha e o `snippet` apenas como evidencia técnica, não como prova funcional completa
- quando a mudanca exigir semantica GeneXus, abrir o XML e revisar o `Source` efetivo
