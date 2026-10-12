#requires -Version 7.4

<#
.SYNOPSIS
    Gate mecanico de paridade documental da frente MSBuild probe (pre-push).

.DESCRIPTION
    Executa quando o intervalo pre-push toca GeneXusMsBuildPathContract,
    Test-GeneXusMsBuildSetup, Test-GeneXusMsBuildDiscoveryContract, 10-base MSBuild
    ou xpz-msbuild-import-export/SKILL.md.

    Falhas (severity=fail) bloqueiam o passo mecanico via Invoke-PrePushMechanicalChecks.ps1.
    Avisos (severity=warn) entram em agentWarnings sem bloquear sozinhos.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MsBuildFrontPattern = '(?i)^(scripts/GeneXusMsBuildPathContract\.ps1|scripts/Test-GeneXusMsBuildSetup\.ps1|scripts/Test-GeneXusMsBuildDiscoveryContract\.ps1|10-base-operacional-msbuild-headless\.md|xpz-msbuild-import-export/SKILL\.md)$'

$LegacyPhrasePattern = '(?i)fallback aplicado em caminhos conhecidos do Visual Studio'

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

function Normalize-RepoPath {
    param([string]$Path)

    return (($Path -replace '\\', '/').Trim())
}

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Target,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('warn', 'fail')]
        [string]$Severity = 'warn',

        [string]$Path = $null
    )

    $Target.Add([pscustomobject][ordered]@{
            code     = $Code
            severity = $Severity
            path     = $Path
            message  = $Message
        })
}

function Get-FileText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $fullPath = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $null
    }

    return [System.IO.File]::ReadAllText($fullPath)
}

