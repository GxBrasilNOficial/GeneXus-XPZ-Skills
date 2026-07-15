#requires -Version 7.4
<#
.SYNOPSIS
    Prepara, de forma transacional, os artefatos de uma rodada de revisao por pares:
    recebe o conteudo do manuscrito e a lista de revisores, valida estrutura/seguranca,
    e publica os artefatos num diretorio estavel sob <TempDir>\<RoundId>.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; consumido por Invoke-LlmDelegatePanelDispatch.ps1
    quando o orquestrador passa -ManuscriptText em vez de -ManuscriptPath.

    A preparacao e TRANSAICIONAL: cria um staging temporario (.prepare-<guid>), valida tudo
    (manuscrito nao-vazio, reviewers JSON array nao-vazio com minimo backend+invokeArgs,
    ausencia de BOM, releitura estrita UTF-8, hashes SHA256), e so publica o diretorio final
    (<TempDir>\<RoundId>) por rename/move apos validacao completa. Em falha, limpa o staging
    e nao deixa diretorio final.

    ESTE SCRIPT NAO CHAMA DISPATCHER NEM ADAPTERS. E puramente um preparador de arquivos.
    A invocacao do dispatcher e o passo seguinte, feito pelo chamador.

    Disciplina de stdout: exatamente uma linha JSON (Kind/SchemaVersion PascalCase).
    Texto humano sai por [Console]::Error.
.PARAMETER ManuscriptText
    Texto do manuscrito (UTF-8). Exclusivo com -ManuscriptPath.
.PARAMETER ManuscriptPath
    Caminho do manuscrito (UTF-8). Exclusivo com -ManuscriptText.
.PARAMETER ReviewersJson
    Array JSON [{backend, targetModelKey, invokeArgs, family?, rank?, fallbackChain?}] inline OU caminho de arquivo.
    Validacao minima: array nao-vazio; cada item deve ter backend e invokeArgs.
.PARAMETER RoundId
    Identificador da rodada (subpasta do staging final). Default: [guid]::NewGuid().ToString('N').
    Validado como seguro: letras, numeros, ponto, hifen e underscore; sem path traversal.
.PARAMETER TempDir
    Raiz do staging. Default: <temp do sistema>\xpz-llm-panel-dispatch.
    O staging final fica em <TempDir>\<RoundId>\.
.PARAMETER FailAt
    (SO TESTE) Injeta falha controlada: afterManuscript | beforePublish.
    afterManuscript: falha apos escrever manuscript.md, antes de publicar.
    beforePublish: falha apos escrever todos os artefatos, antes do rename final.
.EXAMPLE
    .\New-LlmDelegatePeerReviewArtifacts.ps1 -ManuscriptText "# Revisao de plano" -ReviewersJson '[{"backend":"opencode","invokeArgs":{}}]' -RoundId rodada-001
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Inline')] [string] $ManuscriptText,
    [Parameter(ParameterSetName = 'File')] [string] $ManuscriptPath,
    [Parameter(Mandatory)] [string] $ReviewersJson,
    [string] $RoundId,
    [string] $TempDir,
    [ValidateSet('afterManuscript', 'beforePublish')] [string] $FailAt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$utf8StrictNoBom = [System.Text.UTF8Encoding]::new($false, $true)

