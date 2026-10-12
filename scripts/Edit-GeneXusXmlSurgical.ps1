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

    EOL: o motor nao normaliza. Quando a fonte tem EOL uniforme (CRLF/LF/CR) e o
    Replacement traz quebra diferente da dominante (ou EOL misto dentro dele), a
    rodada falha com 29 REPLACEMENT_EOL_MISMATCH sem gravar (apply e dry-run);
    fonte Mixed segue diagnostico (replacementEolMismatch=null) e grava.

    Limite declarado: o motor nao detecta BOM na entrada; a leitura consome um
    BOM eventual e a gravacao e sempre UTF-8 sem BOM (padrao do repo).

    Codigos de saida (o contrato e o `code` string; o numero e por script):
      11 ANCHOR_FAIL                    14 INPUT_NOT_FOUND
      12 NO_LASTUPDATE                  15 OUTPUT_DIR_MISSING
      13 XML_NOT_WELLFORMED_AFTER       16 BASELINE_NOT_FOUND
      17 EXPECTED_ANCHOR_COUNT_INVALID  18 AMBIGUOUS_APPLY_SCOPE
      19 SELFCHECK_MUTATION_MISMATCH    26 NOOP_REPLACEMENT
      27 ANCHOR_EMPTY                   28 LASTUPDATE_TARGET_MOVED
      29 REPLACEMENT_EOL_MISMATCH       30 LASTUPDATE_CONTEXT_CONFLICT
      31 LASTUPDATE_BASELINE_IDENTITY_MISMATCH  90 INTERNAL_ERROR
      32 PAYLOAD_SOURCE_MISSING         33 PAYLOAD_SOURCE_CONFLICT
      34 PAYLOAD_PATH_INVALID           35 PAYLOAD_READ_FAILED
      36 PAYLOAD_ENCODING_INVALID

    Exatamente uma origem por conteúdo: Anchor ou AnchorPath; Replacement ou
    ReplacementPath. Omissões agora geram erro estruturado (32), não do binder.
    Nomes completos e posições existentes preservados; -Anc/-Rep passam a ser
    ambíguos. Use -Anchor/-Replacement completos. Sem aliases novos.

.PARAMETER InputPath
    Caminho do XML fonte.

.PARAMETER OutputPath
    Destino opcional. Quando omitido, edita in-place em InputPath.

.PARAMETER Anchor
    Substring literal a localizar, alternativa exclusiva a AnchorPath.
    Multi-linha permitida; escapes do chamador.
    A contagem usa ocorrências literais NAO sobrepostas, esquerda->direita,
    comparacao Ordinal.

.PARAMETER Replacement
    Texto substituto (Replace) ou inserido após a ancora (InsertAfter),
    alternativa exclusiva a ReplacementPath.
    Vazio é permitido: em Replace, remove a ancora; em InsertAfter, é no-op (26).
    Com fonte de EOL uniforme, a(s) quebra(s) do Replacement têm de casar com a
    dominante (ou o Replacement não pode ter quebra); senão → 29.

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
    Explícito com bump: mesma raiz Object/Attribute e GUID válido não zero
    igual, senão LASTUPDATE_BASELINE_IDENTITY_MISMATCH/31 (inclusive legado
    com GUID vazio). Lê só a raiz, proíbe DTD e não antecipa parse do corpo.

.PARAMETER NewObjectNotImported
    Declara objeto novo nunca importado: gera UtcNow + 60s sem acumular a
    frente. Não inferir pela ausência no acervo. Com baseline não vazio ou
    PreserveLastUpdate: LASTUPDATE_CONTEXT_CONFLICT/30, após 14/15 e antes
    de âncora/no-op/EOL. Sem escrita nem backup, inclusive em DryRun.

.PARAMETER DryRun
    Simula o apply sem gravar nem criar backup.

.PARAMETER AssertWellFormedAfter
    Valida XML após gravar (default true). Em falha, restaura .bak.

.PARAMETER AsJson
    Saida estruturada JSON.

.PARAMETER AnchorPath
    Arquivo auxiliar FileSystem UTF-8 estrito com ou sem BOM; remove somente
    um BOM inicial, preserva texto/EOL. Vazio resulta em ANCHOR_EMPTY.

