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
    $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
    }
    catch {
        return $null
    }
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
            if ([System.IO.File]::Exists($backup)) {
                try { [System.IO.File]::Delete($backup) } catch { }
            }
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

function Get-AsyncQuotaCircuitLockPath {
    param([object]$Context)
    return (Join-Path $Context.stateDir "$($Context.safeBaseKey).circuit.lock")
}

function Invoke-AsyncQuotaCircuitWithLock {
    param(
        [object]$Context,
        [scriptblock]$ScriptBlock,
        [int]$DeadlineMs = 250
    )

    [System.IO.Directory]::CreateDirectory($Context.stateDir) | Out-Null
    $lockPath = Get-AsyncQuotaCircuitLockPath -Context $Context
    $deadline = [datetime]::UtcNow.AddMilliseconds($DeadlineMs)
    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $lock = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            try {
                return [pscustomobject]@{
                    lockAcquired = $true
                    lockPath     = $lockPath
                    value        = (& $ScriptBlock)
                }
            }
            finally {
                $lock.Dispose()
            }
        }
        catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 25
        }
        catch [System.UnauthorizedAccessException] {
            Start-Sleep -Milliseconds 25
        }
    }

    return [pscustomobject]@{
        lockAcquired = $false
        lockPath     = $lockPath
        value        = $null
    }
}

function Test-AsyncOwnsQuotaLease {
    param([AllowNull()] $Lease, [object]$Context)

    if ($null -eq $Lease) { return $false }
    $baseKeyHash = [string](Get-ClaudeCodeProp $Lease 'baseKeyHash')
    $probeAttemptId = [string](Get-ClaudeCodeProp $Lease 'probeAttemptId')
    if ($baseKeyHash -ne $Context.safeBaseKey) { return $false }
    if ([string]::IsNullOrWhiteSpace($probeAttemptId)) { return $false }
    if ($probeAttemptId -ne $script:jobId) { return $false }

    $probeOwner = Get-ClaudeCodeProp $Lease 'probeOwner'
    $ownerJobId = [string](Get-ClaudeCodeProp $probeOwner 'jobId')
    return ([string]::IsNullOrWhiteSpace($ownerJobId) -or $ownerJobId -eq $script:jobId)
}

function New-AsyncHalfOpenLeaseUnderLock {
    param([object]$Context, [int]$TimeoutSeconds, [string]$LeasePath)

    $read = Read-AsyncJsonWithDeadline -Path $LeasePath -DeadlineMs 150
    if ($read.status -eq 'ok') {
        $expires = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $read.value 'probeExpiresAtUtc'))
        if ($null -ne $expires -and $expires -gt [datetime]::UtcNow) {
            return [pscustomobject]@{
                status         = 'observed'
                leasePath      = $LeasePath
                ownsLease      = $false
                probeAttemptId = $null
            }
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
    Write-AsyncJsonAtomic -Path $LeasePath -Object $lease -Depth 6
    return [pscustomobject]@{
        status         = 'acquired'
        leasePath      = $LeasePath
        ownsLease      = $true
        probeAttemptId = $script:jobId
    }
}

function New-AsyncHalfOpenLease {
    param([object]$Context, [int]$TimeoutSeconds)

    [System.IO.Directory]::CreateDirectory($Context.stateDir) | Out-Null
    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    $locked = Invoke-AsyncQuotaCircuitWithLock -Context $Context -ScriptBlock {
        New-AsyncHalfOpenLeaseUnderLock -Context $Context -TimeoutSeconds $TimeoutSeconds -LeasePath $leasePath
    }
    if (-not [bool]$locked.lockAcquired) {
        return [pscustomobject]@{
            status         = 'inconclusive'
            leasePath      = $leasePath
            ownsLease      = $false
            probeAttemptId = $null
        }
    }

    return $locked.value
}

