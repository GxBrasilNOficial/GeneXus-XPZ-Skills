[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbRoot,

    [Parameter(Mandatory = $true)]
    [string]$GateWrapperPath,

    [Parameter(Mandatory = $true)]
    [string]$MetadataWrapperTestPath,

    [string]$SourceSanityWrapperPath,

    [string]$PackageCollisionWrapperPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-WrapperText {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "BLOCK: wrapper ausente: $Path"
    }

    $output = & $Path 2>&1
    if (-not $?) {
        $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "BLOCK: wrapper falhou sem saida: $Path"
        }

        throw $text
    }

    return (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
}

function Get-MetadataField {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    $pattern = '^\s*{0}\s*[:=]\s*(?<value>.+?)\s*$' -f [regex]::Escape($FieldName)
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Normalize-Value {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed -eq '(ausente)') {
        return $null
    }

    return $trimmed
}

function Emit-Line {
    param(
        [string]$Key,
        [string]$Value
    )

    '{0}: {1}' -f $Key, $Value
}

$metadataPath = Join-Path $KbRoot 'kb-source-metadata.md'
if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md nao encontrado: $metadataPath"
}

$metadataLines = [System.IO.File]::ReadAllLines($metadataPath)
$lastMaterialization = Normalize-Value (Get-MetadataField -Lines $metadataLines -FieldName 'last_xpz_materialization_run_at')

$gateRaw = $null
$gateStatus = $null
try {
    $gateRaw = Invoke-WrapperText -Path $GateWrapperPath
    $gateStatus = if ($gateRaw -match '\bGATE_OK\b') { 'OK' } else { 'PENDENTE' }
} catch {
    $gateRaw = $_.Exception.Message.Trim()
    $gateStatus = 'BLOCK'
}

$metadataWrapperRaw = $null
$metadataWrapperStatus = $null
try {
    $metadataWrapperRaw = Invoke-WrapperText -Path $MetadataWrapperTestPath
    if ($metadataWrapperRaw -match '\bMETADATA_WRAPPER_OK\b') {
        $metadataWrapperStatus = 'OK'
    } elseif ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'PENDENTE'
    }
} catch {
    $metadataWrapperRaw = $_.Exception.Message.Trim()
    if ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'BLOCK'
    }
}

$syncStatus = if ($lastMaterialization) { 'OK' } else { 'PENDENTE' }
$syncEvidence = if ($lastMaterialization) {
    "last_xpz_materialization_run_at=$lastMaterialization"
} else {
    'last_xpz_materialization_run_at ausente'
}

$packagesDir = Join-Path $KbRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
$packageDirExists = Test-Path -LiteralPath $packagesDir -PathType Container
$hasSourceSanityWrapper = $SourceSanityWrapperPath -and (Test-Path -LiteralPath $SourceSanityWrapperPath -PathType Leaf)
$hasPackageCollisionWrapper = $PackageCollisionWrapperPath -and (Test-Path -LiteralPath $PackageCollisionWrapperPath -PathType Leaf)

if ($packageDirExists -or $hasSourceSanityWrapper -or $hasPackageCollisionWrapper) {
    if ($hasSourceSanityWrapper -and $hasPackageCollisionWrapper) {
        $packageAuditStatus = 'OK'
    } else {
        $packageAuditStatus = 'PENDENTE'
    }
} else {
    $packageAuditStatus = 'NAO_ADOTADO'
}

$packageEvidenceParts = @()
$packageEvidenceParts += ('packages_dir={0}' -f $(if ($packageDirExists) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('source_sanity_wrapper={0}' -f $(if ($hasSourceSanityWrapper) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('package_collision_wrapper={0}' -f $(if ($hasPackageCollisionWrapper) { 'presente' } else { 'ausente' }))
$packageEvidence = $packageEvidenceParts -join '; '

$suggestedState = switch ($true) {
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $packageAuditStatus -eq 'OK') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $packageAuditStatus -eq 'NAO_ADOTADO') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $packageAuditStatus -eq 'PENDENTE') { 'auditoria_de_empacotamento_pendente'; break }
    ($syncStatus -eq 'PENDENTE') { 'pronto_para_primeira_materializacao'; break }
    default { 'wrappers_atualizados' }
}

Emit-Line -Key 'sync/materializacao' -Value $syncStatus
Emit-Line -Key 'sync/materializacao.evidencia' -Value $syncEvidence
Emit-Line -Key 'indice/gate' -Value $gateStatus
Emit-Line -Key 'indice/gate.evidencia' -Value $(if ($gateRaw) { $gateRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'metadata wrapper' -Value $metadataWrapperStatus
Emit-Line -Key 'metadata wrapper.evidencia' -Value $(if ($metadataWrapperRaw) { $metadataWrapperRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'empacotamento local' -Value $packageAuditStatus
Emit-Line -Key 'empacotamento local.evidencia' -Value $packageEvidence
Emit-Line -Key 'estado_operacional_sugerido' -Value $suggestedState
