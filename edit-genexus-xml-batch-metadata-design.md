# v10 — desenho de `Edit-GeneXusXmlBatchMetadata.ps1`

**VERSÃO CONGELADA.** A revisão por pares encerra aqui; a prova migra para a implementação e
os self-tests. Congelamento decidido pelo humano em 2026-09-13, após o parecer sobre a v9
concluir que *"a revisão de papel parou de render"* — não por abandono do ciclo.

## Estado da implementação — nota aditiva de 2026-09-14

Este bloco é **posterior ao congelamento** e existe porque o corpo abaixo não muda: ele foi
escrito antes da implementação e continua sendo o registro do que se decidiu, com o tempo
verbal do dia em que foi congelado. Quem lê o corpo lê o desenho; quem precisa do estado
atual lê aqui.

**Implementado em 2026-09-13/14.** O motor é
[`scripts/Edit-GeneXusXmlBatchMetadata.ps1`](scripts/Edit-GeneXusXmlBatchMetadata.ps1), com o
núcleo em `scripts/GeneXusXmlBatchMetadataSupport.ps1`, o roteiro de recuperação manual em
`scripts/Show-GeneXusXmlBatchMetadataRecoveryPlan.ps1` e os suportes entregues por esta
frente em `scripts/XpzAtomicTextWriteSupport.ps1` e `scripts/XpzProtectedAreaSupport.ps1`.
A bateria de contrato é `scripts/Test-EditGeneXusXmlBatchMetadataContract.ps1`, mais
`scripts/Test-GeneXusLastUpdateEngineOptionalBaselineSelfTest.ps1`.

**O dono normativo do contrato passou a ser [`xpz-builder/SKILL.md`](xpz-builder/SKILL.md)**
(com o satélite `xpz-builder/quality-checklist.md`); a regra operacional está em
`02-regras-operacionais-e-runtime.md` e o ponteiro de rastreabilidade em
`09-inventario-e-rastreabilidade-publica.md`. Este documento é o **racional**: ele explica
por que cada regra existe e guarda as medições e os dez pareceres que a produziram. Detalhe
de contrato que mudar depois desta data muda no dono, não aqui — documento congelado não
acompanha motor.

**Todos os entregáveis da §13.1 foram entregues**, incluindo a edição de
`Test-XpzParameterNamingContract.ps1` e a entrada de `checksum=""` em `999`. Em particular,
`-BaselineXmlPath` **já é opcional** em `Get-NewGeneXusLastUpdateValueFromEngine`: a frase
«Hoje é `Mandatory = $true`» na §13.1 descreve o estado em 2026-09-13, não uma pendência.
As citações ao `Mandatory` nas linhas do diagnóstico da v10 são narrativa histórica do erro
da v9 e continuam corretas.

**Correção factual à «Nota de custo» da §2.1.** O desenho afirma que um lote de 131 alvos
gera «131 arquivos e **131 invocações de processo**». A segunda metade é falsa:
`Get-NewGeneXusLastUpdateValueFromEngine` chama o motor com `& $enginePath`, que executa o
`.ps1` **no mesmo processo**. *(Medido em 2026-09-14: PID do chamador idêntico ao PID dentro
do script; 20 chamadas em 155 ms, ~8 ms cada — cerca de 1 segundo para as 131.)* O custo em
disco é real (131 arquivos de baseline sintético); o custo de processo não existe. A frente
própria que a §2.1 manda registrar continua valendo, com prioridade menor do que o texto
sugere, e está em `999-ideias-pendentes.md`.

**Decisões que o desenho não fechava e a implementação fechou** estão nos cabeçalhos dos
scripts e na entrada desta frente em `historico/IdeiasImplementadas_202609.md`: o código
`MANIFEST_SCHEMA_INVALID` acrescentado à §10, a leitura da regra de duplicidade por `guid`
que preserva a composição da §4, o escopo da âncora de documentação no próprio `<Part>`, a
recusa de contar âncora dentro de `CDATA`, o cálculo do `lastUpdate` na Fase 1b e o hard
link indeterminável como aviso declarado.

Consolidada após **dez pareceres de quatro famílias**: três sobre a v1 (openai/gpt-5.6-luna,
anthropic/claude-opus-5, opencode/big-pickle), um sobre a v2 (openai/gpt-5.6-luna), um
sobre a v3 (anthropic/claude-opus-5), um sobre a v4 (opencode/big-pickle), um sobre a v6
(opencode-go/deepseek-v4-pro), dois sobre a v7 e a v8 (opencode-go/qwen3.8-max) e um sobre
a v9 (anthropic/claude-opus-5). Origem das mudanças entre parênteses.

**Diagnóstico de encerramento** *(opus-5 v9)*: as costuras das três últimas versões eram
todas da mesma classe — *o desenho descrevia o contrato de uma função existente sem abrir o
arquivo dela*. Não era o desenho que vazava; era o procedimento de redigi-lo. A consequência
prática para quem implementar: **abra os arquivos citados antes de confiar em qualquer
descrição de contrato deste documento**, inclusive as da v10.

**A v6 não veio de parecer.** Ela corrigiu um defeito que uma **medição própria** encontrou
na v5, depois de todos os pareceres da época: a v5 supunha que a grafia qualificada de
referência a Domain fosse `Modulo.Nome`, e a forma real no acervo é `Nome, Modulo`. O erro
produziria falso negativo no scanner — exatamente a classe de falha que a §7 existe para
impedir. Ver §7 e o registro de medição ao final dela.

**A v7** fechou nove gaps do parecer sobre a v6, dos quais dois eram estruturais: a
composição dos três termos do `lastUpdate` não estava especificada (§2, D1), e a fonte da
pré-condição não estava separada da fonte da testemunha de divergência (§11).

**A v8** fecha nove gaps do parecer sobre a v7, **todos por contradição contra código
existente no repositório**. Dois deles tornavam o caso de uso principal inexequível:

- **a âncora da documentação estava fora do escopo declarado** (§6.0). O desenho confundia
  *tag raiz* com *elemento raiz*; o Part de documentação é **filho** de `<Object>`, então
  `setDocumentation` devolveria `ANCHOR_NOT_FOUND` sempre;
- **a composição dos baselines não era implementável** (§2.1). O motor recebe **caminho**,
  não valor.

Ambos vinham da mesma raiz: eu descrevia contratos de motores existentes sem conferir as
assinaturas. A v8 nomeia **funções** em vez de scripts (§6) e materializa o baseline em vez
de supor um parâmetro que não existe.

**A v9** fecha cinco costuras que **as próprias correções da v8 criaram** — padrão que se
repetiu em três versões seguidas e está registrado aqui para quem implementar não repeti-lo:

| Costura | Nasceu de | Fechada em |
|---|---|---|
| `EOL_MIXED` prometido sem detector capaz de disparar | correção P1-5 (v8) | §5.0 |
| patch global × âncora escopada — contar em B e gravar fora de B | correção P0-1 (v8) | §6.0 |
| `max` de strings sem parse, e reformatação duplicando o formato | correção P0-2 (v8) | §2.1 |
| limiar sobre a entrada, quando o envelope confere a saída | correção P1-4 (v8) | §9.1 |
| §14 listando como retirada uma recusa que a v8 restaurou | correção P1-6 (v8) | §14 |

As três primeiras eram **silenciosas**: bloqueio que nunca dispara, escrita no alvo errado e
comparação errada não aparecem em nenhum relatório. É a classe que a §1 existe para impedir.

**A v10** fecha quatro itens do parecer sobre a v9 — um deles sendo a repetição do próprio
padrão **dentro** da correção que o tabulava:

| Item | O quê | Onde |
|---|---|---|
| P1-1 | o ramo "ambos ausentes" era inexecutável: `Get-NewGeneXusLastUpdateValueFromEngine` declara `-BaselineXmlPath` **`Mandatory = $true`** | §2.1 |
| P1-2 | o chamador lia `lastUpdate` por regex sem `+` no charset — valor com offset virava "ausente" **em silêncio** | §2.1 |
| P1-4 | o payload de documentação vem de JSON com `\n` e criaria, em arquivo CRLF, o EOL misto que a ferramenta recusa | §5.0 / §6 |
| P1-5 | a varredura léxica contava `<Object` dentro de `CDATA` — **confirmado vivo em 2 arquivos reais** | §6.0 |

---

## 1. Tese (inalterada)

Separar a **declaração** do que se quer da **execução**, e obrigar a execução a conferir a
declaração contra a realidade do XML antes de tocar em disco. O manifesto é a análise
materializada; o motor é um executor desconfiado e auditável.

Caso concreto: numa frente real (schemas de CTe), 131 objetos foram editados por um script
descartável que operava por nome de arquivo, fazia no-op silencioso quando o atributo não
existia, escrevia documentação na primeira ocorrência de `<InnerHtml>` do arquivo inteiro,
gravava `UtcNow+90s` como `lastUpdate` para todos, gravava dentro do laço sem rollback e
esquecia `description=` no rename. Funcionou, e reportou `status = ok` em todos esses
cenários.

## 2. Decisões

