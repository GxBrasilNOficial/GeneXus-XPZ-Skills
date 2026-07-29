#requires -Version 7.4
<#
.SYNOPSIS
    Adapter Claude Code assíncrono tipado para o painel xpz-llm-delegate.
.DESCRIPTION
    Uso interno do dispatcher de painel. Executa `claude -p --output-format stream-json`, grava
    um sidecar técnico atômico em JSON e só escreve no stdout o texto final aceito. JSON técnico
    nunca vai ao stdout. Em `kb-sensitive`, texto bruto só pode persistir depois de aceito pelo
    dispatcher como `.verdict.txt`; este adapter omite hashes de stream/stderr nesse modo.
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [Parameter(Mandatory)] [string] $SidecarPath,
    [string] $Model = 'claude-opus-4-8',
    [ValidateSet('default', 'acceptEdits', 'plan', 'auto', 'dontAsk', 'bypassPermissions')] [string] $PermissionMode = 'plan',
    [string] $Tools = 'Read,Glob,Grep',
    [string] $Cd,
    [string] $ClaudeExe,
    [ValidateRange(1, 3600)] [int] $TimeoutSec = 300,
    [ValidateSet('public', 'kb-sensitive')] [string] $RetentionMode = 'public',
    [string] $CircuitStateRoot,
    [string] $TempDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

function ConvertTo-AsyncUtcIso {
    param([AllowNull()] $Value)
    if ($null -eq $Value) { return $null }
    return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Get-AsyncSha256Text {
    param([AllowNull()] [string] $Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

function Get-AsyncSha256File {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = [System.Security.Cryptography.SHA256]::HashData($stream)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
    }
}

function Write-AsyncJsonAtomic {
    param([string]$Path, [object]$Object, [int]$Depth = 12)
    $targetPath = [System.IO.Path]::GetFullPath($Path)
    $dir = [System.IO.Path]::GetDirectoryName($targetPath)
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = [System.IO.Directory]::GetCurrentDirectory() }
    [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    $tmp = Join-Path $dir ('.tmp-' + [guid]::NewGuid().ToString('N') + '.json')
    $backup = Join-Path $dir ('.bak-' + [guid]::NewGuid().ToString('N') + '.json')
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $tmpOwnsContent = $false
    $replaceSucceeded = $false
    try {
        [System.IO.File]::WriteAllText($tmp, ($Object | ConvertTo-Json -Compress -Depth $Depth), $utf8NoBom)
        $tmpOwnsContent = $true
        if ([System.IO.File]::Exists($targetPath)) {
            [System.IO.File]::Replace($tmp, $targetPath, $backup, $true)
            $tmpOwnsContent = $false
            $replaceSucceeded = $true
            if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) }
        }
        else {
            [System.IO.File]::Move($tmp, $targetPath, $false)
            $tmpOwnsContent = $false
        }
    }
    finally {
        if ($tmpOwnsContent -and [System.IO.File]::Exists($tmp)) {
            try { [System.IO.File]::Delete($tmp) } catch { }
        }
        if ($replaceSucceeded -and [System.IO.File]::Exists($backup)) {
            try { [System.IO.File]::Delete($backup) } catch { }
        }
    }
}

function Read-AsyncJsonWithDeadline {
    param([string]$Path, [int]$DeadlineMs = 150)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ status = 'missing'; value = $null; error = $null }
    }
    $deadline = [datetime]::UtcNow.AddMilliseconds($DeadlineMs)
    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
            try {
                $sr = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8, $true)
                try { $raw = $sr.ReadToEnd() } finally { $sr.Dispose() }
            }
            finally {
                $fs.Dispose()
            }
            try {
                return [pscustomobject]@{ status = 'ok'; value = ($raw | ConvertFrom-Json); error = $null }
            }
            catch {
                return [pscustomobject]@{ status = 'json-invalid'; value = $null; error = $_.Exception.Message }
            }
        }
        catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 25
        }
    }
    return [pscustomobject]@{ status = 'read-inconclusive'; value = $null; error = 'deadline' }
}

