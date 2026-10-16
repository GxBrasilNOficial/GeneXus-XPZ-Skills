# 01j - WorkWithWeb: Padrões de CDATA e Ancoragem Cirúrgica

## Papel do documento
empírico e operacional

## Nível de confiança predominante
evidência direta (Gx_FabricaBrasil: 184 objetos; Gx_wsEducacaoSpTeste: amostra menor)

## Depende de
01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md

## Usado por
xpz-builder/SKILL.md

## Objetivo

Documentar a hierarquia interna do CDATA de objetos `WorkWithForWeb` para orientar inserção textual cirúrgica. A falta deste mapa levou a erros reais de regex que casaram com `<actions>` em dois ou mais níveis distintos dentro do mesmo CDATA, corrompendo o alvo da transformação.

---

## Container do CDATA

O conteúdo de configuração do `WorkWithForWeb` está em:

- **Part type**: `a51ced48-7bee-0001-ab12-04e9e32123d1`
- **Elemento interno**: `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="1.0"><![CDATA[...]]></Data>`

Dentro do CDATA há um documento XML completo começando com `<?xml version="1.0" encoding="utf-16"?>`.

Atenção: o CDATA principal pode conter blocos `<![CDATA[...]]>` internos dentro de elementos `<variable>`. Esses blocos internos contêm código GeneXus que o padrão aplica ao objeto gerado. Não são CDATA aninhados no sentido XML — o parser os trata como texto literal dentro do CDATA externo.

---

## Hierarquia estrutural do CDATA

```
<instance webFormDefaults="..." updateTransaction="...">
  <transaction transaction="GUID-EntityName" />
  <level id="GUID-level:1" name="EntityName">
    <descriptionAttribute attribute="GUID-Attribute" description="..." />

    <selection description="..." page="..." customStartEventCode="...">
      <modes Insert="..." Delete="..." Display="..." Export="..." />
      <attributes>
        <attribute attribute="GUID-Attr" ... />
        <variable name="IconeUpdate" domain="..." ...><![CDATA[código GeneXus]]></variable>
        ...
      </attributes>
      <actions>                  <!-- NÍVEL 1 — ações da LISTA -->
        <action name="LimpaGridState" .../>
        <action name="Insert" />
        <action name="RelatorioX" .../>
        ...
      </actions>
      <filter>                   <!-- filtro da listagem principal -->
        <attributes>
          <filterAttribute name="AttrName" description="..." default="..." />
        </attributes>
        <conditions>
          <condition value="..." />
        </conditions>
      </filter>
    </selection>

    <view caption="..." description="..." backToSelection="..." masterPage="...">
      <parameters>
        <parameter name="EntityNameEmpresaId" null="True" />
        <parameter name="EntityNameId" null="True" />
      </parameters>
      <fixedData>
        <attributes>...</attributes>
      </fixedData>
      <tabs>

        <tab name="Geral" code="General" type="Tabular" wcname="EntityNameGeneral">
          <attributes>...</attributes>
          <actions>              <!-- NÍVEL 2a — ações do DETALHE (registro corrente) -->
            <action name="Update" />
            <action name="Delete" />
            <action name="CustomAction" .../>
          </actions>
        </tab>

        <tab name="Itens" code="EntityNameItens" type="Grid" wcname="EntityNameItensWC"
             page="..." condition="...">
          <transaction transaction="GUID-EntityNameItens" />
          <modes Insert="..." Update="..." Export="..." />
          <attributes>...</attributes>
          <actions>              <!-- NÍVEL 2b — ações do GRID FILHO -->
            <action name="NovoItem" .../>
            <action name="RelatorioItens" .../>
          </actions>
          <orders>...</orders>
          <filter>               <!-- filtro do grid filho — independente do filtro da selection -->
            <attributes>
              <filterAttribute name="AttrName" description="..." />
            </attributes>
            <conditions>
              <condition value="..." />
            </conditions>
          </filter>
        </tab>

        <tab name="Documentos" code="EntityNameDocs" type="UserDefined" wcname="EntityNameDocsWC">
          <!-- tabs UserDefined tipicamente não têm <actions> -->
        </tab>

      </tabs>
    </view>
  </level>
</instance>
```