| | Decisão | Estado |
|---|---|---|
| D1 | `lastUpdate` = `max(UtcNow + margem, acervo + margem, frente + margem)`, um bump por arquivo; **composição explícita** (§2.1); baseline anormalmente futuro é **aviso**, não bloqueio | corrigida na v5, **composição especificada na v7** |
| D2 | Guardas extraídos para `XpzProtectedAreaSupport.ps1`, mesmos nomes de função | mantida |
| D3 | `-InputPath` com alias `-ManifestPath`, validação precoce de `Kind`/`SchemaVersion` | mantida |
| D4′ | Referência encontrada bloqueia sempre; o motor gera a evidência; ambiguidade é fail-closed | **semânticas fechadas na v5** |
| D5″ | Degradação preexistente reportada; introduzida bloqueia; exceção por operação | mantida |
| D6 | Três operações; `setParent` só para Folder; Module recusado | mantida |
| D7′ | Testemunha é o acervo em `HEAD` contra `expected`, só em `objectState: existing` | **mecanismo especificado na v5** |

### 2.1 Composição dos baselines de `lastUpdate` *(deepseek v6, G1)*

`Get-GeneXusXpzLastUpdate.ps1` e `Set-GeneXusXmlLastUpdate.ps1` aceitam **um** baseline e
computam `max(UtcNow + margem, baseline + margem)`. A D1 exige **três** termos. A v6 dizia
"calculado pelo motor existente" sem dizer quem compõe — e essa omissão é exatamente por
onde a regressão da v2/v3 entrou (passar só o acervo e perder o termo da frente).

**Correção da v8** *(qwen v7, P0-2)*: a v7 dizia "repassa `baselineEfetivo` como baseline
único ao motor". **O motor não aceita valor — aceita caminho.**
`Get-GeneXusXpzLastUpdate.ps1` expõe `-Count`, `-BaselineXmlPath`,
`-FreshnessMarginSeconds`, `-AsJson`; não há parâmetro de valor, e o leitor interno lê o
atributo do **arquivo**. A regra da v7 era inexecutável.

Regra explícita da v8:

1. O **chamador** lê os dois `lastUpdate` com `Get-FirstObjectLastUpdateFromText`, função do
   suporte dot-sourceável `GeneXusXmlSurgicalEditSupport.ps1` — **não** com
   `Read-GeneXusLastUpdate`, que é script-local dentro de um script executável (dot-sourcê-lo
   executaria o corpo e emitiria timestamp no stdout). A leitura é validada pela regra de
   intervalo da tag raiz (§6.0).
2. **Leitura por DOM, não por regex** *(opus-5 v9, P1-2)*. A v9 mandava ler com
   `Get-FirstObjectLastUpdateFromText`, cujo padrão é `lastUpdate="([0-9T:.\-Z]+)"` — charset
   **sem `+`**. Um valor com offset (`+03:00`), que a §6 admite, não casaria, a função
   devolveria `$null`, e o ramo trataria como **ausente**: o termo de baseline seria
   descartado em silêncio e o carimbo gravado poderia ficar **abaixo** do valor real do
   acervo. A §6 já reconhecia esse furo para a **escrita**; na **leitura** ele continuava
   aberto.

   Regra da v10: o chamador já faz parse real na Fase 1a — lê
   `DocumentElement.GetAttribute('lastUpdate')` ali, **a mesma semântica do motor**. Isso
   elimina o charset, elimina o "primeira ocorrência global" e dispensa validar o índice
   contra o intervalo da tag raiz **para os baselines** (a validação continua valendo para a
   escrita). Valor presente porém não parseável → `LASTUPDATE_UNREADABLE`, **distinto de
   ausente**.

   **Parse-then-compare**: parsear ambos com `DateTimeOffset` (`AssumeUniversal`), comparar
   os instantes, guardar **qual venceu**.
   - Ambos presentes → vence o instante maior.
   - Só um presente → esse.
   - **Ambos ausentes** → ver o ramo abaixo (§2.1-bis), que a v9 especificava de forma
     inexecutável.

   **§2.1-bis — o ramo sem baseline** *(opus-5 v9, P1-1)*. A v9 dizia "chamar o motor **sem**
   `-BaselineXmlPath`". Inexecutável pela função que a tabela de reuso nomeia:
   `Get-NewGeneXusLastUpdateValueFromEngine` declara o parâmetro
   **`[Parameter(Mandatory = $true)]`**. Foi a repetição, dentro da correção da v9, do
   mesmo padrão que a v9 tabula — descrever contrato sem abrir o arquivo.

   Rota escolhida: **tornar `-BaselineXmlPath` opcional na função**, com o comportamento
   herdado do script que ela chama (`Get-GeneXusXpzLastUpdate.ps1` já o aceita opcional).
   Isso vira entregável na §13.1, com self-test próprio. A alternativa — invocar o script
   diretamente nesse ramo — deixaria o motor com duas portas de entrada e contraria a
   disciplina de nomear funções.
3. **Materializa um XML de baseline sintético** em `-WorkDir` e chama o motor com
   `-BaselineXmlPath` apontando para ele. O sintético recebe a **string original do
   vencedor**, verbatim — nunca uma reformatação do `DateTimeOffset` parseado. *(qwen v8,
   P2-A)* Reformatar duplicaria a string de formato no chamador, que é exatamente o motivo
   pelo qual a alternativa "calcular no chamador" foi rejeitada acima. O motor continua
   sendo a **única** fonte da fórmula, do formato e da leitura de `UtcNow`.

   Nome do sintético: `<runId>.<opIdOuGuidDoAlvo>.baseline.xml` em `-WorkDir` — um por alvo,
   inventariado e coberto por `ARTIFACT_PATH_COLLISION`. *(qwen v8, P3)* **Nota de custo**:
   um lote de 131 alvos gera 131 arquivos e 131 invocações de processo, só para transportar
   um valor que o chamador já tem em memória. É aceitável para o caso de uso, e a
   justificativa (o motor como única fonte da fórmula) se sustenta — **mas isto é um
   workaround, não o desenho preferido**. A saída limpa é expor a composição como função
   dot-sourceável do motor, e isso é **frente própria**, a registrar em `999`. *(opus-5 v9, P2)*

Por que não as alternativas: chamar o motor duas vezes (uma por caminho) e tomar o max das
saídas é matematicamente igual, mas **cada chamada lê o próprio `UtcNow`** e o formato tem
resolução de segundo — o teste das duas ordens ficaria *flaky* na fronteira de segundo, e
não há injeção de relógio no motor. Calcular no chamador duplicaria a string de formato e
derrotaria o propósito do reuso.

**O baseline sintético é uma quarta classe de artefato** e entra no inventário do `-WorkDir`
e no escopo de `ARTIFACT_PATH_COLLISION` (§5), que a v7 declarava cobrir "os três".

O motor permanece intocado; a composição é responsabilidade declarada do chamador. Teste
obrigatório: fixar `acervo > frente` e `frente > acervo` e exigir o **mesmo** resultado nas
duas ordens, além do caso em que ambos estão no passado e `UtcNow` domina.

## 3. Superfície

```
Edit-GeneXusXmlBatchMetadata.ps1
  -InputPath <manifesto.json>        (alias -ManifestPath)
  -FrontFolder <frente canônica>
  [-AcervoPath <ObjetosDaKbEmXml>]   (default: convenção <RepoRoot>/ObjetosDaKbEmXml)
  [-WorkDir <dir>]                   (default: <RepoRoot>/Temp/xpz-batch-metadata/<NomeDaFrente>)
  [-Apply]
  [-ReportPath <absoluto.json>]
  [-AcknowledgeReferences]
  [-RequireHeadWitness]
  [-AllowDegradedAccents]
```

`-WorkDir` é **estável por frente**, não por execução — o lock precisa de local compartilhado
para que dois processos se enxerguem (§5). Default declarado acima; `Temp/` é a pasta
descartável canônica da pasta paralela. *(big-pickle v4, P2-9 e P1-5)*

JSON de máquina no stdout por padrão, sempre — inclusive quando a gravação do
`-ReportPath` falhar.

**Nomenclatura:** `-AcervoPath` segue a família de empacotamento/drift. A divergência
`-AcervoPath` / `-AcervoFolder` / `-CorpusFolder` é pré-existente, **não tem gate**, e está
registrada em `999:3157-3183`; esta frente não a resolve.

**O alias `-Path` tem gate, e a v7 silenciava sobre ele** *(qwen v7, P2-7)*.
`Test-XpzParameterNamingContract.ps1` assere "entrada primária simples: `-InputPath` com
alias `-Path`" sobre uma lista que inclui os dois irmãos mais próximos deste motor —
`Edit-GeneXusXmlSurgical.ps1` e `Set-GeneXusXmlLastUpdate.ps1`, ambos com `[Alias('Path')]`.
Decisão da v8: o parâmetro é `[Alias('Path','ManifestPath')]` e o script **entra na lista**
do contrato nesta frente. Ressalva semântica registrada: aqui `-InputPath` é um **manifesto
JSON**, não um XML — `-Path` é alias de consistência de família, não descritivo.

## 4. Manifesto

Schema estrito por operação. `objectState` obrigatório. `null` = atributo **ausente**;
`""` = presente com valor vazio. Para `documentation` (conteúdo de Part): `null` = Part sem
`<InnerHtml>`; `""` = `<InnerHtml>` com CDATA vazio.

