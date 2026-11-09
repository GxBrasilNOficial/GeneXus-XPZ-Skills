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

# Contrato de emissores: o catalogo precisa apontar motores reais e cobrir a
# matriz observada pelos self-tests de integracao. Se um motor passar a emitir
# um codigo novo, atualize a matriz e o catalogo juntos.
$scriptNames = @(
    'Test-McpIntegrations.ps1',
    'Install-McpIntegration.ps1',
    'Uninstall-McpIntegration.ps1',
    'Invoke-McpVendor.ps1',
    'Set-McpCredential.ps1'
)
$knownEngineTokens = @('*', 'launcher') + $scriptNames
foreach ($entry in @($catalog.codes)) {
    foreach ($engine in @($entry.engines)) {
        $token = [string]$engine
        $known = $knownEngineTokens -contains $token
        if (-not $known -and $token -like '*.ps1') {
            $known = Test-Path -LiteralPath (Join-Path $repoRoot (Join-Path 'scripts' $token)) -PathType Leaf
        }
        Assert-True $known "(catalog) exit $($entry.exit) aponta motor conhecido: $token"
    }
}

$code69 = @($catalog.codes | Where-Object { [int]$_.exit -eq 69 })
Assert-True ($code69.Count -eq 1) '(catalog) exit 69 unico'
if ($code69.Count -eq 1) {
    $engines69 = @($code69[0].engines)
    Assert-True ($engines69 -contains '*') '(catalog) 69 cobre todos os motores'
    Assert-True ($engines69 -contains 'launcher') '(catalog) 69 cobre o launcher'
}
foreach ($name in $scriptNames) {
    $enginePath = Join-Path $repoRoot (Join-Path 'scripts' $name)
    Assert-True (Test-Path -LiteralPath $enginePath -PathType Leaf) "(engines) $name existe"
    if (Test-Path -LiteralPath $enginePath -PathType Leaf) {
        $engineText = [System.IO.File]::ReadAllText($enginePath)
        Assert-True ($engineText -match '(?m)^trap\s*\{') "(engines) $name tem trap de nivel superior"
        Assert-True ($engineText -match 'Write-McpInternalFailure') "(engines) $name chama Write-McpInternalFailure"
    }
}

$requiredEmitters = @{
    60 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1')
    61 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1', 'Set-McpCredential.ps1', 'launcher')
    62 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1', 'launcher')
    63 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1', 'Invoke-McpVendor.ps1', 'launcher')
    64 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1', 'Invoke-McpVendor.ps1', 'launcher')
    65 = @('Test-McpIntegrations.ps1')
    66 = @('Test-McpIntegrations.ps1', 'Install-McpIntegration.ps1', 'Uninstall-McpIntegration.ps1')
}
foreach ($code in $requiredEmitters.Keys) {
    $entry = @($catalog.codes | Where-Object { [int]$_.exit -eq $code })
    Assert-True ($entry.Count -eq 1) "(catalog) exit $code presente"
    if ($entry.Count -eq 1) {
        $declared = @($entry[0].engines)
        foreach ($engine in $requiredEmitters[$code]) {
            $covered = ($declared -contains '*') -or ($declared -contains $engine)
            Assert-True $covered "(catalog) exit $code deve listar $engine"
        }
        foreach ($engine in $declared) {
            if ($engine -eq '*') { continue }
            Assert-True ($requiredEmitters[$code] -contains $engine) "(catalog) exit $code nao deve listar $engine"
        }
    }
}

# Prova de emissao do 69: injeta uma falha interna depois dos dot-sources e
# verifica o trap real de cada motor, sem gravar nada no repositorio.
$probeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-exit69-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($probeRoot) | Out-Null
try {
    $scriptsRoot = Join-Path $repoRoot 'scripts'
    $scriptsLiteral = $scriptsRoot.Replace("'", "''")
    $probeKinds = @{
        'Test-McpIntegrations.ps1'     = 'audit'
        'Install-McpIntegration.ps1'   = 'mutation'
        'Uninstall-McpIntegration.ps1' = 'mutation'
        'Invoke-McpVendor.ps1'         = 'vendor'
        'Set-McpCredential.ps1'        = 'credential'
    }
    foreach ($probeEngine in $probeKinds.Keys) {
        $enginePath = Join-Path $scriptsRoot $probeEngine
        $engineText = [System.IO.File]::ReadAllText($enginePath)
        $engineText = $engineText.Replace('$scriptDir = $PSScriptRoot', "`$scriptDir = '$scriptsLiteral'")
        $dotSources = [regex]::Matches($engineText, "(?m)^\. \(Join-Path \`$scriptDir '[^']+\.ps1'\)$")
        Assert-True ($dotSources.Count -gt 0) "(engines) $probeEngine tem dot-source"
        if ($dotSources.Count -eq 0) { continue }
        $anchor = $dotSources[$dotSources.Count - 1].Value
        $anchorIndex = $engineText.LastIndexOf($anchor)
        $engineText = $engineText.Substring(0, $anchorIndex + $anchor.Length) +
            "`nthrow 'XPZ_MCP_TEST_FORCED_INTERNAL_ERROR'" +
            $engineText.Substring($anchorIndex + $anchor.Length)
        $probeName = [System.IO.Path]::GetFileNameWithoutExtension($probeEngine) + '.probe.ps1'
        $probePath = Join-Path $probeRoot $probeName
        [System.IO.File]::WriteAllText($probePath, $engineText, [System.Text.UTF8Encoding]::new($false))
        $probeOutput = @(& pwsh -NoProfile -File $probePath 2>&1)
        $probeExit = $LASTEXITCODE
        Assert-True ($probeExit -eq 69) "(engines) $probeEngine falha interna forcada sai 69; obtido $probeExit"
        $probeJson = $null
        try { $probeJson = (($probeOutput | ForEach-Object { [string]$_ }) -join "`n") | ConvertFrom-Json -AsHashtable } catch { }
        Assert-True ($null -ne $probeJson) "(engines) $probeEngine emite JSON parseavel"
        if ($null -ne $probeJson) {
            Assert-True ([int]$probeJson.exitCode -eq 69) "(engines) $probeEngine JSON com exitCode 69"
            Assert-True ([string]$probeJson.kind -eq "xpz-mcp-integrations-setup-$($probeKinds[$probeEngine])") "(engines) $probeEngine JSON com kind esperado"
            Assert-True (@($probeJson.findings)[0].code -eq 'erro_interno') "(engines) $probeEngine JSON registra erro_interno"
        }
    }
} finally {
    Remove-Item -LiteralPath $probeRoot -Recurse -Force -ErrorAction SilentlyContinue
}

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
