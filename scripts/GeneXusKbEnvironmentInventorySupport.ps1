#requires -Version 7.4

<#
.SYNOPSIS
    Inventario de environments GeneXus via MSBuild (SetActiveEnvironment) sobre lista explicita.

.DESCRIPTION
    Valida nomes declarados pelo usuário com SetActiveEnvironment headless.
    Scan automático de pastas da KB nativa foi removido (superestimava environments _bad, hotfix, etc.).
    Get-GeneXusKbNativeFolderEnvironmentProbeExcludeReason permanece para gates de metadata legado.
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Get-GeneXusKbNativeFolderEnvironmentProbeExcludeReason {
    param([string]$FolderName)

    if ([string]::IsNullOrWhiteSpace($FolderName)) {
        return 'nome vazio'
    }

    $trimmed = $FolderName.Trim()
    if ($trimmed.StartsWith('.')) {
        return 'pasta oculta ou reservada'
    }

    $exactExcluded = @(
        'CSSLibraries'
        'UserControls'
        'SDTs'
        'Modules'
        'Templates'
        'Images'
        'Logs'
        'Library'
        'Media'
        'Resources'
        'JavaStubs'
        'Web'
    )

    foreach ($exact in $exactExcluded) {
        if ($trimmed -ieq $exact) {
            return ("pasta estrutural '{0}' — nao e environment GeneXus" -f $exact)
        }
    }

    $prefixExcluded = @(
        'CSharpModel'
        'CSharp'
        'Data'
        'DATA'
        'backup'
        'Backup'
        'Temp'
        'temp'
    )

    foreach ($prefix in $prefixExcluded) {
        if ($trimmed.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return ("prefixo legado/estrutural '{0}'" -f $prefix)
        }
    }

    return $null
}

function Get-GeneXusKbEnvironmentNameCandidatesFromNativePath {
    param(
        [string]$KbNativePath,
        [string[]]$AdditionalCandidateNames = @()
    )

    if ([string]::IsNullOrWhiteSpace($KbNativePath) -or -not (Test-Path -LiteralPath $KbNativePath -PathType Container)) {
        throw "BLOCK: KbNativePath invalido para candidatos de environment: $KbNativePath"
    }

    $nativeRoot = [System.IO.Path]::GetFullPath($KbNativePath)
    $candidateSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $excluded = New-Object System.Collections.Generic.List[object]

    foreach ($child in Get-ChildItem -LiteralPath $nativeRoot -Directory -ErrorAction SilentlyContinue) {
        $excludeReason = Get-GeneXusKbNativeFolderEnvironmentProbeExcludeReason -FolderName $child.Name
        if ($excludeReason) {
            $excluded.Add([ordered]@{
                    folderName = $child.Name
                    reason       = $excludeReason
                }) | Out-Null
            continue
        }

        [void]$candidateSet.Add($child.Name.Trim())
    }

    foreach ($extra in $AdditionalCandidateNames) {
        if (-not [string]::IsNullOrWhiteSpace($extra)) {
            [void]$candidateSet.Add($extra.Trim())
        }
    }

    return [pscustomobject][ordered]@{
        kbNativePath = $nativeRoot
        candidates   = @($candidateSet | Sort-Object)
        excluded     = $excluded.ToArray()
    }
}


function Escape-GeneXusKbEnvironmentInventoryXml {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Value)
}

