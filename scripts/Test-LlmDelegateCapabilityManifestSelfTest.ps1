#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test do Build-LlmDelegateCapabilityManifest.ps1 (skill xpz-llm-delegate).
#
# Cobre:
#  (A) Enumeracao + localidade: a partir de um opencode.jsonc fixture com comentarios e
#      trailing commas, com um provider loopback (local) e um provider externo, o manifesto
#      lista os dois modelos com a localidade correta.
#  (B) Sanitizacao por desenho: o manifesto NAO contem segredo-isca (apiKey, host externo,
#      baseURL, caminho de config) plantados no fixture.
#  (C) Schema: schemaVersion/generatedAt/backends presentes; os 5 backends; metadados v11
#      por entrada (provider/family/sourceKind/sourceConfidence/availableInManifest/hardVeto);
#      Copilot/Gemini none-native com models=[]; lastHealthCheck null.
#  (D) Snapshot por-KB: snapshotAt presente e sourceGeneratedAt == generatedAt do manifesto.
#  (E) Codex: nao inventa openai/<slug> quando o resolvedor nao prova provider.
#  (F) Claude Code: stats-cache entra como historico/fraco, nao disponibilidade atual.

$scriptsDir = $PSScriptRoot
$scriptUnderTest = Join-Path $scriptsDir 'Build-LlmDelegateCapabilityManifest.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf) "Script sob teste ausente: $scriptUnderTest"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-cap-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

# Segredos-isca: devem NUNCA aparecer no manifesto.
$secretApiKey = 'sk-TOPSECRET-TOKEN-isca-123'
$externalHost = 'secret-host.internal.example'

