#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Set-/Resolve-LlmDelegatePreferredReviewers.ps1 (skill xpz-llm-delegate).
# Contrato schema 3 (preferred-reviewers v20): Orchestrator/Scope obrigatorios, invokeArgs
# obrigatorio no titular, hard-veto = exit 3, schema 1/2 = preferred-schema-unsupported.

$scriptsDir = $PSScriptRoot
$setScript = Join-Path $scriptsDir 'Set-LlmDelegatePreferredReviewers.ps1'
$resolveScript = Join-Path $scriptsDir 'Resolve-LlmDelegatePreferredReviewers.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Set {
    param([hashtable]$CallArgs)
    $out = & $setScript @CallArgs 2>$null
    $code = $LASTEXITCODE
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$out)) {
        $json = $out | ConvertFrom-Json
    }
    return [pscustomobject]@{ code = $code; json = $json; raw = $out }
}

function Invoke-Resolve {
    param([hashtable]$CallArgs)
    $out = & $resolveScript @CallArgs 2>$null
    $code = $LASTEXITCODE
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$out)) {
        $json = $out | ConvertFrom-Json
    }
    return [pscustomobject]@{ code = $code; json = $json; raw = $out }
}

function Assert-ReasonExit {
    param($Result, [string]$Reason, [int]$ExitCode, [string]$Label)
    Assert-True ($Result.code -eq $ExitCode) ("{0}: esperado exit {1}; veio {2}." -f $Label, $ExitCode, $Result.code)
    Assert-True ($null -ne $Result.json) ("{0}: stdout deveria ser JSON." -f $Label)
    Assert-True ([string]$Result.json.reason -eq $Reason) ("{0}: reason deveria ser '{1}'; veio '{2}'." -f $Label, $Reason, $Result.json.reason)
}

Assert-True (Test-Path -LiteralPath $setScript -PathType Leaf) "Script ausente: $setScript"
Assert-True (Test-Path -LiteralPath $resolveScript -PathType Leaf) "Script ausente: $resolveScript"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-pref-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$secretToken = 'sk-SECRET-isca-pref-789'
$secretHost = 'pref-secret-host.internal.example'