function Get-AsyncSafeHash {
    param([string]$Text)
    return (Get-AsyncSha256Text -Text $Text).Substring(0, 32)
}

function Get-AsyncDefaultCircuitRoot {
    if (-not [string]::IsNullOrWhiteSpace($CircuitStateRoot)) { return $CircuitStateRoot }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        return (Join-Path $env:LOCALAPPDATA 'xpz-llm-delegate')
    }
    return (Join-Path ([System.IO.Path]::GetTempPath()) 'xpz-llm-delegate')
}

function Get-AsyncCircuitContext {
    param([string]$Root, [string]$ModelName)
    $credentialSignal = if ([string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) { 'anthropic-api-key=absent' } else { 'anthropic-api-key=present' }
    $credentialFingerprint = Get-AsyncSafeHash -Text $credentialSignal
    $baseKey = "provider=anthropic|backend=claude-code|modelKey=$ModelName|credentialContextFingerprint=$credentialFingerprint"
    $safeBaseKey = Get-AsyncSafeHash -Text $baseKey
    $stateDir = Join-Path $Root 'claude-code-quota-circuit'
    [pscustomobject]@{
        stateDir              = $stateDir
        safeBaseKey           = $safeBaseKey
        provider              = 'anthropic'
        backend               = 'claude-code'
        modelKey              = $ModelName
        credentialFingerprint = $credentialFingerprint
    }
}

function Get-AsyncIsoToUtc {
    param([AllowNull()] [string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return ([datetimeoffset]::Parse($Text, [System.Globalization.CultureInfo]::InvariantCulture)).UtcDateTime } catch { return $null }
}

function New-AsyncHalfOpenLease {
    param([object]$Context, [int]$TimeoutSeconds)
    [System.IO.Directory]::CreateDirectory($Context.stateDir) | Out-Null
    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    $lockPath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.lock"
    $deadline = [datetime]::UtcNow.AddMilliseconds(250)
    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $lock = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            try {
                $read = Read-AsyncJsonWithDeadline -Path $leasePath -DeadlineMs 150
                if ($read.status -eq 'ok') {
                    $expires = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $read.value 'probeExpiresAtUtc'))
                    if ($null -ne $expires -and $expires -gt [datetime]::UtcNow) {
                        return [pscustomobject]@{ status = 'observed'; leasePath = $leasePath }
                    }
                }
                $now = [datetime]::UtcNow
                $probeLeaseSeconds = [Math]::Max(($TimeoutSeconds + 30), 120)
                $lease = [ordered]@{
                    Kind              = 'claude-code-quota-half-open-lease'
                    SchemaVersion     = 1
                    baseKeyHash       = $Context.safeBaseKey
                    probeOwner        = [ordered]@{
                        adapterName = 'Invoke-ClaudeCodeAsync.ps1'
                        jobId       = $script:jobId
                        processId   = $PID
                        machineName = $env:COMPUTERNAME
                        userName    = $env:USERNAME
                    }
                    probeAttemptId    = $script:jobId
                    probeLeaseSeconds = $probeLeaseSeconds
                    probeStartedAtUtc = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    probeExpiresAtUtc = $now.AddSeconds($probeLeaseSeconds).ToString('yyyy-MM-ddTHH:mm:ssZ')
                }
                Write-AsyncJsonAtomic -Path $leasePath -Object $lease -Depth 6
                return [pscustomobject]@{ status = 'acquired'; leasePath = $leasePath }
            }
            finally {
                $lock.Dispose()
            }
        }
        catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 25
        }
    }
    return [pscustomobject]@{ status = 'inconclusive'; leasePath = $leasePath }
}