function Get-AsyncQuotaCircuitDecision {
    param([object]$Context, [int]$TimeoutSeconds)

    [System.IO.Directory]::CreateDirectory($Context.stateDir) | Out-Null
    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    $locked = Invoke-AsyncQuotaCircuitWithLock -Context $Context -ScriptBlock {
        $now = [datetime]::UtcNow
        $variantDecisions = [System.Collections.Generic.List[object]]::new()
        $stateFiles = @(Get-ChildItem -LiteralPath $Context.stateDir -Filter "$($Context.safeBaseKey).*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.EndsWith('.state.json', [System.StringComparison]::OrdinalIgnoreCase) })

        $hadInvalid = $false
        $hadExpiredOpen = $false
        $hadReadInconclusive = $false
        $hadOpen = $false
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
                $hadReadInconclusive = $true
                continue
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
                $hadOpen = $true
                continue
            }
            if ($state -eq 'open') {
                $hadExpiredOpen = $true
                $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'expired-open' })
            }
            else {
                $variantDecisions.Add([ordered]@{ rateLimitType = $variant; decision = 'closed' })
            }
        }

        if ($hadReadInconclusive) {
            return [pscustomobject]@{ blocked = $true; decision = 'state-read-inconclusive'; variants = @($variantDecisions); leasePath = $null; ownsLease = $false; probeAttemptId = $null }
        }
        if ($hadOpen) {
            return [pscustomobject]@{ blocked = $true; decision = 'open'; variants = @($variantDecisions); leasePath = $null; ownsLease = $false; probeAttemptId = $null }
        }

        $leaseRead = Read-AsyncJsonWithDeadline -Path $leasePath -DeadlineMs 150
        if ($leaseRead.status -eq 'read-inconclusive') {
            return [pscustomobject]@{ blocked = $true; decision = 'state-read-inconclusive'; variants = @($variantDecisions); leasePath = $leasePath; ownsLease = $false; probeAttemptId = $null }
        }
        if ($leaseRead.status -eq 'ok') {
            $expires = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $leaseRead.value 'probeExpiresAtUtc'))
            if ($null -ne $expires -and $expires -gt $now) {
                return [pscustomobject]@{ blocked = $true; decision = 'half-open-observed'; variants = @($variantDecisions); leasePath = $leasePath; ownsLease = $false; probeAttemptId = $null }
            }
        }

        if ($hadExpiredOpen -or $hadInvalid) {
            $lease = New-AsyncHalfOpenLeaseUnderLock -Context $Context -TimeoutSeconds $TimeoutSeconds -LeasePath $leasePath
            if ($lease.status -eq 'observed') {
                return [pscustomobject]@{ blocked = $true; decision = 'half-open-observed'; variants = @($variantDecisions); leasePath = $lease.leasePath; ownsLease = $false; probeAttemptId = $null }
            }
            $decision = if ($hadInvalid) { 'closed-with-invalid-state-ignored' } else { 'half-open' }
            return [pscustomobject]@{ blocked = $false; decision = $decision; variants = @($variantDecisions); leasePath = $lease.leasePath; ownsLease = $lease.ownsLease; probeAttemptId = $lease.probeAttemptId }
        }

        return [pscustomobject]@{ blocked = $false; decision = 'closed'; variants = @($variantDecisions); leasePath = $leasePath; ownsLease = $false; probeAttemptId = $null }
    }

    if (-not [bool]$locked.lockAcquired) {
        return [pscustomobject]@{
            blocked        = $true
            decision       = 'state-read-inconclusive'
            variants       = @([ordered]@{ rateLimitType = 'base-key'; decision = 'state-read-inconclusive'; evidence = 'circuit-lock-timeout' })
            leasePath      = $leasePath
            ownsLease      = $false
            probeAttemptId = $null
        }
    }

    return $locked.value
}

