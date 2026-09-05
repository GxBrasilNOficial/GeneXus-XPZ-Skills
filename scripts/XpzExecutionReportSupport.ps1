#requires -Version 7.4
<#
.SYNOPSIS
    Suporte privado ao relatorio de execucao do empacotamento XPZ.

.DESCRIPTION
    Mantem a publicacao atomica, a validacao de caminho e o historico de fases
    do relatorio xpz-package-execution-report. O wrapper e o dono das fases de
    preflight e pos-inventario; o motor Python recebe o mesmo arquivo e pode
    atualizar apenas o intervalo em que esta executando.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-XpzReportUtcNow {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-XpzCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [IO.Path]::GetFullPath($Path)
}

function Test-XpzPathEqualOrUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $candidateFull = Get-XpzCanonicalPath -Path $Candidate
    $baseFull = Get-XpzCanonicalPath -Path $Base
    if ($candidateFull.Equals($baseFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $basePrefix = $baseFull.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-XpzReparsePointInPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $cursor = Get-XpzCanonicalPath -Path $Path
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $item.FullName
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent -or $parent.FullName.Equals($cursor, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $cursor = $parent.FullName
    }
    return $null
}

function Test-XpzForbiddenReportArea {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $forbidden = @(
        (Join-Path $RepoRoot 'ObjetosDaKbEmXml'),
        (Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus'),
        (Join-Path $RepoRoot 'XpzExportadosPelaIDE'),
        (Join-Path $RepoRoot 'scripts'),
        (Join-Path $RepoRoot 'KbIntelligence'),
        (Join-Path $RepoRoot '.git'),
        (Join-Path $RepoRoot 'ArquivoMorto'),
        (Join-Path $RepoRoot 'kb-source-metadata.md')
    )
    foreach ($area in $forbidden) {
        if (Test-XpzPathEqualOrUnder -Candidate $Candidate -Base $area) {
            return [pscustomobject]@{ blocked = $true; reason = "ReportPath pertence a area proibida: $area" }
        }
    }
    return [pscustomobject]@{ blocked = $false; reason = $null }
}

function Test-XpzReportPathSafety {
    param(
        [Parameter(Mandatory = $true)][string]$ReportPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedPackagePath,
        [switch]$AllowExistingTarget
    )

    if (-not [IO.Path]::IsPathRooted($ReportPath)) {
        return [pscustomobject]@{ valid = $false; path = $null; reason = 'ReportPath deve ser absoluto' }
    }
    if (-not $ReportPath.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ valid = $false; path = $null; reason = 'ReportPath deve terminar em .json' }
    }

    try {
        $candidate = Get-XpzCanonicalPath -Path $ReportPath
        $repo = Get-XpzCanonicalPath -Path $RepoRoot
        $expected = Get-XpzCanonicalPath -Path $ExpectedPackagePath
    } catch {
        return [pscustomobject]@{ valid = $false; path = $null; reason = "ReportPath nao pode ser normalizado: $($_.Exception.Message)" }
    }

    $parent = [IO.Directory]::GetParent($candidate)
    if ($null -eq $parent -or -not (Test-Path -LiteralPath $parent.FullName -PathType Container)) {
        return [pscustomobject]@{ valid = $false; path = $candidate; reason = 'a pasta pai de ReportPath deve existir' }
    }
    $reparse = Get-XpzReparsePointInPath -Path $candidate
    if ($null -ne $reparse) {
        return [pscustomobject]@{ valid = $false; path = $candidate; reason = "ReportPath ou um componente pai e ponto de reanalise: $reparse" }
    }
    $forbidden = Test-XpzForbiddenReportArea -Candidate $candidate -RepoRoot $repo
    if ($forbidden.blocked) {
        return [pscustomobject]@{ valid = $false; path = $candidate; reason = $forbidden.reason }
    }

    $collisionPaths = @(
        $expected,
        ($expected + '.package-inventory.json')
    )
    foreach ($collisionPath in $collisionPaths) {
        if ($candidate.Equals($collisionPath, [StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ valid = $false; path = $candidate; reason = "ReportPath colide com artefato do pacote: $collisionPath" }
        }
    }
    $rejectedPrefix = $expected + '.rejected.'
    if ($candidate.StartsWith($rejectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ valid = $false; path = $candidate; reason = 'ReportPath colide com artefato rejeitado do pacote' }
    }

    $exists = Test-Path -LiteralPath $candidate
    if ($exists) {
        if (-not $AllowExistingTarget) {
            return [pscustomobject]@{ valid = $false; path = $candidate; reason = 'ReportPath ja existe; informe um destino novo' }
        }
        $item = Get-Item -LiteralPath $candidate -Force
        if (-not $item.PSIsContainer -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)) {
            return [pscustomobject]@{ valid = $true; path = $candidate; reason = $null }
        }
        return [pscustomobject]@{ valid = $false; path = $candidate; reason = 'ReportPath existente nao e arquivo regular' }
    }
    return [pscustomobject]@{ valid = $true; path = $candidate; reason = $null }
}

function ConvertTo-XpzReportJsonValue {
    param([Parameter(Mandatory = $true)][object]$Value)

    return ($Value | ConvertTo-Json -Depth 20)
}

function Write-XpzReportFileAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Json,
        [switch]$ReplaceExisting
    )

    $tempPath = "$Path.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    $encoding = [Text.UTF8Encoding]::new($false)
    $stream = $null
    try {
        $stream = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $bytes = $encoding.GetBytes($Json)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if ($ReplaceExisting) {
            [IO.File]::Move($tempPath, $Path, $true)
        } else {
            [IO.File]::Move($tempPath, $Path)
        }
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-XpzExecutionReportContext {
    param(
        [Parameter(Mandatory = $true)][string]$ReportPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FrontName,
        [Parameter(Mandatory = $true)][string]$NN,
        [Parameter(Mandatory = $true)][string]$ExpectedPackagePath,
        [Parameter(Mandatory = $true)][string]$RunId
    )

    $safety = Test-XpzReportPathSafety -ReportPath $ReportPath -RepoRoot $RepoRoot -ExpectedPackagePath $ExpectedPackagePath
    if (-not $safety.valid) {
        throw $safety.reason
    }
    $now = Get-XpzReportUtcNow
    $document = [ordered]@{
        Kind                    = 'xpz-package-execution-report'
        SchemaVersion           = 1
        runId                   = $RunId
        repoRoot                = (Get-XpzCanonicalPath -Path $RepoRoot)
        frontName               = $FrontName
        nn                      = $NN
        executionState          = 'running'
        currentStage            = 'validate-input'
        startedAtUtc             = $now
        updatedAtUtc             = $now
        completedAtUtc           = $null
        stageHistory             = @([ordered]@{ stage = 'validate-input'; atUtc = $now; writer = 'powershell'; note = 'execucao iniciada' })
        processExitCode          = $null
        resultExitCode           = $null
        packageState             = 'not-written'
        packageWritten           = $false
        packagePath              = (Get-XpzCanonicalPath -Path $ExpectedPackagePath)
        rejectedPath             = $null
        inventoryDecision        = 'not-run'
        inventoryStatus          = $null
        deltaStatus              = $null
        contentReviewRequired    = $null
        contentReviewReasons     = @()
        stderrTail               = ''
        stderrTruncated          = $false
        stdoutNoiseDetected      = $false
        warnings                 = @()
        errors                   = @()
        lastWriter               = 'powershell'
    }
    $context = [pscustomobject]@{
        Path = $safety.path
        RepoRoot = (Get-XpzCanonicalPath -Path $RepoRoot)
        ExpectedPackagePath = (Get-XpzCanonicalPath -Path $ExpectedPackagePath)
        RunId = $RunId
        Document = $document
    }
    Write-XpzReportFileAtomic -Path $context.Path -Json (ConvertTo-XpzReportJsonValue -Value $document)
    return $context
}

function Update-XpzExecutionReport {
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [string]$Stage,
        [string]$Writer = 'powershell',
        [string]$Note,
        [hashtable]$Values
    )

    $safety = Test-XpzReportPathSafety -ReportPath $Context.Path -RepoRoot $Context.RepoRoot -ExpectedPackagePath $Context.ExpectedPackagePath -AllowExistingTarget
    if (-not $safety.valid) {
        throw $safety.reason
    }
    [void](Get-XpzExecutionReportSnapshot -Context $Context)
    $now = Get-XpzReportUtcNow
    if (-not [string]::IsNullOrWhiteSpace($Stage) -and [string]$Context.Document.currentStage -ne $Stage) {
        $history = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in @($Context.Document.stageHistory)) { [void]$history.Add($entry) }
        [void]$history.Add([ordered]@{ stage = $Stage; atUtc = $now; writer = $Writer; note = $Note })
        if ($history.Count -gt 16) {
            $kept = [System.Collections.Generic.List[object]]::new()
            [void]$kept.Add($history[0])
            foreach ($entry in $history | Select-Object -Skip ($history.Count - 15)) { [void]$kept.Add($entry) }
            $history = $kept
        }
        $Context.Document.stageHistory = @($history)
        $Context.Document.currentStage = $Stage
    }
    if ($null -ne $Values) {
        foreach ($key in $Values.Keys) { $Context.Document[$key] = $Values[$key] }
    }
    $Context.Document.updatedAtUtc = $now
    $Context.Document.lastWriter = $Writer
    Write-XpzReportFileAtomic -Path $Context.Path -Json (ConvertTo-XpzReportJsonValue -Value $Context.Document) -ReplaceExisting
}

