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

Quando `-ReportPath` e informado, o wrapper grava um relatorio atomico de execucao
em JSON com fases, estado do pacote e decisao do inventario; com path valido o
pos-inventario do motor compartilhado liga FailOnDeltaMismatch e
FailOnUnknownTypes, e inventario com exit diferente de 0 pode marcar
status=bloqueado no stdout e alterar o exit do empacotamento. Sem -ReportPath,
o inventario corre em modo informativo e nao promove esse exit. O relatorio nao
prova importacao real, build ou evidencia da IDE.

O gate de drift frente-vs-acervo (Test-GeneXusFrontAcervoDrift.ps1) executa
sempre antes do empacotamento (fail-closed). -AcervoPath e opcional; quando
omitido, o acervo canonico <RepoRoot>/ObjetosDaKbEmXml e resolvido
automaticamente. Sem acervo resolvivel, o empacotamento e bloqueado. O gate
detecta XMLs na frente com lastUpdate mais antigo que o homonimo no acervo e
bloqueia Object/@type divergente quando frente e acervo compartilham o mesmo
guid. Protecao mecanica parcial nesta versao: o 9-FD tambem detecta remocao
forte de trailing whitespace herdado contra baseline por GUID unico; nao
detecta introducao de trailing whitespace novo e nao e detector completo de
whitespace, reindentacao ou EOL. Acervo ambiguo por guid gera diagnostico informativo
front-object-type-drift-ambiguous-acervo, sem escolher tipo automaticamente.

O gate 9-FD também compara assinaturas funcionais de Attribute e Domains autônomos. -ApprovedAttributeSizeGrowth encaminha ao motor cada tupla exata <GUID>|<campo>|<valor-acervo>|<valor-frente>, após solicitação explícita do usuário nesta execução. -ApprovedDomainChangesPath encaminha o arquivo JSON UTF-8 sem BOM kind=domain-drift-approvals/schemaVersion=1; cada autorização deve corresponder exatamente a um finding. Identidade inválida ou ambígua, colisões, leitura incompleta, Domain aninhado, campos destrutivos, redução de tamanho e autorizações inválidas ou sem correspondência continuam bloqueando.

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
ou remocao forte de trailing whitespace herdado
(front-textual-fidelity-trim-removal-churn), o empacotamento e abortado.
Ambiguidade por guid no acervo e diagnostico informativo, reportado como
front-object-type-drift-ambiguous-acervo.

.PARAMETER ApprovedAttributeSizeGrowth
Uma ou mais tuplas exatas <GUID>|<campo>|<valor-acervo>|<valor-frente>, solicitadas explicitamente pelo usuário nesta execução. O wrapper encaminha os valores sem transformação ao gate 9-FD.

.PARAMETER ApprovedDomainChangesPath
Caminho do JSON UTF-8 sem BOM de aprovações exatas, com kind=domain-drift-approvals e schemaVersion=1. O wrapper encaminha o caminho ao motor compartilhado, que valida a correspondência integral com os findings.

.PARAMETER ReportPath
Caminho absoluto, novo e terminado em `.json`, preferencialmente sob `Temp`.
A pasta pai deve existir; caminhos em areas de acervo, frente, scripts,
`KbIntelligence`, `.git`, `ArquivoMorto`, `historico`,
`PacotesGeradosParaImportacaoNaKbNoGenexus`, `XpzExportadosPelaIDE` ou artefatos
do pacote sao bloqueados.
Com ReportPath valido, o pos-inventario liga FailOnDeltaMismatch e
FailOnUnknownTypes; sem ReportPath, o inventario permanece informativo.

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

    [string]$ReportPath,

    [string[]]$ApprovedAttributeSizeGrowth = @(),

    [string]$ApprovedDomainChangesPath,

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

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $argsForEngine.ReportPath = $ReportPath
}

if ($ApprovedAttributeSizeGrowth.Count -gt 0) {
    $argsForEngine.ApprovedAttributeSizeGrowth = $ApprovedAttributeSizeGrowth
}

if (-not [string]::IsNullOrWhiteSpace($ApprovedDomainChangesPath)) {
    $argsForEngine.ApprovedDomainChangesPath = $ApprovedDomainChangesPath
}

& $enginePath @argsForEngine
