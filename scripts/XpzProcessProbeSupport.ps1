<#
.SYNOPSIS
    Inicia um processo de sonda, captura as duas saidas e classifica seu termino.

.DESCRIPTION
    Biblioteca compatível com Windows PowerShell 5.1 para gates que precisam
    localizar e consultar outro runtime antes de exigir PowerShell 7.4+. Não
    valida o conteudo da versao: cada consumidor aplica seu proprio contrato.
#>

function ConvertTo-XpzWindowsCommandLineArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append([char]34)
    $backslashCount = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashCount++
            continue
        }

        if ($character -eq [char]34) {
            if ($backslashCount -gt 0) {
                [void]$builder.Append([char]92, (2 * $backslashCount))
            }
            [void]$builder.Append([char]92)
            [void]$builder.Append([char]34)
        } else {
            if ($backslashCount -gt 0) {
                [void]$builder.Append([char]92, $backslashCount)
            }
            [void]$builder.Append($character)
        }
        $backslashCount = 0
    }

    if ($backslashCount -gt 0) {
        [void]$builder.Append([char]92, (2 * $backslashCount))
    }
    [void]$builder.Append([char]34)
    return $builder.ToString()
}

function Invoke-XpzProcessProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [AllowEmptyCollection()]
        [string[]]$ArgumentList = @(),

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 8000
    )

    $result = [pscustomobject]@{
        Started        = $false
        Completed      = $false
        TimedOut       = $false
        ExitCode       = $null
        StandardOutput = ''
        StandardError  = ''
        Output         = ''
        Succeeded      = $false
        FailureKind    = 'startFailed'
        Error          = $null
    }

    $process = $null
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        $extension = [System.IO.Path]::GetExtension($FilePath)
        if ($extension -match '^\.(cmd|bat)$') {
            $commandProcessor = $env:ComSpec
            if ([string]::IsNullOrWhiteSpace($commandProcessor)) {
                $commandProcessor = Join-Path $env:SystemRoot 'System32\cmd.exe'
            }
            $startInfo.FileName = $commandProcessor
            $commandParts = @('"{0}"' -f $FilePath)
            foreach ($argument in @($ArgumentList)) {
                $commandParts += ConvertTo-XpzWindowsCommandLineArgument -Argument ([string]$argument)
            }
            $startInfo.Arguments = '/d /c ' + ($commandParts -join ' ')
        } else {
            $startInfo.FileName = $FilePath
            $quotedArguments = @(
                foreach ($argument in @($ArgumentList)) {
                    ConvertTo-XpzWindowsCommandLineArgument -Argument ([string]$argument)
                }
            )
            $startInfo.Arguments = $quotedArguments -join ' '
        }

        $process = [System.Diagnostics.Process]::Start($startInfo)
        if ($null -eq $process) {
            $result.Error = 'Process.Start nao retornou um processo.'
            return $result
        }
        $result.Started = $true

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMs)) {
            try {
                $process.Kill($true)
            } catch {
                try { $process.Kill() } catch { }
            }
            try { [void]$process.WaitForExit(5000) } catch { }

            $result.TimedOut = $true
            $result.FailureKind = 'timeout'
            $result.Error = "Processo excedeu o timeout de $TimeoutMs ms."
            if ($stdoutTask.IsCompleted) {
                try { $result.StandardOutput = $stdoutTask.GetAwaiter().GetResult() } catch { }
            }
            if ($stderrTask.IsCompleted) {
                try { $result.StandardError = $stderrTask.GetAwaiter().GetResult() } catch { }
            }
        } else {
            $result.Completed = $true
            $result.ExitCode = $process.ExitCode
            $result.StandardOutput = $stdoutTask.GetAwaiter().GetResult()
            $result.StandardError = $stderrTask.GetAwaiter().GetResult()
            if ($result.ExitCode -eq 0) {
                $result.Succeeded = $true
                $result.FailureKind = $null
            } else {
                $result.FailureKind = 'nonZeroExit'
                $result.Error = "Processo terminou com exit code $($result.ExitCode)."
            }
        }

        if (-not [string]::IsNullOrEmpty($result.StandardOutput)) {
            $result.Output = $result.StandardOutput
        }
        if (-not [string]::IsNullOrEmpty($result.StandardError)) {
            if (-not [string]::IsNullOrEmpty($result.Output)) {
                $result.Output += [Environment]::NewLine
            }
            $result.Output += $result.StandardError
        }
        return $result
    } catch {
        $result.Error = $_.Exception.Message
        if ($result.Started) {
            $result.FailureKind = 'probeFailed'
        }
        return $result
    } finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}
