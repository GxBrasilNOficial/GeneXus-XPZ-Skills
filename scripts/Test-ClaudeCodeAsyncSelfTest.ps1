#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$scriptUnderTest = Join-Path $scriptsDir 'Invoke-ClaudeCodeAsync.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-TestSha256Text {
    param([AllowNull()] [string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Assert-NoRawCaptureFiles {
    param([string]$Path, [string]$Message)
    $rawFiles = @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*.stream.jsonl' -or $_.Name -like '*.stderr.txt' })
    $rawFileNames = @($rawFiles | ForEach-Object { $_.Name })
    Assert-True ($rawFiles.Count -eq 0) ("{0}: stream/stderr brutos permaneceram: {1}" -f $Message, ($rawFileNames -join ', '))
}

function Assert-RawCaptureFilesExist {
    param([string]$Path, [string]$Message)
    $rawFiles = @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*.stream.jsonl' -or $_.Name -like '*.stderr.txt' })
    Assert-True ($rawFiles.Count -gt 0) ("{0}: esperava stream/stderr bruto para simular falha de limpeza." -f $Message)
}

function New-FakeClaudeCodeExe {
    param([string]$TempRoot)
    $fakeExe = Join-Path $TempRoot 'claude.cmd'
    $argsFile = Join-Path $TempRoot 'args.txt'
    $script = @"
@echo off
if "%1"=="--version" (
  echo 2.1.118
  exit /b 0
)
if "%1"=="--help" (
  echo --model --print --output-format --no-session-persistence --permission-mode --tools
  exit /b 0
)
echo %FAKE_CLAUDE_MODE% %*>>"$argsFile"
if "%FAKE_CLAUDE_MODE%"=="success-delta" (
  echo {"type":"assistant","message":{"content":[{"text":"texto duplicado"}]}}
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"A"}}
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"B"}}
  echo {"type":"result","subtype":"success","is_error":false,"result":"NAO_E_VEREDITO"}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="success-assistant" (
  echo {"type":"assistant","message":{"content":[{"text":"parecer aceito"}]}}
  echo {"type":"result","subtype":"success","is_error":false}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="success-newline" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"linha\n"}}
  echo {"type":"result","subtype":"success","is_error":false}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="success-stderr" (
  echo {"type":"assistant","message":{"content":[{"text":"parecer com stderr"}]}}
  echo detalhe bruto sensivel 1>&2
  echo {"type":"result","subtype":"success","is_error":false}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="success-no-terminal" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"texto-sem-terminal"}}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="success-incomplete-terminal" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"texto-terminal-incompleto"}}
  echo {"type":"result","subtype":"success"}
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="quota-after-text" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"parcial"}}
  echo {"type":"result","is_error":true,"terminal_reason":"api_error","api_error_status":429,"rateLimitType":"weekly","reportedLimitScope":"subscription","resetsAt":1893456000,"result":"rate limit"}
  exit /b 1
)
if "%FAKE_CLAUDE_MODE%"=="timeout-after-text" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"parcial-timeout"}}
  ping -n 6 127.0.0.1 >nul
  exit /b 0
)
if "%FAKE_CLAUDE_MODE%"=="exit-after-text" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"parcial-exit"}}
  exit /b 1
)
if "%FAKE_CLAUDE_MODE%"=="untrusted" (
  echo Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue. 1>&2
  exit /b 1
)
if "%FAKE_CLAUDE_MODE%"=="sleep" (
  ping -n 6 127.0.0.1 >nul
  exit /b 0
)
echo {"type":"result","subtype":"success","is_error":false}
exit /b 0
"@
    Set-Content -LiteralPath $fakeExe -Value $script -Encoding ascii
    [pscustomobject]@{ Exe = $fakeExe; ArgsFile = $argsFile }
}