```json
{
  "Kind": "xpz-batch-metadata-manifest",
  "SchemaVersion": 1,
  "operations": [
    { "id": "op-001", "op": "setDocumentation", "objectState": "existing",
      "target": { "guid": "...", "expectedType": "SDT", "expectedName": "CTe_duto", "xmlPath": "CTe_duto.xml" },
      "expected": { "documentation": null },
      "new": { "documentation": "Os Soap Types deste SDT..." },
      "allowDegradedAccents": false },

    { "id": "op-002", "op": "setParent", "objectState": "existing",
      "target": { "guid": "...", "expectedType": "SDT", "expectedName": "CTe_endereco", "xmlPath": "CTe_endereco.xml" },
      "expected": { "parent": "leiauteCTe", "parentGuid": "47fd5bd9-...", "parentType": "0000...0008" },
      "new":      { "parent": "CTe",        "parentGuid": "aaaa...",      "parentType": "0000...0008" } },

    { "id": "op-003", "op": "setParent", "objectState": "new",
      "target": { "guid": "...", "expectedType": "SDT", "expectedName": "CTe_evNovo", "xmlPath": "CTe_evNovo.xml" },
      "recommendedDestination": { "parent": "leiauteEventoCTe", "parentGuid": "9c374374-...", "parentType": "0000...0008" } },

    { "id": "op-004", "op": "renameDomain", "objectState": "existing",
      "target": { "guid": "...", "expectedType": "Domain", "expectedName": "CTe_TRBSN", "xmlPath": "CTe_TRBSN.xml" },
      "expected": { "name": "CTe_TRBSN", "fullyQualifiedName": "CTe_TRBSN",
                    "propertyName": "CTe_TRBSN", "description": "CTe_TRBSN" },
      "new": { "name": "SemUso_CTe_TRBSN" },
      "renameFile": true,
      "unusedEvidence": { "source": "kb-intelligence", "query": "what-uses CTe_TRBSN",
                          "result": "0 dependentes", "statedBy": "humano" } }
  ]
}
```

Regras de schema, todas fail-closed:

- `guid` obrigatório e conferido em toda operação, `renameDomain` inclusive.
- `expected` obrigatório em `existing`, proibido em `new`.
- **`objectState: new` exige ausência do GUID e do nome no acervo** → `NEW_OBJECT_EXISTS_IN_ACERVO`.
  Sem isso, "declarado novo mas existe homônimo no acervo" ficava sem sanidade. *(big-pickle v4, P2-12)*
- **`objectState: new` com `lastUpdate` acima de `UtcNow + 120s`** → `NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE`
  (§9). *(qwen v7, P1-4)* **Correção de citação:** a v7 declarava paridade com o
  `NewObjectPolicy` (default `warn`) de `Build-GeneXusImportFileEnvelope.ps1`. Era a metade
  errada do código — `warn` cobre `baseline-missing`; o caso relevante aqui é
  `baseline-missing-too-far-in-future`, nas **linhas 417-421**, que aplica `fail`
  **incondicionalmente**, depois do ramo de política e sobrescrevendo-o.
- `recommendedDestination` é o valor efetivamente gravado.
- `renameDomain` com `objectState: new` proibido.
- `renameFile` obrigatório em `renameDomain`; `false` exige justificativa registrada.
- Duplicidade por `xmlPath`: bloqueia entre operações do mesmo tipo. Duplicidade por
  `guid`: bloqueia **globalmente**.
- `expectedType` resolvido contra `gx-object-type-catalog.json`.
- Chaves JSON duplicadas bloqueiam; `Kind`/`SchemaVersion` inesperados bloqueiam antes de tudo.
- `allowDegradedAccents` só é aceita quando `-AllowDegradedAccents` foi passado.

### Composição

Ordem determinística `setDocumentation` → `setParent` → `renameDomain`; re-âncora sobre o
texto intermediário em memória; `lastUpdate` bumpado uma vez por arquivo ao final;
validação final confere a união das pós-condições; detecção de ciclo sobre a composição
inteira.

## 5. Execução

### 5.0 Detecção de EOL — detector próprio, não o suporte existente *(qwen v8, P1-A)*

A v8 criticou `XpzTextFileEolSupport.ps1` por **normalizar** EOL misto e, na frase seguinte,
nomeou `Get-TextFileLineContext` como o detector de `EOL_MIXED`. Contradição: essa função
computa `$eolSequence = if ($raw -match "\r\n") { "\r\n" } else { "\n" }` — um único CRLF
declara o arquivo inteiro CRLF — e devolve **um** `EolSequence` mais `Lines` já splitadas.
Não expõe separador por linha nem flag de misto. Não há outro detector de EOL misto no
repositório. O resultado seria um **bloqueio que nunca dispara**: arquivo misto passaria
como CRLF puro.

Regra da v9, com papéis separados:

| Papel | Mecanismo |
|---|---|
| **detectar EOL misto** | varredura própria do texto bruto: coexistência de `\r\n` com `\n` ou `\r` soltos → `EOL_MIXED` na Fase 0 |
| **EOL das linhas novas** inseridas pelo motor | `Get-TextFileLineContext`, usado **só** para isso |
| **gravação** | texto bruto pelo escritor atômico; nunca `-join` de linhas |

Consequência de vocabulário: se misto é recusado, não existe "EOL dominante" — existe **o**
EOL do arquivo.

**Medição do `EOL_MIXED`** *(opus-5 v9, P1-3)*. O revisor apontou, com razão, que este era o
**único** bloqueio da família congelado sem medição, e levantou a hipótese de que o GeneXus
gravasse estrutura em CRLF e conteúdo de CDATA em LF — caso em que a maioria do acervo seria
mista e o gate tornaria a ferramenta inútil. *(Medido: 15.149 XMLs do acervo — **15.149 CRLF
puro**, zero LF puro, zero mistos.)* A hipótese não se confirma. `EOL_MIXED` fica como gate
defensivo contra arquivo vindo de fora do fluxo oficial, não como obstáculo ao caso de uso —
o simétrico do que aconteceu com o `LASTUPDATE_BASELINE_IMPLAUSIBLE` da v4, e desta vez
medido antes de congelar.

**EOL do payload de documentação** *(opus-5 v9, P1-4)*. O texto de `new.documentation` vem de
um manifesto **JSON** e naturalmente carrega `\n`. Inserido num arquivo CRLF, produziria o
EOL misto que a própria ferramenta recusa na rodada seguinte. Regra: o payload é
**normalizado para o EOL do arquivo** antes da inserção; `\r` solto no payload é **recusado**
(`PAYLOAD_EOL_INVALID`), não normalizado em silêncio.

Nota adjacente, que vale para a verificação da pós-condição: o parser XML **normaliza fim de
linha em CDATA na leitura**, então comparar texto reparseado não devolve os bytes gravados.
A comparação de identidade de bytes tem de ser sobre o **texto bruto**.

### Fase 0 — preparação

- `-FrontFolder` canônica sob `ObjetosGeradosParaImportacaoNaKbNoGenexus` →
  `FRONT_NOT_CANONICAL`. Reparse point recusado em todos os ancestrais.
- Journal, `.bak` e temporários de escrita ficam em `-WorkDir`, **fora da frente**.
  `ARTIFACT_PATH_COLLISION` cobre os três.
- **Lock** em `-WorkDir` (local estável por frente), conteúdo `{pid, runId, startedAtUtc}`.
  Lock com PID morto é **reaproveitável com aviso registrado** (`staleLockReclaimed`); lock
  com PID vivo → `RUN_LOCKED`. Sem `-Apply`, o lock é adquirido e liberado sem deixar
  artefato persistente. *(big-pickle v4, P1-5)*
- Por alvo: existe, é gravável, não é hard link, está dentro da frente.
- Encoding por sniff de BOM; BOM ou não-UTF8 limpa → `ENCODING_UNEXPECTED`.

### Fase 1a — plano (nenhuma escrita persistente)

- `<Object>` raiz por parse real; mais de um candidato → `MULTIPLE_OBJECT_ROOTS`.
- Identidade conferida; invariantes estruturais mínimos.
- Precondições contra a frente e contra o acervo em `HEAD` (D7′).
- Varredura de referências (§7).
- Âncoras limitadas ao intervalo léxico exato da tag raiz (§6).
- Patches em memória; well-formedness e pós-condições validadas.
- `lastUpdate` calculado pelo motor existente.
- Registro de todas as dependências: hash dos alvos, hash dos arquivos do acervo
  consultados, hash dos arquivos varridos, commit de `HEAD`, existência dos destinos,
  estado do grafo de pais.

Sem `-Apply`, termina aqui, sem artefato persistente em lugar nenhum.

### Fase 1b — materialização da recuperação (só com `-Apply`)

Journal durável, `.bak` e baseline sintético (§2.1), todos em `-WorkDir`. `.bak` preexistente
do mesmo alvo → `BAK_EXISTS`.

**`BAK_EXISTS` também varre a frente** *(qwen v7, P1-3, derivado)*: os motores irmãos
(`Set-GeneXusXmlLastUpdate.ps1`, `Invoke-GeneXusXmlSurgicalEditCore`) deixam `.bak`
**dentro da frente**, e as duas convenções coexistem. Um `.bak` órfão de rodada anterior de
outro motor não dispararia nada e não apareceria no relatório. A Fase 1b procura nos dois
lugares e reporta o que achar.

