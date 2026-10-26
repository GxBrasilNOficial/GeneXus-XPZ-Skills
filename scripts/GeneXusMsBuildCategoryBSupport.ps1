#requires -Version 7.4

<#
.SYNOPSIS
    Barragem estrutural (Categoria B) para wrappers MSBuild GeneXus.

.DESCRIPTION
    Categoria A (extras de inventario, módulos de plataforma, etc.) permanece com exitCode=0
    e decisão do agente (Decisão pos-gates). Categoria B (linhas error: no log MSBuild,
    invalidTypesRejected) rebaixa o exitCode classificado pelo wrapper para 48 quando a task
    MSBuild concluiu com sucesso aparente mas o log registra rejeicao objetiva.
#>

Set-StrictMode -Version Latest

# Fonte canonica numerica: scripts/msbuild-exit-codes.catalog.json
$script:GeneXusMsBuildCategoryBExitCode = 48

$script:ExportOperationalSubStateCategoryB = 'exportação parcial com errors do MSBuild — artefato não confiável'
$script:ImportOperationalSubStateCategoryB = 'importação com errors do MSBuild — alteração não confiável'
$script:PreviewOperationalSubStateCategoryB = 'preview com errors do MSBuild — diagnóstico não confiável'
$script:BuildOperationalSubStateCategoryB = 'build com errors do MSBuild — resultado não confiável'

function Test-GeneXusMsBuildCategoryBPresent {
    param(
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected
    )

    if (@($MsBuildErrors).Count -gt 0) {
        return $true
    }
    if (@($InvalidTypesRejected).Count -gt 0) {
        return $true
    }
    return $false
}