function Invoke-AdapterCase {
    param(
        [string]$TempRoot,
        [string]$Mode,
        [string]$ClaudeExe,
        [string]$CircuitRoot,
        [string]$RetentionMode = 'public',
        [int]$TimeoutSec = 30,
        [switch]$ForceRetentionCleanupFailure
    )
    $env:FAKE_CLAUDE_MODE = $Mode
    $previousForceCleanup = $env:XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL
    if ($ForceRetentionCleanupFailure) { $env:XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL = '1' }
    else { Remove-Item Env:\XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL -ErrorAction SilentlyContinue }
    $caseId = [guid]::NewGuid().ToString('N')
    $prompt = Join-Path $TempRoot "prompt-$Mode-$caseId.md"
    Set-Content -LiteralPath $prompt -Value "prompt $Mode" -Encoding utf8
    $sidecar = Join-Path $TempRoot "$Mode-$caseId.sidecar.json"
    $adapterTemp = Join-Path $TempRoot "adapter-$Mode-$caseId"
    New-Item -ItemType Directory -Path $adapterTemp -Force | Out-Null
    try {
        $stdout = & $scriptUnderTest -MessagePath $prompt -SidecarPath $sidecar -Model 'claude-opus-4-8' `
            -ClaudeExe $ClaudeExe -CircuitStateRoot $CircuitRoot -TempDir $adapterTemp `
            -RetentionMode $RetentionMode -TimeoutSec $TimeoutSec -Cd $TempRoot
        $sidecarJson = Get-Content -LiteralPath $sidecar -Raw -Encoding utf8 | ConvertFrom-Json
        [pscustomobject]@{
            stdout      = if ($null -eq $stdout) { '' } elseif ($stdout -is [array]) { $stdout -join "`n" } else { [string]$stdout }
            sidecar     = $sidecarJson
            path        = $sidecar
            adapterTemp = $adapterTemp
        }
    }
    finally {
        if ($null -eq $previousForceCleanup) { Remove-Item Env:\XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL -ErrorAction SilentlyContinue }
        else { $env:XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL = $previousForceCleanup }
    }
}

