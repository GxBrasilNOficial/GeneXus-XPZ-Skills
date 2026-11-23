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

$isolatedWindowEvents = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines @(
    'start c:\temp\fora-da-janela.bat'
    'Executando eventos pos-construcao ...'
    'Days              : 0'
    '10/07/2026 16:35:06'
    '========== fim =========='
))
if ($isolatedWindowEvents.Count -ne 0) {
    throw "Fallback nao deveria capturar evento externo quando a janela foi detectada; obtido: $($isolatedWindowEvents -join ' | ')"
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

# Familias de linha conhecidas: contagens variaveis nao mudam o fingerprint da forma nova.
$aOne = '[APLICADO] .js varridos=2966 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=1'
$aTwo = '[APLICADO] .js varridos=2970 | arquivos com chave negativa em gx.domain=3 | chaves corrigidas=3'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $aOne) -ne (Get-GeneXusPostBuildEventFamilyHash -Line $aTwo)) {
    throw 'ASSERT_FAILED: familia A deveria ignorar contagens'
}

$bOne = 'Verify-GxJs: verificados 2178 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2301 ms'
$bTwo = 'Verify-GxJs: verificados 2200 .js (modulos pulados: 391 | placeholders pulados: 2) | invalidos: 0 | tempo: 9 ms'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $bOne) -ne (Get-GeneXusPostBuildEventFamilyHash -Line $bTwo)) {
    throw 'ASSERT_FAILED: familia B deveria ignorar contagens e tempo'
}

# Familia C: nas duas formas (Core com 2 entradas e Framework com 1), contagens nao mudam o hash.
$cCoreOne = 'CommonRspHealth: OK - GeneXus.Programs.Common.csproj ok (439 itens, 221 dominios); genexus.programs.common.bld ok (120 itens, 60 dominios); 218 gxdomain*.cs no disco'
$cCoreTwo = 'CommonRspHealth: OK - GeneXus.Programs.Common.csproj ok (441 itens, 222 dominios); genexus.programs.common.bld ok (121 itens, 61 dominios); 219 gxdomain*.cs no disco'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $cCoreOne) -ne (Get-GeneXusPostBuildEventFamilyHash -Line $cCoreTwo)) {
    throw 'ASSERT_FAILED: familia C (Core) deveria ignorar contagens'
}
$cFwOne = 'CommonRspHealth: OK - genexus.programs.common.rsp ok (439 itens, 221 dominios); 218 gxdomain*.cs no disco'
$cFwTwo = 'CommonRspHealth: OK - genexus.programs.common.rsp ok (500 itens, 300 dominios); 999 gxdomain*.cs no disco'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $cFwOne) -ne (Get-GeneXusPostBuildEventFamilyHash -Line $cFwTwo)) {
    throw 'ASSERT_FAILED: familia C (Framework) deveria ignorar contagens'
}

# Familia C: nome de arquivo diferente nao e aceito como o mesmo evento; digito no nome e preservado.
$cBld = 'CommonRspHealth: OK - genexus.programs.common.bld ok (439 itens, 221 dominios); 218 gxdomain*.cs no disco'
$cRsp = 'CommonRspHealth: OK - genexus.programs.common.rsp ok (439 itens, 221 dominios); 218 gxdomain*.cs no disco'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $cBld) -eq (Get-GeneXusPostBuildEventFamilyHash -Line $cRsp)) {
    throw 'ASSERT_FAILED: nome diferente na familia C nao pode ter o mesmo hash'
}
$cDigit18 = 'CommonRspHealth: OK - genexus.programs.common18.rsp ok (1 itens, 1 dominios); 0 gxdomain*.cs no disco'
$cDigit19 = 'CommonRspHealth: OK - genexus.programs.common19.rsp ok (1 itens, 1 dominios); 0 gxdomain*.cs no disco'
if ((Get-GeneXusPostBuildEventFamilyHash -Line $cDigit18) -eq (Get-GeneXusPostBuildEventFamilyHash -Line $cDigit19)) {
    throw 'ASSERT_FAILED: digito em nome de arquivo da familia C deveria ser preservado'
}

