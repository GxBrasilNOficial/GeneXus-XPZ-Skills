#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para gate de colisao de pacote da pasta paralela.

.DESCRIPTION
Executa o script compartilhado `Test-XpzPackageCollision.ps1` antes de qualquer
gravacao de `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` em
`PacotesGeradosParaImportacaoNaKbNoGenexus`.

Este wrapper deve ser o unico ponto local para decidir se a rodada `nn` pode
ser gravada ou se a frente deve bloquear por colisao.

.PARAMETER FrontPrefix
Prefixo nominal da frente no formato `NomeCurto_GUID_YYYYMMDD`.

.PARAMETER NN
Rodada curta pretendida para o pacote, por exemplo `01`.

.PARAMETER OutputDir
Caminho opcional da pasta de saida. Quando omitido, usa
`PacotesGeradosParaImportacaoNaKbNoGenexus` na raiz da pasta paralela.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\Test-KbPackageCollision.ps1 -FrontPrefix MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01

.EXAMPLE
.\Test-KbPackageCollision.ps1 -FrontPrefix MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01 -OutputDir C:\KB\PacotesGeradosParaImportacaoNaKbNoGenexus
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontPrefix,

    [Parameter(Mandatory = $true)]
    [string]$NN,

    [string]$OutputDir,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $OutputDir) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $OutputDir = Join-Path $repoRoot "PacotesGeradosParaImportacaoNaKbNoGenexus"
}

$enginePath = Join-Path $SharedSkillsRoot "scripts\Test-XpzPackageCollision.ps1"
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Shared package collision script not found: $enginePath"
}

& $enginePath -FrontPrefix $FrontPrefix -NN $NN -OutputDir $OutputDir
