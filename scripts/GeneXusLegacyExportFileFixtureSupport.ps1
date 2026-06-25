#requires -Version 7.4
<#
.SYNOPSIS
    Gerador da fixture de export legado GeneXus 9 (iso-8859-1) para self-tests.

.DESCRIPTION
    Este arquivo e versionado em UTF-8/LF (versiona limpo). A funcao grava a fixture em
    iso-8859-1 (Latin-1) numa pasta temporaria informada pelo chamador, com bytes de acento
    Latin-1 reais — em vez de versionar um .xml iso-8859-1 (fragil: editores/git podem
    transcodificar para UTF-8 e quebrar o teste de encoding). Os self-tests geram a fixture
    em Temp on-the-fly e a consomem.

    Cobertura da fixture (spec congelada Fase 2, v2.8.5, §6.1):
    - equivalent com LastUpdate (Transaction), WorkPanel (correcao de tag), Procedure SEM
      LastUpdate (sentinela);
    - orphan Report e Menubar;
    - bloco Attributes com 2 GXAtt (Title com acento);
    - payload adversario: <Objects>/<Object> e <Attribute> aninhados em Structure (>=2 niveis),
      para provar XPath-nao-vaza;
    - acentos Latin-1 (Configuracao, Parametros, Relatorio, Endereco).
#>

Set-StrictMode -Version Latest

function New-GeneXusLegacyExportFixtureFile {
    <# Grava a fixture iso-8859-1 em -Path e devolve o caminho. #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet('CRLF', 'LF')][string]$Eol = 'CRLF'
    )

    $content = @'
<?xml version='1.0' encoding='iso-8859-1'?>
<ExportFile>
  <Model>
    <Name>Financeiro</Name>
  </Model>
  <KMW>
    <MajorVersion>2</MajorVersion>
    <MinorVersion>2</MinorVersion>
    <Path>C:\ModelsGx90\Produção\FIN90</Path>
    <MaxGxBuildSaved>2601</MaxGxBuildSaved>
  </KMW>
  <GXObject>
    <Transaction>
      <Info>
        <Name>Cliente</Name>
        <Description>Configuração de clientes</Description>
        <Folder>FIN</Folder>
      </Info>
      <LastUpdate>2001-01-15 12:28:00GMT</LastUpdate>
      <Structure>
        <Source><![CDATA[ClienteId*
ClienteNome]]></Source>
        <Objects>
          <Object type="aninhado-nao-deve-vazar" name="NaoDeveVazar"/>
        </Objects>
        <Attribute>colSpanInternoNaoDeveVazar</Attribute>
      </Structure>
    </Transaction>
  </GXObject>
  <GXObject>
    <WorkPanel>
      <Info>
        <Name>CbCdPmF</Name>
        <Description>Cadastro de Parâmetros</Description>
      </Info>
    </WorkPanel>
  </GXObject>
  <GXObject>
    <Procedure>
      <Info>
        <Name>RelConfig</Name>
        <Description>Relatório sem data declarada</Description>
      </Info>
    </Procedure>
  </GXObject>
  <GXObject>
    <Report>
      <Info>
        <Name>RelMov</Name>
        <Description>Relatório de Movimentação</Description>
      </Info>
      <LastUpdate>2003-05-10 09:00:00GMT</LastUpdate>
    </Report>
  </GXObject>
  <GXObject>
    <Menubar>
      <Info>
        <Name>MenuPrincipal</Name>
      </Info>
      <LastUpdate>2003-05-10 09:00:00GMT</LastUpdate>
    </Menubar>
  </GXObject>
  <Attributes>
    <GXAtt>
      <Attribute>
        <Id>237</Id>
        <Name>Usrsnh</Name>
        <Title>Senha</Title>
        <LastUpdate>2001-01-15 12:28:00GMT</LastUpdate>
      </Attribute>
    </GXAtt>
    <GXAtt>
      <Attribute>
        <Id>238</Id>
        <Name>Endereco</Name>
        <Title>Endereço de cobrança</Title>
        <LastUpdate>2001-01-15 12:28:00GMT</LastUpdate>
      </Attribute>
    </GXAtt>
  </Attributes>
</ExportFile>
'@

    $newLine = if ($Eol -eq 'CRLF') { "`r`n" } else { "`n" }
    $normalized = (($content -replace "`r`n", "`n") -replace "`n", $newLine)

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir)
    }
    [System.IO.File]::WriteAllText($Path, $normalized, [System.Text.Encoding]::GetEncoding('iso-8859-1'))
    return $Path
}
