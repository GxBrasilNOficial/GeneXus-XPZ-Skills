#requires -Version 7.4

<#
.SYNOPSIS
    Verifica se o setup da pasta paralela da KB está fresco em relacao ao contrato de setup XPZ.

.DESCRIPTION
    Le last_setup_audit_run_at e setup_contract_signature_* de kb-source-metadata.md,
    calcula a assinatura atual da superficie de contrato de xpz-kb-parallel-setup e
    compara com a assinatura gravada após a última auditoria bem-sucedida.
    Retorna GATE_ONLY quando a assinatura auditada coincide com a atual; retorna
    AUDIT_REQUIRED com motivo nos demais casos.

    Projetado para ser chamado pelo wrapper local Test-*KbSetupFreshness.ps1 como primeira ação
    da PRE-CONDICAO obrigatória em xpz-kb-parallel-setup.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB (deve conter kb-source-metadata.md).

.PARAMETER SkillsRoot
    Raiz do repositório de skills XPZ (GeneXus-XPZ-Skills).

.OUTPUTS
    String: "GATE_ONLY" ou "AUDIT_REQUIRED: <motivo>"

.EXAMPLE
    .\Test-XpzSetupFreshness.ps1 -KbParallelRoot "C:\DevTests\Gx_MyCinema" -SkillsRoot "C:\Dev\Knowledge\GeneXus-XPZ-Skills"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [Parameter(Mandatory = $true)]
    [string]$SkillsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    Write-Output "AUDIT_REQUIRED: kb-source-metadata.md ausente em $KbParallelRoot"
    exit 0
}

$content = Get-Content -LiteralPath $metadataPath -Raw

if ($content -notmatch '(?m)^last_setup_audit_run_at:\s*(.+)$') {
    Write-Output 'AUDIT_REQUIRED: campo last_setup_audit_run_at ausente em kb-source-metadata.md'
    exit 0
}

$rawTimestamp = $Matches[1].Trim()

if ([string]::IsNullOrWhiteSpace($rawTimestamp)) {
    Write-Output 'AUDIT_REQUIRED: campo last_setup_audit_run_at vazio em kb-source-metadata.md'
    exit 0
}

$lastAudit = $null
try {
    $lastAudit = [DateTimeOffset]::Parse($rawTimestamp)
} catch {
    Write-Output "AUDIT_REQUIRED: last_setup_audit_run_at nao e timestamp valido: '$rawTimestamp'"
    exit 0
}

$storedSignatureVersion = $null
if ($content -match '(?m)^setup_contract_signature_version:\s*(.+)$') {
    $storedSignatureVersion = $Matches[1].Trim()
}

if ([string]::IsNullOrWhiteSpace($storedSignatureVersion)) {
    Write-Output 'AUDIT_REQUIRED: campo setup_contract_signature_version ausente em kb-source-metadata.md'
    exit 0
}

$storedSignatureHash = $null
if ($content -match '(?m)^setup_contract_signature_hash:\s*(.+)$') {
    $storedSignatureHash = $Matches[1].Trim()
}

if ([string]::IsNullOrWhiteSpace($storedSignatureHash)) {
    Write-Output 'AUDIT_REQUIRED: campo setup_contract_signature_hash ausente em kb-source-metadata.md'
    exit 0
}

if ($storedSignatureHash -notmatch '^[0-9a-fA-F]{64}$') {
    Write-Output "AUDIT_REQUIRED: setup_contract_signature_hash invalido em kb-source-metadata.md: '$storedSignatureHash'"
    exit 0
}

$signatureScriptPath = Join-Path $SkillsRoot 'scripts\Get-XpzSetupContractSignature.ps1'
if (-not (Test-Path -LiteralPath $signatureScriptPath -PathType Leaf)) {
    Write-Output "AUDIT_REQUIRED: motor de assinatura do contrato de setup ausente em $signatureScriptPath"
    exit 0
}

$signatureJson = & $signatureScriptPath -SkillsRoot $SkillsRoot -AsJson
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($signatureJson)) {
    Write-Output "AUDIT_REQUIRED: nao foi possivel calcular assinatura atual do contrato de setup em $SkillsRoot"
    exit 0
}

$currentSignature = $signatureJson | ConvertFrom-Json

if ($storedSignatureVersion -ne $currentSignature.signatureVersion) {
    Write-Output "AUDIT_REQUIRED: versao da assinatura do contrato de setup mudou de $storedSignatureVersion para $($currentSignature.signatureVersion); ultimo audit em $($lastAudit.ToString('o'))"
    exit 0
}

if ($storedSignatureHash -ne $currentSignature.signatureHash) {
    Write-Output "AUDIT_REQUIRED: contrato de setup atualizado; assinatura atual $($currentSignature.signatureHash); assinatura auditada $storedSignatureHash; ultimo audit em $($lastAudit.ToString('o'))"
    exit 0
}

Write-Output 'GATE_ONLY'
exit 0
