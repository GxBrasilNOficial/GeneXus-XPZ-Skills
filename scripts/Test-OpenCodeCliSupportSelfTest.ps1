#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da descoberta do opencode.exe.
.DESCRIPTION
    Valida o helper OpenCodeCliSupport.ps1 sem depender de rede nem de modelo real.
    Sentinela de sucesso: OPENCODE_CLI_SUPPORT_SELFTEST_OK
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')

$fail = 0
function Assert-True {
    param([bool] $Condition, [string] $Message)
    if ($Condition) { Write-Host "PASS  $Message" -ForegroundColor Green }
    else { $script:fail++; Write-Host "FAIL  $Message" -ForegroundColor Red }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-cli-selftest-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

try {
    $fakeReader = Join-Path $tempRoot 'fake-opencode-reader.ps1'
    @'
if ($args.Count -ge 1 -and $args[0] -eq '--version') {
    Write-Output '9.8.7-test'
    exit 0
}
exit 0
'@ | Set-Content -LiteralPath $fakeReader -Encoding utf8

    $fakeCmd = Join-Path $tempRoot 'opencode.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-opencode-reader.ps1" %*
exit /b %errorlevel%
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    $resolvedOverride = Resolve-OpenCodeExe -Override $fakeCmd
    Assert-True ($resolvedOverride -eq $fakeCmd) 'override explicito resolve o fake-opencode.cmd'
    Assert-True ((Get-OpenCodeExeVersion -ExePath $fakeCmd) -eq '9.8.7-test') 'Get-OpenCodeExeVersion le --version'

    $oldPath = $env:PATH
    try {
        $env:PATH = "$tempRoot;$oldPath"
        $resolvedPath = Resolve-OpenCodeExe
        Assert-True ($resolvedPath -eq $fakeCmd) 'Resolve-OpenCodeExe encontra opencode no PATH'
    }
    finally {
        $env:PATH = $oldPath
    }

    $missing = Join-Path $tempRoot 'missing-opencode.exe'
    $threw = $false
    $msg = ''
    try { Resolve-OpenCodeExe -Override $missing | Out-Null }
    catch { $threw = $true; $msg = $_.Exception.Message }
    Assert-True ($threw -and $msg -match 'nao existe') 'override inexistente bloqueia com mensagem clara'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeCliSupportSelfTest.ps1" }
Write-Host 'OPENCODE_CLI_SUPPORT_SELFTEST_OK' -ForegroundColor Cyan