Escreve em disco, mas não altera conteúdo de alvo.

**Schema do registro de passo** (parte do entregável, não promessa): cada passo grava
`{seq, opId, action, state: started|committed, pathBefore, pathAfter, bakPath, hashBefore,
hashAfter, atUtc}`. `started` sem `committed` correspondente é a marca de interrupção.

`pathBefore`/`pathAfter` foram acrescentados na v7 *(deepseek v6, G9)*: a v6 tinha só um
campo `target`, ambíguo sobre qual dos dois nomes ele carregava — e sem o mapeamento
antes↔depois a recuperação manual **não consegue** desfazer renomes em ordem inversa. Como
a §14 usa a recuperabilidade do rename como pilar da recusa de adiá-lo, o schema incompleto
era o elo fraco daquela justificativa.

O entregável inclui o **roteiro de recuperação manual** que lê o journal e diz o que
restaurar. *(big-pickle v4, P2-13)*

### Fase 2 — aplicação

- Reconferência global das dependências no início → `PLAN_STALE`.
- **Por arquivo, imediatamente antes do move**: reler o alvo, conferir o hash →
  `SOURCE_CHANGED`, **e reconferir que não virou hard link** → `HARDLINK_REFUSED`. A Fase 0
  já recusa hard link, mas a janela entre as fases é admitida por construção, e a recusa de
  hard link é **condição da técnica** do move (§5, garantia) — conferir só na Fase 0
  deixaria a condição sem verificação no momento em que ela importa. *(deepseek v6, G8)*
  O registro `started` do journal é gravado **a partir dessa releitura**, nunca do plano da
  1a — senão a recuperação manual restauraria um estado que não era o real. *(big-pickle v4, P1-3)*
- **Janela remanescente declarada**: entre reler e mover existe um intervalo que nenhum
  mecanismo deste desenho fecha. É aceita por construção; o lock não protege contra a IDE
  nem contra outro processo.
- Escrita em temporário validado, seguida de `File.Move` com replace.
- Mesmo encoding (constante por construção, §6); EOL dominante preservado.
- Renomes por último, cada passo registrado antes e depois.

### Falha

Desfazer renomes em ordem inversa, depois restaurar os `.bak`. A restauração continua mesmo
se um item falhar; status por item. Hash do restaurado conferido contra o `.bak`. Falha na
restauração → `ROLLBACK_INCOMPLETE`, exit code distinto, lista dos `.bak` remanescentes,
proibição de apagá-los.

**Aborto após a Fase 1b** (ex.: `PLAN_STALE` ou `SOURCE_CHANGED` antes de qualquer move):
journal e `.bak` são **preservados** e o relatório os lista. São a evidência de que a rodada
chegou a materializar recuperação; apagá-los automaticamente destruiria o rastro. A limpeza
é ação explícita posterior. *(big-pickle v4, P2-11)*

### Garantia

> **Rollback best-effort com recuperação manual após interrupção.** O rollback automático
> cobre falhas capturadas **e verificadas**. Morte do processo, queda de energia ou falha de
> I/O durante a restauração deixam estado recuperável manualmente pelo journal e pelos
> `.bak`. O relatório distingue `rollbackComplete`, `rollbackIncomplete` e
> `partiallyApplied`; `rollbackComplete` significa exclusivamente "falha capturada e
> rollback verificado".

`File.Move` com replace é atômico quanto à **visibilidade do nome** no mesmo volume; não há
fsync de diretório, então não é durável contra queda de energia no instante do move — essa
durabilidade é coberta pelo journal e pelos `.bak`. O move substitui metadados do arquivo
pelos do temporário, e por isso a **recusa de hard link é condição da técnica**.

**Journal é superset do relatório**, que só nasce ao final.

## 6. Mutações autorizadas, âncoras e reuso

### 6.0 Dois escopos nomeados *(qwen v7, P0-1)*

A v7 tinha uma contradição que tornava o caso de uso principal inexequível: dizia que a
escrita é "por índice ordinal **dentro do intervalo da tag raiz**" e, ao mesmo tempo, que a
âncora de `setDocumentation` é o Part `babf62c5-…` "no escopo do `<Object>` raiz". Não é a
mesma coisa — o Part é **elemento filho**, e a tag raiz já fechou no `>` muitos bytes antes.
Ao pé da letra, `setDocumentation` devolveria `ANCHOR_NOT_FOUND` **sempre**.

Dois escopos, nomeados e distintos:

| Escopo | Extensão | Usado por |
|---|---|---|
| **A — intervalo da tag raiz** | de `<Object` até o `>` que a fecha | micro-patch de atributos: `setParent`, `@name`/`@fullyQualifiedName`/`@description` do rename, `lastUpdate` |
| **B — conteúdo do elemento raiz** | do `>` da tag raiz até `</Object>` correspondente, **excluindo** subárvores `<Object>` aninhadas | Part de documentação (`setDocumentation`) |

**Como A e B são obtidos, e como o patch fica dentro deles** *(qwen v8, P1-B)*

A v8 dizia "parse delimita A e B" e, ao mesmo tempo, que `setDocumentation` "reusa apenas o
primitivo `Invoke-GeneXusXmlLiteralPatch`". Duas imprecisões que juntas produzem escrita
silenciosa no alvo errado:

- `XmlDocument` **não fornece offset de byte**; parse valida e confirma a estrutura, mas não
  delimita intervalo para escrita ordinal;
- `Invoke-GeneXusXmlLiteralPatch` faz `$Text.IndexOf($Anchor, Ordinal)` — **primeira
  ocorrência no texto inteiro**, sem parâmetro de escopo ou offset. Contar a âncora em **B** e
  aplicar o patch globalmente pode **contar uma ocorrência e gravar outra**, num `<Object>`
  aninhado. A própria medição da v8 mostra que há arquivos onde a primeira ocorrência global
  está fora de B (`PackagedModule\GeneXus.xml`, 248 Parts).

Regra da v9:

1. **A e B são intervalos de byte do texto bruto**, obtidos por **varredura léxica com
   controle de profundidade** — não por parse. A varredura respeita aspas ao procurar o `>`
   que fecha a tag raiz, e conta abertura/fechamento de `<Object` para excluir subárvores
   aninhadas de B.

   **A varredura pula regiões não-markup antes de contar profundidade** *(opus-5 v9, P1-5)*:
   `<![CDATA[ … ]]>`, comentários `<!-- … -->` e instruções de processamento. Sem isso, um
   `<Object` literal dentro de `<Source>` desbalanceia a contagem e mutila o intervalo **B** —
   âncora contada no escopo errado, que é a falha silenciosa que a §6.0 veio fechar.

   *(Medido: em 15.149 XMLs do acervo, **2 arquivos** têm `<Object` dentro de CDATA —
   `Dashboard\GAM_ActivityDashboard.xml` (`<Object ElementId="5" ControlName="NewUsers"…`) e
   `PatternSettings\WorkWith.xml` (`<Objects />`); zero em comentários. **Correção de uma
   medição anterior**: `GAM_ActivityDashboard.xml` foi usado como exemplo da medição "23
   arquivos com mais de um `<Object>`" — as ocorrências extras dele estão em CDATA, não são
   objetos aninhados reais. O perigo é vivo.)*
2. O parse (`Test-GeneXusXmlWellFormed` e leitura estrutural) **valida**; não delimita.
3. O primitivo é chamado sobre a **substring do escopo**, e o resultado é rejuntado ao texto
   completo pelos offsets. Alternativa equivalente: um patch escopado próprio. O que **não**
   é aceito é chamar o primitivo sobre o texto inteiro quando a âncora é de escopo B.
4. A contagem da âncora e a aplicação do patch ocorrem **no mesmo escopo**. Divergência entre
   o escopo contado e o escopo gravado é erro de implementação que o teste adversarial
   (§13.2) deve pegar.

Busca global permanece proibida, e agora o mecanismo que a tornaria possível está fechado.

**Consequência para a pós-condição:** como B está fora de A, a identidade de bytes tem
escopo de **documento inteiro** — byte-idêntico fora da união dos intervalos mutados, com
`lastUpdate` como única exceção global. É o que a §6 já dizia; agora está coerente com o
escopo das âncoras.

**Consequência para `ANCHOR_AMBIGUOUS`:** a contagem do Part é feita em **B**, não no
arquivo inteiro. A distinção não é acadêmica — *(Medido: 10 arquivos do acervo têm mais de
um Part `babf62c5`; `PackagedModule\GeneXus.xml` tem 248.)* Se a contagem fosse no arquivo,
esses 10 seriam inoperáveis; contando em B, cada um tem exatamente 1 e a operação procede.
As duas leituras dão comportamento **oposto** nos arquivos que a própria medição cita.

### Mutações autorizadas

| Alvo | Regra |
|---|---|
| atributo alvo da operação | alterado conforme o manifesto |
| conteúdo do Part de documentação | alterado conforme o manifesto |
| `lastUpdate` | alteração única por arquivo, calculada (D1) |
| `checksum` | preservado como está (intervalo nulo), com aviso |
| `description` em `renameDomain` | condicional; quando preservado por divergência, o resultado **não** é `ok` puro |
| **todo o resto do documento** | **byte-idêntico fora dos intervalos declarados** |