# Linhas fora das familias: hash da forma nova igual ao da legada, e sem texto de familia.
$outside = @(
    '[dry-run] .js varridos=5 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=1'
    '[APLICADO] .js varridos=0 | arquivos com chave negativa em gx.domain=0 | chaves corrigidas=0'
    'Verify-GxJs: verificados 0 .js (modulos pulados: 0 | placeholders pulados: 0) | invalidos: 0 | tempo: 4 ms'
    'Verify-GxJs: verificados 2178 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 1 | tempo: 2301 ms'
    'CommonRspHealth: aviso - algo'
    '> Build All Task Sucesso'
)
foreach ($o in $outside) {
    if ((Get-GeneXusPostBuildEventFamilyHash -Line $o) -ne (Get-GeneXusPostBuildEventNormalizedHash -Line $o)) {
        throw "ASSERT_FAILED: linha fora das familias deveria manter o hash legado: $o"
    }
    if ($null -ne (Get-GeneXusPostBuildEventFamilyText -Line $o)) {
        throw "ASSERT_FAILED: linha fora das familias nao deveria casar familia: $o"
    }
}

# Vetores fixos da forma legada (registros reais existentes dependem dela).
if ((Get-GeneXusPostBuildEventNormalizedHash -Line '> Build All Task Sucesso') -ne '117b74510cfb2842438aacd70a231eeffcbfee1a6547cfd353f1197c4636277d') {
    throw 'ASSERT_FAILED: vetor legado de "> Build All Task Sucesso" mudou'
}
if ((Get-GeneXusPostBuildEventNormalizedHash -Line 'Verify-GxJs: verificados 2178 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2301 ms') -ne '731e32fdd1f382e3e0f9fd19867bfc3046497ac8b695dfb59946b7750cda0d97') {
    throw 'ASSERT_FAILED: vetor legado do Verify-GxJs (tempo 2301) mudou'
}
if ((Get-GeneXusPostBuildEventNormalizedHash -Line 'Verify-GxJs: verificados 2178 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 9 ms') -ne '731e32fdd1f382e3e0f9fd19867bfc3046497ac8b695dfb59946b7750cda0d97') {
    throw 'ASSERT_FAILED: vetor legado do Verify-GxJs (tempo 9) mudou'
}

# nextStep do registro pendente (Get-GeneXusPostBuildRegistryNextStep): o build so detecta e encaminha para
# a auditoria de setup (skill xpz-kb-parallel-setup), sem citar script de registro.
$nsFamilyLine = '[APLICADO] .js varridos=2968 | arquivos com chave negativa em gx.domain=3 | chaves corrigidas=5'
$nsFamilyHash = Get-GeneXusPostBuildEventFamilyHash -Line $nsFamilyLine
$nsLegacyHash = Get-GeneXusPostBuildEventNormalizedHash -Line $nsFamilyLine
$nsOther = 'Powershell Write-Output evento-novo'
$nsSound = 'start "" powershell -NoProfile -WindowStyle Hidden -Command "(New-Object System.Media.SoundPlayer ''c:\temp\sino.wav'').PlaySync()"'

function Get-NextStepCase {
    param([string[]]$Lines, [string[]]$Registered, [string]$State)
    $classification = Get-GeneXusPostBuildEventClassification -PostBuildEventLines $Lines -RegisteredHashes $Registered
    return Get-GeneXusPostBuildRegistryNextStep -Classification $classification -RegistryState ([pscustomobject]@{ state = $State }) -EnvironmentName 'EnvTeste'
}
function Assert-NextStepText {
    param([string]$Text, [string]$Reason, [string]$Case)
    if ([string]::IsNullOrEmpty($Text)) { throw "ASSERT_FAILED: nextStep ($Case) deveria vir preenchido." }
    if ($Text -notmatch [regex]::Escape($Reason)) { throw "ASSERT_FAILED: nextStep ($Case) deveria citar '$Reason'; recebeu '$Text'." }
    if ($Text -notmatch 'xpz-kb-parallel-setup' -or $Text -notmatch 'auditoria de setup') { throw "ASSERT_FAILED: nextStep ($Case) deveria apontar para a auditoria de setup; recebeu '$Text'." }
    if ($Text -match 'Register-') { throw "ASSERT_FAILED: nextStep ($Case) nao deveria citar script de registro; recebeu '$Text'." }
    if ($Text -notmatch "'EnvTeste'") { throw "ASSERT_FAILED: nextStep ($Case) deveria citar o environment; recebeu '$Text'." }
}

