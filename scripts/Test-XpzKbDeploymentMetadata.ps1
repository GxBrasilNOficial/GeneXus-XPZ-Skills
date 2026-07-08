#requires -Version 7.4
<#
.SYNOPSIS
    Valida plausibilidade semantica dos campos de environment/deploy em kb-source-metadata.md.

.DESCRIPTION
    Gate de setup (xpz-kb-parallel-setup): rejeita metadata legado com nomes tipicos de scan
    por pastas web\ (CSharpModel, Data*), inconsistencias de contagem e mapeamento
    de output/web ausente ou divergente. A lista correta vem do usuário via
    -KbEnvironmentNames e -KbEnvironmentOutputDirs; este gate não valida existência no GeneXus (MSBuild).
    Para java-tomcat, exige metadata Java dedicado ou retorna PENDENTE/BLOCK conforme ausencia
    ou inconsistencia dos campos.

.PARAMETER MetadataPath
    Caminho para kb-source-metadata.md.

.PARAMETER AsJson
    Emite JSON em vez de linhas textuais.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

$MetadataPath = [System.IO.Path]::GetFullPath($MetadataPath)

$result = Test-GeneXusKbDeploymentMetadataPlausibility -MetadataPath $MetadataPath

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
    if ($result.status -eq 'BLOCK') { exit 1 }
    exit 0
}

switch ($result.status) {
    'OK' {
        Write-Output 'DEPLOYMENT_METADATA_PLAUSIBILITY_OK'
        Write-Output ("deployment_environment_name: {0}" -f $result.deployment_environment_name)
        Write-Output ("kb_environment_count: {0}" -f $result.kb_environment_count)
        Write-Output ("kb_environment_names: {0}" -f ($result.kb_environment_names -join ', '))
        Write-Output ("kb_environment_output_dirs: {0}" -f (Join-GeneXusKbEnvironmentMap -Map $result.kb_environment_output_dirs))
        Write-Output ("kb_environment_web_dirs: {0}" -f (Join-GeneXusKbEnvironmentMap -Map $result.kb_environment_web_dirs))
        if ($result.deployment_hosting_kind -ieq 'java-tomcat') {
            Write-Output ("kb_environment_servlet_dirs: {0}" -f (Join-GeneXusKbEnvironmentMap -Map $result.kb_environment_servlet_dirs))
            Write-Output ("kb_environment_app_package: {0}" -f (Join-GeneXusKbEnvironmentMap -Map $result.kb_environment_app_package))
            Write-Output ("kb_environment_servlet_flavor: {0}" -f (Join-GeneXusKbEnvironmentMap -Map $result.kb_environment_servlet_flavor))
        }
    }
    'PENDENTE' {
        foreach ($warning in $result.warnings) {
            Write-Output "PENDENTE: $warning"
        }
        Write-Output 'DEPLOYMENT_METADATA_PENDENTE'
        exit 0
    }
    'BLOCK' {
        foreach ($failure in $result.failures) {
            Write-Output "BLOCK: $failure"
        }
        Write-Output 'DEPLOYMENT_METADATA_IMPLAUSIVEL'
        exit 1
    }
    default {
        throw ("BLOCK: status de plausibilidade desconhecido: {0}" -f $result.status)
    }
}
