#requires -Version 7.4
<#
.SYNOPSIS
    Grava a lista CURADA de revisores preferidos do usuario para a oferta de revisao por
    pares (machine-level), a partir de uma selecao ja feita pelo usuario.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.
    Esta lista e PREFERENCIA do usuario (fato da MAQUINA), distinta de:
      - capabilities.json  (probe do que esta instalado; mesmo dir, regenerado)
      - llm-delegation-policy.json (autorizacao por-KB; raiz da pasta paralela)

    NAO e verdade do gate: o Resolve-LlmDelegateAuthorization.ps1 continua soberano por
    destino+sensibilidade. Preferencia != autorizacao.

    SCHEMA DE 2 EIXOS (ver `## ANATOMIA` do SKILL): cada revisor guarda
      - targetModelKey : chave de DESTINO canonica (ex.: openai/gpt-5.5) -> politica/autorizacao
      - invokeArgs     : argumentos sanitizados do adapter (model, e quando aplicavel
                         profile/oss/localProvider) -> mecanica da chamada
    canonicalModel sozinho nao reproduz a chamada do Codex (que usa -Model nu + profile/oss).

    SANITIZACAO POR DESENHO: grava SOMENTE backend, targetModelKey e invokeArgs com os
    campos permitidos (model/profile/oss/localProvider). NUNCA token, chave, baseURL,
    header, path de config ou politica.

    VETO DURO: revisores cujo modelo casa baixo-aterramento-comprovado (Mistral Large 3,
    Nemotron 3 Ultra — ver README, politica de modelos) sao DESCARTADOS com aviso, mesmo
    que o usuario os tenha escolhido (a preferencia nao supera o veto duro).

    A SELECAO e feita pelo usuario (gatilhos em 15/SKILL): o agente monta o menu
    (`opencode models` para o catalogo opencode + capabilities.json/defaults para os demais),
    o usuario escolhe, e este script PERSISTE a escolha. read-only -> oferta -> confirmacao.
.PARAMETER ReviewersJson
    JSON dos revisores escolhidos. Aceita o array v1/v2 ou um objeto com { reviewers: [...] }.
    No schema v2 cada revisor pode ter rank e fallbackChain[].
.PARAMETER OutputPath
    Caminho do arquivo. Default: %LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json.
.PARAMETER Preview
    Valida e emite o documento v2 que seria gravado, sem escrever o arquivo.
.EXAMPLE
    .\Set-LlmDelegatePreferredReviewers.ps1 -ReviewersJson '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $ReviewersJson,
    [string] $OutputPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'preferred-reviewers.json'),
    [switch] $Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

# Veto duro por baixo aterramento comprovado (README, politica de modelos). Casado pelo
# NOME do modelo (parte apos a ultima '/'), case-insensitive.
$hardVetoPatterns = @('mistral-large-3', 'nemotron-3-ultra')
$allowedBackends = @('opencode', 'codex', 'claude-code', 'copilot', 'gemini')
$allowedInvokeArgs = @('backend', 'model', 'profile', 'localProvider', 'oss', 'timeoutSec')

$parsed = $null
try { $parsed = $ReviewersJson | ConvertFrom-Json } catch {
    throw "BLOCK: -ReviewersJson nao e JSON valido: $($_.Exception.Message)"
}
$inputSchema = Get-Prop $parsed 'schemaVersion'
$itemsNode = Get-Prop $parsed 'reviewers'
$items = if ($null -ne $itemsNode) { @($itemsNode) } else { @($parsed) }
$fallbackPolicyIn = Get-Prop $parsed 'fallbackPolicy'

$kept = [System.Collections.Generic.List[object]]::new()
$discardedVeto = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()
$rankCounter = 0

function Test-HardVetoTarget {
    param([string]$TargetModelKey)
    $modelPart = @($TargetModelKey -split '/')[-1]
    foreach ($v in $hardVetoPatterns) {
        if ($modelPart.ToLowerInvariant().Contains($v)) { return $true }
    }
    return $false
}

function Copy-SanitizedInvokeArgs {
    param($InvokeArgs, [string]$Backend, [string]$TargetModelKey)
    $invClean = [ordered]@{}
    $invBackend = [string](Get-Prop $InvokeArgs 'backend')
    if (-not [string]::IsNullOrWhiteSpace($invBackend) -and $invBackend -ne $Backend) {
        throw "BLOCK: invokeArgs.backend ('$invBackend') diverge de backend ('$Backend') para $TargetModelKey"
    }
    $invClean['backend'] = $Backend
    foreach ($f in $allowedInvokeArgs) {
        if ($f -eq 'backend') { continue }
        $val = Get-Prop $InvokeArgs $f
        if ($null -eq $val) { continue }
        if ($f -eq 'oss') {
            if ($val -is [bool] -and $val) { $invClean[$f] = $true }
            continue
        }
        if ($f -eq 'timeoutSec') {
            $invClean[$f] = [int]$val
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$val)) { $invClean[$f] = [string]$val }
    }
    if (-not $invClean.Contains('model')) {
        $modelPart = @($TargetModelKey -split '/')[-1]
        $invClean['model'] = if ($Backend -eq 'codex') { $modelPart } else { $TargetModelKey }
    }
    return [pscustomobject]$invClean
}

