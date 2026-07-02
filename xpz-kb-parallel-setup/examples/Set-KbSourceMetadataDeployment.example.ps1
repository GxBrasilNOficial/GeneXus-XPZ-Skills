#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para gravar campos de environment/deploy em kb-source-metadata.md.

.DESCRIPTION
Delega a scripts/Set-XpzKbSourceMetadataDeployment.ps1 no repositório GeneXus-XPZ-Skills.
A lista kb_environment_names vem SOMENTE de -KbEnvironmentNames confirmada pelo usuário.
O mapeamento de output por environment vem SOMENTE de -KbEnvironmentOutputDirs confirmado
pelo usuário; não fazer scan de pastas da KB nativa.
Por padrão valida cada nome via SetActiveEnvironment headless (MSBuild).

NOTA DE INVOCACAO: os parametros de lista (-KbEnvironmentNames, -KbEnvironmentOutputDirs,
-KbEnvironmentWebDirs) exigem invocacao nativa PowerShell com @(...), como no .EXAMPLE abaixo.
NAO invocar por `pwsh -File ... -KbEnvironmentNames a,b`: nesse modo a virgula NAO vira array,
o valor chega como um unico elemento com a virgula embutida e o motor barra com
"BLOCK: KbEnvironmentOutputDirs contem environment '...' que nao consta em -KbEnvironmentNames".

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\Set-KbSourceMetadataDeployment.ps1 `
    -KbParallelRoot "C:\Dev\Prod\Gx_FabricaBrasil" `
    -DeploymentEnvironmentName "NETPostgreSQL" `
    -DeploymentHostingKind "dotnet-core-self-host" `
    -KbEnvironmentNames @("NETPostgreSQL", ".Net Environment") `
    -KbEnvironmentOutputDirs @("NETPostgreSQL=NETPostgreSQL", ".Net Environment=NETFrameworkPostgreSQL") `
    -KbNativePath "C:\GxModels\FabricaBrasil18" `
    -InventoryWorkingDirectory "C:\Dev\Prod\Gx_FabricaBrasil\Temp\msbuild-inventory"
#>

param(
    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentEnvironmentName,

    [Parameter(Mandatory = $true)]
    # Fase 2 (paridade Java/Tomcat): [ValidateSet] removido. O motor compartilhado valida o valor contra o
    # registro-fonte-unica (GeneXusKbHostingKindSupport.ps1) em runtime — aceita dotnet-core-self-host,
    # dotnet-framework-iis e java-tomcat. Manter o [ValidateSet] .NET-only aqui barraria java-tomcat antes do motor.
    [string]$DeploymentHostingKind,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentNames,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentOutputDirs,

    [string[]]$KbEnvironmentWebDirs,

    [string]$KbNativePath,

    [string]$InventoryWorkingDirectory,

    [string]$InventoryLogPath,

    [switch]$SkipEnvironmentNamesMsBuildValidation,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engineScript = Join-Path $SharedSkillsRoot 'scripts\Set-XpzKbSourceMetadataDeployment.ps1'

if (-not (Test-Path -LiteralPath $engineScript -PathType Leaf)) {
    throw "Motor compartilhado ausente: $engineScript"
}

$invokeArgs = @{
    DeploymentEnvironmentName = $DeploymentEnvironmentName
    DeploymentHostingKind     = $DeploymentHostingKind
    KbEnvironmentNames        = $KbEnvironmentNames
    KbEnvironmentOutputDirs   = $KbEnvironmentOutputDirs
}
if ($KbParallelRoot) { $invokeArgs['KbParallelRoot'] = $KbParallelRoot }
if ($MetadataPath) { $invokeArgs['MetadataPath'] = $MetadataPath }
if ($KbEnvironmentWebDirs) { $invokeArgs['KbEnvironmentWebDirs'] = $KbEnvironmentWebDirs }
if ($KbNativePath) { $invokeArgs['KbNativePath'] = $KbNativePath }
if ($InventoryWorkingDirectory) { $invokeArgs['InventoryWorkingDirectory'] = $InventoryWorkingDirectory }
if ($InventoryLogPath) { $invokeArgs['InventoryLogPath'] = $InventoryLogPath }
if ($SkipEnvironmentNamesMsBuildValidation.IsPresent) { $invokeArgs['SkipEnvironmentNamesMsBuildValidation'] = $true }
if ($GeneXusDir) { $invokeArgs['GeneXusDir'] = $GeneXusDir }
if ($MsBuildPath) { $invokeArgs['MsBuildPath'] = $MsBuildPath }
if ($DatabaseUser) { $invokeArgs['DatabaseUser'] = $DatabaseUser }
if ($DatabasePassword) { $invokeArgs['DatabasePassword'] = $DatabasePassword }
if ($AsJson.IsPresent) { $invokeArgs['AsJson'] = $true }

& $engineScript @invokeArgs
exit $LASTEXITCODE
