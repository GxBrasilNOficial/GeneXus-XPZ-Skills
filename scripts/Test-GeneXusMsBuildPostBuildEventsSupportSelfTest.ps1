#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildPostBuildEventsSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildPostBuildEventsSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

$windowLines = @(
    '========== Build iniciado =========='
    'Executando eventos pós-construção ...'
    'start c:\temp\sino.mp3'
    'call c:\scripts\deploy.bat'
    'cmd /k c:\scripts\debug.bat'
    'powershell -File c:\scripts\deploy.ps1'
    'REM c:\scripts\faltante.bat'
    'C:\temp\buildall.msbuild(34,5): warning : spc0001: diagnostico'
    '========== Build finalizado =========='
    'call c:\scripts\fora-da-janela.bat'
)

$windowEvents = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines $windowLines)
if ($windowEvents.Count -ne 5) {
    throw "Esperava 5 eventos por janela; obtido: $($windowEvents.Count)"
}
if ($windowEvents[0] -ne 'start c:\temp\sino.mp3') {
    throw "Primeiro evento inesperado: $($windowEvents[0])"
}
if ($windowEvents[1] -ne 'call c:\scripts\deploy.bat') {
    throw "Evento call nao foi preservado: $($windowEvents[1])"
}
if ($windowEvents[3] -ne 'powershell -File c:\scripts\deploy.ps1') {
    throw "Evento powershell nao foi preservado: $($windowEvents[3])"
}
if ($windowEvents[4] -ne '(commented) REM c:\scripts\faltante.bat') {
    throw "Linha REM nao recebeu prefixo de compatibilidade: $($windowEvents[4])"
}

$fallbackLines = @(
    'alguma linha'
    'start cmd /c c:\scripts\deploy.bat'
    'REM start c:\temp\sino.mp3'
)
$fallbackEvents = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines $fallbackLines)
if ($fallbackEvents.Count -ne 2) {
    throw "Esperava 2 eventos por fallback; obtido: $($fallbackEvents.Count)"
}
if ($fallbackEvents[1] -ne '(commented) REM start c:\temp\sino.mp3') {
    throw "Fallback REM inesperado: $($fallbackEvents[1])"
}

$emptyEvents = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines @('Executando eventos pos-construcao ...', '========== fim =========='))
if ($emptyEvents.Count -ne 0) {
    throw "Janela vazia nao deveria produzir eventos; obtido: $($emptyEvents.Count)"
}

$timingWindowLines = @(
    'Executando eventos pos-construcao ...'
    'Powershell New-TimeSpan -Start (Get-Content Inicio.txt) -End (Get-Date)'
    'Days              : 0'
    'TotalSeconds      : 49,0339218'
    'Powershell (Get-Date).ToString()'
    '10/07/2026 16:35:06'
    '> Build All Task Sucesso'
    '========== fim =========='
)
$timingWindowEvents = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines $timingWindowLines)
if ($timingWindowEvents.Count -ne 3) {
    throw "Esperava somente 3 comandos/marcadores, sem as 3 linhas de output inerte; obtido: $($timingWindowEvents.Count)"
}
if ($timingWindowEvents[0] -notmatch '^Powershell New-TimeSpan' -or
    $timingWindowEvents[1] -notmatch '^Powershell \(Get-Date\)' -or
    $timingWindowEvents[2] -ne '> Build All Task Sucesso') {
    throw "Separacao comando/output de timing inesperada: $($timingWindowEvents -join ' | ')"
}

Write-Output 'GENEXUS_MSBUILD_POST_BUILD_EVENTS_SUPPORT_SELFTEST_OK'