A verificação publica o **conjunto exato de intervalos mutados por operação**, incluindo os
pontos de inserção do `setParent`, a exceção do `description` preservado e o `checksum`
como intervalo nulo. O teste de escala é o veículo dessa verificação. *(big-pickle v4)*

### Exceção declarada à regra de âncora

O bump de `lastUpdate` reusa `Set-FirstObjectLastUpdateInText`, que procura a **primeira
ocorrência** de `lastUpdate="` no texto inteiro — uma busca global, contrária à regra acima.

A v6 justificava a exceção por precedência lexical (a raiz vem antes de qualquer `<Object>`
aninhado). **A v7 troca o argumento por uma verificação** *(deepseek v6, G3)*: o índice da
ocorrência encontrada precisa cair **dentro do intervalo da tag raiz**, que a Fase 1a já
delimita; se não cair, `LASTUPDATE_TARGET_OUTSIDE_ROOT`. O argumento anterior tinha um furo:
o padrão do motor é `lastUpdate="([0-9T:.\-Z]+)"` e a classe de caracteres **não inclui
`+`**, então um valor com offset (`+03:00`) não casaria na raiz e a busca acharia um
`<Object>` aninhado com valor válido — escrita no alvo errado, em silêncio.

*(Medido: em 15.149 XMLs do acervo, o padrão estrito casa a primeira ocorrência em todos;
nenhum `lastUpdate` vazio; os 11 valores atípicos são `Folder` com
`0001-01-01T00:00:00.0000000`, que o padrão casa. O furo é latente, não observado — mas
verificar o índice custa menos que sustentar o argumento.)* *(big-pickle v4, P1-4)*

### Reuso de ativos existentes

**A tabela nomeia funções, não scripts** *(qwen v7, P1-3)*. A v7 nomeava
`Set-GeneXusXmlLastUpdate.ps1` — um **gravador** cuja disciplina é incompatível com a §5:
`.bak` em `"$resolvedOutput.bak"` (**dentro da frente**), `WriteAllText` direto (**não
atômico**), **apaga** o `.bak` no sucesso, e tem well-formedness e rollback próprios,
concorrentes com o journal. O mesmo vale para `Invoke-GeneXusXmlSurgicalEditCore`, que tem
`.bak` intra-frente e escrita não atômica idênticos. A prosa restringia corretamente; a
**tabela** não — e é a tabela que o implementador lê.

| Peça | Função reusada |
|---|---|
| cálculo de `lastUpdate` | `Get-NewGeneXusLastUpdateValueFromEngine` (que chama `Get-GeneXusXpzLastUpdate.ps1`) |
| leitura de `lastUpdate` | `Get-FirstObjectLastUpdateFromText` |
| gravação de `lastUpdate` no texto | `Set-FirstObjectLastUpdateInText` |
| patch literal ordinal | `Invoke-GeneXusXmlLiteralPatch` |
| well-formedness | `Test-GeneXusXmlWellFormed` |
| UTF-8 sem BOM | `Get-Utf8NoBomEncoding` |
| detecção de EOL | `Get-TextFileLineContext` (**detecção apenas** — §5) |
| escrita atômica | `Write-XpzTextFileAtomic` (entregue por esta frente — ver abaixo) |
| vocabulário de acentuação | `ptbr-accent-wordlist.json` |
| guardas de caminho | `XpzProtectedAreaSupport.ps1` (extraído — D2) |
| catálogo de tipos | `gx-object-type-catalog.json` |

**Compatibilidade da extração D2** *(deepseek v6, G4)*: "mesmos nomes de função" não bastava
— se a extração **remover** as funções do arquivo original, o consumidor quebra.
Inventário de consumidores em `scripts/`: **um**, `New-XpzImportPackage.ps1:71`, que
dot-sourceia `XpzExecutionReportSupport.ps1` e usa `Test-XpzReportPathSafety`, dependente de
`Test-XpzPathEqualOrUnder` e `Get-XpzReparsePointInPath`. Regra: `XpzExecutionReportSupport.ps1`
passa a **dot-sourcear** `XpzProtectedAreaSupport.ps1` e continua expondo as mesmas funções;
nenhum consumidor migra nesta frente. `Test-NewXpzImportPackageObservabilitySelfTest.ps1`
entra na bateria obrigatória como prova de não-regressão.

**`Write-XpzTextFileAtomic` volta — por localização, não por encoding.** *(qwen v7, P1-6)*

A v4 o entregava justificado por "mesmo encoding detectado na leitura"; a v5 o descartou
porque a Fase 0 recusa BOM e não-UTF8, logo o encoding é constante por construção. **O
argumento de encoding continua correto** — `Write-XpzReportFileAtomic` já grava UTF-8 sem
BOM. Mas encoding não era o único motivo, e o que sobrou derruba o descarte:

- o helper existente cria o temporário **ao lado do destino**
  (`"$Path.tmp.$PID.<guid>"`) — para um alvo da frente, isso é **dentro da frente**,
  contradizendo a promessa da §5 de que temporários vivem em `-WorkDir`;
- sem `-ReplaceExisting`, o `File.Move` **falha** quando o destino existe — e **todo** alvo
  do lote já existe. O desenho nunca mencionava o switch.

`Write-XpzTextFileAtomic` é entregue em forma estreita: recebe `-TempDir` (apontando para
`-WorkDir`), grava, valida e substitui com replace. `Write-XpzReportFileAtomic` permanece
intocado para o relatório de empacotamento; nenhum consumidor existente migra.

**Limite do reuso de EOL** *(qwen v7, P1-5)*: `XpzTextFileEolSupport.ps1` **normaliza**, não
preserva — `$eolSequence = if ($raw -match "\r\n") { "\r\n" } else { "\n" }` faz **um único**
CRLF declarar o arquivo inteiro como CRLF, e o `-join` rejunta **todas** as linhas com esse
EOL, mudando bytes em cada linha que era só-LF. Isso violaria a identidade de bytes e
tornaria ambígua a asserção "zero hashes alterados". Regra da v8: o suporte é usado **só
para detecção** (`Get-TextFileLineContext`); a gravação é **texto bruto** pelo escritor
atômico, sem nunca rejuntar linhas; e arquivo de **EOL misto** é recusado na Fase 0 com
`EOL_MIXED`, em vez de normalizado em silêncio. Linhas novas inseridas pelo motor usam o EOL
dominante detectado.

**Limite do reuso de acentuação:** `Measure-PtBrAccentDegradation.ps1` opera sobre
`git ls-files` em `.md`/`.ps1`; XML não entra nesse escopo. Reusa-se a **wordlist e a
taxonomia**, não o script. Mojibake entra como segunda classe sobre o mesmo vocabulário.

### Âncoras

**`setDocumentation`** — âncora `<Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">` no
**escopo B** (§6.0). Contagem **0** → `ANCHOR_NOT_FOUND`; contagem **>1** →
`ANCHOR_AMBIGUOUS`. Ausência não é ambiguidade. *(big-pickle v4, P2-8)*

**A inserção `null → texto` é o caminho principal, não variante.** *(qwen v7, P0-1)*
*(Medido no próprio repositório: `01b-matriz-part-types-por-tipo.md` — SDT 594/594 objetos
com o Part, `EmptyPct` **98,3**; Domain 593/593, `EmptyPct` **100**.)* Ou seja, ~584 dos 594
SDTs têm o Part **vazio**, e documentar os 96 SDTs do caso CTe é esmagadoramente inserção.
A v7 tratava isso como variante secundária da substituição e não especificava a forma.
Especificação:

- **Forma inserida**: `<InnerHtml><![CDATA[<texto>]]></InnerHtml>`, posicionada **antes** de
  `<Properties>` dentro do Part — a ordem observada nos objetos que têm conteúdo.
- **Part multi-linha** (`<Part …>\n  <Properties />\n</Part>`): o `<InnerHtml>` entra em
  linha própria, com a indentação do `<Properties>` irmão, usando o EOL detectado (§5).
- **Part colapsado numa linha** (`<Part …><Properties /></Part>`): **preservado inline** — o
  `<InnerHtml>` é inserido imediatamente após a tag de abertura do Part, sem expandir o Part
  para multi-linha. Expandir mudaria bytes fora do delta e interage com o gate de fidelidade
  textual.
- **Substituição** (`texto → texto`): substitui o bloco `<InnerHtml>…</InnerHtml>` inteiro,
  preservando o que houver em volta.
- O intervalo do Part entra no **conjunto publicado de intervalos mutados** — a v7 enumerava
  os pontos do `setParent`, o `description` e o `checksum` nulo, e esquecia este.

**Correção de redação** *(deepseek v6, G6)*: a v6 dizia que esses códigos "acompanham o
vocabulário do `GeneXusXmlSurgicalEditSupport`". Não acompanham — o suporte existente emite
**um** código genérico `ANCHOR_FAIL` com contagem, e os dois códigos acima **são novos**.
Consequência prática: este motor **não** reusa `Invoke-GeneXusXmlSurgicalEditCore` para a
âncora de documentação; reusa apenas o primitivo `Invoke-GeneXusXmlLiteralPatch` e
reimplementa a contagem e o mapeamento de código.
*(Medido: 10 arquivos do acervo têm mais de um desses Part; `PackagedModule\GeneXus.xml`
tem 248.)* `]]>` no texto → `CDATA_UNSAFE`.

