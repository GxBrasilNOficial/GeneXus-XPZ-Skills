#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Resolve-LlmDelegationPolicyPath.ps1 (fallback de nome).
    Sentinela de sucesso: OK: Test-LlmDelegationPolicyPathSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegationPolicyPath.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $target" }

$canonicalName = 'llm-delegation-policy.json'
$legacyName    = 'opencode-delegation-policy.json'

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

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("llmpol-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # nenhum arquivo
    $r = & $target -ParallelKbRoot $tmp | ConvertFrom-Json
    Assert-Equal 'none -> status' $r.status 'none'
    Assert-Equal 'none -> exists false' $r.exists $false
    Assert-Equal 'none -> path aponta para o canonico' (Split-Path -Leaf $r.path) $canonicalName

    # so o legado
    Set-Content -LiteralPath (Join-Path $tmp $legacyName) -Value '{}' -Encoding utf8
    $r = & $target -ParallelKbRoot $tmp | ConvertFrom-Json
    Assert-Equal 'legacy -> status' $r.status 'legacy'
    Assert-Equal 'legacy -> deprecatedNameInUse' $r.deprecatedNameInUse $true
    Assert-Equal 'legacy -> fileName legado' $r.fileName $legacyName

    # ambos
    Set-Content -LiteralPath (Join-Path $tmp $canonicalName) -Value '{}' -Encoding utf8
    $r = & $target -ParallelKbRoot $tmp | ConvertFrom-Json
    Assert-Equal 'both -> status' $r.status 'both'
    Assert-Equal 'both -> usa o canonico' $r.fileName $canonicalName
    Assert-Equal 'both -> deprecatedNameInUse sinalizado' $r.deprecatedNameInUse $true

    # so o canonico
    Remove-Item -LiteralPath (Join-Path $tmp $legacyName) -Force
    $r = & $target -ParallelKbRoot $tmp | ConvertFrom-Json
    Assert-Equal 'new -> status' $r.status 'new'
    Assert-Equal 'new -> nao depreciado' $r.deprecatedNameInUse $false
    Assert-Equal 'new -> exists true' $r.exists $true
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-LlmDelegationPolicyPathSelfTest.ps1" }
Write-Host 'OK: Test-LlmDelegationPolicyPathSelfTest.ps1' -ForegroundColor Cyan
