#requires -Version 7.4

<#
.SYNOPSIS
    Self-test offline do adaptador Codex da skill xpz-mcp-integrations-setup.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpCodexSupport.ps1')

$fixtureDir = Join-Path (Split-Path -Parent $scriptDir) 'xpz-mcp-integrations-setup/fixtures/codex'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-cx-selftest-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$originalPath = $env:PATH
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$codexDir = Join-Path $tempRoot '.codex'
[System.IO.Directory]::CreateDirectory($codexDir) | Out-Null
$baseUrl = 'https://api.commandcode.ai/provider/v1/systemone'
$model = 'typesafe/jev'
$launcher = Join-Path $tempRoot 'launcher-0.13.0.ps1'
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

function New-Fixture {
    param([string]$Name)
    $path = Join-Path $fixtureDir $Name
    $text = [System.IO.File]::ReadAllText($path)
    $escapedLauncher = $launcher.Replace('\', '\\')
    $text = $text.Replace('__LAUNCHER__', $escapedLauncher)
    $text = $text.Replace('__BASE_URL__', $baseUrl)
    $text = $text.Replace('__MODEL__', $model)
    $destination = Join-Path $tempRoot $Name
    [System.IO.File]::WriteAllText($destination, $text, [System.Text.UTF8Encoding]::new($false))
    return $destination
}

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

try {
    # 1. Config sem a entrada: append + idempotencia.
    $empty = New-Fixture -Name 'empty.toml'
    $insert = Update-McpCodexConfig -Path $empty -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($insert.status -eq 'written') "(empty) esperado written; obtido $($insert.status)"
    $emptyText = Read-Text -Path $empty
    Assert-True ($emptyText -match '\[mcp_servers\.jev\]') '(empty) bloco emitido'
    Assert-True ($emptyText -match '\[shell_environment_policy\]') '(empty) config alheia preservada'
    $insertAgain = Update-McpCodexConfig -Path $empty -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($insert.entryHash) -Action install
    Assert-True ($insertAgain.status -eq 'unchanged') '(empty) idempotente'

    # 2. Entrada manual canonica: manual sem aprovacao; migracao com aprovacao.
    $manual = New-Fixture -Name 'manual-canonical.toml'
    $before = Read-Text -Path $manual
    $manualResult = Update-McpCodexConfig -Path $manual -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($manualResult.status -eq 'manual') "(manual) esperado manual; obtido $($manualResult.status)"
    Assert-True ((Read-Text -Path $manual) -ceq $before) '(manual) arquivo intacto sem aprovacao'
    $migrate = Update-McpCodexConfig -Path $manual -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install -MigrateLegacy
    Assert-True ($migrate.status -eq 'written') "(manual-migrate) esperado written; obtido $($migrate.status)"
    $manualText = Read-Text -Path $manual
    Assert-True ($manualText -match '# >>> xpz-mcp-integrations-setup:jev >>>') '(manual-migrate) marcadores emitidos'
    $migrateAgain = Update-McpCodexConfig -Path $manual -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($migrate.entryHash) -Action install
    Assert-True ($migrateAgain.status -eq 'unchanged') '(manual-migrate) idempotente'

    $stateTarget = Join-Path $codexDir 'config.toml'
    $manualStateSource = New-Fixture -Name 'manual-canonical.toml'
    Copy-Item -LiteralPath $manualStateSource -Destination $stateTarget -Force
    $manualState = Get-McpCodexState -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @()
    Assert-True (@($manualState.findings | Where-Object { $_.code -eq 'edicao_manual_necessaria' }).Count -eq 1) '(manual-state) edicao_manual_necessaria'
    Assert-True ($manualState.form -eq 'manual' -and $manualState.migration -eq 'MigrateLegacy') '(manual-state) form/migration'
    Remove-Item -LiteralPath $stateTarget -Force

    # 3. Grafias equivalentes que a migracao recusa.
    foreach ($fixture in @('manual-quoted.toml', 'manual-dotted.toml', 'manual-inline.toml', 'manual-subtable.toml', 'manual-spaced-header.toml')) {
        $path = New-Fixture -Name $fixture
        $before = Read-Text -Path $path
        $result = Update-McpCodexConfig -Path $path -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install -MigrateLegacy
        Assert-True ($result.status -eq 'entrada_em_conflito') "($fixture) esperado entrada_em_conflito; obtido $($result.status)"
        Assert-True ((Read-Text -Path $path) -ceq $before) "($fixture) arquivo intacto"
    }
    $dotted = New-Fixture -Name 'manual-dotted.toml'
    Copy-Item -LiteralPath $dotted -Destination $stateTarget -Force
    $dottedState = Get-McpCodexState -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @()
    Assert-True (@($dottedState.findings | Where-Object { $_.code -eq 'entrada_em_conflito' }).Count -eq 1) '(dotted-state) entrada_em_conflito'
    Remove-Item -LiteralPath $stateTarget -Force

    # 4. Bloco entre marcadores reconhecido.
    $balanced = New-Fixture -Name 'markers-balanced.toml'
    $balancedTarget = Join-Path $codexDir 'config.toml'
    Copy-Item -LiteralPath $balanced -Destination $balancedTarget -Force
    $state = Get-McpCodexState -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @()
    Assert-True ($state.state -in @('escrito', 'recarga_pendente')) "(balanced) estado esperado escrito/recarga_pendente; obtido $($state.state)"
    Remove-Item -LiteralPath $balancedTarget -Force

    # 4b. Bloco emitido por versao anterior: substituicao so do conteudo, sem duplicar marcadores.
    $oldBlockPath = New-Fixture -Name 'markers-balanced.toml'
    $oldText = Read-Text -Path $oldBlockPath
    $oldLauncher = (Join-Path $tempRoot 'old-launcher.ps1').Replace('\', '\\')
    $currentLauncherEscaped = $launcher.Replace('\', '\\')
    $oldText = $oldText.Replace($currentLauncherEscaped, $oldLauncher)
    [System.IO.File]::WriteAllText($oldBlockPath, $oldText, [System.Text.UTF8Encoding]::new($false))
    $oldInfo = Get-McpCodexBlockInfo -Text $oldText
    $replace = Update-McpCodexConfig -Path $oldBlockPath -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($oldInfo.contentHash) -Action install
    Assert-True ($replace.status -eq 'written') "(replace) esperado written; obtido $($replace.status)"
    $replacedText = Read-Text -Path $oldBlockPath
    Assert-True ($replacedText -match [regex]::Escape($currentLauncherEscaped)) '(replace) launcher atual no bloco'
    Assert-True (@([regex]::Matches($replacedText, '# >>> xpz-mcp-integrations-setup:jev >>>')).Count -eq 1) '(replace) um marcador de abertura'
    Assert-True (@([regex]::Matches($replacedText, '# <<< xpz-mcp-integrations-setup:jev <<<')).Count -eq 1) '(replace) um marcador de fechamento'

    # 5. Marcadores desbalanceados e tabela alheia.
    $unbalanced = New-Fixture -Name 'markers-unbalanced.toml'
    $before = Read-Text -Path $unbalanced
    $unbalancedResult = Update-McpCodexConfig -Path $unbalanced -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($unbalancedResult.status -eq 'entrada_em_conflito') "(unbalanced) esperado entrada_em_conflito; obtido $($unbalancedResult.status)"
    Assert-True ((Read-Text -Path $unbalanced) -ceq $before) '(unbalanced) arquivo intacto'
    $foreign = New-Fixture -Name 'foreign-between-markers.toml'
    $before = Read-Text -Path $foreign
    $foreignResult = Update-McpCodexConfig -Path $foreign -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($foreignResult.status -eq 'entrada_em_conflito') "(foreign) esperado entrada_em_conflito; obtido $($foreignResult.status)"
    Assert-True ((Read-Text -Path $foreign) -ceq $before) '(foreign) arquivo intacto'

    # 6. TOML invalido.
    $syntax = New-Fixture -Name 'syntax-error.toml'
    $before = Read-Text -Path $syntax
    $syntaxResult = Update-McpCodexConfig -Path $syntax -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($syntaxResult.status -eq 'entrada_quebrada') "(syntax) esperado entrada_quebrada; obtido $($syntaxResult.status)"
    Assert-True ((Read-Text -Path $syntax) -ceq $before) '(syntax) arquivo intacto'

    # 7. Remocao reconhecida e remocao desconhecida.
    $removeTarget = New-Fixture -Name 'empty.toml'
    $removeInstall = Update-McpCodexConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    $removeOk = Update-McpCodexConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($removeInstall.entryHash) -Action remove
    Assert-True ($removeOk.status -eq 'written') "(remove) esperado written; obtido $($removeOk.status)"
    $removeText = Read-Text -Path $removeTarget
    Assert-True ($removeText -notmatch '\[mcp_servers\.jev\]') '(remove) entrada removida'
    Assert-True ($removeText -match '\[shell_environment_policy\]') '(remove) config alheia preservada'
    $removeUnknown = Update-McpCodexConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @('deadbeef') -Action remove
    Assert-True ($removeUnknown.status -eq 'unchanged') '(remove) entrada ausente nao e conflito'
    $unknownRemoveTarget = New-Fixture -Name 'foreign-between-markers.toml'
    $before = Read-Text -Path $unknownRemoveTarget
    $unknownRemove = Update-McpCodexConfig -Path $unknownRemoveTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @('deadbeef') -Action remove
    Assert-True ($unknownRemove.status -eq 'entrada_em_conflito') "(remove-unknown) esperado entrada_em_conflito; obtido $($unknownRemove.status)"
    Assert-True ((Read-Text -Path $unknownRemoveTarget) -ceq $before) '(remove-unknown) arquivo intacto'
    $manualRemoveTarget = New-Fixture -Name 'manual-canonical.toml'
    $before = Read-Text -Path $manualRemoveTarget
    $manualRemove = Update-McpCodexConfig -Path $manualRemoveTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action remove
    Assert-True ($manualRemove.status -eq 'entrada_em_conflito') "(remove-manual) esperado entrada_em_conflito; obtido $($manualRemove.status)"
    Assert-True ((Read-Text -Path $manualRemoveTarget) -ceq $before) '(remove-manual) arquivo intacto'

    # 8. -WhatIf nao grava.
    $whatIf = New-Fixture -Name 'empty.toml'
    $before = Read-Text -Path $whatIf
    $whatIfResult = Update-McpCodexConfig -Path $whatIf -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install -WhatIf
    Assert-True ($whatIfResult.status -eq 'planned') "(whatif) esperado planned; obtido $($whatIfResult.status)"
    Assert-True ((Read-Text -Path $whatIf) -ceq $before) '(whatif) arquivo intacto'

    # 9. Python ausente: Codex cai em edicao manual com snippet.
    $noPython = New-Fixture -Name 'empty.toml'
    $before = Read-Text -Path $noPython
    $env:PATH = "$env:SystemRoot\System32"
    $pythonResult = Update-McpCodexConfig -Path $noPython -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    $env:PATH = $originalPath
    Assert-True ($pythonResult.status -eq 'python_indisponivel') "(no-python) esperado python_indisponivel; obtido $($pythonResult.status)"
    Assert-True ($pythonResult.PSObject.Properties['snippet'] -and -not [string]::IsNullOrWhiteSpace([string]$pythonResult.snippet)) '(no-python) snippet pronto'
    Assert-True ((Read-Text -Path $noPython) -ceq $before) '(no-python) arquivo intacto'
} finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:PATH = $originalPath
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_CODEX_ADAPTER_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_CODEX_ADAPTER_SELFTEST_OK: $assertCount asserts"
exit 0