function Set-AsyncQuotaCircuitOpen {
    param([object]$Context, [object]$QuotaEvidence)
    $resetsAtUtc = [string](Get-ClaudeCodeProp $QuotaEvidence 'resetsAtUtc')
    $resetUtc = Get-AsyncIsoToUtc -Text $resetsAtUtc
    if ($null -eq $resetUtc -or $resetUtc -le [datetime]::UtcNow) {
        return [pscustomobject]@{ status = 'state-not-written'; statePath = $null; reason = 'reset-not-in-future'; leaseRemoved = $false }
    }
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

    $locked = Invoke-AsyncQuotaCircuitWithLock -Context $Context -ScriptBlock {
        $observedAtUtc = [datetime]::UtcNow
        $existingHitCount = 0
        $existingState = Read-AsyncJsonWithDeadline -Path $statePath -DeadlineMs 150
        if ($existingState.status -eq 'ok') {
            $existingHitCountValue = Get-ClaudeCodeProp $existingState.value 'hitCount'
            if ($null -ne $existingHitCountValue) {
                [void][int]::TryParse([string]$existingHitCountValue, [ref]$existingHitCount)
            }
        }

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
            lastHitAtUtc                 = $observedAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
            hitCount                     = ($existingHitCount + 1)
            updatedAtUtc                 = $observedAtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
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

        $leaseRemoved = $false
        if ($script:quotaCircuitLeaseOwned) {
            $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
            $leaseRead = Read-AsyncJsonWithDeadline -Path $leasePath -DeadlineMs 150
            if ($leaseRead.status -eq 'ok' -and (Test-AsyncOwnsQuotaLease -Lease $leaseRead.value -Context $Context)) {
                try {
                    Remove-Item -LiteralPath $leasePath -Force -ErrorAction Stop
                    $leaseRemoved = $true
                }
                catch {
                    $leaseRemoved = $false
                }
            }
        }

        return [pscustomobject]@{ status = 'open-written'; statePath = $statePath; reason = $null; leaseRemoved = $leaseRemoved }
    }

    if (-not [bool]$locked.lockAcquired) {
        return [pscustomobject]@{ status = 'state-write-inconclusive'; statePath = $statePath; reason = 'circuit-lock-timeout'; leaseRemoved = $false }
    }

    return $locked.value
}

function Test-AsyncQuotaStateNewerThanAttempt {
    param([AllowNull()] $State)

    foreach ($field in @('updatedAtUtc', 'observedAtUtc', 'openedAtUtc')) {
        $stateTime = Get-AsyncIsoToUtc -Text ([string](Get-ClaudeCodeProp $State $field))
        if ($null -ne $stateTime -and $stateTime -gt $script:startedAtUtc) {
            return $true
        }
    }
    return $false
}

function Close-AsyncQuotaCircuitProbe {
    param([object]$Context)

    if (-not $script:quotaCircuitLeaseOwned) {
        return [pscustomobject]@{ status = 'not-owned'; removedLease = $false; removedStates = 0 }
    }

    $leasePath = Join-Path $Context.stateDir "$($Context.safeBaseKey).lease.json"
    $locked = Invoke-AsyncQuotaCircuitWithLock -Context $Context -ScriptBlock {
        $leaseRead = Read-AsyncJsonWithDeadline -Path $leasePath -DeadlineMs 150
        if ($leaseRead.status -ne 'ok' -or -not (Test-AsyncOwnsQuotaLease -Lease $leaseRead.value -Context $Context)) {
            return [pscustomobject]@{ status = 'lease-not-owned'; removedLease = $false; removedStates = 0 }
        }

        $removedLease = $false
        try {
            Remove-Item -LiteralPath $leasePath -Force -ErrorAction Stop
            $removedLease = $true
        }
        catch {
            return [pscustomobject]@{ status = 'lease-remove-failed'; removedLease = $false; removedStates = 0 }
        }

        $removedStates = 0
        $stateFiles = @(Get-ChildItem -LiteralPath $Context.stateDir -Filter "$($Context.safeBaseKey).*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.EndsWith('.state.json', [System.StringComparison]::OrdinalIgnoreCase) })
        foreach ($file in $stateFiles) {
            $read = Read-AsyncJsonWithDeadline -Path $file.FullName -DeadlineMs 150
            if ($read.status -eq 'ok' -and -not (Test-AsyncQuotaStateNewerThanAttempt -State $read.value)) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $removedStates++
                }
                catch { }
            }
        }

        return [pscustomobject]@{ status = 'closed'; removedLease = $removedLease; removedStates = $removedStates }
    }

    if (-not [bool]$locked.lockAcquired) {
        return [pscustomobject]@{ status = 'close-inconclusive'; removedLease = $false; removedStates = 0 }
    }

    return $locked.value
}

