#requires -Version 7.4
<#
.SYNOPSIS
    Edicao cirurgica de XML GeneXus preservando conteúdo fora do delta aprovado.

.DESCRIPTION
    Le o arquivo em modo raw (ReadAllText), valida as ocorrências literais da
    ancora — substrings nao sobrepostas, esquerda->direita, comparacao Ordinal —,
    aplica Replace ou InsertAfter, atualiza lastUpdate por defeito (exceto com
    -PreserveLastUpdate), grava UTF-8 sem BOM e valida well-formedness opcional.

    Por construcao, a operacao e conferida antes e depois da gravacao: cada
    mutacao tem de produzir exatamente o Replacement, e o restante do documento
    tem de permanecer identico fora da uniao dos intervalos mutados — verificado
    na memoria (dry-run) e no arquivo lido de volta (apply).

    Limite declarado: o motor nao detecta BOM na entrada; a leitura consome um
    BOM eventual e a gravacao e sempre UTF-8 sem BOM (padrao do repo).

    Codigos de saida (o contrato e o `code` string; o numero e por script):
      11 ANCHOR_FAIL                    14 INPUT_NOT_FOUND
      12 NO_LASTUPDATE                  15 OUTPUT_DIR_MISSING
      13 XML_NOT_WELLFORMED_AFTER       16 BASELINE_NOT_FOUND
      17 EXPECTED_ANCHOR_COUNT_INVALID  18 AMBIGUOUS_APPLY_SCOPE
      19 SELFCHECK_MUTATION_MISMATCH    26 NOOP_REPLACEMENT
      27 ANCHOR_EMPTY                   28 LASTUPDATE_TARGET_MOVED
      90 INTERNAL_ERROR

.PARAMETER InputPath
    Caminho do XML fonte.

.PARAMETER OutputPath
    Destino opcional. Quando omitido, edita in-place em InputPath.

.PARAMETER Anchor
    Substring literal a localizar (multi-linha permitida; escapes do chamador).
    A contagem usa ocorrências literais NAO sobrepostas, esquerda->direita,
    comparacao Ordinal.

.PARAMETER Replacement
    Texto substituto (Replace) ou texto inserido após a ancora (InsertAfter).
    Vazio é permitido: em Replace, remove a ancora; em InsertAfter, é no-op (26).

.PARAMETER EditMode
    Replace ou InsertAfter.

.PARAMETER ExpectedAnchorCount
    Número esperado de ocorrências da ancora (minimo 1; sem teto superior).
    Default: 1. Apenas valida a contagem; o escopo de aplicacao e decidido por
    -ApplyToAllOccurrences.

.PARAMETER ApplyToAllOccurrences
    Aplica em TODAS as ocorrências literais. Com mais de uma ocorrência e sem
    este switch, a rodada devolve 18 (AMBIGUOUS_APPLY_SCOPE). O switch nao
    relaxa a contagem: o número real ainda tem de bater com o esperado.

.PARAMETER PreserveLastUpdate
    Não atualiza lastUpdate na raiz do Object.

.PARAMETER LastUpdateBaselinePath
    XML usado como baseline para o bump. Quando omitido, usa InputPath. Exigido
    apenas quando ha bump: caminho inexistente (ou diretorio) devolve 16.

.PARAMETER DryRun
    Simula o apply sem gravar nem criar backup.

.PARAMETER AssertWellFormedAfter
    Valida XML após gravar (default true). Em falha, restaura .bak.

