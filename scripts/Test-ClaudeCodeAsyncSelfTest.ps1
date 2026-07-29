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
if "%FAKE_CLAUDE_MODE%"=="quota-after-text" (
  echo {"type":"content_block_delta","delta":{"type":"text_delta","text":"parcial"}}
  echo {"type":"result","is_error":true,"terminal_reason":"api_error","api_error_status":429,"rateLimitType":"weekly","reportedLimitScope":"subscription","resetsAt":1893456000,"result":"rate limit"}
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
        [int]$TimeoutSec = 30
    )
    $env:FAKE_CLAUDE_MODE = $Mode
    $prompt = Join-Path $TempRoot "prompt-$Mode.md"
    Set-Content -LiteralPath $prompt -Value "prompt $Mode" -Encoding utf8
    $sidecar = Join-Path $TempRoot "$Mode.sidecar.json"
    $adapterTemp = Join-Path $TempRoot "adapter-$Mode"
    New-Item -ItemType Directory -Path $adapterTemp -Force | Out-Null
    $stdout = & $scriptUnderTest -MessagePath $prompt -SidecarPath $sidecar -Model 'claude-opus-4-8' `
        -ClaudeExe $ClaudeExe -CircuitStateRoot $CircuitRoot -TempDir $adapterTemp `
        -RetentionMode $RetentionMode -TimeoutSec $TimeoutSec -Cd $TempRoot
    $sidecarJson = Get-Content -LiteralPath $sidecar -Raw -Encoding utf8 | ConvertFrom-Json
    [pscustomobject]@{
        stdout  = if ($null -eq $stdout) { '' } elseif ($stdout -is [array]) { $stdout -join "`n" } else { [string]$stdout }
        sidecar = $sidecarJson
        path    = $sidecar
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

    $kb = Invoke-AdapterCase -TempRoot $tmp -Mode 'success-assistant' -ClaudeExe $fake.Exe `
        -CircuitRoot (Join-Path $tmp 'circuit-kb') -RetentionMode 'kb-sensitive'
    Assert-True ($kb.stdout -eq 'parecer aceito') 'kb-sensitive: stdout aceito deveria conter o parecer final.'
    Assert-True ($null -eq $kb.sidecar.streamSha256) 'kb-sensitive: streamSha256 deve ser omitido/null.'
    Assert-True ($null -eq $kb.sidecar.stderrSha256) 'kb-sensitive: stderrSha256 deve ser omitido/null.'

    $circuitQuota = Join-Path $tmp 'circuit-quota'
    $quota = Invoke-AdapterCase -TempRoot $tmp -Mode 'quota-after-text' -ClaudeExe $fake.Exe -CircuitRoot $circuitQuota
    Assert-True ([string]::IsNullOrWhiteSpace($quota.stdout)) 'quota: stdout deveria ficar vazio.'
    Assert-True ($quota.sidecar.technicalStatus -eq 'quota') 'quota: technicalStatus deveria ser quota.'
    Assert-True ($quota.sidecar.resultAccepted -eq $false) 'quota: resultAccepted=false esperado.'
    Assert-True ($quota.sidecar.failureAfterText.reason -eq 'quota-after-text') 'quota: failureAfterText deveria registrar falha apos texto.'
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
