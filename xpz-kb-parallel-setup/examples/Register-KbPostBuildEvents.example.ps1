#requires -Version 7.4

<#
.SYNOPSIS
Wrapper local para registrar os eventos pos-build conhecidos de um environment em kb-source-metadata.md.

.DESCRIPTION
Delega a scripts/Register-GeneXusKbPostBuildEvents.ps1 no repositório GeneXus-XPZ-Skills.
Le os eventos pos-build observados no JSON de um build (stdoutSignals.postBuildEvents), filtra
inertes (REM comentado, duração TimeSpan válida ou data civil válida), gera fingerprints SHA-256 e grava kb_environment_post_build_event_hashes + a
secao-espelho legivel. Ação sensivel (desarma o rebaixamento por evento pos-build daquele
environment): exige confirmacao. Sem -ConfirmRegistration, o motor pede frase exata via Read-Host;
o agente só passa -ConfirmRegistration após o usuário aprovar explicitamente os eventos listados.
O motor recusa (BLOCK), sem gravar nada, o build que não sirva de base do registro, com o mesmo
veredito da dimensão pos-build/base da auditoria de setup, e também quando -EnvironmentName diverge
de observedContext.ActiveEnvironment do JSON. Em -BuildResultJsonPath, use o JSON exato que a
evidência de pos-build/base cita como apto para o environment (formato "build Temp\..."); a linha
pos-build/base é agregada e não serve para escolher o environment. A regra completa de aptidão está
na seção "Registro de eventos pos-build" de xpz-kb-parallel-setup/SKILL.md.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
# JSON citado na evidência de pos-build/base (a cópia automática tem nome por execução).
.\Register-KbPostBuildEvents.ps1 `
    -BuildResultJsonPath "C:\Dev\Prod\Gx_FabricaBrasil\Temp\xpz-msbuild-build\buildall-20261123-161907-a38d2b47.json" `
    -EnvironmentName "NETPostgreSQL" `
    -KbParallelRoot "C:\Dev\Prod\Gx_FabricaBrasil" `
    -ConfirmRegistration `
    -AsJson
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BuildResultJsonPath,

    [string]$EnvironmentName,

    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [switch]$ConfirmRegistration,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engineScript = Join-Path $SharedSkillsRoot 'scripts\Register-GeneXusKbPostBuildEvents.ps1'

if (-not (Test-Path -LiteralPath $engineScript -PathType Leaf)) {
    throw "Motor compartilhado ausente: $engineScript"
}

$invokeArgs = @{
    BuildResultJsonPath = $BuildResultJsonPath
}
if ($EnvironmentName) { $invokeArgs['EnvironmentName'] = $EnvironmentName }
if ($KbParallelRoot) { $invokeArgs['KbParallelRoot'] = $KbParallelRoot }
if ($MetadataPath) { $invokeArgs['MetadataPath'] = $MetadataPath }
if ($ConfirmRegistration.IsPresent) { $invokeArgs['ConfirmRegistration'] = $true }
if ($AsJson.IsPresent) { $invokeArgs['AsJson'] = $true }

$global:LASTEXITCODE = $null
& $engineScript @invokeArgs
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