**`setParent`** — micro-patch por atributo, âncora vinda do `expected`, contagem própria,
limitada ao intervalo da tag raiz. Quando a grafia real diverge do literal derivado do
`expected` (espaços em volta do `=`, aspas simples), o motor **bloqueia** com
`ATTRIBUTE_LEXICAL_MISMATCH` em vez de normalizar por conta própria — normalização
silenciosa reintroduziria a classe de risco que o micro-patch veio eliminar. Atributo
ausente é inserido após `name="<expectedName>"`; âncora de inserção não encontrada →
`ATTRIBUTE_INSERTION_ANCHOR_NOT_FOUND`. *(big-pickle v4, P2-7)*
*(Medido: zero tags raiz com `>` cru ou escapado em 15.149 XMLs. O micro-patch é adotado
porque dispensa delimitar a tag e torna a preservação demonstrável.)*

**`renameDomain`** — quatro pontos com precondição e contagem próprias: `Object/@name`
(exata); `Object/@fullyQualifiedName` (só o segmento final); `Property[Name='Name']/Value`
(exata); `Object/@description` (só se idêntico a `expectedName`; senão preserva, reporta e
rebaixa o status). Mais: nome de arquivo válido no Windows; rename que difere só na caixa →
`RENAME_CASE_ONLY`; colisões em lote antes do primeiro rename, contra frente e acervo;
ciclo entre renomes do lote; pós-condição `Object/@name` == novo nome == base do arquivo;
varredura residual case-insensitive do nome antigo.

## 7. Scanner de referências a Domain (D4′)

O motor sempre executa a busca; o bloqueio decorre da medição dele.

- **Scanner estrutural**: percorre nós `<Property>` e compara por **igualdade exata do texto
  do nó `<Value>`** contra as grafias aceitas. Atributos entram **apenas** como insumo do
  detector de grafia desconhecida, não como fonte de casamento positivo — a v4 prometia
  "nós e atributos" e descrevia mecanismo só de `<Value>`. *(big-pickle v4, P0-2.4)*
- **Grafias aceitas derivadas do objeto — três formas, duas sintaxes.** *(medição v6)*
  1. **curta**: `Domain:<name>` — 498 das 692 grafias distintas do acervo;
  2. **qualificada de referência**: `Domain:<name>, <NomeDoMódulo>` — **vírgula e espaço**,
     194 das 692 (28%). É a mesma forma do `ATTCUSTOMTYPE` (`sdt:Messages, GeneXus.Common`);
  3. **`fullyQualifiedName`**: `<Módulo>.<name>` — **ponto**, sintaxe **diferente** da usada
     na referência para o **mesmo objeto**.

  O caso `GAMMessageType` prova que as três coexistem: `Domain/GAMMessageType.xml` tem
  `name="GAMMessageType"` e `fullyQualifiedName="GAM.GAMMessageType"`, e a única referência
  a ele no acervo é `Domain:GAMMessageType, GAM`. Um scanner que só procurasse o nome curto
  e o `fullyQualifiedName` acharia **zero** e liberaria o rename — falso negativo medido.

  **Fonte do nome do módulo**: `moduleGuid` da tag raiz cruzado com
  `ObjetosDaKbEmXml/Module/*.xml`. O layout do acervo é plano (`<Type>/<Name>.xml`), então o
  módulo não vem do caminho. *(big-pickle v4, P0-2.3; sintaxe corrigida pela medição v6)*
- **Domain definido dentro de `PackagedModule` está fora de escopo.** Das 194 grafias
  qualificadas, **193** apontam para Domains que não existem em `Domain/` — vivem dentro de
  XMLs de `PackagedModule`. Renomear Domain de módulo empacotado não é caso desta
  ferramenta; uma ocorrência qualificada cujo definidor não seja um `Domain/*.xml` do acervo
  é registrada e tratada como `REFERENCE_SCAN_INCOMPLETE` quando puder colidir com o alvo,
  nunca como não-uso silencioso. *(medição v6)*
- **Regra de casamento, sem contradição** *(qwen v7, P2-8a)*: a comparação é
  **case-insensitive com `StringComparison.OrdinalIgnoreCase`** — âncora de cultura fixada
  explicitamente *(opus-5 v9)*, senão a comparação fica sujeita à cultura corrente, que é a
  armadilha registrada nas convenções da máquina — entre o texto do nó `<Value>` e a grafia
  aceita, **completo contra completo** (nunca substring). A v7 dizia "igualdade exata" num ponto e "case-insensitive"
  noutro — a intenção era recuperável, mas a redação autorizava a implementação oposta, e é
  ela que decide se `domain:cte_tdata` bloqueia um rename. Casamento que diverge só na caixa
  é reportado como `caseInsensitiveMatch`.
- **Não reusar `Get-AnchorOccurrenceCount`** *(qwen v7, P2-8c)*: ele faz
  `[regex]::Escape` + `[regex]::Matches` **sem** `RegexOptions`, portanto é
  case-**sensitive**. Um scanner case-insensitive não pode consumi-lo — é exatamente a
  armadilha `[regex]::Match` × `-match` registrada nas convenções da máquina. O scanner
  implementa a própria contagem, como o `setDocumentation` já faz (§6).
- **Ambiguidade com `PackagedModule`** *(qwen v7, P2-8b)*: o ramo fail-closed da v7 era
  **inalcançável**. Ele disparava quando a forma curta resolvia para mais de um Domain — mas
  o layout plano `Domain/<Nome>.xml` impede homônimos *(Medido: zero)*, e os de
  `PackagedModule` estão fora de escopo, logo nunca eram enumerados como candidatos. O buraco
  real é o oposto: um nome que existe **tanto** em `Domain/` **quanto** dentro de um
  `PackagedModule` resolvia com confiança para o objeto do acervo, com o homônimo empacotado
  invisível. `GAMMessageType` — a única sobreposição medida, usada como fixture da §13.7 —
  prova que o caso existe. Regra: ao casar a forma curta, o scanner **também** verifica se
  algum XML de `PackagedModule` define Domain homônimo; se sim, `REFERENCE_SCAN_INCOMPLETE`.
- **Resolução ambígua é fail-closed.** Cada ocorrência `Domain:<x>` é resolvida para o
  Object que a define; quando a grafia não qualificada resolve para **mais de um** Domain
  (homônimos em módulos distintos), o resultado é `REFERENCE_SCAN_INCOMPLETE` com as
  ocorrências listadas — nunca escolha arbitrária. Espelha o padrão já existente de
  `front-object-type-drift-ambiguous-acervo`. *(big-pickle v4, P0-2.1)*
- **GUID como resolução, não como termo de busca.** A ocorrência só conta como uso quando o
  Object que a define tem o `guid` do alvo.
- **`CDATA` do Part de documentação é report-only — e só ele.** *(recorte corrigido por
  deepseek v6, G5)* Ocorrências de `Domain:<nome>` dentro do CDATA do Part
  `babf62c5-…` são listadas no relatório e **não** contam para `DOMAIN_STILL_REFERENCED`:
  ali é prosa, não vínculo resolvido pelo GeneXus, e contá-la criaria auto-infração — uma
  `setDocumentation` do próprio lote que mencionasse o nome bloquearia o `renameDomain`
  correspondente.

  A v6 generalizava para "todo CDATA", o que estava errado: `<Source><![CDATA[…]]></Source>`
  também é CDATA e é **código**. Ocorrência de `Domain:<nome>` em `<Source>` é tratada como
  ocorrência normal e **bloqueia**. Teste dedicado para os dois casos. *(big-pickle v4, P0-2.2)*
- **Precedência entre `unusedEvidence` e medição**: escopos diferentes (o `what-uses` cobre
  o índice; o scanner cobre XML do acervo e da frente). A regra é **conservadora**:
  qualquer das duas fontes indicando uso bloqueia. Divergência entre elas é reportada
  explicitamente, e a medição do motor nunca é rebaixada pela declaração humana. *(big-pickle v4, P0-2.5)*
- **Detector de grafia desconhecida**: qualquer `<Value>` começando com `Domain:` cujo
  sufixo não resolva para nenhum Domain conhecido dispara `REFERENCE_SCAN_INCOMPLETE`.
- Escopo: acervo **e** frente planejada. Case-insensitive. *(Medido: 424 referências
  casando exatamente — porém essa varredura cobriu apenas `SDT/`, `Transaction/` e
  `Procedure/`, não o acervo inteiro; a varredura completa achou 692 grafias distintas. A
  conclusão sobre caixa vale no escopo medido e é adotada por precaução fora dele. O custo
  computacional é desprezível, mas o custo semântico não é zero — casamento que diverge só
  na caixa é reportado como tal.)* *(escopo da medição corrigido na v6)*

### Registro da medição que gerou a v6