try {
    $prefPath = Join-Path $tempRoot 'preferred-reviewers.json'
    $capPath = Join-Path $tempRoot 'capabilities.json'

    # --------------------------------------------------------------------------------------
    # (A) Gravacao schema 3 CLI com Orchestrator+Scope+OutputPath; invokeArgs; modelos;
    #     sanitizacao; hard-veto = exit 3 (nao discardedVeto).
    # --------------------------------------------------------------------------------------
    $reviewersJson = @"
{
  "schemaVersion": 3,
  "reviewers": [
    {
      "backend": "opencode",
      "targetModelKey": "ollama-cloud/deepseek-v4-pro",
      "rank": 1,
      "invokeArgs": {},
      "fallbackChain": [
        {
          "backend": "opencode",
          "targetModelKey": "nvidia/deepseek-ai/deepseek-v4-pro",
          "invokeArgs": { "backend": "opencode" },
          "reason": "fallback contratado"
        }
      ]
    },
    {
      "backend": "codex",
      "targetModelKey": "openai/gpt-5.5",
      "invokeArgs": {
        "backend": "codex",
        "baseURL": "https://$secretHost/v1",
        "token": "$secretToken"
      }
    }
  ]
}
"@

    $setA = Invoke-Set @{
        ReviewersJson = $reviewersJson
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $prefPath
    }
    Assert-True ($setA.code -eq 0) "(A) Set deveria exit 0; veio $($setA.code)."
    Assert-True (Test-Path -LiteralPath $prefPath -PathType Leaf) '(A) preferred-reviewers.json nao foi gravado.'
    Assert-True ($setA.json.written -eq 2) "(A) Deveria gravar 2 revisores; gravou $($setA.json.written)."
    Assert-True ($setA.json.schemaVersion -eq 3) '(A) schemaVersion do report deveria ser 3.'

    $prefText = [System.IO.File]::ReadAllText($prefPath)
    $pref = $prefText | ConvertFrom-Json
    Assert-True ($pref.schemaVersion -eq 3) '(A) schemaVersion do documento deveria ser 3.'
    $migA = $pref.PSObject.Properties['migratedFrom']
    Assert-True ($null -eq $migA -or $null -eq $migA.Value) '(A) entrada schema 3 nao deve trazer migratedFrom.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$pref.updatedAt)) '(A) updatedAt ausente.'
    Assert-True ($pref.calibratedBy -eq 'cursor') ("(A) Scope machine deveria gravar calibratedBy; veio '{0}'." -f $pref.calibratedBy)
    $orchA = $pref.PSObject.Properties['orchestrator']
    Assert-True ($null -eq $orchA -or [string]::IsNullOrWhiteSpace([string]$orchA.Value)) '(A) Scope machine nao deve gravar orchestrator.'
    Assert-True ($pref.fallbackPolicy.mode -eq 'ordered-chain') '(A) fallbackPolicy.mode deveria ser ordered-chain.'

    $oc = @($pref.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' })[0]
    Assert-True ($null -ne $oc) '(A) Revisor opencode ausente.'
    Assert-True ($oc.type -eq 'delegation-cli') '(A) type CLI deveria ser delegation-cli.'
    Assert-True ($oc.rank -eq 1) '(A) rank=1 deveria ser preservado.'
    Assert-True ($oc.invokeArgs.backend -eq 'opencode') '(A) invokeArgs.backend opencode ausente.'
    Assert-True ($oc.invokeArgs.model -eq 'ollama-cloud/deepseek-v4-pro') "(A) model opencode deveria ser chave completa; veio '$($oc.invokeArgs.model)'."
    Assert-True (@($oc.fallbackChain).Count -eq 1) '(A) fallbackChain deveria preservar 1 item.'

    $cx = @($pref.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' })[0]
    Assert-True ($null -ne $cx) '(A) Revisor codex ausente.'
    Assert-True ($cx.invokeArgs.backend -eq 'codex') '(A) invokeArgs.backend codex ausente.'
    Assert-True ($cx.invokeArgs.model -eq 'gpt-5.5') "(A) model codex deveria ser nome nu; veio '$($cx.invokeArgs.model)'."

    foreach ($forbidden in @($secretToken, $secretHost, 'baseURL', 'token')) {
        Assert-True (-not ($prefText -like "*$forbidden*")) "(A) preferred-reviewers.json vazou conteudo sensivel: '$forbidden'."
    }

    $vetoJson = '{"reviewers":[{"backend":"opencode","targetModelKey":"ollama-cloud/nemotron-3-ultra","invokeArgs":{}}]}'
    $veto = Invoke-Set @{
        ReviewersJson = $vetoJson
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'veto.json')
    }
    Assert-ReasonExit -Result $veto -Reason 'hard-veto' -ExitCode 3 -Label '(A) hard-veto'

    # --------------------------------------------------------------------------------------
    # (B) Resolve com -Orchestrator -PreferredPath -CapabilitiesPath
    # --------------------------------------------------------------------------------------
    @'
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-17T00:00:00Z",
  "backends": [
    { "backend": "opencode", "installed": true, "enumeration": "config", "models": [
      { "canonicalModel": "nvidia/deepseek-ai/deepseek-v4-pro", "locality": "external", "sourceKind": "configured", "sourceConfidence": "strong" }
    ] },
    { "backend": "codex", "installed": true, "enumeration": "config", "models": [
      { "canonicalModel": "openai/gpt-5.5", "locality": "external", "reasonCode": "external", "sourceKind": "configured", "sourceConfidence": "strong" }
    ] }
  ],
  "lastHealthCheck": null
}
'@ | Set-Content -LiteralPath $capPath -Encoding utf8

    $resB = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredPath    = $prefPath
        CapabilitiesPath = $capPath
    }
    Assert-True ($resB.code -eq 0) "(B) Resolve deveria exit 0; veio $($resB.code)."
    Assert-True ($resB.json.hasPreferences -eq $true) '(B) hasPreferences deveria ser true.'
    Assert-True ($resB.json.schemaVersion -eq 3) '(B) schemaVersion deveria ser 3.'
    Assert-True ($resB.json.preferenceSource -eq 'explicit-path') "(B) preferenceSource deveria ser explicit-path; veio '$($resB.json.preferenceSource)'."
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$resB.json.note)) '(B) note (preferencia != autorizacao) ausente.'

    $rcx = @($resB.json.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' })[0]
    Assert-True ($rcx.availableInManifest -eq $true) '(B) codex deveria estar availableInManifest=true.'
    Assert-True ($rcx.type -eq 'delegation-cli') '(B) type deveria ecoar delegation-cli.'
    Assert-True ($rcx.reasoningEffort -eq 'unset') '(B) reasoningEffort default deveria ser unset.'
    Assert-True ($null -eq $rcx.harnessModelId -or [string]::IsNullOrWhiteSpace([string]$rcx.harnessModelId)) '(B) CLI nao deve ter harnessModelId.'

    $roc = @($resB.json.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' })[0]
    Assert-True ($roc.availableInManifest -eq $false) '(B) opencode primario ausente do manifesto.'
    Assert-True (@($roc.fallbackChain).Count -eq 1) '(B) fallbackChain resolvida ausente.'
    Assert-True ($roc.fallbackChain[0].availableInManifest -eq $true) '(B) fallback nvidia deveria estar no manifesto.'
    Assert-True ($roc.fallbackChain[0].fallbackIndex -eq 0) '(B) fallbackIndex deveria ser 0.'

    # --------------------------------------------------------------------------------------
    # (E) PreferredPath apontando para arquivo ausente
    # --------------------------------------------------------------------------------------
    $resE = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredPath    = (Join-Path $tempRoot 'nao-existe.json')
        CapabilitiesPath = $capPath
    }
    Assert-True ($resE.code -eq 0) '(E) arquivo ausente deveria exit 0.'
    Assert-True ($resE.json.hasPreferences -eq $false) '(E) hasPreferences=false esperado.'
    Assert-True ($resE.json.reason -eq 'no-preferred-file') "(E) reason=no-preferred-file; veio '$($resE.json.reason)'."
    Assert-True ($resE.json.preferenceSource -eq 'explicit-path') '(E) preferenceSource=explicit-path esperado.'

    # --------------------------------------------------------------------------------------
    # (F) schema v1 -> exit 2 preferred-schema-unsupported (NAO resolve como v1)
    # --------------------------------------------------------------------------------------
    $legacyPath = Join-Path $tempRoot 'preferred-v1.json'
    @'
{
  "updatedAt": "2026-06-17T00:00:00Z",
  "reviewers": [
    { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "model": "gpt-5.5" } }
  ]
}
'@ | Set-Content -LiteralPath $legacyPath -Encoding utf8
    $resF = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredPath    = $legacyPath
        CapabilitiesPath = $capPath
    }
    Assert-ReasonExit -Result $resF -Reason 'preferred-schema-unsupported' -ExitCode 2 -Label '(F) schema v1'

    $legacyV2Path = Join-Path $tempRoot 'preferred-v2.json'
    @'
{
  "schemaVersion": 2,
  "reviewers": [
    { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "codex", "model": "gpt-5.5" } }
  ]
}
'@ | Set-Content -LiteralPath $legacyV2Path -Encoding utf8
    $resF2 = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredPath    = $legacyV2Path
        CapabilitiesPath = $capPath
    }
    Assert-ReasonExit -Result $resF2 -Reason 'preferred-schema-unsupported' -ExitCode 2 -Label '(F) schema v2'

    # --------------------------------------------------------------------------------------
    # (G) invokeArgs.backend diverge
    # --------------------------------------------------------------------------------------
    $badPrimary = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "opencode", "model": "gpt-5.5" } }]}'
    $g = Invoke-Set @{
        ReviewersJson = $badPrimary
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'bad-primary.json')
    }
    Assert-ReasonExit -Result $g -Reason 'invoke-args-backend-divergent' -ExitCode 3 -Label '(G) primario'

    $badFallback = @'
{
  "reviewers": [
    {
      "backend": "opencode",
      "targetModelKey": "ollama-cloud/deepseek-v4-pro",
      "invokeArgs": { "backend": "opencode" },
      "fallbackChain": [
        { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "backend": "opencode", "model": "gpt-5.5" } }
      ]
    }
  ]
}
'@
    $g2 = Invoke-Set @{
        ReviewersJson = $badFallback
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'bad-fallback.json')
    }
    Assert-ReasonExit -Result $g2 -Reason 'invoke-args-backend-divergent' -ExitCode 3 -Label '(G) fallback'

    # --------------------------------------------------------------------------------------
    # (H) ciclo em fallbackChain
    # --------------------------------------------------------------------------------------
    $cycleFallback = @'
{
  "reviewers": [
    {
      "backend": "opencode",
      "targetModelKey": "ollama-cloud/deepseek-v4-pro",
      "invokeArgs": {},
      "fallbackChain": [
        { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro", "invokeArgs": {} }
      ]
    }
  ]
}
'@
    $h = Invoke-Set @{
        ReviewersJson = $cycleFallback
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'cycle.json')
    }
    Assert-ReasonExit -Result $h -Reason 'fallback-cycle' -ExitCode 3 -Label '(H) ciclo'

    # --------------------------------------------------------------------------------------
    # (I) ranks, rank implicito, overwrite-required, -Overwrite
    # --------------------------------------------------------------------------------------
    $outOfOrder = @'
