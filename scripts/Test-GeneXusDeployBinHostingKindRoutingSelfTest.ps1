#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de roteamento por hosting kind no gate de deploy-bin (Fase 2 da paridade Java/Tomcat).

.DESCRIPTION
    Trava a fiacao do registro (GeneXusKbHostingKindSupport.ps1) nos dois consumidores do Eixo A que
    a Fase 2 fia: Resolve-GeneXusKbDeployBinCheckPolicy (A2) e Invoke-GeneXusKbDeployBinPostBuildClassification (A3).
    Complementa o golden .NET (fachada) exercitando o PIPELINE policy+classificacao, que os 4 self-tests
    de deploy-bin existentes nao cobrem para os ramos Java/invalido.

    Casos:
      1. java-tomcat  -> reconhecido-sem-motor: shouldRun=false; a classificacao materializa o contrato
                         de skip DERIVANDO a string do registro (nunca redigitada aqui).
      2. foobar       -> presente-e-fora-do-registro: shouldRun=false, skipReason = mensagem canonica
                         (que ecoa o valor recebido).
      3. JAVA-TOMCAT  -> case-insensitive: mesmo record que 'java-tomcat' (lookup [ordered]@{}.Contains).
      4. SkipDeployBinCheck (skip NAO-Java) -> Invoke-...Classification le $policy.hostingSkipStatus no ramo
                         de skip SEM lancar sob StrictMode (prova o init $null na BASE do $policy — regressao
                         StrictMode que quebraria os skips nao-Java sem o init).

    FONTE-UNICA: o valor esperado do skip e DERIVADO de (Get-GeneXusKbHostingKindSupportRecord ...).freshnessSkipStatus.
    Este arquivo NAO redigita o literal do status de skip (fica fora da varredura §8 do drift self-test) e NAO
    referencia a hashtable interna do registro nem o campo de forma-alvo da Fase 3.

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

# Valor esperado do skip, DERIVADO do registro (nunca redigitado neste arquivo).
$javaRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat'
if ($null -eq $javaRec) {
    throw "ASSERT_FAILED: registro nao reconhece 'java-tomcat' (pre-condicao da Fase 1)."
}
$expectedSkipStatus = $javaRec.freshnessSkipStatus
if ([string]::IsNullOrWhiteSpace($expectedSkipStatus)) {
    throw "ASSERT_FAILED: freshnessSkipStatus de 'java-tomcat' vazio; registro incoerente."
}
if ($javaRec.runsFreshnessEngine) {
    throw "ASSERT_FAILED: 'java-tomcat' nao deveria rodar o motor (runsFreshnessEngine=true)."
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

    # ── Caso 1: java-tomcat → policy skip + classificacao materializa o skip derivado ────────────────
    $policyJava = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'java-tomcat' `
        -ValidationEnvironmentName $envName `
        -BuildOperationallySucceeded $true
    if ($policyJava.shouldRun) {
        throw "ASSERT_FAILED: caso 1 (java-tomcat) nao deveria rodar o motor (shouldRun=$($policyJava.shouldRun))."
    }
    if ($policyJava.hostingSkipStatus -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: caso 1 policy.hostingSkipStatus esperado=[$expectedSkipStatus] atual=[$($policyJava.hostingSkipStatus)]."
    }
    if ([string]::IsNullOrWhiteSpace($policyJava.unsupportedReason)) {
        throw "ASSERT_FAILED: caso 1 policy.unsupportedReason deveria ser nao-vazio."
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
    if ($classJava.deployBinFreshness -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: caso 1 classificacao.deployBinFreshness esperado=[$expectedSkipStatus] atual=[$($classJava.deployBinFreshness)]."
    }
    if ($classJava.statusReclassified) {
        throw "ASSERT_FAILED: caso 1 skip Java nao deveria reclassificar status (statusReclassified=$($classJava.statusReclassified))."
    }
    if ($null -ne $classJava.newExitCode) {
        throw "ASSERT_FAILED: caso 1 skip Java nao deveria setar newExitCode, atual=[$($classJava.newExitCode)]."
    }
    if (-not $classJava.deployBinCheck.Contains('hostingSkipStatus')) {
        throw "ASSERT_FAILED: caso 1 deployBinCheck deveria conter 'hostingSkipStatus'."
    }
    if ($classJava.deployBinCheck['hostingSkipStatus'] -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: caso 1 deployBinCheck.hostingSkipStatus esperado=[$expectedSkipStatus] atual=[$($classJava.deployBinCheck['hostingSkipStatus'])]."
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

    # ── Caso 3: JAVA-TOMCAT (case-insensitive) → mesmo skip do caso 1 ─────────────────────────────────
    $policyUpper = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind 'JAVA-TOMCAT' `
        -ValidationEnvironmentName $envName `
        -BuildOperationallySucceeded $true
    if ($policyUpper.shouldRun) {
        throw "ASSERT_FAILED: caso 3 (JAVA-TOMCAT) deveria ser reconhecido case-insensitive e nao rodar o motor."
    }
    if ($policyUpper.hostingSkipStatus -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: caso 3 (JAVA-TOMCAT) lookup case-insensitive falhou. esperado hostingSkipStatus=[$expectedSkipStatus] atual=[$($policyUpper.hostingSkipStatus)]."
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