function Get-GeneXusMsBuildCategoryBBlockingReasons {
    param(
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected,
        [string]$StageLabel
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $label = if ([string]::IsNullOrWhiteSpace($StageLabel)) { 'MSBuild' } else { $StageLabel }

    if (@($InvalidTypesRejected).Count -gt 0) {
        [void]$reasons.Add(
            ('{0}: tipo(s) rejeitado(s) na lista ou no log ({1}).' -f $label, ($InvalidTypesRejected -join ', '))
        )
    }

    $errorLines = @($MsBuildErrors)
    $maxLines = 3
    for ($i = 0; $i -lt [Math]::Min($errorLines.Count, $maxLines); $i++) {
        [void]$reasons.Add(('{0}: linha error: no log — {1}' -f $label, $errorLines[$i]))
    }
    if ($errorLines.Count -gt $maxLines) {
        [void]$reasons.Add(
            ('{0}: mais {1} linha(s) com error: em msbuild.stdout.log / msbuild.stderr.log (ver array de errors no diagnostico).' -f $label, ($errorLines.Count - $maxLines))
        )
    }

    if ($reasons.Count -eq 0) {
        [void]$reasons.Add(('{0}: rejeicao Categoria B detectada sem detalhe serializado; consultar logs brutos.' -f $label))
    }

    return @($reasons)
}

function Get-GeneXusMsBuildCategoryBStatusSummary {
    param(
        [string]$OperationLabel,
        [bool]$ArtifactOnDisk,
        [string]$ArtifactKind
    )

    $artifactNote = if ($ArtifactOnDisk) {
        if ([string]::IsNullOrWhiteSpace($ArtifactKind)) {
            ' O artefato pode ter sido gravado no disco apenas para inspecao — nao tratar como entrega operacional limpa.'
        } else {
            " O $ArtifactKind pode ter sido gravado no disco apenas para inspecao — nao tratar como entrega operacional limpa."
        }
    } else {
        ''
    }

    return [ordered]@{
        Status  = 'falha operacional com rejeicao MSBuild no log'
        Summary = ("{0} concluiu com sucesso aparente da task MSBuild, mas o log contem linha(s) error: ou tipo(s) rejeitado(s) (Categoria B).{1}" -f $OperationLabel, $artifactNote)
    }
}

function Read-GeneXusMsBuildStageSignals {
    param(
        [string]$StdOutPath,
        [string]$StdErrPath,
        [string]$Stage,
        [string]$SignalsScriptPath,
        [string]$OutputPath,
        [string]$ExpectedItems
    )

    $empty = [pscustomobject]@{
        exportErrors         = @()
        importErrors         = @()
        buildErrors          = @()
        previewErrors        = @()
        invalidTypesRejected = @()
        knownStdOutNoise      = @()
        rawSignals           = $null
        signalsDegraded      = $false
        signalsDegradedReason = $null
    }

    if (-not (Test-Path -LiteralPath $SignalsScriptPath -PathType Leaf)) {
        $empty.signalsDegraded = $true
        $empty.signalsDegradedReason = "Read-MsBuildImportSignals.ps1 nao encontrado: $SignalsScriptPath"
        return $empty
    }

    try {
        $readerArgs = @{
            StdOutPath = $StdOutPath
            StdErrPath = $StdErrPath
            Stage      = $Stage
            AsJson     = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedItems)) {
            $readerArgs['ExpectedItems'] = $ExpectedItems
        }
        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
            $readerArgs['OutputPath'] = $OutputPath
        }

        $signalsJsonText = (& $SignalsScriptPath @readerArgs) | Out-String
        if ([string]::IsNullOrWhiteSpace($signalsJsonText)) {
            $empty.signalsDegraded = $true
            $empty.signalsDegradedReason = 'Read-MsBuildImportSignals.ps1 retornou JSON vazio.'
            return $empty
        }

        $signals = $signalsJsonText | ConvertFrom-Json
        $exportErrors = @()
        $importErrors = @()
        $invalidTypesRejected = @()
        $knownStdOutNoise = @()

        if ($Stage -eq 'export') {
            if ($null -ne $signals.PSObject.Properties['exportErrors']) {
                $exportErrors = @($signals.exportErrors)
            }
            if ($null -ne $signals.PSObject.Properties['invalidTypesRejected']) {
                $invalidTypesRejected = @($signals.invalidTypesRejected)
            }
        } else {
            if ($null -ne $signals.PSObject.Properties['errors']) {
                $importErrors = @($signals.errors)
            }
        }

        if ($null -ne $signals.PSObject.Properties['knownStdOutNoise']) {
            $knownStdOutNoise = @($signals.knownStdOutNoise)
        }

        $buildErrors = @()
        $previewErrors = @()
        if ($Stage -eq 'build-all') {
            $buildErrors = @($importErrors)
            $importErrors = @()
        } elseif ($Stage -eq 'import-preview') {
            $previewErrors = @($importErrors)
            $importErrors = @()
        }

        return [pscustomobject]@{
            exportErrors          = @($exportErrors)
            importErrors          = @($importErrors)
            buildErrors           = @($buildErrors)
            previewErrors         = @($previewErrors)
            invalidTypesRejected  = @($invalidTypesRejected)
            knownStdOutNoise      = @($knownStdOutNoise)
            rawSignals            = $signals
            signalsDegraded       = $false
            signalsDegradedReason = $null
        }
    }
    catch {
        $empty.signalsDegraded = $true
        $empty.signalsDegradedReason = $_.Exception.Message
        return $empty
    }
}

function Resolve-GeneXusMsBuildCategoryBExitCode {
    param(
        [int]$BaseExitCode,
        [int]$MsBuildExitCode,
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected
    )

    if ($BaseExitCode -ne 0) {
        return $BaseExitCode
    }
    if ($MsBuildExitCode -ne 0) {
        return $BaseExitCode
    }
    if (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors $MsBuildErrors -InvalidTypesRejected $InvalidTypesRejected) {
        return $script:GeneXusMsBuildCategoryBExitCode
    }
    return $BaseExitCode
}

