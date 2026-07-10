#requires -Version 7.4
<#
.SYNOPSIS
    Extracao de eventos pos-build do stdout MSBuild GeneXus.

.DESCRIPTION
    Prefere a janela delimitada pelo marcador "Executando eventos pos-construcao"
    e pelo próximo separador "==========". Mantem a regex histórica como fallback
    para logs antigos ou variantes sem marcador de fase.
#>

Set-StrictMode -Version Latest

function Convert-GeneXusPostBuildEventLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $value = $Line.Trim()
    if ($value -match '^(?i)REM\s+') {
        return "(commented) $value"
    }
    return $value
}

function Test-GeneXusPostBuildPhaseStartLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }
    return ($Line -match '(?i)Executando\s+eventos\s+p[oó]s-constru[cç][aã]o')
}

function Test-GeneXusMsBuildPhaseBoundaryLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }
    return ($Line -match '^\s*=+\s*.*=+\s*$')
}

function Test-GeneXusPostBuildWindowDiagnosticLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $true
    }
    if (Test-GeneXusPostBuildPhaseStartLine -Line $Line) {
        return $true
    }
    if (Test-GeneXusMsBuildPhaseBoundaryLine -Line $Line) {
        return $true
    }
    if ($Line -match '(?i)\(\d+,\d+\)\s*:\s*(warning|error)\s*:') {
        return $true
    }
    if ($Line -match '(?i)^\s*(Build succeeded|Build FAILED|Compilaci[oó]n|Compila[cç][aã]o)\b') {
        return $true
    }
    return $false
}

function Get-GeneXusMsBuildPostBuildEventLines {
    param(
        [AllowNull()]
        [string[]]$StdOutLines
    )

    $lines = @($StdOutLines)
    $windowEvents = [System.Collections.Generic.List[string]]::new()
    $insidePostBuildWindow = $false

    foreach ($line in $lines) {
        if (-not $insidePostBuildWindow) {
            if (Test-GeneXusPostBuildPhaseStartLine -Line $line) {
                $insidePostBuildWindow = $true
            }
            continue
        }

        if (Test-GeneXusMsBuildPhaseBoundaryLine -Line $line) {
            break
        }
        if (Test-GeneXusPostBuildWindowDiagnosticLine -Line $line) {
            continue
        }

        [void]$windowEvents.Add((Convert-GeneXusPostBuildEventLine -Line $line))
    }

    if ($windowEvents.Count -gt 0) {
        return @($windowEvents)
    }

    $fallbackText = ($lines -join "`n")
    return @([regex]::Matches($fallbackText, '(?im)^\s*(REM\s+)?(start\s+c:|start\s+cmd)[^\r\n]*') |
             ForEach-Object { Convert-GeneXusPostBuildEventLine -Line $_.Value })
}

function Test-GeneXusPostBuildEventInert {
    param([AllowNull()][string]$Line)

    # Linha comentada (REM) já vem prefixada por Convert-GeneXusPostBuildEventLine; não executa.
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $true
    }
    return ($Line -match '^\(commented\)')
}

function Get-GeneXusPostBuildEventNormalizedHash {
    param([Parameter(Mandatory = $true)][string]$Line)

    # Normalizacao tolerante a variacao inocua: trim, colapso de espacos internos, lowercase
    # (paths e comandos no Windows são case-insensitive). SHA-256 hex, a prova de delimitador
    # para caber no encoding plano `env=h1,h2; env=h3` do kb-source-metadata.md.
    $normalized = (($Line.Trim()) -replace '\s+', ' ').ToLowerInvariant()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()
}

function Test-GeneXusPostBuildEventBenignBySound {
    param([AllowNull()][string]$Line)

    # Rede de seguranca (fallback) quando o environment ainda não tem eventos registrados:
    # reconhece tocadores de som como benignos. Exige token específico de som — não um
    # `start` genérico — para não confiar em comando arbitrario disfarcado.
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }
    if ($Line -match '(?i)System\.Media\.SoundPlayer') { return $true }
    if ($Line -match '(?i)\bPlaySync\b') { return $true }
    if ($Line -match '(?i)\bPlaySound\b') { return $true }
    if ($Line -match '(?i)\bstart\b.*\.(wav|mp3|wma|wave|mid|midi|aac|ogg|flac)\b') { return $true }
    return $false
}

function Test-GeneXusPostBuildEventBenignByTimingDiagnostic {
    param([AllowNull()][string]$Line)

    # Algumas KBs usam eventos pos-build apenas para imprimir duracao/data no Output.
    # Essas linhas nao disparam processo externo relevante nem alteram artefatos; sao
    # tratadas como benignas quando aparecem sem registro explicito do environment.
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    $value = $Line.Trim()
    if ($value -match '(?i)^Powershell\s+New-TimeSpan\s+-Start\s+\(Get-Content\s+Inicio\.txt\)\s+-End\s+\(Get-Date\)$') { return $true }
    if ($value -match '(?i)^Powershell\s+\(Get-Date\)\.ToString\(\)$') { return $true }
    if ($value -match '^(Days|Hours|Minutes|Seconds|Milliseconds|Ticks|TotalDays|TotalHours|TotalMinutes|TotalSeconds|TotalMilliseconds)\s*:') { return $true }
    if ($value -match '^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}:\d{2}$') { return $true }
    if ($value -match '^>\s*Build\s+All\s+Task\s+Sucesso$') { return $true }

    return $false
}

function Get-GeneXusPostBuildEventClassification {
    param(
        [AllowNull()][string[]]$PostBuildEventLines,
        [AllowNull()][string[]]$RegisteredHashes
    )

    $events = @(@($PostBuildEventLines) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $registeredSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($h in @($RegisteredHashes)) {
        if (-not [string]::IsNullOrWhiteSpace($h)) {
            [void]$registeredSet.Add($h.Trim().ToLowerInvariant())
        }
    }
    $hasRegistry = ($registeredSet.Count -gt 0)

    $inert           = [System.Collections.Generic.List[string]]::new()
    $expected        = [System.Collections.Generic.List[string]]::new()
    $unexpected      = [System.Collections.Generic.List[string]]::new()
    $benignFallback  = [System.Collections.Generic.List[string]]::new()
    $unknownFallback = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $events) {
        if (Test-GeneXusPostBuildEventInert -Line $line) {
            [void]$inert.Add($line)
            continue
        }

        if ($hasRegistry) {
            $hash = Get-GeneXusPostBuildEventNormalizedHash -Line $line
            if ($registeredSet.Contains($hash)) {
                [void]$expected.Add($line)
            } else {
                [void]$unexpected.Add($line)
            }
        } else {
            if ((Test-GeneXusPostBuildEventBenignBySound -Line $line) -or
                (Test-GeneXusPostBuildEventBenignByTimingDiagnostic -Line $line)) {
                [void]$benignFallback.Add($line)
            } else {
                [void]$unknownFallback.Add($line)
            }
        }
    }

    $shouldDowngrade = ($unexpected.Count -gt 0) -or ($unknownFallback.Count -gt 0)

    return [pscustomobject][ordered]@{
        registryAvailable = $hasRegistry
        inert             = @($inert)
        expected          = @($expected)
        unexpected        = @($unexpected)
        benignFallback    = @($benignFallback)
        unknownFallback   = @($unknownFallback)
        shouldDowngrade   = $shouldDowngrade
    }
}