[
  { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "rank": 20, "invokeArgs": {} },
  { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro", "rank": 10, "invokeArgs": {} }
]
'@
    $rankPath = Join-Path $tempRoot 'ranked.json'
    $rankSet = Invoke-Set @{
        ReviewersJson = $outOfOrder
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $rankPath
    }
    Assert-True ($rankSet.code -eq 0) "(I) Set ranked deveria exit 0; veio $($rankSet.code)."
    $ranked = Get-Content -LiteralPath $rankPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($ranked.reviewers[0].rank -eq 10) "(I) titular rank 10 deveria sair antes; veio $($ranked.reviewers[0].rank)."
    $rankedResolved = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredPath    = $rankPath
        CapabilitiesPath = $capPath
    }
    Assert-True ($rankedResolved.code -eq 0) '(I) Resolve ranked deveria exit 0.'
    Assert-True ($rankedResolved.json.reviewers[0].rank -eq 10) '(I) Resolve deveria preservar ordenacao por rank.'

    $mixedImplicitRank = @'
[
  { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "rank": 2, "invokeArgs": {} },
  { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro", "invokeArgs": {} }
]
'@
    $mixedRankPath = Join-Path $tempRoot 'mixed-implicit-rank.json'
    $mixedSet = Invoke-Set @{
        ReviewersJson = $mixedImplicitRank
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $mixedRankPath
    }
    Assert-True ($mixedSet.code -eq 0) '(I) Set mixed-rank deveria exit 0.'
    $mixedRanked = Get-Content -LiteralPath $mixedRankPath -Raw -Encoding utf8 | ConvertFrom-Json
    $implicitReviewer = @($mixedRanked.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' })[0]
    Assert-True ($implicitReviewer.rank -eq 3) "(I) rank implicito deveria evitar colisao com 2; veio $($implicitReviewer.rank)."

    $ow = Invoke-Set @{
        ReviewersJson = $outOfOrder
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $rankPath
    }
    Assert-ReasonExit -Result $ow -Reason 'overwrite-required' -ExitCode 1 -Label '(I) sem Overwrite'

    $owOk = Invoke-Set @{
        ReviewersJson = $outOfOrder
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $rankPath
        Overwrite     = $true
    }
    Assert-True ($owOk.code -eq 0) "(I) com -Overwrite deveria exit 0; veio $($owOk.code)."

    $badRank = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "rank": 0, "invokeArgs": {} }]}'
    $br = Invoke-Set @{
        ReviewersJson = $badRank
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'bad-rank.json')
    }
    Assert-ReasonExit -Result $br -Reason 'rank-invalid' -ExitCode 3 -Label '(I) rank 0'

    $dupRank = @'
