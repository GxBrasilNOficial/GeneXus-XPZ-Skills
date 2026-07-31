#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para resolver o .cs gerado de um objeto GeneXus.

.DESCRIPTION
Delega ao motor compartilhado Resolve-GeneXusGeneratedCsPath.ps1, que le
kb-source-metadata.md e usa kb_environment_web_dirs para montar o caminho direto
do .cs sem varredura recursiva da KB nativa.

Se o metadata não tiver o mapeamento de output/web por environment, o motor
bloqueia e encaminha para xpz-kb-parallel-setup.

.PARAMETER KbPath
Caminho da KB nativa GeneXus.

.PARAMETER ObjectName
Nome do objeto GeneXus.

.PARAMETER ObjectType
Tipo do objeto GeneXus. Informativo.

.PARAMETER EnvironmentName
Environment GeneXus. Quando omitido, usa deployment_environment_name ou o único
environment em metadata single-environment.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada GeneXus-XPZ-Skills.

.EXAMPLE
.\Resolve-KbGeneratedCsPath.ps1 -KbPath C:\GxModels\MinhaKb -EnvironmentName NETPostgreSQL -ObjectName WpProcessaArquivo -ObjectType WebPanel -AsJson
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [string]$ObjectType,

    [string]$EnvironmentName,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\Resolve-GeneXusGeneratedCsPath.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared generated .cs resolver not found: $enginePath"
}

$argsForEngine = @{
    KbPath         = $KbPath
    ParallelKbRoot = $repoRoot
    ObjectName     = $ObjectName
}

if (-not [string]::IsNullOrWhiteSpace($ObjectType)) {
    $argsForEngine.ObjectType = $ObjectType
}

if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) {
    $argsForEngine.EnvironmentName = $EnvironmentName
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

$global:LASTEXITCODE = $null
& $enginePath @argsForEngine
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
