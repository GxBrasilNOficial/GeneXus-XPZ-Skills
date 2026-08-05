#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de contrato de Resolve-LlmDelegateAuthorization.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Valida a tabela de decisão allow/ask/deny combinando sensibilidade do payload,
    localidade do modelo e politica por-KB, com config e politica sinteticas (sem opencode
    instalado nem rede). Determinístico.
    Sentinela de sucesso: OK: Test-LlmDelegateAuthorizationSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegateAuthorization.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $target" }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ocauth-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$cfg = Join-Path $tmp 'opencode.json'
@'
{
  "provider": {
    "ollama":   { "options": { "baseURL": "http://127.0.0.1:11434/v1" } },
    "remote-x": { "options": { "baseURL": "https://api.example.com/v1" } }
  }
}
'@ | Set-Content -LiteralPath $cfg -Encoding utf8
$pol = Join-Path $tmp 'opencode-delegation-policy.json'
@'
{
  "schemaVersion": 1,
  "defaultExternal": "ask",
  "models": {
            "openai/gpt-5.4": "allow-external",
            "openai/*": "allow-external",
            "anthropic/claude-opus-4-8": "allow-external",
            "anthropic/claude-deny-test": "deny-external",
            "github-copilot/*": "allow-external",
            "google/gemini-deny-test": "deny-external",
            "google/*": "allow-external",
            "antigravity/gemini-deny-test": "deny-external",
            "antigravity/*": "allow-external",
            "remote-x/*": "deny-external"
  }
}
'@ | Set-Content -LiteralPath $pol -Encoding utf8

# Config.toml sintetica para os casos do backend codex (default cai em openai/external).
$cfgToml = Join-Path $tmp 'config.toml'
@'
model = "gpt-5.5"
'@ | Set-Content -LiteralPath $cfgToml -Encoding utf8

$fail = 0
function Assert-Verdict {
    param([string]$Model, [string]$Sensitivity, [string]$Expected, [switch]$WithPolicy, [string]$Note, [string]$Backend = 'opencode')
    $cfgForBackend = if ($Backend -eq 'codex') { $cfgToml } else { $cfg }
    $callArgs = @{ Model = $Model; PayloadSensitivity = $Sensitivity; ConfigPath = $cfgForBackend; Backend = $Backend }
    if ($WithPolicy) { $callArgs['PolicyPath'] = $pol }
    $out = & $target @callArgs | ConvertFrom-Json
    $got = [string]$out.verdict
    $tagPol = if ($WithPolicy) { ' +pol' } else { '' }
    $tagBk = if ($Backend -ne 'opencode') { " $Backend" } else { '' }
    $label = "{0} [{1}]{2}{3}" -f $Model, $Sensitivity, $tagPol, $tagBk
    if ($got -eq $Expected) {
        Write-Host ("PASS  {0,-40} -> {1}  ({2})" -f $label, $got, $Note) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0,-40} -> {1} (esperado {2})  ({3})" -f $label, $got, $Expected, $Note) -ForegroundColor Red
    }
}

function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Label) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0} -> '{1}' (esperado '{2}')" -f $Label, $Got, $Expected) -ForegroundColor Red
    }
}

