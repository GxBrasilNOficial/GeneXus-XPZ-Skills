# 04b - UCW gxControlType: Referência de User Controls em WebPanel

## Papel do documento
empírico e operacional

## Nível de confiança predominante
misto — ver nível por UC

## Depende de
04-webpanel-familias-e-templates.md, 02-regras-operacionais-e-runtime.md

## Usado por
xpz-builder/SKILL.md, 04-webpanel-familias-e-templates.md

## Objetivo
Catalogar os User Controls usados dentro de `GxMultiForm` (layout responsivo de `WebPanel`) com seus `gxControlType` numéricos, propriedades em `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, regras de eventos, e a tabela de upload de arquivo por contexto de objeto.

---

## Como UCW aparece no XML

No layout de um `WebPanel` com `GxMultiForm`, cada User Control ocupa um elemento `<ucw>` dentro do CDATA do `Part type d24a58ad-57ba-41b7-9e6e-eaca3543c778`:

```xml
<ucw gxControlType="NUMERO" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;...&lt;/Properties&gt;" />
```

O atributo `PATTERN_ELEMENT_CUSTOM_PROPERTIES` contém um fragmento XML escapado com a lista de `<Property>` do UC. O número em `gxControlType` identifica o tipo do UC — é um inteiro negativo fixo, não um GUID.

---

> **Dado versionado:** este documento é a fonte documental do arquivo `scripts/gx-ucw-gxcontroltype-catalog.json`, consumido por `scripts/Get-GeneXusObjectSummary.ps1` para resolver o `gxControlType` de cada `<ucw>` no bloco `webpanel`. Ao acrescentar um UC aqui, refletir a entrada no JSON (chave = `gxControlType`); `gxControlType` ausente do JSON é reportado como desconhecido (`unknownUcwControlTypes`), nunca omitido.

## Catálogo de gxControlType

### Button — `-2133704903`

- Nível de confiança: **Evidência direta** (WP0004.xml desta base, FabricaBrasil)
- Uso: botão clicável que dispara um evento GeneXus nomeado
- Forma alternativa: o Button também aparece como `<action controlName= onClickEvent=>` no layout (mesma semântica, serialização diferente). Para a regra de declaração única e a desambiguação entre botão de layout, `<actions>` de pattern (ver `01j`) e referências `.Visible`/`.Icon` em código, ver [xpz-builder/responsibilities-by-type/webpanel.md](xpz-builder/responsibilities-by-type/webpanel.md).

Propriedades em `PATTERN_ELEMENT_CUSTOM_PROPERTIES`:

| Propriedade | Obrigatória | Descrição |
|-------------|-------------|-----------|
| `ControlName` | Sim | Nome do controle (ex.: `ButtonOpcaoA`) |
| `Enabled` | Sim | `True` ou `False` |
| `Event` | Sim | Nome do evento entre aspas simples (ex.: `'AbrirOpcaoA'`) |
| `CaptionExpression` | Sim | Texto exibido no botão |
| `Class` | Não | Classes CSS aplicadas (ex.: `button-tertiary Altura_100px`) |

Exemplo de `ucw` completo (propriedades já escapadas para o CDATA do layout):

```xml
<ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;ButtonOpcaoA&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Enabled&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'AbrirOpcaoA'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opcao A&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Class&lt;/Name&gt;&lt;Value&gt;button-tertiary&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
```

---

### FileUpload — `-1987551761`

- Nível de confiança: **Inferência forte — evidência de KB externa inspecionada** (wpImportaPessoas.xml, FabricaBrasil; OnlineShopSS, GeneXus 18 U9 Build 187794)
- Uso: controle de upload de arquivo em `WebPanel` com layout responsivo (`GxMultiForm`)
- Validar com XML real da KB alvo antes de materializar

Propriedades em `PATTERN_ELEMENT_CUSTOM_PROPERTIES`:

| Propriedade | Obrigatória | Descrição |
|-------------|-------------|-----------|
| `ControlName` | Sim | Nome do controle (ex.: `FileUpload1`) |
| `UploadedFiles` | Sim | Variável de coleção SDT que receberá os arquivos (ex.: `&UploadedFiles`) |
| `AutoUpload` | Não | `True` para upload automático ao selecionar o arquivo |
| `CustomFileTypes` | Não | Extensões aceitas separadas por vírgula (ex.: `*.jpg,*.png`) |

Exemplo de `ucw` completo:

```xml
<ucw gxControlType="-1987551761" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;FileUpload1&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;UploadedFiles&lt;/Name&gt;&lt;Value&gt;&amp;amp;UploadedFiles&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;AutoUpload&lt;/Name&gt;&lt;Value&gt;True&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CustomFileTypes&lt;/Name&gt;&lt;Value&gt;*.jpg,*.png&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" />
```

Nota sobre `UploadedFiles`: o valor é uma referência a variável GeneXus prefixada com `&`; no CDATA do layout ela aparece duplamente escapada (`&amp;amp;`).

---

### ProgressIndicator — `-1269900845`

- Nível de confiança: **Inferência forte — evidência de KB externa inspecionada** (FabricaBrasil, GeneXus 18 U9)
- Uso: indicador de progresso visual
- Propriedades: não documentadas nesta base — consultar XML real da KB alvo

---

### WebNotification — `-1946546103`

- Nível de confiança: **Inferência forte — evidência de KB externa inspecionada** (FabricaBrasil, GeneXus 18 U9)
- Uso: notificação visual na tela
- Propriedades: não documentadas nesta base — consultar XML real da KB alvo

---

## Regra de eventos de UC

- **Evidência direta**: a sintaxe `Event NomeUC.NomeEvento` em `Source` de `WebPanel` é inválida e gera erro `src0265: Invalid attribute` no GeneXus 18.
- **Regra operacional**: eventos de User Control não são acessíveis via `Event NomeUC.NomeEvento` no `Source` do `WebPanel`.
- **Inferência forte — evidência de KB externa inspecionada**: o padrão funcional validado é usar um botão comum (event `'SAVE'` ou equivalente) que lê a coleção `UploadedFiles` após o upload ter ocorrido; o disparo é implícito ao UC, não explícito via evento nomeado.
- **Regra operacional**: ao gerar `Source` de `WebPanel` com FileUpload UC, nunca usar `Event FileUpload1.UploadComplete` ou similar; usar evento de botão que processa a coleção após upload.

---

## SDT FileUploadData

- Nível de confiança: **Inferência forte — evidência de KB externa inspecionada** (OnlineShopSS, GeneXus 18 U9 Build 187794)
- Validar com XML real da KB alvo antes de materializar como molde definitivo

### Estrutura canônica dos membros

| Membro | Tipo | Observação |
|--------|------|------------|
| `FullName` | `bas:Character` | Caminho completo do arquivo |
| `Name` | `bas:Character` | Nome do arquivo sem caminho |
| `Extension` | `bas:Character` | Extensão do arquivo |
| `Size` | `bas:Numeric` (Length=10, AttMaxLen=10) | Tamanho em bytes |
| `File` | `bas:Blob` | Conteúdo binário do arquivo |

### Localização na KB

- O SDT `FileUploadData` deve ser criado dentro da pasta (Folder) `FileUploadUserControl`, não na raiz da KB.
- A variável de coleção que recebe os arquivos do UC deve ter `AttCollection=True` (ver seção abaixo).

---

## Propriedade canônica de coleção SDT

- **Evidência direta** (moldes desta base em `01e-moldes-sanitizados-core.md` e `04-webpanel-familias-e-templates.md`): a propriedade correta para declarar uma variável como coleção de SDT é `AttCollection=True`.
- **Regra operacional**: `Collection=True` e `IsCollection=True` são inválidos e serão rejeitados pelo GeneXus; nunca usá-los.
- Essa regra vale em variáveis de `WebPanel`, `Procedure` e `DataProvider`.

Forma correta no XML da variável:

```xml
<Property>
  <Name>AttCollection</Name>
  <Value>True</Value>
