# 01f - Moldes Sanitizados Dados e Design

## Papel do documento
empirico e materializavel

## Objetivo
Concentrar moldes sanitizados ligados a dados declarativos, tema, pacote visual e design system.

## Moldes sanitizados completos de Domain

- Evidência direta: o acervo usado nesta base contem 593 objetos Domain.
- Evidência direta: 229 desses 593 objetos carregam `IDEnumDefinedValues`.
- Evidência direta: entre os dominios enumerados, os perfis mais frequentes do corpus atual sao `bas:VarChar` com `AddEmptyItem=True` (87 casos), `bas:Character` sem `AddEmptyItem` (71 casos) e `bas:Numeric` com ou sem `AddEmptyItem` (28 casos somados).
- Inferência forte: o tipo se divide bem entre dominios escalares simples e dominios enumerados com perfis recorrentes, o que justifica documentar um molde escalar e tres moldes enumerados representativos.

### Molde sanitizado de Domain 1 - `NumeroExemplo`

- Perfil: Domain escalar simples baseado em `bas:Numeric`.
- Uso operacional: boa referencia para dominios pequenos sem enum e sem metadata adicional relevante.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:42.0000000Z" checksum="e69ba129cdc6aa72ddcef4b634ca05bb" fullyQualifiedName="NumeroExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="cab4dbf1-394a-4e5c-bb72-3abf1987f5ea" name="NumeroExemplo" type="00972a17-9975-449e-aab1-d26165d51393" description="NumeroExemplo">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>NumeroExemplo</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:Numeric</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Domain 2 - `DomainExemploPrazoA`

- Perfil: Domain enumerado baseado em `bas:VarChar`, com `IDEnumDefinedValues` e `AddEmptyItem=True`.
- Uso operacional: boa referencia para dominios de selecao controlada compactos, com item vazio explicito e rotulos de negocio curtos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:44.0000000Z" checksum="1e399c871195f8d88f96aca2a24e43ac" fullyQualifiedName="DomainExemploPrazoA" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="6c56169c-5576-42a6-8257-f4aba9fab263" name="DomainExemploPrazoA" type="00972a17-9975-449e-aab1-d26165d51393" description="Domain Exemplo Prazo A">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DomainExemploPrazoA</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:VarChar</Value>
    </Property>
    <Property>
      <Name>Length</Name>
      <Value>6</Value>
    </Property>
    <Property>
      <Name>AttMaxLen</Name>
      <Value>6</Value>
    </Property>
    <Property>
      <Name>IDEnumDefinedValues</Name>
      <Value>Avista, Avista, A Vista; Aprazo, Aprazo, A Prazo</Value>
    </Property>
    <Property>
      <Name>AddEmptyItem</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Domain 3 - `DomainExemploUfA`

- Perfil: Domain enumerado baseado em `bas:Character`, com `IDEnumDefinedValues` e sem `AddEmptyItem`.
- Uso operacional: boa referencia para dominios enumerados compactos, de codigo curto e sem item vazio adicional.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:41.0000000Z" checksum="" fullyQualifiedName="DomainExemploUfA" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="c1f2a054-539e-4e42-9040-d6f4821fd482" name="DomainExemploUfA" type="00972a17-9975-449e-aab1-d26165d51393" description="Domain Exemplo Uf A">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DomainExemploUfA</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:Character</Value>
    </Property>
    <Property>
      <Name>Length</Name>
      <Value>9999</Value>
    </Property>
    <Property>
      <Name>AttMaxLen</Name>
      <Value>9999</Value>
    </Property>
    <Property>
      <Name>IDEnumDefinedValues</Name>
      <Value>AC, AC, AC; AL, AL, AL; AM, AM, AM; AP, AP, AP; BA, BA, BA; CE, CE, CE; DF, DF, DF; ES, ES, ES; GO, GO, GO; MA, MA, MA; MG, MG, MG; MS, MS, MS; MT, MT, MT; PA, PA, PA; PB, PB, PB; PE, PE, PE; PI, PI, PI; PR, PR, PR; RJ, RJ, RJ; RN, RN, RN; RO, RO, RO; RR, RR, RR; RS, RS, RS; SC, SC, SC; SE, SE, SE; SP, SP, SP; TO, TO, TO; EX, EX, EX</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Domain 4 - `DomainExemploOperacaoA`

- Perfil: Domain enumerado baseado em `bas:Numeric`, com `Signed=True`, `IDEnumDefinedValues` e sem `AddEmptyItem`.
- Uso operacional: boa referencia para dominios enumerados numericos, inclusive com valor negativo e metadata adicional no bloco de propriedades.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:35.0000000Z" checksum="802842c8dd4adb494e4040050b7c42fd" fullyQualifiedName="DomainExemploOperacaoA" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="026175fd-e613-4beb-9995-7aa7ecf0a656" name="DomainExemploOperacaoA" type="00972a17-9975-449e-aab1-d26165d51393" description="Domain Exemplo Operacao A">
  <Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c">
    <Help>
      <HelpItem>
        <Language>88313f43-5eb2-0000-0028-e8d9f5bf9588-Portuguese</Language>
        <Content />
      </HelpItem>
    </Help>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DomainExemploOperacaoA</Value>
    </Property>
    <Property>
      <Name>ATTCUSTOMTYPE</Name>
      <Value>bas:Numeric</Value>
    </Property>
    <Property>
      <Name>Length</Name>
      <Value>2</Value>
    </Property>
    <Property>
      <Name>AttMaxLen</Name>
      <Value>2</Value>
    </Property>
    <Property>
      <Name>Signed</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IDEnumDefinedValues</Name>
      <Value>0, Entrada, Entrada; 1, Saida, Saida; -1, SemFiltro, Sem Filtro</Value>
    </Property>
    <Property>
      <Name>NotifyContextChange</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Theme, PackagedModule, DesignSystem e ColorPalette

