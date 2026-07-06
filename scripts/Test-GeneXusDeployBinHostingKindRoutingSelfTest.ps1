#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de roteamento por hosting kind no gate de deploy-bin (Fase 3 da paridade Java/Tomcat).

.DESCRIPTION
    Trava a fiacao do registro (GeneXusKbHostingKindSupport.ps1) nos dois consumidores do Eixo A:
    Resolve-GeneXusKbDeployBinCheckPolicy (A2) e Invoke-GeneXusKbDeployBinPostBuildClassification (A3).
    A partir da Fase 3 (Commit 3) o java-tomcat tem Eixo A SUPPORTED (motor Java = co-gate): NAO pula
    mais; RODA o motor e, sem kb_environment_servlet_dirs no fixture, cai em config-error 'unknown'
    (fail-safe — nunca 'fresh'). Complementa o golden .NET exercitando o PIPELINE policy+classificacao.

    Casos:
      1. java-tomcat  -> Eixo A supported: shouldRun=TRUE; sem servlet_dirs -> freshness 'unknown'
                         (config-error); sob gate (PostImportDeployValidation) reclassifica + exit 49.
      2. foobar       -> presente-e-fora-do-registro: shouldRun=false, skipReason = mensagem canonica.
      3. JAVA-TOMCAT  -> case-insensitive: mesmo roteamento do caso 1 (shouldRun=TRUE).
      4. SkipDeployBinCheck (skip NAO-Java) -> Invoke-...Classification le $policy.hostingSkipStatus no ramo
                         de skip SEM lancar sob StrictMode (prova o init $null na BASE do $policy).

    FONTE-UNICA: nenhuma redigitacao do literal de skip (fica fora da varredura §8 do drift self-test).

    Falha => 'ASSERT_FAILED: ...'; sucesso => 'GENEXUS_DEPLOY_BIN_HOSTING_KIND_ROUTING_SELFTEST_OK'.
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