# Sem entrada + evento desconhecido (sem registro, nao e som) -> sem registro
Assert-NextStepText -Text (Get-NextStepCase -Lines @($nsOther) -Registered @() -State 'noEntryForEnvironment') -Reason 'sem registro' -Case 'sem entrada e desconhecido'
# Sem entrada + so evento benigno (som) -> tambem sem registro (a auditoria conta esse caso como pendente)
Assert-NextStepText -Text (Get-NextStepCase -Lines @($nsSound) -Registered @() -State 'noEntryForEnvironment') -Reason 'sem registro' -Case 'sem entrada e benigno'
# Registro existente + evento nao registrado -> evento nao registrado
Assert-NextStepText -Text (Get-NextStepCase -Lines @($nsOther) -Registered @($nsFamilyHash) -State 'available') -Reason 'evento nao registrado' -Case 'registrado com evento novo'
# Registro so na forma legada com a mesma contagem -> aceito, mas pede regravacao
Assert-NextStepText -Text (Get-NextStepCase -Lines @($nsFamilyLine) -Registered @($nsLegacyHash) -State 'available') -Reason 'registro na forma antiga' -Case 'forma antiga'
# Registro nao consultado -> sem nextStep
if ($null -ne (Get-NextStepCase -Lines @($nsOther) -Registered @() -State 'metadataNotProvided')) { throw 'ASSERT_FAILED: metadataNotProvided nao deveria ter nextStep.' }
if ($null -ne (Get-NextStepCase -Lines @($nsOther) -Registered @() -State 'environmentNameUnavailable')) { throw 'ASSERT_FAILED: environmentNameUnavailable nao deveria ter nextStep.' }
# Registro completo (tudo esperado, forma de familia) -> sem nextStep
if ($null -ne (Get-NextStepCase -Lines @($nsFamilyLine) -Registered @($nsFamilyHash) -State 'available')) { throw 'ASSERT_FAILED: registro completo nao deveria ter nextStep.' }