function New-GeneXusKbEnvironmentInventoryArtifactDirectory {
    param([string]$BaseDirectory)

    $artifactDirectory = Join-Path $BaseDirectory ('gx-env-inventory-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function New-GeneXusKbEnvironmentRegistrationProbeProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$CandidateEnvironmentName,
        [string]$DatabaseUser,
        [string]$DatabasePassword
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped = Escape-GeneXusKbEnvironmentInventoryXml -Value $targetsPath
    $kbPathEscaped = Escape-GeneXusKbEnvironmentInventoryXml -Value $ResolvedKbPath
    $environmentEscaped = Escape-GeneXusKbEnvironmentInventoryXml -Value $CandidateEnvironmentName
    $databaseUserEscaped = Escape-GeneXusKbEnvironmentInventoryXml -Value $DatabaseUser
    $databasePasswordEscaped = Escape-GeneXusKbEnvironmentInventoryXml -Value $DatabasePassword

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <DatabaseUser>$databaseUserEscaped</DatabaseUser>
    <DatabasePassword>$databasePasswordEscaped</DatabasePassword>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" CaptureOutput="true" DatabaseUser="`$(DatabaseUser)" DatabasePassword="`$(DatabasePassword)">
      <Output TaskParameter="TaskOutput" PropertyName="OpenOutput" />
    </OpenKnowledgeBase>
    <SetActiveEnvironment EnvironmentName="`$(KBEnvironment)" />
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <Message Text="__ACTIVE_ENVIRONMENT__=`$(ActiveEnvironmentOutput)" Importance="High" />
    <CloseKnowledgeBase />
    <OnError ExecuteTargets="CloseOnError" />
  </Target>
</Project>
"@
}

function Invoke-GeneXusKbEnvironmentRegistrationProbeProcess {
    param(
        [string]$ResolvedMsBuildPath,
        [string]$MsBuildFilePath,
        [string]$StdOutPath,
        [string]$StdErrPath
    )

    $arguments = @(
        $MsBuildFilePath
        '/nologo'
        '/verbosity:minimal'
        '/nodeReuse:false'
        '/target:Run'
    )

    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -NoNewWindow -PassThru -Wait
    return $process.ExitCode
}

function Read-GeneXusKbEnvironmentInventoryTextFile {
    param([string]$PathValue)

    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($PathValue)
}

function Test-GeneXusKbEnvironmentRegisteredFromProbeOutput {
    param(
        [string]$CandidateEnvironmentName,
        [string]$StdOutText,
        [string]$StdErrText
    )

    $combined = ($StdOutText + [Environment]::NewLine + $StdErrText)
    $setEnvironmentFailed = [bool]($combined -match 'Set Active Environment falhou')
    $missingMatch = [regex]::Match($combined, "Ambiente '([^']+)' n[aã]o existe", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $activeMatch = [regex]::Match($combined, "The active environment is '([^']+)'", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $activeEnvironment = $null
    if ($activeMatch.Success) {
        $activeEnvironment = $activeMatch.Groups[1].Value.Trim()
    }

    $registered = (-not $setEnvironmentFailed) -and
        (-not [string]::IsNullOrWhiteSpace($activeEnvironment)) -and
        ($activeEnvironment -ieq $CandidateEnvironmentName)

    if ($missingMatch.Success -and ($missingMatch.Groups[1].Value.Trim() -ieq $CandidateEnvironmentName)) {
        $registered = $false
    }

    return [pscustomobject][ordered]@{
        registered              = $registered
        activeEnvironment       = $activeEnvironment
        setEnvironmentFailed    = $setEnvironmentFailed
        missingEnvironmentName  = if ($missingMatch.Success) { $missingMatch.Groups[1].Value.Trim() } else { $null }
    }
}

function Invoke-GeneXusKbEnvironmentRegistrationProbe {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedMsBuildPath,
        [string]$ResolvedKbPath,
        [string]$WorkingDirectory,
        [string]$CandidateEnvironmentName,
        [string]$DatabaseUser,
        [string]$DatabasePassword
    )

    $artifactDirectory = New-GeneXusKbEnvironmentInventoryArtifactDirectory -BaseDirectory $WorkingDirectory
    $msBuildFilePath = Join-Path $artifactDirectory 'probe-environment.msbuild'
    $stdOutPath = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-GeneXusKbEnvironmentRegistrationProbeProjectContent `
        -ResolvedGeneXusDir $ResolvedGeneXusDir `
        -ResolvedKbPath $ResolvedKbPath `
        -CandidateEnvironmentName $CandidateEnvironmentName `
        -DatabaseUser $DatabaseUser `
        -DatabasePassword $DatabasePassword

    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))

    $msBuildExitCode = Invoke-GeneXusKbEnvironmentRegistrationProbeProcess `
        -ResolvedMsBuildPath $ResolvedMsBuildPath `
        -MsBuildFilePath $msBuildFilePath `
        -StdOutPath $stdOutPath `
        -StdErrPath $stdErrPath

    $stdOutText = Read-GeneXusKbEnvironmentInventoryTextFile -PathValue $stdOutPath
    $stdErrText = Read-GeneXusKbEnvironmentInventoryTextFile -PathValue $stdErrPath
    $interpretation = Test-GeneXusKbEnvironmentRegisteredFromProbeOutput `
        -CandidateEnvironmentName $CandidateEnvironmentName `
        -StdOutText $stdOutText `
        -StdErrText $stdErrText

    return [pscustomobject][ordered]@{
        candidateEnvironmentName = $CandidateEnvironmentName
        registered               = $interpretation.registered
        msBuildExitCode          = $msBuildExitCode
        activeEnvironment        = $interpretation.activeEnvironment
        setEnvironmentFailed     = $interpretation.setEnvironmentFailed
        missingEnvironmentName   = $interpretation.missingEnvironmentName
        artifacts                = [ordered]@{
            msBuildFilePath = $msBuildFilePath
            stdOutPath      = $stdOutPath
            stdErrPath      = $stdErrPath
        }
    }
}

function Invoke-GeneXusKbMsBuildSetupProbe {
    param(
        [string]$WorkingDirectory,
        [string]$LogPath,
        [string]$KbPath,
        [string]$GeneXusDir,
        [string]$MsBuildPath,
        [switch]$VerboseLog
    )

    $probeScriptPath = Join-Path $PSScriptRoot 'Test-GeneXusMsBuildSetup.ps1'
    if (-not (Test-Path -LiteralPath $probeScriptPath -PathType Leaf)) {
        throw "BLOCK: probe MSBuild ausente: $probeScriptPath"
    }

    $probeArgs = @{
        WorkingDirectory = $WorkingDirectory
        LogPath          = $LogPath
        KbPath           = $KbPath
    }

    if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) {
        $probeArgs['GeneXusDir'] = $GeneXusDir
    }
    if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) {
        $probeArgs['MsBuildPath'] = $MsBuildPath
    }
    if ($VerboseLog.IsPresent) {
        $probeArgs['VerboseLog'] = $true
    }

    $probeOutput = & $probeScriptPath @probeArgs
    $probeExitCode = $LASTEXITCODE
    $probeJson = ($probeOutput -join [Environment]::NewLine)
    $probeDiagnostic = $probeJson | ConvertFrom-Json -Depth 8

    return [pscustomobject][ordered]@{
        ExitCode    = $probeExitCode
        Json        = $probeJson
        Diagnostic  = $probeDiagnostic
    }
}

