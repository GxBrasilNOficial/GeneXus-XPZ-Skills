#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

$dictionaryContext = [ordered]@{
    validationEnvironmentResolved = 'Prototipo_18U13'
    kbSourceMetadataPath          = 'C:\temp\kb-source-metadata.md'
}
$psObjectContext = [pscustomobject]@{
    validationEnvironmentResolved = 'Prototipo_18U13'
    kbSourceMetadataPath          = 'C:\temp\kb-source-metadata.md'
}

foreach ($context in @($dictionaryContext, $psObjectContext)) {
    if ((Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $context -Name 'validationEnvironmentResolved') -ne 'Prototipo_18U13') {
        throw "Falha ao ler validationEnvironmentResolved de $($context.GetType().FullName)."
    }
    if (-not (Test-GeneXusKbActiveEnvironmentMatchesValidation -ActiveEnvironment 'prototipo_18u13' -DeploymentEnvironmentContext $context)) {
        throw "Comparacao case-insensitive falhou para $($context.GetType().FullName)."
    }
}

if ($null -ne (Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $psObjectContext -Name 'missing')) {
    throw 'Propriedade ausente deveria retornar null.'
}

foreach ($wrapperName in @('Invoke-GeneXusKbBuildAll.ps1', 'Invoke-GeneXusKbSpecifyGenerate.ps1')) {
    $wrapperText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $wrapperName)
    if ($wrapperText -match '\$script:DeploymentEnvironmentContext\[') {
        throw "$wrapperName ainda possui indexacao direta incompatível com PSCustomObject."
    }
    if ($wrapperText -notmatch 'Get-GeneXusKbDeploymentContextValue') {
        throw "$wrapperName nao usa o helper compartilhado de contexto."
    }
}

'GENEXUS_KB_DEPLOYMENT_ENVIRONMENT_CONTEXT_SELFTEST_OK'
