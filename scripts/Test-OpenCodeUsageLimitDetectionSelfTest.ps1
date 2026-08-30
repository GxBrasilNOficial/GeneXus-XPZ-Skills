#requires -Version 7.4
<#
.SYNOPSIS
    Regressao do resolvedor tipado de limite de uso/taxa do provider no log do opencode.
.DESCRIPTION
    Cobre Resolve-OpenCodeProviderLimitHit / Get-OpenCodeUsageLimitError (objeto tipado).
    Sentinela: OK: Test-OpenCodeUsageLimitDetectionSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'OpenCodeStreamSupport.ps1')

function Get-Utf8NoBomEncoding { return [System.Text.UTF8Encoding]::new($false) }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("opencode-usagelimit-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $logDir = Join-Path $tempRoot 'log'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    $line429 = '{"level":"ERROR","service":"provider","statusCode":429,"responseBody":"{\"error\":\"you (AntonioJose_Dev) have reached your weekly usage limit, upgrade for higher limits: https://ollama.com/upgrade\"}"}'
    $lineOk  = '{"level":"INFO","service":"session","message":"step_finish reason=stop"}'
    $sinceTime = ([DateTime]::UtcNow).AddSeconds(-10)

    $log429 = Join-Path $logDir '2026-06-21T000001.log'
    [System.IO.File]::WriteAllText($log429, $line429 + "`n", (Get-Utf8NoBomEncoding))
    $hit = Get-OpenCodeUsageLimitError -SinceTime $sinceTime -LogDir $logDir
    if ($null -eq $hit) { throw "ASSERT_FAILED: (a) 429+usage no log deveria ser detectado" }
    if ((Get-OcProp $hit 'kind') -ne 'usage-limit') { throw "ASSERT_FAILED: (a) kind deveria ser usage-limit: $(Get-OcProp $hit 'kind')" }
    if ([string](Get-OcProp $hit 'message') -notmatch 'weekly usage limit') {
        throw "ASSERT_FAILED: (a) mensagem nao contem weekly usage limit"
    }

    $logDirOk = Join-Path $tempRoot 'log-ok'
    New-Item -ItemType Directory -Path $logDirOk -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $logDirOk '2026-06-21T000002.log'), $lineOk + "`n", (Get-Utf8NoBomEncoding))
    $miss = Get-OpenCodeUsageLimitError -SinceTime $sinceTime -LogDir $logDirOk
    if ($null -ne $miss) { throw "ASSERT_FAILED: (b) log sem limite deveria retornar `$null" }

    $logDirOld = Join-Path $tempRoot 'log-old'
    New-Item -ItemType Directory -Path $logDirOld -Force | Out-Null
    $oldLog = Join-Path $logDirOld '2026-06-20T000001.log'
    [System.IO.File]::WriteAllText($oldLog, $line429 + "`n", (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $oldLog).LastWriteTime = [DateTime]::Now.AddHours(-1)
    $outOfWindow = Get-OpenCodeUsageLimitError -SinceTime ([DateTime]::UtcNow).AddSeconds(-10) -LogDir $logDirOld
    if ($null -ne $outOfWindow) { throw "ASSERT_FAILED: (c) 429 fora da janela deveria retornar `$null" }

    $logSpace = Join-Path $tempRoot 'log-space'
    New-Item -ItemType Directory -Path $logSpace -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $logSpace 's.log'), '{"statusCode": 429,"msg":"Too Many Requests"}' + "`n", (Get-Utf8NoBomEncoding))
    $rateHit = Get-OpenCodeUsageLimitError -SinceTime $sinceTime -LogDir $logSpace
    if ((Get-OcProp $rateHit 'kind') -ne 'rate-limit') { throw "ASSERT_FAILED: statusCode com espaco sem frase de cota deveria ser rate-limit" }

    $stepFinish = '{"type":"step_finish","part":{"cost":0.402,"tokens":{"total":429}}}'
    $sfKind = Get-OpenCodeProviderLimitKindFromText -Text $stepFinish
    if ($null -ne $sfKind) { throw "ASSERT_FAILED: step_finish cost/tokens nao deve classificar limite" }

    $combo = '{"statusCode":429,"msg":"weekly usage limit"}'
    if ((Get-OpenCodeProviderLimitKindFromText -Text $combo) -ne 'usage-limit') {
        throw "ASSERT_FAILED: 429 estrutural + weekly usage limit deve ser usage-limit"
    }
    if ((Get-OpenCodeProviderLimitKindFromText -Text '{"statusCode":429}') -ne 'rate-limit') {
        throw "ASSERT_FAILED: 429 estrutural sem frase de cota deve ser rate-limit"
    }

    'OK: Test-OpenCodeUsageLimitDetectionSelfTest.ps1'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
