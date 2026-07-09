#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para criar pacote import_file.xml de uma frente da KB.

.DESCRIPTION
Executa o wrapper compartilhado `New-XpzImportPackage.ps1`, que chama o motor Python,
le
`kb-source-metadata.md`, coleta os XMLs de
`ObjetosGeradosParaImportacaoNaKbNoGenexus\<FrontName>` e grava o pacote em
`PacotesGeradosParaImportacaoNaKbNoGenexus`.

Este wrapper e recomendado quando a pasta paralela adota empacotamento local
recorrente e precisa de comando curto, auditavel e aderente a allowlist.

O gate de drift frente-vs-acervo (Test-GeneXusFrontAcervoDrift.ps1) executa
sempre antes do empacotamento (fail-closed). -AcervoPath e opcional; quando
omitido, o acervo canonico <RepoRoot>/ObjetosDaKbEmXml e resolvido
automaticamente. Sem acervo resolvivel, o empacotamento e bloqueado. O gate
detecta XMLs na frente com lastUpdate mais antigo que o homonimo no acervo e
bloqueia Object/@type divergente quando frente e acervo compartilham o mesmo
guid. Acervo ambiguo por guid gera diagnostico informativo
front-object-type-drift-ambiguous-acervo, sem escolher tipo automaticamente.

.PARAMETER FrontName
Nome da subpasta da frente no formato `NomeCurto_GUID_YYYYMMDD`.

.PARAMETER NN
Rodada curta pretendida para o pacote. Default: 01.

.PARAMETER TemplatePackagePath
Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
Dependencies e ObjectsIdentityMapping. Quando o template trouxer Attributes de
topo e a frente não trouxer atributos explicitos, o motor preserva esses
Attributes. Quando omitido, o motor usa envelope mínimo derivado de
kb-source-metadata.md.

.PARAMETER AcervoPath
Caminho para a pasta do acervo oficial (ObjetosDaKbEmXml). Opcional: quando
omitido, o acervo canonico <RepoRoot>/ObjetosDaKbEmXml e resolvido
automaticamente. O gate de drift frente-vs-acervo executa sempre antes do
empacotamento (fail-closed); sem acervo resolvivel, o empacotamento e bloqueado.
Se o gate detectar que um XML da frente está mais antigo que o homonimo no
acervo ou que o mesmo guid tem Object/@type divergente entre frente e acervo,
o empacotamento e abortado. Ambiguidade por guid no acervo e diagnostico
informativo, reportado como front-object-type-drift-ambiguous-acervo.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\New-KbImportPackage.ps1 -FrontName MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\New-XpzImportPackage.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared import package script not found: $enginePath"
}

$argsForEngine = @{
    RepoRoot = $repoRoot
    FrontName = $FrontName
    NN = $NN
}

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $argsForEngine.TemplatePackagePath = $TemplatePackagePath
}

if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $argsForEngine.AcervoPath = $AcervoPath
}

& $enginePath @argsForEngine