## Chamadas de `View` e `wcname`

A cadeia observada de geração é `WorkWithWeb<Trn>` → `WW<Trn>` (Selection) → `View<Trn>` → `<Trn>General` (Web Component Tabular) e `<Trn><Code>WC` (Web Components Grid). Uma `View` padrão gerada pelo pattern não tem corpo materializado no XML e é acessada por URL; sua assinatura de chamada é formada pelas chaves da Transaction base na ordem declarada, seguidas por um `string` final `code`. Chaves de níveis filhos ficam de fora; passe `""` para solicitar a aba default.

`Ressalva de compatibilidade`: em Views geradas até 2026-07-01, o C# observado comparava a aba default com `"General"`; em Views regeneradas a partir de aproximadamente 2026-08-30, houve comparação com `"Geral"`, embora não exista aba com `code="Geral"`. Não use nenhum desses literais para solicitar a aba default: passe `""`. Para uma aba não default, use o `code` efetivo; a divergência é um quirk datado do código gerado, não um contrato para substituir `code` por `name`.

| Campo da aba | Papel no fluxo gerado |
|---|---|
| `code` | Identificador interno da aba e seletor da URL; use este valor para selecionar a aba |
| `name` | Nome de exibição; não o use como seletor da URL |
| `wcname` | Nome do Web Component gerado associado à aba; não é o seletor da URL |

| Exceção de `wcname` | Contagem | Regra |
|---|---:|---|
| Em abas Grid, `wcname` acompanha a Transaction referenciada, não o `code` da aba | 14 | Continue usando `code` como seletor; a exceção não altera a assinatura da View |

Para a distinção de componentes, o caso `spc0045` e a evidência de `WEB_COMP`, consulte [02-regras-operacionais-e-runtime.md](02-regras-operacionais-e-runtime.md) e [xpz-builder/responsibilities-by-type/workwithforweb.md](xpz-builder/responsibilities-by-type/workwithforweb.md).

---

## Elementos que aparecem em múltiplos níveis

| Elemento | Onde aparece | Papel |
|---|---|---|
| `<actions>` | `<selection>` | Ações da **lista** — sem contexto de registro específico (ex.: Insert, relatórios, LimpaGridState, exportações em lote) |
| `<actions>` | `<tab type="Tabular">` | Ações do **detalhe** — aplicam-se ao registro corrente (ex.: Update, Delete, ações por registro) |
| `<actions>` | `<tab type="Grid">` | Ações do **grid filho** — específicas daquela aba (ex.: NovoItem, relatórios da aba) |
| `<filter>` | `<selection>` | Filtro da listagem principal |
| `<filter>` | `<tab type="Grid">` | Filtro do grid filho (independente) |

---

## Distribuição empírica (Gx_FabricaBrasil, 184 objetos)

| Padrão | Quantidade |
|---|---|
| `<actions>` em AMBOS `<selection>` e `<tab>` | 122 |
| `<actions>` apenas em `<tab>` (sem `<selection>/<actions>`) | 62 |
| `<actions>` apenas em `<selection>` | 0 |
| Sem `<actions>` | 0 |

- Inferência forte: o padrão dominante nesta KB é a presença de `<actions>` nos dois níveis simultaneamente. Uma regex genérica sobre `<actions>` **sempre casará em múltiplos pontos** para 2/3 dos objetos.
- Evidência direta: objetos com até 14 tabs foram observados; um único objeto pode ter `<actions>` em `<selection>` + `<tab type="Tabular">` + múltiplos `<tab type="Grid">` = 4 ou mais blocos `<actions>` distintos.

---

## Regras de ancoragem cirúrgica

### Para inserir uma `<action>` na LISTA (`<selection>`)

Âncora confiável: o elemento `<selection>` é único no CDATA e antecede `<view>`.

