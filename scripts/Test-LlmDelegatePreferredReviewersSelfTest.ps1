#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Set-/Resolve-LlmDelegatePreferredReviewers.ps1 (skill xpz-llm-delegate).
#
# Cobre:
#  (A) Gravacao v2 + schema de 2 eixos: targetModelKey + invokeArgs.backend/model
#      (model derivado quando ausente), rank e fallbackChain.
#  (B) Sanitizacao por desenho: segredo-isca no invokeArgs (baseURL/token) NAO vaza.
#  (C) Veto duro: Nemotron 3 Ultra escolhido pelo usuario e DESCARTADO.
#  (D) Resolve cruza com capabilities.json (availableInManifest), com a invariante de que
#      preferencia != autorizacao (campo note presente; nada de veredito de gate).
#  (E) Sem arquivo de preferencia -> hasPreferences=false (fallback).
#  (F) Schema v1 sem schemaVersion continua resolvido como v1.
#  (G) Divergencia invokeArgs.backend no primario e em item N>0 de fallbackChain bloqueia
#      antes de qualquer dispatcher.
#  (H) Ciclo/duplicidade em fallbackChain bloqueia.

$scriptsDir = $PSScriptRoot
$setScript = Join-Path $scriptsDir 'Set-LlmDelegatePreferredReviewers.ps1'
$resolveScript = Join-Path $scriptsDir 'Resolve-LlmDelegatePreferredReviewers.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $setScript -PathType Leaf) "Script ausente: $setScript"
Assert-True (Test-Path -LiteralPath $resolveScript -PathType Leaf) "Script ausente: $resolveScript"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-pref-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$secretToken = 'sk-SECRET-isca-pref-789'
$secretHost = 'pref-secret-host.internal.example'

try {
    $prefPath = Join-Path $tempRoot 'preferred-reviewers.json'

    # Entrada: opencode (sem invokeArgs -> model derivado), codex (com segredo-isca a sanitizar),
    # e um veto duro (Nemotron 3 Ultra) que o usuario "escolheu" e deve ser descartado.
    $reviewersJson = @"
[
  {
    "backend": "opencode",
    "targetModelKey": "ollama-cloud/deepseek-v4-pro",
    "rank": 1,
    "fallbackChain": [
      {
        "backend": "opencode",
        "targetModelKey": "nvidia/deepseek-ai/deepseek-v4-pro",
        "invokeArgs": { "backend": "opencode", "model": "nvidia/deepseek-ai/deepseek-v4-pro" },
        "reason": "fallback contratado"
      }
    ]
  },
  { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "codex", "model": "gpt-5.5", "baseURL": "https://$secretHost/v1", "token": "$secretToken" } },
  { "backend": "opencode", "targetModelKey": "ollama-cloud/nemotron-3-ultra" }
]
"@

    $setOut = & $setScript -ReviewersJson $reviewersJson -OutputPath $prefPath | ConvertFrom-Json

    # (A) gravacao
    Assert-True (Test-Path -LiteralPath $prefPath -PathType Leaf) 'preferred-reviewers.json nao foi gravado.'
    Assert-True ($setOut.written -eq 2) "Deveria gravar 2 revisores (veto descartado); gravou $($setOut.written)."
    Assert-True (@($setOut.discardedVeto) -contains 'ollama-cloud/nemotron-3-ultra') 'Nemotron 3 Ultra deveria ter sido descartado por veto duro.'

    $prefText = [System.IO.File]::ReadAllText($prefPath)
    $pref = $prefText | ConvertFrom-Json
    Assert-True ($pref.schemaVersion -eq 2) 'schemaVersion deveria ser 2.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$pref.updatedAt)) 'updatedAt ausente.'
    Assert-True ($pref.fallbackPolicy.mode -eq 'ordered-chain') 'fallbackPolicy.mode deveria ser ordered-chain.'

    $oc = $pref.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' }
    Assert-True ($null -ne $oc) 'Revisor opencode ausente.'
    Assert-True ($oc.rank -eq 1) 'Revisor opencode deveria preservar rank=1.'
    Assert-True ($oc.invokeArgs.backend -eq 'opencode') 'invokeArgs.backend deveria ser gravado no primario.'
    Assert-True ($oc.invokeArgs.model -eq 'ollama-cloud/deepseek-v4-pro') "model do opencode deveria ser derivado da chave de destino; veio '$($oc.invokeArgs.model)'."
    Assert-True (@($oc.fallbackChain).Count -eq 1) 'fallbackChain deveria preservar 1 item.'
    Assert-True ($oc.fallbackChain[0].invokeArgs.backend -eq 'opencode') 'fallback deveria preservar invokeArgs.backend.'
    $cx = $pref.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' }
    Assert-True ($null -ne $cx) 'Revisor codex ausente.'
    Assert-True ($cx.invokeArgs.backend -eq 'codex') 'invokeArgs.backend deveria ser gravado no codex.'
    Assert-True ($cx.invokeArgs.model -eq 'gpt-5.5') "model do codex deveria ser o nome nu 'gpt-5.5'; veio '$($cx.invokeArgs.model)'."

    # (B) sanitizacao: segredo-isca nao vaza
    foreach ($forbidden in @($secretToken, $secretHost, 'baseURL', 'token')) {
        Assert-True (-not ($prefText -like "*$forbidden*")) "preferred-reviewers.json vazou conteudo sensivel: '$forbidden'."
    }

    # (D) Resolve com manifesto fixture: codex disponivel; opencode (deepseek) ausente do manifesto.
    $capPath = Join-Path $tempRoot 'capabilities.json'
    @'
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-17T00:00:00Z",
  "backends": [
    { "backend": "opencode", "installed": true, "enumeration": "config", "models": [
      { "canonicalModel": "nvidia/deepseek-ai/deepseek-v4-pro", "locality": "external", "sourceKind": "configured", "sourceConfidence": "strong" }
    ] },
    { "backend": "codex", "installed": true, "enumeration": "config", "models": [ { "canonicalModel": "openai/gpt-5.5", "locality": "external", "reasonCode": "external", "sourceKind": "configured", "sourceConfidence": "strong" } ] }
  ],
  "lastHealthCheck": null
}
'@ | Set-Content -LiteralPath $capPath -Encoding utf8

    $res = & $resolveScript -PreferredPath $prefPath -CapabilitiesPath $capPath | ConvertFrom-Json
    Assert-True ($res.hasPreferences -eq $true) 'Resolve deveria reportar hasPreferences=true.'
    Assert-True ($res.schemaVersion -eq 2) 'Resolve deveria reportar schemaVersion=2.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$res.note)) 'note (invariante preferencia != autorizacao) ausente.'
    $rcx = $res.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' }
    Assert-True ($rcx.availableInManifest -eq $true) 'codex (openai/gpt-5.5) deveria estar availableInManifest=true.'
    $roc = $res.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' }
    Assert-True ($roc.availableInManifest -eq $false) 'opencode (deepseek) deveria estar availableInManifest=false (manifesto nao enumera opencode aqui).'
    Assert-True (@($roc.fallbackChain).Count -eq 1) 'Resolve deveria preservar fallbackChain resolvida.'
    Assert-True ($roc.fallbackChain[0].availableInManifest -eq $true) 'fallback nvidia deveria estar availableInManifest=true.'
    Assert-True ($roc.fallbackChain[0].fallbackIndex -eq 0) 'fallbackIndex deveria ser 0.'

    # (E) sem arquivo de preferencia -> fallback
    $res2 = & $resolveScript -PreferredPath (Join-Path $tempRoot 'nao-existe.json') -CapabilitiesPath $capPath | ConvertFrom-Json
    Assert-True ($res2.hasPreferences -eq $false) 'Sem arquivo, hasPreferences deveria ser false.'
    Assert-True ($res2.reason -eq 'no-preferred-file') "reason deveria ser 'no-preferred-file'; veio '$($res2.reason)'."

    # (F) schema v1 legado sem schemaVersion.
    $legacyPath = Join-Path $tempRoot 'preferred-v1.json'
    @'
{
  "updatedAt": "2026-06-17T00:00:00Z",
  "reviewers": [
    { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "model": "gpt-5.5" } }
  ]
}
'@ | Set-Content -LiteralPath $legacyPath -Encoding utf8
    $legacy = & $resolveScript -PreferredPath $legacyPath -CapabilitiesPath $capPath | ConvertFrom-Json
    Assert-True ($legacy.schemaVersion -eq 1) 'Ausencia de schemaVersion deveria ser tratada como v1.'
    Assert-True ($legacy.reviewers[0].targetModelKey -eq 'openai/gpt-5.5') 'Schema v1 deveria continuar resolvendo revisor.'

    # (G) divergencia primario.
    $badPrimary = '[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "opencode", "model": "gpt-5.5" } }]'
    $blocked = $false
    try { & $setScript -ReviewersJson $badPrimary -OutputPath (Join-Path $tempRoot 'bad-primary.json') | Out-Null } catch { $blocked = ([string]$_.Exception.Message -like '*invokeArgs.backend*') }
    Assert-True $blocked 'Divergencia invokeArgs.backend no primario deveria bloquear no Set.'

    # (G2) divergencia em item N>0 do fallbackChain.
    $badFallback = @'
