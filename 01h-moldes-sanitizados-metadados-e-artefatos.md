# 01h - Moldes Sanitizados Metadados e Artefatos

## Papel do documento
empirico e materializavel

## Objetivo
Concentrar moldes sanitizados de metadados, artefatos auxiliares, identidade estrutural e exemplos minimos de compatibilidade de `Source`.

## Moldes sanitizados completos de ThemeColor

### Molde sanitizado de ThemeColor 1 - `CorAcaoExemplo`

- Perfil: ThemeColor raiz extremamente enxuto, sem `Part` internas adicionais.
- Uso operacional: boa referencia para entradas simples de paleta tematica.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-03-12T17:40:30.0000000Z" checksum="b17ddaa4991114c1378fcb07dc0c2475" fullyQualifiedName="CorAcaoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="ce3a249f-a6aa-4ab3-9a13-9663409d441b" name="CorAcaoExemplo" type="5592de59-d30a-499d-9100-a7006d3674f2" description="CorAcaoExemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>CorAcaoExemplo</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de ThemeColor 2 - `CorAlertaExemplo`

- Perfil: ThemeColor raiz paralela ao primeiro molde, mudando apenas identidade nominal.
- Uso operacional: boa referencia para duplicacao controlada de entradas de cor com mesma assinatura estrutural.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-03-21T15:49:40.0000000Z" checksum="0f7c966ebc90a770da7aaac3a5c86ed3" fullyQualifiedName="CorAlertaExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="08bbf1e9-a441-45a3-abeb-5288e07b0b76" name="CorAlertaExemplo" type="5592de59-d30a-499d-9100-a7006d3674f2" description="CorAlertaExemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>CorAlertaExemplo</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de Document

### Molde sanitizado de Document 1 - `DocumentoReferenciaExemplo`

- Perfil: Document enxuto, com um unico bloco `InnerHtml` curto e referencia textual simples.
- Uso operacional: boa referencia para documentos de anotacao, links ou lembretes tecnicos curtos.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-11-23T15:47:23.0000000Z" checksum="" fullyQualifiedName="DocumentoReferenciaExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="b8f276b6-f342-4740-901a-94eda21fa7c4" name="DocumentoReferenciaExemplo" type="faeb588c-dcce-4dad-9af3-cdd11b961a32" description="Documento Referencia Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/tools/xsd-generator]]></InnerHtml>
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
      <Value>DocumentoReferenciaExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Document 2 - `DocumentoNotasExemplo`

- Perfil: Document mais rico, com HTML maior e varias anotacoes internas.
- Uso operacional: boa referencia para documentos de observacoes, instrucoes e listas de itens em HTML embutido.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-03-09T01:02:26.0000000Z" checksum="0895e8d40b56f1d73cabc8531bbfc84e" fullyQualifiedName="DocumentoNotasExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f412243c-32fb-4945-9112-bdd66d0e31d6" name="DocumentoNotasExemplo" type="faeb588c-dcce-4dad-9af3-cdd11b961a32" description="DocumentoNotasExemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[<P>AMBIENTE DE EXEMPLO:</P>
<P>DIRECTORY: SANITIZED-DIRECTORY-ID</P>
<P>USER ID: SANITIZED-USER-ID</P>
<P>repository id: SANITIZED-REPOSITORY-ID</P>
<P>&nbsp;</P>
<P>Bibliotecas externas que exigem revisao na migracao:</P>
<P>BibliotecaA.dll e BibliotecaB.dll</P>
<P>&nbsp;</P>
<P>&nbsp;</P>
<P>Classes e estilos ajustados em uma revisao de tema:<BR>Attribute, ActionButtons, ActiunButtonsHovered, BtnLogin, WorkWith, PromptGrid, ViewGrid, WWColumn, FormCell, WWGridCell, ViewGridCellAdvanced, WWGridCellExpanded, HeaderContainer, WWAdvancedContainer, WWTabPage, WWTabePageHovered, Label, TextBlockHeader, nav, col-sm-8, col-sm-offset-2, col-xs-offset-1, control-label, Rules, ExtraSmall, Small, form-control-static, form-group, form-horizontal, gx-button, P e WWAdvancedContainer.container-fluid.</P>]]></InnerHtml>
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
      <Value>DocumentoNotasExemplo</Value>
    </Property>
    <Property>
      <Name>IsDocumentoNotasExemplo</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de DataSelector

### Molde sanitizado de DataSelector 1 - `dsMovimentoAtivoOuCanceladoExemplo`

