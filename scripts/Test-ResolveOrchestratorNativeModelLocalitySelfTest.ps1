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

# (3) prefixo cursor sem mapeamento de Criador -> unknown / native-cursor-prefix
$r3 = & $locality -Model 'cursor/modelo-sem-mapeamento' | ConvertFrom-Json
Assert-True ([string]$r3.locality -eq 'unknown') "(3) locality deveria ser unknown; veio '$($r3.locality)'."
Assert-True ([string]$r3.reason -eq 'native-cursor-prefix') "(3) reason deveria ser native-cursor-prefix; veio '$($r3.reason)'."

# (4) criador cloud conhecido -> external / native-cloud-creator (resolvedor direto)
$r4 = & $locality -Model 'moonshot/kimi-k3-max' | ConvertFrom-Json
Assert-True ([string]$r4.locality -eq 'external') "(4) locality deveria ser external; veio '$($r4.locality)'."
Assert-True ([string]$r4.reason -eq 'native-cloud-creator') "(4) reason deveria ser native-cloud-creator; veio '$($r4.reason)'."
Assert-True ([string]$r4.family -eq 'moonshot') "(4) family deveria ser moonshot; veio '$($r4.family)'."

# (5) G16: criador fora da allowlist -> unknown / native-unknown-family (nunca local)
$r5 = & $locality -Model 'fabrica-inventada/modelo-x' | ConvertFrom-Json
Assert-True ([string]$r5.locality -eq 'unknown') "(5) criador desconhecido deveria ser unknown; veio '$($r5.locality)'."
Assert-True ([string]$r5.reason -eq 'native-unknown-family') "(5) reason deveria ser native-unknown-family; veio '$($r5.reason)'."
Assert-True ([string]$r5.locality -ne 'local') '(5) nativo nunca deveria classificar como local.'

# (6) cursor-grok-* (slug sem barra) -> xai / external / native-cloud-creator
$r6 = & $locality -Model 'cursor-grok-4.6-medium' | ConvertFrom-Json
Assert-True ([string]$r6.family -eq 'xai') "(6) family deveria ser xai; veio '$($r6.family)'."
Assert-True ([string]$r6.locality -eq 'external') "(6) locality deveria ser external; veio '$($r6.locality)'."
Assert-True ([string]$r6.reason -eq 'native-cloud-creator') "(6) reason deveria ser native-cloud-creator; veio '$($r6.reason)'."

# (7) cursor/grok-* (forma com barra) -> xai / external
$r7 = & $locality -Model 'cursor/grok-4' | ConvertFrom-Json
Assert-True ([string]$r7.family -eq 'xai') "(7) family deveria ser xai; veio '$($r7.family)'."
Assert-True ([string]$r7.locality -eq 'external') "(7) locality deveria ser external; veio '$($r7.locality)'."
Assert-True ([string]$r7.reason -eq 'native-cloud-creator') "(7) reason deveria ser native-cloud-creator; veio '$($r7.reason)'."

# (8) cursor/composer-* -> anysphere / external (Criador dos pesos, nao o dono societario)
$r8 = & $locality -Model 'cursor/composer-2' | ConvertFrom-Json
Assert-True ([string]$r8.family -eq 'anysphere') "(8) family deveria ser anysphere; veio '$($r8.family)'."
Assert-True ([string]$r8.locality -eq 'external') "(8) locality deveria ser external; veio '$($r8.locality)'."
Assert-True ([string]$r8.reason -eq 'native-cloud-creator') "(8) reason deveria ser native-cloud-creator; veio '$($r8.reason)'."

# (9) cursor-composer-* (slug sem barra) -> anysphere / external
$r9 = & $locality -Model 'cursor-composer-2-medium' | ConvertFrom-Json
Assert-True ([string]$r9.family -eq 'anysphere') "(9) family deveria ser anysphere; veio '$($r9.family)'."
Assert-True ([string]$r9.locality -eq 'external') "(9) locality deveria ser external; veio '$($r9.locality)'."
Assert-True ([string]$r9.reason -eq 'native-cloud-creator') "(9) reason deveria ser native-cloud-creator; veio '$($r9.reason)'."

Write-Host 'OK: Test-ResolveOrchestratorNativeModelLocalitySelfTest.ps1'