- Evidência direta: o acervo usado nesta base contem 7 objetos Theme, 16 PackagedModule, 2 DesignSystem e 1 ColorPalette.
- Inferência forte: nesses tipos pequenos vale mais registrar moldes completos representativos do que tentar classificacoes muito finas por familia.

### Molde sanitizado de Theme - `ThemeExemploMobile`

- Perfil: Theme mobile com PredefinedTypes, KmwSchemaVersion e conjunto grande de classes visuais.
- Uso operacional: boa referencia para temas de plataforma e estilos visuais baseados em classes internas.
- Evidência direta: a validacao posterior no acervo real mostrou que classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption` fazem parte do conjunto minimo usado por temas simples validos.
- Inferência forte: ao reduzir este molde, o agente nao deve podar classes apenas por parecerem acessorias; referencias internas entre classes podem quebrar o import mesmo quando o envelope estiver correto.
- Inferência forte: para clonagem segura, preservar `PredefinedTypes`, `Styles` e o grafo minimo de referencias de classe e mais importante do que simplificar agressivamente o XML.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T16:08:29.0000000Z" checksum="4f94c975e75fa53cc0a01dceeefd6fb8" fullyQualifiedName="ThemeExemploMobile" moduleGuid="00000000-0000-0000-0000-000000000000" guid="62516c42-4e89-428c-87ef-2a006971b9b4" name="ThemeExemploMobile" type="c804fdbd-7c0b-440d-8527-4316c92649a6" description="Theme Exemplo Mobile">
  <BaseImagePath />
  <TemplateName />
  <Part type="c31007a6-01d3-4788-95b3-425921d47758">
    <KmwSchemaVersion>3</KmwSchemaVersion>
    <PredefinedTypes>
      <Type ID="Application">
        <Default>Application</Default>
      </Type>
      <Type ID="ApplicationBars">
        <Default>ApplicationBars</Default>
      </Type>
      <Type ID="Animation">
        <Default>Animation</Default>
      </Type>
      <Type ID="Form">
        <Default>Form</Default>
      </Type>
      <Type ID="Attribute">
        <Default>Attribute</Default>
      </Type>
      <Type ID="Button">
        <Default>Button</Default>
      </Type>
      <Type ID="Menu">
        <Default>Menu</Default>
      </Type>
      <Type ID="MenuItem">
        <Default>MenuItem</Default>
      </Type>
      <Type ID="Grid">
        <Default>Grid</Default>
      </Type>
      <Type ID="GridRow">
        <Default>GridRow</Default>
      </Type>
      <Type ID="Group">
        <Default>Group</Default>
      </Type>
      <Type ID="GroupSeparator">
        <Default>GroupSeparator</Default>
      </Type>
      <Type ID="HorizontalLine">
        <Default>HorizontalLine</Default>
      </Type>
      <Type ID="Image">
        <Default>Image</Default>
      </Type>
      <Type ID="Multimedia">
        <Default>Multimedia</Default>
      </Type>
      <Type ID="Progress">
        <Default>Progress</Default>
      </Type>
      <Type ID="Tab">
        <Default>Tab</Default>
      </Type>
      <Type ID="TabPage">
        <Default>TabPage</Default>
      </Type>
      <Type ID="Table">
        <Default>Table</Default>
      </Type>
      <Type ID="TextBlock">
        <Default>TextBlock</Default>
      </Type>
      <Type ID="AudioController">
        <Default>AudioController</Default>
      </Type>
      <Type ID="Matrix">
        <Default>Matrix</Default>
      </Type>
      <Type ID="MatrixAxisLabel">
        <Default>MatrixAxisLabel</Default>
      </Type>
      <Type ID="Rating">
        <Default>Rating</Default>
      </Type>
      <Type ID="Calendar">
        <Default>Calendar</Default>
      </Type>
      <Type ID="PageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="Slider">
        <Default>Slider</Default>
      </Type>
      <Type ID="MapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="MapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="MapPolygon">
        <Default>MapPolygon</Default>
      </Type>
      <Type ID="Switch">
        <Default>Switch</Default>
      </Type>
      <Type ID="ToggleButtonGroup">
        <Default>ToggleButtonGroup</Default>
      </Type>
      <Type ID="SDPageController">
        <Default>PageController</Default>
      </Type>
      <Type ID="SDSlider">
        <Default>Slider</Default>
      </Type>
      <Type ID="SDMapPinImage">
        <Default>MapPinImage</Default>
      </Type>
      <Type ID="SDMapRoute">
        <Default>MapRoute</Default>
      </Type>
      <Type ID="Dashboard">
        <Default>Dashboard</Default>
      </Type>
      <Type ID="DashboardOption">
        <Default>DashboardOption</Default>
      </Type>
    </PredefinedTypes>
    <Styles>
      <GxClass Name="AttributeTitle" Description="Attribute Title" Guid="8a58438a-f492-5f73-99cf-55a2841b213b">
        <Properties>
          <sd_font_size>18dip</sd_font_size>
          <sd_font_style />
        </Properties>
      </GxClass>
      <GxClass Name="AttributeSubtitle" Description="Attribute Subtitle" Guid="9cc07d44-616e-5dfa-8772-15c59fa18c2e">
        <Properties>
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="Button" Description="Button" Guid="abd2de3e-1c96-5681-b52b-bbe33c0dca49">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>#9E9E9E</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>12dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>12dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>12dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>12dip</sd_border_bottom_right_radius>
          <background_color>White</background_color>
          <highlighted_background_color>#0070ED</highlighted_background_color>
          <color>Black</color>
          <highlighted_color>White</highlighted_color>
          <sd_font_size>14dip</sd_font_size>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
      <GxClass Name="Grid" Description="Grid" Guid="e4351147-2c00-5e86-a86c-1b1683dce3d8">
        <Properties>
          <ThemeGridOddRowClassReference>GridRowOdd</ThemeGridOddRowClassReference>
          <ThemeGridEvenRowClassReference>GridRowEven</ThemeGridEvenRowClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="Group" Description="Group" Guid="5b6cae15-fc08-5644-a800-3bafa192ec88">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_top_left_radius>8dip</sd_border_top_left_radius>
          <sd_border_top_right_radius>8dip</sd_border_top_right_radius>
          <sd_border_bottom_left_radius>8dip</sd_border_bottom_left_radius>
          <sd_border_bottom_right_radius>8dip</sd_border_bottom_right_radius>
          <ThemeCaptionClassReference>TextBlockGroupCaption</ThemeCaptionClassReference>
          <ThemeGroupSeparatorClassReference />
          <background_color>white</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="HorizontalLine" Description="Horizontal Line" Guid="1fd49dd6-9a67-5da8-9cec-86596e45e98e">
        <Properties>
          <background_color>Silver</background_color>
        </Properties>
      </GxClass>
      <GxClass Name="Tab" Description="Tab" Guid="41ccdaf1-69f2-55ac-aebd-c82c6cb8c06e">
        <Properties>
          <ThemeSelectedTabPageClassReference>TabPageSelected</ThemeSelectedTabPageClassReference>
          <ThemeUnselectedTabPageClassReference>TabPageUnselected</ThemeUnselectedTabPageClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TableDetail" Description="Table Detail" Guid="f29ce968-0c51-5789-b72a-b00938eb43b7">
        <Properties>
          <background_color>#E0E0E0</background_color>
          <sd_padding_bottom>10dip</sd_padding_bottom>
          <sd_padding_left>10dip</sd_padding_left>
          <sd_padding_right>10dip</sd_padding_right>
          <sd_padding_top>10dip</sd_padding_top>
        </Properties>
      </GxClass>
      <GxClass Name="TableSection" Description="Table Section" Guid="d97cfb58-0788-504c-8882-0413e104c009">
        <Properties>
          <sd_border_style>solid</sd_border_style>
          <sd_border_color>Silver</sd_border_color>
          <sd_border_width>1dip</sd_border_width>
          <sd_border_radius>12dip</sd_border_radius>
          <background_color>White</background_color>
          <sd_row_horizontal_line_separator_table>True</sd_row_horizontal_line_separator_table>
          <ThemeHorizontalLineClassReference>HorizontalLine</ThemeHorizontalLineClassReference>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlock" Description="Text Block" Guid="27607de1-bd65-5b1b-99b8-9db711c42fc6">
        <Properties>
          <color />
        </Properties>
      </GxClass>
      <GxClass Name="CalendarLabel" Description="Calendar Label" Guid="b4e3175c-0c31-5e1d-9195-4b737ad6ff2d">
        <Properties>
          <sd_font_size>34dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockTitle" Description="Text Block Title" Guid="abae902b-d82f-59c6-a3f8-52de01a4a9f2">
        <Properties>
          <color />
          <sd_font_size>18dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockSubtitle" Description="Text Block Subtitle" Guid="ae4cb8a2-9d3d-5a1c-b8b1-427ef274d83f">
        <Properties>
          <color />
          <sd_font_size>14dip</sd_font_size>
        </Properties>
      </GxClass>
      <GxClass Name="TextBlockGroupCaption" Description="Text Block Group Caption" Guid="a7187aa1-d84c-57b0-a3cb-d2942a7818c9">
        <Properties>
          <color>White</color>
          <sd_font_weight>bold</sd_font_weight>
        </Properties>
      </GxClass>
    </Styles>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="43b86e51-163f-44af-ac5a-e101541b1a71">
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>ThemeExemploMobile</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Theme Exemplo Mobile</Value>
    </Property>
    <Property>
      <Name>ThemeType</Name>
      <Value>idSD</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de PackagedModule - `PacoteExemplo.Servicos`

- Perfil: PackagedModule enxuto, organizado como modulo filho com poucos Part type estruturais.
- Uso operacional: boa referencia para empacotamento modular simples sem conteudo interno complexo.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T21:48:25.0000000Z" checksum="" fullyQualifiedName="PacoteExemplo.Servicos" moduleGuid="c940501b-c1aa-4da5-a3ef-e8f497343e2e" guid="4b14738c-7611-4134-ab88-db7d218c8353" name="Servicos" type="c88fffcd-b6f8-0000-8fec-00b5497e2117" description="Servicos" parent="PacoteExemplo" parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117">
  <Part type="ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc">
    <Properties />
  </Part>
  <Part type="a5e6a251-2df0-44d8-adab-1da237574326">
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>Servicos</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
` 