[
  {
    "backend": "opencode",
    "targetModelKey": "ollama-cloud/deepseek-v4-pro",
    "invokeArgs": { "backend": "opencode", "model": "ollama-cloud/deepseek-v4-pro" },
    "fallbackChain": [
      { "backend": "opencode", "targetModelKey": "nvidia/a", "invokeArgs": { "backend": "opencode", "model": "nvidia/a" } },
      { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "opencode", "model": "gpt-5.5" } }
    ]
  }
]
'@
    $blocked = $false
    try { & $setScript -ReviewersJson $badFallback -OutputPath (Join-Path $tempRoot 'bad-fallback.json') | Out-Null } catch { $blocked = ([string]$_.Exception.Message -like '*invokeArgs.backend*') }
    Assert-True $blocked 'Divergencia invokeArgs.backend em fallback N>0 deveria bloquear no Set.'

    # (H) ciclo/duplicidade.
    $cycleFallback = @'
[
  {
    "backend": "opencode",
    "targetModelKey": "ollama-cloud/deepseek-v4-pro",
    "invokeArgs": { "backend": "opencode", "model": "ollama-cloud/deepseek-v4-pro" },
    "fallbackChain": [
      { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro", "invokeArgs": { "backend": "opencode", "model": "ollama-cloud/deepseek-v4-pro" } }
    ]
  }
]
'@
    $blocked = $false
    try { & $setScript -ReviewersJson $cycleFallback -OutputPath (Join-Path $tempRoot 'cycle.json') | Out-Null } catch { $blocked = ([string]$_.Exception.Message -like '*ciclo/duplicidade*') }
    Assert-True $blocked 'Ciclo/duplicidade em fallbackChain deveria bloquear.'

    Write-Output 'OK: Test-LlmDelegatePreferredReviewersSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