function Get-AsyncLastResultEvent {
    param([AllowNull()] [object[]]$Events)
    $last = $null
    foreach ($ev in @($Events)) {
        if ([string](Get-ClaudeCodeProp $ev 'type') -eq 'result') { $last = $ev }
    }
    return $last
}

function Test-AsyncTerminalResultAccepted {
    param([AllowNull()] $ResultEvent)

    if ($null -eq $ResultEvent) { return $false }
    if ([string](Get-ClaudeCodeProp $ResultEvent 'type') -ne 'result') { return $false }
    if ([string](Get-ClaudeCodeProp $ResultEvent 'subtype') -ne 'success') { return $false }

    $isError = Get-ClaudeCodeProp $ResultEvent 'is_error'
    if ($null -eq $isError) { return $false }
    if ($isError -is [bool]) { return (-not [bool]$isError) }
    return ([string]$isError -ieq 'false')
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
        terminalSuccess = (Test-AsyncTerminalResultAccepted -ResultEvent $lastResult)
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

function ConvertTo-AsyncStdoutFinalText {
    param([AllowNull()] [string]$Text)
    return ([string]$Text).TrimEnd("`r", "`n")
}

function Remove-AsyncSensitiveRawCaptureFiles {
    param(
        [AllowNull()] [string]$StreamPath,
        [AllowNull()] [string]$StderrPath
    )

    if ($RetentionMode -ne 'kb-sensitive') { return }

    foreach ($rawPath in @($StreamPath, $StderrPath)) {
        if ([string]::IsNullOrWhiteSpace([string]$rawPath)) { continue }
        if (-not (Test-Path -LiteralPath ([string]$rawPath) -PathType Leaf)) { continue }
        if ($env:XPZ_TEST_CLAUDE_ASYNC_FORCE_RETENTION_CLEANUP_FAIL -eq '1') {
            $script:retentionCleanupFailed = $true
            continue
        }

        $removed = $false
        for ($attempt = 0; $attempt -lt 3 -and -not $removed; $attempt++) {
            try {
                Remove-Item -LiteralPath ([string]$rawPath) -Force -ErrorAction Stop
                $removed = $true
            } catch {
                if ($attempt -lt 2) { Start-Sleep -Milliseconds 50 }
            }
        }

        if (-not $removed -and (Test-Path -LiteralPath ([string]$rawPath) -PathType Leaf)) {
            $script:retentionCleanupFailed = $true
        }
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
        $stdoutAcceptedText = ConvertTo-AsyncStdoutFinalText -Text $AcceptedText
        $acceptedHash = Get-AsyncSha256Text -Text $stdoutAcceptedText
        $acceptedBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$stdoutAcceptedText)
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
    $stdoutAcceptedText = $null
    if ($ResultAccepted) {
        $stdoutAcceptedText = ConvertTo-AsyncStdoutFinalText -Text $AcceptedText
    }
    Remove-AsyncSensitiveRawCaptureFiles -StreamPath $StreamPath -StderrPath $StderrPath
    if ($RetentionMode -eq 'kb-sensitive' -and $ResultAccepted -and $script:retentionCleanupFailed) {
        $FailureAfterText = New-AsyncFailureAfterText -Reason 'retention-cleanup-after-accepted-text' -Text $stdoutAcceptedText
        $TechnicalStatus = 'internalError'
        $ResultAccepted = $false
        $AcceptanceRejectionReason = 'retention-cleanup-failed'
        $FinalTextDisposition = 'none'
        $stdoutAcceptedText = $null
    }
    $sidecar = New-AsyncSidecarObject -TechnicalStatus $TechnicalStatus -ResultAccepted $ResultAccepted `
        -AcceptanceRejectionReason $AcceptanceRejectionReason -ExitCode $ExitCode `
        -TerminalReason $TerminalReason -ApiErrorStatus $ApiErrorStatus -FailureAfterText $FailureAfterText `
        -StreamPath $StreamPath -StderrPath $StderrPath -AcceptedText $stdoutAcceptedText `
        -FinalTextDisposition $FinalTextDisposition
    Write-AsyncJsonAtomic -Path $SidecarPath -Object $sidecar -Depth 12
    if ($ResultAccepted) {
        Write-Output $stdoutAcceptedText
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
$script:quotaCircuitLeaseOwned = $false
$script:quotaCircuitProbeAttemptId = $null
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
    $ownsLeaseValue = Get-ClaudeCodeProp $circuitDecision 'ownsLease'
    $script:quotaCircuitLeaseOwned = ($ownsLeaseValue -eq $true -or [string]$ownsLeaseValue -ieq 'true')
    $script:quotaCircuitProbeAttemptId = Get-ClaudeCodeProp $circuitDecision 'probeAttemptId'
    $script:quotaEvidence = [ordered]@{
        baseKeyHash              = $circuitContext.safeBaseKey
        variantDecisions         = @($circuitDecision.variants)
        leasePathPresent         = -not [string]::IsNullOrWhiteSpace([string]$circuitDecision.leasePath)
        quotaCircuitLeaseOwned   = $script:quotaCircuitLeaseOwned
        quotaCircuitProbeAttemptId = $script:quotaCircuitProbeAttemptId
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
        if ($env:XPZ_TEST_CLAUDE_ASYNC_FORCE_IDENTITY_UNVERIFIABLE -eq '1') {
            $identityVerified = $false
            $script:processIdentityVerified = $false
        }
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
            baseKeyHash              = $circuitContext.safeBaseKey
            variantDecisions         = @($circuitDecision.variants)
            quotaCircuitLeaseOwned   = $script:quotaCircuitLeaseOwned
            quotaCircuitProbeAttemptId = $script:quotaCircuitProbeAttemptId
            evidenceTypes            = @($quota.evidenceTypes)
            rateLimitType            = $quota.rateLimitType
            reportedLimitScope       = $quota.reportedLimitScope
            resetsAtUtc              = $quota.resetsAtUtc
        }
        $stateWrite = Set-AsyncQuotaCircuitOpen -Context $circuitContext -QuotaEvidence $quota
        $script:quotaEvidence['quotaCircuitStateWriteStatus'] = [string](Get-ClaudeCodeProp $stateWrite 'status')
        $script:quotaEvidence['quotaCircuitLeaseRemoved'] = Get-ClaudeCodeProp $stateWrite 'leaseRemoved'
        $failureAfterText = New-AsyncFailureAfterText -Reason 'quota-after-text' -Text $acceptedText
        Complete-AsyncAdapter -TechnicalStatus 'quota' -ResultAccepted $false `
            -AcceptanceRejectionReason 'quota-signal' -ExitCode ([int]$process.ExitCode) `
            -TerminalReason $terminalReason -ApiErrorStatus $apiErrorStatus -FailureAfterText $failureAfterText `
            -StreamPath $streamPath -StderrPath $stderrPath -AcceptedText $null -FinalTextDisposition 'none'
        exit 0
    }

    if ($process.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($acceptedText) -and [bool]$streamInspection.terminalSuccess) {
        if ($script:quotaCircuitLeaseOwned) {
            [void](Close-AsyncQuotaCircuitProbe -Context $circuitContext)
        }
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