function ConvertTo-ReviewerV2 {
    param($Item, [int]$DefaultRank)
    $backend = [string](Get-Prop $Item 'backend')
    $target = [string](Get-Prop $Item 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($target)) {
        $target = [string](Get-Prop $Item 'model')
    }
    if ([string]::IsNullOrWhiteSpace($backend) -or [string]::IsNullOrWhiteSpace($target)) {
        return @{ skipped = $true; target = $target }
    }
    if ($allowedBackends -notcontains $backend) {
        return @{ skipped = $true; target = $target }
    }
    if (Test-HardVetoTarget -TargetModelKey $target) {
        return @{ veto = $true; target = $target }
    }

    $rankValue = Get-Prop $Item 'rank'
    $rank = if ($null -ne $rankValue) { [int]$rankValue } else { $DefaultRank }
    $invClean = Copy-SanitizedInvokeArgs -InvokeArgs (Get-Prop $Item 'invokeArgs') -Backend $backend -TargetModelKey $target
    $chain = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$seen.Add("$backend|$target")
    $fallbackItems = Get-Prop $Item 'fallbackChain'
    if ($null -eq $fallbackItems) { $fallbackItems = @() }
    foreach ($fb in @($fallbackItems)) {
        $fbBackend = [string](Get-Prop $fb 'backend')
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        if ([string]::IsNullOrWhiteSpace($fbBackend) -or [string]::IsNullOrWhiteSpace($fbTarget) -or $null -eq (Get-Prop $fb 'invokeArgs')) {
            throw "BLOCK: fallbackChain de $target tem item sem backend, targetModelKey ou invokeArgs completo"
        }
        if ($allowedBackends -notcontains $fbBackend) {
            throw "BLOCK: fallbackChain de $target usa backend invalido: $fbBackend"
        }
        if (Test-HardVetoTarget -TargetModelKey $fbTarget) {
            throw "BLOCK: fallbackChain de $target contem modelo sob veto duro: $fbTarget"
        }
        $key = "$fbBackend|$fbTarget"
        if (-not $seen.Add($key)) {
            throw "BLOCK: ciclo/duplicidade em fallbackChain de $target envolvendo $fbTarget"
        }
        $fbInv = Copy-SanitizedInvokeArgs -InvokeArgs (Get-Prop $fb 'invokeArgs') -Backend $fbBackend -TargetModelKey $fbTarget
        $reason = [string](Get-Prop $fb 'reason')
        $chain.Add([pscustomobject]@{
                backend        = $fbBackend
                targetModelKey = $fbTarget
                invokeArgs     = $fbInv
                reason         = $reason
            })
    }

    return @{
        reviewer = [pscustomobject]@{
            backend        = $backend
            targetModelKey = $target
            rank           = $rank
            invokeArgs     = $invClean
            fallbackChain  = @($chain)
        }
    }
}

foreach ($it in $items) {
    $rankCounter++
    $converted = ConvertTo-ReviewerV2 -Item $it -DefaultRank $rankCounter
    if ($converted.ContainsKey('skipped') -and $converted['skipped']) { $skipped.Add([string]$converted['target']); continue }
    if ($converted.ContainsKey('veto') -and $converted['veto']) { $discardedVeto.Add([string]$converted['target']); continue }
    $kept.Add($converted['reviewer'])
}

$doc = [pscustomobject]@{
    schemaVersion  = 2
    updatedAt      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    migratedFrom   = if ($null -eq $inputSchema) { 1 } else { $inputSchema }
    fallbackPolicy = if ($null -ne $fallbackPolicyIn) { $fallbackPolicyIn } else {
        [pscustomobject]@{
            mode              = 'ordered-chain'
            defaultActivateOn = @('quota', 'timeout', 'error', 'unavailable', 'noResponse')
            gateAskBehavior   = 'ask-human'
            gateDenyBehavior  = 'stop-or-suggest-manual-alternative'
        }
    }
    reviewers      = @($kept)
}
$docJson = $doc | ConvertTo-Json -Depth 12

if (-not $Preview) {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
        $backupPath = "$OutputPath.bak-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
        Copy-Item -LiteralPath $OutputPath -Destination $backupPath -Force
    }
    $tmpPath = "$OutputPath.tmp-$([guid]::NewGuid().ToString('N'))"
    Set-Content -LiteralPath $tmpPath -Value $docJson -Encoding utf8
    Move-Item -LiteralPath $tmpPath -Destination $OutputPath -Force
}

[pscustomobject]@{
    written       = $kept.Count
    discardedVeto = @($discardedVeto)
    skipped       = @($skipped)
    outputPath    = $OutputPath
    preview       = [bool]$Preview
    document      = if ($Preview) { $doc } else { $null }
} | ConvertTo-Json -Depth 6 -Compress
