#requires -Version 7.4

<#
.SYNOPSIS
    Regressao mínima da resolucao de web\bin via kb_environment_web_dirs.
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETFrameworkPostgreSQL') 'web'
    $binDir = Join-Path $webDir 'bin'
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: .Net Environment'
        'deployment_hosting_kind: dotnet-framework-iis'
        'kb_environment_count: 1'
        'kb_environment_names: .Net Environment'
        'kb_environment_output_dirs: .Net Environment=NETFrameworkPostgreSQL'
        ('kb_environment_web_dirs: .Net Environment={0}' -f $webDir)
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    $buildStartedAt = [DateTimeOffset]::Now.AddMinutes(-2)
    [System.IO.File]::WriteAllText((Join-Path $binDir 'minhaapp.dll'), 'test', (Get-Utf8NoBomEncoding))

    $result = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $kbNativePath `
        -EnvironmentName '.Net Environment' `
        -DeploymentHostingKind 'dotnet-framework-iis' `
        -BuildStartedAt $buildStartedAt `
        -MetadataPath $metadataPath

    if ($result.paths.pathResolutionSource -ne 'kb-source-metadata.kb_environment_web_dirs') {
        throw "ASSERT_FAILED: pathResolutionSource divergente: $($result.paths.pathResolutionSource)"
    }
    if ($result.paths.environmentWebPath -ne $webDir) {
        throw "ASSERT_FAILED: environmentWebPath divergente. esperado=$webDir atual=$($result.paths.environmentWebPath)"
    }
    if ($result.paths.environmentBinPath -ne $binDir) {
        throw "ASSERT_FAILED: environmentBinPath divergente. esperado=$binDir atual=$($result.paths.environmentBinPath)"
    }
    if ($result.status -ne 'fresh') {
        throw "ASSERT_FAILED: status esperado fresh, atual=$($result.status)"
    }

    $blockedWithoutMetadata = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $kbNativePath `
        -EnvironmentName '.Net Environment' `
        -DeploymentHostingKind 'dotnet-framework-iis' `
        -BuildStartedAt $buildStartedAt

    if ($blockedWithoutMetadata.paths.pathResolutionStatus -ne 'blocked') {
        throw "ASSERT_FAILED: metadata ausente deveria bloquear resolucao, atual=$($blockedWithoutMetadata.paths.pathResolutionStatus)"
    }
    if ($blockedWithoutMetadata.paths.pathResolutionSource -ne 'kb-source-metadata.kb_environment_web_dirs') {
        throw "ASSERT_FAILED: metadata ausente nao deve usar fallback legado, atual=$($blockedWithoutMetadata.paths.pathResolutionSource)"
    }
    if ($blockedWithoutMetadata.paths.environmentWebPath) {
        throw "ASSERT_FAILED: metadata ausente nao deve inferir environmentWebPath, atual=$($blockedWithoutMetadata.paths.environmentWebPath)"
    }

    'GENEXUS_DEPLOY_BIN_FRESHNESS_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
