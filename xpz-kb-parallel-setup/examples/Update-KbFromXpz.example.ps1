<#
.SYNOPSIS
Wrapper local sanitizado para atualizar `ObjetosDaKbEmXml` a partir de um XPZ/XML da KB.

.DESCRIPTION
Usa os caminhos da pasta paralela da KB e delega a extração/verificação para o
motor compartilhado desta base metodológica.

.PARAMETER InputPath
Caminho para um .xpz, para o XML do pacote exportado ou para a pasta que contém
esse XML.

.PARAMETER VerifyOnly
Executa apenas conferência, sem regravar arquivos no destino.

.PARAMETER FullSnapshot
Além da conferência do pacote atual, compara o snapshot inteiro do destino com o
conteúdo do pacote. Use este modo para exports completos da KB.

.PARAMETER ReportPath
Caminho opcional para salvar um relatório JSON com o resultado.

.PARAMETER KeepReport
Mantém o relatório JSON mesmo quando a execução termina sem erro.

.PARAMETER KbMetadataPath
Caminho opcional para salvar metadados da KB em Markdown.

.PARAMETER NoGitSummary
Suprime resumo local de alterações Git em `ObjetosDaKbEmXml`.

.PARAMETER ExpectedItems
Lista opcional de itens esperados no formato `Tipo:Nome`, repassada ao motor
compartilhado para comparar foco esperado versus retorno oficial da KB.

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente'

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente', 'Procedure:GeraBoleto'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [switch]$VerifyOnly,

    [switch]$FullSnapshot,

    [string]$ReportPath,

    [switch]$KeepReport,

    [string]$KbMetadataPath,

    [string[]]$ExpectedItems = @(),

    [switch]$NoGitSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills\scripts\Sync-GeneXusXpzToXml.ps1"
$destinationRoot = Join-Path $repoRoot "ObjetosDaKbEmXml"

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

$params = @{
    InputPath       = $InputPath
    DestinationRoot = $destinationRoot
}

if ($VerifyOnly) {
    $params.VerifyOnly = $true
}

if ($FullSnapshot) {
    $params.FullSnapshot = $true
}

if ($ReportPath) {
    $params.ReportPath = $ReportPath
}

if ($KeepReport) {
    $params.KeepReport = $true
}

if ($KbMetadataPath) {
    $params.KbMetadataPath = $KbMetadataPath
}

if ($ExpectedItems.Count -gt 0) {
    $params.ExpectedItems = @($ExpectedItems)
}

$result = & $enginePath @params

if (-not $NoGitSummary) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git -C $repoRoot status --short -- ObjetosDaKbEmXml
    }
}

$result
