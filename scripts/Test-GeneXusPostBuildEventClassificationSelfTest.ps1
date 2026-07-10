#requires -Version 7.4
<#
.SYNOPSIS
    Regressao da classificação de eventos pos-build (Get-GeneXusPostBuildEventClassification).

.DESCRIPTION
    Usa os dois eventos reais de um environment FrigoByte (sino + deploy .Bat) como fixture.
    Cobre: sem registro (sino benigno por som, deploy desconhecido rebaixa), com registro
    completo (não rebaixa), registro parcial (deploy não registrado rebaixa) e linha inerte.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusMsBuildPostBuildEventsSupport.ps1')

$sino   = 'start "" powershell -NoProfile -WindowStyle Hidden -Command "(New-Object System.Media.SoundPlayer ''c:\temp\sino.wav'').PlaySync()"'
$deploy = 'start "" /D "c:\Dropbox\AplicativosFrigobyte\AtualizacaoDoDeploy" "AtualizaDeployFB18PgNetCore.Bat"'
$inert  = '(commented) REM start c:\temp\antigo.bat'

$sinoHash   = Get-GeneXusPostBuildEventNormalizedHash -Line $sino
$deployHash = Get-GeneXusPostBuildEventNormalizedHash -Line $deploy

# Caso A: sem registro. Sino reconhecido por som (benigno); deploy desconhecido -> rebaixa.
$a = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino, $deploy) -RegisteredHashes @()
if (-not $a.shouldDowngrade) { throw 'ASSERT_FAILED: caso A deveria rebaixar (deploy desconhecido sem registro)' }
if ($a.benignFallback.Count -ne 1 -or $a.benignFallback[0] -ne $sino) { throw 'ASSERT_FAILED: caso A sino deveria ser benignFallback' }
if ($a.unknownFallback.Count -ne 1 -or $a.unknownFallback[0] -ne $deploy) { throw 'ASSERT_FAILED: caso A deploy deveria ser unknownFallback' }
if ($a.registryAvailable) { throw 'ASSERT_FAILED: caso A nao deveria ter registro' }

# Caso B: ambos registrados -> esperados, não rebaixa.
$b = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino, $deploy) -RegisteredHashes @($sinoHash, $deployHash)
if ($b.shouldDowngrade) { throw 'ASSERT_FAILED: caso B nao deveria rebaixar (ambos registrados)' }
if ($b.expected.Count -ne 2) { throw "ASSERT_FAILED: caso B deveria ter 2 esperados, atual=$($b.expected.Count)" }
if (-not $b.registryAvailable) { throw 'ASSERT_FAILED: caso B deveria ter registro' }

# Caso C: só o sino registrado -> deploy inesperado rebaixa.
$c = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino, $deploy) -RegisteredHashes @($sinoHash)
if (-not $c.shouldDowngrade) { throw 'ASSERT_FAILED: caso C deveria rebaixar (deploy nao registrado)' }
if ($c.expected.Count -ne 1 -or $c.expected[0] -ne $sino) { throw 'ASSERT_FAILED: caso C sino deveria ser esperado' }
if ($c.unexpected.Count -ne 1 -or $c.unexpected[0] -ne $deploy) { throw 'ASSERT_FAILED: caso C deploy deveria ser inesperado' }

# Caso D: linha inerte (REM comentada) ignorada; sozinha não rebaixa.
$d = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($inert) -RegisteredHashes @()
if ($d.shouldDowngrade) { throw 'ASSERT_FAILED: caso D inerte nao deveria rebaixar' }
if ($d.inert.Count -ne 1) { throw "ASSERT_FAILED: caso D deveria ter 1 inerte, atual=$($d.inert.Count)" }

# Caso E: sem registro, só o sino -> alivio sem registro (não rebaixa).
$e = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino) -RegisteredHashes @()
if ($e.shouldDowngrade) { throw 'ASSERT_FAILED: caso E sino-only sem registro nao deveria rebaixar' }

# Caso F: cronometro/data/sucesso de pos-build -> diagnostico benigno sem registro.
$timer = @(
    'Powershell New-TimeSpan -Start (Get-Content Inicio.txt) -End (Get-Date)',
    'Days              : 0',
    'Hours             : 0',
    'Minutes           : 0',
    'Seconds           : 49',
    'Milliseconds      : 33',
    'Ticks             : 490339218',
    'TotalDays         : 0,000567522243055555',
    'TotalHours        : 0,0136205338333333',
    'TotalMinutes      : 0,81723203',
    'TotalSeconds      : 49,0339218',
    'TotalMilliseconds : 49033,9218',
    'Powershell (Get-Date).ToString()',
    '10/07/2026 16:35:06',
    '> Build All Task Sucesso'
)
$f = Get-GeneXusPostBuildEventClassification -PostBuildEventLines $timer -RegisteredHashes @()
if ($f.shouldDowngrade) { throw 'ASSERT_FAILED: caso F cronometro pos-build nao deveria rebaixar' }
if ($f.benignFallback.Count -ne $timer.Count) { throw "ASSERT_FAILED: caso F deveria ter todos em benignFallback, atual=$($f.benignFallback.Count)" }

# Hash estavel a variacao inocua de espacos/caixa.
$sinoSpaced = '  start ""   powershell -NoProfile -WindowStyle Hidden -Command "(New-Object System.Media.SoundPlayer ''C:\TEMP\SINO.WAV'').PlaySync()"  '
if ((Get-GeneXusPostBuildEventNormalizedHash -Line $sinoSpaced) -ne $sinoHash) {
    throw 'ASSERT_FAILED: hash deveria ser estavel a espacos/caixa (path Windows case-insensitive)'
}

'GENEXUS_POST_BUILD_EVENT_CLASSIFICATION_SELFTEST_OK'