function Get-GeneXusKbRegisteredEnvironmentNamesFromMsBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$KbNativePath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [string]$LogPath,

        [string]$GeneXusDir,

        [string]$MsBuildPath,

        [Parameter(Mandatory = $true)]
        [string[]]$CandidateNames,

        [string]$DatabaseUser,

        [string]$DatabasePassword,

        [switch]$VerboseLog
    )

    $resolvedWorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
    if (-not (Test-Path -LiteralPath $resolvedWorkingDirectory -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($resolvedWorkingDirectory) | Out-Null
    }

    $resolvedLogPath = $LogPath
    if ([string]::IsNullOrWhiteSpace($resolvedLogPath)) {
        $resolvedLogPath = Join-Path $resolvedWorkingDirectory ('gx-env-inventory-' + [System.Guid]::NewGuid().ToString('N') + '.json')
    } else {
        $resolvedLogPath = [System.IO.Path]::GetFullPath($resolvedLogPath)
    }

    $candidatePack = $null
    if (-not $CandidateNames -or $CandidateNames.Count -eq 0) {
        throw 'BLOCK: informe -CandidateNames com a lista explicita de environments declarados pelo usuario. Scan de pastas da KB nativa foi removido.'
    }

    $candidateSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $CandidateNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$candidateSet.Add($name.Trim())
        }
    }

    if ($candidateSet.Count -eq 0) {
        throw 'BLOCK: -CandidateNames vazio ou invalido.'
    }

    $candidatePack = [pscustomobject][ordered]@{
        kbNativePath = [System.IO.Path]::GetFullPath($KbNativePath)
        candidates   = @($candidateSet | Sort-Object)
        excluded     = @()
    }

    if ($candidatePack.candidates.Count -eq 0) {
        throw ("BLOCK: nenhum candidato a environment apos pre-filtro em {0}." -f $candidatePack.kbNativePath)
    }

    $probeStage = Invoke-GeneXusKbMsBuildSetupProbe `
        -WorkingDirectory $resolvedWorkingDirectory `
        -LogPath $resolvedLogPath `
        -KbPath $KbNativePath `
        -GeneXusDir $GeneXusDir `
        -MsBuildPath $MsBuildPath `
        -VerboseLog:$VerboseLog

    if ($probeStage.ExitCode -ne 0) {
        throw 'BLOCK: probe MSBuild nao apto para inventario de environments GeneXus.'
    }

    $resolvedGeneXusDir = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath = [string]$probeStage.Diagnostic.resolvedPaths.KbPath

    $registeredNames = New-Object System.Collections.Generic.List[string]
    $probeResults = New-Object System.Collections.Generic.List[object]

    foreach ($candidate in $candidatePack.candidates) {
        $probeResult = Invoke-GeneXusKbEnvironmentRegistrationProbe `
            -ResolvedGeneXusDir $resolvedGeneXusDir `
            -ResolvedMsBuildPath $resolvedMsBuildPath `
            -ResolvedKbPath $resolvedKbPath `
            -WorkingDirectory $resolvedWorkingDirectory `
            -CandidateEnvironmentName $candidate `
            -DatabaseUser $DatabaseUser `
            -DatabasePassword $DatabasePassword

        $probeResults.Add($probeResult) | Out-Null
        if ($probeResult.registered) {
            $registeredNames.Add($candidate) | Out-Null
        }
    }

    if ($registeredNames.Count -eq 0) {
        throw 'BLOCK: validacao MSBuild nao confirmou nenhum environment declarado. Verifique nomes com o usuario ou indisponibilidade da sondagem headless.'
    }

    return [pscustomobject][ordered]@{
        status                 = 'KB_ENVIRONMENT_INVENTORY_OK'
        kbNativePath           = $resolvedKbPath
        kb_environment_names   = @($registeredNames | Sort-Object)
        kb_environment_count   = $registeredNames.Count
        candidatesConsidered   = @($candidatePack.candidates)
        excludedNativeFolders  = @($candidatePack.excluded)
        probeResults           = $probeResults.ToArray()
        resolvedPaths          = [ordered]@{
            geneXusDir         = $resolvedGeneXusDir
            msBuildPath        = $resolvedMsBuildPath
            workingDirectory   = $resolvedWorkingDirectory
            logPath            = $resolvedLogPath
        }
    }
}