.PARAMETER ReplacementPath
    Mesma leitura de AnchorPath. Vazio remove em Replace; InsertAfter é no-op.
    Assinaturas UTF-16/32 são recusadas; sem assinatura não há heurística
    (41 00 42 00 é UTF-8 válido). Não muda a leitura do XML-fonte.
    Auxiliares devem ser distintos do destino efetivo e seu .bak, inclusive
    por links/aliases, para preservação. Não há guarda de identidade física.
    Escolhas de origem, leitura de AnchorPath e depois ReplacementPath
    precedem as validações do núcleo (14/15/30). DryRun não cria auxiliares.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$OutputPath,

    [AllowEmptyString()]
    [string]$Anchor,

    [AllowEmptyString()]
    [string]$Replacement,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Replace', 'InsertAfter')]
    [string]$EditMode,

    [int]$ExpectedAnchorCount = 1,

    [switch]$ApplyToAllOccurrences,

    [switch]$PreserveLastUpdate,

    [switch]$NewObjectNotImported,

    [string]$LastUpdateBaselinePath,

    [switch]$DryRun,

    [bool]$AssertWellFormedAfter = $true,

    [switch]$AsJson,

    [AllowEmptyString()]
    [string]$AnchorPath,

    [AllowEmptyString()]
    [string]$ReplacementPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-SurgicalPayloadText {
    param([string]$LiteralPath, [string]$Role)

    $details = [pscustomobject]@{ role = $Role; parameter = "${Role}Path"; path = $LiteralPath }
    try {
        if ([string]::IsNullOrWhiteSpace($LiteralPath)) { throw 'Informe um caminho não vazio.' }
        $resolved = Resolve-Path -LiteralPath $LiteralPath -ErrorAction Stop
        if ($resolved.Provider.Name -ne 'FileSystem' -or
            -not (Test-Path -LiteralPath $LiteralPath -PathType Leaf -ErrorAction Stop)) {
            throw 'Informe um arquivo do provedor FileSystem.'
        }
    } catch {
        return [pscustomobject]@{ Text = $null; Error = (New-GeneXusXmlSurgicalError -Code 'PAYLOAD_PATH_INVALID' -ExitCode 34 -Message "PAYLOAD_PATH_INVALID: $($details.parameter): informe um arquivo FileSystem existente, não um diretório." -Details $details) }
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($resolved.ProviderPath)
    } catch {
        return [pscustomobject]@{ Text = $null; Error = (New-GeneXusXmlSurgicalError -Code 'PAYLOAD_READ_FAILED' -ExitCode 35 -Message "PAYLOAD_READ_FAILED: não foi possível ler $($details.parameter); confira acesso ao arquivo." -Details $details) }
    }
    try {
        # UTF-32 antes de UTF-16: FF FE 00 00 também tem prefixo UTF-16LE.
        $signature = $null
        if ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) { $signature = 'UTF-32LE' }
        elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) { $signature = 'UTF-32BE' }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $signature = 'UTF-16LE' }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $signature = 'UTF-16BE' }
        if ($null -ne $signature) {
            $details | Add-Member -NotePropertyName signature -NotePropertyValue $signature
            throw 'Assinatura não UTF-8.'
        }
        $offset = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes, $offset, $bytes.Length - $offset)
        return [pscustomobject]@{ Text = $text; Error = $null }
    } catch {
        return [pscustomobject]@{ Text = $null; Error = (New-GeneXusXmlSurgicalError -Code 'PAYLOAD_ENCODING_INVALID' -ExitCode 36 -Message "PAYLOAD_ENCODING_INVALID: $($details.parameter) exige UTF-8 válido, com ou sem BOM." -Details $details) }
    }
}

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
        @{ Prefix = 'LASTUPDATE_TARGET_MOVED:'; Code = 'LASTUPDATE_TARGET_MOVED'; ExitCode = 28 },
        @{ Prefix = 'REPLACEMENT_EOL_MISMATCH:'; Code = 'REPLACEMENT_EOL_MISMATCH'; ExitCode = 29 },
        @{ Prefix = 'LASTUPDATE_CONTEXT_CONFLICT:'; Code = 'LASTUPDATE_CONTEXT_CONFLICT'; ExitCode = 30 },
        @{ Prefix = 'LASTUPDATE_BASELINE_IDENTITY_MISMATCH:'; Code = 'LASTUPDATE_BASELINE_IDENTITY_MISMATCH'; ExitCode = 31 }
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
    Write-Output ("  newObjectNotImported   : {0}" -f $Result.NewObjectNotImported)
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
        newObjectNotImported   = $Result.NewObjectNotImported
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

    $coreResult = $null
    foreach ($role in @('Anchor', 'Replacement')) {
        $hasString = $PSBoundParameters.ContainsKey($role)
        $hasPath = $PSBoundParameters.ContainsKey("${role}Path")
        $details = [pscustomobject]@{ role = $role; parameter = $role; pathParameter = "${role}Path" }
        if ($hasPath) { $details | Add-Member -NotePropertyName path -NotePropertyValue $PSBoundParameters["${role}Path"] }
        if (-not $hasString -and -not $hasPath) {
            $coreResult = New-GeneXusXmlSurgicalError -Code 'PAYLOAD_SOURCE_MISSING' -ExitCode 32 -Message "PAYLOAD_SOURCE_MISSING: informe -$role ou -${role}Path." -Details $details
            break
        }
        if ($hasString -and $hasPath) {
            $coreResult = New-GeneXusXmlSurgicalError -Code 'PAYLOAD_SOURCE_CONFLICT' -ExitCode 33 -Message "PAYLOAD_SOURCE_CONFLICT: use somente -$role ou -${role}Path." -Details $details
            break
        }
    }
    if ($null -eq $coreResult -and $PSBoundParameters.ContainsKey('AnchorPath')) {
        $payload = Read-SurgicalPayloadText -LiteralPath $AnchorPath -Role Anchor
        $coreResult = $payload.Error
        $Anchor = $payload.Text
    }
    if ($null -eq $coreResult -and $PSBoundParameters.ContainsKey('ReplacementPath')) {
        $payload = Read-SurgicalPayloadText -LiteralPath $ReplacementPath -Role Replacement
        $coreResult = $payload.Error
        $Replacement = $payload.Text
    }
    if ($null -eq $coreResult) {
        $coreResult = Invoke-GeneXusXmlSurgicalEditCore `
        -InputPath $InputPath `
        -OutputPath $OutputPath `
        -Anchor $Anchor `
        -Replacement $Replacement `
        -EditMode $EditMode `
        -ExpectedAnchorCount $ExpectedAnchorCount `
        -ApplyToAllOccurrences:$ApplyToAllOccurrences.IsPresent `
        -PreserveLastUpdate:$PreserveLastUpdate.IsPresent `
        -NewObjectNotImported:$NewObjectNotImported.IsPresent `
        -LastUpdateBaselinePath $LastUpdateBaselinePath `
        -DryRun:$DryRun.IsPresent `
        -AssertWellFormedAfter $AssertWellFormedAfter
    }

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
