#requires -Version 7.4
<#
.SYNOPSIS
    Golden de regressao .NET + skip por familia do diagnostico de deploy-bin (fachada Test-GeneXusDeployBinFreshness.ps1).

.DESCRIPTION
    Congela, com timestamps e paths normalizados (<TS>/<ROOT>), a saida JSON canonica da fachada em
    TRES casos, apos a Fase 2 da paridade Java/Tomcat fiar o registro na fachada:

      - ACEITO    : dotnet-framework-iis com DLL de objeto fresca em web\bin -> status 'fresh'.
      - SKIP      : java-tomcat -> reconhecido pelo registro como recognized-no-engine; a fachada
                    ROTEIA para o skip via registro -> status 'skipped-hosting-unsupported' + summary
                    derivado de unsupportedReason. (Na Fase 1 este caso era rejeitado como 'invalido';
                    a Fase 2 mudou-o DELIBERADAMENTE para skip — ver java-tomcat-paridade-gerador-design.md.)
      - REJEITADO : 'foobar' — hosting kind GENUINAMENTE invalido (fora do registro) -> a fachada rejeita
                    com a mensagem canonica (status 'skipped', deployBinCheck null). Preserva a cobertura
                    de rejeicao de valor invalido que a decisao (a') exige — cobertura que o caso java-tomcat
                    deixou de exercer ao virar skip.

    O motor de deploy-bin (Get-GeneXusKbDeployBinPaths / Test-GeneXusKbDeployBinFreshnessCore) permanece
    ESCALAR (a mudanca de aridade e da Fase 3); a Fase 2 so fia o registro na fachada/policy.

    Rode com -UpdateBaseline para reimprimir os baselines normalizados (ao evoluir a fachada na Fase 3,
    revalidar a mudanca e recapturar conscientemente).

    Falha => 'ASSERT_FAILED: ...'; sucesso => 'GENEXUS_DEPLOY_BIN_DOTNET_GOLDEN_SELFTEST_OK'.
#>

[CmdletBinding()]
param(
    [switch]$UpdateBaseline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $PSCommandPath
$facade     = Join-Path $scriptDir 'Test-GeneXusDeployBinFreshness.ps1'

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function ConvertTo-GoldenNormalizedText {
    param(
        [string]$Text,
        [string]$Root
    )
    $t = $Text
    # Normaliza o root temporario nas duas formas em que aparece no JSON (barra dupla escapada e crua).
    $t = $t.Replace($Root.Replace('\', '\\'), '<ROOT>')
    $t = $t.Replace($Root, '<ROOT>')
    # Normaliza timestamps ISO 8601 (formato 'o' com fracao e offset/Z).
    $t = [regex]::Replace($t, '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)?', '<TS>')
    return $t
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-golden-" + [guid]::NewGuid().ToString('N'))
try {
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETFrameworkPostgreSQL') 'web'
    $binDir = Join-Path $webDir 'bin'
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $envName = '.Net Environment'
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

    # DLL de objeto fresca (timestamp fixado, nao confiado ao relogio de criacao).
    $objectDll = Join-Path $binDir 'minhaapp.dll'
    [System.IO.File]::WriteAllText($objectDll, 'objeto', (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $objectDll).LastWriteTime = $buildStartedAt.AddMinutes(1).LocalDateTime

    # ── Caso ACEITO ─────────────────────────────────────────────────────────────
    $acceptedRaw = & $facade `
        -KbPath $kbNativePath `
        -EnvironmentName $envName `
        -KbMetadataPath $metadataPath `
        -BuildStartedAt ($buildStartedAt.ToString('o')) `
        -AsJson
    $acceptedActual = ConvertTo-GoldenNormalizedText -Text (($acceptedRaw | Out-String).TrimEnd()) -Root $tempRoot

    # ── Caso SKIP (java-tomcat reconhecido-sem-motor -> skip via registro) ────────
    $skipRaw = & $facade `
        -KbPath $kbNativePath `
        -EnvironmentName $envName `
        -KbMetadataPath $metadataPath `
        -DeploymentHostingKind 'java-tomcat' `
        -BuildStartedAt ($buildStartedAt.ToString('o')) `
        -AsJson
    $skipActual = ConvertTo-GoldenNormalizedText -Text (($skipRaw | Out-String).TrimEnd()) -Root $tempRoot

    # ── Caso REJEITADO (hosting kind GENUINAMENTE invalido, fora do registro) ─────
    $rejectedRaw = & $facade `
        -KbPath $kbNativePath `
        -EnvironmentName $envName `
        -KbMetadataPath $metadataPath `
        -DeploymentHostingKind 'foobar' `
        -BuildStartedAt ($buildStartedAt.ToString('o')) `
        -AsJson
    $rejectedActual = ConvertTo-GoldenNormalizedText -Text (($rejectedRaw | Out-String).TrimEnd()) -Root $tempRoot

    if ($UpdateBaseline) {
        '===== ACCEPTED BASELINE ====='
        $acceptedActual
        '===== SKIP BASELINE ====='
        $skipActual
        '===== REJECTED BASELINE ====='
        $rejectedActual
        return
    }

    # ── Baselines congelados (normalizados) ──────────────────────────────────────
    $acceptedGolden = @'
{
  "status": "fresh",
  "validationEnvironmentName": ".Net Environment",
  "deploymentHostingKind": "dotnet-framework-iis",
  "metadataPath": "<ROOT>\\parallel\\kb-source-metadata.md",
  "buildStartedAt": "<TS>",
  "buildStartedAtSource": "parameter",
  "deployBinCheck": {
    "paths": {
      "environmentWebPath": "<ROOT>\\KbNative\\NETFrameworkPostgreSQL\\web",
      "environmentBinPath": "<ROOT>\\KbNative\\NETFrameworkPostgreSQL\\web\\bin",
      "pathResolutionStatus": "resolved",
      "pathResolutionSource": "kb-source-metadata.kb_environment_web_dirs",
      "pathResolutionReason": null
    },
    "binCheck": {
      "rule": "publication-object-dll-or-config",
      "binDirectoryFound": true,
      "objectDllCount": 1,
      "objectDllMaxWriteTime": "<TS>",
      "newestObjectDllName": "minhaapp.dll",
      "objectDllFreshSinceBuild": true,
      "configMaxWriteTime": null,
      "newestConfigName": null,
      "configFreshSinceBuild": false,
      "publicationFreshSinceBuild": true,
      "binFreshSinceBuild": true
    },
    "diagnosticLayer": {
      "environmentWebMaxWriteTime": null,
      "environmentWebFreshSinceBuild": false
    },
    "interpretation": "Publicacao em web\\bin confirmada (DLL de objeto ou config com timestamp >= inicio do build).",
    "thresholdAt": "<TS>"
  },
  "summary": "Publicacao em web\\bin confirmada (DLL de objeto ou config com timestamp >= inicio do build)."
}
'@ -replace "`r`n", "`n"

    $skipGolden = @'
{
  "status": "skipped-hosting-unsupported",
  "validationEnvironmentName": ".Net Environment",
  "deploymentHostingKind": "java-tomcat",
  "metadataPath": "<ROOT>\\parallel\\kb-source-metadata.md",
  "buildStartedAt": "<TS>",
  "buildStartedAtSource": "parameter",
  "deployBinCheck": null,
  "summary": "Gerador Java/Tomcat reconhecido, mas o motor de verificacao de deploy-bin ainda e .NET (Eixo A). Checagem pulada (skipped-hosting-unsupported) ate a Fase 3 dar motor por familia."
}
'@ -replace "`r`n", "`n"

    $rejectedGolden = @'
{
  "status": "skipped",
  "validationEnvironmentName": ".Net Environment",
  "deploymentHostingKind": "foobar",
  "metadataPath": "<ROOT>\\parallel\\kb-source-metadata.md",
  "buildStartedAt": "<TS>",
  "buildStartedAtSource": "parameter",
  "deployBinCheck": null,
  "summary": "deployment_hosting_kind invalido: 'foobar'. Valores reconhecidos: dotnet-core-self-host, dotnet-framework-iis, java-tomcat."
}
'@ -replace "`r`n", "`n"

    $acceptedActualN = $acceptedActual -replace "`r`n", "`n"
    $skipActualN     = $skipActual -replace "`r`n", "`n"
    $rejectedActualN = $rejectedActual -replace "`r`n", "`n"

    if ($acceptedActualN -ne $acceptedGolden) {
        Write-Host '----- ACEITO (atual normalizado) -----'
        Write-Host $acceptedActualN
        Write-Host '----- ACEITO (baseline) -----'
        Write-Host $acceptedGolden
        throw 'ASSERT_FAILED: caso ACEITO divergiu do golden .NET (regressao no motor/fachada de deploy-bin?).'
    }
    if ($skipActualN -ne $skipGolden) {
        Write-Host '----- SKIP (atual normalizado) -----'
        Write-Host $skipActualN
        Write-Host '----- SKIP (baseline) -----'
        Write-Host $skipGolden
        throw 'ASSERT_FAILED: caso SKIP (java-tomcat) divergiu do golden. Se a mudanca da fachada e DELIBERADA (registro/motor por familia), recapturar o baseline com -UpdateBaseline apos revalidar.'
    }
    if ($rejectedActualN -ne $rejectedGolden) {
        Write-Host '----- REJEITADO (atual normalizado) -----'
        Write-Host $rejectedActualN
        Write-Host '----- REJEITADO (baseline) -----'
        Write-Host $rejectedGolden
        throw 'ASSERT_FAILED: caso REJEITADO (foobar) divergiu do golden. Se a mensagem canonica de valor invalido mudou deliberadamente, recapturar o baseline com -UpdateBaseline apos revalidar.'
    }

    'GENEXUS_DEPLOY_BIN_DOTNET_GOLDEN_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
