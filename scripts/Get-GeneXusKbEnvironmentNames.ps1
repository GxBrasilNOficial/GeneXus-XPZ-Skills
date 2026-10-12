#requires -Version 7.4

<#
.SYNOPSIS
    Inventaria environments GeneXus registrados na KB via MSBuild (somente leitura).

.DESCRIPTION
    Inventario automático por scan de pastas da KB nativa foi removido. Informe -CandidateNames
    com a lista explicita declarada pelo usuário; o script valida cada nome via SetActiveEnvironment
    headless (não descobre candidatos por pasta).

.PARAMETER KbNativePath
    Caminho da KB nativa GeneXus (ex.: C:\GxModels\FabricaBrasil18).

.PARAMETER WorkingDirectory
    Diretório de trabalho para artefatos temporarios e probe MSBuild.

.PARAMETER LogPath
    Caminho do log JSON do probe inicial (opcional).

.PARAMETER GeneXusDir
    Instalacao GeneXus (opcional — resolvida pelo probe).

.PARAMETER MsBuildPath
    Caminho do MSBuild.exe (opcional — resolvido pelo probe).

.PARAMETER CandidateNames
    Lista explicita de environments declarados pelo usuário. Obrigatório. Cada nome e validado
    via SetActiveEnvironment headless; não ha scan de pastas da KB nativa.

.PARAMETER DatabaseUser
    Usuário de banco para abertura headless (opcional).

.PARAMETER DatabasePassword
    Senha de banco para abertura headless (opcional).

.PARAMETER AsJson
    Emite JSON em vez de texto simples.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbNativePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [Parameter(Mandatory = $true)]
    [string[]]$CandidateNames,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson,

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbEnvironmentInventorySupport.ps1')

$result = Get-GeneXusKbRegisteredEnvironmentNamesFromMsBuild `
    -KbNativePath $KbNativePath `
    -WorkingDirectory $WorkingDirectory `
    -LogPath $LogPath `
    -GeneXusDir $GeneXusDir `
    -MsBuildPath $MsBuildPath `
    -CandidateNames $CandidateNames `
    -DatabaseUser $DatabaseUser `
    -DatabasePassword $DatabasePassword `
    -VerboseLog:$VerboseLog

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $namesJoined = ($result.kb_environment_names -join ', ')
    Write-Output ("KB_ENVIRONMENT_INVENTORY_OK: count={0} names={1}" -f $result.kb_environment_count, $namesJoined)
}