# Caso conhecido do compressor de estaticos do GeneXus 18 (BuildAll). Dispensa a Categoria B somente
# quando: (1) stdout e stderr trazem apenas linhas `<arquivo>.js(N): Syntax error : }` do compressor,
# uma por arquivo, sem nenhuma outra linha de erro, falha ou exception, salvo ruido GAM que o
# classificador nao conta; (2) o contorno do pos-build foi aplicado a exatamente esses arquivos, com
# uma linha de correcao por arquivo; (3) o Verify-GxJs reportou zero invalidos na mesma raiz;
# (4) o BuildAll concluiu, na ordem abaixo; (5) o node --check aprova cada arquivo corrigido.
# Qualquer outra situacao mantem exit 48. Quem dispensa e somente este wrapper, nunca o agente.
$script:StaticCompressorClassifierErrorRegex = '(?i)error\s*:'
$script:StaticCompressorBroadErrorRegex = '(?i)error|erro|failed|failure|falha|falhou|exception|unhandled|is denied|access denied|permission denied|cannot access|cannot (write|copy|read|open|load)|could not (copy|write|read|open|access|find|load)|unable to|negado|inacess[íi]vel|n[ãa]o foi poss[íi]vel|n.{1,3}o foi poss.{1,3}vel|n.{1,3}o [ê] poss.{1,3}vel|unexpected token|unterminated|\bmissing\b|\binvalid\b|\binv.{1,2}lido\b|\bfatal\b|\babort\b|\bat System\.|\bat Microsoft\.|\bat Artech\.|\bat GeneXus\.'
$script:StaticCompressorSyntaxErrorRegex = '^\s*(?<file>[^\\/\s()]+\.js)\(\d+\): Syntax error : \}\s*(?<tail>\[[^\]\r\n]*\])?\s*$'
$script:StaticCompressorFileMessageRegex = '^\s*(?:.*[\\/])?(?<file>[^\\/\s()]+\.(?:js|css))(?:\(\d+\))?: '
$script:StaticCompressorFixRootRegex = '^\s*Fix-GxNegativeDomainKeys: raiz = (?<raiz>.+?)\s*$'
$script:StaticCompressorAppliedRegex = '^\s*\[APLICADO\] \.js varridos=(?<varridos>\d+) \| arquivos com chave negativa em gx\.domain=(?<arquivos>\d+) \| chaves corrigidas=(?<chaves>\d+)\s*$'
$script:StaticCompressorPerFileRegex = '^\s*(?<file>[^\s\\/]+\.js) -> (?<chaves>\d+) chave\(s\)\s*$'
$script:StaticCompressorVerifyRootRegex = '^\s*Verify-GxJs: raiz\s*=\s*(?<raiz>.+?)\s+\(via argumento\)\s*$'
$script:StaticCompressorVerifyRegex = '^\s*Verify-GxJs: verificados (?<verificados>\d+) \.js .*\| invalidos: (?<invalidos>\d+)\b'
$script:StaticCompressorBuildAllSuccessRegex = '^\s*> Build All Task Sucesso\s*$'
$script:StaticCompressorBuildAllDoneRegex = '^\s*__BUILDALL_DONE__=true\s*$'

function Get-GeneXusStaticCompressorCaseResult {
    param(
        [bool]$Recognized,
        [AllowNull()][string]$Reason,
        [AllowNull()][string]$WebDir,
        [AllowNull()][object[]]$Files,
        [AllowNull()]$ChavesCorrigidas,
        [AllowNull()][string]$AppliedLine,
        [AllowNull()][string]$VerifyLine,
        [AllowNull()][string]$NodeVersion
    )

    $fileList = @()
    if ($null -ne $Files) {
        $fileList = @($Files)
    }
    return [pscustomobject][ordered]@{
        recognized       = $Recognized
        reason           = $Reason
        webDir           = $WebDir
        files            = $fileList
        chavesCorrigidas = $ChavesCorrigidas
        appliedLine      = $AppliedLine
        verifyLine       = $VerifyLine
        nodeVersion      = $NodeVersion
    }
}

function Get-GeneXusStaticCompressorCaseRefusal {
    param([string]$Reason)

    return Get-GeneXusStaticCompressorCaseResult -Recognized $false -Reason $Reason -WebDir $null -Files @() -ChavesCorrigidas $null -AppliedLine $null -VerifyLine $null -NodeVersion $null
}

