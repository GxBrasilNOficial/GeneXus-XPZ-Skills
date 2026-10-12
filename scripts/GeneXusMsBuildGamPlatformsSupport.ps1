#requires -Version 7.4

<#
.SYNOPSIS
    Filtro de ruido GAM/NetCore em stdout e hints consultivos de remediacao NTFS.

.DESCRIPTION
    Linhas de error MSB3491 ou NuGet.targets com acesso negado sob Library\GAM\Platforms
    da instalacao GeneXus são ruido estrutural quando o build não roda elevado.
    Quando pelo menos uma linha e filtrada, New-GamPlatformsEnvironmentRemediationHints
    monta comandos icacls para o usuário executar uma única vez (a skill nunca executa).
#>

Set-StrictMode -Version Latest

function Test-GamPlatformsStdoutNoiseLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $isGamAccessDenied = (($Line -match 'is denied') -or ($Line -match 'acesso negado')) -and
                         ($Line -match '\\GeneXus\\') -and
                         ($Line -match '\\Library\\GAM\\Platforms\\')
    if (-not $isGamAccessDenied) {
        return $false
    }
    if ($Line -match 'error MSB3491') {
        return $true
    }
    if ($Line -match 'NuGet\.targets\(\d+,\d+\):\s*error\s*:') {
        return $true
    }
    return $false
}

function Split-StdoutByGamPlatformsNoise {
    param(
        [AllowNull()]
        [string[]]$Lines
    )

    $noiseLines    = [System.Collections.Generic.List[string]]::new()
    $nonNoiseLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @($Lines)) {
        if ([string]::IsNullOrEmpty($line)) { continue }
        if (Test-GamPlatformsStdoutNoiseLine -Line $line) {
            [void]$noiseLines.Add($line)
        } else {
            [void]$nonNoiseLines.Add($line)
        }
    }

    return [ordered]@{
        NoiseLines    = @($noiseLines)
        NonNoiseLines = @($nonNoiseLines)
    }
}

function New-GamPlatformsEnvironmentRemediationHints {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGeneXusDir,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$FilteredNoiseLines
    )

    if (@($FilteredNoiseLines).Count -eq 0) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($ResolvedGeneXusDir)) {
        return $null
    }

    $platformsPath = Join-Path $ResolvedGeneXusDir 'Library\GAM\Platforms'
    $buildUser     = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $grantCmd      = ('icacls "{0}" /grant "{1}:(OI)(CI)M" /T /C' -f $platformsPath, $buildUser)
    $verifyCmd     = ('icacls "{0}"' -f $platformsPath)
    $revertCmd     = ('icacls "{0}" /remove:g "{1}" /T /C' -f $platformsPath, $buildUser)

    $summaryForUser = @(
        'Ruído estrutural do dotnet publish em GAM\Platforms foi filtrado do stdout; o build permanece classificado como limpo.'
        'Para eliminar esse ruído de forma permanente, execute UMA VEZ os comandos sugeridos em terminal elevado (como administrador), com a mesma conta que roda o build headless.'
        'A skill não executa icacls nem recomenda elevar o build a cada execução.'
    ) -join ' '

    return [ordered]@{
        gamPlatformsWriteDeniedFiltered = [ordered]@{
            condition                      = 'gam_platforms_write_denied_filtered'
            filteredLineCount              = @($FilteredNoiseLines).Count
            resolvedGeneXusDir             = $ResolvedGeneXusDir
            resolvedPlatformsPath          = $platformsPath
            buildUser                      = $buildUser
            oneTimeUserAction              = $true
            skillDoesNotExecuteGrant        = $true
            doesNotRecommendElevatedBuild  = $true
            summaryForUser                 = $summaryForUser
            suggestedCommands              = [ordered]@{
                grant  = $grantCmd
                verify = $verifyCmd
                revert = $revertCmd
            }
        }
    }
}

function Get-GamPlatformsStdoutPostFilterResult {
    param(
        [AllowNull()]
        [string[]]$StdOutLines,

        [AllowNull()]
        [string]$ResolvedGeneXusDir
    )

    $gamStdoutSplit = Split-StdoutByGamPlatformsNoise -Lines $StdOutLines
    $noiseLines     = @($gamStdoutSplit.NoiseLines)
    $nonNoiseLines  = @($gamStdoutSplit.NonNoiseLines)
    $hints          = $null
    $hintWarning    = $null

    if ($noiseLines.Count -gt 0) {
        try {
            $hints = New-GamPlatformsEnvironmentRemediationHints `
                -ResolvedGeneXusDir $ResolvedGeneXusDir `
                -FilteredNoiseLines $noiseLines
        }
        catch {
            $hintWarning = $_.Exception.Message
        }
    }

    return [ordered]@{
        NoiseLines                  = $noiseLines
        NonNoiseLines               = $nonNoiseLines
        EnvironmentRemediationHints = $hints
        RemediationHintWarning      = $hintWarning
    }
}