- Perfil: DataSelector enxuto com duas `Condition`, uma variavel booleana e um `InnerHtml` curto de apoio.
- Uso operacional: boa referencia para filtros binarios simples e seletores com uma unica variavel de entrada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="702d2e19-b267-4c25-ae37-0e2ef9e330a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2020-12-23T03:16:25.0000000Z" checksum="faa11acd91e9338faa49bd9fd6cd07ea" fullyQualifiedName="dsMovimentoAtivoOuCanceladoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="438f9146-d6c2-4427-ab41-bf1ed620b571" name="dsMovimentoAtivoOuCanceladoExemplo" type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af" description="Movimento Ativo ou Cancelado Exemplo" parent="RegistroMovimento" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a2bc65a1-999f-4e9b-b837-72285cc9bb16">
    <Level>
      <Condition>
        <Source><![CDATA[RegistroMovimentoCancelado 		= false or RegistroMovimentoCancelado.IsNull() when not &SomenteCancelados
	
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[RegistroMovimentoCancelado 		= true when &SomenteCancelados
]]></Source>
      </Condition>
    </Level>
    <Variables type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
      <Variable Name="SomenteCancelados">
        <Documentation />
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>SomenteCancelados</Value>
          </Property>
          <Property>
            <Name>idBasedOn</Name>
            <Value>Domain:Logico</Value>
          </Property>
        </Properties>
      </Variable>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variables>
    <Parameters>
      <Parameter>
        <Type>Variable</Type>
        <Name>SomenteCancelados</Name>
        <Description>Somente Cancelados</Description>
      </Parameter>
    </Parameters>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[https://example.org/docs/data-selector-note]]></InnerHtml>
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
      <Value>dsMovimentoAtivoOuCanceladoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Movimento Ativo ou Cancelado Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataSelector 2 - `dsRegistrosPorMovimentoExemplo`

- Perfil: DataSelector denso, com muitas `Condition`, `Variables` customizadas e filtro parametrico mais rico.
- Uso operacional: boa referencia para seletores baseados em varias condicoes combinadas e SDT de parametros.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="988004e2-6090-42c3-9603-c073172b75a6" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-12-23T13:38:47.0000000Z" checksum="70d20e81967466e858649307c9e679f3" fullyQualifiedName="dsRegistrosPorMovimentoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="3e3c9034-b9dd-44cf-9d5a-97b37c606153" name="dsRegistrosPorMovimentoExemplo" type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af" description="ds Registros Por Movimento Exemplo" parent="Registro" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a2bc65a1-999f-4e9b-b837-72285cc9bb16">
    <Level>
      <Condition>
        <Source><![CDATA[MovimentoEmpresaId = &sdtRegistroParametros.EmpresaId when not &sdtRegistroParametros.EmpresaId.IsEmpty() and not &sdtRegistroParametros.FiltrarPelaEntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoEmpresaId in &sdtRegistroParametros.listaEmpresaOrcamentosId when &sdtRegistroParametros.EmpresaId.IsEmpty() and not &sdtRegistroParametros.FiltrarPelaEntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeEmpresaId = &sdtRegistroParametros.EntidadeEmpresaId
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeAtivoFaturamentoMunicipioId = &sdtRegistroParametros.MunicipioId when not &sdtRegistroParametros.MunicipioId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoCancelado = false or MovimentoCancelado.IsNull()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCancelado = false or MovimentoRegistroCancelado.IsNull()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipo = &sdtRegistroParametros.TipoRegistro when not &sdtRegistroParametros.TipoRegistro.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoTipo = TipoProcesso.Composicao or MovimentoProcessoTipo = TipoProcesso.Acrescimo or MovimentoProcessoTipo = TipoProcesso.Reducao when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and (&sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Pendente or &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Entrada);
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoTipo = TipoProcesso.Baixa when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Baixado;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCodigoHistoricoExterno = &sdtRegistroParametros.codigoHistoricoExterno when not &sdtRegistroParametros.codigoHistoricoExterno.IsEmpty() and &sdtRegistroParametros.codigoHistoricoExterno > 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCodigoHistoricoExterno.IsEmpty() when not &sdtRegistroParametros.codigoHistoricoExterno.IsEmpty() and &sdtRegistroParametros.codigoHistoricoExterno < 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeId = &sdtRegistroParametros.EntidadeId when not &sdtRegistroParametros.EntidadeId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procInscricaoFederalFormatada(MovimentoRegistroEntidadeInscricaoFederal) = &sdtRegistroParametros.EntidadeInscricaoFederal when not &sdtRegistroParametros.EntidadeInscricaoFederal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaId.IsEmpty() or MovimentoRegistroDocumentoOperacionalSaidaId.IsNull() or MovimentoRegistroTipoDocumentoSaida <> &sdtRegistroParametros.aIgnorarTipoDocumentoSaida when not &sdtRegistroParametros.aIgnorarTipoDocumentoSaida.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoSaida = &sdtRegistroParametros.TipoDocumentoSaida when not &sdtRegistroParametros.TipoDocumentoSaida.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaId = &sdtRegistroParametros.DocumentoSaidaId when &sdtRegistroParametros.DocumentoSaidaId > 0
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[PRCExemploAgenteDocumentoSaidaA(MovimentoRegistroDocumentoOperacionalSaidaEmpresaId, MovimentoRegistroDocumentoOperacionalSaidaId) = &sdtRegistroParametros.AgenteId when not &sdtRegistroParametros.AgenteId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[(not MovimentoRegistroDocumentoOperacionalId.IsEmpty() and not MovimentoRegistroDocumentoOperacionalId.IsNull() and 
	MovimentoRegistroDocumentoOperacionalResponsavelId = &sdtRegistroParametros.DFResponsavelId
) or
(	(MovimentoRegistroDocumentoOperacionalId.IsEmpty() or MovimentoRegistroDocumentoOperacionalId.IsNull()) and
	not MovimentoRegistroDocumentoOperacionalSaidaTipo.IsEmpty() and not MovimentoRegistroDocumentoOperacionalSaidaTipo.IsNull() and
	not MovimentoRegistroPedidoId.IsEmpty() and not MovimentoRegistroPedidoId.IsNull() and
	PRCExemploResponsavelPedidoA(MovimentoRegistroDocumentoOperacionalSaidaTipo, MovimentoRegistroPedidoEmpresaId, MovimentoRegistroPedidoId, MovimentoRegistroPedidoTipo) = &sdtRegistroParametros.DFResponsavelId
)
when not &sdtRegistroParametros.DFResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeResponsavelId = &sdtRegistroParametros.EntidadeResponsavelId or
(	MovimentoRegistroEntidadeSetorVendedorId = &sdtRegistroParametros.EntidadeResponsavelId and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.EntidadeResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalId > 0 and MovimentoRegistroDocumentoOperacionalResponsavelId in &sdtRegistroParametros.ResponsaveisDoSupervisor when not &sdtRegistroParametros.DFResponsavelSupervisorId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeResponsavelId in &sdtRegistroParametros.ResponsaveisDoSupervisor or
(	MovimentoRegistroEntidadeSetorVendedorId in &sdtRegistroParametros.ResponsaveisDoSupervisor and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.EntidadeResponsavelSupervisorId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoData >= &sdtRegistroParametros.DataInicial when not &sdtRegistroParametros.DataInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoData <= &sdtRegistroParametros.DataFinal when not &sdtRegistroParametros.DataFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroData >= &sdtRegistroParametros.RegistroDataInicial when not &sdtRegistroParametros.RegistroDataInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroData <= &sdtRegistroParametros.RegistroDataFinal when not &sdtRegistroParametros.RegistroDataFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroVencimento >= &sdtRegistroParametros.VencimentoInicial  when not &sdtRegistroParametros.VencimentoInicial.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroVencimento <= &sdtRegistroParametros.VencimentoFinal when not &sdtRegistroParametros.VencimentoFinal.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoId = &sdtRegistroParametros.ProcessoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.ProcessoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[not MovimentoRegistroSaldoValor.IsEmpty() or not MovimentoRegistroDiferencaComposicao.IsEmpty() when &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Pendente;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDiferencaComposicao.IsEmpty() when &sdtRegistroParametros.SituacaoRegistro = SituacaoRegistro.Entrada
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procEntidadeTemUmPapel(MovimentoRegistroEntidadeEmpresaId, MovimentoRegistroEntidadeId, &sdtRegistroParametros.EntidadePapel) when not &sdtRegistroParametros.EntidadePapel.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeSetorId = &sdtRegistroParametros.SetorId when not &sdtRegistroParametros.SetorId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoGrupoId = &sdtRegistroParametros.ProcessoGrupoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.ProcessoGrupoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalResponsavelId in &sdtRegistroParametros.ResponsaveisDoUsuario or
MovimentoRegistroEntidadeResponsavelId in &sdtRegistroParametros.ResponsaveisDoUsuario or
(	MovimentoRegistroEntidadeSetorVendedorId in &sdtRegistroParametros.ResponsaveisDoUsuario and
	(MovimentoRegistroEntidadeResponsavelId.IsEmpty() or MovimentoRegistroEntidadeResponsavelId.IsNull())
)
when not &sdtRegistroParametros.UsuarioTodosResponsaveisLiberados and not &sdtRegistroParametros.semControleResponsaveisDoUsuario;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroCondicaoOperacional = &sdtRegistroParametros.CondicaoOperacional when not &sdtRegistroParametros.CondicaoOperacional.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalId = &sdtRegistroParametros.TipoDocumentoId when not &sdtRegistroParametros.TipoDocumentoId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalSaidaEmpresaId > 0 and MovimentoRegistroDocumentoOperacionalSaidaId > 0 and MovimentoRegistroTipoDocumentoSaida = TipoDocumentoSaida.DocumentoOperacionalA			 
when not &sdtRegistroParametros.AgentePrestouContas.IsEmpty() or not &sdtRegistroParametros.PrestacaoContasComObservacao.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoAgenteId = &sdtRegistroParametros.MovimentoAgenteId when not &sdtRegistroParametros.MovimentoAgenteId.IsEmpty()
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroPrevisaoBaixaContaEmpresaId = &sdtRegistroParametros.RegistroPrevisaoBaixaContaEmpresaId 
when not &sdtRegistroParametros.RegistroPrevisaoBaixaContaEmpresaId.IsEmpty() and not &sdtRegistroParametros.RegistroPrevisaoBaixaContaId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroPrevisaoBaixaContaId = &sdtRegistroParametros.RegistroPrevisaoBaixaContaId 
when not &sdtRegistroParametros.RegistroPrevisaoBaixaContaId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroEntidadeProprietarioId = &sdtRegistroParametros.EntidadeProprietarioId or MovimentoRegistroEntidadeId = &sdtRegistroParametros.EntidadeProprietarioId
when not &sdtRegistroParametros.EntidadeProprietarioId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroSaiNoRelatorioMutuoTradicional when &sdtRegistroParametros.RegistroSaiNoRelatorioMutuoTradicional
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoProcessoSaiNoRelatorioResumoFaturamento when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and &sdtRegistroParametros.SaiNoRelatorioResumoFaturamento;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[procProcessoComItemAlgumaContaAlmejada(MovimentoProcessoEmpresaId, MovimentoProcessoId, &sdtRegistroParametros.ProcessoItemContaEmpresaId, &sdtRegistroParametros.ProcessoItemContaId, &sdtRegistroParametros.ProcessoItemContaClassificacao, &sdtRegistroParametros.ProcessoItemContaReduzido) 
when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and (not &sdtRegistroParametros.ProcessoItemContaId.IsEmpty() or not &sdtRegistroParametros.ProcessoItemContaClassificacao.IsEmpty() or not &sdtRegistroParametros.ProcessoItemContaReduzido.IsEmpty());
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalFormularioOperacional = FormularioOperacional.DocumentoCobrancaBancario and procDocumentoCobrancaIdDeUmRegistroId(MovimentoRegistroEmpresaId, MovimentoRegistroId, false, false) > 0 
when &sdtRegistroParametros.ComDocumentoCobranca = SimOuNao.Sim;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroTipoDocumentoOperacionalFormularioOperacional <> FormularioOperacional.DocumentoCobrancaBancario or procDocumentoCobrancaIdDeUmRegistroId(MovimentoRegistroEmpresaId, MovimentoRegistroId, false, false) = 0 
when &sdtRegistroParametros.ComDocumentoCobranca = SimOuNao.Nao;
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoCentroResultadoId = &sdtRegistroParametros.CentroResultadoId when &sdtRegistroParametros.VersaoRelatorioRegistros <> VersaoRelatorioRegistros.PorProcesso and not &sdtRegistroParametros.CentroResultadoId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroDocumentoOperacionalId.IsEmpty() or MovimentoRegistroDocumentoOperacionalId.IsNull() or MovimentoRegistroDocumentoOperacionalResponsavelId <> &sdtRegistroParametros.aIgnorarDFResponsavelId when not &sdtRegistroParametros.aIgnorarDFResponsavelId.IsEmpty();
]]></Source>
      </Condition>
      <Condition>
        <Source><![CDATA[MovimentoRegistroAgrupadorOperacional = &sdtRegistroParametros.AgrupadorOperacional when not &sdtRegistroParametros.AgrupadorOperacional.IsEmpty();
]]></Source>
      </Condition>
    </Level>
    <Variables type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
      <Variable Name="sdtRegistroParametros">
        <Documentation />
        <Properties>
          <Property>
            <Name>Name</Name>
            <Value>sdtRegistroParametros</Value>
          </Property>
          <Property>
            <Name>ATTCUSTOMTYPE</Name>
            <Value>sdt:sdtRegistroParametros</Value>
          </Property>
        </Properties>
      </Variable>
      <Properties>
        <Property>
          <Name>IsDefault</Name>
          <Value>False</Value>
        </Property>
      </Properties>
    </Variables>
    <Parameters>
      <Parameter>
        <Type>Variable</Type>
        <Name>sdtRegistroParametros</Name>
        <Description>sdt Registro Parametros</Description>
      </Parameter>
    </Parameters>
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
      <Value>dsRegistrosPorMovimentoExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>ds Registros Por Movimento Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Generator

### Molde sanitizado de Generator 1 - `GeneratorPadraoExemplo`

- Perfil: `Generator` minimo com categoria default e sem `DefaultType`.
- Uso operacional: boa referencia para definicoes basicas de gerador padrao.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="4cecd62b7d1aa14890e7e98e0df97a46" fullyQualifiedName="GeneratorPadraoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="5953b12e-71f1-4020-a9b9-254085cb7061" name="GeneratorPadraoExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Padrao Exemplo">
  <Properties>
    <Property>
      <Name>IsReorg</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorPadraoExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Generator 2 - `GeneratorFrontendExemplo`

- Perfil: `Generator` customizado de usuario, sem categoria default.
- Uso operacional: boa referencia para geradores adicionais definidos na KB.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T21:48:48.0000000Z" checksum="bc1ad3de3f7892e3ac7f7afc41a65044" fullyQualifiedName="GeneratorFrontendExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="1082669b-8306-4b74-8964-552d1c688e05" name="GeneratorFrontendExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Frontend Exemplo">
  <Properties>
    <Property>
      <Name>IsUser</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorFrontendExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Generator 3 - `GeneratorMobileExemplo`

- Perfil: `Generator` com `DefaultType`, representando variante orientada a plataforma.
- Uso operacional: boa referencia para casos em que o gerador carrega um tipo default numerico.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="9acc5ae74e2b862e3010bd733afae29e" fullyQualifiedName="GeneratorMobileExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="d8a1a11c-3259-4d3b-8769-76776bb25ec7" name="GeneratorMobileExemplo" type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" description="Generator Mobile Exemplo">
  <Properties>
    <Property>
      <Name>IsUser</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>False</Value>
    </Property>
    <Property>
      <Name>DefaultType</Name>
      <Value>28</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>GeneratorMobileExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de PatternSettings

### Molde sanitizado de PatternSettings 1 - `PatternWebExemplo`

- Perfil: configuracao enxuta de `PatternSettings` para `Work With for Web`, com `StandardActions`, `Context` e `Security`.
- Uso operacional: boa referencia para padroes web centralizados que preservam a hierarquia `<Config>`.
- Evidência direta: a validacao posterior no acervo real confirmou que `PatternSettings` depende de `Pattern="..."`, `ContextVariable`, `LoadProcedure` e referencias de seguranca presentes no ambiente.
- Inferência forte: este molde nao deve ser tratado como objeto autocontido; ele so fecha comportamento quando o pattern correspondente estiver registrado no destino.
- Inferência forte: se o ambiente nao reconhecer o pattern citado, o resultado esperado e importacao sem mudanca util ou aviso de pattern nao registrado.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-10-28T12:27:41.0000000Z" checksum="8fd2b9f45a2b8a0bd391eb086dfb7235" fullyQualifiedName="PatternWebExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="4bb38735-7288-3760-86ce-8d6e91fba04b" name="PatternWebExemplo" type="83476c1e-fa72-4229-9930-f51b954fca2d" description="Pattern Web Exemplo">
  <Part type="3c89746e-54b1-441a-8f3f-97cc81be06bd">
    <Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b" Version="15.0.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Config>
  <Template />
  <Objects />
  <Theme OptionalColumn="WWOptionalColumn" GridAction="ActionAttribute" />
  <Labels WorkWithTitle="Work With &lt;Object&gt;" ViewDescription="&lt;Object&gt; - Informacao" OrderedBy="Ordenado por" PreviousTab="Tab Anterior" NextTab="Proxima Tab" RecordNotFound="Registro Nao Encontrado" />
  <Grid CellSpacing="1" CellPadding="2" />
  <MasterPages />
  <StandardActions>
    <Insert Caption="GXM_insert" Tooltip="GXM_insert" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionInsert" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisabled" ButtonClass="BtnEnter" />
    <Update Caption="GXM_update" Tooltip="GXM_update" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionUpdate" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionUpdateDisabled" DisabledClass="DisabledActionAttribute" ButtonClass="BtnEnter" InGridClass="UpdateAttribute" />
    <Delete Caption="GX_BtnDelete" Tooltip="GX_BtnDelete" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDelete" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDeleteDisabled" DisabledClass="DisabledActionAttribute" ButtonClass="BtnDelete" InGridClass="DeleteAttribute" />
    <Display Caption="GXM_display" Tooltip="GXM_display" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisplay" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisplayDisabled" DisabledClass="DisabledActionAttribute" InGridClass="DisplayAttribute" />
    <Export Caption="Planilha" Tooltip="Exporta como Planilha" DefaultMode="False" Image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionExport" DisabledImage="9fb193d9-64a4-4d30-b129-ff7c76830f7e-ActionDisabled" />
    <Search Caption="GX_BtnSearch" Tooltip="GX_BtnSearch" />
  </StandardActions>
  <Context>
    <ContextVariable Name="Context" Type="447527b5-9210-4523-898b-5dccb17be60a-Context" LoadProcedure="84a12160-f59b-4ad7-a683-ea4481ac23e9-procCarregaContextoExemplo" />
  </Context>
  <Security Check="84a12160-f59b-4ad7-a683-ea4481ac23e9-procAutorizacaoExemplo" NotAuthorized="c9584656-94b6-4ccd-890f-332d11fc2c25-PainelNaoAutorizadoExemplo">
    <Parameters />
  </Security>
</Config>]]></Data>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PatternWebExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Pattern Web Exemplo</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de PatternSettings 2 - `PatternDevicesExemplo`

- Perfil: configuracao de `PatternSettings` voltada a multiplas plataformas, com bloco denso de `Platforms`.
- Uso operacional: boa referencia para padroes mobile/web com segmentacao por dispositivo e tema.
- Evidência direta: o `Pattern` e os `Theme` referenciados no bloco de plataformas importam contexto real do ambiente.
- Inferência forte: editar apenas nomes e plataformas sem validar GUIDs de `Pattern` e referencias de `Theme` pode manter o XML bem-formado e ainda assim torná-lo inutilizavel no destino.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-17T22:18:24.0000000Z" checksum="567e74ca5f88b8ff29214d2163bea9da" fullyQualifiedName="PatternDevicesExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="d0f701a5-7288-3760-91b5-395d02d79889" name="PatternDevicesExemplo" type="83476c1e-fa72-4229-9930-f51b954fca2d" description="Pattern Devices Exemplo">
  <Part type="3c89746e-54b1-441a-8f3f-97cc81be06bd">
    <Data Pattern="15cf49b5-fc38-4899-91b5-395d02d79889" Version="18.5.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Config>
  <Template />
  <Platforms>
    <Platform Name="Any Platform" OS="Any Platform" Theme="78b3fa0e-174c-4b2b-8716-718167a428b5-TemaUnificadoExemplo" Predefined="True" />
    <Platform Name="Any Phone" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Phone" MaximumShortestBound="599" />
    <Platform Name="Any Tablet 7&quot;" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Medium" Predefined="True" BoundsName="Tablet 7" MinimumShortestBound="600" MaximumShortestBound="719" />
    <Platform Name="Any Tablet 10&quot;" OS="Any Platform" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="Tablet 10" MinimumShortestBound="720" />
    <Platform Name="Any TV" DeviceKind="TV" Size="Large" Predefined="True" />
    <Platform Name="Any Watch" DeviceKind="Watch" Size="Small" Predefined="True" />
    <Platform Name="Any Android Device" OS="Android" Theme="c804fdbd-7c0b-440d-8527-4316c92649a6-TemaAndroidExemplo" NavigationStyle="Slide" Predefined="True" />
    <Platform Name="Android Phone" OS="Android" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Phone" MaximumShortestBound="599" />
    <Platform Name="Android Tablet 7&quot;" OS="Android" DeviceKind="Phone or Tablet" Size="Medium" Predefined="True" BoundsName="Tablet 7" MinimumShortestBound="600" MaximumShortestBound="719" />
    <Platform Name="Android Tablet 10&quot;" OS="Android" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="Tablet 10" MinimumShortestBound="720" />
    <Platform Name="Any Apple Device" OS="Apple" NavigationStyle="Slide" Predefined="True" />
    <Platform Name="iPad" OS="Apple" DeviceKind="Phone or Tablet" Size="Large" Predefined="True" BoundsName="iPad" MinimumShortestBound="768" />
    <Platform Name="iPhone" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone" MaximumShortestBound="767" />
    <Platform Name="iPhone 4&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 4&quot;" MinimumShortestBound="320" MaximumShortestBound="320" MinimumLongestBound="568" MaximumLongestBound="568" />
    <Platform Name="iPhone 3.5&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 3.5&quot;" MinimumShortestBound="320" MaximumShortestBound="320" MinimumLongestBound="480" MaximumLongestBound="480" />
    <Platform Name="iPhone 4.7&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 4.7&quot;" MinimumShortestBound="375" MaximumShortestBound="375" MinimumLongestBound="667" MaximumLongestBound="667" />
    <Platform Name="iPhone 5.5&quot; &amp; 6.1&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 5.5&quot;" MinimumShortestBound="414" MaximumShortestBound="414" MinimumLongestBound="736" MaximumLongestBound="736" />
    <Platform Name="iPhone 5.8&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 5.8&quot;" MinimumShortestBound="375" MaximumShortestBound="375" MinimumLongestBound="812" MaximumLongestBound="812" />
    <Platform Name="iPhone 6.5&quot;" OS="Apple" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="iPhone 6.5&quot;" MinimumShortestBound="414" MaximumShortestBound="414" MinimumLongestBound="896" MaximumLongestBound="896" />
    <Platform Name="Apple TV" OS="Apple" DeviceKind="TV" Size="Large" Predefined="True" />
    <Platform Name="Apple Watch" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" />
    <Platform Name="Apple Watch 38mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 38mm" MinimumShortestBound="136" MaximumShortestBound="136" />
    <Platform Name="Apple Watch 42mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 42mm" MinimumShortestBound="156" MaximumShortestBound="156" />
    <Platform Name="Apple Watch 40mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 40mm" MinimumShortestBound="162" MaximumShortestBound="162" />
    <Platform Name="Apple Watch 44mm" OS="Apple" DeviceKind="Watch" Size="Small" Predefined="True" BoundsName="Apple Watch 44mm" MinimumShortestBound="184" MaximumShortestBound="184" />
    <Platform Name="Any Web Screen" OS="Web" Predefined="True" />
    <Platform Name="Web Phone" OS="Web" DeviceKind="Phone or Tablet" Size="Small" Predefined="True" BoundsName="Web Phone" MaximumLongestBound="599" />
    <Platform Name="Web Small" OS="Web" Size="Medium" Predefined="True" BoundsName="Web Small" MinimumLongestBound="600" MaximumLongestBound="719" />
    <Platform Name="Web Desktop" OS="Web" Size="Large" Predefined="True" BoundsName="Web Desktop" MinimumLongestBound="720" MaximumLongestBound="1199" />
    <Platform Name="Web Big Screen" OS="Web" Size="Large" Predefined="True" BoundsName="Web Big Screen" MinimumLongestBound="1200" />
  </Platforms>
  <Labels />
  <StandardActions>
    <Insert Caption="GXM_insert" />
    <Update Caption="GXM_update" />
    <Delete Caption="GX_BtnDelete" />
    <Search Caption="GX_BtnSearch" />
  </StandardActions>
</Config>]]></Data>
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PatternDevicesExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Pattern Devices Exemplo</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de DataStore

### Molde sanitizado de DataStore 1 - `DataStorePadraoExemplo`

- Perfil: `DataStore` minimo com propriedades de categoria default.
- Uso operacional: boa referencia para definicoes simples de datastore sem metadados adicionais.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2022-09-05T17:09:46.0000000Z" checksum="fc8ae8c25e3951dcd60d9bec160667f5" fullyQualifiedName="DataStorePadraoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="05dfb0e3-dfc1-478d-82cc-8517bebb2485" name="DataStorePadraoExemplo" type="dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0" description="DataStore Padrao Exemplo">
  <Properties>
    <Property>
      <Name>IsDefaultCategory</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Name</Name>
      <Value>DataStorePadraoExemplo</Value>
    </Property>
    <Property>
      <Name>IsGeneratedObject</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de DataStore 2 - `DataStoreSegurancaExemplo`

- Perfil: `DataStore` simples sem categoria default, util para variação minima de propriedades.
- Uso operacional: boa referencia para datastores secundarios ou especializados.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2023-04-03T11:38:41.0000000Z" checksum="3647285ee867f5d77a3101085168ed18" fullyQualifiedName="DataStoreSegurancaExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="c54239e9-16ff-40e9-ba98-b97cf2ac2ba4" name="DataStoreSegurancaExemplo" type="dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0" description="DataStore Seguranca Exemplo">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>DataStoreSegurancaExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Dashboard

### Molde sanitizado de Dashboard 1 - `DashboardAtividadeExemplo`

- Perfil: `Dashboard` com `Parameters`, `Layout`, `Card`, `Chart` e filtro superior.
- Uso operacional: boa referencia para dashboards compostos por indicadores e graficos em tabela principal.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="5fa995f2-62aa-4d92-8aeb-197abdd13e89" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:29:54.0000000Z" checksum="f647498b2bf609c1667f0a415f2fab27" fullyQualifiedName="DashboardAtividadeExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="1d0eb41a-7bcf-447e-91dc-75c207e4c2ff" name="DashboardAtividadeExemplo" type="526aba9f-a725-4bc7-b1db-0b9f92ac9550" description="Dashboard Atividade Exemplo" parent="PainelExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="a51ced48-7bee-0001-ab12-04e9e32123d1">
    <Data Pattern="526aba9f-a725-4bc7-b1db-0b9f92ac9550" Version="17.0.1"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<Dashboard>
  <Parameters>
    <Parameter Name="From" DataType="Date" />
    <Parameter Name="To" DataType="Date" />
  </Parameters>
  <Layout FiltersPosition="Top">
    <MainTable>
      <Row ElementId="32">
        <Cell ElementId="4">
          <Object ElementId="5" ControlName="NovosRegistros" FrameVisible="True" FrameTitle="CHAVE_NOVOS_REGISTROS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardTotalRegistros" OutputType="Card">
            <ObjectElement Name="CountItems" Type="Datum" Title=" " />
          </Object>
        </Cell>
        <Cell ElementId="53">
          <Object ElementId="54" ControlName="TotalSessoes" FrameVisible="True" FrameTitle="CHAVE_TOTAL_SESSOES" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardTotalSessoes" OutputType="Card">
            <ObjectElement Name="TotalSessions" Type="Datum" Title=" " />
          </Object>
        </Cell>
      </Row>
      <Row ElementId="42">
        <Cell ElementId="47">
          <Object ElementId="48" ControlName="SessoesPorAplicacao" FrameVisible="True" FrameTitle="CHAVE_SESSOES_POR_APLICACAO" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesPorAplicacao" OutputType="Chart">
            <ObjectElement Name="ApplicationId" />
            <ObjectElement Name="Sessions" Type="Datum" />
            <ObjectElement Name="ApplicationName" />
          </Object>
        </Cell>
        <Cell ElementId="43">
          <Object ElementId="44" ControlName="SessoesPorDia" FrameVisible="True" FrameTitle="CHAVE_SESSOES_POR_DIA" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesPorDia" OutputType="Chart" ChartType="Timeline" XAxisTitle="Date" YAxisTitle="Sessions">
            <ObjectElement Name="Date" />
            <ObjectElement Name="Sessions" Type="Datum" />
          </Object>
        </Cell>
      </Row>
      <Row ElementId="49">
        <Cell ElementId="51">
          <Object ElementId="52" ControlName="UsuariosRegistrados" FrameVisible="True" FrameTitle="CHAVE_USUARIOS_REGISTRADOS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardUsuariosRegistrados" OutputType="Card">
            <ObjectElement Name="TotalUsers" Type="Datum" Title=" " />
          </Object>
        </Cell>
        <Cell ElementId="39">
          <Object ElementId="40" ControlName="SessoesAtivas" FrameVisible="True" FrameTitle="CHAVE_SESSOES_ATIVAS" Object="2a9e9aba-d2de-4801-ae7f-5e3819222daf-procDashboardSessoesAtivas" OutputType="Card">
            <ObjectElement Name="ActiveSessions" Type="Datum" Title=" " />
          </Object>
        </Cell>
      </Row>
    </MainTable>
    <FiltersTable>
      <Row ElementId="34">
        <Cell ElementId="35">
          <Filter ElementId="36" ControlName="FiltroPeriodo" FilterType="Range" DataType="Date" Name="From" NameLowerValue="From" NameUpperValue="To" Caption="CHAVE_PERIODO" Modified="True" />
        </Cell>
      </Row>
    </FiltersTable>
  </Layout>
</Dashboard>]]></Data>
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
      <Value>DashboardAtividadeExemplo</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>Dashboard Atividade Exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>PainelExemplo-web</Categories>
</Object>
```

## Moldes sanitizados completos de DeploymentUnit

### Molde sanitizado de DeploymentUnit 1 - `DeploymentUnitExemplo`

- Perfil: `DeploymentUnit` com poucos `Member` e um `Part` principal declarativo.
- Uso operacional: boa referencia para unidades de deploy que apenas agregam objetos ja existentes.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-02-15T14:07:19.0000000Z" checksum="a97c0da3de76a832806f0606ac08aac4" fullyQualifiedName="DeploymentUnitExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="7665e34c-f52d-430c-b113-e76e9cbdf635" name="DeploymentUnitExemplo" type="bf08dfb1-361c-4e7e-ad54-391e56e60b49" description="Deployment Unit Exemplo">
  <Part type="122ea32d-7ffa-4c47-9cbf-0829c2f060fe">
    <Definition>
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploA" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploB" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploC" />
      <Member object="84a12160-f59b-4ad7-a683-ea4481ac23e9-procServicoExemploD" />
    </Definition>
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
      <Value>DeploymentUnitExemplo</Value>
    </Property>
  </Properties>
</Object>
```


## Moldes sanitizados completos de Language

### Molde sanitizado de Language 1 - `IdiomaExemploPT`

- Perfil: `Language` completo com bloco extenso de `Translations`.
- Uso operacional: boa referencia para objetos de idioma que centralizam mensagens e traducoes de interface.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="0001-01-01T00:00:00.0000000" checksum="cb04c786ee9f23279149b0a430455587" fullyQualifiedName="IdiomaExemploPT" moduleGuid="00000000-0000-0000-0000-000000000000" guid="6cc49ef5-e1eb-459c-aefd-331de0d9fa8c" name="IdiomaExemploPT" type="88313f43-5eb2-0000-0028-e8d9f5bf9588" description="Idioma Exemplo PT">
  <Part type="c23f3bb5-1e43-4c6b-b219-4717979df76a">
    <Translations>
      <Entry>
        <Message>Hide Filters</Message>
        <Type>User</Type>
        <Translation>Esconder Filtros</Translation>
      </Entry>
      <Entry>
        <Message>MORE</Message>
        <Type>User</Type>
        <Translation>MAIS</Translation>
      </Entry>
      <Entry>
        <Message>HIDE FILTERS</Message>
        <Type>User</Type>
        <Translation>Esconder Filtros</Translation>
      </Entry>
      <Entry>
        <Message>Hide</Message>
        <Type>User</Type>
        <Translation>Esconder</Translation>
      </Entry>
      <Entry>
        <Message>Show Filters</Message>
        <Type>User</Type>
        <Translation>Mostrar Filtros</Translation>
      </Entry>
      <Entry>
        <Message>SHOW FILTERS</Message>
        <Type>User</Type>
        <Translation>MOSTRAR FILTROS</Translation>
      </Entry>
      <Entry>
        <Message>ShowHide</Message>
        <Type>User</Type>
        <Translation>MostrarEsconder</Translation>
      </Entry>
      <Entry>
        <Message>Users</Message>
        <Type>User</Type>
        <Translation>Usuários</Translation>
      </Entry>
      <Entry>
        <Message>USERS</Message>
        <Type>User</Type>
        <Translation>USUÁRIOS</Translation>
      </Entry>
      <Entry>
        <Message>Users permissions</Message>
        <Type>User</Type>
        <Translation>Permissões de usuários</Translation>
      </Entry>
      <Entry>
        <Message>User</Message>
        <Type>User</Type>
        <Translation>Usuário</Translation>
      </Entry>
      <Entry>
        <Message>User Name</Message>
        <Type>User</Type>
        <Translation>Nome de Usuário</Translation>
      </Entry>
      <Entry>
        <Message>User name</Message>
        <Type>User</Type>
        <Translation>Nome de usuário</Translation>
      </Entry>
      <Entry>
        <Message>First name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>First Name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>Last name</Message>
        <Type>User</Type>
        <Translation>Sobrenome</Translation>
      </Entry>
      <Entry>
        <Message>Last Name</Message>
        <Type>User</Type>
        <Translation>Sobrenome</Translation>
      </Entry>
      <Entry>
        <Message>Authentication</Message>
        <Type>User</Type>
        <Translation>Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authorization</Message>
        <Type>User</Type>
        <Translation>Autorização</Translation>
      </Entry>
      <Entry>
        <Message>Authorize</Message>
        <Type>User</Type>
        <Translation>Autorize</Translation>
      </Entry>
      <Entry>
        <Message>Role</Message>
        <Type>User</Type>
        <Translation>Papel</Translation>
      </Entry>
      <Entry>
        <Message>Roles</Message>
        <Type>User</Type>
        <Translation>Papéis</Translation>
      </Entry>
      <Entry>
        <Message>ROLES</Message>
        <Type>User</Type>
        <Translation>PAPÉIS</Translation>
      </Entry>
      <Entry>
        <Message>Security Policies</Message>
        <Type>User</Type>
        <Translation>Políticas de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security policies</Message>
        <Type>User</Type>
        <Translation>Políticas de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security policy</Message>
        <Type>User</Type>
        <Translation>Política de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Security Policy</Message>
        <Type>User</Type>
        <Translation>Política de Segurança</Translation>
      </Entry>
      <Entry>
        <Message>Connection</Message>
        <Type>User</Type>
        <Translation>Conexão</Translation>
      </Entry>
      <Entry>
        <Message>Connections</Message>
        <Type>User</Type>
        <Translation>Conexões</Translation>
      </Entry>
      <Entry>
        <Message>Authentication Types</Message>
        <Type>User</Type>
        <Translation>Tipos de Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authentication types</Message>
        <Type>User</Type>
        <Translation>Tipos de autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Event subscriptions</Message>
        <Type>User</Type>
        <Translation>Subscrição de eventos</Translation>
      </Entry>
      <Entry>
        <Message>Event Subscriptions</Message>
        <Type>User</Type>
        <Translation>Subscrição de Eventos</Translation>
      </Entry>
      <Entry>
        <Message>Repositories</Message>
        <Type>User</Type>
        <Translation>Repositórios</Translation>
      </Entry>
      <Entry>
        <Message>GAM configuration</Message>
        <Type>User</Type>
        <Translation>Configuração do GAM</Translation>
      </Entry>
      <Entry>
        <Message>GAM Configuration</Message>
        <Type>User</Type>
        <Translation>Configuração do GAM</Translation>
      </Entry>
      <Entry>
        <Message>Dashboard</Message>
        <Type>User</Type>
        <Translation>Painel</Translation>
      </Entry>
      <Entry>
        <Message>Role name</Message>
        <Type>User</Type>
        <Translation>Nome do papel</Translation>
      </Entry>
      <Entry>
        <Message>Role Name</Message>
        <Type>User</Type>
        <Translation>Nome do Papel</Translation>
      </Entry>
      <Entry>
        <Message>EDIT</Message>
        <Type>User</Type>
        <Translation>EDITAR</Translation>
      </Entry>
      <Entry>
        <Message>Edit</Message>
        <Type>User</Type>
        <Translation>Editar</Translation>
      </Entry>
      <Entry>
        <Message>Copy</Message>
        <Type>User</Type>
        <Translation>Copia</Translation>
      </Entry>
      <Entry>
        <Message>COPY</Message>
        <Type>User</Type>
        <Translation>COPIA</Translation>
      </Entry>
      <Entry>
        <Message>Active</Message>
        <Type>User</Type>
        <Translation>Ativo</Translation>
      </Entry>
      <Entry>
        <Message>Add</Message>
        <Type>User</Type>
        <Translation>Adicionar</Translation>
      </Entry>
      <Entry>
        <Message>Application Name</Message>
        <Type>User</Type>
        <Translation>Nome do Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>New User</Message>
        <Type>User</Type>
        <Translation>Novo Usuário</Translation>
      </Entry>
      <Entry>
        <Message>New users</Message>
        <Type>User</Type>
        <Translation>Novos usuários</Translation>
      </Entry>
      <Entry>
        <Message>Gender</Message>
        <Type>User</Type>
        <Translation>Gênero</Translation>
      </Entry>
      <Entry>
        <Message>Gender:</Message>
        <Type>User</Type>
        <Translation>Gênero:</Translation>
      </Entry>
      <Entry>
        <Message>Authentication type</Message>
        <Type>User</Type>
        <Translation>Tipo de autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Authentication Type</Message>
        <Type>User</Type>
        <Translation>Tipo de Autenticação</Translation>
      </Entry>
      <Entry>
        <Message>Rol</Message>
        <Type>User</Type>
        <Translation>Papéls</Translation>
      </Entry>
      <Entry>
        <Message>Show users status</Message>
        <Type>User</Type>
        <Translation>Status dos Usuários</Translation>
      </Entry>
      <Entry>
        <Message>Authenticated date from</Message>
        <Type>User</Type>
        <Translation>Autenticado desde</Translation>
      </Entry>
      <Entry>
        <Message>Authenticated date to</Message>
        <Type>User</Type>
        <Translation>Autenticado até</Translation>
      </Entry>
      <Entry>
        <Message>Register date from</Message>
        <Type>User</Type>
        <Translation>Registro desde</Translation>
      </Entry>
      <Entry>
        <Message>Register date to</Message>
        <Type>User</Type>
        <Translation>Registro até</Translation>
      </Entry>
      <Entry>
        <Message>Clear</Message>
        <Type>User</Type>
        <Translation>Limpar</Translation>
      </Entry>
      <Entry>
        <Message>ClearFilters</Message>
        <Type>User</Type>
        <Translation>LimparFiltros</Translation>
      </Entry>
      <Entry>
        <Message>Apply</Message>
        <Type>User</Type>
        <Translation>Aplicar</Translation>
      </Entry>
      <Entry>
        <Message>Try a Search</Message>
        <Type>User</Type>
        <Translation>Digite Texto a Pesquisar</Translation>
      </Entry>
      <Entry>
        <Message>External Id</Message>
        <Type>User</Type>
        <Translation>Id Externo</Translation>
      </Entry>
      <Entry>
        <Message>External ID</Message>
        <Type>User</Type>
        <Translation>ID Externo</Translation>
      </Entry>
      <Entry>
        <Message>Application GUID</Message>
        <Type>User</Type>
        <Translation>GUID do Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>Company name</Message>
        <Type>User</Type>
        <Translation>Nome da Companhia</Translation>
      </Entry>
      <Entry>
        <Message>description</Message>
        <Type>User</Type>
        <Translation>descrição</Translation>
      </Entry>
      <Entry>
        <Message>Description</Message>
        <Type>User</Type>
        <Translation>Descrição</Translation>
      </Entry>
      <Entry>
        <Message>Client ID</Message>
        <Type>User</Type>
        <Translation>ID da Companhia</Translation>
      </Entry>
      <Entry>
        <Message>Client Id.</Message>
        <Type>User</Type>
        <Translation>Id da Companhia.</Translation>
      </Entry>
      <Entry>
        <Message>Client Id: Tag</Message>
        <Type>User</Type>
        <Translation>Id da Companhia: Marcação</Translation>
      </Entry>
      <Entry>
        <Message>Filters</Message>
        <Type>User</Type>
        <Translation>Filtros</Translation>
      </Entry>
      <Entry>
        <Message>Filter by</Message>
        <Type>User</Type>
        <Translation>Filtrado por</Translation>
      </Entry>
      <Entry>
        <Message>Filter User Gender</Message>
        <Type>User</Type>
        <Translation>Filtro de Gênero do Usuário</Translation>
      </Entry>
      <Entry>
        <Message>Hide filters</Message>
        <Type>User</Type>
        <Translation>Esconder filtros</Translation>
      </Entry>
      <Entry>
        <Message>Applications</Message>
        <Type>User</Type>
        <Translation>Aplicativos</Translation>
      </Entry>
      <Entry>
        <Message>Application</Message>
        <Type>User</Type>
        <Translation>Aplicativo</Translation>
      </Entry>
      <Entry>
        <Message>name</Message>
        <Type>User</Type>
        <Translation>nome</Translation>
      </Entry>
      <Entry>
        <Message>Name</Message>
        <Type>User</Type>
        <Translation>Nome</Translation>
      </Entry>
      <Entry>
        <Message>Connection name</Message>
        <Type>User</Type>
        <Translation>Nome da conexão</Translation>
      </Entry>
      <Entry>
        <Message>Connection Name</Message>
        <Type>User</Type>
        <Translation>Nome da Conexão</Translation>
      </Entry>
      <Entry>
        <Message>Keys</Message>
        <Type>User</Type>
        <Translation>Chaves</Translation>
      </Entry>
      <Entry>
        <Message>Enabled?</Message>
        <Type>User</Type>
        <Translation>Habilitado ?</Translation>
      </Entry>
      <Entry>
        <Message>type</Message>
        <Type>User</Type>
        <Translation>tipo</Translation>
      </Entry>
      <Entry>
        <Message>Type</Message>
        <Type>User</Type>
        <Translation>Tipo</Translation>
      </Entry>
      <Entry>
        <Message>Event Description</Message>
        <Type>User</Type>
        <Translation>Descrição do Evento</Translation>
      </Entry>
      <Entry>
        <Message>Event</Message>
        <Type>User</Type>
        <Translation>Evento</Translation>
      </Entry>
      <Entry>
        <Message>File name</Message>
        <Type>User</Type>
        <Translation>Nome do arquivo</Translation>
      </Entry>
      <Entry>
        <Message>File Name</Message>
        <Type>User</Type>
        <Translation>Nome do Arquivo</Translation>
      </Entry>
      <Entry>
        <Message>ClassName</Message>
        <Type>User</Type>
        <Translation>Nome da Classe</Translation>
      </Entry>
      <Entry>
        <Message>Class name</Message>
        <Type>User</Type>
        <Translation>Nome da classe</Translation>
      </Entry>
      <Entry>
        <Message>Class Name</Message>
        <Type>User</Type>
        <Translation>Nome da Classe</Translation>
      </Entry>
      <Entry>
        <Message>Method name</Message>
        <Type>User</Type>
        <Translation>Nome do método</Translation>
      </Entry>
      <Entry>
        <Message>Method Name</Message>
        <Type>User</Type>
        <Translation>Nome do Método</Translation>
      </Entry>
      <Entry>
        <Message>Delete</Message>
        <Type>User</Type>
        <Translation>Apagar</Translation>
      </Entry>
      <Entry>
        <Message>DELETE</Message>
        <Type>User</Type>
        <Translation>APAGAR</Translation>
      </Entry>
      <Entry>
        <Message>Delete permanently</Message>
        <Type>User</Type>
        <Translation>Apagar permanentemente</Translation>
      </Entry>
      <Entry>
        <Message>Deleted</Message>
        <Type>User</Type>
        <Translation>Apagado</Translation>
      </Entry>
      <Entry>
        <Message>Database version</Message>
        <Type>User</Type>
        <Translation>Versão do banco de dados</Translation>
      </Entry>
      <Entry>
        <Message>API version</Message>
        <Type>User</Type>
        <Translation>Versão da API</Translation>
      </Entry>
      <Entry>
        <Message>Default repository</Message>
        <Type>User</Type>
        <Translation>Repositório padrão</Translation>
      </Entry>
      <Entry>
        <Message>Custom email regular expression</Message>
        <Type>User</Type>
        <Translation>Expressão regular personalizada de email</Translation>
      </Entry>
      <Entry>
        <Message>Enable tracing</Message>
        <Type>User</Type>
        <Translation>Ativar rastreamento</Translation>
      </Entry>
      <Entry>
        <Message>confirm</Message>
        <Type>User</Type>
        <Translation>confirmar</Translation>
      </Entry>
      <Entry>
        <Message>Confirm</Message>
        <Type>User</Type>
        <Translation>Confirmar</Translation>
      </Entry>
    </Translations>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <InnerHtml><![CDATA[<P>&nbsp;</P>]]></InnerHtml>
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
      <Value>IdiomaExemploPT</Value>
    </Property>
    <Property>
      <Name>ISOLangCode</Name>
      <Value>PT</Value>
    </Property>
    <Property>
      <Name>ISOCountryCode</Name>
      <Value>BR</Value>
    </Property>
    <Property>
      <Name>Codepage</Name>
      <Value>1252</Value>
    </Property>
    <Property>
      <Name>LangDateFormat</Name>
      <Value>POR</Value>
    </Property>
    <Property>
      <Name>LangTimeFormat</Name>
      <Value>24</Value>
    </Property>
    <Property>
      <Name>LangDecimalPoint</Name>
      <Value>,</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Moldes sanitizados completos de Folder

### Molde sanitizado de Folder 1 - `PastaRefinamentoExemplo`

- Perfil: `Folder` minimo com apenas `Name` e propriedades basicas.
- Uso operacional: boa referencia para pastas simples de organizacao sem metadados extras.
- Evidência direta: a validacao posterior no acervo real confirmou que este shape minimo e coerente com exemplos reais de `Folder`.
- Inferência forte: a divergencia observada na bateria, em que a IDE exibiu o objeto como `Category`, nao invalida este molde; por enquanto ela deve ser lida como diferenca de reconhecimento semantico/nomenclatura da IDE.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-03-27T23:17:35.0000000Z" checksum="66a8ea763f94ed342bd2726191bed7a0" fullyQualifiedName="PastaRefinamentoExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="91314acb-c530-4e3e-9b94-db33281c99bf" name="PastaRefinamentoExemplo" type="00000000-0000-0000-0000-000000000006" description="Pasta Refinamento Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PastaRefinamentoExemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de Folder 2 - `PastaProgramasPrincipaisExemplo`

- Perfil: `Folder` com propriedades adicionais como `ShowInModelTree`, `Query` e flags textuais.
- Uso operacional: boa referencia para pastas funcionais e de agrupamento visivel na arvore do modelo.
- Evidência direta: esse perfil continua coerente com os exemplos reais da pasta `Folder` consultada depois da bateria.
- Inferência forte: quando o objetivo for apenas criar uma pasta simples, preferir o molde 1; usar este molde 2 apenas quando as propriedades adicionais forem realmente exigidas.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="00000000-0000-0000-0000-000000000000" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2014-09-03T20:49:42.0000000Z" checksum="55629d2ccd74c89a2b72536ff9c3b4c2" fullyQualifiedName="PastaProgramasPrincipaisExemplo" moduleGuid="00000000-0000-0000-0000-000000000000" guid="a7ccc3ad-5574-4898-9a1d-c6b74633f3d1" name="PastaProgramasPrincipaisExemplo" type="00000000-0000-0000-0000-000000000006" description="Pasta Programas Principais Exemplo">
  <Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">
    <Properties />
  </Part>
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>PastaProgramasPrincipaisExemplo</Value>
    </Property>
    <Property>
      <Name>ShowInModelTree</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>Query</Name>
      <Value />
    </Property>
    <Property>
      <Name>Properties</Name>
      <Value>main_program=true</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

## Exemplos sanitizados de identidade estrutural em Folder e Module

- Evidência direta: em `Procedure` sob `Folder`, o nome da pasta aparece em `parent`, mas nao entra em `fullyQualifiedName`.
- Evidência direta: em `WebPanel` sob `Folder`, o padrao observado e o mesmo.
- Evidência direta: em `Module`, o `fullyQualifiedName` pode ser qualificado pelo nome do modulo.
- Evidência direta: em objeto sob `Folder` dentro de `Module`, o modulo pode permanecer em `fullyQualifiedName`, mas a pasta continua restrita a `parent`.
- Inferência forte: a decisao correta entre `Folder` e `Module` depende da leitura conjunta de `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid`.

### Exemplo sanitizado 1 - `PRCExemploFolderA`

- Perfil: `Procedure` em `Folder`, sem prefixo da pasta em `fullyQualifiedName`.
- Uso operacional: exemplar minimo para impedir serializacao do tipo `Pasta.Procedure` quando o contêiner real e apenas `Folder`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="GUID_PASTA_PROCEDURES" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-09-30T03:43:09.0000000Z" checksum="8b29660f938eb825e90dbc5b42faa4d0" fullyQualifiedName="PRCExemploFolderA" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="GUID_PRC_EXEMPLO_FOLDER_A" name="PRCExemploFolderA" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Folder A" parent="PastaProceduresExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[&Data = ctod(&DatetimeTexto)]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
</Object>
```

### Exemplo sanitizado 2 - `WPExemploFolderA`

- Perfil: `WebPanel` em `Folder`, sem prefixo da pasta em `fullyQualifiedName`.
- Uso operacional: exemplar minimo para validar que pasta organiza o objeto por `parent`, nao por namespace automatico.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="GUID_PASTA_ABATE" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2026-04-09T11:18:17.0000000Z" checksum="1accc2250b948d6c23384fccaccbcc3f" fullyQualifiedName="WPExemploFolderA" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="GUID_WP_EXEMPLO_FOLDER_A" name="WPExemploFolderA" type="c9584656-94b6-4ccd-890f-332d11fc2c25" description="WebPanel Exemplo Folder A" parent="PastaAbateExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778">
    <Source><![CDATA[<GxMultiForm rootId="2"><Form id="2" type="layout"><detail /></Form></GxMultiForm>]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
</Object>
```

### Exemplo sanitizado 3 - `PRCExemploModuloA`

- Perfil: `Procedure` diretamente sob `Module`, com qualificacao de modulo em `fullyQualifiedName`.
- Uso operacional: contraste minimo para provar que qualificacao por modulo nao pode ser extrapolada para `Folder`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="GUID_MODULE_GENERAL_SERVICES" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2019-07-26T18:37:24.0000000Z" checksum="ca9dbb87d6d7a0949fb671454d480699" fullyQualifiedName="ModuloExemplo.Services.PRCExemploModuloA" moduleGuid="GUID_MODULE_GENERAL_SERVICES" guid="GUID_PRC_EXEMPLO_MODULO_A" name="PRCExemploModuloA" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Modulo A" parent="ModuloExemplo.Services" parentType="c88fffcd-b6f8-0000-8fec-00b5497e2117">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[Do case
Endcase]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
</Object>
```

### Exemplo sanitizado 4 - `PRCExemploFolderDentroModuloA`

- Perfil: `Procedure` em `Folder` dentro de `Module`; o modulo permanece em `fullyQualifiedName`, mas a pasta continua em `parent`.
- Uso operacional: contraexemplo minimo para evitar o erro de promover nome de pasta para o nome qualificado.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="GUID_PASTA_SYNC_EXEMPLO" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2016-01-04T13:40:16.0000000Z" checksum="19894cc8d64aaf194ad4af2e684da9c6" fullyQualifiedName="ModuloExemplo.Services.PRCExemploFolderDentroModuloA" moduleGuid="GUID_MODULE_GENERAL_SERVICES" guid="GUID_PRC_EXEMPLO_FOLDER_DENTRO_MODULO_A" name="PRCExemploFolderDentroModuloA" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" description="Procedure Exemplo Folder Dentro Modulo A" parent="ModuloExemplo.Services.PastaSyncExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[]]></Source>
    <Properties>
      <Property>
        <Name>IsDefault</Name>
        <Value>False</Value>
      </Property>
    </Properties>
  </Part>
</Object>
```

## Exemplos sanitizados minimos de compatibilidade de `Source`

- `Objetivo`: registrar padroes minimos de `Source` que esta propria trilha ja sustenta metodologicamente sem depender de corpus grande da KB.
- `Regra operacional`: estes exemplos servem como camada metodologica primaria para KB nova ou pouco povoada; o corpus local entra apenas como confirmacao ou desempate.
- `Regra operacional`: ao introduzir operador, funcao, conversao ou padrao string/numerico novo em `Source`, preferir reescrita usando um destes padroes ou outro ja documentado nesta base.
- `Regra operacional`: a ausencia de um operador, funcao ou conversao nesta secao nao prova proibicao absoluta, mas impede tratar o trecho como pronto sem outra base metodologica explicita da trilha.

### Padrao minimo 1 - `parm(...)` simples de entrada e saida

- `Uso operacional`: forma minima ja documentada na trilha para assinatura simples de `Procedure`.

```geneXus
parm(out:&DomainExemploTipoOperacaoA);
parm(in:ContextoAId, in:ContextoBId);
```

### Padrao minimo 2 - conversao numerico para texto com ajuste explicito

- `Uso operacional`: conversao numerico->texto e montagem de string ja documentadas nesta base por molde sanitizado de `DataProvider`.

```geneXus
Chave = RegistroId.ToString()
Valor = "CtxA:" + RegistroEmpresaId.ToString().Trim() +
" Chave: " + RegistroId.ToFormattedString() +
"| Seq:" + SequenciaExemplo.ToString()
```

### Padrao minimo 3 - string e enumeracao em composicao textual

- `Uso operacional`: composicao textual com `Trim()` e `EnumerationDescription()` ja aparece em molde sanitizado documentado nesta base.

```geneXus
" | B:" + procRightExemplo(PessoaBId.ToString()," ",10) +
"-" + PessoaBNome.Trim() + " (" + TipoRegistro.EnumerationDescription() + ")"
```

### Padrao minimo 4 - condicao booleana com `IsNull()` e guarda com `when`

- `Uso operacional`: padrao de filtro/condicao ja documentado nesta base para `Source` de condicao materializada.

```geneXus
RegistroMovimentoCancelado = false or RegistroMovimentoCancelado.IsNull() when not &SomenteCancelados
MovimentoEmpresaId = &sdtRegistroParametros.EmpresaId when not &sdtRegistroParametros.EmpresaId.IsEmpty()
```

### Limite metodologico atual

- `Evidência direta`: esta secao ancora apenas um conjunto minimo de padroes ja documentados na propria trilha.
- `Regra operacional`: operador, funcao ou conversao que nao apareca em regra explicita, exemplo sanitizado ou molde documentado desta base continua sem lastro suficiente para consolidacao final apenas por plausibilidade.

## Moldes sanitizados completos de Stencil

### Molde sanitizado de Stencil 1 - `StencilCardResumoExemplo`

- Perfil: `Stencil` com `Source` rico em `Controls`, `Screenshot` embutido e bloco visual de card.
- Uso operacional: boa referencia para stencils declarativos que embutem layout visual completo em `CDATA`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:33:55.0000000Z" checksum="5c96cea3449e70000bfeb99a5623d2fa" fullyQualifiedName="StencilCardResumoExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="744d7301-c4c1-46af-afdf-5e55bcb4ae80" name="StencilCardResumoExemplo" type="624a8b31-36f0-4292-adba-2d270d1e3537" description="Stencil Card Resumo Exemplo" parent="ColecaoStencilExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c68">
    <Source><![CDATA[<Root Screenshot="data:image/png;base64,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9dzlmlb3qnou97DSh88O9SMpABL8GQYAKYIBQIpgAJAiGACkCAYAKYIBQIpgAJCSDsbSDetj2OzRAPRAL7a+2uW9v1k6GFMWzopjrz8+Lr13EAA9yCf/+cQY9+y0Lu/9zX6lYJxz51c6/t8qAPQcXx7/VcEA4L0JBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAygcSjKOv+VicO/ZCAHqQjw065v0Nxur2LTH5+zMB6IFWbmzv8t7fLB0MAA5tggFAimAAkCIYAKQIBgApggFAimAAkCIYAKTsC0bf6gEA/DJ9hkT8NxoiJ60zkrHQAAAAAElFTkSuQmCC@data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAYwAAAEsCAYAAADQJYSkAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEOoAABDqAYLTCpgAAAtlSURBVHhe7dxpsFYFGcDxvjSDzbSNLZYOxLQ5U5OogTWVRWMxWTahN3JvVAJL4o4KKomEG0psV5QtF0BBBUlBzQQ1dmQJRKEQFK4oVwRTq4+VPJ2jHs9rXeFpJkbm9vvwg/e57wHu+7znnP+wXN7V8/I9r/YcvmcPAOzNu8pv/vyXCAB4O72uihAMAPZJMABIEQwAUgQDgBTBACBFMABIEQwAUtLBePr5iPmPAdARbdnR/r2/UToYD6yNaBoTcfEMADqSPmMj7lnZ/r2/0X8VjEtvj2h7EYCO5PLZggFAgmAAkCIYAKQIBgApggFAimAAkCIYAKQIBgApggFAygETjA3L74xLTjk5vtPrhPhWof+IObF29552j90v/vhAnDdwXjzW3nMAHCDBKGIx6NyBMWzk3XHbrAVxx5wFMXXo4Ohx5ar2j98f1kyKY77UEsvbew6AAyEYu2PWhefGRRMXxootf4/ndr/+8W0bt8bc1S//27H7kWAA7NU7H4xND0b/k0fE9KU7Y9sbsXiL3a9G66ppcX6fL8YR3Y+Nr/98SsxY/1Isu39qnHvO0BjctymO6HZcHH/2zTHzD8XxrZti7qTmOPG44vheZ8V5U9fGo+tXxjVXtMTA8wfEN48bGuMnXR0/Pf646N6tOKbb6XH+rL9G60rBANibdz4YT/wmTuvTErNX7Y5nynnBuOhx9JHxmc9+Lj5z0vRY9cLWaGnqHcPv3RgLF6+J2dPGxGn9psYdNw2Lb3Q7J4bdsSIWzp0TYy68JAaPejjmzbg5RgwbHTcvKI6fPzsGXTQ5Jt44Kfoff3r8pHlKzJn/VGzc3BZrVj0Zi5YVx9w1Onr1nhZLFl8XPQQD4G0deMF47qVYuXZrrLjn8vjCMS2xZNWk+Eqn98TBh30yunyiaxx6yGHR9fCmGDxuTPQ5c0Ysb/tntG3dFLeOGx3Ng26IawefHId/8MPxsc7F8Z0/Hh/8wJFxcvOg+MEp18b4u/4UW3btee0vuEf07xufP/xz0eWwj8RBR18d8xe1CAbAXrzzwXhhW7SccU5cNffp2LSz4eNrJkT3MhjLxsWX39s3Jm9oi3WveT7Wr98c993WEqf2u/v1f9XUujluHd8SzRe0xJXNl8RZ/W6JeW8evyv+tObeGNCvJabcvzWefvGxuKbXj2PIFXNj0ertse7BsfG1nuPiYcEA2KsD4C+9X43WeVfHj04cGJMe2B3bymisWxznffTgePcXx8bStsdjyDEfioETnom2nX+L1b+dHKeePjFm3t5OMH75m5gxcUg0n9EcMx95Jdo2L48rL50cN0y6Pvr1r4KxOoYec3EMmbotNrZFrJlwWXzkq6P9DgNgHw6AYBR2/SMenXdFfK/LIfG+TgdFpx5nxZBbRsZRPVpixe5/xpaHZkbT0Z2i0/s/HIf2Hh7jlz8fC9oLxvBH4vEtW2L68DOjW5fi+E8dG98f9ft45NH50fxmMF6N1ZNHRu8uh8b7i1/rqCO7x7u7XysYAPtwYAQDgAOeYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQsl+C0TQm4pIZAHQkPxr7Pw7G020R89cB0BFt2dH+vb9ROhgA/H8TDABSBAOAFMEAIEUwAEgRDABSBAOAFMEAIEUwAEh5MxjfLh6cOCriqR0R5ePST2+MWPrHeh4+K2LOinqePD9iwu/qufzS8mF31POjT0b8ZHI9b9sZ8f1rX398/IiIZ3fVz501IWLNU/U8ZEbE/Wvq+br7I256uJ7vXBpx1Zx6Xrgh4uc31/OmZyP6jK3n3a/Uj0+7LuKJZ+r5gmkRD62v55H3RNy2uJ6nLYwYPa+eH1wXMfi2el6/LeKM8fW886X68UnFTsuvoKzmnxU7XdKw0/L/cLlreT3/ekHE9Q/U87xVEUNvr+eVmyP6Nuy0tdjpCW/s9LvFTrc37PTsiRGrt9TzL2ZG3Le6nq/7bbHTh+p51rKIKxt2uqjY6YCGnT5Z7PSHY+p518v149d22lrPF0wvdvpYPY+c+9adTi92Oqr4WDWXX2k66NZ63utORxc7fa6ef3bTW3d6xV0Rs4vXUs2pnU6q59YXIr53zeuPy++fKebquXOK41YVx1fzpcVO723Y6fhipzf++06Lz6eaF2+MOK/4fKt5c/E6morXU80vNLzO04udPt6w0wuLnS5o2Gm5v+mL6vnW4vGvGnZaHlv+mGouf67y56zmxl+rfF/L97eaBxSf46Lic63m8jWUr6Way9dYvtZqLndQ7qKay/OuPP+quTwvv/vGTk8ovi93XD1X7r58D6q5fG/K96iay/eufA+rubxeyuummsv3vjwHqrk8N8pzpJobz53ynCrPrWouz7ny3KvmUcV1Xp6b1Vyes+W5W83lOV2e29Vc3kfKc7+aG6+J/9hpcS2V11Q1l9da407La7G8z1XzfcX9r7xmq7ndnRbXfPm4vAeU94LqufIe0bjTy4r78tzi/lzNNxT37Sn72mlxr6rm8h5W9qHncL/DACDBH0kBkCIYAKQIBgApggFAimAAkCIYAKQIBgAp6WBs2L4jblkyG4AOaH3r9nbv/Y3SwZi+7O7oPLhrNE08E4AOpOvFn47Jv5/R7r2/0X8VjN7XnxptLwYAHcgpU/oKBgD7JhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApAgGACmCAUCKYACQIhgApOyXYHQe3DWaJp4JQAfS9eJP/2+DsWH7jrhlyWwAOqD1rdvbvfc3SgcDgP9vggFAimAAkCIYAKQIBgApggFAimAAkCIYAKS8GYxvFw8A4O30HB7xL2eOWqnkP1cdAAAAAElFTkSuQmCC"><Controls><table class="card" tableType="Responsive" responsiveSizes="[]" layoutType="SD"><row><cell><table controlName="TableGeneralTitle" class="card-heading" tableType="Responsive"><row><cell><textblock controlName="TBTitleGeneral" caption="Resumo" class="attribute-label" /></cell></row></table></cell></row><row><cell><table controlName="TableDataGeneral" class="card-body" tableType="Responsive" IsSlot="True" /></cell></row></table><table class="card bg-white" tableType="Responsive" responsiveSizes="[]" layoutType="Web"><row><cell><table controlName="TableGeneralTitle" class="card-heading" tableType="Responsive"><row><cell><textblock controlName="TBTitleGeneral" caption="EXEMPLO_General" class="" /></cell></row></table></cell></row><row><cell><table controlName="TableDataGeneral" class="card-body" tableType="Responsive" IsSlot="True" /></cell></row></table></Controls></Root>]]></Source>
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
      <Value>EXEMPLO_DataCard</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>GAM Data  Card</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>ColecaoStencilExemplo-web</Categories>
</Object>
```

### Molde sanitizado de Stencil 2 - `StencilCabecalhoListaExemplo`

- Perfil: `Stencil` de cabecalho com acoes, busca, imagem e variavel declarada.
- Uso operacional: boa referencia para stencils com controles interativos e `Variables` embutidas.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="fdf9baf8-1249-463c-b803-76e914f87c2d" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-04-28T23:34:41.0000000Z" checksum="9d5d14b2efafae0b5b00b33d3e8ec0a1" fullyQualifiedName="StencilCabecalhoListaExemplo" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="39ae3b48-9e9f-4ae8-ae2c-94a0ac238a4b" name="StencilCabecalhoListaExemplo" type="624a8b31-36f0-4292-adba-2d270d1e3537" description="Stencil Cabecalho Lista Exemplo" parent="ColecaoStencilExemplo" parentType="00000000-0000-0000-0000-000000000008">
  <Part type="3dd92fe7-b095-44d3-9fa0-8488fa3f0c68">
    <Source><![CDATA[<Root Screenshot="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAYwAAAEsCAYAAADQJYSkAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEOoAABDqAYLTCpgAABbCSURBVHhe7d0HdFRl3sfxPcdXxX2LoCtHXcsuru6ur7qu2ECQRaWIqCC8KlURpEoLTZAi0juKkQ6R3iGht0AILSSQRnqAAAmEFiGhpv3eO5MEQoj4XzEYzPc55+PJ3OfOvZPBud+Ze0P4XdX+2VlVv8zOBgDgen7n+s/J0xIAAD+mxkCJYAAAfhLBAACYEAwAgAnBAACYEAwAgAnBAACYEAwAgIk5GClH0pQaHAsA+A1KSUwt9NifnzkYqbujpFGjJC8vAMBvyejRSgsIL/TYn9+/F4wZM6R9+wAAvyVz5hAMAIABwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAIAJwQB+XckhoYrYthO5sgt5jlBMEAwUpcz4eJ2MjlZyVJSOREaWWMec7z8tJkZZzvNR8DkK2bJN23cEKjomrsRbsmyV+/+Zgs8RigmCgaLieuEnRkTo0P79On7smI6VYEeTkpToPB+nnHgWjIYrGPv2J4ghefusIRjFGcFAUTnhvKs+mJCgs2fPKjMzU1lZWSVWenq6Tp06pUNxcUp1Pmnkf54IxpVBMIo5goGiEh0WprS0tEIPoCXRpUuXlHzkiJIjI696ngjGlUEwirmbEYyjPp4a07KW3q9VQLNB2uI1Qt2bddZM7506G5vvgeXKjPXW1HojFF5gOYq/sNBQZWRkFHrwLKlOnjihpIiIq54ngnFl3Egwzm6ar+lfj9GyFQGFzhdfcTofvEZznGNkk7p11bV5O3VsN0yBe0K0b9FMLe4/R4cKvd+v4GYE42zABgXNnSyfyf3V5dW6avdJT82Y7NyevVKH/dbIb/YiRTgPIj3OWX/VCDUatEgXYuLc982Inqx2/91MG/NtD7cGVzBK+qmogk6ePOm+rpP/eSIYV8aNBCNl2Wh1aNdaQ702FTpfXGVFhSn466aq2rCbVk2bps1zFsh3wWrnk+guBY0brIHvDdde17oBK7Rg0njNW7aj0O3cFDf3lNRazWrQVRNHLtbRQucds1vrvo/GKy0q1n2bYNy6CMa1CMb1hzkYkQEKnT1eE0ct0w+5y27VYGTu3aNtvV/X2wPXF5grEAy/mRrUp6e+mupbYD2reF3yn6BeA30KmTP69YPhWjZAG3x36cD0Dqrz3MO6vexjqvBceQ1bEFcgGFE66TdBXzz/vCo56tT/REvW520HxQ3BuJY5GJHz1KrR26pUqZKjr1Ynn1F67tSVkamzp9bpS/c6jmrvqfkIX53InS26kanUoyFa8OUgbTyeu+gXGj8djGgd3/C9RrxdVQ0+/Err/PcoPXfu6mAEK2jUQC0Y0099G9XTm65jRstR2rtjkabXq6Ua7mNIJ20IiVBW7v3T53d3H1cqPf+yatX4TGsD8vYZpgNLhqtz7nGnYYMG6t37W3l5rtQZ9/xW+fZro0a5850GzFL8nrz7Xk+80iN9Nf3/ntU/Hi6t+/78jN6qXVvDx3ppUrNxis4XjIBN8zSxeSU9+vBDeuTxp9Wq+9cKdj8+X/l0aKL6ufvuMXaFjoa7lgdo1WdttGDWaH32SkVVfr67djr7zArfom2DP1W112po8or8j8Xo1w/GEg39Z2vNXbFVKbs3K3RIfZWp3VP+i5YqISQ+XzDidDZwqb77oLyadpmqIO/Z8h7moV7v9dW23fn3geKCYFzLFowIzWrSwnnxL9H6HUFa3v9DvTBgpU6dy5+MLF1MW6++FZ5T/X7LFRQUpB0b12nhd2O19hc+iF87MpSSsEVjG3ys+YdzF/1C43rBSA/eqo1f1NJrr7+pYeNWKXpToM7nm786GIHa0K2uqv+rvoaO8dJO71HqXPElVXiiij4fOE1bFntrefsa+ofH9zofnXP6e+ugz+Xt7a2gRfO0skdDVWk5TclOoI5tmKIRDaqqQ28v57gzTz6DW6n+K6+rTb/5OrUvVKGeHdSxSXN9+81cZ/5rDa3zicaNW6HkKOdxuU6xV6uo8k89VYCHtjn7zI6LUOLy2Zre4kXV7DRFIauXaKvXKH3xSm8F5QtGaESwkuYNVbsWzdS67wRFbQlQanSwdg5tqk+bdtSMifOdfY9U39eaauIMP52O8df0N8vpb9U85L1giTO3JSduznObscdPO+fPkGfT51SzZnut3XXlOfxJxSkYZ123f+yUVHS4Dk5oq+ff+kJBIa4fS4zV0ZWTNaJJVQ2ZHZS7LRQnNyUYScvU6fWK+sInWefTC5nPc/GkYvy/V++Ba5Vc2PzpMC2c8r1m+ITrTGHzvxBTMI6vlEfTIVoadFjns6X0CE/V9FimlNRLct4e6un+flK28+li7zi9VbaFFv+QE5LsjHSd/+GEzmS4bxbhuMnBcA6qyYv76r1nX9JbHp6K8fXTqYh887muDUYL9e8zTsGB0c6niAhFDKqvuq1HaJd/uLMPJ0Br+uhfr/VXTGTOjzmn7d6tS65txUfq2JoRavV0N+2KDlT4dz3VrIqHNoW51ovTxZ2LNa1bZ/V1BcN/toa0baPuw+YqKdIVnkht/6K2Pu02QsE7Ip32B2nfxvXau2ZNATuUlvu4XaekdvR5Qw1H+ju3QxW/4NpgFHpKyneSOn3UWkPGe+ukO3oR2ti+ghr3nqqE4E1OMB5QowFrlRJ9bYCzY2OUss1HflM+10dPVlKDLjN0vMA6hbplghEVqv3D6+j239+rRx5+WOUcjz5wnx57pqL6TLvVfiqiZLgZwQgYWVGfNXpXZduvUIrzDrywddwuHFPY6jH6pN1CJRY2fypAk4aN0diZu5RS2PwvxBSMzHPaOLS2mn/to/17F6pDxXrqt/qgzmU49VjbXre1WumslKXzJ+aq6d3l1GxhYs79rhonFbZiuBqUK6dyjlptBmvd/typ+JXq07y6e3m5cq+r55xAJZ13TRyVT/dOmr5knJq++JyeKOehVakXnD0d1NR6OdspV+5JvVB5sNa4g1FfI7ynqLl7eSW9/9lcOa/+GxqFf8Jw3hVHbFfQ9K56u/RfVevtIQq7aj7HtcFoo7EjvRTnPkWzT4meTdSkz3TFBTqP0nWfLUP1ZuU+2psbjAzfIaqbd2x58BE9+UQnbQv1l/+gFqra2FOHc/ej0DVaPKCPBriC4TtVvd4pr9L33q8/5d73j/f8Xs82GqTArVf/Of+Ynx2MNWOdkD2le8s+cHnfD5a+U+Vbjtf+3b5OMKpoxKJAXXT9MFG+/blFhWj/N031yBNP6pXWE5QUtFeZBdcpzC0VjNGN9afq/RS4Y4eSch3dFaTUqJyPlCheij4YuzS4fDvNCp6h5n/uqlUp55RR6HqOWykYzji4oI1eePJhlb2vtN4fHaDDZ7Lk5EIJE2voxZHO/Z2RnXlaB5Z/rhdLl9ML/xqpQPdS1zivhAAv9f7oXfWdG6qkpF1aNLiP+nWbqWDnNRrnv0lb/DcrJilJSetGq07L4Zq7J1EXdVhzmv1Tf6nWU8tDY3U4KUXnsxI0rd4fVab5LGc7STrkvDP3H+upZQnr1KP8g3qu2jBtcJaHbpylri2qqe085131DYwfPyUVr8yYvTq1eZV8BzdThbJP6533Ryoi3zo3FIxZrfTI/R9rsfu44qfwxYPVzhWMkC3yG/CJKjeboCN5+9q+UOM92qplXjA++VQdBnyv6HzHpWPBe5Ue63wf3v1V47kn9GDZsgW0lG/u9m4oGB+2Uv9v5isu376Ph0YqM26LE4xqGrss6OpgxEbr1MSP9eCjj+vlTtOUtHOXToRHX5n/KbdMMPZF6bjvYDV64Am19dyee18UZ0UejJ1D9Wz7WYpOTtHqDo+q5jfBupiet790pR5frE/LlFEZx2N//5uaf5k/GEe1a25v1cqdr/xObdVvWTyCsWfSB2o+dLp2xhxVSkq4pjR+Wn9qN1cn0i5pfafSarH8yrWM7IwLOhYXorHvldL9T1WUx7Ik54UYrRXjuuntXkt1KN2VmSzFrx6hXj3ba2bQD8rMyHD/ubhmlBmose/2ldf6KP3gDsZTajU5WMnn3LPSpu66u9THWph3/SQ7W5kXz+p4gp9Gv99I30dfkOsMWHZqnNbOGK4uA9frRi6h/PRFbycc0RE6s321Vo/so57dZ14+lXJDwZjWUHc831dxzvKMiN3y86isx13BiA9W9Ozu+vCvldRvuutMRriip/fUhy++pOauYMRt0MI2b6vOWx21fG1oznbzi43UmZBgpezZU4ATlNx1fnYw4lZqSv1X9c4H/bXNb++Vfbq5rmEUDEa8Lq4boPfe+EohwSE6k/vJ6t9S7IIRN1Od7rtH/12qlNpOjc0XjH3Kjg/TweX9VO/2O3WXM39XqUf1as2BCr28LRQnRR2M7YNfVMc5oTqWlqWMtZ11zxujFXEx57TUxXNhGlm9rN79LtL9q0mSYwM0ovFjquAORppiN3mqS6M6Grgi51eXRPgMVMM6tdTj1w5G8mr1aDtaS3YluK9fOIdiZV6K0YT3HlWNVs316qvDFOGOQL7hHMQz0px3+Qs6q9o/XtO4NZHy/vJN3fYfd6jUXXfpLkepO2/XozXbymtXivNC9deYj1/TI+65O3X7bW9q8LpIpbiD8aHGbD6gM3lNWtdRd7wyWs7bt3yjkGsYZ/fLd85YdftqrY7lLvo546eDkSdeWbGxSo+Ju/zbbW8oGHHrNOSft6uUc1y5+9579cZn3dXZFQxnvexwf20d1ED/6z7u3K/KVeqoXYde+sp90dv1yWeN5jarrmfuyDsuVdXAqaucubzHen3mYMRv1oqu9fSCs58qjfpoy1ZXPL01ofbLevzOvH2/KU8ff6UVGgzXNmJ1yXkz/rN/I/DNDQZKkiINxqH5avZUB3mFH1aae9kGdSxdVaP3XnS+ztS50FF6/Q+dtTFv/fynpNL2aeM3/dWy8RSF5c0Xl1NSR1eoa5ux8g46pAs5S3LGgamqdc9/qcXiNGUV6EXOuKRj0UvV+53y6jhpvbzHdlGtPquuPXjHLJNH3ZZq991m5Vz5CJbnO84njMvBaKixfgWCUXmM4nJv5oziEIxf0bYF+rZ/N3X1XFf4/G8ZwUBRKbpgZCphbks98+d7dKfzrsr1rtDtjtv0u4+WKMPZZ+qyVipTfbz25d3HFYxVo9XMFYzkEC0Y0UXv9lulo3nzJ3dq4tDRGvOrn5IK0Xd1K6rVoLWKSr6gCxdcNurzxx7S3c73eEeFQQo9d14XLl7SuWjnU5JnVM46Z44obGEf1Xm5vbyPnFTo8q/U6IW3NGCFEx73Ni4qPSNL2bE+6urRW/3m79JxZ/nB5b31xlMN833CKBAMOSH+n9+r8si97u2cTUlR6OSJ8i5BwciOj1N6VKQuRLr4adPgZmpd/eOS+XfACAaKSpEFIyNBsz99WZ2nByoxNd9y3+4qfddH8r7gBMOnrf5wbzutOp/zu6wyU/Zr87dt9JIrGMfCtKhPS73eYLx2X3I9vkzngOCjXl16qHuxuOi9R57vVtYTuddXypSpoqHbjsv5tuTb4yHde08Zla09QVFnvNXq8jpl9JfyVfXN5Svfx7VnSX/VvjxfSc0HrdR+ndK2iZ+p5l9zlj/ftq1aVOytOZti9IOStKjdpxq/7aBSr1wmccZGdczbTtmH9GQTL4Ud2q7xLdppaVLuKucStGXRePUd7lvE1zButigdWe0pj2fvVpm7c7xQo6kWrSts3RKAYKCoFFUwLsbP1CcVPOQVlKDUq+YOaGL1/1TjJed0IW2FOj3ykGqP3KnExIOK2DFPnV97Uq+4r2EcV4j3ADWtVEd95oc68zHaMMlDtaq8q57FIhgld9wSp6RKMoKBolJUwQiZ1kQ1ek5U6KHT18wleH2gx3ptcj6FXNLpkG/1jvvvCPxdL7/aTKPmTlOPvrmnodL2a9Okzqrinn9Jjdt11+fDpmna0lCdLrDNXxLBuP4gGMUcwUBRKdKL3rcognH9QTCKOYKBokIwrkUwrj8IRjFHMFBUCMa1CMb1B8Eo5ggGikq4Ewz+xb2rnThxgmBcZxCMYo5goKhEh4fzb3rnk56eruSjR3W0kH/Te09wmI4cSS7xli5bRTCKM4KBouI6MCYcOKDz58+X+FNTrlikpKQo0XleUmOu/h0+CYG7tWOjH3JlEYzii2CgqGQ4L/xDERE66Hx9+PBhJSYmlliHDh7UAScUJ6KjOSDi1kUwUJRc0UgMCVFkQIAidu4skVzfe3xgoE7s3UsscGsjGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADAhGAAAE4IBADApkmCMHi3NnAkA+C0ZM+aXDUZKYqpSAyMAAL9BKYdPF3rsz88cDABAyUYwAAAmBAMAYEIwAAAmBAMAYEIwAAAmBAMAYEIwAAAml4NR3fkCAIAfU/VL6f8BGW/1Ymin6XgAAAAASUVORK5CYII=@data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAYwAAAEsCAYAAADQJYSkAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEOoAABDqAYLTCpgAABYoSURBVHhe7dwJcJXlvcdxZ3rb6kzvOF47dkG99V6rFW1Lq0VQkEURZK2KAQQBkYqiEDEIBDgkQBIWExJAlrAEklRZJUDCGpawBggJhJCFLCyBAGEJELaEAL/7ngjeEIL9awVC+L4zH4fzvG+e95x3nPd7nnMyuafB4MuXGvhevgwAwHe5x/2fYyclAABupLGfRDAAAP8SwQAAmBAMAIAJwQAAmBAMAIAJwQAAmBAMAICJORgFB0+rcFsmAKAKKjhQWOG9vyxzMAoT06WgIGn6dAC3yIWwMO0PGVMlHRzzRYWvGbfBqFE6vTmlwnt/Wd8vGBERUk4O8KO47DiXmamTu3apICPjrnbauQ6XsrOvu0anUtO0IHqptiRsq1LiN29VzMKl171e3CZffXVzg1G4YZFWTfBXqH85U6K0LzH12ieTslLLpy3R0fTM0pvENftwV3L/f3DKCcUB50aZu3evcnNz71r79u3Tfud6HElPvy4a7mCsWLlWVW0rLi4mGJXJzQ7GsdhIRXh3Us9Of9dr1Z9V/dpN1KWT87ifj0KDZyknLkbLw2O0f1uqLq0L1OsNXUpy/7vsk8Rdy72ycMciPz9fRUVFunjxoi5dunRXcr/2wsJCZTnX47iz2ih7nQgGbombHYz/F6tZ7/bVeL+ZOuB+vCNWiybMVuq8EeryuksrVyboAsFAOe5304fy8kpvHBXdRO9GJ06c0K4dO665TgQDt8RtC4b746cp4fp6YBvV+1M9dfIKVeZif7W6Goyk+YoZ4Slfz0/kFzhNidvKz4e7QV5amo4cOVLhjfNu5V5ppCQnX3OdrgvGhQLt3rFMU7+M0cYdR64MOtu5XG1eMF2Bvr7yHTNGURt3q+DMlX0/1laUr51bNmldQq7OXRn6oRvBqGRuWzA2TVXv9r004sMWqlujobr2m6LsJVeDsVEb+rWXa+BnGvbZZ/If+Ik8B0XpxHVzoqojGBVL3r79mut0bTAu6HjmUk0d0kavf+StwSHztKc0CseUOn+yhvXsq/6+wzQsqLc8PxyvmISD+lGbcWqHZo0LUcCE9Tp+ZeiHbgSjkrm9wXBpwSSXOpb/SGr1BL3/6MOq90YneXbqpA9b1dIfnuyk2KTyc6Kqu6XByE/W/KmhmrIoSXlnK9hfsFURYauVffyMSsqO56/W6DFrdKTs2E323cE4q5x1ERr5UXsN+uIL+bsCtfaoezhZkUP8NWLsSu0vcj/ep/gF67Qt5+i/vRK4ZiMYVVelDEa0Sw3vq60eQ4Zqop+fw19hn09Txo7yc6Kqu5XBOBQXqSEdW6mla5ZW7T57/TG5M9TBI1jr9h1XcdnxzGDVqz9W2WXHbrLvDkaJTmWuUdjgd9W4Sx/5B8xW1nlnuGiPosd4a+jQYMWnH9d599jV7cQ2LZs+QF49u6nb0FAtyDntvEZnPG2WAj/8QN26dVP3j4M1J7VYp3YvV1DQNE2cOEo+fvMUv32Jxvg4P9ftU7mCv9bm9A1OMPzV62MfjfTr54x7a+SXicou+OZU32cjGJVMpQzGhkj1+cOTGjotXsrO1vn10xU44CsdvW5OVHW3LhinlRgxVZMCvdUrIEJfr8jR2fLH3DHBKFZ+8lL1b1ZLjzXopPHLD8m9oHCPH0marxnDe6hr5y5q1663Ji1LVX7RCW2d5KtR40drcni4wqcHqMuABco6XazLB7doWWSEwp3xsBG91bbXIqWsG65G1dto2KRIhU+YoODeb6mvzxiFTwpVYK/BGt7XV4P79pLHm14KnOrMN7yfPN2x2XBAZRtl2QhGJXPbgzErSCM9Guj1Rr21fK6Pmpd+h7FVmWN6qFvz+vJo1kxtunaXz/g4nb1uTlR1tywYhama5dzcIucv1tzAEQqNiNUe98dSxxO0KPQTvd/xLXl199ATL/trpTsYh1do2tAOauvxlgZ4eui3lSgYRUczFBvuKy/XKPn7+qpP/yDNWhChhIPuO3ChjuRs08olCzT58z563WucotZ9rUHN6+iFuq+q5Zse8mheUw9Xe0NTUk7qwqHlmuIzSB7O63zztb/p901CtGlDkFo1GqakQ3naFTdRnl0DtCXPSUHJeR3LSFfysjn6wn+oeg+OUqYTHR2IVZD3SE2N3qnC0mdo3whGJXPrgpGivKWrtGdtos67H6dvUeriOB3eHq/9i77U8qnztS9htTbNi9PJXVm6vDNBO2ZP1sLJk7Vo7lLtSy0/H+4GtyoYhTu/1tTwMC1IPq7sqOHyGRuuuN152hz6vvr7eyts1hzNnfCRHm3ir+X7MhTjXU/dg0YrKmq+Zoe01b2VKBgFu1YrYmgbjV5/XKnLZqlbg4Z6s+cIrXYHo8xWdGqthrQfrClTh6nji+3lOTxUMxcu1MJSa5VZkKCJzdvLL3hm6djcL7qpljsYm0L0Zrtw5RYd0Y4lIera82tdM3X57zCOrlPQoBCCURXcumAA39+tCUahUub6qlP96vrLi6+o3rNP6Hf1P9TEqEj5fjJAU5Zs1bGiEp3LDFPL1kFakzBdnZp7Kjo7XyUXL+nMdj/VqETBKNy9UZOGtNeHM7N1PDlO/Vu+rRY9/6n4Hcs1Osy5cSdmlf5W1ImcuerceYgmLVmokHebakDwYuWduCDlx2rwoHnKLFyknvd3VvDWU9LlS8qa5qXHygbj0hnnTV6EBrZrq1kbnTScO6602TM1pY9LAwIIRpVEMFCZ3ZJgFKZqduR4DQ/+SmvXrnUs1CjPTxQc3FftuwZr7obdOuM+7up3GOuC1axZsJIKzuqie7ySfYdxqeioEmM+1zsN/qLX/t5WvTy9NXT8HC1OzdbqSF+93fIV1apTR8+38FCPccuVln9KRzbPlF+3Jnql/guq066bvGan6WjRca3r21OvP1dHdZ3j27doogfLBkOXVFywW+sn99bbr9VUndqN1Ky1t0JnztCkEIJRJREMVGa3Ihinds7X2LEjNWXt4StjxdoTNVT9RvmpR5tmck2ZpZwT53Qoupf+2myoVmSt1fAWNeRalqLikovaF9ZUD1aqL70vqej0Ee1JSdD2lDTt25+n/GMFOnH+os6fOKTsnduVkJCghJQMHSj9FWHnRy6c0aE9O7UtyRl3wpJ3ukSXLktFR3KVsXVr6fFp6RnalnlYZ84cVnbOMRWXnso950Fl7nR+LmGbUnbt1/HThSrIP6yDR06rxH1MyWkdzjusoyfP6aL78ffYCEYlQzBQmd38YJxSyrwJCg4Yo9UHL3w7Xrx3gVx9R2nqxMH6sHkd1XjyKTXrWFM1G/pqzb7Dyt/orxbVn9bT1aur9ce1VbNSBaPqbASjkiEYqMxufjBKdO7UCRUcO6Gzzlvtb8edd9zHjhTo1KkCHd6/V9mZmdqXt0+5+4/pbHGJLhaf1IGc7NI/BJh7OFf7959Q0TXz3lwEA7cFwUBldmu+9L7zEAzcFgQDldkhdzDy8+/qP2te3oULFwgGbg+CgcrsWEaGcnfv1pkzZyq8ed6N3CuuPTt3XnOd3MGYOy9G8+YvrmIWEYzKhGCgMruYna39qanat3dvaTTu5pWGe2Vx6NCh0j9tXpyVVeH1Am4qgoHKrsSJRu62bdoQF6cVsbF3rbiVK5UcH08scPsQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAAJgQDACACcEAcMfbEauFQUEKG79Ipyraf6skztGYt5uo9u9/r6dLNZLnqLU6mlrBsT9E8hLNGRakL6cu0+mK9t9sBAPAHW97jCJdLn0+/GsVVLT/VtkSroHvfKoJY2doZ1yccub4q2Nrf8Wv366LFR3/fSVFaVIfl8aGLNTJivZ/p2wVrRypTq1Ha3+F+w0IBoA71elV0dowZpw2RlWiYLzr0pzZcTrrfpw1S75/+kBzYzfrfPljf4h/Mxjnl7rUuJ6/9rgfp27XwbBABU2ar0PXHXsDBAPAHSd1q5LHD5Fn646aEB6tQ0lXguHtq8D+n6rjGy1U88+P6dl2PeTq0VG1nqyrtgPDtHd7mjS3n7o8Xk2/uv9+PXD/C/p4cpouO3OWrBisj150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"><Controls><table class="Flex" tableType="Responsive" responsiveSizes="[]" layoutType="SD"><row><cell cellClass="stack-bottom-xxl"><table controlName="TableActions" tableType="Flex" justifyContent="Flex End"><row rowHeightWeb="61px"><cell><textblock controlName="Title" caption="Title" class="Title" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0"><action controlName="AddNew" onClickEvent="'AddNew'" caption="Adicionar" class="button" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0"><data attribute="&amp;Search" labelPosition="None" labelCaption="" class="AttributeSearch" inviteMessage="Tente uma busca" controlNameForStencil="&amp;Search" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;AutoResize&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value&gt;30chr&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell hAlign="Right" flexGrow="0" alignSelf="Center"><image controlName="ToggleFilters" image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-PageLast" class="Image-20" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;eventGX&lt;/Name&gt;&lt;Value&gt;'Hide'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;width&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;title&lt;/Name&gt;&lt;Value&gt;GXM_first&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row></table><table class="" tableType="Responsive" responsiveSizes="[]" layoutType="Web"><row><cell cellClass="stack-bottom-xxl"><table controlName="TableActions" tableType="Flex" flexWrap="Wrap" justifyContent="Flex End" alignItems="Center"><row rowHeightWeb="61px"><cell minHeight="30"><textblock controlName="Title" caption="EXEMPLO_Titulo" class="Title" /></cell><cell cellClass="inline-right-xl" hAlign="Right" flexGrow="0" minHeight="30"><action controlName="AddNew" onClickEvent="'AddNew'" caption="EXEMPLO_Adicionar" class="button Primary" /></cell><cell cellControlName="CellSearch" cellClass="" hAlign="Right" flexGrow="0" minHeight="30"><data attribute="&amp;Search" labelPosition="None" labelCaption="" class="AttributeSearch" inviteMessage="EXEMPLO_TenteUmaBusca" controlNameForStencil="&amp;Search" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;AutoResize&lt;/Name&gt;&lt;Value&gt;False&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;GxWidth&lt;/Name&gt;&lt;Value&gt;30chr&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell cellClass="inline-left-xl" hAlign="Right" flexGrow="0" minHeight="30"><image controlName="ToggleFilters" image="9fb193d9-64a4-4d30-b129-ff7c76830f7e-TemaExemplo.filter" class="Image-20 color-primary" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;eventGX&lt;/Name&gt;&lt;Value&gt;'Hide'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;width&lt;/Name&gt;&lt;Value /&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;title&lt;/Name&gt;&lt;Value&gt;Filters&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell></row></table></cell></row></table></Controls><Variables><Variable Name="Search"><Properties><Property><Name>Name</Name><Value>Search</Value></Property><Property><Name>OBJ_TYPE</Name><Value>id_OTYPE_VAR</Value></Property><Property><Name>idBasedOn</Name><Value>Domain:GAMUserIdentification, SegurancaExemplo</Value></Property></Properties></Variable></Variables></Root>]]></Source>
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
      <Value>EXEMPLO_HeaderWW</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>GAM Header WW</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
  <Categories>ColecaoStencilExemplo-web</Categories>
</Object>
```

## Moldes sanitizados completos de File

### Molde sanitizado de File 1 - `ArquivoImagemExemplo_gif`

- Perfil: `File` curto com `base64Binary` pequeno e propriedades de extracao em `Resources`.
- Uso operacional: boa referencia para assets binarios compactos acoplados ao pacote.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2024-09-28T20:51:45.0000000Z" checksum="b667dcf6150444093ca6130acc038fd1" fullyQualifiedName="ArquivoImagemExemplo_gif" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f33ac53a-282e-491b-b748-79f213e2dbe6" name="ArquivoImagemExemplo_gif" type="1132ac08-290f-4fd1-bd18-64777b7329d1" description="Arquivo Imagem Exemplo">
  <Part type="9b6155f9-f286-4ed5-bd15-67672e8ea320">
    <Data>
      <base64Binary>R0lGODlhCgBQAIAAAAAAAP///yH5BAUUAAEALAAAAAAKAFAAAAIahI+py+0Po5y02ouz3rz7D4biSJbmiabqihUAOw==</base64Binary>
    </Data>
    <Properties>
      <Property>
        <Name>FileName</Name>
        <Value>imagem-exemplo.gif</Value>
      </Property>
      <Property>
        <Name>FileExtension</Name>
        <Value>.gif</Value>
      </Property>
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
      <Value>ArquivoImagemExemplo_gif</Value>
    </Property>
    <Property>
      <Name>NetExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetExtractFolder</Name>
      <Value>Resources\\arquivo-exemplo</Value>
    </Property>
    <Property>
      <Name>NetCoreExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetCoreExtractFolder</Name>
      <Value>Resources\\arquivo-exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```

### Molde sanitizado de File 2 - `ArquivoConfiguracaoExemplo_props`

- Perfil: `File` textual pequeno em `.props`, ainda armazenado via `base64Binary`.
- Uso operacional: boa referencia para arquivos de configuracao e apoio a build com extracao controlada.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Object parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" user="SANITIZED\\USER" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="2025-05-14T20:38:37.0000000Z" checksum="c60dc61999093d19c1b8571fb805f188" fullyQualifiedName="ArquivoConfiguracaoExemplo_props" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361" guid="f818bc6d-1bb8-4459-88f4-4c781953252f" name="ArquivoConfiguracaoExemplo_props" type="1132ac08-290f-4fd1-bd18-64777b7329d1" description="ArquivoConfiguracaoExemplo.props">
  <Part type="9b6155f9-f286-4ed5-bd15-67672e8ea320">
    <Data>
      <base64Binary>PFByb2plY3Q+DQoJPEl0ZW1Hcm91cD4NCgkJPFBhY2thZ2VSZWZlcmVuY2UgSW5jbHVkZT0iQm91bmN5Q2FzdGxlLkNyeXB0b2dyYXBoeSIgVmVyc2lvbj0iMi40LjAiLz4NCgkJPFBhY2thZ2VSZWZlcmVuY2UgSW5jbHVkZT0iU3lzdGVtLlNlY3VyaXR5LkNyeXB0b2dyYXBoeS5YbWwiIFZlcnNpb249IjguMC4wIi8+DQoJPC9JdGVtR3JvdXA+DQo8L1Byb2plY3Q+</base64Binary>
    </Data>
    <Properties>
      <Property>
        <Name>FileName</Name>
        <Value>ArquivoConfiguracaoExemplo.props</Value>
      </Property>
      <Property>
        <Name>FileExtension</Name>
        <Value>.props</Value>
      </Property>
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
      <Value>ArquivoConfiguracaoExemplo_props</Value>
    </Property>
    <Property>
      <Name>Description</Name>
      <Value>SignXml.props</Value>
    </Property>
    <Property>
      <Name>NetCoreExtract</Name>
      <Value>True</Value>
    </Property>
    <Property>
      <Name>NetCoreExtractFolder</Name>
      <Value>..\\build-exemplo</Value>
    </Property>
    <Property>
      <Name>IsDefault</Name>
      <Value>False</Value>
    </Property>
  </Properties>
</Object>
```
