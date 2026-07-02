#requires -Version 7.4
<#
.SYNOPSIS
    Regressao mínima do resolvedor de .cs gerado via kb-source-metadata.md.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$setMetadataScript = Join-Path $scriptDir 'Set-XpzKbSourceMetadataDeployment.ps1'
$resolveScript = Join-Path $scriptDir 'Resolve-GeneXusGeneratedCsPath.ps1'

if (-not (Test-Path -LiteralPath $setMetadataScript -PathType Leaf)) {
    throw "Set-XpzKbSourceMetadataDeployment.ps1 nao encontrado: $setMetadataScript"
}

if (-not (Test-Path -LiteralPath $resolveScript -PathType Leaf)) {
    throw "Resolve-GeneXusGeneratedCsPath.ps1 nao encontrado: $resolveScript"
}

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-resolve-cs-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETPostgreSQL') 'web'
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $webDir -Force | Out-Null

    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'last_xpz_materialization_run_at: 2026-06-04T10:00:00.0000000+00:00'
        '---'
        ''
        '## Source'
        ''
        '| field | value |'
        '| --- | --- |'
        '| kb (GUID) | 11111111-1111-1111-1111-111111111111 |'
        ''
        '## Source/Version'
        ''
        '| field | value |'
        '| --- | --- |'
        '| name | MinhaKb |'
        '| guid | 22222222-2222-2222-2222-222222222222 |'
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    & $setMetadataScript `
        -KbParallelRoot $parallelRoot `
        -DeploymentEnvironmentName 'NETPostgreSQL' `
        -DeploymentHostingKind 'dotnet-core-self-host' `
        -KbEnvironmentNames 'NETPostgreSQL' `
        -KbEnvironmentOutputDirs 'NETPostgreSQL=NETPostgreSQL' `
        -KbNativePath $kbNativePath `
        -SkipEnvironmentNamesMsBuildValidation `
        -AsJson | Out-Null

    $csPath = Join-Path $webDir 'wpprocessaarquivo.cs'
    [System.IO.File]::WriteAllText($csPath, 'public class wpprocessaarquivo {}', (Get-Utf8NoBomEncoding))

    $json = & $resolveScript `
        -KbPath $kbNativePath `
        -ParallelKbRoot $parallelRoot `
        -ObjectName 'WpProcessaArquivo' `
        -ObjectType 'WebPanel' `
        -AsJson

    $result = $json | ConvertFrom-Json
    if ($result.status -ne 'CS_PATH_RESOLVED') {
        throw "ASSERT_FAILED: status inesperado: $($result.status)"
    }
    if (-not $result.exists) {
        throw 'ASSERT_FAILED: resolvedor deveria encontrar o .cs criado.'
    }
    if ($result.csPath -ne $csPath) {
        throw "ASSERT_FAILED: csPath divergente. esperado=$csPath atual=$($result.csPath)"
    }
    if ($result.resolutionSource -ne 'kb-source-metadata.kb_environment_web_dirs') {
        throw "ASSERT_FAILED: resolutionSource divergente: $($result.resolutionSource)"
    }

    # ── Fase 2 — guarda de familia (Eixo B) ─────────────────────────────────────────
    # Caso B2-skip: java-tomcat SEM kb_environment_web_dirs -> skip exit 0 (prova que o skip NAO depende
    # de web_dirs; sem a guarda, cairia em BLOCK no bloco de web_dirs — a regressao que a Fase 2 evita).
    # Metadata escrito direto (nao via Set-Xpz, que derivaria web_dirs); frontmatter-only.
    $javaParallel = Join-Path $tempRoot 'parallel-java'
    New-Item -ItemType Directory -Path $javaParallel -Force | Out-Null
    $javaMeta = @(
        '---'
        'deployment_environment_name: JavaEnv'
        'deployment_hosting_kind: java-tomcat'
        'kb_environment_count: 1'
        'kb_environment_names: JavaEnv'
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $javaParallel 'kb-source-metadata.md'), $javaMeta + "`n", (Get-Utf8NoBomEncoding))

    $javaJson = & $resolveScript `
        -KbPath $kbNativePath `
        -ParallelKbRoot $javaParallel `
        -ObjectName 'WpProcessaArquivo' `
        -ObjectType 'WebPanel' `
        -AsJson
    $javaExit = $LASTEXITCODE
    if ($javaExit -ne 0) {
        throw "ASSERT_FAILED: skip Java (sem web_dirs) deveria sair exit 0, atual=$javaExit"
    }
    $javaResult = $javaJson | ConvertFrom-Json
    if ($javaResult.status -ne 'CS_PATH_SKIPPED_HOSTING_UNSUPPORTED') {
        throw "ASSERT_FAILED: skip Java status esperado CS_PATH_SKIPPED_HOSTING_UNSUPPORTED, atual=$($javaResult.status)"
    }
    if ($javaResult.PSObject.Properties['csPath']) {
        throw "ASSERT_FAILED: skip Java nao deveria carregar csPath, atual=$($javaResult.csPath)"
    }
    if ($javaResult.environmentName -ne 'JavaEnv') {
        throw "ASSERT_FAILED: skip Java deveria reportar o environment resolvido 'JavaEnv', atual=$($javaResult.environmentName)"
    }
    if ($javaResult.family -ne 'java') {
        throw "ASSERT_FAILED: skip Java deveria reportar family='java', atual=$($javaResult.family)"
    }

    # Caso B2-invalido: deployment_hosting_kind fora do registro -> BLOCK exit 1, com nextStep PROPRIO de
    # hosting_kind (nao o texto de reconciliar web_dirs do BLOCK generico).
    $bogusParallel = Join-Path $tempRoot 'parallel-bogus'
    New-Item -ItemType Directory -Path $bogusParallel -Force | Out-Null
    $bogusMeta = @(
        '---'
        'deployment_environment_name: BogusEnv'
        'deployment_hosting_kind: foobar'
        'kb_environment_count: 1'
        'kb_environment_names: BogusEnv'
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $bogusParallel 'kb-source-metadata.md'), $bogusMeta + "`n", (Get-Utf8NoBomEncoding))

    $bogusJson = & $resolveScript `
        -KbPath $kbNativePath `
        -ParallelKbRoot $bogusParallel `
        -ObjectName 'WpProcessaArquivo' `
        -ObjectType 'WebPanel' `
        -AsJson
    $bogusExit = $LASTEXITCODE
    if ($bogusExit -ne 1) {
        throw "ASSERT_FAILED: hosting_kind invalido deveria sair exit 1, atual=$bogusExit"
    }
    $bogusResult = $bogusJson | ConvertFrom-Json
    if ($bogusResult.status -ne 'BLOCK') {
        throw "ASSERT_FAILED: hosting_kind invalido status esperado BLOCK, atual=$($bogusResult.status)"
    }
    if ($bogusResult.reason -notmatch [regex]::Escape('foobar')) {
        throw "ASSERT_FAILED: reason deveria ecoar o valor invalido 'foobar', atual=$($bogusResult.reason)"
    }
    if ($bogusResult.nextStep -notmatch [regex]::Escape('deployment_hosting_kind')) {
        throw "ASSERT_FAILED: nextStep do invalido deveria falar de deployment_hosting_kind (nao de web_dirs), atual=$($bogusResult.nextStep)"
    }
    if ($bogusResult.nextStep -match [regex]::Escape('kb_environment_web_dirs')) {
        throw "ASSERT_FAILED: nextStep do invalido NAO deveria falar de kb_environment_web_dirs, atual=$($bogusResult.nextStep)"
    }
    if ($bogusResult.environmentName -ne 'BogusEnv') {
        throw "ASSERT_FAILED: invalido deveria reportar o environment resolvido 'BogusEnv', atual=$($bogusResult.environmentName)"
    }

    'RESOLVE_GENEXUS_GENERATED_CS_PATH_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