function Get-MsBuildJsonExampleSections {
    param([string]$TenBaseText)

    $successMarker = 'Exemplo canônico inicial em `JSON`:'
    $blockedMarker = 'Exemplo canônico inicial em caso bloqueado:'
    $restrictionsMarker = 'Restrições de desenho:'

    $successIndex = $TenBaseText.IndexOf($successMarker, [System.StringComparison]::Ordinal)
    $blockedIndex = $TenBaseText.IndexOf($blockedMarker, [System.StringComparison]::Ordinal)
    $restrictionsIndex = $TenBaseText.IndexOf($restrictionsMarker, [System.StringComparison]::Ordinal)

    if ($successIndex -lt 0 -or $blockedIndex -lt 0 -or $restrictionsIndex -lt 0) {
        return $null
    }

    return [pscustomobject]@{
        SuccessChunk  = $TenBaseText.Substring($successIndex, $blockedIndex - $successIndex)
        BlockedChunk  = $TenBaseText.Substring($blockedIndex, $restrictionsIndex - $blockedIndex)
    }
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$normalizedChangedFiles = @(
    $ChangedFiles |
        ForEach-Object { Normalize-RepoPath -Path $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)

if ($normalizedChangedFiles.Count -eq 0) {
    $changedResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', "$BaseRef..HEAD")
    if ($changedResult.ExitCode -ne 0) {
        throw ("Falha ao listar arquivos alterados em {0}..HEAD: {1}" -f $BaseRef, $changedResult.Text)
    }
    $normalizedChangedFiles = @(
        $changedResult.Lines |
            ForEach-Object { Normalize-RepoPath -Path $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

$triggeredFiles = @($normalizedChangedFiles | Where-Object { $_ -match $MsBuildFrontPattern })
if ($triggeredFiles.Count -eq 0) {
    $skipped = [ordered]@{
        status       = 'skipped'
        baseRef      = $BaseRef
        changedFiles = @($normalizedChangedFiles)
        triggeredFiles = @()
        findings     = @()
    }
    if ($AsJson) {
        [pscustomobject]$skipped | ConvertTo-Json -Depth 6
    } else {
        Write-Output 'MSBUILD_PROBE_DOC_PARITY=skipped'
    }
    exit 0
}

$findings = [System.Collections.Generic.List[object]]::new()
$tenBaseRelative = '10-base-operacional-msbuild-headless.md'
$skillRelative = 'xpz-msbuild-import-export/SKILL.md'
$tenBaseText = Get-FileText -RepositoryRoot $resolvedRoot -RelativePath $tenBaseRelative
$skillText = Get-FileText -RepositoryRoot $resolvedRoot -RelativePath $skillRelative

if (-not [string]::IsNullOrWhiteSpace($tenBaseText)) {
    $sections = Get-MsBuildJsonExampleSections -TenBaseText $tenBaseText
    if ($null -ne $sections) {
        $successHasProbe = $sections.SuccessChunk -match 'msBuildProbe'
        $blockedHasProbe = $sections.BlockedChunk -match 'msBuildProbe'
        if ($successHasProbe -and -not $blockedHasProbe) {
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_JSON_EXAMPLE_BLOCKED_MISSING' `
                -Path $tenBaseRelative `
                -Message 'O exemplo JSON de sucesso em 10-base contem msBuildProbe, mas o exemplo bloqueado nao; espelhar ambos.'
        }
        if (-not $successHasProbe -and $blockedHasProbe) {
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_JSON_EXAMPLE_SUCCESS_MISSING' `
                -Path $tenBaseRelative `
                -Message 'O exemplo JSON bloqueado em 10-base contem msBuildProbe, mas o exemplo de sucesso nao; espelhar ambos.'
        }
    }
}

$motorSurfaceChanged = @(
    $triggeredFiles | Where-Object {
        $_ -match '(?i)^scripts/GeneXusMsBuildPathContract\.ps1$' -or
        $_ -match '(?i)^scripts/Test-GeneXusMsBuildSetup\.ps1$'
    }
).Count -gt 0

if ($motorSurfaceChanged) {
    $docSurfaces = @(
        @{ Path = $tenBaseRelative; Text = $tenBaseText }
        @{ Path = $skillRelative; Text = $skillText }
    )
    foreach ($surface in $docSurfaces) {
        if ([string]::IsNullOrWhiteSpace($surface.Text)) {
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_DOC_SURFACE_MISSING' `
                -Path $surface.Path `
                -Message ("{0} ausente ou ilegivel enquanto o motor/probe MSBuild mudou no intervalo." -f $surface.Path)
            continue
        }

        $hasProbeToken = $surface.Text -match 'msBuildProbe'
        $hasDiscoveryHint = $surface.Text -match 'vswhere|Test-GeneXusMsBuildDiscoveryContract'
        if (-not $hasProbeToken -or -not $hasDiscoveryHint) {
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_DOC_SURFACE_INCOMPLETE' `
                -Path $surface.Path `
                -Message ("{0} deve mencionar msBuildProbe e vswhere ou Test-GeneXusMsBuildDiscoveryContract apos mudanca no motor/probe." -f $surface.Path)
        }
    }
}

if ($triggeredFiles -contains $skillRelative -and -not [string]::IsNullOrWhiteSpace($skillText)) {
    $inventoryMatch = [regex]::Match(
        $skillText,
        '(?is)Scripts nesta frente:\s*(?<body>.*?)(?:\r?\n- `Open-GeneXusKbHeadless\.ps1`|\r?\n## |\z)'
    )
    if ($inventoryMatch.Success) {
        $inventoryBody = $inventoryMatch.Groups['body'].Value
        $setupMention = $inventoryBody -match 'Test-GeneXusMsBuildSetup\.ps1'
        $inventoryComplete = $inventoryBody -match 'msBuildProbe|Test-GeneXusMsBuildDiscoveryContract\.ps1'
        if ($setupMention -and -not $inventoryComplete) {
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_SKILL_INVENTORY_INCOMPLETE' `
                -Path $skillRelative `
                -Message 'xpz-msbuild-import-export/SKILL.md lista Test-GeneXusMsBuildSetup.ps1 em Scripts nesta frente sem msBuildProbe nem Test-GeneXusMsBuildDiscoveryContract.ps1.'
        }
    }
}

foreach ($triggeredPath in $triggeredFiles) {
    $diffResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $triggeredPath)
    if ($diffResult.ExitCode -ne 0) {
        continue
    }

    $addedLines = @($diffResult.Lines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' })
    $addedText = ($addedLines -join [Environment]::NewLine)
    if ($addedText -match $LegacyPhrasePattern) {
        Add-Finding -Target $findings -Severity 'warn' -Code 'MSBUILD_PROBE_LEGACY_PHRASE_IN_DIFF' `
            -Path $triggeredPath `
            -Message ("Diff de {0} reintroduz frase legada de fallback MSBuild; usar descoberta via vswhere + catalogo estatico." -f $triggeredPath)
    }
}

$runDiscoveryContract = @(
    $triggeredFiles | Where-Object {
        $_ -match '(?i)^scripts/GeneXusMsBuildPathContract\.ps1$' -or
        $_ -match '(?i)^scripts/Test-GeneXusMsBuildDiscoveryContract\.ps1$'
    }
).Count -gt 0

if ($runDiscoveryContract) {
    $discoveryScript = Join-Path $PSScriptRoot 'Test-GeneXusMsBuildDiscoveryContract.ps1'
    if (-not (Test-Path -LiteralPath $discoveryScript -PathType Leaf)) {
        Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_DISCOVERY_CONTRACT_MISSING' `
            -Path 'scripts/Test-GeneXusMsBuildDiscoveryContract.ps1' `
            -Message 'Test-GeneXusMsBuildDiscoveryContract.ps1 nao encontrado enquanto o contrato MSBuild mudou.'
    } else {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $discoveryOutput = & $discoveryScript 2>&1
        $discoveryExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction
        if ($discoveryExitCode -ne 0) {
            $detail = ($discoveryOutput | ForEach-Object { $_.ToString() }) -join '; '
            Add-Finding -Target $findings -Severity 'fail' -Code 'MSBUILD_PROBE_DISCOVERY_CONTRACT_FAILED' `
                -Path 'scripts/Test-GeneXusMsBuildDiscoveryContract.ps1' `
                -Message ("Test-GeneXusMsBuildDiscoveryContract.ps1 falhou (exit {0}): {1}" -f $discoveryExitCode, $detail)
        }
    }
}

$hasFail = @($findings | Where-Object { $_.severity -eq 'fail' }).Count -gt 0
$hasWarn = @($findings | Where-Object { $_.severity -eq 'warn' }).Count -gt 0
$status = if ($hasFail) { 'fail' } elseif ($hasWarn) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status         = $status
    baseRef        = $BaseRef
    changedFiles   = @($normalizedChangedFiles)
    triggeredFiles = @($triggeredFiles)
    findings       = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("MSBUILD_PROBE_DOC_PARITY={0}" -f $status)
    foreach ($finding in $findings) {
        Write-Output ("MSBUILD_PROBE_DOC_PARITY_FINDING: {0} [{1}]: {2}" -f $finding.code, $finding.severity, $finding.message)
    }
}

exit 0