try {
    Assert-Verdict -Model 'remote-x/foo'   -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'payload publico'
    Assert-Verdict -Model 'ollama/foo'     -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'local: dado nao sai'
    Assert-Verdict -Model 'openai/gpt-5.4' -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'politica allow-external exato'
    Assert-Verdict -Model 'remote-x/zzz'   -Sensitivity 'kb-sensitive' -Expected 'deny'  -WithPolicy -Note 'curinga remote-x/* deny'
    Assert-Verdict -Model 'opencode-go/x'  -Sensitivity 'kb-sensitive' -Expected 'ask'   -WithPolicy -Note 'nao listado -> defaultExternal ask'
    Assert-Verdict -Model 'remote-x/foo'   -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'externo sem arquivo de politica -> ask'

    # Backend codex: a chave de DESTINO (openai/...) casa a MESMA regra de politica que o
    # opencode usaria; o adapter nao entra na chave. Esta e a prova do design 'openai/' != 'codex/'.
    Assert-Verdict -Model 'gpt-5.5' -Backend codex -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'codex publico -> allow'
    Assert-Verdict -Model 'gpt-5.4' -Backend codex -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'codex casa openai/gpt-5.4 exata (mesma regra do opencode)'
    Assert-Verdict -Model 'gpt-5.5' -Backend codex -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'codex casa curinga openai/* (unificacao por destino)'
    Assert-Verdict -Model 'gpt-5.5' -Backend codex -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'codex externo sem politica -> ask'
    Assert-Verdict -Model ''        -Backend codex -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'codex sem -Model deriva model da config e casa openai/*'

    # Backend claude-code: chave de DESTINO Anthropic, nunca claude-code/*.
    Assert-Verdict -Model 'claude-opus-4-8' -Backend claude-code -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'Claude Code publico -> allow'
    Assert-Verdict -Model 'claude-opus-4-8' -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'Claude Code casa anthropic/claude-opus-4-8 exata'
    Assert-Verdict -Model 'opus'             -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'alias opus normalizado para Opus 4.8'
    Assert-Verdict -Model 'claude-deny-test' -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'deny'  -WithPolicy -Note 'Claude Code respeita deny-external exato'
    Assert-Verdict -Model 'claude-opus-4-8' -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'Claude Code externo sem politica -> ask'
    Assert-Verdict -Model ''                 -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'Claude Code sem -Model: unknown -> ask (fail-safe, nao erro de binding)'
    Assert-Verdict -Model ''                 -Backend claude-code -Sensitivity 'public'       -Expected 'allow' -Note 'Claude Code sem -Model: payload publico -> allow'
    Assert-Verdict -Model ''                 -Backend claude-code -Sensitivity 'kb-sensitive' -Expected 'ask'   -WithPolicy -Note 'Claude Code sem -Model + politica presente: ask sem excecao (regressao do crash name-vazio no lookup de politica)'

    # Backends copilot/gemini: tambem casam por chave de DESTINO, nao por adapter generico.
    Assert-Verdict -Model 'gpt-5-mini' -Backend copilot -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'Copilot publico -> allow'
    Assert-Verdict -Model 'gpt-5-mini' -Backend copilot -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'Copilot casa github-copilot/*'
    Assert-Verdict -Model 'gpt-5-mini' -Backend copilot -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'Copilot externo sem politica -> ask'
    Assert-Verdict -Model 'gemini-3-flash-preview' -Backend gemini -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'Gemini publico -> allow'
    Assert-Verdict -Model 'gemini-deny-test'        -Backend gemini -Sensitivity 'kb-sensitive' -Expected 'deny'  -WithPolicy -Note 'Gemini respeita deny-external exato'
    Assert-Verdict -Model 'gemini-3-flash-preview' -Backend gemini -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'Gemini externo sem politica -> ask'
    Assert-Verdict -Model 'gemini-3.6-flash-high' -Backend antigravity -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'Antigravity publico -> allow'
    Assert-Verdict -Model 'gemini-deny-test'        -Backend antigravity -Sensitivity 'kb-sensitive' -Expected 'deny'  -WithPolicy -Note 'Antigravity respeita deny-external exato'
    Assert-Verdict -Model 'gemini-3.6-flash-high' -Backend antigravity -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'Antigravity casa antigravity/*'
    Assert-Verdict -Model 'gemini-3.6-flash-high' -Backend antigravity -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'Antigravity externo sem politica -> ask'

    # B2: descoberta do arquivo de politica por -ParallelKbRoot, com fallback de nome.
    # $tmp ja contem o nome legado (opencode-delegation-policy.json).
    $oLegacy = & $target -Model 'openai/gpt-5.4' -PayloadSensitivity 'kb-sensitive' -ConfigPath $cfg -ParallelKbRoot $tmp | ConvertFrom-Json
    Assert-Equal 'ParallelKbRoot acha legado -> allow' $oLegacy.verdict 'allow'
    Assert-Equal 'ParallelKbRoot legado -> status legacy' $oLegacy.policyNameStatus 'legacy'

    $kbNew = Join-Path $tmp 'kb-new'
    New-Item -ItemType Directory -Path $kbNew -Force | Out-Null
    Copy-Item -LiteralPath $pol -Destination (Join-Path $kbNew 'llm-delegation-policy.json')
    $oNew = & $target -Model 'openai/gpt-5.4' -PayloadSensitivity 'kb-sensitive' -ConfigPath $cfg -ParallelKbRoot $kbNew | ConvertFrom-Json
    Assert-Equal 'ParallelKbRoot acha nome novo -> allow' $oNew.verdict 'allow'
    Assert-Equal 'ParallelKbRoot novo -> status new' $oNew.policyNameStatus 'new'

    $kbNone = Join-Path $tmp 'kb-none'
    New-Item -ItemType Directory -Path $kbNone -Force | Out-Null
    $oNone = & $target -Model 'openai/gpt-5.4' -PayloadSensitivity 'kb-sensitive' -ConfigPath $cfg -ParallelKbRoot $kbNone | ConvertFrom-Json
    Assert-Equal 'ParallelKbRoot sem politica -> ask' $oNone.verdict 'ask'
    Assert-Equal 'ParallelKbRoot sem politica -> status none' $oNone.policyNameStatus 'none'

    # -PolicyPath explicito prevalece sobre -ParallelKbRoot (retrocompat).
    $oPrec = & $target -Model 'openai/gpt-5.4' -PayloadSensitivity 'kb-sensitive' -ConfigPath $cfg -PolicyPath $pol -ParallelKbRoot $kbNone | ConvertFrom-Json
    Assert-Equal 'PolicyPath explicito prevalece sobre ParallelKbRoot' $oPrec.verdict 'allow'
} finally {
    Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $tmp -Force -Recurse -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-LlmDelegateAuthorizationSelfTest.ps1" }
Write-Host 'OK: Test-LlmDelegateAuthorizationSelfTest.ps1' -ForegroundColor Cyan