function Set-XpzExecutionReportHeartbeat {
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Writer,
        [Parameter(Mandatory = $true)][string]$Progress
    )

    $Context.Document.progress = $Progress
    Update-XpzExecutionReport -Context $Context -Stage $Stage -Writer $Writer -Values @{ progress = $Progress }
}

function Get-XpzExecutionReportSnapshot {
    param([Parameter(Mandatory = $true)][object]$Context)

    $safety = Test-XpzReportPathSafety -ReportPath $Context.Path -RepoRoot $Context.RepoRoot -ExpectedPackagePath $Context.ExpectedPackagePath -AllowExistingTarget
    if (-not $safety.valid) { throw $safety.reason }
    $raw = [IO.File]::ReadAllText($Context.Path, [Text.UTF8Encoding]::new($false))
    $snapshot = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($snapshot.Kind -ne 'xpz-package-execution-report' -or [int]$snapshot.SchemaVersion -ne 1 -or [string]$snapshot.runId -ne $Context.RunId) {
        throw 'relatorio de execucao ausente, corrompido ou com runId divergente'
    }
    return $snapshot
}

function Complete-XpzExecutionReport {
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$ExecutionState,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][int]$ResultExitCode,
        [int]$ProcessExitCode,
        [string]$PackageState,
        [string]$InventoryDecision,
        [hashtable]$Values
    )

    $allValues = @{}
    if ($null -ne $Values) {
        foreach ($key in $Values.Keys) { $allValues[$key] = $Values[$key] }
    }
    $allValues['executionState'] = $ExecutionState
    $allValues['completedAtUtc'] = Get-XpzReportUtcNow
    $allValues['resultExitCode'] = $ResultExitCode
    if ($PSBoundParameters.ContainsKey('ProcessExitCode')) { $allValues['processExitCode'] = $ProcessExitCode }
    if ($PSBoundParameters.ContainsKey('PackageState')) { $allValues['packageState'] = $PackageState }
    if ($PSBoundParameters.ContainsKey('InventoryDecision')) { $allValues['inventoryDecision'] = $InventoryDecision }
    Update-XpzExecutionReport -Context $Context -Stage $Stage -Writer 'powershell' -Note 'execucao encerrada' -Values $allValues
}