# Pre-condicao Fase 3: java-tomcat RODA o motor do Eixo A (deploy-bin), pelo campo do seu eixo.
$javaRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat'
if ($null -eq $javaRec) {
    throw "ASSERT_FAILED: registro nao reconhece 'java-tomcat' (pre-condicao)."
}
if (-not $javaRec.runsDeployBinEngine) {
    throw "ASSERT_FAILED: 'java-tomcat' deveria rodar o motor do Eixo A (runsDeployBinEngine=false) apos a Fase 3."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-routing-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $parallelRoot = Join-Path $tempRoot 'parallel'
    New-Item -ItemType Directory -Path $kbNativePath -Force | Out-Null
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $envName = 'Deploy Environment'
    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: Deploy Environment'
        'deployment_hosting_kind: java-tomcat'
        'kb_environment_count: 1'
        'kb_environment_names: Deploy Environment'
        'kb_environment_output_dirs: Deploy Environment=JavaTomcat'
        'kb_environment_web_dirs: Deploy Environment=C:\dummy\web'
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    $buildStartedAt = [DateTimeOffset]::Now.AddMinutes(-2)

    # ── Caso 1: java-tomcat → Eixo A supported: RODA o motor; sem servlet_dirs -> unknown (config-error) ──
    $policyJava = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'java-tomcat' `
        -ValidationEnvironmentName $envName `
        -BuildOperationallySucceeded $true
    if (-not $policyJava.shouldRun) {
        throw "ASSERT_FAILED: caso 1 (java-tomcat) deveria RODAR o motor do Eixo A (shouldRun=$($policyJava.shouldRun))."
    }
    if ($null -ne $policyJava.hostingSkipStatus) {
        throw "ASSERT_FAILED: caso 1 (java-tomcat supported) nao e skip; hostingSkipStatus deveria ser `$null, atual=[$($policyJava.hostingSkipStatus)]."
    }
    if (-not $policyJava.gateEnabled) {
        throw "ASSERT_FAILED: caso 1 com -PostImportDeployValidation deveria ter gateEnabled=true."
    }

    $classJava = Invoke-GeneXusKbDeployBinPostBuildClassification `
        -KbPath $kbNativePath `
        -ValidationEnvironmentName $envName `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'java-tomcat' `
        -BuildStartedAt $buildStartedAt `
        -BuildOperationallySucceeded $true `
        -PostImportDeployValidation `
        -OperationLabel 'SelfTest'
    if ($classJava.deployBinFreshness -ne 'unknown') {
        throw "ASSERT_FAILED: caso 1 sem servlet_dirs deveria dar freshness 'unknown' (config-error), atual=[$($classJava.deployBinFreshness)]."
    }
    if (-not $classJava.statusReclassified) {
        throw "ASSERT_FAILED: caso 1 'unknown' sob gate deveria reclassificar (statusReclassified=false)."
    }
    if ($classJava.newExitCode -ne 49) {
        throw "ASSERT_FAILED: caso 1 'unknown' sob gate deveria setar newExitCode=49, atual=[$($classJava.newExitCode)]."
    }

    # ── Caso 2: foobar → rejeicao canonica (presente-e-fora-do-registro) ─────────────────────────────
    $policyBogus = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'foobar' `
        -ValidationEnvironmentName $envName `
        -BuildOperationallySucceeded $true
    if ($policyBogus.shouldRun) {
        throw "ASSERT_FAILED: caso 2 (foobar) nao deveria rodar o motor."
    }
    if ($null -ne $policyBogus.hostingSkipStatus) {
        throw "ASSERT_FAILED: caso 2 (foobar invalido) nao e skip reconhecido; hostingSkipStatus deveria ser `$null, atual=[$($policyBogus.hostingSkipStatus)]."
    }
    if ($policyBogus.skipReason -notmatch [regex]::Escape('foobar')) {
        throw "ASSERT_FAILED: caso 2 skipReason deveria ecoar o valor invalido 'foobar', atual=[$($policyBogus.skipReason)]."
    }
    $expectedInvalidMsg = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind 'foobar'
    if ($policyBogus.skipReason -ne $expectedInvalidMsg) {
        throw "ASSERT_FAILED: caso 2 skipReason deveria ser a mensagem canonica do registro. esperado=[$expectedInvalidMsg] atual=[$($policyBogus.skipReason)]."
    }

    # ── Caso 3: JAVA-TOMCAT (case-insensitive) → mesmo roteamento do caso 1 (roda o motor) ────────────
    $policyUpper = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'JAVA-TOMCAT' `
        -ValidationEnvironmentName $envName `
        -BuildOperationallySucceeded $true
    if (-not $policyUpper.shouldRun) {
        throw "ASSERT_FAILED: caso 3 (JAVA-TOMCAT) deveria ser reconhecido case-insensitive e RODAR o motor (shouldRun=false)."
    }
    if ($null -ne $policyUpper.hostingSkipStatus) {
        throw "ASSERT_FAILED: caso 3 (JAVA-TOMCAT) nao e skip; hostingSkipStatus deveria ser `$null, atual=[$($policyUpper.hostingSkipStatus)]."
    }

    # ── Caso 4: SkipDeployBinCheck (skip NAO-Java) → classificacao sem lancar (regressao StrictMode) ─
    # O init $null de hostingSkipStatus na BASE do $policy garante que a leitura em A3 nao lance.
    $classSkip = Invoke-GeneXusKbDeployBinPostBuildClassification `
        -KbPath $kbNativePath `
        -ValidationEnvironmentName $envName `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'dotnet-framework-iis' `
        -BuildStartedAt $buildStartedAt `
        -BuildOperationallySucceeded $true `
        -SkipDeployBinCheck `
        -OperationLabel 'SelfTest'
    if ($classSkip.deployBinFreshness -ne 'skipped') {
        throw "ASSERT_FAILED: caso 4 (SkipDeployBinCheck) deveria manter deployBinFreshness='skipped', atual=[$($classSkip.deployBinFreshness)]."
    }
    if ($classSkip.statusReclassified) {
        throw "ASSERT_FAILED: caso 4 nao deveria reclassificar."
    }

    'GENEXUS_DEPLOY_BIN_HOSTING_KIND_ROUTING_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