Varredura de `<Value>Domain:…</Value>` em todo o acervo (15.149 XMLs): 692 grafias
distintas, 21.219 ocorrências, 498 curtas, 194 qualificadas `Nome, Modulo`, zero fora
dessas duas formas. Módulos citados nas qualificadas: `GeneXusSecurityCommon` (98 grafias),
`GeneXus` (32), `GeneXusReporting` (13), `GeneXusCryptography` (12), `GeneXus.Common` (8),
`GeneXus.SD` (7) e outros. Sobreposição curto×qualificado: **uma** (`GAMMessageType`).
Domains homônimos em `Domain/`: **zero** — o layout plano `<Type>/<Name>.xml` impede
representá-los, o que é limite do acervo, não garantia da KB.
- Sintaxe desconhecida, arquivo ilegível ou tipo não coberto → `REFERENCE_SCAN_INCOMPLETE`.
  "Zero com cobertura incompleta" não é sucesso. `-AcknowledgeReferences` registra aceitação
  do limite; não transforma medição incompleta em autorização.
- **Limite declarado**: o acervo é o último XPZ exportado e XPZ não representa deleções.

## 8. Acentuação (D5″)

Degradação preexistente no alvo → reportada por ocorrência, não bloqueia. Degradação
introduzida pelo texto novo → `DEGRADED_ACCENTS_INTRODUCED`. A exceção é **por operação**
(`allowDegradedAccents`), habilitada pelo switch de linha de comando mas nunca concedida por
ele. Detecção cobre acento ausente e mojibake.

## 9. `lastUpdate` anormalmente futuro — aviso, não bloqueio

A v4 listava `LASTUPDATE_BASELINE_IMPLAUSIBLE` como bloqueio. **Removido.** *(big-pickle v4, P0-1)*

