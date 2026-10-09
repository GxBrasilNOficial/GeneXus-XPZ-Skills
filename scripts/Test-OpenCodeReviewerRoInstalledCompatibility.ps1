#requires -Version 7.4
<#
.SYNOPSIS
    Diagnostica a compatibilidade local do opencode reviewer-ro instalado.
.DESCRIPTION
    Nao chama modelo nem rede. Resolve o opencode.exe, verifica a definicao estatica do
    reviewer-ro, compara a versao instalada com os fixtures versionados e confere o allow-set
    efetivo de `opencode agent list`.

    Este script e diagnostico: uma versao nova com allow-set OK retorna status
    needsFixtureRecapture, nao compatible. Para promover a versao, recapture os fixtures
    empiricos exigidos pela xpz-llm-delegate e atualize a versao testada.

    Com bloqueio `static`, `static.divergences` lista TODAS as divergencias e `nextAction` aponta o
    reparo: o instalador (Install-OpenCodeReviewerRoAgent.ps1) quando a fonte e o opencode.jsonc
    global; a correcao do markdown quando a fonte e um project-local.
#>
[CmdletBinding()]
param(
    [string] $OpenCodeExe,
    [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

$exe = Resolve-OpenCodeExe -Override $OpenCodeExe
$cwd = (Get-Location).Path
$installedVersion = Get-OpenCodeVersionFromExe -Exe $exe
$testedVersion = Get-OpenCodeReviewerRoTestedVersion

$static = Test-OpenCodeReviewerRoStatic -WorkingDirectory $cwd
$allow = $null
if ($static.ok) {
    $allow = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $exe
}

$versionKnown = (-not [string]::IsNullOrWhiteSpace($testedVersion)) -and ($installedVersion -eq $testedVersion)
$allowSetOk = $false
$externalDirectoryOk = $false
if ($allow -and $allow.ok) {
    $expected = @($script:OpenCodeReviewerRoExpectedAllowSet | Sort-Object)
    $got = @($allow.allowSet | Sort-Object)
    $allowSetOk = ($null -eq (Compare-Object -ReferenceObject $expected -DifferenceObject $got))
    $allowSetOk = $allowSetOk -and $allow.policyOk
    $externalDirectoryOk = ($allow.externalDirStar -eq 'deny')
}

$blockingReasons = [System.Collections.Generic.List[string]]::new()
if (-not $static.ok) { $blockingReasons.Add('static') }
if ($allow -and -not $allow.ok) { $blockingReasons.Add('agentlist') }
if ($allow -and $allow.ok -and -not $allowSetOk) { $blockingReasons.Add('allowset') }
if ($allow -and $allow.ok -and -not $externalDirectoryOk) { $blockingReasons.Add('external_directory') }

$status = 'blocked'
$nextAction = 'Corrigir os bloqueios estruturais antes de usar reviewer-ro.'
if (-not $static.ok) {
    if ([string]$static.source -like 'global:*') {
        # Definicao global ausente/divergente: o reparo e o instalador (faz backup; -WhatIf antes).
        $installerPath = Join-Path $PSScriptRoot 'Install-OpenCodeReviewerRoAgent.ps1'
        $nextAction = "Reinstalar o reviewer-ro global: pwsh -NoProfile -File `"$installerPath`" -WhatIf; depois sem -WhatIf (faz backup do opencode.jsonc). Em seguida, rodar este diagnostico de novo."
    } else {
        $nextAction = "Corrigir a definicao project-local $($static.source) para o contrato canonico (.opencode/agent/reviewer-ro.md do repositorio GeneXus-XPZ-Skills); o instalador global nao a substitui."
    }
} elseif ($blockingReasons.Count -eq 0) {
    if ($versionKnown) {
        $status = 'compatible'
        $nextAction = 'Pode usar reviewer-ro com esta versao testada.'
    } else {
        $status = 'needsFixtureRecapture'
        $nextAction = 'A configuracao estrutural parece OK, mas a versao instalada ainda nao e a versao dos fixtures. Recapture os fixtures empiricos do reviewer-ro para esta versao antes de promover.'
    }
}

$result = [ordered]@{
    status = $status
    exe = $exe
    installedVersion = $installedVersion
    testedVersion = $testedVersion
    versionKnown = $versionKnown
    workingDirectory = $cwd
    static = $static
    agentList = if ($allow) { $allow } else { $null }
    allowSetOk = $allowSetOk
    externalDirectoryOk = $externalDirectoryOk
    blockingReasons = @($blockingReasons)
    nextAction = $nextAction
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    "status=$status"
    "exe=$exe"
    "installedVersion=$installedVersion"
    "testedVersion=$testedVersion"
    "blockingReasons=$(@($blockingReasons) -join ',')"
    "nextAction=$nextAction"
}

if ($status -eq 'blocked') { exit 20 }
exit 0