[
  { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "rank": 1, "invokeArgs": {} },
  { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro", "rank": 1, "invokeArgs": {} }
]
'@
    $dr = Invoke-Set @{
        ReviewersJson = $dupRank
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'dup-rank.json')
    }
    Assert-ReasonExit -Result $dr -Reason 'rank-duplicate' -ExitCode 3 -Label '(I) rank duplicado'

    # --------------------------------------------------------------------------------------
    # (J) parametros obrigatorios exit 1 + JSON
    # --------------------------------------------------------------------------------------
    $j1 = Invoke-Set @{ ReviewersJson = '[]'; Scope = 'machine'; OutputPath = (Join-Path $tempRoot 'j1.json') }
    Assert-ReasonExit -Result $j1 -Reason 'orchestrator-required' -ExitCode 1 -Label '(J) orchestrator-required'

    $j2 = Invoke-Set @{
        ReviewersJson = '[]'
        Orchestrator  = 'nope'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'j2.json')
    }
    Assert-ReasonExit -Result $j2 -Reason 'orchestrator-invalid' -ExitCode 1 -Label '(J) orchestrator-invalid'

    $j3 = Invoke-Set @{ ReviewersJson = '[]'; Orchestrator = 'cursor'; OutputPath = (Join-Path $tempRoot 'j3.json') }
    Assert-ReasonExit -Result $j3 -Reason 'scope-required' -ExitCode 1 -Label '(J) scope-required'

    $j4 = Invoke-Set @{ Orchestrator = 'cursor'; Scope = 'machine'; OutputPath = (Join-Path $tempRoot 'j4.json') }
    Assert-ReasonExit -Result $j4 -Reason 'reviewers-json-required' -ExitCode 1 -Label '(J) reviewers-json-required'

    $jR = Invoke-Resolve @{ PreferredPath = $prefPath; CapabilitiesPath = $capPath }
    Assert-ReasonExit -Result $jR -Reason 'orchestrator-required' -ExitCode 1 -Label '(J) Resolve orchestrator-required'

    # --------------------------------------------------------------------------------------
    # (K) nativo: harnessModelId + invokeArgs {}; fallbackChain proibido; cursor/* proibido
    # --------------------------------------------------------------------------------------
    $nativeOk = @'
{
  "reviewers": [
    {
      "backend": "orchestrator-native",
      "targetModelKey": "moonshot/kimi-k3-max",
      "harnessModelId": "kimi-k3-max",
      "invokeArgs": {}
    }
  ]
}
'@
    $nativePath = Join-Path $tempRoot 'native.json'
    $kOk = Invoke-Set @{
        ReviewersJson = $nativeOk
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $nativePath
    }
    Assert-True ($kOk.code -eq 0) "(K) nativo valido deveria exit 0; veio $($kOk.code)."
    $nativeDoc = Get-Content -LiteralPath $nativePath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($nativeDoc.reviewers[0].type -eq 'orchestrator-native-subagent') '(K) type nativo esperado.'
    Assert-True ($nativeDoc.reviewers[0].harnessModelId -eq 'kimi-k3-max') '(K) harnessModelId deveria ser preservado.'

    $nativeFb = @'
{
  "reviewers": [
    {
      "backend": "orchestrator-native",
      "targetModelKey": "moonshot/kimi-k3-max",
      "harnessModelId": "kimi-k3-max",
      "invokeArgs": {},
      "fallbackChain": [
        { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": {} }
      ]
    }
  ]
}
'@
    $kFb = Invoke-Set @{
        ReviewersJson = $nativeFb
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'native-fb.json')
    }
    Assert-ReasonExit -Result $kFb -Reason 'native-fallback-chain-forbidden' -ExitCode 3 -Label '(K) native fallback'

    $cursorPref = '{"reviewers":[{ "backend": "opencode", "targetModelKey": "cursor/composer", "invokeArgs": {} }]}'
    $kCur = Invoke-Set @{
        ReviewersJson = $cursorPref
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'cursor-pref.json')
    }
    Assert-ReasonExit -Result $kCur -Reason 'native-cursor-prefix' -ExitCode 3 -Label '(K) cursor prefix'

    # (K2) chave de harness Cursor: legitima como titular NATIVO com Criador conhecido,
    # proibida como alvo CLI (indespachavel) nas duas grafias e como elo de fallbackChain.
    $nativeGrok = @'
{
  "reviewers": [
    {
      "backend": "orchestrator-native",
      "targetModelKey": "cursor/grok-4",
      "harnessModelId": "grok-4",
      "invokeArgs": {}
    }
  ]
}
'@
    $grokPath = Join-Path $tempRoot 'native-grok.json'
    $kGrok = Invoke-Set @{
        ReviewersJson = $nativeGrok
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = $grokPath
    }
    Assert-True ($kGrok.code -eq 0) "(K2) nativo cursor/grok-* deveria exit 0; veio $($kGrok.code)."
    $grokDoc = Get-Content -LiteralPath $grokPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($grokDoc.reviewers[0].targetModelKey -eq 'cursor/grok-4') '(K2) targetModelKey nativo deveria ser preservado.'

    $nativeComposer = @'
{
  "reviewers": [
    {
      "backend": "orchestrator-native",
      "targetModelKey": "cursor-composer-2-medium",
      "harnessModelId": "composer-2-medium",
      "invokeArgs": {}
    }
  ]
}
'@
    $kComposer = Invoke-Set @{
        ReviewersJson = $nativeComposer
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'native-composer.json')
    }
    Assert-True ($kComposer.code -eq 0) "(K2) nativo cursor-composer-* deveria exit 0; veio $($kComposer.code)."

    $nativeUnmapped = @'
{
  "reviewers": [
    {
      "backend": "orchestrator-native",
      "targetModelKey": "cursor/modelo-sem-mapeamento",
      "harnessModelId": "modelo-sem-mapeamento",
      "invokeArgs": {}
    }
  ]
}
'@
    $kUnmapped = Invoke-Set @{
        ReviewersJson = $nativeUnmapped
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'native-unmapped.json')
    }
    Assert-ReasonExit -Result $kUnmapped -Reason 'native-cursor-prefix' -ExitCode 3 -Label '(K2) nativo sem Criador conhecido'

    $cliGrokSlug = '{"reviewers":[{ "backend": "opencode", "targetModelKey": "cursor-grok-4.6-medium", "invokeArgs": {} }]}'
    $kCliSlug = Invoke-Set @{
        ReviewersJson = $cliGrokSlug
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'cli-grok-slug.json')
    }
    Assert-ReasonExit -Result $kCliSlug -Reason 'native-cursor-prefix' -ExitCode 3 -Label '(K2) CLI slug sem barra'

    $cliGrokSlash = '{"reviewers":[{ "backend": "codex", "targetModelKey": "cursor/grok-4", "invokeArgs": {} }]}'
    $kCliSlash = Invoke-Set @{
        ReviewersJson = $cliGrokSlash
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'cli-grok-slash.json')
    }
    Assert-ReasonExit -Result $kCliSlash -Reason 'native-cursor-prefix' -ExitCode 3 -Label '(K2) CLI grafia com barra'

    $fbCursor = @'
{
  "reviewers": [
    {
      "backend": "codex",
      "targetModelKey": "openai/gpt-5.5",
      "invokeArgs": {},
      "fallbackChain": [
        { "backend": "opencode", "targetModelKey": "cursor/grok-4", "invokeArgs": {} }
      ]
    }
  ]
}
'@
    $kFbCursor = Invoke-Set @{
        ReviewersJson = $fbCursor
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'fb-cursor.json')
    }
    Assert-ReasonExit -Result $kFbCursor -Reason 'native-cursor-prefix' -ExitCode 3 -Label '(K2) fallback cursor'

    # --------------------------------------------------------------------------------------
    # (L) cascata PreferredRoot vazio -> no-preferred-file preferenceSource=none
    # --------------------------------------------------------------------------------------
    $cascadeRoot = Join-Path $tempRoot 'cascade-empty'
    [System.IO.Directory]::CreateDirectory($cascadeRoot) | Out-Null
    $resL = Invoke-Resolve @{
        Orchestrator     = 'cursor'
        PreferredRoot    = $cascadeRoot
        CapabilitiesPath = $capPath
    }
    Assert-True ($resL.code -eq 0) '(L) cascata vazia deveria exit 0.'
    Assert-True ($resL.json.hasPreferences -eq $false) '(L) hasPreferences=false.'
    Assert-True ($resL.json.reason -eq 'no-preferred-file') '(L) reason=no-preferred-file.'
    Assert-True ($resL.json.preferenceSource -eq 'none') "(L) preferenceSource=none; veio '$($resL.json.preferenceSource)'."

    # --------------------------------------------------------------------------------------
    # (M) envelope Resolve como ReviewersJson -> unknown-property
    # --------------------------------------------------------------------------------------
    $wrapperEnvelope = @{
        hasPreferences = $true
        reason         = $null
        reviewers      = @(
            @{ backend = 'codex'; targetModelKey = 'openai/gpt-5.5'; invokeArgs = @{} }
        )
        note           = 'eco do Resolve'
    } | ConvertTo-Json -Depth 6 -Compress
    $m = Invoke-Set @{
        ReviewersJson = $wrapperEnvelope
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'wrapper-envelope.json')
    }
    Assert-ReasonExit -Result $m -Reason 'unknown-property' -ExitCode 3 -Label '(M) wrapper Resolve'

    # --------------------------------------------------------------------------------------
    # (N) model alias diverge de targetModelKey
    # --------------------------------------------------------------------------------------
    $nJson = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "model": "openai/other", "invokeArgs": {} }]}'
    $n = Invoke-Set @{
        ReviewersJson = $nJson
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'model-divergent.json')
    }
    Assert-ReasonExit -Result $n -Reason 'target-model-key-divergent' -ExitCode 3 -Label '(N) model alias'

    # --------------------------------------------------------------------------------------
    # (O) type inconsistente com backend
    # --------------------------------------------------------------------------------------
    $oJson = '{"reviewers":[{ "type": "orchestrator-native-subagent", "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": {} }]}'
    $o = Invoke-Set @{
        ReviewersJson = $oJson
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'type-divergent.json')
    }
    Assert-ReasonExit -Result $o -Reason 'type-backend-divergent' -ExitCode 3 -Label '(O) type'

    # --------------------------------------------------------------------------------------
    # (P) incompleto sem invokeArgs
    # --------------------------------------------------------------------------------------
    $pJson = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5" }]}'
    $p = Invoke-Set @{
        ReviewersJson = $pJson
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'incomplete.json')
    }
    Assert-ReasonExit -Result $p -Reason 'reviewer-incomplete' -ExitCode 3 -Label '(P) sem invokeArgs'

    # --------------------------------------------------------------------------------------
    # (Q) claude-code / antigravity sem model em invokeArgs -> ultimo segmento
    # --------------------------------------------------------------------------------------
    $qJson = @'
