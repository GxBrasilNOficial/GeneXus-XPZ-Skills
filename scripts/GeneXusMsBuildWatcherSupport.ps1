#requires -Version 7.4
Set-StrictMode -Version Latest

function New-GeneXusMsBuildWatcherContext {
    param([bool]$StartWatcherRequested)

    return [ordered]@{
        startWatcherRequested = $StartWatcherRequested
        watcherLaunched       = $false
        watcherPid            = $null
        watcherMonitorLogPath = $null
        watcherScriptPath     = $null
        watcherLaunchError    = $null
    }
}

function Test-GeneXusMsBuildWatcherParameters {
    param(
        [bool]$StartWatcherRequested,
        [string]$MonitorLogPath
    )

    if ($StartWatcherRequested -and [string]::IsNullOrWhiteSpace($MonitorLogPath)) {
        return [ordered]@{
            ok       = $false
            causeId  = 'watcher-sem-monitor-log'
            reason   = '-StartWatcher requer -MonitorLogPath. Forneca o caminho do log do monitor para que watcher e execucao MSBuild possam ser conectados.'
            summary  = '-StartWatcher requer -MonitorLogPath. Execute novamente informando -MonitorLogPath com o caminho do log do monitor.'
        }
    }

    return [ordered]@{
        ok       = $true
        causeId  = $null
        reason   = $null
        summary  = $null
    }
}

function Add-GeneXusMsBuildWatcherWarning {
    param([string]$Message)

    if (Get-Command -Name Add-WarningMessage -ErrorAction SilentlyContinue) {
        Add-WarningMessage -Message $Message
        return
    }

    Write-Warning $Message
}

function Add-GeneXusMsBuildWatcherTrace {
    param([string]$Message)

    if (Get-Command -Name Add-StrategyTrace -ErrorAction SilentlyContinue) {
        Add-StrategyTrace -Message $Message
    }
}

function ConvertTo-GeneXusMsBuildWatcherProcessArgument {
    param([string]$Value)

    return '"{0}"' -f ($Value -replace '"', '\"')
}

function Start-GeneXusMsBuildWatcherProcess {
    param(
        [System.Collections.Specialized.OrderedDictionary]$WatcherContext,
        [string]$ScriptsDirectory,
        [string]$LogFilePath,
        [string]$MonitorLogFilePath,
        [int]$IntervalSeconds,
        [int]$SilenceThresholdSeconds
    )

    $watcherScript = Join-Path $ScriptsDirectory 'Watch-GeneXusMsBuildLog.ps1'
    $WatcherContext['watcherScriptPath'] = $watcherScript
    $WatcherContext['watcherMonitorLogPath'] = $MonitorLogFilePath

    if (-not (Test-Path -LiteralPath $watcherScript -PathType Leaf)) {
        Add-GeneXusMsBuildWatcherWarning -Message ('Watch-GeneXusMsBuildLog.ps1 nao localizado em: {0}. Watcher nao iniciado.' -f $watcherScript)
        $WatcherContext['watcherLaunchError'] = 'script nao localizado'
        return
    }

    try {
        $watchArgs = @(
            '-NoExit', '-NoProfile',
            '-File', (ConvertTo-GeneXusMsBuildWatcherProcessArgument -Value $watcherScript),
            '-ProcessId', $PID,
            '-LogPath', (ConvertTo-GeneXusMsBuildWatcherProcessArgument -Value $LogFilePath),
            '-MonitorLog', (ConvertTo-GeneXusMsBuildWatcherProcessArgument -Value $MonitorLogFilePath),
            '-IntervalSeconds', $IntervalSeconds,
            '-SilenceThresholdSeconds', $SilenceThresholdSeconds
        )
        $watchProc = Start-Process pwsh -ArgumentList $watchArgs -PassThru
        $WatcherContext['watcherLaunched'] = $true
        $WatcherContext['watcherPid'] = $watchProc.Id
        Add-GeneXusMsBuildWatcherTrace -Message ('Watcher iniciado automaticamente: PID={0}, script={1}' -f $watchProc.Id, $watcherScript)
    } catch {
        Add-GeneXusMsBuildWatcherWarning -Message ('Falha ao iniciar watcher: {0}. Execucao MSBuild prossegue sem watcher.' -f $_.Exception.Message)
        $WatcherContext['watcherLaunchError'] = $_.Exception.Message
    }
}