function Get-AsyncQuotaCircuitDecision {
    param([object]$Context, [int]$TimeoutSeconds)

    [System.IO.Directory]::CreateDirectory($Context.stateDir) | Out-Null
    $now = [datetime]::UtcNow
    $variantDecisions = [System.Collections.Generic.List[object]]::new()
    $stateFiles = @(Get-ChildItem -LiteralPath $Context.stateDir -Filter "$($Context.safeBaseKey).*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.EndsWith('.state.json', [System.StringComparison]::OrdinalIgnoreCase) })

    $hadInvalid = $false
    $hadExpiredOpen = $false
    foreach ($file in $stateFiles) {
        $variant = $file.BaseName
        if ($variant.StartsWith("$($Context.safeBaseKey).", [System.StringComparison]::OrdinalIgnoreCase)) {
            $variant = $variant.Substring($Context.safeBaseKey.Length + 1)
            if ($variant.EndsWith('.state', [System.StringComparison]::OrdinalIgnoreCase)) {
                $variant = $variant.Substring(0, $variant.Length - 6)
            }
        }
        $read = Read-AsyncJsonWithDeadline -Path $file.FullName -DeadlineMs 150
        if ($read.status -eq 'read-inconclusive') {
            $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'state-read-inconclusive' })
            return [pscustomobject]@{ blocked = $true; decision = 'state-read-inconclusive'; variants = @($variantDecisions); leasePath = $null }
        }
        if ($read.status -eq 'json-invalid') {
            $hadInvalid = $true
            $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'state-json-invalid' })
            continue
        }
        if ($read.status -ne 'ok') { continue }
        $state = [string](Get-ClaudeCodeProp $read.value 'circuitState')
        if ([string]::IsNullOrWhiteSpace($state)) { $state = [string](Get-ClaudeCodeProp $read.value 'state') }
        $resetsAtUtc = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $read.value 'resetsAtUtc'))
        if ($state -eq 'open' -and $null -ne $resetsAtUtc -and $resetsAtUtc -gt $now) {
            $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'open'; resetsAtUtc = $resetsAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ') })
            return [pscustomobject]@{ blocked = $true; decision = 'open'; variants = @($variantDecisions); leasePath = $null }
        }
        if ($state -eq 'open') {
            $hadExpiredOpen = $true
            $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'expired-open' })
        }
        else {
            $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'closed' })
        }
    }

    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    $leaseRead = Read-AsyncJsonWithDeadline -Path $leasePath -DeadlineMs 150
    if ($leaseRead.status -eq 'read-inconclusive') {
        return [pscustomobject]@{ blocked = $true; decision = 'state-read-inconclusive'; variants = @($variantDecisions); leasePath = $leasePath }
    }
    if ($leaseRead.status -eq 'ok') {
        $expires = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $leaseRead.value 'probeExpiresAtUtc'))
        if ($null -ne $expires -and $expires -gt $now) {
            return [pscustomobject]@{ blocked = $true; decision = 'half-open-observed'; variants = @($variantDecisions); leasePath = $leasePath }
        }
    }

    if ($hadExpiredOpen -or $hadInvalid) {
        $lease = New-AsyncHalfOpenLease -Context $Context -TimeoutSeconds $TimeoutSeconds
        if ($lease.status -eq 'observed') {
            return [pscustomobject]@{ blocked = $true; decision = 'half-open-observed'; variants = @($variantDecisions); leasePath = $lease.leasePath }
        }
        if ($lease.status -eq 'inconclusive') {
            return [pscustomobject]@{ blocked = $true; decision = 'state-read-inconclusive'; variants = @($variantDecisions); leasePath = $lease.leasePath }
        }
        $decision = if ($hadInvalid) { 'closed-with-invalid-state-ignored' } else { 'half-open' }
        return [pscustomobject]@{ blocked = $false; decision = $decision; variants = @($variantDecisions); leasePath = $lease.leasePath }
    }

    return [pscustomobject]@{ blocked = $false; decision = 'closed'; variants = @($variantDecisions); leasePath = $leasePath }
}