### Molde sanitizado de DesignSystem 1 - `DesignSystemExemploAuth`

- Perfil: DesignSystem enxuto com Styles e imports externos basicos.
- Uso operacional: boa referencia para design system pequeno e focado em overrides localizados.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="GeneXus" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-09-09T13:56:53.0000000Z" checksum="5d6c8e1c33b0aec4d2e8aa9471ab0656" fullyQualifiedName="DesignSystemExemploAuth" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="3050c016-2f23-456f-875c-afc6c6c52aa1" name="DesignSystemExemploAuth" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="Design System Exemplo Auth" parent="PastaExemploDesignSystem" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles DesignSystemExemploAuth
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    .table-login{
        width: 380px;
        padding: 40px 35px 40px 35px;
    }
    .cell-padding-top-label{
        padding-top: 8px;
    }
    .button-add-grid{
        @include Button;
        margin-bottom: -30px !important;
        z-index: 1 !important;
    } 

    .cell-ispassword{
        max-height: 1.5em;
        overflow: hidden;
    }
}

]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DesignSystemExemploAuth</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Design System Exemplo Auth</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>DesignSystem_Samples-web</Categories>
</Object>
` 

### Molde sanitizado de DesignSystem 2 - `dsExemploBase`

- Perfil: DesignSystem mais rico, com 	okens, Styles, imports e muito CSS/Sass customizado.
- Uso operacional: boa referencia para design system extenso com ajustes de layout, componentes e comportamento visual.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-19T15:55:10.0000000Z" checksum="06b5dabbb64ab6e177b8a976cdd4d07f" fullyQualifiedName="dsExemploBase" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="ebbe998c-b28d-4173-a685-d41208d4ce72" name="dsExemploBase" type="78b3fa0e-174c-4b2b-8716-718167a428b5" description="ds Exemplo Base">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[tokens Name {

	#colors
	{
        
        #region Unanimo_Colors
            //primary: #696ef2;
            //secondary: rgba(128 , 0, 6, 1); //#13142c;
        #endregion

        #region Background_Colors
            ///surface: #ffffff;
        #endregion



        //primary-enabled: $colors.primary; 
        //secondary-enabled: $colors.secondary;

        //primary-active: #3015b0;
        //primary-hover: #413cd4;

        //secondary-active: rgba(128 , 0, 6, 1);
        //secondary-hover: rgba(192, 0, 0, 1);

		AzulClaro: #abc;

		//VermelhoEscuro: rgba(173, 8, 8);
        
	}
}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles dsExemploBase
{
    @import PackageExemploUI.UnanimoWeb;
    @import PackageExemploReports.QueryViewerWeb;
    @import PackageExemploReports.DashboardViewerWeb;

    //@import PackageExemploReports.QueryViewer;
    //@import PackageExemploReports.DashboardViewer;

    //nao salvou o problema do conteudo do tab nao aparecer sem clicar.
    //.tab-displayblock{
    //    @include Tab;
    //    display: block;
    //}

    //Para resolver a falta do fundo do item clicado num Dynamic List Box no Google Chrome
    select option {
        background-color: white; //gainsboro; //lightgray;
        color: black;
    }
    select option:checked {
        background-color: dodgerblue; //#007bff;
        color: white;
    }

    DIV.gx-mask
    {
            position: absolute;
            background-color: black;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            animation: entermask 1s;
            -webkit-animation: entermask 1s;
            //opacity: $opacity.mask-opacity;

            z-index: 99;

            background-image: gx-image(Loading_Icon_Exemplo); //(LoadingResults);
            background-repeat: no-repeat;
            background-size: 33%;
            -ms-filter: "alpha(opacity=10)";
            opacity: .20;
            display:inline-block;                      
            background-position: top; //0% 0%;
        }
    .form-group {
        margin-bottom: 1px;
    }

    //usado pelo menos em tables de web components como WCExemploVolumesA, tambem em transacoes
    .form-horizontal .form-group {
        margin-inline-start: 15px;
        margin-inline-end: 15px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em transacoes
    .form-horizontal .form-container .form-group {
        margin-inline-start: 0px;
        margin-inline-end: 0px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    //usado em webpanels com cad-basico
    .form-horizontal .Card-Basico .form-group {
        margin-inline-start: -5px;
        margin-inline-end: -5px;
        border-bottom: lightgray;
        border-bottom-width: 1px;
        border-bottom-style: inset;
    }

    // .gx-form-group {
    //     margin-bottom: 1px;
    // }

    // .form-control-static {
    //     padding-block: 0px;
    //     min-height: 15px;
    //     width: auto !important;
    // }

    //resolve o problema de linha vazia gastar espaco, em campos escondidos de transacoes.
    .col-xs-12.form__cell{
        display:contents !important;
        padding-block: 1px;
    }

    //faz quebrar o texto do cabeÃ§alho de grid como a aba de estoque movto diario de produto
    ///.gx-tab-padding-fix-1.GridTitle{    
    ///    white-space: normal !important;
    ///}

     //.gx-tab-spacing-fix-2.Grid.table-responsive{

     //.gx-grid.gx-standard-grid{
     //    text-align: left;
     //}

    //nao resolveu o problema do prompt no filtro do ww
    // .gx-prompt {
        
    //     content: gx-image(PackageExemploUI.prompt_light); 
    //     z-index: 0;
    //     width: 50px;
    //     height: 50px;

    // }

    //nao funcionou pra resolver o popup no ios
    //.gx-responsive-popup {
    //    height: auto;
    //}
        
    //para permitir popup em iOS    
    @media screen and (max-width: 767px) {
        .gx-responsive-popup.gx-popup {
            height: auto;
        }
        .gx-responsive-popup .gx-popup-content > iframe {
            height: auto;
        }
    }

    .gx-freestyle-grid{
        padding-block: 0px;
        min-height: 15px;
    }

    // .gx-grid .gx-standard-grid {


    // }

   .gx-action-group {
        display: flex; //Ativa Flexbox, permitindo organizaÃ§Ã£o dinÃ¢mica de elementos.
        flex-wrap: wrap; //Permite que os elementos quebrem para a prÃ³xima linha quando o espaÃ§o horizontal acabar.
        justify-content: flex-start; /* Alinha os itens Ã  esquerda */
        gap: $spacing.inline-xl; //usado para definir o espaÃ§amento entre os itens dentro de um container flex
    }

    .gx-grid-paging-bar {
        justify-content:center;
    }


    //.FreeStyleGrid{
        //line-height: 1;
    //}

    // .attribute-label {
    //     padding-top: 0px;
    // }

    //no carmime tem para a classe
    //gx-label col-xs-8 col-sm-3 col-md-2 col-lg-12 AttributeLabel control-label
    //text-align: left!important;

    //legenda de atributo em caso mais especifico, mas alem da transacao
    //.gx-label.col-sm-3.AttributeLabel.control-label {
    //      text-align: right;
    //}

    //nao funciona
    //.form-group.gx-form-group > label.gx-label.col-sm-3.AttributeLabel.control-label {
    //    text-align: right;
    //}
    
    //nao Ã© especifico o sufiente, pra funcionar apenas pra crud de transacao
    //.form-group.gx-form-group label.gx-label.col-sm-3.AttributeLabel.control-label {
    //     //text-align: right;
    //     color: red;
    //}

    //legenda dos campos de atributo , em transacao ou webpanel qualquer
    .gx-label.AttributeLabel {
        padding-top: 0px;
    }
    //ajuste da legenda dos campos da transacao
    .form-container .gx-label.AttributeLabel {
        text-align: right;
        padding-right: 0px;
        padding-left: 0px;
    }

    //legenda dos campos das transacoes, da aba geral
    .gx-label.ReadonlyAttributeLabel {
        padding-top: 0px;
        //text-align: right;
    }

    //usado em legenda de atributo de transacao, na aba geral do ww da transacao
    .form__cell .ReadonlyAttributeLabel {
        padding-inline-start: 15px;
        padding-inline-end: 3px;
        padding-block-start: 1px;
        text-align: right;
    }

    //usado em atributo de transacao, na aba geral do ww da transacao
    .form__cell .form-control-static {
        padding-block: 1px;
        min-height: 15px;
    }

    //Usado em transacao, junto aos atributos. Tambem em TransacaoGeneral, junto aos atributos
    .form__cell {
        padding-block: 1px;
    }
    //usado em transacao, junto aos atributos
    .form__cell-advanced {
        padding-block: 1px;
    }


    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //desligado em 13/05/2025 para depender de outro recurso
    //.Attribute[data-gx-readonly] {
    //   overflow-wrap:normal;
    //}

    ///faz quebrar linha por padrao em grid do ww
    ///.Attribute[data-gx-readonly]{
    ///    white-space: normal;
    ///    overflow-wrap:normal !important;
    ///}

    //funciona pra aba cadastros externos nao ficar com largura fixa nas colunas
    ///.gx-tab-spacing-fix-2.ViewGrid.table-responsive{
    ///    table-layout: auto;
    ///    display:table-caption; 
    ///    white-space:normal !important;
    ///}


//     .ActionButtons {
//     height: 25px;
// }
//     .HideFiltersButton{
//         margin-top: 0px;
//     }

//     .ShowFiltersButton {
//         margin-top: 0px;
//     }



    //usado em tables de filtros do work with, principalmente em grids ww de transacao
    .filters-container--visible {
        top:00;
        padding-inline-start: 10px;
        padding-inline-end: 10px;
    }
    @media screen and (max-width: 767px) {
        .filters-container--visible {
            
            top: 140px;
            max-height: 500px;
            min-height: calc(100vh - 220px);
            overflow-y: auto;
            margin-bottom: 80px; 

            //inset-inline-end: 1px;
            //inset-inline-start: 16px;

            //max-width: 100%;
            //box-sizing: border-box;

            //max-width: 90%;
            //width: 519px; //90%;

        }

        //usado nos filtros verticais do ww transacao
        .ww__filters-cell .filters-container--visible .col-xs-12 {

            justify-content: left;

        }

    }

    // //539px de largura no google chrome do Thinkphone.
    // @media screen and (min-width: 539px) and (max-width: 767px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 519px; //90%;

    //     }
    // }
    // //462 no edge do thinkphone
    // @media screen and (min-width: 462px) and (max-width: 538px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 442px; //90%;

    //     }
    // }
    // //390 google chrome no lg g8
    // @media screen and (min-width: 390px) and (max-width: 461px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 370px; //90%;

    //     }
    // }
    // //378 no firefox do thinkphone
    // @media screen and (min-width: 378px) and (max-width: 389px) {
    //     .filters-container--visible {
            
    //         top: 140px;
    //         max-height: 500px;
    //         min-height: calc(100vh - 220px);
    //         overflow-y: auto;
    //         margin-bottom: 80px; 

    //         //inset-inline-end: 1px;
    //         //inset-inline-start: 16px;

    //         //max-width: 100%;
    //         //box-sizing: border-box;

    //         //max-width: 90%;
    //         width: 358px; //90%;

    //     }
    // }

    
    .TextblockLargeLink {
        @include TextblockLarge;
        color: $colors.AzulClaro;
    }

    .HeaderContainer {
        height: 60px;
    }

    //usado em filtros nos grids ww, como legenda
    .filter-item__label {
        
        //original
        font-family: $fonts.primary-semibold;
        color: $colors.on-background;
        position: relative;
        gx-text-block-link-class: filter-item__link;

        //ajuste
        //color: red;
        height: auto;

    }
    //conteudo
    .filter-item__label strong {
        
        //original
        //font-weight: normal;
        font-family: $fonts.primary-regular;
        padding-inline-start: 5px;

        //ajuste
        font-weight: bold;
        color: blue;
        
        ///nao funciona com padding-inline-start
        ///height: auto;

    }

    //para funcionar prompt em filtros no ww
    .filter-item__cell .input-group span.input-group-btn .btn {
        height: 28px;
        content: gx-image(PackageExemploUI.prompt_light); 
    }

    ///desligado porque parece estar atrapalhando.
    // //para para ww mostrar icone de esconder/mostrar um pouco mais longe do texto
    // .filters-container__item {
    //     padding-right: 11px;
    //     ///height: auto;
    // }
    // .filters-container__item--expanded {
    //     padding-right: 11px;    

    //     //z-index: -1; //nao resolve o problema do prompt no filtro do ww
    //     //position: relative; estraga tudo.
    // }

    // //par para ww esconder e mostrar direito o calendario
    // .filters-container__item .calendar.Calendar {
    //         display:none !important;
    // }
    // .filters-container__item--expanded .calendar.Calendar {
    //         display:block !important;
    // }

    .Grid tr:nth-child(even) {
        background-color: LightGray;
    }

    .Grid th {
        background-color: LightGray;
    }

    // .Grid-Basico {
    //     @include Grid;
    //     //gx-grid-odd-row-class: Grid-Basico-FundoCinza;
    // }
    // .Grid-Basico tr:nth-child(even) {
    //     background-color: Gray;
    // }
    // .Grid-Basico-FundoCinza {
    //     @include Grid;
    //     background-color: Gray;
    // }

    //funciona mudar, mas nao precisou
    // .Title
    // {
     
    //      //original
    //      font-size: $fontSizes.xl;
    //      font-family: $fonts.primary-bold;
    //      display: inline-block;
    //      //color: $colors.on-background;

    //     //ajuste
    //     color: red;

    // }

    .TableTop {
        
        //Original
        margin-bottom: $spacing.stack-l;

       //Ajuste
       //column-gap: $spacing.inline-xl;

    }

    // //table do topo da tela do ww quando ainda usa layout carmine
    .TableTopSearch {
         
        @include TableTop; 
        
        //nao adianta colocar mais nada, pois o form layout carmine usa colunas fixas
        //background-color: red;
        
    }
    //@media screen and (max-width: 767px) {
    //    .TableTopSearch {
    //        ;
    //    }
    //}

    .Card-Basico {
        @include Table;
        //border: 1px solid $colors.gray02;

        background-color: White;
        box-shadow: 1px 1px 1px 0px DarkGray;

        border-style: solid;
        border-width: 1px;
        border-radius: 5px;
        border-color: DarkGrey;

        padding-left: 5px;
        padding-right: 5px;
        padding-top: 2px;
        padding-bottom: 2px;
        
        margin-bottom: 2px;
        margin-top: 2px;

        line-height: 1.14;

    }
    .CardPesando {
        @include Card-Basico;
        background-color: LightGrey;

    }
    .CardErro {
        @include Card-Basico;
        background-color: Thistle;

    }
    .CardNovo {
        @include Card-Basico;
        background-color: AliceBlue;

    }
    .CardCarregado {
        @include Card-Basico;
        background-color: LightYellow;

    }
    .CardSalvo {
        @include Card-Basico;
        background-color: Lavender;

    }


    .Button {
        white-space: normal;
        height: auto; //28px;
        padding-inline-start: $spacing.inset-m;
        padding-inline-end: $spacing.inset-m;
        border-radius: $radius.l;
        min-width: auto; //80px;

        //button primary defaults
        background-color: $colors.primary;
        font-size: $fontSizes.s;
        font-family: $fonts.primary-semibold;
        color: $colors.on-primary;
        text-transform: uppercase;
        border: solid $borders.extra-small;

        gx-button-hovered-class: button-primary--hover;
        gx-button-focused-class: button-primary--focused;
        gx-button-highlighted-class: button-primary--active;
        gx-button-disabled-class: button-primary--disabled;

    }

    //.Button_2xHeight {
    //    @include Button;
    //    height: 56px;
    //}
    .ButtonHtmlExtensao {
        @include Button;
    }

    .Altura_64px {
        height: 64px;
    }

    .Altura_100px {
        height: 100px;
    }

    .Largura_64px {
        width: 64px;
    }

    .Largura_100px {
        width: 100px;
    }
    
    .LarguraMinima_50px {
        min-width: 50px;
    }

    .LarguraMinima_85px {
        min-width: 85px;
    }

    .LarguraMinima_100px {
        min-width: 100px;
    }

    .LarguraMinima_150px {
        min-width: 150px;
    }

    .LarguraMinima_200px {
        min-width: 200px;
    }

    .LarguraMinima_250px {
        min-width: 250px;
    }

    .LarguraMinima_300px {
        min-width: 300px;
    }

    .LarguraMaxima_250px {
        max-width: 250px;
    }

    #region varia pelo tamanho da tela
    
    //padrao pra telas acima de 1600px ( mas testando em 1920 px de largura )
    .LarguraMinima_ConformeTela {
        min-width: 450px;
    }

    //padrao pra telas de 1200 atÃ© 1599 px ( mas testando em 1366 px de largura )
    @media screen and (min-width: 1200px) and (max-width: 1599px) {
        .LarguraMinima_ConformeTela {
            min-width: 300px;
        }
    }

    //padrao pra telas de 992 atÃ© 1199 px ( mas testando em 1024 px de largura )
    @media screen and (min-width: 992px) and (max-width: 1199px) {
        .LarguraMinima_ConformeTela {
            min-width: 150px;
        }
    }

    //padrao pra telas de 768 atÃ© 991 px ( mas testando em 800 px de largura )
    @media screen and (min-width: 768px) and (max-width: 991px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    //@media (max-width: 767px) {
    //padrao pra telas atÃ© 767 px  ( mas testando em 360 px que imita celular em retrato )  
    @media screen and (max-width: 767px) {
        .LarguraMinima_ConformeTela {
            min-width: 10px; //praticamente sem minimo
        }
    }

    #endregion

    .Largura_AjustaPeloConteudo {
        width: fit-content;
    }

    // //toda tentativa falhou, nao escondendo o date picker
    // .DatePickerDesligado {
    //     //pointer-events: none;   //evitaria clicar no campo
    //     //appearance: textfield; /* Remove o estilo de datepicker */
    //     gx-hide-date-time-picker: True;
    // }

    #region Classes para Column Class

        .WWColumn {
            @include column;
            overflow: hidden;
        }        
        .WWColumnTamanhoLimitado {
            @include WWColumn;
            max-width: 150px;
        }

        .WWColumnTamanhoLimitado100px {
            @include WWColumn;
            max-width: 100px;
        }

        .WWColumnTamanhoLimitado75px {
            @include WWColumn;
            max-width: 75px;
        }

        .WWOptionalColumnTamanhoLimitado300 {
            
            @include column;
            max-width: 300px;

        }
        @media screen and (max-width: 767px) {

            .WWOptionalColumnTamanhoLimitado300 {
                
                //@include OptionalColumn; //nao deixa incluir
                display: none;

            }

         }

    #endregion

    //funciona pra aba cadastros externos nao ficar fixa
    .gx-tab-spacing-fix-2.ViewGrid.table-responsive{
        table-layout: auto;
        display:table-caption; 
        white-space:normal !important;
    }

    .ww__grid {
       table-layout: auto;
       
       display:table-caption; //tira o espaco extra na primeira coluna e deixa de fora, Ã  direita do grid.
       
       //width: auto; //nao resolveu
    }
    .ww__grid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ww__grid th {
        background-color: LightGray;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab {
       height: 5px;
    }

    //usado no tab de abas do view transaction com ww web
    .ww__view__tab .tab-content {
        padding: 0px;
        padding-top: 5px;
        padding-bottom: 5px;
        padding-left: 0px;
        padding-right: 0px;
    }
        
    //usado no tab de abas do view transaction com ww web    
    .ww__view__tab__form-container {
        padding-inline-start: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
        padding-inline-end: 15px; //00 causa desalinhamento das abas originais do ww nas transacoes
    }

    // .gx_usercontrol gx-basic-tab ww__view__tab {
    //     //height: 12px;
    //     padding: 0px;
    // }

    // .div.ww__view__tab UL.nav-tabs {
    //     height: 12px;
    // }

    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI A {
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs LI {
        //height: 12px;
        padding: 1px;
    }
    //usado nas tabs das views de transacao com ww web
    div.ww__view__tab UL.nav-tabs {
        //height: 12px;
        margin-top: 0px;
    }

    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table { 
        height: 22px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .heading-01 {
        font-size: 14px;
    }
    //usado no flex table de dados fixos de view transation com ww web
    .ww__view__title-table .form-control-static {
        
        height: 14px;
        min-height: 14px;
        max-height: 14px;
        padding-block: 0px;

    }


    // //para os campos de dados fixos das Views das transacoes com Work With Web
    // //tambem serve pra ww de transacacoes, pra mostrar o nome da pagina com o grid
    // //tambem pra paginas de edicao de transacoes
    // .heading-01 {
    //     font-size: 12px;
    // }

    //usado no table top do transacao general com ww web, pra mostrar link pra voltar pro grid
    .ww__actions-container {
        margin-bottom: 0px;
    }

    //container do grid em objetos ww
    // .ww__grid-container {
    //     width: auto;
    // }

    //usado em tables de grid do work with
    .ww__grid-cell--expanded .container-fluid {
        padding-inline-start: 1px;
    }

    .WorkWith,.PromptGrid,.ViewGrid {
        
        //original unanimoweb
        text-align: start;
        //table-layout: fixed;
        border-collapse: collapse;

        //ajustado
        table-layout: auto;
        display:table-caption; 
        width:auto;

    }
    .WorkWith tr:nth-child(even) {
        background-color: LightGray;
    }
    .WorkWith th {
        background-color: LightGray;
    }
    .PromptGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .PromptGrid th {
        background-color: LightGray;
    }
    .ViewGrid tr:nth-child(even) {
        background-color: LightGray;
    }
    .ViewGrid th {
        background-color: LightGray;
    }

    .DescriptionAttribute a{
        
        //original unanimoweb
        color: $colors.primary-enabled; 
        text-decoration: underline;

        //ajustado
        white-space: nowrap;

    }
    .DescriptionAttribute a:hover {
        
        //original unanimoweb
        color: $colors.border-primary-hover;

        //ajustado
        white-space:normal;

    }

    .Attribute {

        //Original
        // min-height: 28px;
        // max-width: 100%;
        // font-family: $fonts.primary-regular;
        // font-size: $fontSizes.s;
        // padding-inline-start: $spacing.inset-s;
        // padding-inline-end: $spacing.inset-s;
        // border-color: $colors.gray04;
        // color: $colors.on-background;
        // background-color: $colors.attribute-bg;
        // border-radius: $radius.l;
        // gx-attribute-focused-class: AttributeFocusedClass;
        // gx-readonly-class: ROAttribute;
        // gx-label-class: attribute-label;
        // gx-datepicker-image-class: datepicker-image;
        // gx-prompt-image-class: gx-prompt;

        //Ajustes
        white-space: nowrap; //nao quebra em linhas, igual estÃ¡ no carmine
        
        //nao funciona
        //gx-hide-date-time-picker: True;

    }

    //funciona pra evitar quebrar coluna no grid indevidamente, como quebra de id ou data.
    //.AttributeQuebraLinha[data-gx-readonly] {
    //   overflow-wrap:normal !important;
    //}

    
    //resolve o problema de largura 100% em campo de transacao unanimo chamada de pagina do carmine
    .Attribute.form-control{
     
        @include Attribute;
     
        width: auto !important;

        height:auto;

    }
    
    //coluna em wwgrid para atributo marcado como descricao
    .attribute-description {
        white-space: nowrap; //nao quebra em linhas
    }

    .AttributeTextoPreservado {
        white-space: pre;
    }
    
    .AttributeQuebraLinha {
        @include Attribute;
        
        white-space: normal !important;
        
        //overflow-wrap:normal !important; //funciona, mas sobra espaco na linha
        overflow-wrap:break-word !important;
        
        //display: inline-block; //nao ajuda a melhorar a quebra
        //min-width: 300px; //nao funciona aqui

    }

    .AttributeQuebraLinhaApenasAteWidth1199px {
        
        @include Attribute;
        
    }
    @media screen and (max-width: 1199px) {

        .AttributeQuebraLinhaApenasAteWidth1199px {
            
            min-height: 28px;
            max-width: 100%;
            font-family: $fonts.primary-regular;
            font-size: $fontSizes.s;
            //padding-inline-start: $spacing.inset-s;
            //padding-inline-end: $spacing.inset-s;
            //border-color: $colors.gray04;
            //color: $colors.on-background;
            //background-color: $colors.attribute-bg;
            //border-radius: $radius.l;
            //gx-attribute-focused-class: AttributeFocusedClass;
            //gx-readonly-class: ROAttribute;
            //gx-label-class: attribute-label;
            //gx-datepicker-image-class: datepicker-image;
            //gx-prompt-image-class: gx-prompt;
            
            white-space: normal !important;
            overflow-wrap:break-word !important;

        }

    }

    //usada pelo ww com form layout carmine
    .FilterAttribute {
        
        @include Attribute;
        //overflow: hidden;

        //copiado de attribute-filter:
        //gx-label-class: attribute-label;
        width: 100%;
        //font-family: $fonts.primary-regular;
        //font-size: $fontSizes.s;
        padding-inline-start: $spacing.inset-s;
        padding-inline-end: $spacing.inset-s;
        //gx-attribute-focused-class: AttributeFocusedClass;
        //background-color: $colors.attribute-bg;

    }
    //usada pelo ww com form layout carmine
    .FilterComboAttribute {
        
        @include FilterAttribute;

    }

    // .WWAdvancedLabel {
    //     color: red;
    // }
    // .WWFilterLabel {
    //     color: blue;
    // }


    .AttributeSenha {
        @include Attribute;
        -webkit-text-security:disc !important;
    }

    .AttributeAvisos {
        @include Attribute;
        height: auto;
        width: auto;
    }

    .AttributeMessagesNormal{
        //@include Attribute;
        color: ForestGreen !important;
    }

    .AttributeMessagesAlertaExtremo{
        //@include Attribute;
        color: OrangeRed !important;

    }

    .AttributeMessagesAlerta{
        //@include Attribute;
        color: DarkOrange !important;
    }

    .AttributeMessagesErro{
        //@include Attribute;
        color: rgb(210, 4, 45) !important;

    }

    .AttributeMessagesInfo{
        //@include Attribute;
        color: Black !important;

    }

    .AttributeMessagesSeparador{
        //@include Attribute;
        color: Silver !important;
        background-color: Silver !important;

    }


    // .column {
    //     @include column;
    //         width: 100%;  
    //         padding-inline-start: $spacing.inset-s;
    //         padding-inline-end: $spacing.inset-s;
    //         border-bottom-width: 1px;
    //         border-bottom-color: $colors.gray01;
    //         border-bottom-style:solid;
    //         gx-grid-column-header-class: column;
    // } 

    //.GridColuna-Opcional {
    //    overflow: hidden;  //NAO ESCONDE COISA NENHUMA !
    //    color: $colors.on-background;
    //}

    // .blink {
    // animation: blink 1s steps(1, end) infinite;
    // }
    .blink {
    animation: blink 1s infinite;
    }

    @keyframes blink {
        0% {
            opacity: 1;
            }
        50% {
            opacity: 0;
        }
        100% {
            opacity: 1;
        }
    }

}]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="36982745-cb77-47a3-bc04-9d0d764ff532">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/design-system-migration]]></InnerHtml>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>dsExemploBase</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>

` 

