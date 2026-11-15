#requires -Version 7.4

<#
.SYNOPSIS
    Self-test offline do launcher, cofre DPAPI, descritor e escrita transacional.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$script:SelfTestPwshPath = (Get-Command pwsh).Source
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVaultSupport.ps1')
. (Join-Path $scriptDir 'McpLauncherSupport.ps1')
. (Join-Path $scriptDir 'McpVendorSupport.ps1')

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-launcher-selftest-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$originalLeak = $env:SECRET_LEAK
$originalPath = $env:PATH
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$env:SECRET_LEAK = 'must-not-leak'
$baseUrl = 'https://api.commandcode.ai/provider/v1/systemone'
$model = 'typesafe/jev'
$secret = 'test-secret-launcher'
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

function Assert-ThrowsLike {
    param([scriptblock]$Action, [string]$Pattern, [string]$Message)
    $script:assertCount++
    try {
        & $Action
        $script:failures.Add("$Message (nao lancou)") | Out-Null
    } catch {
        if ($_.Exception.Message -notmatch $Pattern) {
            $script:failures.Add("$Message (mensagem: $($_.Exception.Message))") | Out-Null
        }
    }
}

function Start-LauncherProcess {
    param([string]$LauncherPath)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command pwsh).Source
    $psi.Arguments = '-NoProfile -File "' + $LauncherPath + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ ExitCode = $exitCode; Stdout = $stdout; Stderr = $stderr }
}

function Invoke-RuntimeGateSyntheticCase {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$OutputText,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$ShimPath,
        [switch]$MissingShim
    )

    if (-not $MissingShim) {
        $lineBreak = [Environment]::NewLine
        $shimText = '@echo off' + $lineBreak + 'echo ' + $OutputText + $lineBreak + 'exit /b ' + $ExitCode + $lineBreak
        [System.IO.File]::WriteAllText($ShimPath, $shimText, [System.Text.UTF8Encoding]::new($false))
    }

    $runtimePath = Join-Path $script:scriptDir 'Test-XpzPowerShellRuntime.ps1'
    $childTemplate = @'
function global:Get-Command {
    param([string]$Name, [string]$ErrorAction)
    if ($Name -eq 'pwsh') { return [pscustomobject]@{ Source = $env:XPZ_TEST_PWSH_SHIM } }
    return Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
}
& '__RUNTIME_PATH__' -MinimumVersion ([version]'7.4')
'@
    $childCommand = $childTemplate.Replace('__RUNTIME_PATH__', $runtimePath.Replace("'", "''"))
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childCommand))

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:SelfTestPwshPath
    [void]$startInfo.ArgumentList.Add('-NoProfile')
    [void]$startInfo.ArgumentList.Add('-EncodedCommand')
    [void]$startInfo.ArgumentList.Add($encodedCommand)
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.EnvironmentVariables['XPZ_TEST_PWSH_SHIM'] = $ShimPath

    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            [void]$process.WaitForExit(5000)
            return [pscustomobject]@{ ExitCode = $null; TimedOut = $true; Stdout = ''; Stderr = '' }
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            TimedOut = $false
            Stdout   = $stdoutTask.GetAwaiter().GetResult()
            Stderr   = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

