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

# Caso F: outputs numericos/data validos sao inertes, mas comandos e marcador exigem registro.
$timerCommands = @(
    'Powershell New-TimeSpan -Start (Get-Content Inicio.txt) -End (Get-Date)',
    'Powershell (Get-Date).ToString()',
    '> Build All Task Sucesso'
)
$timerOutput = @(
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
    '10/07/2026 16:35:06'
)
$f = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($timerCommands + $timerOutput) -RegisteredHashes @()
if (-not $f.shouldDowngrade) { throw 'ASSERT_FAILED: caso F comandos de timing sem registro deveriam rebaixar' }
if ($f.inert.Count -ne $timerOutput.Count) { throw "ASSERT_FAILED: caso F deveria ter outputs inertes=$($timerOutput.Count), atual=$($f.inert.Count)" }
if ($f.unknownFallback.Count -ne $timerCommands.Count) { throw "ASSERT_FAILED: caso F deveria ter comandos desconhecidos=$($timerCommands.Count), atual=$($f.unknownFallback.Count)" }

# Caso G: comandos/marcador registrados + outputs inertes -> fluxo limpo.
$timerCommandHashes = @($timerCommands | ForEach-Object { Get-GeneXusPostBuildEventNormalizedHash -Line $_ })
$g = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($timerCommands + $timerOutput) -RegisteredHashes $timerCommandHashes
if ($g.shouldDowngrade) { throw 'ASSERT_FAILED: caso G comandos registrados e outputs inertes nao deveriam rebaixar' }
if ($g.expected.Count -ne $timerCommands.Count -or $g.inert.Count -ne $timerOutput.Count) {
    throw 'ASSERT_FAILED: caso G separacao entre comandos esperados e outputs inertes falhou'
}

# Caso H: registro parcial continua cauteloso.
$h = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($timerCommands + $timerOutput) -RegisteredHashes @($timerCommandHashes[0])
if (-not $h.shouldDowngrade -or $h.unexpected.Count -ne 2) {
    throw 'ASSERT_FAILED: caso H registro parcial deveria rebaixar pelos dois eventos restantes'
}

# Caso I: output inerte junto de evento real desconhecido nao mascara o evento.
$i = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @('Seconds : 49', 'call c:\scripts\desconhecido.bat') -RegisteredHashes @()
if (-not $i.shouldDowngrade -or $i.inert.Count -ne 1 -or $i.unknownFallback.Count -ne 1) {
    throw 'ASSERT_FAILED: caso I output inerte nao deveria mascarar evento desconhecido'
}

# Caso J: controles negativos nao podem ser classificados como output inerte.
$invalidTimingOutput = @('Days: not-a-number', 'TotalSeconds: ERROR', '99/99/9999 99:99:99')
$j = Get-GeneXusPostBuildEventClassification -PostBuildEventLines $invalidTimingOutput -RegisteredHashes @()
if (-not $j.shouldDowngrade -or $j.unknownFallback.Count -ne $invalidTimingOutput.Count -or $j.inert.Count -ne 0) {
    throw 'ASSERT_FAILED: caso J valores/data invalidos deveriam permanecer desconhecidos'
}

# Hash estavel a variacao inocua de espacos/caixa.
$sinoSpaced = '  start ""   powershell -NoProfile -WindowStyle Hidden -Command "(New-Object System.Media.SoundPlayer ''C:\TEMP\SINO.WAV'').PlaySync()"  '
if ((Get-GeneXusPostBuildEventNormalizedHash -Line $sinoSpaced) -ne $sinoHash) {
    throw 'ASSERT_FAILED: hash deveria ser estavel a espacos/caixa (path Windows case-insensitive)'
}

# Hash estavel para a saida prevista do contorno Verify-GxJs quando a unica variacao e o tempo.
$verifyOk1 = 'Verify-GxJs: verificados 2161 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2388 ms'
$verifyOk2 = 'Verify-GxJs: verificados 2161 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2289 ms'
$verifyHash = Get-GeneXusPostBuildEventNormalizedHash -Line $verifyOk1
if ((Get-GeneXusPostBuildEventNormalizedHash -Line $verifyOk2) -ne $verifyHash) {
    throw 'ASSERT_FAILED: hash do Verify-GxJs deveria ignorar variacao de tempo quando invalidos=0'
}
$k = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($verifyOk2) -RegisteredHashes @($verifyHash)
if ($k.shouldDowngrade -or $k.expected.Count -ne 1) {
    throw 'ASSERT_FAILED: Verify-GxJs com tempo diferente deveria ser esperado apos registro'
}

'GENEXUS_POST_BUILD_EVENT_CLASSIFICATION_SELFTEST_OK'