### Molde sanitizado de ColorPalette - `PaletteExemplo`

- Perfil: ColorPalette simples, com conjunto de cores nomeadas em PaletteColors.
- Uso operacional: boa referencia para paletas enxutas baseadas apenas em nomes e cores hexadecimais.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-08-16T16:51:47.0000000Z" checksum="2ccb44e8b9d067e4056a4eae8fa03a75" fullyQualifiedName="PaletteExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7bdd2542-2a09-4884-90d6-e1dafe4a4391" name="PaletteExemplo" type="3affc0b3-494b-4d84-9ec1-3a6ab8349cda" description="PaletteExemplo">
  <Part type="5d481862-64bc-4e88-8af2-e21c276dab77">
    <PaletteColors>
      <PaletteColor name="Text" color="#2A3143" />
      <PaletteColor name="Base" color="#2457A7" />
      <PaletteColor name="DarkBase" color="#163B72" />
      <PaletteColor name="Dominant" color="#9FD3FF" />
      <PaletteColor name="Read Only Text" color="#EAEAEA" />
      <PaletteColor name="Action" color="#0C8C74" />
      <PaletteColor name="SecondaryAction" color="#5B6EF5" />
      <PaletteColor name="Border" color="#EFEFEF" />
      <PaletteColor name="DarkBorder" color="#B7B7B7" />
      <PaletteColor name="Background" color="#F9F9F9" />
      <PaletteColor name="MessageBackground" color="#FFFEBC" />
      <PaletteColor name="LightMessageBackground" color="#FFFFE1" />
      <PaletteColor name="RecentLink" color="#3D434F" />
      <PaletteColor name="WarningColor" color="#FF8000" />
    </PaletteColors>
    <Properties />
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PaletteExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