Assert-True (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf) "Script sob teste ausente: $scriptUnderTest"

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('claude-code-async-selftest-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$previousMode = $env:FAKE_CLAUDE_MODE
try {
    $fake = New-FakeClaudeCodeExe -TempRoot $tmp

    $circuitOk = Join-Path $tmp 'circuit-ok'
    $ok = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitOk
    Assert-True ($ok.stdout -eq 'AB') "stdout aceito deveria ser apenas deltas concatenados; veio '$($ok.stdout)'."
    Assert-True ($ok.sidecar.Kind -eq 'claude-code-async-sidecar') 'sidecar: Kind invalido.'
    Assert-True ([int]$ok.sidecar.SchemaVersion -eq 1) 'sidecar: SchemaVersion deveria ser 1.'
    Assert-True ($ok.sidecar.technicalStatus -eq 'completed') 'sidecar: technicalStatus completed esperado.'
    Assert-True ($ok.sidecar.resultAccepted -eq $true) 'sidecar: resultAccepted=true esperado.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$ok.sidecar.acceptedFinalTextSha256)) 'sidecar: hash do texto aceito ausente.'
    Assert-True ($ok.sidecar.promptTransmission -eq 'stdin-file') 'sidecar: promptTransmission deveria ser stdin-file.'
    Assert-True ($ok.sidecar.processCreated -eq $true) 'sidecar: processCreated=true esperado.'
    Assert-True ($ok.sidecar.quotaCircuitDecision -eq 'closed') 'sidecar: circuito sem estado deveria ser closed.'

    $newline = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-newline' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-newline')
    Assert-True ($newline.stdout -eq 'linha') 'newline terminal: stdout deveria remover apenas quebra final.'
    Assert-True ($newline.sidecar.acceptedFinalTextSha256 -eq (Get-TestSha256Text -Text $newline.stdout)) 'newline terminal: hash do sidecar deveria casar com stdout capturado.'
    Assert-True ([int]$newline.sidecar.acceptedFinalTextBytes -eq [System.Text.Encoding]::UTF8.GetByteCount($newline.stdout)) 'newline terminal: bytes do sidecar deveriam casar com stdout capturado.'

    $noTerminal = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-no-terminal' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-no-terminal')
    Assert-True ([string]::IsNullOrWhiteSpace($noTerminal.stdout)) 'sem terminal: stdout deveria ficar vazio.'
    Assert-True ($noTerminal.sidecar.technicalStatus -eq 'internalError') 'sem terminal: technicalStatus deveria ser internalError.'
    Assert-True ($noTerminal.sidecar.resultAccepted -eq $false) 'sem terminal: resultAccepted deveria ser false.'
    Assert-True ($noTerminal.sidecar.failureAfterText.reason -eq 'process-exit-after-partial-text') 'sem terminal: texto parcial deveria virar failureAfterText.'

    $incompleteTerminal = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-incomplete-terminal' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-incomplete-terminal')
    Assert-True ([string]::IsNullOrWhiteSpace($incompleteTerminal.stdout)) 'terminal incompleto: stdout deveria ficar vazio.'
    Assert-True ($incompleteTerminal.sidecar.technicalStatus -eq 'internalError') 'terminal incompleto: technicalStatus deveria ser internalError.'
    Assert-True ($incompleteTerminal.sidecar.resultAccepted -eq $false) 'terminal incompleto: resultAccepted deveria ser false.'
    Assert-True ($incompleteTerminal.sidecar.failureAfterText.reason -eq 'process-exit-after-partial-text') 'terminal incompleto: texto parcial deveria virar failureAfterText.'

    $kb = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-stderr' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-kb') -RetentionMode 'kb-sensitive'
    Assert-True ($kb.stdout -eq 'parecer com stderr') 'kb-sensitive: stdout aceito deveria conter o parecer final.'
    Assert-True ($null -eq $kb.sidecar.streamSha256) 'kb-sensitive: streamSha256 deve ser omitido/null.'
    Assert-True ($null -eq $kb.sidecar.stderrSha256) 'kb-sensitive: stderrSha256 deve ser omitido/null.'
    Assert-True ($kb.sidecar.retentionCleanupFailed -eq $false) 'kb-sensitive: limpeza de stream/stderr deveria completar.'
    Assert-NoRawCaptureFiles -Path $kb.adapterTemp -Message 'kb-sensitive sucesso'

    $cleanupFail = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-stderr' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-cleanup-fail') -RetentionMode 'kb-sensitive' -ForceRetentionCleanupFailure
    Assert-True ([string]::IsNullOrWhiteSpace($cleanupFail.stdout)) 'kb-sensitive limpeza falhou: stdout deveria ficar vazio.'
    Assert-True ($cleanupFail.sidecar.technicalStatus -eq 'internalError') 'kb-sensitive limpeza falhou: technicalStatus deveria ser internalError.'
    Assert-True ($cleanupFail.sidecar.resultAccepted -eq $false) 'kb-sensitive limpeza falhou: resultAccepted deveria ser false.'
    Assert-True ($cleanupFail.sidecar.acceptanceRejectionReason -eq 'retention-cleanup-failed') 'kb-sensitive limpeza falhou: reason deveria ser retention-cleanup-failed.'
    Assert-True ($cleanupFail.sidecar.retentionCleanupFailed -eq $true) 'kb-sensitive limpeza falhou: retentionCleanupFailed deveria ser true.'
    Assert-True ($cleanupFail.sidecar.failureAfterText.reason -eq 'retention-cleanup-after-accepted-text') 'kb-sensitive limpeza falhou: deve preservar metadado redigido do texto aceito bloqueado.'
    Assert-True ($null -eq $cleanupFail.sidecar.failureAfterText.textSha256) 'kb-sensitive limpeza falhou: textSha256 deveria ser null.'
    Assert-RawCaptureFilesExist -Path $cleanupFail.adapterTemp -Message 'kb-sensitive limpeza falhou'

    $circuitQuota = Join-Path $tmp 'circuit-quota'
    $quota = Invoke-AdapterCase -TempRoot $tmp -Mode 'quota-after-text' -ClaudeExe $fake.Exe -CircuitRoot $circuitQuota
    Assert-True ([string]::IsNullOrWhiteSpace($quota.stdout)) 'quota: stdout deveria ficar vazio.'
    Assert-True ($quota.sidecar.technicalStatus -eq 'quota') 'quota: technicalStatus deveria ser quota.'
    Assert-True ($quota.sidecar.resultAccepted -eq $false) 'quota: resultAccepted=false esperado.'
    Assert-True ($quota.sidecar.failureAfterText.reason -eq 'quota-after-text') 'quota: failureAfterText deveria registrar falha apos texto.'
    $quotaStatePath = Join-Path (Join-Path $circuitQuota 'claude-code-quota-circuit') "$($quota.sidecar.quotaEvidence.baseKeyHash).weekly.state.json"
    $quotaState = Get-Content -LiteralPath $quotaStatePath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($quotaState.provider -eq 'anthropic') 'estado de cota: provider ausente/incorreto.'
    Assert-True ($quotaState.modelKey -eq 'claude-opus-4-8') 'estado de cota: modelKey ausente/incorreto.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$quotaState.credentialContextFingerprint)) 'estado de cota: credentialContextFingerprint ausente.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$quotaState.observedAtUtc)) 'estado de cota: observedAtUtc ausente.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$quotaState.lastHitAtUtc)) 'estado de cota: lastHitAtUtc ausente.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$quotaState.updatedAtUtc)) 'estado de cota: updatedAtUtc ausente.'
    Assert-True ([int]$quotaState.hitCount -ge 1) 'estado de cota: hitCount deveria ser >= 1.'
    Assert-True ($quotaState.effectiveLimitScope -eq 'subscription') 'estado de cota: effectiveLimitScope deveria refletir escopo reportado.'
    Assert-True ($quotaState.scopeAssumed -eq $false) 'estado de cota: scopeAssumed deveria ser false quando ha escopo reportado.'
    Assert-True ($null -eq $quotaState.scopeAssumptionReason) 'estado de cota: scopeAssumptionReason deveria ser null quando ha escopo reportado.'
    Assert-True ($null -ne $quotaState.sourceEvidence) 'estado de cota: sourceEvidence ausente.'
    Assert-True (@($quotaState.sourceEvidence.evidenceTypes) -contains 'result-api-error-429') 'estado de cota: sourceEvidence nao preservou tipo de evidencia.'
    Assert-True ($quotaState.sourceEvidence.terminalReason -eq 'api_error') 'estado de cota: sourceEvidence nao preservou terminalReason.'
    Assert-True ([string]$quotaState.sourceEvidence.apiErrorStatus -eq '429') 'estado de cota: sourceEvidence nao preservou apiErrorStatus.'
    $argsBeforeBlock = @(Get-Content -LiteralPath $fake.ArgsFile)
    $blocked = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitQuota
    $argsAfterBlock = @(Get-Content -LiteralPath $fake.ArgsFile)
    Assert-True ([string]::IsNullOrWhiteSpace($blocked.stdout)) 'circuito aberto: stdout deveria ficar vazio.'
    Assert-True ($blocked.sidecar.spawnAttempted -eq $false) 'circuito aberto: nao deve tentar spawn.'
    Assert-True ($null -eq $blocked.sidecar.exitCode) 'circuito aberto: exitCode deve ser null quando nao ha processo.'
    Assert-True ($blocked.sidecar.promptTransmission -eq 'none') 'circuito aberto: nao deve transmitir prompt.'
    Assert-True ($blocked.sidecar.quotaCircuitDecision -eq 'open') "circuito aberto: decisao deveria ser open; veio $($blocked.sidecar.quotaCircuitDecision)."
    Assert-True ($argsAfterBlock.Count -eq $argsBeforeBlock.Count) 'circuito aberto: fake CLI nao deveria ser chamado.'

    $circuitInvalid = Join-Path $tmp 'circuit-invalid'
    $ctxDir = Join-Path $circuitInvalid 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $ctxDir -Force | Out-Null
    $baseHash = $blocked.sidecar.quotaEvidence.baseKeyHash
    Set-Content -LiteralPath (Join-Path $ctxDir "$baseHash.hourly.state.json") -Value '{ json invalido' -Encoding utf8
    $invalid = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitInvalid
    Assert-True ($invalid.sidecar.quotaCircuitDecision -eq 'closed-with-invalid-state-ignored') "estado invalido: decisao agregada inesperada $($invalid.sidecar.quotaCircuitDecision)."
    Assert-True ($invalid.stdout -eq 'AB') 'estado invalido ignorado: chamada deveria seguir e aceitar texto.'
    Assert-True (Test-Path -LiteralPath (Join-Path $ctxDir "$baseHash.hourly.state.json") -PathType Leaf) 'estado invalido nao deve ser apagado automaticamente.'

    $circuitNewerFence = Join-Path $tmp 'circuit-newer-fence'
    $fenceDir = Join-Path $circuitNewerFence 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $fenceDir -Force | Out-Null
    $fencePath = Join-Path $fenceDir "$baseHash.weekly.state.json"
    $newerEvidenceState = [ordered]@{
        Kind          = 'claude-code-quota-circuit-state'
        SchemaVersion = 1
        circuitState  = 'open'
        baseKeyHash   = $baseHash
        backend       = 'claude-code'
        model         = 'claude-opus-4-8'
        rateLimitType = 'weekly'
        openedAtUtc   = '2020-01-01T00:00:00Z'
        updatedAtUtc  = '2020-01-01T00:00:00Z'
        observedAtUtc = '2030-01-01T00:00:00Z'
        resetsAtUtc   = '2020-01-01T00:00:01Z'
    }
    $newerEvidenceState | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $fencePath -Encoding utf8
    $fenced = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitNewerFence
    Assert-True ($fenced.sidecar.quotaCircuitDecision -eq 'half-open') "estado com evidencia mais nova: deveria sondar half-open; veio $($fenced.sidecar.quotaCircuitDecision)."
    Assert-True ($fenced.stdout -eq 'AB') 'estado com evidencia mais nova: chamada deveria seguir e aceitar texto.'
    Assert-True (Test-Path -LiteralPath $fencePath -PathType Leaf) 'estado com evidencia mais nova nao deve ser apagado por limpeza de sonda antiga.'

    $circuitInvalidAndOpen = Join-Path $tmp 'circuit-invalid-and-open'
    $mixedDir = Join-Path $circuitInvalidAndOpen 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $mixedDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $mixedDir "$baseHash.hourly.state.json") -Value '{ json invalido' -Encoding utf8
    $futureOpen = [ordered]@{
        Kind          = 'claude-code-quota-circuit-state'
        SchemaVersion = 1
        circuitState  = 'open'
        baseKeyHash   = $baseHash
        backend       = 'claude-code'
        model         = 'claude-opus-4-8'
        rateLimitType = 'daily'
        openedAtUtc   = '2029-12-31T00:00:00Z'
        resetsAtUtc   = '2030-01-01T00:00:00Z'
    }
    $futureOpen | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $mixedDir "$baseHash.daily.state.json") -Encoding utf8
    $mixedBlocked = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitInvalidAndOpen
    Assert-True ($mixedBlocked.sidecar.quotaCircuitDecision -eq 'open') "estado invalido + aberto: decisao agregada deveria ser open; veio $($mixedBlocked.sidecar.quotaCircuitDecision)."
    Assert-True ([string]::IsNullOrWhiteSpace($mixedBlocked.stdout)) 'estado invalido + aberto: stdout deveria ficar vazio.'
    Assert-True (@($mixedBlocked.sidecar.quotaEvidence.variantDecisions | ForEach-Object { $_.decision }) -contains 'state-json-invalid') 'estado invalido + aberto: evidencia por variante deveria preservar state-json-invalid.'

    $circuitReadInconclusiveAndOpen = Join-Path $tmp 'circuit-read-inconclusive-and-open'
    $inconclusiveDir = Join-Path $circuitReadInconclusiveAndOpen 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $inconclusiveDir -Force | Out-Null
    $futureOpen | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $inconclusiveDir "$baseHash.daily.state.json") -Encoding utf8
    $lockedStatePath = Join-Path $inconclusiveDir "$baseHash.hourly.state.json"
    $futureOpen | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $lockedStatePath -Encoding utf8
    $lockedState = [System.IO.File]::Open($lockedStatePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $inconclusiveBlocked = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitReadInconclusiveAndOpen
    }
    finally {
        $lockedState.Dispose()
    }
    Assert-True ($inconclusiveBlocked.sidecar.quotaCircuitDecision -eq 'state-read-inconclusive') "leitura inconclusiva + aberto: decisao agregada deveria ser state-read-inconclusive; veio $($inconclusiveBlocked.sidecar.quotaCircuitDecision)."
    Assert-True ([string]::IsNullOrWhiteSpace($inconclusiveBlocked.stdout)) 'leitura inconclusiva + aberto: stdout deveria ficar vazio.'
    Assert-True (@($inconclusiveBlocked.sidecar.quotaEvidence.variantDecisions | ForEach-Object { $_.decision }) -contains 'open') 'leitura inconclusiva + aberto: evidencia por variante deveria preservar open.'

    $circuitLease = Join-Path $tmp 'circuit-lease'
    $leaseDir = Join-Path $circuitLease 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $leaseDir -Force | Out-Null
    $expired = [ordered]@{
        Kind          = 'claude-code-quota-circuit-state'
        SchemaVersion = 1
        circuitState  = 'open'
        baseKeyHash   = $baseHash
        backend       = 'claude-code'
        model         = 'claude-opus-4-8'
        rateLimitType = 'weekly'
        openedAtUtc   = '2020-01-01T00:00:00Z'
        resetsAtUtc   = '2020-01-01T00:00:01Z'
    }
    $expired | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $leaseDir "$baseHash.weekly.state.json") -Encoding utf8
    $lease = [ordered]@{
        Kind              = 'claude-code-quota-half-open-lease'
        SchemaVersion     = 1
        baseKeyHash       = $baseHash
        probeStartedAtUtc = '2029-12-31T00:00:00Z'
        probeExpiresAtUtc = '2030-01-01T00:00:00Z'
    }
    $lease | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $leaseDir "$baseHash.lease.json") -Encoding utf8
    $observed = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-delta' -ClaudeExe $fake.Exe -CircuitRoot $circuitLease
    Assert-True ($observed.sidecar.quotaCircuitDecision -eq 'half-open-observed') "lease: decisao deveria ser half-open-observed; veio $($observed.sidecar.quotaCircuitDecision)."
    Assert-True ($observed.sidecar.spawnAttempted -eq $false) 'lease: nao deve spawn quando ha probe half-open ativo.'

    $circuitProbeLease = Join-Path $tmp 'circuit-probe-lease'
    $probeLeaseDir = Join-Path $circuitProbeLease 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $probeLeaseDir -Force | Out-Null
    $expired | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $probeLeaseDir "$baseHash.weekly.state.json") -Encoding utf8
    $probeTimeout = Invoke-AdapterCase -TempRoot $tmp -Mode 'timeout-after-text' -ClaudeExe $fake.Exe `
        -CircuitRoot $circuitProbeLease -TimeoutSec 1 -RetentionMode 'kb-sensitive'
    Assert-True ($probeTimeout.sidecar.quotaCircuitDecision -eq 'half-open') "lease novo: decisao deveria ser half-open; veio $($probeTimeout.sidecar.quotaCircuitDecision)."
    Assert-True ([string]::IsNullOrWhiteSpace($probeTimeout.stdout)) 'timeout apos texto: stdout deveria ficar vazio.'
    Assert-True ($probeTimeout.sidecar.technicalStatus -eq 'timeout') 'timeout apos texto: technicalStatus deveria ser timeout.'
    Assert-True ($probeTimeout.sidecar.failureAfterText.reason -eq 'timeout-after-partial-text') 'timeout apos texto: failureAfterText deveria registrar timeout-after-partial-text.'
    Assert-True ([int]$probeTimeout.sidecar.failureAfterText.textBytes -gt 0) 'timeout apos texto: textBytes deveria ser maior que zero.'
    Assert-True ($null -eq $probeTimeout.sidecar.failureAfterText.textSha256) 'timeout apos texto kb-sensitive: textSha256 deveria ser null.'
    Assert-True ($probeTimeout.sidecar.retentionCleanupFailed -eq $false) 'timeout apos texto kb-sensitive: limpeza de stream/stderr deveria completar.'
    Assert-NoRawCaptureFiles -Path $probeTimeout.adapterTemp -Message 'kb-sensitive timeout apos texto'
    $newLease = Get-Content -LiteralPath (Join-Path $probeLeaseDir "$baseHash.lease.json") -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($newLease.probeOwner.jobId -eq $newLease.probeAttemptId) 'lease novo: probeOwner/probeAttemptId deveriam compartilhar o job da tentativa.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$newLease.probeAttemptId)) 'lease novo: probeAttemptId ausente.'
    Assert-True ([int]$newLease.probeLeaseSeconds -eq 120) 'lease novo: TimeoutSec=1 deveria gerar probeLeaseSeconds=120.'
    $leaseSeconds = [int](([datetime]$newLease.probeExpiresAtUtc - [datetime]$newLease.probeStartedAtUtc).TotalSeconds)
    Assert-True ($leaseSeconds -eq 120) 'lease novo: janela persistida deveria ser 120 segundos.'

    $circuitProbeLeaseLong = Join-Path $tmp 'circuit-probe-lease-long'
    $probeLeaseLongDir = Join-Path $circuitProbeLeaseLong 'claude-code-quota-circuit'
    New-Item -ItemType Directory -Path $probeLeaseLongDir -Force | Out-Null
    $expired | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath (Join-Path $probeLeaseLongDir "$baseHash.weekly.state.json") -Encoding utf8
    $exitPartial = Invoke-AdapterCase -TempRoot $tmp -Mode 'exit-after-text' -ClaudeExe $fake.Exe `
        -CircuitRoot $circuitProbeLeaseLong -TimeoutSec 180
    Assert-True ([string]::IsNullOrWhiteSpace($exitPartial.stdout)) 'process exit apos texto: stdout deveria ficar vazio.'
    Assert-True ($exitPartial.sidecar.technicalStatus -eq 'internalError') 'process exit apos texto: technicalStatus deveria ser internalError.'
    Assert-True ($exitPartial.sidecar.failureAfterText.reason -eq 'process-exit-after-partial-text') 'process exit apos texto: failureAfterText deveria registrar process-exit-after-partial-text.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$exitPartial.sidecar.failureAfterText.textSha256)) 'process exit apos texto public: textSha256 deveria existir.'
    $longLease = Get-Content -LiteralPath (Join-Path $probeLeaseLongDir "$baseHash.lease.json") -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ([int]$longLease.probeLeaseSeconds -eq 210) 'lease longo: TimeoutSec=180 deveria gerar probeLeaseSeconds=210.'

    $sensitiveExitPartial = Invoke-AdapterCase -TempRoot $tmp -Mode 'exit-after-text' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-exit-kb') -RetentionMode 'kb-sensitive'
    Assert-True ([string]::IsNullOrWhiteSpace($sensitiveExitPartial.stdout)) 'process exit apos texto kb-sensitive: stdout deveria ficar vazio.'
    Assert-True ($sensitiveExitPartial.sidecar.failureAfterText.reason -eq 'process-exit-after-partial-text') 'process exit apos texto kb-sensitive: failureAfterText deveria registrar process-exit-after-partial-text.'
    Assert-True ($null -eq $sensitiveExitPartial.sidecar.failureAfterText.textSha256) 'process exit apos texto kb-sensitive: textSha256 deveria ser null.'
    Assert-True ($sensitiveExitPartial.sidecar.retentionCleanupFailed -eq $false) 'process exit apos texto kb-sensitive: limpeza de stream/stderr deveria completar.'
    Assert-NoRawCaptureFiles -Path $sensitiveExitPartial.adapterTemp -Message 'kb-sensitive process exit apos texto'

    $timeout = Invoke-AdapterCase -TempRoot $tmp -Mode 'sleep' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-timeout') -TimeoutSec 1
    Assert-True ($timeout.sidecar.technicalStatus -eq 'timeout') 'timeout: technicalStatus deveria ser timeout.'
    Assert-True ($timeout.sidecar.cancelRequested -eq $true) 'timeout: cancelRequested=true esperado.'
    Assert-True ($timeout.sidecar.processIdentity.startTimeUtc -ne $null) 'timeout: StartTime real deveria ser capturado.'
    Assert-True ($timeout.sidecar.acceptanceRejectionReason -eq 'timeout') 'timeout normal nao deve virar cancelled.'

    Write-Output 'OK: Test-ClaudeCodeAsyncSelfTest.ps1'
}
finally {
    if ($null -eq $previousMode) { Remove-Item Env:\FAKE_CLAUDE_MODE -ErrorAction SilentlyContinue }
    else { $env:FAKE_CLAUDE_MODE = $previousMode }
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