Motivo, verificado na fonte: `Test-SetGeneXusXmlLastUpdateSelfTest.ps1:88-97` exige que o
motor **respeite** baseline futuro (`2099-01-01T00:00:00.0000000Z`, "Caso 2: lastUpdate
deveria respeitar o baseline futuro (regra max)"), e `Build-GeneXusImportFileEnvelope.ps1`
**eleva** o teto de futuro permitido para acomodar `baseline + margem`. O bloqueio proposto
contradiria o contrato testado do motor que a própria D1 manda reusar, e a lista de testes
da v4 se contradizia ao pedir "baseline futuro → implausível" e "acervo com data futura →
interação com o 9-FD" na mesma linha.

Há ainda o caso operacional legítimo: re-execução **dentro da margem de frescor** vê o
baseline da própria rodada anterior no futuro, e o bloqueio transformaria a ferramenta em
uso único por arquivo dentro dessa janela.

Fica como campo de aviso no relatório (`baselineFutureAnomaly`, com o valor e a origem),
para que baseline corrompido — a preocupação legítima que originou o gate — permaneça
visível sem bloquear o que o ecossistema valida.

### 9.1 Exceção: `objectState: new` **bloqueia** *(qwen v7, P1-4)*

A decisão acima vale para `objectState: existing`. Para objeto **novo** ela estava errada, e
o motivo é assimetria no próprio envelope:

| Caso | `Build-GeneXusImportFileEnvelope.ps1` |
|---|---|
| **com** baseline (`existing`), L436-440 | `maxAllowedFuture = max(maxFuture, baseline + margem)` — o teto **sobe** |
| **sem** baseline (`new`), L417-421 | `candidate > maxFuture` → `fail`, `baseline-missing-too-far-in-future`, **sem elevação de teto e independente de `NewObjectPolicy`** |

Como a §2.1 reduz o baseline de objeto novo ao valor da frente, um arquivo novo com
`lastUpdate` futuro faria o motor gravar `frente + margem`, reportar `ok` com
`baselineFutureAnomaly`, e o pacote seria bloqueado **depois**, no empacotamento. Isso
reproduz literalmente o pecado que a §1 nomeia: transferir uma falha dura para um gate
posterior e declarar sucesso.

**O limiar é sobre a saída, não sobre a entrada** *(qwen v8, P2-B)*. A v8 bloqueava quando o
`lastUpdate` **da frente** passasse de `UtcNow + 120s`. Mas o motor grava `entrada + margem`
(default 60), e o envelope confere o valor **gravado**. Uma frente entre `UtcNow+60` e
`UtcNow+120` passaria no pré-bloqueio, o motor gravaria entre `UtcNow+120` e `UtcNow+180`, e
o empacotamento barraria depois — reabrindo, numa janela de 60 segundos, o buraco que esta
seção existe para fechar.

Regra da v9: em `objectState: new`, o bloqueio é avaliado sobre o **valor que o motor vai
gravar**, contra a tolerância de futuro do envelope. Essa tolerância é o
`FutureToleranceSeconds` de `Build-GeneXusImportFileEnvelope.ps1` (default 120, mas
**parâmetro**, não constante mágica) — o motor lê o default do contrato do envelope em vez
de repetir o número. Código: `NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE`.

Não se clampeia silenciosamente: transformar valor sem dizer é o oposto do que este desenho
faz.

## 10. Bloqueios

`IDENTITY_MISMATCH`, `PRECONDITION_MISMATCH`, `HEAD_DIVERGENCE`, `ANCHOR_NOT_FOUND`,
`ANCHOR_AMBIGUOUS`, `ATTRIBUTE_LEXICAL_MISMATCH`, `ATTRIBUTE_INSERTION_ANCHOR_NOT_FOUND`,
`CDATA_UNSAFE`, `DOMAIN_STILL_REFERENCED`, `REFERENCE_SCAN_INCOMPLETE`, `NAME_COLLISION`,
`RENAME_CYCLE`, `RENAME_CASE_ONLY`, `INVALID_FILENAME`, `MODULE_PARENT_UNSUPPORTED`,
`PARENT_TARGET_MISSING`, `PARENT_TARGET_NOT_FOLDER`, `PARENT_SELF_REFERENCE`,
`PARENT_CYCLE`, `NEW_OBJECT_EXISTS_IN_ACERVO`, `UNSUPPORTED_OPERATION`,
`DUPLICATE_OPERATION`, `DUPLICATE_TARGET`, `TYPE_NOT_IN_CATALOG`, `PROTECTED_AREA`,
`PATH_OUTSIDE_FRONT`, `FRONT_NOT_CANONICAL`, `ARTIFACT_PATH_COLLISION`, `HARDLINK_REFUSED`,
`RUN_LOCKED`, `SOURCE_CHANGED`, `PLAN_STALE`, `BAK_EXISTS`, `ROLLBACK_INCOMPLETE`,
`MULTIPLE_OBJECT_ROOTS`, `TARGET_FILE_MISSING`, `TARGET_NOT_WRITABLE`,
`ENCODING_UNEXPECTED`, `EOL_MIXED`, `PAYLOAD_EOL_INVALID`, `DEGRADED_ACCENTS_INTRODUCED`,
`LASTUPDATE_TARGET_OUTSIDE_ROOT`, `LASTUPDATE_UNREADABLE`,
`NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE`, `MANIFEST_KIND_MISMATCH`,
`MANIFEST_SCHEMA_UNSUPPORTED`.

`ANCHOR_NOT_FOUND`, `ANCHOR_AMBIGUOUS` e `LASTUPDATE_TARGET_OUTSIDE_ROOT` são **códigos
novos**, sem equivalente nos motores existentes (§6). `HARDLINK_REFUSED` passa a poder
disparar na Fase 0 **e** na Fase 2.

Avisos que **não** bloqueiam e têm campo próprio no relatório: `baselineFutureAnomaly`,
`checksumStale`, `descriptionPreservedByDivergence`, `staleLockReclaimed`,
`caseInsensitiveMatch`, `cdataOccurrence`.

**`checksumStale` é status de máquina distinto**, não `ok` com aviso embutido — o relatório
nunca promove o resultado a "importável". *(big-pickle v4)*

## 11. D7′ — duas fontes distintas, não uma

**Separação explícita** *(deepseek v6, G2)* — a v6 confundia as duas e deixava a validação
sem base quando o git faltasse:

| Papel | Fonte | Sempre disponível? |
|---|---|---|
| **Pré-condição** (`expected` contra a realidade) | **worktree do acervo** | sim |
| **Testemunha de divergência** (`HEAD_DIVERGENCE`) | **objeto git** (`git show HEAD:<caminho>`) | não |

A validação de `expected` **nunca** depende de git: lê o worktree do acervo, como faz o gate
9-FD existente (`Test-GeneXusFrontAcervoDrift.ps1`), que não tem dependência de
versionamento. A testemunha de `HEAD` serve **apenas** para confrontar o `expected`
declarado contra o estado versionado, detectando declaração feita sobre um acervo já
alterado no worktree.

`headWitness: available | unavailable | dirtyWorktree` no relatório; `-RequireHeadWitness`
torna `unavailable` um bloqueio. Com `unavailable` e sem esse switch, a rodada **prossegue**
com a pré-condição validada contra o worktree e o relatório registrando que a segunda
testemunha não existiu.

*(Medido: nesta KB o acervo é versionado — 15.150 arquivos rastreados, e o `.gitignore`
ignora frente, pacotes, `Temp/` e XPZ, não o acervo. Mas o `README` trata versionamento da
pasta paralela como **opcional**, então pasta sem git é caso previsto, não hipotético.)*

Critério de disparo distinto: `HEAD_DIVERGENCE` é *o `expected` declarado não bate com o
acervo em `HEAD`* (erro de declaração, na Fase 1a). `PLAN_STALE` é *uma dependência mudou
entre o plano e a aplicação* (corrida, na Fase 2). *(big-pickle v4, P2-10)*

## 12. Limites declarados

- **`checksum`**: obsoleto, não recalculado nem zerado. Comportamento **não verificado fora
  do caso CTe** — 131 objetos importados com checksum obsoleto e a importação funcionou.
  Caminho observado com n=1, não regra do GeneXus. **Registrar em `999`** uma medição futura
  (importação com `checksum=""` em KB de ensaio) para fechar a questão com evidência em vez
  de argumento. *(big-pickle v4)* **A entrada nova precisa referenciar e distinguir** a que
  já existe em `999:1479-1504`, que trata da task MSBuild `CalculateChecksums` — pergunta
  diferente (granularidade e comparação antes/depois do import). Sem essa distinção, um
  implementador futuro pode marcar a obrigação como cumprida pela entrada errada.
  *(qwen v7, P2-9)*
- Well-formedness não prova validade GeneXus nem sucesso de importação ou build.
- O lock coordena execuções deste motor; não impede a IDE nem outro processo.
- Existe janela entre reler e mover que nenhum mecanismo aqui fecha.
- `File.Move` é atômico quanto à visibilidade, não durável contra queda de energia.
- **O journal herda a mesma janela.** *(deepseek v6, G7)* Ele é gravado pelo
  `Write-XpzTextFileAtomic` — o mesmo escritor dos alvos, com `-TempDir` em `-WorkDir`
  *(qwen v8, P3: a v8 dizia `Write-XpzReportFileAtomic` aqui e `Write-XpzTextFileAtomic` na
  §6; os dois são viáveis para um journal que já vive em `-WorkDir`, mas o desenho precisa
  dizer qual)*. A mecânica é a mesma (temporário + `File.Move`, sem fsync de diretório): o
  `Flush($true)` cobre o **conteúdo** do arquivo, não a entrada de diretório. Portanto a
  frase "a durabilidade do move é coberta pelo journal" vale contra **morte de processo**,
  não contra **queda de energia no instante do move do próprio journal**. Fechar isso
  exigiria fsync de diretório, que não está no escopo desta versão.
- A cobertura do scanner é a declarada; fora dela, `REFERENCE_SCAN_INCOMPLETE`.
- Medições citadas são deste acervo (15.149 XMLs), não do GeneXus em geral.

## 13. Testes

1. Fixture derivado de arquivo real do acervo (indentação irregular, `<Properties>`
   colapsado, Part vazio com `<Properties />`). **Inclui o caminho principal**: inserção
   `null → texto` em Part vazio multi-linha **e** em Part colapsado numa linha, com asserção
   de que o colapsado **não** é expandido.
1b. EOL: arquivo só-LF, arquivo só-CRLF e arquivo **misto** (→ `EOL_MIXED`, nunca
   normalizado em silêncio).
2. Fixture adversarial: `>` em valor de atributo e `<Object>` aninhado em `PackagedModule`.
3. Escala com falha injetada: 131 operações, falha na 120ª — zero arquivos com hash
   alterado, zero renomes remanescentes, zero arquivos novos na frente; e publicação do
   conjunto de intervalos mutados por operação.
4. Não-escrita: duas execuções sem `-Apply` — hash e mtime inalterados em toda a frente e
   **nenhum artefato persistente** em lugar nenhum (o lock transitório não conta).
5. Recuperação real a partir do journal e dos `.bak` após morte do processo, inclusive
   quando o processo morre **entre** o `started` e o `committed` do journal.
6. `lastUpdate`: baseline parado há meses (o carimbo supera `UtcNow`); baseline futuro
   (respeitado pela regra max, com `baselineFutureAnomaly` no relatório — **não** bloqueia);
   re-execução dentro da margem de frescor (não bloqueia); acervo com data futura
   (interação com o 9-FD); **composição dos dois baselines** — `acervo > frente` e
   `frente > acervo` devem produzir o mesmo valor, e ambos no passado deixam `UtcNow`
   dominar; **raiz sem `lastUpdate` casável** com aninhado válido →
   `LASTUPDATE_TARGET_OUTSIDE_ROOT`, nunca escrita no aninhado.
6b. `objectState: new` com `lastUpdate` acima de `UtcNow + 120s` →
   `NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE`, **nunca** `ok` com aviso (§9.1).
7. Scanner: **fixture real `GAMMessageType`** — `name` curto, `fullyQualifiedName` com ponto
   (`GAM.GAMMessageType`) e referência com vírgula (`Domain:GAMMessageType, GAM`); o teste
   falha se o scanner reportar zero. Mais: grafia desconhecida; qualificada cujo definidor
   está em `PackagedModule`; homônimos em módulos diferentes (→ `REFERENCE_SCAN_INCOMPLETE`);
   ocorrência em `CDATA` (→ report-only, não bloqueia); divergência entre `unusedEvidence` e
   medição.
8. Lock: PID vivo (`RUN_LOCKED`); PID morto (`staleLockReclaimed`); lock em `-WorkDir`
   compartilhado visto por dois processos.
9. Aborto pós-1b: `PLAN_STALE` antes de qualquer move — journal e `.bak` preservados e
   listados no relatório.
10. Colisão de `-ReportPath` com alvo; falha durante a criação dos backups; dependência do
    acervo alterada entre as fases; no-op completo; duplicidade de caminho e de GUID;
    `objectState: new` com homônimo no acervo.

Mais: queda durante escrita e durante rename, `.bak` órfão, falha de rollback, manifesto
ambíguo, destino Folder inexistente, ciclo de renomes, nome reservado do Windows, hard
link, frente mais nova que o acervo, falha ao gravar relatório.

Bateria adjacente: parse de `scripts/`, edição cirúrgica, `lastUpdate`, copy-to-front,
drift, observabilidade de empacotamento, nomenclatura, colisão de pacote.

## 13.1 Entregáveis explícitos *(qwen v8, P3)*

Além do motor e do seu teste de contrato:

- `scripts/XpzProtectedAreaSupport.ps1` — guardas extraídos (D2), com
  `XpzExecutionReportSupport.ps1` passando a dot-sourceá-lo e continuando a expor as mesmas
  funções.
- **`-BaselineXmlPath` opcional** em `Get-NewGeneXusLastUpdateValueFromEngine`, com self-test
  próprio (§2.1-bis). Hoje é `Mandatory = $true`, o que torna o ramo sem baseline
  inexecutável. *(opus-5 v9, P1-1)*
- `Write-XpzTextFileAtomic` — escritor atômico com `-TempDir`, em suporte compartilhado.
- **Edição de `Test-XpzParameterNamingContract.ps1`**: acrescentar
  `Edit-GeneXusXmlBatchMetadata.ps1` à lista `$inputPathWithPathAlias`. A v8 dizia apenas
  "entra na lista do contrato", sem tratar isso como entregável — e o gate não falha sozinho
  se a entrada não for feita.
- **Roteiro de recuperação manual** a partir do journal (§5).
- Entrada em `999` sobre a medição futura de `checksum=""`, referenciando e distinguindo
  `999:1479-1504`.
- Entrada em `999` sobre a divergência `-AcervoPath`/`-AcervoFolder`/`-CorpusFolder` —
  **já gravada** em `999:3157-3183`.

## 14. O que foi recusado dos pareceres

- **Zerar o `checksum`** — a única evidência real é o caso CTe (n=1), com checksum obsoleto
  e importação bem-sucedida. Zerar troca o caminho medido por um não medido. Recusa mantida,
  com a medição futura registrada em `999` (§12).
- **Adiar `renameDomain`** — 35 dos 131 objetos do caso real. A justificativa não se apoia
  mais só na solidez do scanner (que tinha buracos apontados na v4 e foram fechados na v5),
  e sim na **necessidade operacional somada à recuperabilidade**: o rename é desfeito em
  ordem inversa antes da restauração dos `.bak`, e o aborto pós-1b preserva o rastro.
  *(re-ancorada conforme big-pickle v4)*

**Recusas retiradas ao longo das versões:** o default de D5 (v2→v3), o escopo global de
`-AllowDegradedAccents` (v3→v4) e o bloqueio `LASTUPDATE_BASELINE_IMPLAUSIBLE` (v4→v5).

**Correção desta lista** *(qwen v8, P2-C)*: a v8 ainda listava o descarte do
`Write-XpzTextFileAtomic` (v4→v5) entre as retiradas permanentes, embora a própria v8 o
tenha **restaurado** (§6). Quem lesse só a §14 concluiria que seguia removido. O histórico
correto é: entregue na v4, descartado na v5 por argumento de encoding, **restaurado na v8**
por argumento de localização de temporário — o argumento de encoding continua válido e não
era o único motivo.

**Correções contra o próprio repositório:** a D1 da v2/v3 (`max(acervo, frente)`) era
regressão contra `Set-GeneXusXmlLastUpdate.ps1`; a v4 corrigiu a fórmula mas introduziu um
bloqueio que contradizia o self-test do mesmo motor; a v5 removeu o bloqueio.
