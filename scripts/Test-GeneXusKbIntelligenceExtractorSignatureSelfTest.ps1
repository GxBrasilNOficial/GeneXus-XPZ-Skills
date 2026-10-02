#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contractPath = Join-Path $PSScriptRoot 'GeneXusKbIntelligenceExtractorContract.ps1'
if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "GeneXusKbIntelligenceExtractorContract.ps1 nao encontrado: $contractPath"
}
. $contractPath
. (Join-Path $PSScriptRoot 'GeneXusPythonPrerequisite.ps1')

$indexRebuildPrerequisiteMessage = Get-GeneXusPythonPrerequisiteErrorMessage -Operation 'index-rebuild'
if ($indexRebuildPrerequisiteMessage -notmatch 'rebuild do indice KbIntelligence nao foi concluido') {
    throw 'Mensagem do pre-requisito de rebuild nao identifica a atualizacao incompleta do indice'
}

$signaturePrerequisiteMessage = Get-GeneXusPythonPrerequisiteErrorMessage -Operation 'extractor-signature'
if ($signaturePrerequisiteMessage -notmatch 'assinatura atual do extrator nao pode ser calculada' -or
    $signaturePrerequisiteMessage -match 'apenas o indice KbIntelligence nao foi gerado') {
    throw 'Mensagem do pre-requisito de assinatura deve identificar a validacao incompleta sem afirmar que o indice nao existe'
}

$writabilityPrerequisiteMessage = Get-GeneXusPythonPrerequisiteErrorMessage -Operation 'transaction-writability'
if ($writabilityPrerequisiteMessage -notmatch 'classificacao automatica de gravabilidade nao pode ser concluida') {
    throw 'Mensagem do pre-requisito de gravabilidade nao identifica a operacao incompleta'
}

$expected = Get-GeneXusKbIntelligenceExpectedExtractorSignature
if ($expected.extractor_signature_version -ne '16') {
    throw "Vetor fixo de versao divergente: esperado 16, obtido $($expected.extractor_signature_version)"
}
if ($expected.extractor_signature_hash -ne 'e46b53b895974602af1f60ccf05a13524674be02b882f691e83b5fe53319e97f') {
    throw "Vetor fixo de hash divergente: $($expected.extractor_signature_hash)"
}
if ($expected.extractor_signature_format -ne 'manifest-lf-v1') {
    throw "Formato inesperado: $($expected.extractor_signature_format)"
}

$okResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{
    extractor_signature_version = $expected.extractor_signature_version
    extractor_signature_hash    = $expected.extractor_signature_hash
    extractor_signature_format  = $expected.extractor_signature_format
}
if (-not $okResult.ok) {
    throw "Assinatura esperada deveria passar: $($okResult.summary)"
}

$missingResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{}
if ($missingResult.ok) {
    throw 'Metadata vazia deveria falhar'
}
if ($missingResult.reason -ne 'indice_sem_assinatura_extrator') {
    throw "reason incorreto: $($missingResult.reason)"
}

$versionResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{
    extractor_signature_version = '0'
    extractor_signature_hash    = $expected.extractor_signature_hash
    extractor_signature_format  = $expected.extractor_signature_format
}
if ($versionResult.ok -or $versionResult.reason -ne 'extrator_version_defasada') {
    throw 'Versao defasada deveria falhar com extrator_version_defasada'
}

$formatResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{
    extractor_signature_version = $expected.extractor_signature_version
    extractor_signature_hash    = $expected.extractor_signature_hash
    extractor_signature_format  = 'legacy-raw-file-v0'
}
if ($formatResult.ok -or $formatResult.reason -ne 'extrator_format_defasado') {
    throw 'Formato defasado deveria falhar com extrator_format_defasado'
}

Write-Output 'KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK'
