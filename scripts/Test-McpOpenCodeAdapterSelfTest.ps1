#requires -Version 7.4

<#
.SYNOPSIS
    Self-test offline do adaptador OpenCode da skill xpz-mcp-integrations-setup.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpOpenCodeSupport.ps1')

$fixtureDir = Join-Path (Split-Path -Parent $scriptDir) 'xpz-mcp-integrations-setup/fixtures/opencode'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-oc-selftest-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$opencodeDir = Join-Path $tempRoot '.config\opencode'
[System.IO.Directory]::CreateDirectory($opencodeDir) | Out-Null
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
    # 1. Entrada canonica exata: estado escrito e idempotencia.
    $canonical = New-Fixture -Name 'canonical.jsonc'
    $canonicalTarget = Join-Path $opencodeDir 'opencode.jsonc'
    Copy-Item -LiteralPath $canonical -Destination $canonicalTarget -Force
    $state = Get-McpOpenCodeState -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @()
    Assert-True ($state.state -in @('escrito', 'recarga_pendente')) "(canonical) estado esperado escrito/recarga_pendente; obtido $($state.state)"
    Assert-True ($state.form -eq 'canonical') '(canonical) forma canonica'
    Remove-Item -LiteralPath $canonicalTarget -Force
    $before = Read-Text -Path $canonical
    $update = Update-McpOpenCodeConfig -Path $canonical -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($update.status -eq 'unchanged') "(canonical) idempotente; obtido $($update.status)"
    Assert-True ((Read-Text -Path $canonical) -ceq $before) '(canonical) nenhum byte alterado'

    # 1b. Entrada emitida por versao anterior: substituir pelo hash do manifesto.
    $oldEntryPath = New-Fixture -Name 'canonical.jsonc'
    $oldText = Read-Text -Path $oldEntryPath
    $currentLauncherEscaped = $launcher.Replace('\', '\\')
    $oldLauncherEscaped = (Join-Path $tempRoot 'old-launcher.ps1').Replace('\', '\\')
    $oldText = $oldText.Replace($currentLauncherEscaped, $oldLauncherEscaped)
    [System.IO.File]::WriteAllText($oldEntryPath, $oldText, [System.Text.UTF8Encoding]::new($false))
    $oldInfo = Get-McpOpenCodeEntryInfo -Path $oldEntryPath -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    $replace = Update-McpOpenCodeConfig -Path $oldEntryPath -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($oldInfo.hash) -Action install
    Assert-True ($replace.status -eq 'written') "(replace) esperado written; obtido $($replace.status)"
    $replacedInfo = Get-McpOpenCodeEntryInfo -Path $oldEntryPath -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($replacedInfo.hash -eq $replacedInfo.expectedHash) '(replace) entrada substituida pela forma atual'

    # 2. Forma legada sem migracao: manual e arquivo intacto.
    $legacy = New-Fixture -Name 'legacy.jsonc'
    $before = Read-Text -Path $legacy
    $manual = Update-McpOpenCodeConfig -Path $legacy -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($manual.status -eq 'manual') "(legacy) esperado manual; obtido $($manual.status)"
    Assert-True ((Read-Text -Path $legacy) -ceq $before) '(legacy) arquivo intacto sem aprovacao'

    # 3. Forma legada com migracao: canonica, legada ausente, demais chaves preservadas.
    $legacy2 = New-Fixture -Name 'legacy.jsonc'
    $migrate = Update-McpOpenCodeConfig -Path $legacy2 -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install -MigrateLegacy
    Assert-True ($migrate.status -eq 'written') "(legacy-migrate) esperado written; obtido $($migrate.status)"
    $migrateInfo = Get-McpOpenCodeEntryInfo -Path $legacy2 -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($migrateInfo.form -eq 'canonical') '(legacy-migrate) forma canonica apos migracao'
    $migrateText = Read-Text -Path $legacy2
    Assert-True ($migrateText -notmatch '"enabled"') '(legacy-migrate) enabled legado removido'
    $migrateAgain = Update-McpOpenCodeConfig -Path $legacy2 -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($migrate.entryHash) -Action install
    Assert-True ($migrateAgain.status -eq 'unchanged') '(legacy-migrate) idempotente apos migracao'

    # 4. As duas formas coexistindo: conflito sem escrita.
    $both = New-Fixture -Name 'both-forms.jsonc'
    $before = Read-Text -Path $both
    $bothResult = Update-McpOpenCodeConfig -Path $both -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($bothResult.status -eq 'entrada_em_conflito') "(both) esperado entrada_em_conflito; obtido $($bothResult.status)"
    Assert-True ((Read-Text -Path $both) -ceq $before) '(both) arquivo intacto'

    # 5. disabled canonico e enabled:false legado sao reconhecidos.
    $disabled = New-Fixture -Name 'disabled-canonical.jsonc'
    $disabledInfo = Get-McpOpenCodeEntryInfo -Path $disabled -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($disabledInfo.disabled -eq $true) '(disabled) disabled=true reconhecido'
    $enabledFalse = New-Fixture -Name 'enabled-false-legacy.jsonc'
    $enabledFalseInfo = Get-McpOpenCodeEntryInfo -Path $enabledFalse -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($enabledFalseInfo.disabled -eq $true) '(enabled-false) enabled=false reconhecido'

    # 6. mcp ausente: insercao e idempotencia.
    $absent = New-Fixture -Name 'mcp-absent.jsonc'
    $insert = Update-McpOpenCodeConfig -Path $absent -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($insert.status -eq 'written') "(absent) esperado written; obtido $($insert.status)"
    $absentInfo = Get-McpOpenCodeEntryInfo -Path $absent -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($absentInfo.form -eq 'canonical') '(absent) entrada canonica criada'
    $insertAgain = Update-McpOpenCodeConfig -Path $absent -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($insert.entryHash) -Action install
    Assert-True ($insertAgain.status -eq 'unchanged') '(absent) idempotente'

    # 7. Outro servidor em mcp.servers e preservado.
    $other = New-Fixture -Name 'mcp-other-servers.jsonc'
    $otherResult = Update-McpOpenCodeConfig -Path $other -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($otherResult.status -eq 'written') "(other) esperado written; obtido $($otherResult.status)"
    $otherText = Read-Text -Path $other
    Assert-True ($otherText -match '"outro"') '(other) servidor outro preservado'

    # 8. Entrada desconhecida: conflito sem escrita.
    $unknown = New-Fixture -Name 'unknown-entry.jsonc'
    $before = Read-Text -Path $unknown
    $unknownResult = Update-McpOpenCodeConfig -Path $unknown -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($unknownResult.status -eq 'conflict') "(unknown) esperado conflict; obtido $($unknownResult.status)"
    Assert-True ((Read-Text -Path $unknown) -ceq $before) '(unknown) arquivo intacto'

    # 9. Chave duplicada: fail-closed.
    $duplicated = New-Fixture -Name 'duplicated-key.jsonc'
    $before = Read-Text -Path $duplicated
    $duplicatedResult = Update-McpOpenCodeConfig -Path $duplicated -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($duplicatedResult.status -eq 'entrada_quebrada') "(duplicated) esperado entrada_quebrada; obtido $($duplicatedResult.status)"
    Assert-True ((Read-Text -Path $duplicated) -ceq $before) '(duplicated) arquivo intacto'

    # 10. Armadilha de comentario: nao confunde chave comentada com entrada.
    $trap = New-Fixture -Name 'comment-trap.jsonc'
    $trapResult = Update-McpOpenCodeConfig -Path $trap -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    Assert-True ($trapResult.status -eq 'written') "(trap) esperado written; obtido $($trapResult.status)"
    $trapText = Read-Text -Path $trap
    Assert-True ($trapText -match 'Armadilha de comentario') '(trap) comentario preservado'

    # 11. Remocao reconhecida e remocao desconhecida.
    $removeTarget = New-Fixture -Name 'mcp-absent.jsonc'
    $removeInstall = Update-McpOpenCodeConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install
    $removeOk = Update-McpOpenCodeConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @($removeInstall.entryHash) -Action remove
    Assert-True ($removeOk.status -eq 'written') "(remove) esperado written; obtido $($removeOk.status)"
    $removeInfo = Get-McpOpenCodeEntryInfo -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model
    Assert-True ($removeInfo.form -eq 'absent') '(remove) entrada ausente apos remocao'
    $removeUnknown = Update-McpOpenCodeConfig -Path $removeTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @('deadbeef') -Action remove
    Assert-True ($removeUnknown.status -eq 'unchanged') '(remove) entrada ausente nao e conflito'
    $unknownRemoveTarget = New-Fixture -Name 'unknown-entry.jsonc'
    $before = Read-Text -Path $unknownRemoveTarget
    $unknownRemove = Update-McpOpenCodeConfig -Path $unknownRemoveTarget -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @('deadbeef') -Action remove
    Assert-True ($unknownRemove.status -eq 'conflict') "(remove-unknown) esperado conflict; obtido $($unknownRemove.status)"
    Assert-True ((Read-Text -Path $unknownRemoveTarget) -ceq $before) '(remove-unknown) arquivo intacto'

    # 12. -WhatIf nao grava.
    $whatIf = New-Fixture -Name 'mcp-absent.jsonc'
    $before = Read-Text -Path $whatIf
    $whatIfResult = Update-McpOpenCodeConfig -Path $whatIf -LauncherPath $launcher -BaseUrl $baseUrl -Model $model -ManifestHashes @() -Action install -WhatIf
    Assert-True ($whatIfResult.status -eq 'planned') "(whatif) esperado planned; obtido $($whatIfResult.status)"
    Assert-True ((Read-Text -Path $whatIf) -ceq $before) '(whatif) arquivo intacto'

    # 13. Dois arquivos de config: conflito de alvo.
    $jsonPath = Join-Path $opencodeDir 'opencode.json'
    $jsoncPath = Join-Path $opencodeDir 'opencode.jsonc'
    [System.IO.File]::WriteAllText($jsonPath, '{ "mcp": {} }', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($jsoncPath, '{ "mcp": {} }', [System.Text.UTF8Encoding]::new($false))
    $target = Get-McpOpenCodeConfigTarget
    Assert-True ($target.status -eq 'conflict') '(two-files) esperado conflict'
    Remove-Item -LiteralPath $jsonPath -Force
    Remove-Item -LiteralPath $jsoncPath -Force
} finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_OPENCODE_ADAPTER_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_OPENCODE_ADAPTER_SELFTEST_OK: $assertCount asserts"
exit 0
