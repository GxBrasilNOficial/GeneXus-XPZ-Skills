#requires -Version 7.4
<#
.SYNOPSIS
    Contrato de assinatura do extrator KbIntelligence, calculado pelo dono Python.
#>

Set-StrictMode -Version Latest

function Get-GeneXusKbIntelligenceExpectedExtractorSignature {
    $scriptDir = $PSScriptRoot
    . (Join-Path $scriptDir 'GeneXusPythonPrerequisite.ps1')
    $signaturePath = Join-Path $scriptDir 'GeneXusKbIntelligenceExtractorSignature.py'
    if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) {
        throw "GeneXusKbIntelligenceExtractorSignature.py nao encontrado: $signaturePath"
    }
    $repoRoot = Split-Path -Parent $scriptDir
    $python = Get-GeneXusPythonExecutable
    if ($null -eq $python) {
        throw (Get-GeneXusPythonPrerequisiteErrorMessage)
    }

    $output = @(& $python.Source -B $signaturePath '--repo-root' $repoRoot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $detail = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($detail)) { $detail = '(sem saida capturada do calculador Python)' }
        throw "Nao foi possivel calcular a assinatura canonica do extrator (exit $LASTEXITCODE).`n$detail"
    }
    $jsonText = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    try {
        $payload = $jsonText | ConvertFrom-Json -AsHashtable
    } catch {
        throw "Calculador Python retornou JSON invalido: $($_.Exception.Message)"
    }
    $invalidPayload = $payload -isnot [System.Collections.IDictionary]
    if (-not $invalidPayload) {
        $invalidPayload = [string]::IsNullOrWhiteSpace([string]$payload.extractor_signature_version)
        if (-not $invalidPayload) { $invalidPayload = [string]::IsNullOrWhiteSpace([string]$payload.extractor_signature_hash) }
        if (-not $invalidPayload) { $invalidPayload = [string]$payload.extractor_signature_hash -notmatch '^[0-9a-f]{64}$' }
        if (-not $invalidPayload) { $invalidPayload = [string]$payload.extractor_signature_format -ne 'manifest-lf-v1' }
    }
    if ($invalidPayload) {
        throw 'Calculador Python retornou contrato de assinatura incompleto ou invalido.'
    }
    return [ordered]@{
        extractor_signature_version = [string]$payload.extractor_signature_version
        extractor_signature_hash    = [string]$payload.extractor_signature_hash
        extractor_signature_format  = [string]$payload.extractor_signature_format
    }
}

function Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metadata
    )

    $expected = Get-GeneXusKbIntelligenceExpectedExtractorSignature
    $storedVersion = $Metadata['extractor_signature_version']
    $storedHash = $Metadata['extractor_signature_hash']
    $storedFormat = $Metadata['extractor_signature_format']
    $missingSignature = [string]::IsNullOrWhiteSpace($storedVersion)
    if (-not $missingSignature) { $missingSignature = [string]::IsNullOrWhiteSpace($storedHash) }
    if (-not $missingSignature) { $missingSignature = [string]::IsNullOrWhiteSpace($storedFormat) }
    if ($missingSignature) {
        return [ordered]@{
            ok = $false
            reason = 'indice_sem_assinatura_extrator'
            summary = 'Indice legado sem versao/hash/formato da assinatura do extrator — regenerar.'
            expected = $expected
            stored = [ordered]@{ extractor_signature_version = $storedVersion
                                 extractor_signature_hash = $storedHash
                                 extractor_signature_format = $storedFormat }
        }
    }
    if ($storedVersion -ne $expected.extractor_signature_version) {
        return [ordered]@{
            ok = $false
            reason = 'extrator_version_defasada'
            summary = ('Versao do extrator indexada {0}, atual {1} — regenerar indice.' -f $storedVersion, $expected.extractor_signature_version)
            expected = $expected
            stored = [ordered]@{ extractor_signature_version = $storedVersion
                                 extractor_signature_hash = $storedHash
                                 extractor_signature_format = $storedFormat }
        }
    }
    if ($storedFormat -ne $expected.extractor_signature_format) {
        return [ordered]@{
            ok = $false
            reason = 'extrator_format_defasado'
            summary = 'Formato da assinatura do extrator incompatível — regenerar índice.'
            expected = $expected
            stored = [ordered]@{ extractor_signature_version = $storedVersion
                                 extractor_signature_hash = $storedHash
                                 extractor_signature_format = $storedFormat }
        }
    }
    if ($storedHash -ne $expected.extractor_signature_hash) {
        return [ordered]@{
            ok = $false
            reason = 'extrator_hash_defasado'
            summary = 'Assinatura do extrator difere dos arquivos automáticos atuais — regenerar índice.'
            expected = $expected
            stored = [ordered]@{ extractor_signature_version = $storedVersion
                                 extractor_signature_hash = $storedHash
                                 extractor_signature_format = $storedFormat }
        }
    }
    return [ordered]@{
        ok = $true
        reason = $null
        summary = $null
        expected = $expected
        stored = [ordered]@{ extractor_signature_version = $storedVersion
                             extractor_signature_hash = $storedHash
                             extractor_signature_format = $storedFormat }
    }
}

function Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IndexMetadataText
    )

    $metadata = @{}
    foreach ($line in ($IndexMetadataText -split "(`r`n|`n|`r)")) {
        if ($line -match '^(?<key>[A-Za-z0-9_]+)\s*:\s*(?<value>.+)$') {
            $metadata[$Matches.key] = $Matches.value.Trim()
        }
    }
    return $metadata
}
