#requires -Version 7.4

<#
.SYNOPSIS
    Regressao da politica de execução do gate de deploy bin (Resolve-GeneXusKbDeployBinCheckPolicy).

.DESCRIPTION
    Cobre a decisão "rodar o gate?" após a Frente 1: ela depende do sucesso operacional
    factual (-BuildOperationallySucceeded), não da string de status. Garante que um build
    rebaixado por evento pos-build benigno (sino) mas factualmente OK ainda roda o gate.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusKbDeployBinSupport.ps1')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-policy-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $parallelRoot = Join-Path $tempRoot 'parallel'
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: .Net Environment'
        'deployment_hosting_kind: dotnet-framework-iis'
        'kb_environment_count: 1'
        'kb_environment_names: .Net Environment'
        'kb_environment_output_dirs: .Net Environment=NETFrameworkPostgreSQL'
        'kb_environment_web_dirs: .Net Environment=C:\dummy\web'
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    # Caso A (regressao central): sucesso operacional + gate pedido + metadata valido => roda o gate,
    # mesmo sem nenhuma string "compilou limpo" envolvida (simula build rebaixado por sino pos-build).
    $policyA = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -ValidationEnvironmentName '.Net Environment' `
        -BuildOperationallySucceeded $true
    if (-not $policyA.shouldRun) {
        throw "ASSERT_FAILED: caso A deveria rodar o gate (shouldRun=true), atual shouldRun=$($policyA.shouldRun) skipReason=$($policyA.skipReason)"
    }
    if ($policyA.mode -ne 'gate') {
        throw "ASSERT_FAILED: caso A deveria ter mode=gate, atual=$($policyA.mode)"
    }
    if (-not $policyA.gateEnabled) {
        throw "ASSERT_FAILED: caso A deveria ter gateEnabled=true, atual=$($policyA.gateEnabled)"
    }

    # Caso B: build não concluiu com sucesso operacional => pula com a nova razão.
    $policyB = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -ValidationEnvironmentName '.Net Environment' `
        -BuildOperationallySucceeded $false
    if ($policyB.shouldRun) {
        throw "ASSERT_FAILED: caso B nao deveria rodar o gate, atual shouldRun=$($policyB.shouldRun)"
    }
    if ($policyB.skipReason -notmatch 'sucesso operacional') {
        throw "ASSERT_FAILED: caso B deveria pular por falta de sucesso operacional, atual skipReason=$($policyB.skipReason)"
    }

    # Caso C: SkipDeployBinCheck precede tudo, mesmo com sucesso operacional.
    $policyC = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -SkipDeployBinCheck `
        -MetadataPath $metadataPath `
        -ValidationEnvironmentName '.Net Environment' `
        -BuildOperationallySucceeded $true
    if ($policyC.shouldRun) {
        throw "ASSERT_FAILED: caso C deveria pular por SkipDeployBinCheck, atual shouldRun=$($policyC.shouldRun)"
    }
    if ($policyC.skipReason -notmatch 'SkipDeployBinCheck') {
        throw "ASSERT_FAILED: caso C deveria citar SkipDeployBinCheck, atual skipReason=$($policyC.skipReason)"
    }

    # Caso D: sem gate explicito mas com sucesso operacional => roda em modo diagnostico.
    $policyD = Resolve-GeneXusKbDeployBinCheckPolicy `
        -MetadataPath $metadataPath `
        -ValidationEnvironmentName '.Net Environment' `
        -BuildOperationallySucceeded $true
    if (-not $policyD.shouldRun) {
        throw "ASSERT_FAILED: caso D deveria rodar (diagnostico), atual shouldRun=$($policyD.shouldRun) skipReason=$($policyD.skipReason)"
    }
    if ($policyD.mode -ne 'diagnostic') {
        throw "ASSERT_FAILED: caso D deveria ter mode=diagnostic, atual=$($policyD.mode)"
    }

    'GENEXUS_DEPLOY_BIN_POLICY_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