.PARAMETER AsJson
    Saida estruturada JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Anchor,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Replacement,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Replace', 'InsertAfter')]
    [string]$EditMode,

    [int]$ExpectedAnchorCount = 1,

    [switch]$ApplyToAllOccurrences,

    [switch]$PreserveLastUpdate,

    [string]$LastUpdateBaselinePath,

    [switch]$DryRun,

    [bool]$AssertWellFormedAfter = $true,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SurgicalCatchMapping {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    $map = @(
        @{ Prefix = 'ANCHOR_FAIL:'; Code = 'ANCHOR_FAIL'; ExitCode = 11 },
        @{ Prefix = 'NO_LASTUPDATE:'; Code = 'NO_LASTUPDATE'; ExitCode = 12 },
        @{ Prefix = 'XML_NOT_WELLFORMED_AFTER:'; Code = 'XML_NOT_WELLFORMED_AFTER'; ExitCode = 13 },
        @{ Prefix = 'BASELINE_NOT_FOUND:'; Code = 'BASELINE_NOT_FOUND'; ExitCode = 16 },
        @{ Prefix = 'EXPECTED_ANCHOR_COUNT_INVALID:'; Code = 'EXPECTED_ANCHOR_COUNT_INVALID'; ExitCode = 17 },
        @{ Prefix = 'AMBIGUOUS_APPLY_SCOPE:'; Code = 'AMBIGUOUS_APPLY_SCOPE'; ExitCode = 18 },
        @{ Prefix = 'SELFCHECK_MUTATION_MISMATCH:'; Code = 'SELFCHECK_MUTATION_MISMATCH'; ExitCode = 19 },
        @{ Prefix = 'NOOP_REPLACEMENT:'; Code = 'NOOP_REPLACEMENT'; ExitCode = 26 },
        @{ Prefix = 'ANCHOR_EMPTY:'; Code = 'ANCHOR_EMPTY'; ExitCode = 27 },
        @{ Prefix = 'LASTUPDATE_TARGET_MOVED:'; Code = 'LASTUPDATE_TARGET_MOVED'; ExitCode = 28 }
    )

    foreach ($entry in $map) {
        if ($Message.StartsWith($entry.Prefix, [System.StringComparison]::Ordinal)) {
            return [pscustomobject]@{ Code = $entry.Code; ExitCode = $entry.ExitCode }
        }
    }
    return [pscustomobject]@{ Code = 'INTERNAL_ERROR'; ExitCode = 90 }
}

function Write-SurgicalHumanOutput {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

    if ($Result.Status -eq 'ERROR') {
        Write-Output $Result.Message
        return
    }

    Write-Output 'EDIT_OK'
    Write-Output ("  input                  : {0}" -f $Result.InputPath)
    Write-Output ("  output                 : {0}" -f $Result.OutputPath)
    Write-Output ("  editMode               : {0}" -f $Result.EditMode)
    Write-Output ("  dryRun                 : {0}" -f $Result.DryRun)
    Write-Output ("  anchor_count           : {0} (expected {1})" -f $Result.AnchorCount, $Result.ExpectedAnchorCount)
    Write-Output ("  replacements_applied   : {0}" -f $Result.ReplacementsApplied)
    Write-Output ("  post_patch_anchor_count: {0}" -f $Result.PostPatchAnchorCount)
    Write-Output ("  detected_eol           : {0}" -f $Result.DetectedEol)
    Write-Output ("  bytes_before           : {0}" -f $Result.BytesBefore)
    Write-Output ("  bytes_after            : {0}" -f $Result.BytesAfter)
    if ($Result.BytesDelta -ge 0) {
        Write-Output ("  bytes_delta            : +{0}" -f $Result.BytesDelta)
    } else {
        Write-Output ("  bytes_delta            : {0}" -f $Result.BytesDelta)
    }

    if ($Result.PreserveLastUpdate) {
        Write-Output ("  lastUpdate             : {0} (preserved)" -f $Result.LastUpdateBefore)
    } elseif ($Result.WillBumpLastUpdate) {
        Write-Output ("  lastUpdate             : {0} -> {1}" -f $Result.LastUpdateBefore, $Result.LastUpdateAfter)
        if (-not [string]::IsNullOrWhiteSpace($Result.LastUpdateBaselinePath)) {
            Write-Output ("  baseline               : {0}" -f $Result.LastUpdateBaselinePath)
        }
    }

    if ($Result.ReplacementEolMismatch -eq $true) {
        Write-Output ("  aviso                  : Replacement usa EOL diferente do texto (detected_eol={0}); o motor nao normaliza." -f $Result.DetectedEol)
    }

    if ($null -ne $Result.WellFormed) {
        Write-Output ("  wellFormed             : {0}" -f $Result.WellFormed)
    }
}

