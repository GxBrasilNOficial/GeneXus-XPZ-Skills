#requires -Version 7.4

<#
.SYNOPSIS
    Self-test da faixa reservada de exit codes da skill xpz-mcp-integrations-setup.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')

$repoRoot = Get-McpRepoRoot
$catalogPath = Join-Path $repoRoot 'xpz-mcp-integrations-setup/exit-codes.catalog.json'
$msbuildPath = Join-Path $repoRoot 'scripts/msbuild-exit-codes.catalog.json'
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

$catalog = Get-McpJsonFile -Path $catalogPath
Assert-True ($null -ne $catalog) '(catalog) parse'
Assert-True ([int]$catalog.reservedRange.min -eq 60 -and [int]$catalog.reservedRange.max -eq 69) '(catalog) faixa 60-69'
$codes = @($catalog.codes | ForEach-Object { [int]$_.exit })
Assert-True (($codes | Sort-Object -Unique).Count -eq $codes.Count) '(catalog) exits unicos'
foreach ($code in $codes) {
    Assert-True ($code -eq 0 -or ($code -ge 60 -and $code -le 69)) "(catalog) $code dentro da faixa reservada"
}
$msbuild = Get-McpJsonFile -Path $msbuildPath
$msbuildCodes = @($msbuild.codes | ForEach-Object { [int]$_.exit })
$collisions = @($codes | Where-Object { $_ -ne 0 -and $msbuildCodes -contains $_ })
Assert-True ($collisions.Count -eq 0) "(catalog) sem colisao com msbuild: $($collisions -join ',')"
$expected = @{
    credencial_ausente      = 61
    config_ausente          = 62
    node_ausente            = 63
    vendor_ausente          = 64
    launcher_ausente        = 65
    entrada_em_conflito     = 66
    edicao_manual_necessaria = 67
    python_indisponivel     = 68
}
foreach ($code in $expected.Keys) {
    $finding = New-McpFinding -Code $code -Class 'blocking' -Message 'teste'
    $mapped = Get-McpExitCodeForFindings -Findings @($finding)
    Assert-True ($mapped -eq $expected[$code]) "(catalog) $code -> $($expected[$code]); obtido $mapped"
}
$warnOnly = Get-McpExitCodeForFindings -Findings @((New-McpFinding -Code 'python_indisponivel' -Class 'warn' -Message 'teste'))
Assert-True ($warnOnly -eq 0) '(catalog) warn isolado nao bloqueia'

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_EXIT_CODES_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_EXIT_CODES_SELFTEST_OK: $assertCount asserts"
exit 0