function Get-GeneXusMsBuildNowIso {
    return [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Get-GeneXusMsBuildDurationSeconds {
    param([string]$StartIso, [string]$EndIso)

    if ([string]::IsNullOrWhiteSpace($StartIso) -or [string]::IsNullOrWhiteSpace($EndIso)) {
        return $null
    }

    return [int]([DateTime]::Parse($EndIso) - [DateTime]::Parse($StartIso)).TotalSeconds
}

function Wait-GeneXusMsBuildWatcherDrain {
    param(
        [string]$MonitorLogPath,
        [int]$Seconds = 6
    )

    if (-not [string]::IsNullOrWhiteSpace($MonitorLogPath)) {
        Start-Sleep -Seconds $Seconds
    }
}

function Get-GeneXusMsBuildWatcherPhaseTimings {
    param([string]$MonitorLogPath)

    if ([string]::IsNullOrWhiteSpace($MonitorLogPath) -or
        -not (Test-Path -LiteralPath $MonitorLogPath -PathType Leaf)) {
        return @()
    }

    try {
        $lines = [System.Collections.Generic.List[string]]::new()
        $fs = [System.IO.FileStream]::new(
            $MonitorLogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        try {
            $line = $reader.ReadLine()
            while ($null -ne $line) {
                [void]$lines.Add($line)
                $line = $reader.ReadLine()
            }
        } finally {
            $reader.Dispose()
            $fs.Dispose()
        }

        $starts = [ordered]@{}
        $phases = [System.Collections.ArrayList]::new()

        foreach ($line in $lines) {
            if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+={3,}\s+(.+?)\s+(iniciado|terminado)\s+={3,}') {
                $ts = $Matches[1]
                $rawName = $Matches[2].Trim()
                $normName = $rawName -replace '\s+', ''
                $state = $Matches[3]
                if ($state -eq 'iniciado') {
                    $starts[$normName] = @{ ts = $ts; rawName = $rawName }
                } elseif ($state -eq 'terminado' -and $starts.Contains($normName)) {
                    [void]$phases.Add([ordered]@{
                        name            = $rawName
                        start           = $starts[$normName].ts
                        end             = $ts
                        durationSeconds = Get-GeneXusMsBuildDurationSeconds -StartIso $starts[$normName].ts -EndIso $ts
                    })
                    $starts.Remove($normName)
                }
            }
        }

        return @($phases)
    } catch {
        Add-GeneXusMsBuildWatcherWarning -Message ('Get-GeneXusMsBuildWatcherPhaseTimings falhou: {0}' -f $_.Exception.Message)
        return @()
    }
}

function Get-GeneXusMsBuildTimingSection {
    param(
        [System.Collections.Specialized.OrderedDictionary]$TimingLog,
        [string]$MonitorLogPath
    )

    $scriptEnd = Get-GeneXusMsBuildNowIso
    Wait-GeneXusMsBuildWatcherDrain -MonitorLogPath $MonitorLogPath

    return [ordered]@{
        scriptStart            = $TimingLog['scriptStart']
        probeStart             = $TimingLog['probeStart']
        probeEnd               = $TimingLog['probeEnd']
        probeDurationSeconds   = Get-GeneXusMsBuildDurationSeconds -StartIso $TimingLog['probeStart'] -EndIso $TimingLog['probeEnd']
        msbuildStart           = $TimingLog['msbuildStart']
        msbuildEnd             = $TimingLog['msbuildEnd']
        msbuildDurationSeconds = Get-GeneXusMsBuildDurationSeconds -StartIso $TimingLog['msbuildStart'] -EndIso $TimingLog['msbuildEnd']
        scriptEnd              = $scriptEnd
        totalDurationSeconds   = Get-GeneXusMsBuildDurationSeconds -StartIso $TimingLog['scriptStart'] -EndIso $scriptEnd
        phases                 = @(Get-GeneXusMsBuildWatcherPhaseTimings -MonitorLogPath $MonitorLogPath)
    }
}