function ConvertTo-SurgicalJsonOutput {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

    if ($Result.Status -eq 'ERROR') {
        return [pscustomobject]@{
            status   = 'ERROR'
            code     = $Result.Code
            message  = $Result.Message
            exitCode = $Result.ExitCode
            details  = $Result.Details
        }
    }

    return [pscustomobject]@{
        status                 = 'OK'
        code                   = $Result.Code
        dryRun                 = $Result.DryRun
        editMode               = $Result.EditMode
        inputPath              = $Result.InputPath
        outputPath             = $Result.OutputPath
        anchorCount            = $Result.AnchorCount
        expectedAnchorCount    = $Result.ExpectedAnchorCount
        applyToAllOccurrences  = $Result.ApplyToAllOccurrences
        replacementsApplied    = $Result.ReplacementsApplied
        postPatchAnchorCount   = $Result.PostPatchAnchorCount
        bytesBefore            = $Result.BytesBefore
        bytesAfter             = $Result.BytesAfter
        bytesDelta             = $Result.BytesDelta
        lastUpdateBefore       = $Result.LastUpdateBefore
        lastUpdateAfter        = $Result.LastUpdateAfter
        preserveLastUpdate     = $Result.PreserveLastUpdate
        willBumpLastUpdate     = $Result.WillBumpLastUpdate
        lastUpdateBaselinePath = $Result.LastUpdateBaselinePath
        detectedEol            = $Result.DetectedEol
        sourceEolMixed         = $Result.SourceEolMixed
        replacementEolMismatch = $Result.ReplacementEolMismatch
        mutatedIntervals       = $Result.MutatedIntervals
        wellFormed             = $Result.WellFormed
        wellFormedError        = $Result.WellFormedError
        replacementPreview     = $Result.ReplacementPreview
        bakPath                = $Result.BakPath
    }
}

try {
    $supportPath = Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1'
    if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
        throw "GeneXusXmlSurgicalEditSupport.ps1 nao encontrado: $supportPath"
    }

    . $supportPath

    $coreResult = Invoke-GeneXusXmlSurgicalEditCore `
        -InputPath $InputPath `
        -OutputPath $OutputPath `
        -Anchor $Anchor `
        -Replacement $Replacement `
        -EditMode $EditMode `
        -ExpectedAnchorCount $ExpectedAnchorCount `
        -ApplyToAllOccurrences:$ApplyToAllOccurrences.IsPresent `
        -PreserveLastUpdate:$PreserveLastUpdate.IsPresent `
        -LastUpdateBaselinePath $LastUpdateBaselinePath `
        -DryRun:$DryRun.IsPresent `
        -AssertWellFormedAfter $AssertWellFormedAfter

    if ($AsJson) {
        ConvertTo-SurgicalJsonOutput -Result $coreResult | ConvertTo-Json -Depth 6 -Compress
    } else {
        Write-SurgicalHumanOutput -Result $coreResult
    }

    exit [int]$coreResult.ExitCode
} catch {
    $message = $_.Exception.Message
    $mapping = Get-SurgicalCatchMapping -Message $message
    if ($AsJson) {
        [pscustomobject]@{
            status   = 'ERROR'
            code     = $mapping.Code
            message  = $message
            exitCode = $mapping.ExitCode
            details  = $null
        } | ConvertTo-Json -Depth 4 -Compress
    } else {
        Write-Output $message
    }
    exit [int]$mapping.ExitCode
}