try {
    $openCfg = Join-Path $tempRoot 'opencode.jsonc'
    @"
{
  // comentario JSONC: deve ser aceito
  "provider": {
    "ollama": {
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen2.5-coder:7b": {}, }
    },
    "myexternal": {
      "options": { "baseURL": "https://$externalHost/v1", "apiKey": "$secretApiKey" },
      "models": { "big-model": {}, "mistral-large-3": {} }
    },
  },
}
"@ | Set-Content -LiteralPath $openCfg -Encoding utf8

    # config.toml real do Codex: model de topo (openai builtin -> external) + um profile
    # OSS local (loopback -> local). Exercita a enumeracao Codex (regressao do bug de escopo).
    $codexCfg = Join-Path $tempRoot 'config.toml'
    @"
model = "gpt-5.5"

[profiles.local-oss]
model = "qwen2.5-coder:7b"
model_provider = "ollama"

[profiles.providerless]
model = "mystery-model"

[model_providers.ollama]
base_url = "http://localhost:11434/v1"
"@ | Set-Content -LiteralPath $codexCfg -Encoding utf8
    $claudeSettings = Join-Path $tempRoot 'claude-settings.json'
    @'
{
  "model": "claude-opus-4-8"
}
'@ | Set-Content -LiteralPath $claudeSettings -Encoding utf8
    $claudeStats = Join-Path $tempRoot 'stats-cache.json'
    @'
{
  "lastModel": "claude-opus-4-7"
}
'@ | Set-Content -LiteralPath $claudeStats -Encoding utf8

    $fakeAgy = Join-Path $tempRoot 'fake-agy.bat'
    @'
@echo off
if "%1"=="models" (
    echo gemini-3.6-flash-high
    echo claude-sonnet-4-6
    exit /b 0
)
exit /b 1
'@ | Set-Content -LiteralPath $fakeAgy -Encoding ascii

    $outPath = Join-Path $tempRoot 'capabilities.json'
    $snapPath = Join-Path $tempRoot 'snap.json'

    & $scriptUnderTest -OutputPath $outPath -SnapshotPath $snapPath `
        -OpenCodeConfigPath $openCfg -CodexConfigPath $codexCfg `
        -ClaudeSettingsPath $claudeSettings -ClaudeStatsCachePath $claudeStats `
        -AntigravityExe $fakeAgy 1> $null

    Assert-True (Test-Path -LiteralPath $outPath -PathType Leaf) 'Manifesto nao foi gravado.'
    $manifestText = [System.IO.File]::ReadAllText($outPath)
    $manifest = $manifestText | ConvertFrom-Json

    # (C) Schema
    Assert-True ($manifest.schemaVersion -eq 1) 'schemaVersion deveria ser 1.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.generatedAt)) 'generatedAt ausente.'
    Assert-True ($null -eq $manifest.lastHealthCheck) 'lastHealthCheck deveria ser null (saude e volatil).'
    $backendNames = @($manifest.backends | ForEach-Object { $_.backend })
    foreach ($expected in @('opencode', 'codex', 'claude-code', 'copilot', 'gemini', 'antigravity')) {
        Assert-True ($backendNames -contains $expected) "Backend ausente do manifesto: $expected"
    }
    foreach ($b in $manifest.backends) {
        Assert-True ($b.installed -is [bool]) "Campo 'installed' do backend '$($b.backend)' deveria ser booleano."
    }
    foreach ($noneNative in @('copilot', 'gemini')) {
        $b = $manifest.backends | Where-Object { $_.backend -eq $noneNative }
        Assert-True ($b.enumeration -eq 'none-native') "Backend '$noneNative' deveria ter enumeration=none-native."
        Assert-True (@($b.models).Count -eq 0) "Backend '$noneNative' deveria ter models=[] (sem enumeracao nativa)."
    }

    # (A) Enumeracao + localidade do opencode
    $oc = $manifest.backends | Where-Object { $_.backend -eq 'opencode' }
    Assert-True ($oc.enumeration -eq 'config') 'opencode deveria ter enumeration=config.'
    $local = $oc.models | Where-Object { $_.canonicalModel -eq 'ollama/qwen2.5-coder:7b' }
    Assert-True ($null -ne $local) 'Modelo loopback nao enumerado.'
    Assert-True ($local.locality -eq 'local') "Modelo loopback deveria ser local; veio '$($local.locality)'."
    Assert-True ($local.reasonCode -eq 'loopback-local') "reasonCode do loopback deveria ser loopback-local; veio '$($local.reasonCode)'."
    Assert-True ($local.backend -eq 'opencode') 'Entrada deveria declarar backend=opencode.'
    Assert-True ($local.targetModelKey -eq 'ollama/qwen2.5-coder:7b') 'Entrada deveria declarar targetModelKey.'
    Assert-True ($local.provider -eq 'ollama') 'Entrada deveria declarar provider=ollama.'
    Assert-True ($local.family -eq 'ollama') 'Entrada deveria declarar family=ollama.'
    Assert-True ($local.sourceKind -eq 'configured') 'sourceKind deveria ser configured.'
    Assert-True ($local.sourceConfidence -eq 'strong') 'sourceConfidence deveria ser strong.'
    Assert-True ($local.availableInManifest -eq $true) 'availableInManifest deveria ser true.'
    Assert-True ($local.hardVeto -eq $false) 'Modelo local nao deveria ter hardVeto.'
    $ext = $oc.models | Where-Object { $_.canonicalModel -eq 'myexternal/big-model' }
    Assert-True ($null -ne $ext) 'Modelo externo nao enumerado.'
    Assert-True ($ext.locality -eq 'external') "Modelo externo deveria ser external; veio '$($ext.locality)'."
    $veto = $oc.models | Where-Object { $_.canonicalModel -eq 'myexternal/mistral-large-3' }
    Assert-True ($null -ne $veto) 'Modelo de veto deveria aparecer marcado para diagnostico.'
    Assert-True ($veto.hardVeto -eq $true) 'Mistral Large 3 deveria estar marcado como hardVeto.'

    # (A2) Enumeracao + localidade do Codex (regressao do bug de escopo em Add-FromResolver:
    # `$entries += ...` numa funcao aninhada nao atualizava o array do pai -> codex sempre vazio).
    $cx = $manifest.backends | Where-Object { $_.backend -eq 'codex' }
    Assert-True ($cx.enumeration -eq 'config') 'codex deveria ter enumeration=config.'
    Assert-True (@($cx.models).Count -ge 1) 'codex deveria enumerar ao menos 1 modelo a partir do config.toml (regressao do bug de escopo).'
    $cxTop = $cx.models | Where-Object { $_.canonicalModel -eq 'openai/gpt-5.5' }
    Assert-True ($null -ne $cxTop) 'codex deveria enumerar o modelo de topo openai/gpt-5.5.'
    Assert-True ($cxTop.locality -eq 'external') "modelo de topo do codex deveria ser external; veio '$($cxTop.locality)'."
    $providerless = $cx.models | Where-Object { $_.canonicalModel -eq 'mystery-model' }
    Assert-True ($null -ne $providerless) 'codex deveria preservar modelo providerless como diagnostico fraco.'
    Assert-True ($providerless.provider -eq 'unknown') 'codex providerless deveria ficar provider=unknown.'
    Assert-True ($providerless.sourceConfidence -eq 'weak') 'codex providerless deveria ser fonte fraca.'
    Assert-True (-not (@($cx.models | Where-Object { $_.canonicalModel -eq 'openai/mystery-model' }).Count -gt 0)) 'codex nao deve inventar openai/mystery-model quando provider nao foi provado.'

    # (F) Claude Code: settings forte e stats historico/fraco.
    $cc = $manifest.backends | Where-Object { $_.backend -eq 'claude-code' }
    Assert-True ($cc.enumeration -eq 'settings-or-historical') 'claude-code deveria declarar enumeration=settings-or-historical.'
    $ccConfigured = $cc.models | Where-Object { $_.canonicalModel -eq 'anthropic/claude-opus-4-8' }
    Assert-True ($null -ne $ccConfigured) 'Claude settings deveria enumerar claude-opus-4-8.'
    Assert-True ($ccConfigured.sourceKind -eq 'configured') 'Claude settings deveria ser sourceKind=configured.'
    Assert-True ($ccConfigured.availableInManifest -eq $true) 'Claude settings deveria ser availableInManifest=true.'
    $ccHistorical = $cc.models | Where-Object { $_.canonicalModel -eq 'anthropic/claude-opus-4-7' }
    Assert-True ($null -ne $ccHistorical) 'Claude stats-cache deveria enumerar claude-opus-4-7 como historico.'
    Assert-True ($ccHistorical.sourceKind -eq 'historical') 'Claude stats-cache deveria ser sourceKind=historical.'
    Assert-True ($ccHistorical.sourceConfidence -eq 'weak') 'Claude stats-cache deveria ser fonte fraca.'
    Assert-True ($ccHistorical.availableInManifest -eq $false) 'Claude stats-cache nao deve provar disponibilidade atual.'

    # (G) Antigravity: enumeracao via CLI agy models (fake-exe).
    $agy = $manifest.backends | Where-Object { $_.backend -eq 'antigravity' }
    Assert-True ($agy.enumeration -eq 'cli') 'antigravity deveria ter enumeration=cli.'
    $agyModel = $agy.models | Where-Object { $_.canonicalModel -eq 'antigravity/gemini-3.6-flash-high' }
    Assert-True ($null -ne $agyModel) 'antigravity deveria enumerar gemini-3.6-flash-high.'
    Assert-True ($agyModel.sourceKind -eq 'cli') 'antigravity deveria ser sourceKind=cli.'
    Assert-True ($agyModel.sourceConfidence -eq 'strong') 'antigravity deveria ser sourceConfidence=strong.'

    # (B) Sanitizacao por desenho
    foreach ($forbidden in @($secretApiKey, $externalHost, 'apiKey', 'baseURL', 'Authorization', '11434', $openCfg, $codexCfg, $claudeSettings, $claudeStats)) {
        Assert-True (-not ($manifestText -like "*$forbidden*")) "Manifesto vazou conteudo sensivel proibido: '$forbidden'."
    }

    # (D) Snapshot por-KB
    Assert-True (Test-Path -LiteralPath $snapPath -PathType Leaf) 'Snapshot por-KB nao foi gravado.'
    $snap = [System.IO.File]::ReadAllText($snapPath) | ConvertFrom-Json
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$snap.snapshotAt)) 'snapshotAt ausente no snapshot.'
    Assert-True ($snap.sourceGeneratedAt -eq $manifest.generatedAt) 'sourceGeneratedAt do snapshot deveria casar com generatedAt do manifesto.'

    Write-Output 'OK: Test-LlmDelegateCapabilityManifestSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
