#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da guarda de familia (Eixo C) em Test-GeneXusRuntimeFreshness.ps1 (Fase 2 Java/Tomcat).

.DESCRIPTION
    Trava a guarda opt-in por -DeploymentHostingKind (decisao D3), invocando o script como processo-filho
    e conferindo status + exit code por ramo:

      ramo 0 (SEM -DeploymentHostingKind) -> comportamento IDENTICO ao de hoje: segue o diagnostico e sai
              com status 'runtime-*' (aqui 'runtime-unknown', pois a KB de fixture nao tem nav_objs/artefatos).
              Prova zero regressao quando o parametro e ausente.
      ramo 1 (-DeploymentHostingKind fora do registro) -> erro de parametro: exit 1, status
              'runtime-hosting-kind-invalido', reason ecoa o valor.
      ramo 2 (-DeploymentHostingKind java-tomcat) -> skip claro: exit 0, status = runtimeSkipStatus (Eixo C) do
              registro; NAO deriva CSharpModel\web (a KB de fixture nem tem esse diretorio).
      ramo 2 case-insensitive ('JAVA-TOMCAT') -> mesmo skip (lookup [ordered]@{}.Contains).

    FONTE-UNICA: o status de skip esperado e DERIVADO de (Get-...Record 'java-tomcat').runtimeSkipStatus (Eixo C);
    este arquivo nao redigita o literal (fica fora da §8 do drift) e nao referencia o campo de forma-alvo da Fase 3 (§9).

    Falha => 'ASSERT_FAILED: ...'; sucesso => 'GENEXUS_RUNTIME_FRESHNESS_HOSTING_GUARD_SELFTEST_OK'.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$freshnessScript = Join-Path $scriptDir 'Test-GeneXusRuntimeFreshness.ps1'
. (Join-Path $scriptDir 'GeneXusKbHostingKindSupport.ps1')

# Fase 3 (split per-eixo): esta e a guarda do Eixo C (runtime) — o status de skip esperado vem do campo
# DO SEU EIXO (runtimeSkipStatus), NAO do alias legado freshnessSkipStatus (que segue o Eixo A e, apos a
# Fase 3, e $null para Java porque o Eixo A passou a rodar o motor).
$expectedSkipStatus = (Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat').runtimeSkipStatus
if ([string]::IsNullOrWhiteSpace($expectedSkipStatus)) {
    throw "ASSERT_FAILED: runtimeSkipStatus de 'java-tomcat' vazio (Eixo C deveria seguir recognized-no-engine)."
}

$importedAt = '2026-06-01T00:00:00-03:00'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-runtime-guard-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $kbPath = Join-Path $tempRoot 'KbNative'
    New-Item -ItemType Directory -Path $kbPath -Force | Out-Null

    # ── ramo 0: sem -DeploymentHostingKind -> comportamento de hoje (runtime-*), exit 0 ──────────────
    $r0Json = & $freshnessScript -KbPath $kbPath -ObjectName 'MinhaProc' -ImportedAt $importedAt -AsJson
    $r0Exit = $LASTEXITCODE
    if ($r0Exit -ne 0) {
        throw "ASSERT_FAILED: ramo 0 (sem hosting kind) deveria sair exit 0, atual=$r0Exit"
    }
    $r0 = $r0Json | ConvertFrom-Json
    if ($r0.status -notlike 'runtime-*') {
        throw "ASSERT_FAILED: ramo 0 deveria manter status 'runtime-*' (comportamento de hoje), atual=$($r0.status)"
    }
    if ($r0.status -eq $expectedSkipStatus) {
        throw "ASSERT_FAILED: ramo 0 NAO deveria virar skip sem o parametro (zero regressao)."
    }

    # ── ramo 2: java-tomcat -> skip, exit 0, status = skip do registro ───────────────────────────────
    $r2Json = & $freshnessScript -KbPath $kbPath -ObjectName 'MinhaProc' -ImportedAt $importedAt -DeploymentHostingKind 'java-tomcat' -AsJson
    $r2Exit = $LASTEXITCODE
    if ($r2Exit -ne 0) {
        throw "ASSERT_FAILED: ramo 2 (java-tomcat) deveria sair exit 0, atual=$r2Exit"
    }
    $r2 = $r2Json | ConvertFrom-Json
    if ($r2.status -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: ramo 2 status esperado=[$expectedSkipStatus] atual=[$($r2.status)]"
    }
    if ([string]::IsNullOrWhiteSpace($r2.summary)) {
        throw "ASSERT_FAILED: ramo 2 deveria ter summary (unsupportedReason) nao-vazio."
    }

    # ── ramo 2 case-insensitive: JAVA-TOMCAT -> mesmo skip ───────────────────────────────────────────
    $r2uJson = & $freshnessScript -KbPath $kbPath -ObjectName 'MinhaProc' -ImportedAt $importedAt -DeploymentHostingKind 'JAVA-TOMCAT' -AsJson
    $r2uExit = $LASTEXITCODE
    if ($r2uExit -ne 0) {
        throw "ASSERT_FAILED: ramo 2 (JAVA-TOMCAT case-insensitive) deveria sair exit 0, atual=$r2uExit"
    }
    $r2u = $r2uJson | ConvertFrom-Json
    if ($r2u.status -ne $expectedSkipStatus) {
        throw "ASSERT_FAILED: ramo 2 case-insensitive status esperado=[$expectedSkipStatus] atual=[$($r2u.status)]"
    }

    # ── ramo 1: foobar (fora do registro) -> exit 1, status runtime-hosting-kind-invalido ────────────
    $r1Json = & $freshnessScript -KbPath $kbPath -ObjectName 'MinhaProc' -ImportedAt $importedAt -DeploymentHostingKind 'foobar' -AsJson
    $r1Exit = $LASTEXITCODE
    if ($r1Exit -ne 1) {
        throw "ASSERT_FAILED: ramo 1 (foobar invalido) deveria sair exit 1, atual=$r1Exit"
    }
    $r1 = $r1Json | ConvertFrom-Json
    if ($r1.status -ne 'runtime-hosting-kind-invalido') {
        throw "ASSERT_FAILED: ramo 1 status esperado 'runtime-hosting-kind-invalido', atual=$($r1.status)"
    }
    if ($r1.reason -notmatch [regex]::Escape('foobar')) {
        throw "ASSERT_FAILED: ramo 1 reason deveria ecoar o valor invalido 'foobar', atual=$($r1.reason)"
    }

    'GENEXUS_RUNTIME_FRESHNESS_HOSTING_GUARD_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