try {
    # 1. Sonda compartilhada e classificacao de versoes.
    $realPwsh = Invoke-XpzProcessProbe -FilePath $script:SelfTestPwshPath -ArgumentList @(
        '-NoProfile', '-Command', "[Console]::Out.Write('probe-out'); [Console]::Error.Write('probe-err')"
    ) -TimeoutMs 5000
    Assert-True ($realPwsh.Started -and $realPwsh.Completed -and $realPwsh.Succeeded -and $realPwsh.StandardOutput -eq 'probe-out' -and $realPwsh.StandardError -eq 'probe-err') '(probe) captura stdout/stderr com exit 0'

    $nonzeroProbe = Invoke-XpzProcessProbe -FilePath $script:SelfTestPwshPath -ArgumentList @(
        '-NoProfile', '-Command', "Write-Output '7.4.0'; exit 7"
    ) -TimeoutMs 5000
    Assert-True ($nonzeroProbe.Started -and $nonzeroProbe.Completed -and $nonzeroProbe.ExitCode -eq 7 -and -not $nonzeroProbe.Succeeded) '(probe) exit nao zero nao e sucesso'

    $missingProbe = Invoke-XpzProcessProbe -FilePath (Join-Path $tempRoot 'missing-probe.exe') -TimeoutMs 1000
    Assert-True ((-not $missingProbe.Started) -and $missingProbe.FailureKind -eq 'startFailed') '(probe) falha ao iniciar classificada'

    $timeoutProbe = Invoke-XpzProcessProbe -FilePath $script:SelfTestPwshPath -ArgumentList @(
        '-NoProfile', '-Command', 'Start-Sleep -Seconds 10'
    ) -TimeoutMs 300
    Assert-True ($timeoutProbe.Started -and $timeoutProbe.TimedOut -and -not $timeoutProbe.Succeeded) '(probe) timeout classificado e processo encerrado'

    $versionCases = @(
        [pscustomobject]@{ Name = 'pwsh'; Text = '7.4.0'; Valid = $true },
        [pscustomobject]@{ Name = 'node'; Text = 'v24.18.0'; Valid = $true },
        [pscustomobject]@{ Name = 'npm'; Text = '11.18.0'; Valid = $true },
        [pscustomobject]@{ Name = 'python'; Text = 'Python 3.14.2'; Valid = $true },
        [pscustomobject]@{ Name = 'py'; Text = 'Python 3.14.2'; Valid = $true },
        [pscustomobject]@{ Name = 'nvm'; Text = '1.2.2'; Valid = $true },
        [pscustomobject]@{ Name = 'fnm'; Text = 'fnm 1.38.1'; Valid = $true },
        [pscustomobject]@{ Name = 'volta'; Text = '2.0.2'; Valid = $true },
        [pscustomobject]@{ Name = 'winget'; Text = 'v1.12.4601'; Valid = $true },
        [pscustomobject]@{ Name = 'opencode'; Text = 'opencode v2.2.7'; Valid = $true },
        [pscustomobject]@{ Name = 'codex'; Text = 'codex-cli 0.167.0-alpha.3.2'; Valid = $true },
        [pscustomobject]@{ Name = 'node'; Text = 'failed while checking version 24.18.0'; Valid = $false }
    )
    foreach ($versionCase in $versionCases) {
        $isValid = Test-McpCommandVersionOutput -Name $versionCase.Name -Text $versionCase.Text
        Assert-True ($isValid -eq $versionCase.Valid) "(version-format) $($versionCase.Name): '$($versionCase.Text)'"
    }

    $probeDirectory = Join-Path $tempRoot 'command probes'
    [System.IO.Directory]::CreateDirectory($probeDirectory) | Out-Null
    $nodeProbePath = Join-Path $probeDirectory 'node.cmd'
    $lineBreak = [Environment]::NewLine
    $env:PATH = $probeDirectory
    [System.IO.File]::WriteAllText($nodeProbePath, ('@echo off' + $lineBreak + 'echo v24.18.0' + $lineBreak + 'exit /b 7' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $nodeExit7 = Get-McpCommandInfo -Name 'node' -VersionArguments @('--version')
    Assert-True (-not $nodeExit7.Present) '(probe) versao valida com exit 7 rejeitada'

    [System.IO.File]::WriteAllText($nodeProbePath, ('@echo off' + $lineBreak + 'echo v24.18.0' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $nodeValid = Get-McpCommandInfo -Name 'node' -VersionArguments @('--version')
    Assert-True ($nodeValid.Present -and $nodeValid.Version -eq 'v24.18.0') '(probe) versao valida com exit 0 aceita'

    [System.IO.File]::WriteAllText($nodeProbePath, ('@echo off' + $lineBreak + 'echo not-a-version' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $nodeInvalid = Get-McpCommandInfo -Name 'node' -VersionArguments @('--version')
    Assert-True (-not $nodeInvalid.Present) '(probe) exit 0 sem versao valida rejeitado'

    $pythonProbePath = Join-Path $probeDirectory 'python.cmd'
    [System.IO.File]::WriteAllText($pythonProbePath, ('@echo off' + $lineBreak + 'echo Python 3.14.2 1>&2' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $pythonValid = Get-McpCommandInfo -Name 'python' -VersionArguments @('--version')
    Assert-True ($pythonValid.Present -and $pythonValid.Version -match 'Python 3\.14\.2') '(probe) versao Python em stderr aceita apos exit 0'
    $env:PATH = $originalPath

    # Runtime minimo: 7.3.9 bloqueia; 7.4.0 e 7.4.1 passam somente com exit 0.
    $runtimeShim = Join-Path $tempRoot 'runtime probe\pwsh.cmd'
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $runtimeShim)) | Out-Null
    $runtime739 = Invoke-RuntimeGateSyntheticCase -OutputText '7.3.9' -ExitCode 0 -ShimPath $runtimeShim
    Assert-True ($runtime739.ExitCode -eq 1 -and $runtime739.Stdout -match 'BLOCK:') '(runtime) 7.3.9 bloqueado'
    $runtime740 = Invoke-RuntimeGateSyntheticCase -OutputText '7.4.0' -ExitCode 0 -ShimPath $runtimeShim
    Assert-True ($runtime740.ExitCode -eq 0 -and $runtime740.Stdout -match 'POWERSHELL_RUNTIME_OK') '(runtime) 7.4.0 aceito'
    $runtime741 = Invoke-RuntimeGateSyntheticCase -OutputText '7.4.1' -ExitCode 0 -ShimPath $runtimeShim
    Assert-True ($runtime741.ExitCode -eq 0 -and $runtime741.Stdout -match 'POWERSHELL_RUNTIME_OK') '(runtime) 7.4.1 aceito'
    $runtimeExit7 = Invoke-RuntimeGateSyntheticCase -OutputText '7.4.0' -ExitCode 7 -ShimPath $runtimeShim
    Assert-True ($runtimeExit7.ExitCode -eq 1 -and $runtimeExit7.Stdout -match 'BLOCK:') '(runtime) versao impressa com exit 7 bloqueada'
    $runtimeInvalid = Invoke-RuntimeGateSyntheticCase -OutputText 'not-a-version' -ExitCode 0 -ShimPath $runtimeShim
    Assert-True ($runtimeInvalid.ExitCode -eq 1 -and $runtimeInvalid.Stdout -match 'BLOCK:') '(runtime) saida sem versao valida bloqueada'
    $runtimeStartFailure = Invoke-RuntimeGateSyntheticCase -OutputText '' -ExitCode 0 -ShimPath (Join-Path $tempRoot 'missing-runtime\pwsh.cmd') -MissingShim
    Assert-True ($runtimeStartFailure.ExitCode -eq 1 -and $runtimeStartFailure.Stdout -match 'BLOCK:') '(runtime) falha ao iniciar continua bloqueada'

    # 2. Descritor e pin.
    $descriptor = Get-McpDescriptor
    Assert-True ([string]$descriptor.Descriptor.component.version -eq '0.13.0') '(descriptor) versao 0.13.0'
    Assert-True ([string]$descriptor.Descriptor.modes.compatible.secretEnvVar -eq 'JEV_API_KEY') '(descriptor) JEV_API_KEY'
    $pin = Get-McpVendorPin
    Assert-True ($pin.Version -eq '0.13.0') '(pin) versao'
    Assert-True ($pin.TarballIntegrity -match '^sha512-') '(pin) integrity sha512'

    $stubDir = Join-Path $tempRoot 'WindowsApps'
    [System.IO.Directory]::CreateDirectory($stubDir) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $stubDir 'node.cmd'), "@echo off`r`necho v24.18.0`r`n", [System.Text.UTF8Encoding]::new($false))
    # PATH so com o stub: nao pode cair no node real do sistema (Get-Command -All).
    $env:PATH = $stubDir
    $stubInfo = Get-McpCommandInfo -Name 'node' -VersionArguments @('--version')
    $env:PATH = $originalPath
    Assert-True ((-not $stubInfo.Present) -and $stubInfo.Stub) '(prereq) stub WindowsApps recusado'

    # pwsh sob WindowsApps: zero-byte continua stub; nao usamos .cmd wrapper (abre janela).
    $waPwshDir = Join-Path $tempRoot 'WindowsApps'
    $waPwshExe = Join-Path $waPwshDir 'pwsh.exe'
    [System.IO.File]::WriteAllBytes($waPwshExe, [byte[]]@())
    $env:PATH = $waPwshDir
    $waPwshStub = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    $env:PATH = $originalPath
    Assert-True ((-not $waPwshStub.Present) -and $waPwshStub.Stub) '(prereq) pwsh WindowsApps zero-byte recusado'

    # Pasta separada: com o pwsh.exe zero-byte ao lado, o primeiro do PATH seria o stub.
    $waPwshWorkingDir = Join-Path $tempRoot 'working\WindowsApps'
    [System.IO.Directory]::CreateDirectory($waPwshWorkingDir) | Out-Null
    $waPwshCommand = Join-Path $waPwshWorkingDir 'pwsh.cmd'
    [System.IO.File]::WriteAllText($waPwshCommand, ('@echo off' + $lineBreak + 'echo 7.4.1' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $env:PATH = $waPwshWorkingDir
    $waPwshWorking = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    $env:PATH = $originalPath
    Assert-True ($waPwshWorking.Present -and $waPwshWorking.Version -eq '7.4.1') '(prereq) pwsh WindowsApps funcional aceito'

    # pwsh pela ordem do PATH, como o cliente resolve o comando literal 'pwsh': o primeiro vale,
    # mesmo que outro mais adiante (e em ordem alfabetica anterior) seja compativel.
    $pwshFirstDir = Join-Path $tempRoot 'z-primeiro-no-path'
    $pwshSecondDir = Join-Path $tempRoot 'a-segundo-no-path'
    [System.IO.Directory]::CreateDirectory($pwshFirstDir) | Out-Null
    [System.IO.Directory]::CreateDirectory($pwshSecondDir) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $pwshFirstDir 'pwsh.cmd'), ('@echo off' + $lineBreak + 'echo 7.3.9' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $pwshSecondDir 'pwsh.cmd'), ('@echo off' + $lineBreak + 'echo 7.4.1' + $lineBreak + 'exit /b 0' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $env:PATH = $pwshFirstDir + ';' + $pwshSecondDir
    $pwshPathOrder = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    $env:PATH = $originalPath
    Assert-True ($pwshPathOrder.Present -and $pwshPathOrder.Version -eq '7.3.9' -and ([string]$pwshPathOrder.Path).StartsWith($pwshFirstDir)) "(prereq) pwsh auditado e o primeiro do PATH; obtido $($pwshPathOrder.Version) em $($pwshPathOrder.Path)"
    [System.IO.File]::WriteAllText((Join-Path $pwshFirstDir 'pwsh.cmd'), ('@echo off' + $lineBreak + 'exit /b 1' + $lineBreak), [System.Text.UTF8Encoding]::new($false))
    $env:PATH = $pwshFirstDir + ';' + $pwshSecondDir
    $pwshFirstBroken = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    $env:PATH = $originalPath
    Assert-True (-not $pwshFirstBroken.Present) '(prereq) primeiro pwsh do PATH inutilizavel nao cai no segundo'

    # Piso 7.4: Present com 7.3.9 deve gerar achado blocking.
    $oldPwshPrereq = [pscustomobject]@{
        Pwsh             = [pscustomobject]@{ Present = $true; Stub = $false; Name = 'pwsh'; Path = 'C:\fake\pwsh.exe'; Version = '7.3.9' }
        PwshVersion      = [version]'7.3.9'
        PwshCompatible   = $false
        Node             = [pscustomobject]@{ Present = $true; Stub = $false; Version = 'v22.0.0' }
        Npm              = [pscustomobject]@{ Present = $true; Stub = $false }
        Python           = [pscustomobject]@{ Present = $true; Version = 'Python 3.12.0' }
        NodeCompatible   = $true
        PythonCompatible = $true
        Winget           = [pscustomobject]@{ Present = $false }
        VersionManagers  = @()
        NodeVersion      = $null
        PythonVersion    = $null
    }
    $oldPwshFindings = @(Get-McpPrerequisiteFindings -Prerequisites $oldPwshPrereq)
    Assert-True (@($oldPwshFindings | Where-Object { $_.code -eq 'pwsh_ausente' }).Count -eq 1) '(prereq) pwsh 7.3.9 bloqueia com pwsh_ausente'
    foreach ($acceptedVersion in @('7.4.0', '7.4.1')) {
        $acceptedPwshPrereq = $oldPwshPrereq | Select-Object *
        $acceptedPwshPrereq.Pwsh = [pscustomobject]@{ Present = $true; Stub = $false; Name = 'pwsh'; Path = 'C:\fake\pwsh.exe'; Version = $acceptedVersion }
        $acceptedPwshPrereq.PwshVersion = [version]$acceptedVersion
        $acceptedPwshPrereq.PwshCompatible = $true
        $acceptedFindings = @(Get-McpPrerequisiteFindings -Prerequisites $acceptedPwshPrereq)
        Assert-True (@($acceptedFindings | Where-Object { $_.code -eq 'pwsh_ausente' }).Count -eq 0) "(prereq) pwsh $acceptedVersion aceito"
    }

    $fakeRepo = Join-Path $tempRoot 'fake-repo'
    $fakeComponentDir = Join-Path $fakeRepo 'xpz-mcp-integrations-setup/components'
    [System.IO.Directory]::CreateDirectory($fakeComponentDir) | Out-Null
    $fakeDescriptorPath = Join-Path $fakeComponentDir 'jev.json'
    Copy-Item -LiteralPath $descriptor.Path -Destination $fakeDescriptorPath -Force
    $fakeDescriptor = [System.IO.File]::ReadAllText($fakeDescriptorPath)
    $tampered = $fakeDescriptor.Replace('"schemaVersion": 1,', '"schemaVersion": 1, "extra": true,')
    [System.IO.File]::WriteAllText($fakeDescriptorPath, $tampered, [System.Text.UTF8Encoding]::new($false))
    Assert-ThrowsLike -Action { Get-McpDescriptor -RepoRoot $fakeRepo } -Pattern 'XPZ_MCP_DESCRIPTOR_INVALID' -Message '(descriptor) chave extra recusada'

    # 2. Manifesto.
    $manifest = Get-McpManifest
    Assert-True (-not $manifest.Exists) '(manifest) ausente no inicio'
    $value = New-McpManifest
    $value.packageVersion = '0.13.0'
    $value = Add-McpManifestClientHash -Manifest $value -Client 'opencode' -Path 'C:\temp\opencode.jsonc' -Hash 'aaa'
    $value = Add-McpManifestClientHash -Manifest $value -Client 'opencode' -Path 'C:\temp\opencode.jsonc' -Hash 'bbb'
    $value = Add-McpManifestClientHash -Manifest $value -Client 'opencode' -Path 'C:\temp\opencode.jsonc' -Hash 'aaa'
    $null = Set-McpManifest -Value $value
    $manifest = Get-McpManifest
    Assert-True ($manifest.Exists -and -not $manifest.Corrupt) '(manifest) gravado e legivel'
    $client = Get-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
    Assert-True (@($client.hashes).Count -eq 2) '(manifest) hashes deduplicados'
    [System.IO.File]::WriteAllText((Get-McpManifestPath), '{ invalid', [System.Text.UTF8Encoding]::new($false))
    $corrupt = Get-McpManifest
    Assert-True ($corrupt.Corrupt) '(manifest) corrompido detectado'
    Remove-Item -LiteralPath (Get-McpManifestPath) -Force

    # 3. Config e escrita transacional.
    $config = Get-McpConfig
    Assert-True (-not $config.Exists) '(config) ausente no inicio'
    $configWrite = Set-McpConfig -BaseUrl $baseUrl -Model $model -EndpointConfirmed $true
    Assert-True ($configWrite.Status -eq 'written') '(config) gravado'
    $config = Get-McpConfig
    Assert-True ($config.Exists -and $null -ne $config.Value) '(config) legivel'
    [System.IO.File]::WriteAllText((Get-McpConfigPath), '{ invalid', [System.Text.UTF8Encoding]::new($false))
    $configInvalid = Get-McpConfig
    Assert-True ($null -eq $configInvalid.Value) '(config) invalido detectado'
    $null = Set-McpConfig -BaseUrl $baseUrl -Model $model -EndpointConfirmed $true

    $file = Join-Path $tempRoot 'transactional.txt'
    $write1 = Write-McpTextTransactional -Path $file -Text "one`n" -EncodingKind 'utf8-nobom' -CreateExclusive
    Assert-True ($write1.Status -eq 'written') '(tx) criacao'
    $doc = Read-McpTextDocument -Path $file
    $write2 = Write-McpTextTransactional -Path $file -Text "two`n" -EncodingKind 'utf8-nobom' -ExpectedHash $doc.Hash -ExpectedLength $doc.Length -ExpectedLastWriteTimeUtc $doc.LastWriteTimeUtc
    Assert-True ($write2.Status -eq 'written') '(tx) substituicao'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$write2.BackupPath) -and (Test-Path -LiteralPath $write2.BackupPath)) '(tx) backup criado'
    Assert-True (([System.IO.File]::ReadAllText($write2.BackupPath)) -eq "one`n") '(tx) backup preserva o conteudo anterior'
    Assert-ThrowsLike -Action { Write-McpTextTransactional -Path $file -Text "three`n" -EncodingKind 'utf8-nobom' -ExpectedHash 'deadbeef' } -Pattern 'XPZ_MCP_RACE' -Message '(tx) corrida detectada'
    # Corrida create→replace: chamador pediu criacao exclusiva, mas a folha ja existe
    # (terceiro criou entre a sondagem e a entrada do escritor) — nao pode substituir.
    $raceCreate = Join-Path $tempRoot 'race-create.txt'
    [System.IO.File]::WriteAllText($raceCreate, "intruder`n", [System.Text.UTF8Encoding]::new($false))
    Assert-ThrowsLike -Action {
        Write-McpTextTransactional -Path $raceCreate -Text "mine`n" -EncodingKind 'utf8-nobom' -CreateExclusive
    } -Pattern 'XPZ_MCP_RACE' -Message '(tx) criacao exclusiva recusa folha preexistente'
    Assert-True (([System.IO.File]::ReadAllText($raceCreate)) -eq "intruder`n") '(tx) criacao exclusiva nao sobrescreve intruso'
    $directoryTarget = Join-Path $tempRoot 'target-directory'
    [System.IO.Directory]::CreateDirectory($directoryTarget) | Out-Null
    Assert-ThrowsLike -Action { Write-McpTextTransactional -Path $directoryTarget -Text 'x' -EncodingKind 'utf8-nobom' } -Pattern 'XPZ_MCP_TARGET_NOT_REGULAR' -Message '(tx) diretorio recusado'
    $lockTarget = Join-Path $tempRoot 'locked.txt'
    $null = Write-McpTextTransactional -Path $lockTarget -Text "locked`n" -EncodingKind 'utf8-nobom'
    [System.IO.File]::WriteAllText($lockTarget + '.xpz-mcp.lock', 'pid=0', [System.Text.UTF8Encoding]::new($false))
    Assert-ThrowsLike -Action { Write-McpTextTransactional -Path $lockTarget -Text "new`n" -EncodingKind 'utf8-nobom' } -Pattern 'XPZ_MCP_LOCKED' -Message '(tx) lock recusado'
    Assert-True (Test-Path -LiteralPath ($lockTarget + '.xpz-mcp.lock')) '(tx) lock preexistente permanece apos recusa'
    Remove-Item -LiteralPath ($lockTarget + '.xpz-mcp.lock') -Force
    # Concorrencia: vencedor segura o CreateNew; perdedor nao pode apagar o lock alheio no finally.
    $lockRaceTarget = Join-Path $tempRoot 'lock-race.txt'
    $null = Write-McpTextTransactional -Path $lockRaceTarget -Text "base`n" -EncodingKind 'utf8-nobom'
    $lockRacePath = $lockRaceTarget + '.xpz-mcp.lock'
    $lockHolder = [System.IO.File]::Open(
        $lockRacePath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        Assert-ThrowsLike -Action {
            Write-McpTextTransactional -Path $lockRaceTarget -Text "new`n" -EncodingKind 'utf8-nobom'
        } -Pattern 'XPZ_MCP_LOCKED' -Message '(tx) lock concorrente CreateNew'
        Assert-True (Test-Path -LiteralPath $lockRacePath) '(tx) perdedor nao remove lock do vencedor'
    } finally {
        $lockHolder.Dispose()
        Remove-Item -LiteralPath $lockRacePath -Force -ErrorAction SilentlyContinue
    }
    $whatIfTarget = Join-Path $tempRoot 'whatif.txt'
    $whatIfWrite = Write-McpTextTransactional -Path $whatIfTarget -Text 'x' -EncodingKind 'utf8-nobom' -WhatIf
    Assert-True ($whatIfWrite.Status -eq 'planned' -and -not (Test-Path -LiteralPath $whatIfTarget)) '(tx) whatif sem escrita'

    # 4. DPAPI e cofre.
    Assert-True (Test-McpDpapiRoundTrip) '(vault) round-trip DPAPI'
    $secure = ConvertTo-SecureString $secret -AsPlainText -Force
    $vaultWrite = Write-McpVault -SecureSecret $secure
    Assert-True ($vaultWrite.Status -eq 'written' -and $vaultWrite.Verified) '(vault) grava e verifica'
    Assert-True ((Read-McpVault) -ceq $secret) '(vault) le o mesmo valor'
    Assert-True (Test-McpAcl -Path (Get-McpVaultBlobPath)) '(vault) ACL so-dono'
    $vaultAcl = Get-Acl -LiteralPath (Get-McpVaultBlobPath)
    $broadRules = @($vaultAcl.Access | Where-Object { [string]$_.IdentityReference -match 'Everyone|BUILTIN\\Users' })
    Assert-True ($broadRules.Count -eq 0) '(vault) sem regra para Everyone/Users'
    # Predicado SID+FullControl: nao adulterar a ACL em disco com regra hostil — Set-Acl
    # subsequente pode exigir SeSecurityPrivilege neste ambiente. O caminho 'already' e o
    # predicado cobrem o gap do Test-McpAcl frouxo sem autoexclusao.
    $alreadyAcl = Set-McpAcl -Path (Get-McpVaultBlobPath)
    Assert-True ($alreadyAcl.Status -eq 'already') '(vault) Set-McpAcl idempotente com ACL correta'
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $readOnlyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $currentSid,
        [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    Assert-True (-not (Test-McpAclOwnerFullControlRule -Rule $readOnlyRule -ExpectedSid $currentSid)) '(vault) predicado rejeita Read'
    $ownerFullRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $currentSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    Assert-True (Test-McpAclOwnerFullControlRule -Rule $ownerFullRule -ExpectedSid $currentSid) '(vault) predicado aceita FullControl do dono'
    $worldSid = [System.Security.Principal.SecurityIdentifier]::new(
        [System.Security.Principal.WellKnownSidType]::WorldSid,
        $null
    )
    $worldFullRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $worldSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    Assert-True (-not (Test-McpAclOwnerFullControlRule -Rule $worldFullRule -ExpectedSid $currentSid)) '(vault) predicado rejeita SID alheio'
    Assert-True ((@(Get-McpAclAuditFindings)).Count -eq 0) '(vault) auditoria ACL limpa apos cofre/config com so-dono'
    $vaultWrite2 = Write-McpVault -SecureSecret (ConvertTo-SecureString 'second-secret' -AsPlainText -Force)
    Assert-True ($vaultWrite2.Status -eq 'written' -and (Read-McpVault) -ceq 'second-secret') '(vault) rotacao'
    $vaultWrite3 = Write-McpVault -SecureSecret $secure
    Assert-True ($vaultWrite3.Verified) '(vault) restaura segredo de teste'

    # 5. Emissao do launcher e idempotencia.
    $fakeChild = Join-Path $tempRoot 'fake-child.ps1'
    $childCode = @'
if ($env:JEV_API_KEY -ne 'test-secret-launcher') { [Console]::Error.WriteLine('bad-key'); exit 9 }
[Console]::Out.WriteLine("key=$env:JEV_API_KEY")
[Console]::Out.WriteLine("base=$env:JEV_API_BASE_URL")
[Console]::Out.WriteLine("model=$env:JEV_MCP_MODEL")
[Console]::Out.WriteLine("leak=$env:SECRET_LEAK")
[Console]::Error.WriteLine('child-err')
exit 42
'@
    [System.IO.File]::WriteAllText($fakeChild, $childCode, [System.Text.UTF8Encoding]::new($false))
    $launcherWrite = Install-McpLauncher -Version '0.13.0' -NodePath (Get-Command pwsh).Source -EntryPath $fakeChild -VendorDir $tempRoot
    Assert-True ($launcherWrite.Status -eq 'written') '(launcher) emitido'
    $launcherText = [System.IO.File]::ReadAllText($launcherWrite.Path)
    Assert-True ($launcherText.Contains('# xpz-mcp-integrations-setup:launcher v1')) '(launcher) sentinela'
    Assert-True (-not $launcherText.Contains('__XPZ_MCP_')) '(launcher) sem token'
    $launcherAgain = Install-McpLauncher -Version '0.13.0' -NodePath (Get-Command pwsh).Source -EntryPath $fakeChild -VendorDir $tempRoot
    Assert-True ($launcherAgain.Status -eq 'unchanged') '(launcher) idempotente'
    $launcherNext = Install-McpLauncher -Version '0.13.1' -NodePath (Get-Command pwsh).Source -EntryPath $fakeChild -VendorDir $tempRoot
    Assert-True ($launcherNext.Status -eq 'written' -and (Test-Path -LiteralPath $launcherNext.Path)) '(launcher) re-emissao por versao'

    # 6. Filho falso: exit code, stdout/stderr e ambiente limpo.
    $run = Start-LauncherProcess -LauncherPath $launcherWrite.Path
    Assert-True ($run.ExitCode -eq 42) "(launcher-child) exit 42; obtido $($run.ExitCode)"
    Assert-True ($run.Stdout -match 'key=test-secret-launcher') '(launcher-child) chave injetada'
    Assert-True ($run.Stdout -match 'base=https://api.commandcode.ai/provider/v1/systemone') '(launcher-child) base URL injetada'
    Assert-True ($run.Stdout -match 'model=typesafe/jev') '(launcher-child) modelo injetado'
    Assert-True ($run.Stdout -match 'leak=') '(launcher-child) variavel de leak presente como vazia'
    Assert-True ($run.Stdout -notmatch 'must-not-leak') '(launcher-child) ambiente nao herdado'
    Assert-True ($run.Stderr -match 'child-err') '(launcher-child) stderr do filho'

    # 7. Negativos pre-filho.
    $vaultBackup = [System.IO.File]::ReadAllText((Get-McpVaultBlobPath))
    Remove-Item -LiteralPath (Get-McpVaultBlobPath) -Force
    $noVault = Start-LauncherProcess -LauncherPath $launcherWrite.Path
    Assert-True ($noVault.ExitCode -eq 61 -and [string]::IsNullOrEmpty($noVault.Stdout)) "(launcher-novault) exit 61 e stdout vazio; obtido $($noVault.ExitCode)"
    [System.IO.File]::WriteAllText((Get-McpVaultBlobPath), $vaultBackup, [System.Text.UTF8Encoding]::new($false))

    $configBackup = [System.IO.File]::ReadAllText((Get-McpConfigPath))
    [System.IO.File]::WriteAllText((Get-McpConfigPath), '{ invalid', [System.Text.UTF8Encoding]::new($false))
    $noConfig = Start-LauncherProcess -LauncherPath $launcherWrite.Path
    Assert-True ($noConfig.ExitCode -eq 62 -and [string]::IsNullOrEmpty($noConfig.Stdout)) "(launcher-noconfig) exit 62 e stdout vazio; obtido $($noConfig.ExitCode)"

    # config.json editado fora do install: o launcher aplica a regra de endpoint antes do cofre/filho.
    $launcherConfigCases = @(
        @{ Label = 'http'; BaseUrl = 'http://api.commandcode.ai/provider/v1/systemone'; Confirmed = $true; Expected = 62 },
        @{ Label = 'host-nao-confirmado'; BaseUrl = 'https://example.invalid/v1'; Confirmed = $false; Expected = 62 },
        @{ Label = 'confirmado-string'; BaseUrl = 'https://example.invalid/v1'; Confirmed = 'true'; Expected = 62 },
        @{ Label = 'host-confirmado'; BaseUrl = 'https://example.invalid/v1'; Confirmed = $true; Expected = 42 },
        @{ Label = 'preset-sem-confirmacao'; BaseUrl = $baseUrl; Confirmed = $false; Expected = 42 }
    )
    foreach ($case in $launcherConfigCases) {
        $caseConfig = [ordered]@{ schemaVersion = 1; provider = 'compatible'; baseUrl = $case.BaseUrl; model = $model; endpointConfirmed = $case.Confirmed }
        [System.IO.File]::WriteAllText((Get-McpConfigPath), (($caseConfig | ConvertTo-Json) + "`n"), [System.Text.UTF8Encoding]::new($false))
        $caseRun = Start-LauncherProcess -LauncherPath $launcherWrite.Path
        if ($case.Expected -eq 62) {
            Assert-True ($caseRun.ExitCode -eq 62 -and [string]::IsNullOrEmpty($caseRun.Stdout)) "(launcher-endpoint-$($case.Label)) exit 62, sem filho; obtido $($caseRun.ExitCode)"
        } else {
            Assert-True ($caseRun.ExitCode -eq 42) "(launcher-endpoint-$($case.Label)) filho iniciado; obtido $($caseRun.ExitCode)"
        }
    }
    [System.IO.File]::WriteAllText((Get-McpConfigPath), $configBackup, [System.Text.UTF8Encoding]::new($false))

    $missingNodeLauncher = Install-McpLauncher -Version '0.13.2' -NodePath (Join-Path $tempRoot 'missing-node.exe') -EntryPath $fakeChild -VendorDir $tempRoot
    $missingNode = Start-LauncherProcess -LauncherPath $missingNodeLauncher.Path
    Assert-True ($missingNode.ExitCode -eq 63) "(launcher-nonode) exit 63; obtido $($missingNode.ExitCode)"
    $missingEntryLauncher = Install-McpLauncher -Version '0.13.3' -NodePath (Get-Command pwsh).Source -EntryPath (Join-Path $tempRoot 'missing-entry.ps1') -VendorDir $tempRoot
    $missingEntry = Start-LauncherProcess -LauncherPath $missingEntryLauncher.Path
    Assert-True ($missingEntry.ExitCode -eq 64) "(launcher-noentry) exit 64; obtido $($missingEntry.ExitCode)"
} finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:SECRET_LEAK = $originalLeak
    $env:PATH = $originalPath
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_LAUNCHER_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_LAUNCHER_SELFTEST_OK: $assertCount asserts"
exit 0