# Copia do diagnostico no Temp\ da pasta paralela: sem raiz nao ha caminho; raiz inexistente nao e criada.
if ($null -ne (Get-GeneXusParallelKbBuildDiagnosticCopyPath -ParallelKbRoot '' -Stage 'buildall')) { throw 'ASSERT_FAILED: sem -ParallelKbRoot nao deveria haver caminho de copia.' }
$cpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-pbcopy-{0}' -f ([guid]::NewGuid().ToString('N')))
try {
    $cpMissing = Get-GeneXusParallelKbBuildDiagnosticCopyPath -ParallelKbRoot $cpRoot -Stage 'buildall'
    $cpMissingError = Write-GeneXusParallelKbBuildDiagnosticCopy -Path $cpMissing -JsonPayload '{}'
    if ($null -eq $cpMissingError -or $cpMissingError -notmatch 'pasta paralela inexistente') { throw "ASSERT_FAILED: raiz inexistente deveria falhar com 'pasta paralela inexistente'; obtido '$cpMissingError'." }
    if (Test-Path -LiteralPath $cpRoot) { throw 'ASSERT_FAILED: a raiz inexistente da pasta paralela nao deveria ser criada.' }
    [System.IO.Directory]::CreateDirectory($cpRoot) | Out-Null
    $cpPath = Get-GeneXusParallelKbBuildDiagnosticCopyPath -ParallelKbRoot $cpRoot -Stage 'specifygenerate'
    if ((Split-Path -Parent $cpPath) -ne (Join-Path $cpRoot 'Temp\xpz-msbuild-build')) { throw "ASSERT_FAILED: copia fora de Temp\xpz-msbuild-build: '$cpPath'." }
    $cpError = Write-GeneXusParallelKbBuildDiagnosticCopy -Path $cpPath -JsonPayload '{"status":"x"}'
    if ($null -ne $cpError) { throw "ASSERT_FAILED: gravacao da copia deveria funcionar com raiz existente; erro '$cpError'." }
    $cpBytes = [System.IO.File]::ReadAllBytes($cpPath)
    if ($cpBytes[0] -eq 0xEF) { throw 'ASSERT_FAILED: copia nao deveria ter BOM.' }
    if ([System.IO.File]::ReadAllText($cpPath) -ne ('{"status":"x"}' + [Environment]::NewLine)) { throw 'ASSERT_FAILED: conteudo da copia divergente.' }

    # Recuperacao e falha padrao (Complete-GeneXusParallelKbBuildDiagnosticCopy): cita a copia so quando gravou.
    $cpSerialize = { param($d) $d | ConvertTo-Json -Depth 6 }
    $cpOkDiag = [ordered]@{ status = 'falha'; artifacts = [ordered]@{ StdOutPath = 'x' } }
    $cpOkPath = Get-GeneXusParallelKbBuildDiagnosticCopyPath -ParallelKbRoot $cpRoot -Stage 'buildall'
    $cpOkDoc = (Complete-GeneXusParallelKbBuildDiagnosticCopy -Diagnostic $cpOkDiag -Path $cpOkPath -EnvironmentName ' EnvA ' -Serialize $cpSerialize) | ConvertFrom-Json
    if ([string]$cpOkDoc.artifacts.ParallelKbDiagnosticCopyPath -ne $cpOkPath -or [string]$cpOkDoc.validationEnvironment -ne 'EnvA') { throw 'ASSERT_FAILED: copia gravada deveria ser citada, com validationEnvironment aparado.' }
    $cpOkCopy = Get-Content -LiteralPath $cpOkPath -Raw | ConvertFrom-Json
    if ([string]$cpOkCopy.validationEnvironment -ne 'EnvA' -or [string]$cpOkCopy.artifacts.ParallelKbDiagnosticCopyPath -ne $cpOkPath) { throw 'ASSERT_FAILED: a copia gravada deveria levar validationEnvironment e o proprio caminho.' }
    $cpBadDiag = [ordered]@{ status = 'falha'; artifacts = [ordered]@{ StdOutPath = 'x' } }
    $cpBadPath = Get-GeneXusParallelKbBuildDiagnosticCopyPath -ParallelKbRoot (Join-Path $cpRoot 'nao-existe') -Stage 'buildall'
    $cpBadDoc = (Complete-GeneXusParallelKbBuildDiagnosticCopy -Diagnostic $cpBadDiag -Path $cpBadPath -EnvironmentName '' -Serialize $cpSerialize) | ConvertFrom-Json
    if ($null -ne $cpBadDoc.artifacts.ParallelKbDiagnosticCopyPath -or [string]$cpBadDoc.artifacts.ParallelKbDiagnosticCopyError -notmatch 'pasta paralela inexistente' -or $null -ne $cpBadDoc.validationEnvironment) { throw 'ASSERT_FAILED: copia nao gravada nao deveria ser citada; esperado ParallelKbDiagnosticCopyError e validationEnvironment nulo.' }
    $cpNoPathDoc = (Complete-GeneXusParallelKbBuildDiagnosticCopy -Diagnostic ([ordered]@{ status = 'falha'; artifacts = [ordered]@{} }) -Path '' -EnvironmentName 'EnvA' -Serialize $cpSerialize) | ConvertFrom-Json
    if ($null -ne $cpNoPathDoc.PSObject.Properties['validationEnvironment'] -or $null -ne $cpNoPathDoc.artifacts.PSObject.Properties['ParallelKbDiagnosticCopyPath']) { throw 'ASSERT_FAILED: sem -ParallelKbRoot o JSON nao deveria mudar.' }
}
finally {
    if (Test-Path -LiteralPath $cpRoot) { Remove-Item -LiteralPath $cpRoot -Recurse -Force }
}

Write-Output 'GENEXUS_MSBUILD_POST_BUILD_EVENTS_SUPPORT_SELFTEST_OK'
