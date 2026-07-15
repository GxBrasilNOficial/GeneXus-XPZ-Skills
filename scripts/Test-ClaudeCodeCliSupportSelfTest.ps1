#requires -Version 7.4
<#
.SYNOPSIS
    Self-test das funcoes de ClaudeCodeCliSupport.ps1 e da montagem de argumentos dos adapters.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

$fail = 0
function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Label) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0} -> '{1}' (esperado '{2}')" -f $Label, $Got, $Expected) -ForegroundColor Red
    }
}

Assert-Equal 'parse versao' (ConvertFrom-ClaudeCodeVersionText '2.1.118 (Claude Code)') ([version]'2.1.118')
Assert-Equal 'parse invalido -> null' (ConvertFrom-ClaudeCodeVersionText 'sem versao') $null

$helpOk = @'
--model
--print
--output-format
--no-session-persistence
--permission-mode
--tools
'@
Assert-Equal 'help com flags exigidas' (Test-ClaudeCodeHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-ClaudeCodeHelpSupportsContract '--model') $false

$err = Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText 'Error: model not available'
Assert-Equal 'extrai erro simples' $err 'Error: model not available'
$trustErr = 'Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue.'
Assert-Equal 'detecta workspace nao confiavel' (Test-ClaudeCodeWorkspaceNotTrusted -Text $trustErr) $true
Assert-Equal 'erro workspace not trusted vira mensagem canonica' ((Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $trustErr) -match 'workspace-not-trusted') $true

$s1 = Resolve-ClaudeCodeJobStatus -FinalText 'ok' -StreamError '' -Stderr 'Error: ruidoso'
Assert-Equal 'status resposta final manda' $s1.status 'completed'
$s2 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError 'stream boom' -Stderr ''
Assert-Equal 'status erro stream' $s2.status 'error'
$s3 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr 'Error: auth required'
Assert-Equal 'status erro stderr' $s3.status 'error'
$s4 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr ''
Assert-Equal 'status sem texto' $s4.status 'sem-texto'
$s5 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr $trustErr
Assert-Equal 'status workspace not trusted' $s5.status 'unavailable'

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
  echo --model --print --output-format --no-session-persistence --permission-mode --tools --max-turns
  exit /b 0
)
if "%FAKE_CLAUDE_UNTRUSTED%"=="1" (
  echo Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue. 1>&2
  exit /b 1
)
echo %*>>"$argsFile"
echo OK fake claude
exit /b 0
"@
    Set-Content -LiteralPath $fakeExe -Value $script -Encoding ascii
    return [pscustomobject]@{ Exe = $fakeExe; ArgsFile = $argsFile }
}

function Read-LastFakeClaudeArgs {
    param([string]$Path)
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)
    if ($lines.Count -eq 0) { return '' }
    return [string]$lines[-1]
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-code-cli-support-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $fake = New-FakeClaudeCodeExe -TempRoot $tmp

    & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'adapter default tools' -ClaudeExe $fake.Exe -TimeoutSec 30 | Out-Null
    $invokeDefaultArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    Assert-Equal 'invoke default passa --tools' ($invokeDefaultArgs -match '--tools Read,Glob,Grep') $true

    & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'adapter tools vazio' -ClaudeExe $fake.Exe -Tools '' -TimeoutSec 30 | Out-Null
    $invokeEmptyArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    Assert-Equal 'invoke tools vazio omite --tools' ($invokeEmptyArgs -notmatch '--tools') $true

    $env:FAKE_CLAUDE_UNTRUSTED = '1'
    $threwTrust = $false
    $trustMsg = ''
    try { & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'workspace nao confiavel' -ClaudeExe $fake.Exe -TimeoutSec 30 | Out-Null } catch { $threwTrust = $true; $trustMsg = [string]$_.Exception.Message }
    $env:FAKE_CLAUDE_UNTRUSTED = $null
    Assert-Equal 'invoke workspace not trusted bloqueia com codigo canonico' ($threwTrust -and $trustMsg -match 'workspace-not-trusted') $true

    $jobDir = Join-Path $tmp 'jobs'
    $jobJson = & (Join-Path $PSScriptRoot 'Start-ClaudeCodeJob.ps1') 'job default tools' -ClaudeExe $fake.Exe -NoWatcher -TempDir $jobDir
    $job = $jobJson | ConvertFrom-Json
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $jobDefaultArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    } while ($jobDefaultArgs -notmatch 'stream-json' -and (Get-Date) -lt $deadline)
    Assert-Equal 'job default passa --tools' ($jobDefaultArgs -match '--tools Read,Glob,Grep') $true
    if ($job.pid) {
        Wait-Process -Id ([int]$job.pid) -Timeout 5 -ErrorAction SilentlyContinue
    }
} finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-ClaudeCodeCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-ClaudeCodeCliSupportSelfTest.ps1' -ForegroundColor Cyan