function Find-GeneXusStaticCompressorLines {
    param(
        [AllowNull()][string[]]$Lines,
        [string]$Pattern
    )

    $hits = [System.Collections.Generic.List[object]]::new()
    $items = @($Lines)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $match = [regex]::Match([string]$items[$i], $Pattern)
        if ($match.Success) {
            [void]$hits.Add([pscustomobject]@{ Index = $i; Match = $match })
        }
    }
    return $hits.ToArray()
}

function Test-GeneXusStaticCompressorSamePath {
    param(
        [AllowNull()][string]$Left,
        [AllowNull()][string]$Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }
    try {
        $leftFull = [System.IO.Path]::GetFullPath($Left).TrimEnd('\')
        $rightFull = [System.IO.Path]::GetFullPath($Right).TrimEnd('\')
    }
    catch {
        return $false
    }
    return [string]::Equals($leftFull, $rightFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-GeneXusStaticCompressorUnderRoot {
    param(
        [AllowNull()][string]$Path,
        [AllowNull()][string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Root)) {
        return $false
    }
    try {
        $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
        $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    }
    catch {
        return $false
    }
    return $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-GeneXusStaticCompressorKnownCase {
    param(
        [AllowNull()][string[]]$StdOutLines,
        [AllowNull()][string[]]$StdErrLines,
        [AllowNull()][string[]]$GamNoiseLines,
        [int]$MsBuildExitCode,
        [bool]$KbOpen,
        [bool]$TimedOut,
        [bool]$BuildAllDone,
        [AllowNull()][string]$DetectedBlockingPattern,
        [int]$BlockingReasonCount = 0,
        [int]$ClassifierErrorCount = -1,
        [AllowNull()][string]$KbRoot,
        [bool]$MetadataPresent,
        [AllowNull()][string]$ExpectedWebDir
    )

    if ($MsBuildExitCode -ne 0) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'msBuildExitCode diferente de 0.'
    }
    if (-not $KbOpen -or $TimedOut -or -not $BuildAllDone) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'KB nao abriu, houve timeout ou o BuildAll nao concluiu.'
    }
    if (-not [string]::IsNullOrWhiteSpace($DetectedBlockingPattern)) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason ('padrao de alerta detectado pelo wrapper: {0}.' -f $DetectedBlockingPattern)
    }
    if ($BlockingReasonCount -gt 0) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'o wrapper ja registrou motivo de bloqueio antes da avaliacao.'
    }

    # Ruido exento: inclui a forma crua e a aparada (Trim). Get-KnownStdOutNoise grava line ja
    # Trim(); o stdout do MSBuild costuma vir indentado — sem os dois lados, A2 falharia em silencio.
    $gamSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($noise in @($GamNoiseLines)) {
        if ($null -ne $noise) {
            $noiseText = [string]$noise
            [void]$gamSet.Add($noiseText)
            $noiseTrimmed = $noiseText.Trim()
            if ($noiseTrimmed.Length -gt 0) {
                [void]$gamSet.Add($noiseTrimmed)
            }
        }
    }
    $stdout = @($StdOutLines | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    $stderr = @($StdErrLines | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })

    # C1: so linhas de erro de sintaxe do compressor (uma por arquivo). Qualquer outra linha que o
    # classificador conta, ou que traga erro, falha ou exception, recusa, inclusive sob ruido GAM.
    $syntaxHits = [System.Collections.Generic.List[object]]::new()
    $streams = @(@{ Name = 'stdout'; Lines = $stdout }, @{ Name = 'stderr'; Lines = $stderr })
    foreach ($stream in $streams) {
        for ($i = 0; $i -lt $stream.Lines.Count; $i++) {
            $line = [string]$stream.Lines[$i]
            $syntax = [regex]::Match($line, $script:StaticCompressorSyntaxErrorRegex)
            if ($syntax.Success) {
                if ($stream.Name -ne 'stdout') {
                    return Get-GeneXusStaticCompressorCaseRefusal -Reason 'erro de sintaxe do compressor na saida de erro (stderr).'
                }
                if ([regex]::IsMatch($syntax.Groups['tail'].Value, $script:StaticCompressorBroadErrorRegex)) {
                    return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha de sintaxe com trecho de falha fora do caso conhecido.'
                }
                [void]$syntaxHits.Add([pscustomobject]@{ Index = $i; Text = $line; FileName = $syntax.Groups['file'].Value })
                continue
            }
            if ([regex]::IsMatch($line, $script:StaticCompressorClassifierErrorRegex)) {
                return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha de erro contada pelo classificador, fora do caso conhecido.'
            }
            if ($gamSet.Contains($line) -or $gamSet.Contains($line.Trim())) {
                continue
            }
            if ([regex]::IsMatch($line, $script:StaticCompressorBroadErrorRegex)) {
                return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha de erro ou falha fora do caso conhecido.'
            }
        }
    }
    if ($syntaxHits.Count -lt 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'nenhuma linha de erro de sintaxe do compressor.'
    }
    $fileSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $errorFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($hit in $syntaxHits) {
        if (-not $fileSet.Add($hit.FileName)) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('mais de uma linha de erro para o arquivo {0}.' -f $hit.FileName)
        }
        [void]$errorFiles.Add($hit.FileName)
    }
    $expectedCount = $syntaxHits.Count
    if ($ClassifierErrorCount -ge 0 -and $ClassifierErrorCount -ne $expectedCount) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason ('o classificador contou {0} erro(s); a regra reconhece {1} linha(s) de sintaxe.' -f $ClassifierErrorCount, $expectedCount)
    }

    # C2: contorno aplicado uma vez, com chaves corrigidas e a mesma quantidade de arquivos dos erros.
    $applied = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorAppliedRegex)
    $fixRoots = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorFixRootRegex)
    if ($applied.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha [APLICADO] ausente ou repetida.'
    }
    if ($fixRoots.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha Fix-GxNegativeDomainKeys ausente ou repetida.'
    }
    $compressionMarker = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern '^\s*Comprimindo arquivos est')
    $firstSyntaxIndex = [int]::MaxValue
    foreach ($hit in $syntaxHits) { if ($hit.Index -lt $firstSyntaxIndex) { $firstSyntaxIndex = [int]$hit.Index } }
    if ($compressionMarker.Count -lt 1 -or [int]$compressionMarker[0].Index -gt $firstSyntaxIndex) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'marca de compressao de estaticos ausente antes dos erros de sintaxe.'
    }
    $chaves = [int]$applied[0].Match.Groups['chaves'].Value
    if ($chaves -lt 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'contorno aplicado sem chave corrigida.'
    }
    $arquivosContorno = [int]$applied[0].Match.Groups['arquivos'].Value
    if ($arquivosContorno -ne $expectedCount) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason ('contorno afetou {0} arquivo(s); os erros citam {1}.' -f $arquivosContorno, $expectedCount)
    }
    $webDir = $fixRoots[0].Match.Groups['raiz'].Value
    $fixIndex = [int]$fixRoots[0].Index
    $appliedIndex = [int]$applied[0].Index

    # C3: exatamente uma linha de correcao por arquivo com erro, no stdout (a posicao e verificada em C6), com soma igual ao total.
    $perFile = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorPerFileRegex)
    if ($perFile.Count -ne $expectedCount) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason ('linhas por arquivo do contorno: {0}; erros: {1}.' -f $perFile.Count, $expectedCount)
    }
    $correctedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $sumChaves = 0
    $minPerFileIndex = [int]::MaxValue
    $maxPerFileIndex = -1
    foreach ($entry in $perFile) {
        $name = $entry.Match.Groups['file'].Value
        if (-not $fileSet.Contains($name)) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('o contorno corrigiu um arquivo que nao esta nos erros: {0}.' -f $name)
        }
        if (-not $correctedNames.Add($name)) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('arquivo corrigido mais de uma vez: {0}.' -f $name)
        }
        $k = [int]$entry.Match.Groups['chaves'].Value
        if ($k -lt 1) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('arquivo {0} sem chave corrigida.' -f $name)
        }
        $sumChaves += $k
        if ($entry.Index -lt $minPerFileIndex) { $minPerFileIndex = [int]$entry.Index }
        if ($entry.Index -gt $maxPerFileIndex) { $maxPerFileIndex = [int]$entry.Index }
    }
    if ($sumChaves -ne $chaves) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason ('total de chaves do contorno ({0}) difere da soma por arquivo ({1}).' -f $chaves, $sumChaves)
    }

    # C4: nenhuma mensagem de arquivo .js fora do conjunto dos erros, em stdout ou stderr, qualquer que seja a mensagem.
    foreach ($stream in $streams) {
        foreach ($line in $stream.Lines) {
            $message = [regex]::Match($line, $script:StaticCompressorFileMessageRegex)
            if ($message.Success -and -not $fileSet.Contains($message.Groups['file'].Value)) {
                return Get-GeneXusStaticCompressorCaseRefusal -Reason ('mensagem de compressao de arquivo fora do caso: {0}.' -f $message.Groups['file'].Value)
            }
            if ($message.Success -and -not ([regex]::IsMatch($line, '^\s*.+?\.js\(\d+\): Expected ') -or [regex]::IsMatch($line, $script:StaticCompressorSyntaxErrorRegex))) {
                return Get-GeneXusStaticCompressorCaseRefusal -Reason ('mensagem nao prevista para arquivo com erro de sintaxe: {0}.' -f $message.Groups['file'].Value)
            }
        }
    }

    # C5: Verify-GxJs com zero invalidos, ao menos um .js verificado e a mesma raiz do Fix.
    $verify = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorVerifyRegex)
    $verifyRoot = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorVerifyRootRegex)
    if ($verify.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha Verify-GxJs ausente ou repetida.'
    }
    if ($verifyRoot.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha de raiz do Verify-GxJs ausente ou repetida.'
    }
    $verified = [int]$verify[0].Match.Groups['verificados'].Value
    $invalidos = [int]$verify[0].Match.Groups['invalidos'].Value
    if ($invalidos -ne 0 -or $verified -lt 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'Verify-GxJs reportou invalidos ou nao verificou nenhum .js.'
    }
    if (-not (Test-GeneXusStaticCompressorSamePath -Left $verifyRoot[0].Match.Groups['raiz'].Value -Right $webDir)) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'raiz do Verify-GxJs difere da raiz do Fix-GxNegativeDomainKeys.'
    }
    $verifyRootIndex = [int]$verifyRoot[0].Index
    $verifyIndex = [int]$verify[0].Index

    # C6: conclusao do BuildAll, uma vez cada.
    $success = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorBuildAllSuccessRegex)
    $done = @(Find-GeneXusStaticCompressorLines -Lines $stdout -Pattern $script:StaticCompressorBuildAllDoneRegex)
    if ($success.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'linha "> Build All Task Sucesso" ausente ou repetida.'
    }
    if ($done.Count -ne 1) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason '__BUILDALL_DONE__=true ausente ou repetido.'
    }
    $successIndex = [int]$success[0].Index
    $doneIndex = [int]$done[0].Index

    # Ordem estrita: erros, Fix, APLICADO, correcoes por arquivo, raiz do Verify, Verify, sucesso, DONE.
    $maxErrorIndex = -1
    foreach ($hit in $syntaxHits) {
        if ($hit.Index -gt $maxErrorIndex) { $maxErrorIndex = [int]$hit.Index }
    }
    $ordered = ($maxErrorIndex -lt $fixIndex) -and ($fixIndex -lt $appliedIndex) -and ($appliedIndex -lt $minPerFileIndex) -and ($maxPerFileIndex -lt $verifyRootIndex) -and ($verifyRootIndex -lt $verifyIndex) -and ($verifyIndex -lt $successIndex) -and ($successIndex -lt $doneIndex)
    if (-not $ordered) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'ordem fora do esperado no log (erros, Fix, APLICADO, correcoes, Verify, Build All, DONE).'
    }

    # C7: raiz dentro da KB em build; se o metadata existe, ele precisa mapear o environment para essa raiz.
    if (-not (Test-GeneXusStaticCompressorUnderRoot -Path $webDir -Root $KbRoot)) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'raiz do Fix-GxNegativeDomainKeys fora da KB em build.'
    }
    if ($MetadataPresent -and [string]::IsNullOrWhiteSpace($ExpectedWebDir)) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'metadata presente sem mapeamento valido do environment em kb_environment_web_dirs.'
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedWebDir) -and -not (Test-GeneXusStaticCompressorSamePath -Left $webDir -Right $ExpectedWebDir)) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'raiz do Fix-GxNegativeDomainKeys difere do diretorio web do environment validado (kb_environment_web_dirs).'
    }

    # D2: cada arquivo com erro, localizado sem ambiguidade na raiz do Fix (erro de busca recusa), passa em node --check.
    $nodeCommand = Get-Command -Name node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $nodeCommand) {
        return Get-GeneXusStaticCompressorCaseRefusal -Reason 'node indisponivel para a verificacao de sintaxe dos arquivos corrigidos.'
    }
    $nodeVersion = [string](& $nodeCommand.Source --version 2>&1 | Select-Object -First 1)
    $files = [System.Collections.Generic.List[object]]::new()
    $webFiles = @(Get-ChildItem -LiteralPath $webDir -Recurse -File -ErrorAction Stop)
    foreach ($name in $errorFiles) {
        $found = @($webFiles | Where-Object { $_.Name -eq $name })
        if ($found.Count -ne 1) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('arquivo {0} ausente ou ambiguo na raiz do Fix ({1} ocorrencias).' -f $name, $found.Count)
        }
        $path = $found[0].FullName
        $nodeOutput = & $nodeCommand.Source --check $path 2>&1
        if ($LASTEXITCODE -ne 0) {
            return Get-GeneXusStaticCompressorCaseRefusal -Reason ('node --check falhou em {0}: {1}' -f $name, (@($nodeOutput) | Select-Object -First 1))
        }
        $perEntry = $perFile | Where-Object { [string]::Equals($_.Match.Groups['file'].Value, $name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        $hitEntry = $syntaxHits | Where-Object { [string]::Equals($_.FileName, $name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        $fileHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash
        [void]$files.Add([pscustomobject][ordered]@{
            fileName         = $name
            path             = $path
            sha256           = $fileHash
            lastWriteUtc     = $found[0].LastWriteTimeUtc.ToString('o')
            chavesCorrigidas = [int]$perEntry.Match.Groups['chaves'].Value
            syntaxLine       = $hitEntry.Text
            perFileLine      = $perEntry.Match.Value
        })
    }

    return Get-GeneXusStaticCompressorCaseResult -Recognized $true -Reason $null -WebDir $webDir -Files $files.ToArray() -ChavesCorrigidas $chaves -AppliedLine $stdout[$appliedIndex] -VerifyLine $stdout[$verifyIndex] -NodeVersion $nodeVersion
}

# Regra de roundtrip da rota integrada (Invoke-GeneXusXpzImportThenBuild.ps1). So um BuildAll
# "compilou limpo" sem categoria B e sem falha de pos-processamento vira roundtrip-ok; qualquer
# outro resultado com exit 0 fica como roundtrip-pendente-confirmacao. Exit diferente de 0 e
# build-failed-or-blocked.
function Get-GeneXusRoundtripStatus {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [bool]$BuildJsonOk,
        [AllowNull()]$BuildJson
    )

    if ($ExitCode -ne 0) {
        return 'build-failed-or-blocked'
    }
    $status = $null
    $categoryB = $false
    $postFailed = $false
    if ($BuildJsonOk -and $null -ne $BuildJson) {
        $statusProp = $BuildJson.PSObject.Properties['status']
        if ($null -ne $statusProp) { $status = [string]$statusProp.Value }
        $categoryProp = $BuildJson.PSObject.Properties['msBuildCategoryBBlocked']
        if ($null -ne $categoryProp) { $categoryB = ($categoryProp.Value -eq $true) }
        $postProp = $BuildJson.PSObject.Properties['postProcessingFailed']
        if ($null -ne $postProp) { $postFailed = ($postProp.Value -eq $true) }
    }
    if ($status -eq 'compilou limpo' -and -not $categoryB -and -not $postFailed) {
        return 'roundtrip-ok'
    }
    return 'roundtrip-pendente-confirmacao'
}
