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

    -WorkingDirectory define a pasta usada pela checagem estatica E pelo `opencode agent list` (o
    opencode descobre o project-local a partir dela). Default: a pasta atual.

    -ExpectGlobal (auditoria da instalacao GLOBAL, ex.: xpz-skills-setup): exige que a pasta seja
    neutra. Recusa (status invalidVantage, exit 21, sem rodar o agent list) quando a pasta esta dentro
    de um repositorio git ou quando a busca subindo pelas pastas acha um project-local — nesses casos
    o resultado nao mediria a configuracao global. Nunca imprime o conteudo do opencode.jsonc.
#>
[CmdletBinding()]
param(
    [string] $OpenCodeExe,
    [string] $WorkingDirectory,
    [switch] $ExpectGlobal,
    [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

function Find-GitMarkerUpward {
    <# Sobe a partir de $Path procurando `.git` (pasta ou arquivo de worktree). Devolve o caminho ou $null. #>
    param([Parameter(Mandatory)] [string] $Path)
    $dir = $Path
    while (-not [string]::IsNullOrEmpty($dir)) {
        $candidate = Join-Path $dir '.git'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

$exe = Resolve-OpenCodeExe -Override $OpenCodeExe
if ([string]::IsNullOrEmpty($WorkingDirectory)) {
    $cwd = (Get-Location).Path
} else {
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        throw "BLOCK: -WorkingDirectory inexistente: $WorkingDirectory"
    }
    $cwd = (Resolve-Path -LiteralPath $WorkingDirectory).Path
}
$installedVersion = Get-OpenCodeVersionFromExe -Exe $exe
$testedVersion = Get-OpenCodeReviewerRoTestedVersion

$static = Test-OpenCodeReviewerRoStatic -WorkingDirectory $cwd
$sourceKind = $null
if ($static.source) {
    $sourceKind = if ([string]$static.source -like 'global:*') { 'global' } else { 'project-local' }
}

$vantage = $null
if ($ExpectGlobal) {
    $gitMarker = Find-GitMarkerUpward -Path $cwd
    $vantageProblems = [System.Collections.Generic.List[string]]::new()
    if ($gitMarker) { $vantageProblems.Add("pasta dentro de repositorio git ($gitMarker)") }
    if ($sourceKind -ne 'global') { $vantageProblems.Add("fonte da definicao nao e a global ($($static.source))") }
    $vantage = [ordered]@{
        expectGlobal = $true
        insideGitRepo = [bool]$gitMarker
        sourceKind = $sourceKind
        ok = ($vantageProblems.Count -eq 0)
        problems = @($vantageProblems)
    }
}

$allow = $null
if ($static.ok -and -not ($vantage -and -not $vantage.ok)) {
    $allow = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $exe -WorkingDirectory $cwd
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
if ($vantage -and -not $vantage.ok) {
    $status = 'invalidVantage'
    $nextAction = "Resultado recusado: a pasta '$cwd' nao mede a instalacao global ($($vantage.problems -join '; ')). Repetir com -WorkingDirectory numa pasta vazia fora de repositorio git e sem .opencode/agent/reviewer-ro.md nas pastas acima."
} elseif (-not $static.ok) {
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
    sourceKind = $sourceKind
    vantage = $vantage
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
    "source=$($static.source)"
    "blockingReasons=$(@($blockingReasons) -join ',')"
    "nextAction=$nextAction"
}

if ($status -eq 'invalidVantage') { exit 21 }
if ($status -eq 'blocked') { exit 20 }
exit 0
