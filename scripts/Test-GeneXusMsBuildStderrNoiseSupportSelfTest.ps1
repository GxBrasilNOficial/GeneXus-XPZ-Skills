#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusMsBuildStderrNoiseSupport.ps1')

$anonymousComponent = "context [anonymous] 1:12 attribute component isn't defined"
$serviceWorkerObj = "context [/g_service_worker] 7:4 attribute obj isn't defined"
$anonymousObj = "context [anonymous] 1:12 attribute obj isn't defined"
$serviceWorkerComponent = "context [/g_service_worker] 7:4 attribute component isn't defined"
$realError = 'MSBUILD : error MSB1001: Unknown switch.'

$pureNoise = Get-GeneXusMsBuildStderrNoiseClassification -Text ($anonymousComponent + "`r`n" + $serviceWorkerObj)
if (-not [string]::IsNullOrWhiteSpace($pureNoise.FilteredText)) {
    throw "Ruido puro deveria resultar em stderr vazio: $($pureNoise.FilteredText)"
}
if (@($pureNoise.NoiseText -split "`n").Count -ne 2) {
    throw 'Os dois pares conhecidos deveriam ser filtrados.'
}
$noiseLines = @($pureNoise.NoiseText -split "`n")
if (@($noiseLines | Where-Object { $_.EndsWith("`r") }).Count -ne 0) {
    throw 'Linhas em stderrFilteredNoise nao podem carregar CR residual.'
}

$mixed = Get-GeneXusMsBuildStderrNoiseClassification -Text ($anonymousComponent + "`n" + $realError)
if ($mixed.FilteredText -ne $realError) {
    throw "Erro real deveria ser preservado apos filtro: $($mixed.FilteredText)"
}

$negative = Get-GeneXusMsBuildStderrNoiseClassification -Text ($anonymousObj + "`n" + $serviceWorkerComponent)
$negativeLines = @($negative.FilteredText -split "`n")
if ($negativeLines -notcontains $anonymousObj -or $negativeLines -notcontains $serviceWorkerComponent) {
    throw 'Pares cruzados nao documentados nao podem ser filtrados.'
}

$embeddedPattern = "WARN: $anonymousComponent"
$embedded = Get-GeneXusMsBuildStderrNoiseClassification -Text $embeddedPattern
if ($embedded.FilteredText -ne $embeddedPattern -or -not [string]::IsNullOrWhiteSpace($embedded.NoiseText)) {
    throw 'Linha que apenas contem padrao conhecido deve permanecer como stderr real.'
}

foreach ($wrapperName in @('Invoke-GeneXusKbBuildAll.ps1', 'Invoke-GeneXusKbSpecifyGenerate.ps1')) {
    $wrapperText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $wrapperName)
    if ([regex]::Matches($wrapperText, 'Get-GeneXusMsBuildStderrNoiseClassification').Count -lt 2) {
        throw "$wrapperName deve usar o filtro compartilhado no fluxo normal e no recovery."
    }
    if ($wrapperText -notmatch 'stderrContent\s*=\s*@\(\$recoveryStdErrContent' -or
        $wrapperText -notmatch 'stderrFilteredNoise\s*=\s*@\(\$recoveryStdErrFilteredNoise') {
        throw "$wrapperName deve expor stderr filtrado no recovery."
    }
}

foreach ($consumerName in @('Invoke-GeneXusXpzImport.ps1', 'Invoke-GeneXusXpzExport.ps1', 'Test-GeneXusXpzImportPreview.ps1', 'Open-GeneXusKbHeadless.ps1', 'Get-GeneXusKbProperty.ps1', 'Test-GeneXusKbConsistency.ps1')) {
    $consumerText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $consumerName)
    if ($consumerText -notmatch '\. \$stderrNoiseSupportPath' -or
        [regex]::Matches($consumerText, 'Get-GeneXusMsBuildStderrNoiseClassification').Count -ne 1) {
        throw "$consumerName deve carregar e usar uma vez o filtro compartilhado de stderr."
    }
}

'GENEXUS_MSBUILD_STDERR_NOISE_SUPPORT_SELFTEST_OK'
