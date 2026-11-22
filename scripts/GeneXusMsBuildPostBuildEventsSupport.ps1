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

function Test-GeneXusPostBuildTimingOutputLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    $value = $Line.Trim()
    if ($value -match '^(Days|Hours|Minutes|Seconds|Milliseconds|Ticks)\s*:\s*[+-]?\d+$') {
        return $true
    }
    if ($value -match '^(TotalDays|TotalHours|TotalMinutes|TotalSeconds|TotalMilliseconds)\s*:\s*[+-]?\d+(?:[.,]\d+)?$') {
        return $true
    }

    $dateMatch = [regex]::Match(
        $value,
        '^(?<day>\d{1,2})/(?<month>\d{1,2})/(?<year>\d{4})\s+(?<hour>\d{1,2}):(?<minute>\d{2}):(?<second>\d{2})$'
    )
    if (-not $dateMatch.Success) {
        return $false
    }

    try {
        $null = [datetime]::new(
            [int]$dateMatch.Groups['year'].Value,
            [int]$dateMatch.Groups['month'].Value,
            [int]$dateMatch.Groups['day'].Value,
            [int]$dateMatch.Groups['hour'].Value,
            [int]$dateMatch.Groups['minute'].Value,
            [int]$dateMatch.Groups['second'].Value
        )
        return $true
    }
    catch {
        return $false
    }
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
    if (Test-GeneXusPostBuildTimingOutputLine -Line $Line) {
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
    $postBuildWindowDetected = $false

    foreach ($line in $lines) {
        if (-not $insidePostBuildWindow) {
            if (Test-GeneXusPostBuildPhaseStartLine -Line $line) {
                $insidePostBuildWindow = $true
                $postBuildWindowDetected = $true
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

    if ($postBuildWindowDetected) {
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
    return (($Line -match '^\(commented\)') -or
            (Test-GeneXusPostBuildTimingOutputLine -Line $Line))
}

function Get-GeneXusPostBuildEventNormalizedHash {
    param([Parameter(Mandatory = $true)][string]$Line)

    # Normalizacao tolerante a variacao inocua: trim, colapso de espacos internos, lowercase
    # (paths e comandos no Windows são case-insensitive). SHA-256 hex, a prova de delimitador
    # para caber no encoding plano `env=h1,h2; env=h3` do kb-source-metadata.md.
    $normalized = (($Line.Trim()) -replace '\s+', ' ').ToLowerInvariant()
    if ($normalized -match '^verify-gxjs: verificados \d+ \.js .* \| invalidos: 0 \| tempo: \d+ ms$') {
        $normalized = $normalized -replace '\| tempo: \d+ ms$', '| tempo: <ms> ms'
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()
}

# Familias de linha conhecidas (lista fechada). Cada Match casa a linha ja normalizada (trim,
# espacos colapsados, minusculas); as substituicoes trocam so as contagens, ancoradas no texto
# vizinho. Os formatos vem dos scripts locais do pos-build (fora do repositorio, em
# C:\Program Files (x86)\GeneXus\Scripts). Quem mudar um formato confere tambem
# GeneXusMsBuildCategoryBSupport.ps1 (reconhecedor do caso do compressor de estaticos).
$script:PostBuildEventFamilies = @(
    [pscustomobject]@{
        Name    = 'A'
        Match   = '^\[aplicado\] \.js varridos=[1-9]\d* \| arquivos com chave negativa em gx\.domain=\d+ \| chaves corrigidas=\d+$'
        Replace = @(
            @{ Pattern = 'varridos=\d+'; Value = 'varridos=<n>' }
            @{ Pattern = 'gx\.domain=\d+'; Value = 'gx.domain=<n>' }
            @{ Pattern = 'corrigidas=\d+'; Value = 'corrigidas=<n>' }
        )
    }
    [pscustomobject]@{
        Name    = 'B'
        Match   = '^verify-gxjs: verificados [1-9]\d* \.js \(modulos pulados: \d+ \| placeholders pulados: \d+\) \| invalidos: 0 \| tempo: \d+ ms$'
        Replace = @(
            @{ Pattern = 'verificados \d+'; Value = 'verificados <n>' }
            @{ Pattern = 'pulados: \d+'; Value = 'pulados: <n>' }
            @{ Pattern = 'tempo: \d+'; Value = 'tempo: <n>' }
        )
    }
    [pscustomobject]@{
        Name    = 'C'
        Match   = '^commonrsphealth: ok - [-\w.]+ ok \(\d+ itens, \d+ dominios\)(; [-\w.]+ ok \(\d+ itens, \d+ dominios\))*; \d+ gxdomain\*\.cs no disco$'
        Replace = @(
            @{ Pattern = '\(\d+ itens, \d+ dominios\)'; Value = '(<n> itens, <n> dominios)' }
            @{ Pattern = '; \d+ gxdomain'; Value = '; <n> gxdomain' }
        )
    }
)

function Get-GeneXusPostBuildEventFamilyText {
    param([Parameter(Mandatory = $true)][string]$Line)

    # Texto normalizado com as contagens trocadas por <n>, ou $null quando a linha nao casa familia.
    $normalized = (($Line.Trim()) -replace '\s+', ' ').ToLowerInvariant()
    foreach ($family in $script:PostBuildEventFamilies) {
        if ($normalized -match $family.Match) {
            $text = $normalized
            foreach ($rule in $family.Replace) {
                $text = $text -replace $rule.Pattern, $rule.Value
            }
            return $text
        }
    }
    return $null
}

function Get-GeneXusPostBuildEventFamilyHash {
    param([Parameter(Mandatory = $true)][string]$Line)

    # Forma nova do fingerprint. Linha fora das familias devolve o mesmo valor da forma legada.
    $text = Get-GeneXusPostBuildEventFamilyText -Line $Line
    if ($null -eq $text) {
        return Get-GeneXusPostBuildEventNormalizedHash -Line $Line
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
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
    $legacyMatchCount = 0

    foreach ($line in $events) {
        if (Test-GeneXusPostBuildEventInert -Line $line) {
            [void]$inert.Add($line)
            continue
        }

        if ($hasRegistry) {
            # 1) forma nova; 2) linha de familia aceita pela forma legada (registro antigo, com aviso).
            $hash = Get-GeneXusPostBuildEventFamilyHash -Line $line
            if ($registeredSet.Contains($hash)) {
                [void]$expected.Add($line)
            } elseif (($null -ne (Get-GeneXusPostBuildEventFamilyText -Line $line)) -and
                      $registeredSet.Contains((Get-GeneXusPostBuildEventNormalizedHash -Line $line))) {
                [void]$expected.Add($line)
                $legacyMatchCount++
            } else {
                [void]$unexpected.Add($line)
            }
        } else {
            if (Test-GeneXusPostBuildEventBenignBySound -Line $line) {
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
        legacyMatchCount  = $legacyMatchCount
    }
}

function Get-GeneXusPostBuildRegistryNextStep {
    # Proximo passo para o agente quando o registro de eventos pos-build esta pendente: o build so
    # detecta e encaminha. A acao de registrar pertence a skill xpz-kb-parallel-setup, que confere o
    # registro na auditoria de setup e indica a acao; por isso a mensagem nao cita script de registro.
    # Retorna $null quando nao ha pendencia de registro (inclusive registro nao consultado).
    param(
        [Parameter(Mandatory = $true)]$Classification,
        [Parameter(Mandatory = $true)]$RegistryState,
        [AllowNull()][string]$EnvironmentName
    )

    $state = [string]$RegistryState.state
    if ($state -eq 'metadataNotProvided' -or $state -eq 'environmentNameUnavailable') { return $null }

    $nonInertCount = @($Classification.expected).Count + @($Classification.unexpected).Count +
                     @($Classification.benignFallback).Count + @($Classification.unknownFallback).Count
    $reason = $null
    if ($state -eq 'noEntryForEnvironment' -and $nonInertCount -gt 0) {
        $reason = 'sem registro'
    } elseif ($state -eq 'available' -and @($Classification.unexpected).Count -gt 0) {
        $reason = 'evento nao registrado'
    } elseif ([int]$Classification.legacyMatchCount -gt 0) {
        $reason = 'registro na forma antiga'
    }
    if ($null -eq $reason) { return $null }

    return ("Registro de eventos pos-build pendente para '{0}' ({1}): carregue a skill xpz-kb-parallel-setup e rode a auditoria de setup da pasta paralela. Ela confere o registro e indica a acao; o build sozinho nao basta para registrar." -f $EnvironmentName, $reason)
}

function Get-GeneXusPostBuildBaseFacts {
    # Fatos do JSON de um build usados para decidir se ele serve de base do registro de eventos
    # pos-build. Sem excecao por campo ausente: o campo ausente fica $null e o veredito decide.
    param([Parameter(Mandatory = $true)]$BuildJson)

    $exitCode = $null
    if ($null -ne $BuildJson.PSObject.Properties['exitCode']) { $exitCode = $BuildJson.exitCode }

    $msBuildExitCode = $null
    $msBuildFailed = $null
    if ($null -ne $BuildJson.PSObject.Properties['executionEvidence'] -and $null -ne $BuildJson.executionEvidence) {
        $evidence = $BuildJson.executionEvidence
        if ($null -ne $evidence.PSObject.Properties['msBuildExitCode']) { $msBuildExitCode = $evidence.msBuildExitCode }
        if ($null -ne $evidence.PSObject.Properties['msBuildFailed']) { $msBuildFailed = $evidence.msBuildFailed }
    }

    $statusText = ''
    if ($null -ne $BuildJson.PSObject.Properties['status'] -and $null -ne $BuildJson.status) { $statusText = [string]$BuildJson.status }

    $summaryText = ''
    if ($null -ne $BuildJson.PSObject.Properties['summary'] -and $null -ne $BuildJson.summary) { $summaryText = [string]$BuildJson.summary }

    $registryState = $null
    $unexpectedCount = 0
    if ($null -ne $BuildJson.PSObject.Properties['stdoutSignals'] -and $null -ne $BuildJson.stdoutSignals -and
        $null -ne $BuildJson.stdoutSignals.PSObject.Properties['postBuildEventClassification'] -and
        $null -ne $BuildJson.stdoutSignals.postBuildEventClassification) {
        $classification = $BuildJson.stdoutSignals.postBuildEventClassification
        if ($null -ne $classification.PSObject.Properties['registryStatus'] -and $null -ne $classification.registryStatus -and
            $null -ne $classification.registryStatus.PSObject.Properties['state']) {
            $registryState = [string]$classification.registryStatus.state
        }
        if ($null -ne $classification.PSObject.Properties['unexpected'] -and $null -ne $classification.unexpected) {
            $unexpectedCount = @($classification.unexpected).Count
        }
    }

    return [pscustomobject][ordered]@{
        exitCode        = $exitCode
        msBuildExitCode = $msBuildExitCode
        msBuildFailed   = $msBuildFailed
        statusText      = $statusText
        summaryText     = $summaryText
        registryState   = $registryState
        unexpectedCount = $unexpectedCount
    }
}

function Get-GeneXusPostBuildBaseVerdict {
    # Veredito unico (auditoria e registro): o build serve de base do registro de eventos pos-build?
    # Apto: exitCode e executionEvidence.msBuildExitCode 0, sem msBuildFailed, e status "compilou limpo"
    # (BuildAll) ou "specify e generate concluidos" (SpecifyGenerate), ou pendente SO por evento pos-build a registrar:
    # o resumo do build aponta o evento como causa e o registryStatus e available (environment ja registrado, evento novo
    # ou mudado) ou noEntryForEnvironment (environment sem registro). Pendencia por outra causa (stderr, alerta, sem marcador
    # de conclusao) deixa outro resumo e nao serve de base.
    param([Parameter(Mandatory = $true)]$Facts)

    if ($null -eq $Facts.exitCode -or "$($Facts.exitCode)" -ne '0') {
        return [pscustomobject]@{ ok = $false; reason = 'exitCode ausente ou diferente de 0' }
    }
    if ($null -eq $Facts.msBuildExitCode -or "$($Facts.msBuildExitCode)" -ne '0') {
        return [pscustomobject]@{ ok = $false; reason = 'executionEvidence.msBuildExitCode ausente ou diferente de 0' }
    }
    if ($null -ne $Facts.msBuildFailed -and [bool]$Facts.msBuildFailed) {
        return [pscustomobject]@{ ok = $false; reason = 'executionEvidence.msBuildFailed verdadeiro' }
    }
    if ($Facts.statusText -match 'compilou limpo') {
        return [pscustomobject]@{ ok = $true; reason = 'status compilou limpo' }
    }
    # Sucesso do SpecifyGenerate (equivalente ao "compilou limpo" do BuildAll).
    if ($Facts.statusText -match 'specify e generate conclu') {
        return [pscustomobject]@{ ok = $true; reason = 'status specify e generate concluidos' }
    }
    if ($Facts.statusText -match 'pendente de confirma') {
        if ($null -eq $Facts.registryState) {
            return [pscustomobject]@{ ok = $false; reason = 'sem registryStatus no diagnostico (build anterior ao diagnostico de registro)' }
        }
        if ($Facts.registryState -ne 'noEntryForEnvironment' -and $Facts.registryState -ne 'available') {
            return [pscustomobject]@{ ok = $false; reason = "registryStatus=$($Facts.registryState), o registro nao foi consultado para o environment" }
        }
        if ([string]$Facts.summaryText -notmatch 'evento pos-build nao registrado') {
            return [pscustomobject]@{ ok = $false; reason = 'a pendencia nao tem evento pos-build como causa no resumo do build' }
        }
        return [pscustomobject]@{ ok = $true; reason = 'pendente apenas por evento pos-build a registrar' }
    }
    return [pscustomobject]@{ ok = $false; reason = "status nao previsto: $($Facts.statusText)" }
}