```
âncora de abertura:  <selection[^>]*>   (o elemento selection em si)
âncora de fechamento: </selection>
buscar <actions> apenas dentro desse escopo
```

Se `<selection>` não tiver `<actions>`, inserir um bloco novo **antes de `<filter>`** (ou antes de `</selection>` se `<filter>` também estiver ausente). A ordem canônica dentro de `<selection>` é: `<modes>`, `<attributes>`, `<actions>`, `<filter>`.

### Para inserir uma `<action>` no DETALHE (`<tab type="Tabular">`)

Âncora confiável: `code="General"` (o tab Tabular principal tem `code="General"` por convenção do padrão).

```
âncora:  <tab [^>]*code="General"[^>]*>
buscar <actions> apenas dentro desse escopo (até o </tab> correspondente)
```

Se a KB usar outro `code` para o tab Tabular, verificar no XML real.

### Para inserir uma `<action>` em tab Grid específico

Âncora confiável: `code="X"` onde X é o código GeneXus interno daquela aba.

```
âncora:  <tab [^>]*code="EntityNameItens"[^>]*>
buscar <actions> apenas dentro desse escopo
```

O atributo `code` é o identificador estável gerado pelo padrão WorkWithForWeb. O atributo `name` pode variar por localização; o `code` não.

### NUNCA usar

```
# Regex perigosas — casam em múltiplos níveis sem discriminação:
<actions>
<actions>[\s\S]*?</actions>

# Limite de ocorrências (ex.: só a 1ª) depende de ordem de irmãos
# e é frágil quando a ordem selection/view pode variar.
```

---

## Exemplo sanitizado 1 — Simples (1 tab Tabular, sem Grid)

Baseado em objetos de 4–6 KB. `<actions>` existe apenas no tab Tabular (sem `<selection>/<actions>`).

```xml
<?xml version="1.0" encoding="utf-16"?>
<instance webFormDefaults="Responsive Web Design" updateTransaction="Apply WW Style">
  <transaction transaction="GUID-Entidade" />
  <level id="GUID-Level:1" name="Entidade">
    <descriptionAttribute attribute="GUID-EntidadeDescricao" description="Descrição" />

    <selection description="Lista de Registros" page="&lt;default&gt;">
      <modes />
      <attributes>
        <attribute attribute="GUID-EntidadeEmpresaId" description="Empresa Id"
                   autolink="True" visible="True" />
        <attribute attribute="GUID-EntidadeId" description="Id"
                   autolink="True" visible="True" />
        <attribute attribute="GUID-EntidadeDescricao" description="Descrição"
                   autolink="True" visible="True" />
      </attributes>
      <!-- Sem <actions> neste nível neste exemplo -->
      <filter>
        <attributes>
          <filterAttribute name="EntidadeDescricao" description="Descrição" default="" />
        </attributes>
        <conditions>
          <condition value="EntidadeDescricao.IndexOf(&amp;EntidadeDescricao) &gt; 0
                            when not &amp;EntidadeDescricao.IsEmpty()" />
        </conditions>
      </filter>
    </selection>

    <view caption="EntidadeDescricao.ToString()" description="Registro"
          backToSelection="True" masterPage="&lt;default&gt;">
      <parameters>
        <parameter name="EntidadeEmpresaId" null="True" />
        <parameter name="EntidadeId" null="True" />
      </parameters>
      <fixedData>
        <attributes>
          <attribute attribute="GUID-EntidadeDescricao" description="Descrição"
                     autolink="True" visible="True" />
        </attributes>
      </fixedData>
      <tabs>
        <!-- Tab Tabular: code="General" é a convenção do padrão -->
        <tab name="Geral" code="General" description="Registro"
             type="Tabular" wcname="EntidadeGeneral">
          <attributes>
            <attribute attribute="GUID-EntidadeEmpresaId" description="Emp.Id"
                       autolink="True" visible="True" />
            <attribute attribute="GUID-EntidadeId" description="Id"
                       autolink="True" visible="True" />
            <attribute attribute="GUID-EntidadeDescricao" description="Descrição"
                       autolink="True" visible="True" />
          </attributes>
          <!-- NÍVEL 2a: ações do DETALHE -->
          <actions>
            <action name="LimpaGridState" caption="#"
                    gxobject="GUID-procLimpaGridState"
                    tooltip="Limpa Filtros na Sessao">
              <parameters>
                <parameter name="&quot;WWEntidade&quot;" />
                <parameter name="false" />
              </parameters>
            </action>
            <action name="Update" />
            <action name="Delete" />
          </actions>
        </tab>
      </tabs>
    </view>
  </level>
</instance>
```