# ---------------------------------------------------------------------------------------
# 1) Validacao de parametros mutuamente exclusivos
# ---------------------------------------------------------------------------------------
$useInline = $PSCmdlet.ParameterSetName -eq 'Inline'
if (-not ($PSBoundParameters.ContainsKey('ManuscriptText') -xor $PSBoundParameters.ContainsKey('ManuscriptPath'))) {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $null
        failureStage      = 'parameter-validation'
        failureCode       = 'manuscript-source-ambiguous'
        message           = 'Informe exatamente um entre -ManuscriptText e -ManuscriptPath.'
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine('BLOCK: manuscript-source-ambiguous: informe exatamente um entre -ManuscriptText e -ManuscriptPath.')
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

# ---------------------------------------------------------------------------------------
# 2) Resolver manuscrito (texto em memoria)
# ---------------------------------------------------------------------------------------
$manuscriptContent = $null
$manuscriptSource = $null
if ($useInline) {
    $manuscriptContent = $ManuscriptText
    $manuscriptSource = 'inline'
} else {
    if (-not (Test-Path -LiteralPath $ManuscriptPath -PathType Leaf)) {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $null
            failureStage      = 'parameter-validation'
            failureCode       = 'manuscript-path-not-found'
            message           = "-ManuscriptPath nao encontrado: $ManuscriptPath"
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: manuscript-path-not-found: -ManuscriptPath nao encontrado: $ManuscriptPath")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
    try {
        $manuscriptContent = [System.IO.File]::ReadAllText($ManuscriptPath, $utf8StrictNoBom)
    } catch {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $null
            failureStage      = 'manuscript-validation'
            failureCode       = 'manuscript-utf8-invalid'
            message           = "Manuscrito nao e UTF-8 valido: $($_.Exception.Message)"
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: manuscript-utf8-invalid: $($_.Exception.Message)")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
    $manuscriptSource = 'file'
}

# ---------------------------------------------------------------------------------------
# 3) Validar manuscrito nao-vazio (apos trim)
# ---------------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($manuscriptContent)) {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $null
        failureStage      = 'manuscript-validation'
        failureCode       = 'manuscript-empty'
        message           = 'Manuscrito vazio ou apenas whitespace.'
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine('BLOCK: manuscript-empty: manuscrito vazio ou apenas whitespace.')
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

# ---------------------------------------------------------------------------------------
# 4) Resolver RoundId
# ---------------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RoundId)) {
    $RoundId = [guid]::NewGuid().ToString('N')
}

# Validar RoundId seguro
if ($RoundId -match '[^A-Za-z0-9._-]') {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'roundId-validation'
        failureCode       = 'roundId-unsafe-chars'
        message           = "RoundId contem caracteres inseguros: '$RoundId'. Use apenas letras, numeros, ponto, hifen e underscore."
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine("BLOCK: roundId-unsafe-chars: '$RoundId' contem caracteres inseguros.")
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

# Path traversal check
if ($RoundId -match '\.\.' -or $RoundId -match '[/\\]') {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'roundId-validation'
        failureCode       = 'roundId-path-traversal'
        message           = "RoundId com path traversal detectado: '$RoundId'."
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine("BLOCK: roundId-path-traversal: '$RoundId'.")
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

# ---------------------------------------------------------------------------------------
# 5) Resolver TempDir e caminhos
# ---------------------------------------------------------------------------------------
$tempRoot = $TempDir
if ([string]::IsNullOrWhiteSpace($tempRoot)) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'xpz-llm-panel-dispatch'
}

$finalDir = Join-Path $tempRoot $RoundId

# Colisao com diretorio final existente -> falha
if (Test-Path -LiteralPath $finalDir -PathType Container) {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'staging-collision'
        failureCode       = 'final-dir-exists'
        message           = "Diretorio final ja existe: $finalDir. Nao sobrescrever."
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine("BLOCK: final-dir-exists: '$finalDir' ja existe.")
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

# ---------------------------------------------------------------------------------------
# 6) Validar ReviewersJson (minimo: array nao-vazio, cada item com backend + invokeArgs)
# ---------------------------------------------------------------------------------------
$reviewersRaw = $null
if (Test-Path -LiteralPath $ReviewersJson -PathType Leaf) {
    try {
        $reviewersRaw = [System.IO.File]::ReadAllText($ReviewersJson, $utf8StrictNoBom)
    } catch {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $RoundId
            failureStage      = 'reviewers-validation'
            failureCode       = 'reviewers-utf8-invalid'
            message           = "ReviewersJson nao e UTF-8 valido: $($_.Exception.Message)"
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: reviewers-utf8-invalid: $($_.Exception.Message)")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
} else {
    $reviewersRaw = $ReviewersJson
}

$reviewersParsed = $null
try {
    $reviewersParsed = $reviewersRaw | ConvertFrom-Json -NoEnumerate
} catch {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'reviewers-validation'
        failureCode       = 'reviewers-json-invalid'
        message           = "ReviewersJson nao e JSON valido: $($_.Exception.Message)"
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine("BLOCK: reviewers-json-invalid: $($_.Exception.Message)")
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

$reviewersIsArray = $reviewersParsed -is [System.Array]
if (-not $reviewersIsArray) {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'reviewers-validation'
        failureCode       = 'reviewers-root-not-array'
        message           = 'ReviewersJson deve ter raiz array JSON.'
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine('BLOCK: reviewers-root-not-array.')
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

$reviewers = @($reviewersParsed)
if ($reviewers.Count -eq 0) {
    $result = [ordered]@{
        Kind              = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion     = 1
        success           = $false
        roundStarted      = $false
        dispatchStarted   = $false
        reviewersDispatched = 0
        roundId           = $RoundId
        failureStage      = 'reviewers-validation'
        failureCode       = 'reviewers-empty'
        message           = 'ReviewersJson e um array vazio.'
        cleanup           = 'nada a limpar'
    }
    [Console]::Error.WriteLine('BLOCK: reviewers-empty.')
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}

for ($i = 0; $i -lt $reviewers.Count; $i++) {
    $r = $reviewers[$i]
    $backend = $null
    if ($null -ne $r -and $r.PSObject.Properties['backend']) {
        $backend = [string]$r.backend
    }
    $invokeArgs = $null
    if ($null -ne $r -and $r.PSObject.Properties['invokeArgs']) {
        $invokeArgs = $r.invokeArgs
    }
    if ([string]::IsNullOrWhiteSpace($backend)) {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $RoundId
            failureStage      = 'reviewers-validation'
            failureCode       = 'reviewer-missing-backend'
            message           = "Revisor [$i]: campo 'backend' ausente ou vazio."
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: reviewer-missing-backend: revisor [$i].")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
    if ($null -eq $invokeArgs) {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $RoundId
            failureStage      = 'reviewers-validation'
            failureCode       = 'reviewer-missing-invokeArgs'
            message           = "Revisor [$i]: campo 'invokeArgs' ausente."
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: reviewer-missing-invokeArgs: revisor [$i].")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
    if ($invokeArgs -isnot [pscustomobject]) {
        $result = [ordered]@{
            Kind              = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion     = 1
            success           = $false
            roundStarted      = $false
            dispatchStarted   = $false
            reviewersDispatched = 0
            roundId           = $RoundId
            failureStage      = 'reviewers-validation'
            failureCode       = 'reviewer-invalid-invokeArgs'
            message           = "Revisor [$i]: campo 'invokeArgs' deve ser objeto JSON."
            cleanup           = 'nada a limpar'
        }
        [Console]::Error.WriteLine("BLOCK: reviewer-invalid-invokeArgs: revisor [$i].")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
}

# ---------------------------------------------------------------------------------------
# 7) Criar staging transacional
# ---------------------------------------------------------------------------------------
$stagingGuid = [guid]::NewGuid().ToString('N')
$stagingDir = Join-Path $tempRoot ".prepare-$stagingGuid"
try {
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    $cleanStage = $true

    try {
        # -------------------------------------------------------------------------------
        # 7a) Escrever manuscript.md (UTF-8 sem BOM)
        # -------------------------------------------------------------------------------
        $manuscriptPath = Join-Path $stagingDir 'manuscript.md'
        [System.IO.File]::WriteAllText($manuscriptPath, $manuscriptContent, $utf8NoBom)

        # Verificar BOM ausente
        $bomBytes = [System.IO.File]::ReadAllBytes($manuscriptPath)
        if ($bomBytes.Length -ge 3 -and $bomBytes[0] -eq 0xEF -and $bomBytes[1] -eq 0xBB -and $bomBytes[2] -eq 0xBF) {
            throw "BOM UTF-8 detectado apos escrita de manuscript.md"
        }

        # Releitura estrita UTF-8
        $reRead = [System.IO.File]::ReadAllText($manuscriptPath, $utf8StrictNoBom)
        if ($reRead -ne $manuscriptContent) {
            throw "Divergencia na releitura de manuscript.md (round-trip)"
        }

        $manuscriptHash = (Get-FileHash -LiteralPath $manuscriptPath -Algorithm SHA256).Hash
        $manuscriptSize = $bomBytes.Length

        # -------------------------------------------------------------------------------
        # 7b) Escrever reviewers.json (UTF-8 sem BOM, pretty para legibilidade)
        # -------------------------------------------------------------------------------
        $reviewersJsonOut = Join-Path $stagingDir 'reviewers.json'
        $reviewersPretty = ($reviewers | ConvertTo-Json -Depth 8 -AsArray)
        [System.IO.File]::WriteAllText($reviewersJsonOut, $reviewersPretty, $utf8NoBom)

        $reviewersBytes = [System.IO.File]::ReadAllBytes($reviewersJsonOut)
        if ($reviewersBytes.Length -ge 3 -and $reviewersBytes[0] -eq 0xEF -and $reviewersBytes[1] -eq 0xBB -and $reviewersBytes[2] -eq 0xBF) {
            throw "BOM UTF-8 detectado apos escrita de reviewers.json"
        }
        $reviewersReRead = [System.IO.File]::ReadAllText($reviewersJsonOut, $utf8StrictNoBom)
        if ($reviewersReRead -ne $reviewersPretty) {
            throw "Divergencia na releitura de reviewers.json (round-trip)"
        }

        $reviewersHash = (Get-FileHash -LiteralPath $reviewersJsonOut -Algorithm SHA256).Hash
        $reviewersSize = $reviewersBytes.Length

        # -------------------------------------------------------------------------------
        # 7c) Injetar falha (so teste) apos escrever manuscript
        # -------------------------------------------------------------------------------
        if ($FailAt -eq 'afterManuscript') {
            throw "FALHA INJETADA (afterManuscript): staging nao deve ser publicado."
        }

        # -------------------------------------------------------------------------------
        # 7d) Montar e escrever preparation-manifest.json
        # -------------------------------------------------------------------------------
        $createdAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $manifestObj = [ordered]@{
            Kind          = 'xpz-llm-peer-review-artifacts-manifest'
            SchemaVersion = 1
            roundId       = $RoundId
            createdAt     = $createdAt
            encoding      = 'utf-8-no-bom'
            manuscriptSource = $manuscriptSource
            artifacts     = [ordered]@{
                manuscript = [ordered]@{
                    filename = 'manuscript.md'
                    sha256   = $manuscriptHash
                    size     = $manuscriptSize
                }
                reviewers  = [ordered]@{
                    filename = 'reviewers.json'
                    sha256   = $reviewersHash
                    size     = $reviewersSize
                }
            }
            reviewerCount = $reviewers.Count
        }
        $manifestPath = Join-Path $stagingDir 'preparation-manifest.json'
        $manifestJson = ($manifestObj | ConvertTo-Json -Compress -Depth 6)
        [System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

        # -------------------------------------------------------------------------------
        # 7e) Injetar falha (so teste) antes de publicar
        # -------------------------------------------------------------------------------
        if ($FailAt -eq 'beforePublish') {
            throw "FALHA INJETADA (beforePublish): staging nao deve ser publicado."
        }

        # -------------------------------------------------------------------------------
        # 7f) Publicar: rename atomico do staging -> final
        # -------------------------------------------------------------------------------
        [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        [System.IO.Directory]::Move($stagingDir, $finalDir)
        $cleanStage = $false

        # -------------------------------------------------------------------------------
        # 8) Sucesso: emitir resultado
        # -------------------------------------------------------------------------------
        $result = [ordered]@{
            Kind                = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion       = 1
            success             = $true
            roundStarted        = $false
            dispatchStarted     = $false
            reviewersDispatched = 0
            roundId             = $RoundId
            artifactPaths       = [ordered]@{
                manuscript = $finalDir + '\manuscript.md'
                reviewers  = $finalDir + '\reviewers.json'
                manifest   = $finalDir + '\preparation-manifest.json'
            }
            hashes = [ordered]@{
                manuscript = $manuscriptHash
                reviewers  = $reviewersHash
            }
            encoding     = 'utf-8-no-bom'
            cleanup      = 'staging publicado com sucesso'
        }
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 0
    } catch {
        # Limpar staging em falha
        if ($cleanStage) {
            try { Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        }

        $errMsg = [string]$_.Exception.Message
        $failureCode = 'preparation-error'
        $failureStage = 'artifact-preparation'
        if ($errMsg -match 'FALHA INJETADA') {
            $failureCode = 'injected-failure'
            $failureStage = 'injected-failure'
        } elseif ($errMsg -match 'BOM') {
            $failureCode = 'bom-detected'
        } elseif ($errMsg -match 'releitura|round-trip') {
            $failureCode = 'round-trip-mismatch'
        }

        $result = [ordered]@{
            Kind                = 'xpz-llm-peer-review-artifacts-result'
            SchemaVersion       = 1
            success             = $false
            roundStarted        = $false
            dispatchStarted     = $false
            reviewersDispatched = 0
            roundId             = $RoundId
            failureStage        = $failureStage
            failureCode         = $failureCode
            message             = $errMsg
            cleanup             = 'staging removido'
        }
        [Console]::Error.WriteLine("BLOCK: $failureCode ($failureStage): $errMsg")
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
        exit 1
    }
} catch {
    # Falha na criacao do staging dir
    $result = [ordered]@{
        Kind                = 'xpz-llm-peer-review-artifacts-result'
        SchemaVersion       = 1
        success             = $false
        roundStarted        = $false
        dispatchStarted     = $false
        reviewersDispatched = 0
        roundId             = $RoundId
        failureStage        = 'staging-creation'
        failureCode         = 'staging-dir-error'
        message             = "Falha ao criar staging: $($_.Exception.Message)"
        cleanup             = 'nada a limpar'
    }
    [Console]::Error.WriteLine("BLOCK: staging-dir-error: $($_.Exception.Message)")
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 6))
    exit 1
}