</Property>
```

---

## Tabela: upload de arquivo por contexto de objeto GeneXus

| Contexto | Como fazer upload | Nível de confiança |
|----------|-------------------|--------------------|
| `Transaction` form (Insert/Update nativo) | Automático — atributo do tipo `Image` ou `Blob` renderiza controle multimedia-upload nativamente | Evidência direta desta base |
| `WebPanel` com Responsive Layout (`GxMultiForm`) | Somente via `<ucw gxControlType="-1987551761">` (FileUpload UC) + variável de coleção `FileUploadData` com `AttCollection=True` | Inferência forte — evidência de KB externa inspecionada |
| `WebPanel` com Abstract Layout | `<Control Type="FileUpload">` — não testado com sucesso como caminho seguro | Hipótese — sem evidência validada |

- **Regra operacional**: em `WebPanel` com `GxMultiForm`, não tentar substituir o FileUpload UC por atributo `Blob` com `controlType="Blob"` ou por `PATTERN_ELEMENT_CUSTOM_PROPERTIES` com `ControlType=Upload`; esses caminhos foram testados e falharam.
- **Regra operacional**: Abstract Layout em `WebPanel` é caminho não validado para upload; se o objetivo for upload em `WebPanel`, preferir layout responsivo (`GxMultiForm`) com o UCW FileUpload.

---

## Hipótese técnica: `Rows` para `Character` longo em `GxMultiForm`

- **Problema medido** (frente GamAuditoria, 2026-08-17): variável `Character(254)` em `WebPanel` com layout responsivo (`GxMultiForm`) renderiza como `textarea` de três linhas; declarar `ControlType = Edit` nas propriedades da variável **não** converteu para input de uma linha.
- **Hipótese técnica (não validada)**: o controle equivalente à altura de linha do `textarea` no layout `GxMultiForm` pode ser controlado por propriedade de layout (candidata: `Rows=1` no controle correspondente dentro do CDATA do layout) em vez de propriedade da variável.
- **Ressalva obrigatória**: **não empacotar** objetos com essa propriedade até a hipótese ser validada em fixture com `.cs` gerado conferido e renderização visual confirmada. A propriedade `Rows` citada é candidata, não padrão confirmado; ver `999-ideias-pendentes.md` (entrada da hipótese `Rows`) e `Temp/subsidios-dataview-e-webpanel-sdt-20260817.md` (§3.2-c) para a rastreabilidade da medição.