---

## Exemplo sanitizado 2 — Complexo (1 tab Tabular + tabs Grid + tab UserDefined)

Baseado em objetos de 80–115 KB. `<actions>` existe em TRÊS níveis distintos.

```xml
<?xml version="1.0" encoding="utf-16"?>
<instance webFormDefaults="Responsive Web Design" updateTransaction="Apply WW Style">
  <transaction transaction="GUID-Pedido" />
  <level id="GUID-Level:1" name="Pedido">
    <descriptionAttribute attribute="GUID-PedidoNumero" description="Número" />

    <selection description="Pedidos" page="&lt;default&gt;">
      <modes Display="false" Export="false" />
      <attributes>
        <attribute attribute="GUID-PedidoEmpresaId" description="Empresa Id"
                   autolink="True" visible="True" />
        <attribute attribute="GUID-PedidoId" description="Id"
                   autolink="True" visible="True" />
        <attribute attribute="GUID-PedidoNumero" description="Número"
                   autolink="True" visible="True" />
        <!-- variáveis com código GeneXus inline (removidas neste exemplo sanitizado) -->
      </attributes>
      <!-- NÍVEL 1: ações da LISTA (relatórios, exportações, operações em lote) -->
      <actions>
        <action name="LimpaGridState" caption="#"
                gxobject="GUID-procLimpaGridState"
                tooltip="Limpa Filtros na Sessao">
          <parameters>
            <parameter name="&quot;WWPedido&quot;" />
            <parameter name="false" />
          </parameters>
        </action>
        <action name="RelatorioX" caption="Relatório X"
                gxobject="GUID-procRelatorioX" />
        <action name="ExportaPlanilha" caption="Baixar Planilha"
                gxobject="GUID-procExportaPlanilha" />
      </actions>
      <filter>
        <attributes>
          <filterAttribute name="PedidoData" description="Data" default="" />
          <filterAttribute name="PedidoNumero" description="Número" default="" />
        </attributes>
        <conditions>
          <condition value="PedidoData &gt;= &amp;PedidoDataDe
                            when not &amp;PedidoDataDe.IsEmpty()" />
          <condition value="PedidoData &lt; &amp;PedidoDataAte + 1
                            when not &amp;PedidoDataAte.IsEmpty()" />
        </conditions>
      </filter>
    </selection>

    <view caption="PedidoNumero.ToString()" description="Pedido"
          backToSelection="True" masterPage="&lt;default&gt;">
      <parameters>
        <parameter name="PedidoEmpresaId" null="True" />
        <parameter name="PedidoId" null="True" />
      </parameters>
      <fixedData>
        <attributes>
          <attribute attribute="GUID-PedidoNumero" description="Número"
                     autolink="True" visible="True" />
        </attributes>
      </fixedData>
      <tabs>

        <!-- NÍVEL 2a: tab Tabular — code="General" por convenção do padrão -->
        <tab name="Geral" code="General" description="Pedido"
             type="Tabular" wcname="PedidoGeneral">
          <attributes>
            <attribute attribute="GUID-PedidoNumero" description="Número"
                       autolink="True" visible="True" />
          </attributes>
          <actions>
            <action name="Update" />
            <action name="Delete" />
            <action name="RelatorioX" caption="Relatório X"
                    gxobject="GUID-procRelatorioX" />
          </actions>
        </tab>

        <!-- NÍVEL 2b: tab Grid — code é o identificador estável para ancoragem -->
        <tab name="Itens" code="PedidoItens" type="Grid"
             wcname="PedidoPedidoItensWC" page="&lt;unlimited&gt;"
             condition="procEmpresaLiberadaProUsuario(&amp;PedidoEmpresaId)">
          <transaction transaction="GUID-PedidoItens" />
          <modes Insert="false" Update="false" Export="false" />
          <attributes>
            <attribute attribute="GUID-PedidoItensEmpresaId" description="Emp.Id"
                       autolink="True" visible="True" />
            <attribute attribute="GUID-PedidoItensId" description="Id"
                       autolink="True" visible="True" />
          </attributes>
          <!-- NÍVEL 2b: ações específicas do grid filho -->
          <actions>
            <action name="NovoItem" caption="Novo Item"
                    gxobject="GUID-procNovoItem" />
            <action name="RelatorioItens" caption="Relatório de Itens"
                    gxobject="GUID-procRelatorioItens" />
          </actions>
          <orders>
            <order name="Código" isDefault="True">
              <attribute attribute="GUID-PedidoItensCodigo" descending="False" />
            </order>
          </orders>
          <!-- filtro do grid filho — independente do filter da selection -->
          <filter>
            <attributes>
              <filterAttribute name="PedidoItensCodigo" description="Código" default="" />
            </attributes>
            <conditions>
              <condition value="PedidoItensCodigo = &amp;PedidoItensCodigo
                                when not &amp;PedidoItensCodigo.IsEmpty()" />
            </conditions>
          </filter>
        </tab>

        <!-- Tab UserDefined: tipicamente sem <actions> -->
        <tab name="Documentos Fiscais" code="PedidoDocsFiscais"
             type="UserDefined" wcname="PedidoDocsFiscaisWC">
          <!-- conteúdo customizado, sem <actions> neste exemplo -->
        </tab>

      </tabs>
    </view>
  </level>
</instance>
```

