#requires -Version 7.4
<#
.SYNOPSIS
    Trava deterministica do contrato de nomenclatura de parâmetros das skills XPZ.

.DESCRIPTION
    Verifica, via metadados de Get-Command (sem executar os scripts nem exigir KB),
    que os wrappers/motores compartilhados expoem os nomes canonicos e aliases
    acordados:

      - Selecao de objeto: nome canonico -ObjectList; -ObjectNames aceito como
        sinonimo. No motor de export, -ObjectList e [string[]] com alias ObjectNames.
      - Entrada primaria: nome canonico -InputPath, com alias -Path.
      - Familia de import (entrada e um .xpz): -InputPath com aliases -XpzPath e -Path.
      - Regra de direcao: no export, o .xpz e SAIDA e mantem o nome por papel
        -XpzPath; NÃO deve ganhar alias -InputPath (negativo explicito).
      - Contrato de saida do motor de sanidade: Test-GeneXusSourceSanity.ps1 emite
        JSON por padrão e NÃO expoe -AsJson (negativo explicito); trava contra
        wrappers locais que carreguem essa flag de outro motor (ex: Get-*KbLastUpdate).

    Conceitos distintos (-ModifiedObjectNames/-ModifiedObjectGuids = handoff,
    -ExpectedItems = assercao, -IncludeItems/-ExcludeItems = contrato da task
    MSBuild do GeneXus) são intencionalmente fora do escopo de selecao e NÃO são
    aliasados aqui.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot

function Get-ScriptParameter {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptFileName,
        [Parameter(Mandatory = $true)][string]$ParameterName
    )

    $scriptPath = Join-Path $scriptDir $ScriptFileName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Script nao encontrado: $scriptPath"
    }
    $cmd = Get-Command -Name $scriptPath
    if (-not $cmd.Parameters.ContainsKey($ParameterName)) {
        throw "$ScriptFileName nao expoe o parametro -$ParameterName."
    }
    return $cmd.Parameters[$ParameterName]
}

function Assert-CanonicalParameter {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptFileName,
        [Parameter(Mandatory = $true)][string]$ParameterName,
        [string[]]$RequiredAliases = @(),
        [string]$ExpectedType,
        [string[]]$ForbiddenAliases = @()
    )

    $par = Get-ScriptParameter -ScriptFileName $ScriptFileName -ParameterName $ParameterName
    $aliases = @($par.Aliases)

    foreach ($alias in $RequiredAliases) {
        if ($aliases -notcontains $alias) {
            throw "$ScriptFileName :: -$ParameterName deveria ter alias '$alias'; aliases atuais=[$($aliases -join ',')]."
        }
    }
    foreach ($alias in $ForbiddenAliases) {
        if ($aliases -contains $alias) {
            throw "$ScriptFileName :: -$ParameterName NAO deveria ter alias '$alias' (regra de direcao); aliases atuais=[$($aliases -join ',')]."
        }
    }
    if (-not [string]::IsNullOrEmpty($ExpectedType)) {
        $typeName = $par.ParameterType.Name
        if ($typeName -ne $ExpectedType) {
            throw "$ScriptFileName :: -$ParameterName deveria ser do tipo [$ExpectedType]; obtido [$typeName]."
        }
    }
}

function Assert-ParameterAbsent {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptFileName,
        [Parameter(Mandatory = $true)][string]$ParameterName
    )

    $scriptPath = Join-Path $scriptDir $ScriptFileName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Script nao encontrado: $scriptPath"
    }
    $cmd = Get-Command -Name $scriptPath
    if ($cmd.Parameters.ContainsKey($ParameterName)) {
        throw "$ScriptFileName NAO deveria expor o parametro -$ParameterName."
    }
}

# 1. Selecao de objeto: -ObjectList canonico, [string[]], alias ObjectNames no export.
Assert-CanonicalParameter -ScriptFileName 'Invoke-GeneXusXpzExport.ps1' `
    -ParameterName 'ObjectList' -ExpectedType 'String[]' -RequiredAliases @('ObjectNames')

# Copy aceita tanto -ObjectList (canonico, [string[]]) quanto -ObjectNames (param próprio).
Assert-CanonicalParameter -ScriptFileName 'Copy-GeneXusAcervoToFront.ps1' `
    -ParameterName 'ObjectList' -ExpectedType 'String[]'
$null = Get-ScriptParameter -ScriptFileName 'Copy-GeneXusAcervoToFront.ps1' -ParameterName 'ObjectNames'

# 2. Entrada primaria simples: -InputPath com alias -Path.
$inputPathWithPathAlias = @(
    'Sync-GeneXusXpzToXml.ps1',
    'Edit-GeneXusXmlSurgical.ps1',
    'Extract-XpzObject.ps1',
    'Get-GeneXusObjectSummary.ps1',
    'Get-GeneXusImportPackageObjectInventory.ps1',
    'Test-GeneXusSourceSanity.ps1',
    'Test-GeneXusImportFileEnvelope.ps1',
    'Test-GeneXusObjectVariableDelta.ps1',
    'Test-GeneXusTransactionCoherence.ps1',
    'New-GeneXusUnknownTypeMaintainerPrompt.ps1',
    'Set-GeneXusXmlLastUpdate.ps1',
    # Ressalva semantica registrada: aqui a entrada primaria e um manifesto
    # JSON, nao um XML. -Path entra por consistencia de familia (os dois irmaos
    # mais proximos deste motor ja o expoem), nao por ser descritivo.
    'Edit-GeneXusXmlBatchMetadata.ps1'
)
foreach ($scriptFile in $inputPathWithPathAlias) {
    Assert-CanonicalParameter -ScriptFileName $scriptFile -ParameterName 'InputPath' -RequiredAliases @('Path')
}

# 3. Familia de import (entrada .xpz): -InputPath com aliases -XpzPath e -Path.
$importFamily = @(
    'Invoke-GeneXusXpzImport.ps1',
    'Invoke-GeneXusXpzImportThenBuild.ps1',
    'Test-GeneXusXpzImportPreview.ps1'
)
foreach ($scriptFile in $importFamily) {
    Assert-CanonicalParameter -ScriptFileName $scriptFile -ParameterName 'InputPath' -RequiredAliases @('XpzPath', 'Path')
    Assert-ParameterAbsent -ScriptFileName $scriptFile -ParameterName 'XpzPath'
}

# 4. Regra de direcao: no export o .xpz e SAIDA; mantem -XpzPath e NÃO ganha alias -InputPath.
Assert-CanonicalParameter -ScriptFileName 'Invoke-GeneXusXpzExport.ps1' `
    -ParameterName 'XpzPath' -ForbiddenAliases @('InputPath')
Assert-ParameterAbsent -ScriptFileName 'Invoke-GeneXusXpzExport.ps1' -ParameterName 'InputPath'

# 5. Contrato de saida do motor de sanidade: emite JSON por padrão e NÃO expoe -AsJson.
#    Trava negativa contra wrappers locais que carreguem essa flag de outro motor;
#    o erro de binding só apareceria em runtime, invisivel ao parse.
Assert-ParameterAbsent -ScriptFileName 'Test-GeneXusSourceSanity.ps1' -ParameterName 'AsJson'

Write-Output 'XPZ_PARAMETER_NAMING_CONTRACT_OK'