[
  { "backend": "claude-code", "targetModelKey": "anthropic/claude-opus-4-8", "invokeArgs": {} },
  { "backend": "antigravity", "targetModelKey": "google/gemini-3-flash-preview", "invokeArgs": { "backend": "antigravity" } }
]
'@
    $qPath = Join-Path $tempRoot 'last-segment.json'
    $q = Invoke-Set @{
        ReviewersJson = $qJson
        Orchestrator  = 'claude-code'
        Scope         = 'machine'
        OutputPath    = $qPath
    }
    Assert-True ($q.code -eq 0) "(Q) Set claude/antigravity deveria exit 0; veio $($q.code)."
    $qDoc = Get-Content -LiteralPath $qPath -Raw -Encoding utf8 | ConvertFrom-Json
    $qClaude = @($qDoc.reviewers | Where-Object { $_.backend -eq 'claude-code' })[0]
    $qAgy = @($qDoc.reviewers | Where-Object { $_.backend -eq 'antigravity' })[0]
    Assert-True ($qClaude.invokeArgs.model -eq 'claude-opus-4-8') "(Q) claude-code model deveria ser ultimo segmento; veio '$($qClaude.invokeArgs.model)'."
    Assert-True ($qAgy.invokeArgs.model -eq 'gemini-3-flash-preview') "(Q) antigravity model deveria ser ultimo segmento; veio '$($qAgy.invokeArgs.model)'."

    # --------------------------------------------------------------------------------------
    # (R) Scope orchestrator grava orchestrator; Scope machine grava calibratedBy
    # --------------------------------------------------------------------------------------
    $rOrchPath = Join-Path $tempRoot 'scope-orch.json'
    $rOrch = Invoke-Set @{
        ReviewersJson = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": {} }]}'
        Orchestrator  = 'opencode'
        Scope         = 'orchestrator'
        OutputPath    = $rOrchPath
    }
    Assert-True ($rOrch.code -eq 0) '(R) Scope orchestrator deveria exit 0.'
    $rOrchDoc = Get-Content -LiteralPath $rOrchPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($rOrchDoc.orchestrator -eq 'opencode') ("(R) campo orchestrator esperado; veio '{0}'." -f $rOrchDoc.orchestrator)
    $calR = $rOrchDoc.PSObject.Properties['calibratedBy']
    Assert-True ($null -eq $calR -or [string]::IsNullOrWhiteSpace([string]$calR.Value)) '(R) Scope orchestrator nao deve gravar calibratedBy.'

    $rMachPath = Join-Path $tempRoot 'scope-machine.json'
    $rMach = Invoke-Set @{
        ReviewersJson = '{"reviewers":[{ "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": {} }]}'
        Orchestrator  = 'codex'
        Scope         = 'machine'
        OutputPath    = $rMachPath
    }
    Assert-True ($rMach.code -eq 0) '(R) Scope machine deveria exit 0.'
    $rMachDoc = Get-Content -LiteralPath $rMachPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($rMachDoc.calibratedBy -eq 'codex') "(R) calibratedBy esperado; veio '$($rMachDoc.calibratedBy)'."

    # --------------------------------------------------------------------------------------
    # (S) conflito PreferredPath+PreferredRoot / OutputPath+PreferredRoot
    # --------------------------------------------------------------------------------------
    $s1 = Invoke-Set @{
        ReviewersJson = '[]'
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 's1.json')
        PreferredRoot = $tempRoot
    }
    Assert-ReasonExit -Result $s1 -Reason 'preferred-path-mode-conflict' -ExitCode 1 -Label '(S) Set OutputPath+PreferredRoot'

    $s2 = Invoke-Resolve @{
        Orchestrator  = 'cursor'
        PreferredPath = $prefPath
        PreferredRoot = $tempRoot
        CapabilitiesPath = $capPath
    }
    Assert-ReasonExit -Result $s2 -Reason 'preferred-path-mode-conflict' -ExitCode 1 -Label '(S) Resolve PreferredPath+PreferredRoot'

    # --------------------------------------------------------------------------------------
    # (T) Preview: schema 3 -> migratedFrom omitido/null; schema 2 -> migratedFrom 2
    # --------------------------------------------------------------------------------------
    $t3 = Invoke-Set @{
        ReviewersJson = '{"schemaVersion":3,"reviewers":[{"backend":"codex","targetModelKey":"openai/gpt-5.5","invokeArgs":{}}]}'
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        Preview       = $true
    }
    Assert-True ($t3.code -eq 0) '(T) Preview schema3 deveria exit 0.'
    Assert-True ($t3.json.preview -eq $true) '(T) preview=true esperado.'
    $mig3Prop = $t3.json.document.PSObject.Properties['migratedFrom']
    $mig3 = if ($null -ne $mig3Prop) { $mig3Prop.Value } else { $null }
    Assert-True ($null -eq $mig3 -or [string]::IsNullOrWhiteSpace([string]$mig3)) ("(T) schema3 Preview nao deve migrar; migratedFrom='{0}'." -f $mig3)

    $t2 = Invoke-Set @{
        ReviewersJson = '{"schemaVersion":2,"reviewers":[{"backend":"codex","targetModelKey":"openai/gpt-5.5","invokeArgs":{}}]}'
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        Preview       = $true
    }
    Assert-True ($t2.code -eq 0) '(T) Preview schema2 deveria exit 0.'
    $mig2Prop = $t2.json.document.PSObject.Properties['migratedFrom']
    Assert-True ($null -ne $mig2Prop) '(T) schema2 Preview deveria expor migratedFrom.'
    Assert-True ([int]$mig2Prop.Value -eq 2) ("(T) schema2 Preview deveria ter migratedFrom=2; veio '{0}'." -f $mig2Prop.Value)

    # --------------------------------------------------------------------------------------
    # (U) escrita atomica: limpeza do temporario permanece no texto do Set-
    # --------------------------------------------------------------------------------------
    $setScriptText = Get-Content -LiteralPath $setScript -Raw -Encoding utf8
    Assert-True ($setScriptText -match 'Remove-Item -LiteralPath \$tmpPath') '(U) Escrita atomica deveria limpar o arquivo temporario se Move-Item falhar.'

    # politica invalida ainda bloqueia
    $badPolicy = @'
{
  "fallbackPolicy": { "mode": "custom", "defaultActivateOn": ["error"], "gateAskBehavior": "skip", "gateDenyBehavior": "skip" },
  "reviewers": [
    { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": {} }
  ]
}
'@
    $bp = Invoke-Set @{
        ReviewersJson = $badPolicy
        Orchestrator  = 'cursor'
        Scope         = 'machine'
        OutputPath    = (Join-Path $tempRoot 'bad-policy.json')
    }
    Assert-ReasonExit -Result $bp -Reason 'fallback-policy-invalid' -ExitCode 3 -Label 'fallbackPolicy invalida'

    Write-Output 'OK: Test-LlmDelegatePreferredReviewersSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