---

## Sanitização aplicada nos exemplos

- GUIDs reais substituídos por `GUID-NomeDescritivo`
- Nomes de atributos da KB substituídos por nomes genéricos (`Entidade`, `Pedido`, etc.)
- Código GeneXus inline de `<variable>` removido (substituído por comentário)
- `customStartEventCode` removido
- Estrutura XML, atributos `name`, `code`, `type`, `wcname`, ordem dos elementos e padrão de `<filter>` preservados

---

## Variabilidade entre KBs

- Evidência direta (Gx_wsEducacaoSpTeste): alguns objetos não têm `<actions>` em `<selection>` — o bloco existe apenas em `<tab>`.
- Evidência direta (Gx_FabricaBrasil): 122/184 têm `<actions>` em ambos os níveis; 62/184 têm apenas em `<tab>`.
- Inferência forte: a presença ou ausência de `<actions>` em `<selection>` depende da configuração do padrão WorkWithForWeb para cada objeto, não de uma regra universal.
- Regra operacional: **sempre inspecionar o XML real antes de qualquer inserção textual**; não assumir estrutura a partir do tamanho do arquivo ou do nome do objeto.

---

## Prefixo de GUID de atributo no CDATA

- Nível de confiança: **Inferência forte — evidência de KB externa inspecionada** (OnlineShopSS, GeneXus 18 U9 Build 187794)
- Nos exemplos sanitizados deste documento, os GUIDs de atributo dentro do CDATA são representados como `GUID-NomeAtributo` por clareza.
- Em KBs reais observadas externamente, os valores do atributo `attribute="..."` dentro do CDATA do `WorkWithForWeb` seguem o formato `adbb33c9-0906-4971-833c-998de27e0676-NomeAtributo`, onde `adbb33c9-0906-4971-833c-998de27e0676` é um prefixo fixo do padrão e `NomeAtributo` é o nome do atributo GeneXus.
- Regra operacional: ao construir ou editar o CDATA de um `WorkWithForWeb` sem ter o XML real disponível, usar o prefixo `adbb33c9-0906-4971-833c-998de27e0676-` concatenado ao nome do atributo como melhor inferência; validar com o XML real da KB alvo antes de importar.
