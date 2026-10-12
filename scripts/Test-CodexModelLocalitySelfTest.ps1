#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de contrato de Resolve-CodexModelLocality.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Cria um config.toml de Codex sintetico e valida a classificacao local/external/unknown
    e a chave de destino (canonicalModel) para varias invocacoes, sem depender do Codex
    instalado nem de rede. Determinístico.
    Sentinela de sucesso: OK: Test-CodexModelLocalitySelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-CodexModelLocality.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $target" }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cxloc-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$cfg = Join-Path $tmp 'config.toml'
@'
model = "gpt-5.5"

[model_providers.localx]
name = "Local X"
base_url = "http://127.0.0.1:11434/v1"

[model_providers.remotex]
name = "Remote X"
base_url = "https://api.example.com/v1"

[profiles.plocal]
model = "qwen2.5-coder:7b"
model_provider = "localx"

[profiles.premote]
model = "some-model"
model_provider = "remotex"
'@ | Set-Content -LiteralPath $cfg -Encoding utf8

$fail = 0
function Assert-Codex {
    param(
        [string]$Label, [string]$Expected, [string]$ExpectedKey,
        [hashtable]$CallArgs
    )
    $CallArgs['ConfigPath'] = $cfg
    $out = & $target @CallArgs | ConvertFrom-Json
    $got = [string]$out.locality
    $gotKey = [string]$out.canonicalModel
    $okLoc = ($got -eq $Expected)
    $okKey = ([string]::IsNullOrEmpty($ExpectedKey)) -or ($gotKey -eq $ExpectedKey)
    if ($okLoc -and $okKey) {
        Write-Host ("PASS  {0,-40} -> {1,-8} key={2}" -f $Label, $got, $gotKey) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0,-40} -> {1} key={2} (esperado {3} / {4})" -f $Label, $got, $gotKey, $Expected, $ExpectedKey) -ForegroundColor Red
    }
}

try {
    Assert-Codex -Label 'default da config'         -Expected 'external' -ExpectedKey 'openai/gpt-5.5'            -CallArgs @{}
    Assert-Codex -Label 'gpt-5.5 explicito'        -Expected 'external' -ExpectedKey 'openai/gpt-5.5'            -CallArgs @{ Model = 'gpt-5.5' }
    Assert-Codex -Label 'openai/gpt-5.5 prefixado' -Expected 'external' -ExpectedKey 'openai/gpt-5.5'            -CallArgs @{ Model = 'openai/gpt-5.5' }
    Assert-Codex -Label 'oss ollama'               -Expected 'local'    -ExpectedKey 'ollama/qwen2.5-coder:7b'   -CallArgs @{ Model = 'qwen2.5-coder:7b'; Oss = $true; LocalProvider = 'ollama' }
    Assert-Codex -Label 'oss lmstudio'             -Expected 'local'    -ExpectedKey 'lmstudio/foo'              -CallArgs @{ Model = 'foo'; Oss = $true; LocalProvider = 'lmstudio' }
    Assert-Codex -Label 'profile local (loopback)' -Expected 'local'    -ExpectedKey 'localx/qwen2.5-coder:7b'   -CallArgs @{ Profile = 'plocal' }
    Assert-Codex -Label 'profile remoto'           -Expected 'external' -ExpectedKey 'remotex/some-model'        -CallArgs @{ Profile = 'premote' }
    Assert-Codex -Label 'profile inexistente'      -Expected 'unknown'  -ExpectedKey ''                          -CallArgs @{ Model = 'x'; Profile = 'naoexiste' }
} finally {
    Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $tmp -Force -Recurse -ErrorAction SilentlyContinue
}

# Config ausente com modelo explicito: cai para openai/external (built-in), nao unknown.
$missing = Join-Path $tmp 'inexistente.toml'
$out = & $target -Model 'gpt-5.5' -ConfigPath $missing | ConvertFrom-Json
if ([string]$out.locality -eq 'external') {
    Write-Host ("PASS  {0,-40} -> {1}" -f 'config ausente -> openai external', $out.locality) -ForegroundColor Green
} else {
    $fail++
    Write-Host ("FAIL  config ausente -> {0} (esperado external)" -f $out.locality) -ForegroundColor Red
}

# Config ausente e modelo omitido: nao inventa modelo; fica unknown.
$outMissingDefault = & $target -ConfigPath $missing | ConvertFrom-Json
if ([string]$outMissingDefault.locality -eq 'unknown') {
    Write-Host ("PASS  {0,-40} -> {1}" -f 'config ausente + modelo omitido', $outMissingDefault.locality) -ForegroundColor Green
} else {
    $fail++
    Write-Host ("FAIL  config ausente + modelo omitido -> {0} (esperado unknown)" -f $outMissingDefault.locality) -ForegroundColor Red
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-CodexModelLocalitySelfTest.ps1" }
Write-Host 'OK: Test-CodexModelLocalitySelfTest.ps1' -ForegroundColor Cyan