function Set-AsyncQuotaCircuitOpen {
    param([object]$Context, [object]$QuotaEvidence)
    $resetsAtUtc = [string](Get-ClaudeCodeProp $QuotaEvidence 'resetsAtUtc')
    $resetUtc = Get-AsyncIsoToUtc -Text $resetsAtUtc
    if ($null -eq $resetUtc -or $resetUtc -le [datetime]::UtcNow) { return }
    $rateLimitType = [string](Get-ClaudeCodeProp $QuotaEvidence 'rateLimitType')
    if ([string]::IsNullOrWhiteSpace($rateLimitType)) { $rateLimitType = 'unknown' }
    $rateLimitType = [regex]::Replace($rateLimitType, '[^A-Za-z0-9._-]', '-')
    $statePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).$rateLimitType.state.json"
    $reportedLimitScope = Get-ClaudeCodeProp $QuotaEvidence 'reportedLimitScope'
    $reportedLimitScopeText = if ($null -eq $reportedLimitScope -or [string]::IsNullOrWhiteSpace([string]$reportedLimitScope)) { $null } else { [string]$reportedLimitScope }
    $scopeAssumed = [string]::IsNullOrWhiteSpace($reportedLimitScopeText)
    $effectiveLimitScope = if ($scopeAssumed) { 'credential-context' } else { $reportedLimitScopeText }
    $scopeAssumptionReason = if ($scopeAssumed) { 'reported-limit-scope-missing' } else { $null }
    $evidenceTypes = @(Get-ClaudeCodeProp $QuotaEvidence 'evidenceTypes')
    $observedAtUtc = [datetime]::UtcNow
    $state = [ordered]@{
        Kind                         = 'claude-code-quota-circuit-state'
        SchemaVersion                = 1
        circuitState                 = 'open'
        baseKeyHash                  = $Context.safeBaseKey
        provider                     = $Context.provider
        backend                      = $Context.backend
        model                        = $Model
        modelKey                     = $Context.modelKey
        credentialContextFingerprint = $Context.credentialFingerprint
        rateLimitType                = $rateLimitType
        reportedLimitScope           = $reportedLimitScopeText
        effectiveLimitScope          = $effectiveLimitScope
        scopeAssumed                 = $scopeAssumed
        scopeAssumptionReason        = $scopeAssumptionReason
        observedAtUtc                = $observedAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        openedAtUtc                  = $observedAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        resetsAtUtc                  = $resetUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        evidenceTypes                = $evidenceTypes
        sourceEvidence               = [ordered]@{
            source             = 'claude-code-stream-json'
            evidenceTypes      = $evidenceTypes
            terminalReason     = Get-ClaudeCodeProp $QuotaEvidence 'terminalReason'
            apiErrorStatus     = Get-ClaudeCodeProp $QuotaEvidence 'apiErrorStatus'
            rateLimitType      = $rateLimitType
            reportedLimitScope = $reportedLimitScopeText
            resetsAtUtc        = $resetUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
    }
    Write-AsyncJsonAtomic -Path $statePath -Object $state -Depth 8
}

