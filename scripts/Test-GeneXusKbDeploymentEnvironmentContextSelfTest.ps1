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

$environmentPattern = "The active environment is '([^']+)'"
$switchedText = "The active environment is '.Net Environment'`n> Set Active Environment Sucesso`nThe active environment is 'NETPostgreSQL'`n"
$singleReadingText = "The active environment is '.Net Environment'`n"
$readingCases = @(
    @{ Name = 'troca com leitura posterior'; Text = $switchedText; Requested = 'NETPostgreSQL'; SetFailed = $false; AtOpen = '.Net Environment'; Effective = 'NETPostgreSQL'; Count = 2 },
    @{ Name = 'sem troca pedida'; Text = $singleReadingText; Requested = ''; SetFailed = $false; AtOpen = '.Net Environment'; Effective = '.Net Environment'; Count = 1 },
    @{ Name = 'troca pedida sem leitura posterior'; Text = $singleReadingText; Requested = 'NETPostgreSQL'; SetFailed = $false; AtOpen = '.Net Environment'; Effective = $null; Count = 1 },
    @{ Name = 'Set falhou'; Text = $singleReadingText; Requested = 'Inexistente'; SetFailed = $true; AtOpen = '.Net Environment'; Effective = '.Net Environment'; Count = 1 },
    @{ Name = 'stdout vazio'; Text = ''; Requested = 'NETPostgreSQL'; SetFailed = $false; AtOpen = $null; Effective = $null; Count = 0 }
)
foreach ($case in $readingCases) {
    $readings = Resolve-GeneXusKbActiveContextReadings -Text $case.Text -Pattern $environmentPattern -RequestedName $case.Requested -SetFailed $case.SetFailed
    if ($readings.AtOpen -ne $case.AtOpen -or $readings.Effective -ne $case.Effective -or $readings.ReadingCount -ne $case.Count) {
        throw ("Resolve-GeneXusKbActiveContextReadings ({0}): esperado AtOpen='{1}' Effective='{2}' Count={3}; recebeu AtOpen='{4}' Effective='{5}' Count={6}." -f $case.Name, $case.AtOpen, $case.Effective, $case.Count, $readings.AtOpen, $readings.Effective, $readings.ReadingCount)
    }
}

'GENEXUS_KB_DEPLOYMENT_ENVIRONMENT_CONTEXT_SELFTEST_OK'
