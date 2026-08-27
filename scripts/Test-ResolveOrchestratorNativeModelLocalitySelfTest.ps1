#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Resolve-OrchestratorNativeModelLocality.ps1 e do gate com Backend orchestrator-native.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$locality = Join-Path $PSScriptRoot 'Resolve-OrchestratorNativeModelLocality.ps1'
$auth = Join-Path $PSScriptRoot 'Resolve-LlmDelegateAuthorization.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $locality -PathType Leaf) "Script ausente: $locality"
Assert-True (Test-Path -LiteralPath $auth -PathType Leaf) "Script ausente: $auth"

# (1) Gate completo: orchestrator-native + kb-sensitive sem politica -> ask (sem PropertyNotFound)
$authOut = $null
$authErrMsg = $null
try {
    $authOut = & $auth -Backend orchestrator-native -Model 'moonshot/kimi-k3-max' -PayloadSensitivity 'kb-sensitive' | ConvertFrom-Json
} catch {
    $authErrMsg = [string]$_.Exception.Message
}
Assert-True ([string]::IsNullOrEmpty($authErrMsg)) ("(1) Gate nao deveria lancar; veio: {0}" -f $authErrMsg)
Assert-True ($null -ne $authOut) '(1) Gate deveria emitir JSON.'
Assert-True ([string]$authOut.verdict -eq 'ask') ("(1) sem politica, kb-sensitive + external/unknown -> ask; veio '{0}'." -f $authOut.verdict)
$authBlob = ($authOut | ConvertTo-Json -Depth 6 -Compress)
Assert-True ($authBlob -notlike '*PropertyNotFound*') '(1) nao deve haver PropertyNotFound no resultado.'
Assert-True ($authErrMsg -notlike '*PropertyNotFound*') '(1) nao deve haver PropertyNotFound na excecao.'

# (2) chave sem barra -> unknown / native-key-no-slash
$r2 = & $locality -Model 'kimi-k3-max' | ConvertFrom-Json
Assert-True ([string]$r2.locality -eq 'unknown') "(2) locality deveria ser unknown; veio '$($r2.locality)'."
Assert-True ([string]$r2.reason -eq 'native-key-no-slash') "(2) reason deveria ser native-key-no-slash; veio '$($r2.reason)'."

# (3) prefixo cursor -> unknown / native-cursor-prefix
$r3 = & $locality -Model 'cursor/composer-2' | ConvertFrom-Json
Assert-True ([string]$r3.locality -eq 'unknown') "(3) locality deveria ser unknown; veio '$($r3.locality)'."
Assert-True ([string]$r3.reason -eq 'native-cursor-prefix') "(3) reason deveria ser native-cursor-prefix; veio '$($r3.reason)'."

Write-Host 'OK: Test-ResolveOrchestratorNativeModelLocalitySelfTest.ps1'