function Close-AsyncQuotaCircuitProbe {
    param([object]$Context)
    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    try { Remove-Item -LiteralPath $leasePath -Force -ErrorAction SilentlyContinue } catch { }
    $stateFiles = @(Get-ChildItem -LiteralPath $Context.stateDir -Filter "$($Context.safeBaseKey).*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.EndsWith('.state.json', [System.StringComparison]::OrdinalIgnoreCase) })
    foreach ($file in $stateFiles) {
        $read = Read-AsyncJsonWithDeadline -Path $file.FullName -DeadlineMs 150
        if ($read.status -eq 'ok') {
            try { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}

function Get-AsyncLastResultEvent {
    param([AllowNull()] [object[]]$Events)
    $last = $null
    foreach ($ev in @($Events)) {
        if ([string](Get-ClaudeCodeProp $ev 'type') -eq 'result') { $last = $ev }
    }
    return $last
}

function Read-AsyncClaudeCodeStream {
    param([string]$StreamPath)

    $events = [System.Collections.Generic.List[object]]::new()
    $streamError = ''
    if (Test-Path -LiteralPath $StreamPath -PathType Leaf) {
        foreach ($line in @(Get-Content -LiteralPath $StreamPath -Encoding utf8 -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $ev = $line | ConvertFrom-Json
                $events.Add($ev)
                $evError = Get-ClaudeCodeStreamEventErrorText -StreamEvent $ev
                if (-not [string]::IsNullOrWhiteSpace($evError)) { $streamError = $evError }
            }
            catch {
                $streamError = 'stream-json-invalid'
            }
        }
    }
    $acceptedText = Get-ClaudeCodeStreamAcceptedTextFromEvents -StreamEvents @($events)
    $quota = Get-ClaudeCodeStreamQuotaEvidence -StreamEvents @($events)
    $lastResult = Get-AsyncLastResultEvent -Events @($events)
    $terminalReason = [string](Get-ClaudeCodeProp $lastResult 'terminal_reason')
    if ([string]::IsNullOrWhiteSpace($terminalReason)) { $terminalReason = [string](Get-ClaudeCodeProp $quota 'terminalReason') }
    $apiErrorStatus = [string](Get-ClaudeCodeProp $lastResult 'api_error_status')
    if ([string]::IsNullOrWhiteSpace($apiErrorStatus)) { $apiErrorStatus = [string](Get-ClaudeCodeProp $quota 'apiErrorStatus') }

    return [pscustomobject]@{
        events         = @($events)
        streamError    = $streamError
        acceptedText   = $acceptedText
        quota          = $quota
        lastResult     = $lastResult
        terminalReason = $terminalReason
        apiErrorStatus = $apiErrorStatus
    }
}

function New-AsyncFailureAfterText {
    param([string]$Reason, [AllowNull()] [string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $partialTextHash = $null
    if ($RetentionMode -eq 'public') { $partialTextHash = Get-AsyncSha256Text -Text $Text }
    return [ordered]@{
        reason     = $Reason
        textBytes  = [System.Text.Encoding]::UTF8.GetByteCount([string]$Text)
        textSha256 = $partialTextHash
    }
}

function New-AsyncSidecarObject {
    param(
        [string]$TechnicalStatus,
        [bool]$ResultAccepted,
        [AllowNull()] [string]$AcceptanceRejectionReason,
        [AllowNull()] $ExitCode,
        [AllowNull()] [string]$TerminalReason,
        [AllowNull()] [string]$ApiErrorStatus,
        [AllowNull()] $FailureAfterText,
        [AllowNull()] [string]$StreamPath,
        [AllowNull()] [string]$StderrPath,
        [AllowNull()] [string]$AcceptedText,
        [string]$FinalTextDisposition
    )

    $endedAtUtcValue = [datetime]::UtcNow
    $acceptedHash = $null
    $acceptedBytes = $null
    if ($ResultAccepted) {
        $acceptedHash = Get-AsyncSha256Text -Text $AcceptedText
        $acceptedBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$AcceptedText)
    }
    $streamHash = $null
    $stderrHash = $null
    if ($RetentionMode -eq 'public') {
        if ($StreamPath) { $streamHash = Get-AsyncSha256File -Path $StreamPath }
        if ($StderrPath) { $stderrHash = Get-AsyncSha256File -Path $StderrPath }
    }

    [ordered]@{
        Kind                          = 'claude-code-async-sidecar'
        SchemaVersion                 = 1
        adapterName                   = 'Invoke-ClaudeCodeAsync.ps1'
        backend                       = 'claude-code'
        model                         = $Model
        jobId                         = $script:jobId
        startedAtUtc                  = $script:startedAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        endedAtUtc                    = $endedAtUtcValue.ToString('yyyy-MM-ddTHH:mm:ssZ')
        durationMs                    = [int]($endedAtUtcValue - $script:startedAtUtc).TotalMilliseconds
        technicalStatus               = $TechnicalStatus
        resultAccepted                = $ResultAccepted
        acceptanceRejectionReason     = $AcceptanceRejectionReason
        exitCode                      = $ExitCode
        terminalReason                = $TerminalReason
        apiErrorStatus                = $ApiErrorStatus
        failureAfterText              = $FailureAfterText
        stderrSha256                  = $stderrHash
        streamSha256                  = $streamHash
        acceptedFinalTextSha256       = $acceptedHash
        acceptedFinalTextBytes        = $acceptedBytes
        finalTextDisposition          = $FinalTextDisposition
        promptTransmission            = $script:promptTransmission
        spawnAttempted                = $script:spawnAttempted
        processCreated                = $script:processCreated
        processIdentity               = $script:processIdentity
        processIdentityVerified       = $script:processIdentityVerified
        cancelRequested               = $script:cancelRequested
        cancelIssued                  = $script:cancelIssued
        cancelIdentityUnverifiable    = $script:cancelIdentityUnverifiable
        quotaEvidence                 = $script:quotaEvidence
        quotaCircuitDecision          = $script:quotaCircuitDecision
        retentionMode                 = $RetentionMode
        retentionCleanupFailed        = $script:retentionCleanupFailed
    }
}

function Complete-AsyncAdapter {
    param(
        [string]$TechnicalStatus,
        [bool]$ResultAccepted,
        [AllowNull()] [string]$AcceptanceRejectionReason,
        [AllowNull()] $ExitCode,
        [AllowNull()] [string]$TerminalReason,
        [AllowNull()] [string]$ApiErrorStatus,
        [AllowNull()] $FailureAfterText,
        [AllowNull()] [string]$StreamPath,
        [AllowNull()] [string]$StderrPath,
        [AllowNull()] [string]$AcceptedText,
        [string]$FinalTextDisposition = 'none'
    )
    $sidecar = New-AsyncSidecarObject -TechnicalStatus $TechnicalStatus -ResultAccepted $ResultAccepted `
        -AcceptanceRejectionReason $AcceptanceRejectionReason -ExitCode $ExitCode `
        -TerminalReason $TerminalReason -ApiErrorStatus $ApiErrorStatus -FailureAfterText $FailureAfterText `
        -StreamPath $StreamPath -StderrPath $StderrPath -AcceptedText $AcceptedText `
        -FinalTextDisposition $FinalTextDisposition
    Write-AsyncJsonAtomic -Path $SidecarPath -Object $sidecar -Depth 12
    if ($ResultAccepted) {
        Write-Output (([string]$AcceptedText).TrimEnd("`r", "`n"))
    }
}

if ($PSBoundParameters.ContainsKey('PermissionMode') -and $PermissionMode -eq 'bypassPermissions') {
    throw 'BLOCK: Invoke-ClaudeCodeAsync.ps1 nao permite PermissionMode=bypassPermissions.'
}

$script:jobId = [guid]::NewGuid().ToString('N')
$script:startedAtUtc = [datetime]::UtcNow
$script:promptTransmission = 'none'
$script:spawnAttempted = $false
$script:processCreated = $false
$script:processIdentity = $null
$script:processIdentityVerified = $false
$script:cancelRequested = $false
$script:cancelIssued = $false
$script:cancelIdentityUnverifiable = $false
$script:quotaEvidence = $null
$script:quotaCircuitDecision = 'closed'
$script:retentionCleanupFailed = $false

$tempRoot = if ($TempDir) { $TempDir } else { Join-Path ([System.IO.Path]::GetTempPath()) 'claude-code-async' }
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }
$inputPath = $null
$streamPath = Join-Path $tempRoot "$($script:jobId).stream.jsonl"
$stderrPath = Join-Path $tempRoot "$($script:jobId).stderr.txt"
$process = $null
$circuitContext = $null

try {
    if ($PSCmdlet.ParameterSetName -eq 'FromFile' -and -not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }

    $circuitRoot = Get-AsyncDefaultCircuitRoot
    $circuitContext = Get-AsyncCircuitContext -Root $circuitRoot -ModelName $Model
    $circuitDecision = Get-AsyncQuotaCircuitDecision -Context $circuitContext -TimeoutSeconds $TimeoutSec
    $script:quotaCircuitDecision = [string]$circuitDecision.decision
    $script:quotaEvidence = [ordered]@{
        baseKeyHash      = $circuitContext.safeBaseKey
        variantDecisions = @($circuitDecision.variants)
        leasePathPresent = -not [string]::IsNullOrWhiteSpace([string]$circuitDecision.leasePath)
    }

    if ($circuitDecision.blocked) {
        Complete-AsyncAdapter -TechnicalStatus 'quota' -ResultAccepted $false `
            -AcceptanceRejectionReason "quota-circuit-$($circuitDecision.decision)" -ExitCode $null `
            -TerminalReason $null -ApiErrorStatus $null -FailureAfterText $null `
            -StreamPath $null -StderrPath $null -AcceptedText $null -FinalTextDisposition 'none'
        exit 0
    }

    $exe = Resolve-ClaudeCodeExe -Override $ClaudeExe
    $arguments = @(
        '-p',
        '--model', $Model,
        '--output-format', 'stream-json',
        '--no-session-persistence',
        '--permission-mode', $PermissionMode
    )
    if ([string]::IsNullOrWhiteSpace($Tools)) {
        $arguments += @('--tools', '""')
    }
    else {
        $arguments += @('--tools', $Tools)
    }

    if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
        $inputPath = (Resolve-Path -LiteralPath $MessagePath).Path
    }
    else {
        $inputPath = Join-Path $tempRoot "$($script:jobId).stdin.txt"
        [System.IO.File]::WriteAllText($inputPath, $Message, [System.Text.UTF8Encoding]::new($false))
    }

    $script:spawnAttempted = $true
    $script:promptTransmission = 'stdin-file'
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $workDir `
        -NoNewWindow -PassThru -RedirectStandardOutput $streamPath -RedirectStandardError $stderrPath `
        -RedirectStandardInput $inputPath
    $script:processCreated = $true
    $realStartTimeUtc = $null
    try { $realStartTimeUtc = $process.StartTime.ToUniversalTime() } catch { $realStartTimeUtc = $null }
    $script:processIdentity = [ordered]@{
        pid          = [int]$process.Id
        startTimeUtc = if ($null -ne $realStartTimeUtc) { $realStartTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $null }
    }

    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        $script:cancelRequested = $true
        $identityVerified = $false
        if ($null -ne $realStartTimeUtc) {
            try {
                $current = Get-Process -Id $process.Id -ErrorAction Stop
                $currentStartUtc = $current.StartTime.ToUniversalTime()
                $identityVerified = ([math]::Abs(($currentStartUtc - $realStartTimeUtc).TotalMilliseconds) -lt 1000)
            }
            catch {
                $identityVerified = $false
            }
        }
        $script:processIdentityVerified = $identityVerified
        if ($identityVerified) {
            try {
                $process.Kill($true)
                $process.WaitForExit()
                $script:cancelIssued = $true
            }
            catch {
                $script:cancelIssued = $false
            }
        }
        else {
            $script:cancelIdentityUnverifiable = $true
        }
        $streamInspection = Read-AsyncClaudeCodeStream -StreamPath $streamPath
        $failureAfterText = New-AsyncFailureAfterText -Reason 'timeout-after-partial-text' -Text ([string]$streamInspection.acceptedText)
        Complete-AsyncAdapter -TechnicalStatus 'timeout' -ResultAccepted $false `
            -AcceptanceRejectionReason 'timeout' -ExitCode $null -TerminalReason $streamInspection.terminalReason `
            -ApiErrorStatus $streamInspection.apiErrorStatus -FailureAfterText $failureAfterText -StreamPath $streamPath `
            -StderrPath $stderrPath -AcceptedText $null -FinalTextDisposition 'none'
        exit 0
    }

    $stderrText = ''
    if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
        $stderrText = Get-Content -LiteralPath $stderrPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    }
    $streamInspection = Read-AsyncClaudeCodeStream -StreamPath $streamPath
    $streamError = [string]$streamInspection.streamError
    $acceptedText = [string]$streamInspection.acceptedText
    $quota = $streamInspection.quota
    $terminalReason = [string]$streamInspection.terminalReason
    $apiErrorStatus = [string]$streamInspection.apiErrorStatus

    if ($quota.isQuota) {
        $script:quotaEvidence = [ordered]@{
            baseKeyHash        = $circuitContext.safeBaseKey
            variantDecisions   = @($circuitDecision.variants)
            evidenceTypes      = @($quota.evidenceTypes)
            rateLimitType      = $quota.rateLimitType
            reportedLimitScope = $quota.reportedLimitScope
            resetsAtUtc        = $quota.resetsAtUtc
        }
        Set-AsyncQuotaCircuitOpen -Context $circuitContext -QuotaEvidence $quota
        $failureAfterText = New-AsyncFailureAfterText -Reason 'quota-after-text' -Text $acceptedText
        Complete-AsyncAdapter -TechnicalStatus 'quota' -ResultAccepted $false `
            -AcceptanceRejectionReason 'quota-signal' -ExitCode ([int]$process.ExitCode) `
            -TerminalReason $terminalReason -ApiErrorStatus $apiErrorStatus -FailureAfterText $failureAfterText `
            -StreamPath $streamPath -StderrPath $stderrPath -AcceptedText $null -FinalTextDisposition 'none'
        exit 0
    }

    if ($process.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($acceptedText)) {
        Close-AsyncQuotaCircuitProbe -Context $circuitContext
        Complete-AsyncAdapter -TechnicalStatus 'completed' -ResultAccepted $true `
            -AcceptanceRejectionReason $null -ExitCode ([int]$process.ExitCode) -TerminalReason $terminalReason `
            -ApiErrorStatus $apiErrorStatus -FailureAfterText $null -StreamPath $streamPath -StderrPath $stderrPath `
            -AcceptedText $acceptedText -FinalTextDisposition 'stdout'
        exit 0
    }

    $errMsg = Get-ClaudeCodeErrorMessage -StdoutText $streamError -StderrText $stderrText
    if ($errMsg -and $errMsg -match '(?i)\bworkspace-not-trusted\b') {
        Complete-AsyncAdapter -TechnicalStatus 'unavailable' -ResultAccepted $false `
            -AcceptanceRejectionReason 'workspace-not-trusted' -ExitCode ([int]$process.ExitCode) `
            -TerminalReason $terminalReason -ApiErrorStatus $apiErrorStatus -FailureAfterText $null `
            -StreamPath $streamPath -StderrPath $stderrPath -AcceptedText $null -FinalTextDisposition 'none'
        exit 0
    }

    $reason = if ($errMsg) { $errMsg } elseif (-not [string]::IsNullOrWhiteSpace($streamError)) { $streamError } else { 'process-exited-without-accepted-result' }
    $failureAfterText = New-AsyncFailureAfterText -Reason 'process-exit-after-partial-text' -Text $acceptedText
    Complete-AsyncAdapter -TechnicalStatus 'internalError' -ResultAccepted $false `
        -AcceptanceRejectionReason $reason -ExitCode ([int]$process.ExitCode) -TerminalReason $terminalReason `
        -ApiErrorStatus $apiErrorStatus -FailureAfterText $failureAfterText -StreamPath $streamPath -StderrPath $stderrPath `
        -AcceptedText $null -FinalTextDisposition 'none'
    exit 0
}
catch {
    $message = "adapter-internal-error: $($_.Exception.Message)"
    try {
        Complete-AsyncAdapter -TechnicalStatus 'internalError' -ResultAccepted $false `
            -AcceptanceRejectionReason $message -ExitCode $null -TerminalReason $null -ApiErrorStatus $null `
            -FailureAfterText $null -StreamPath $streamPath -StderrPath $stderrPath -AcceptedText $null `
            -FinalTextDisposition 'none'
        exit 0
    }
    catch {
        throw $message
    }
}
finally {
    if ($PSCmdlet.ParameterSetName -eq 'Inline' -and -not [string]::IsNullOrWhiteSpace($inputPath)) {
        try { Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue } catch { }
    }
}
