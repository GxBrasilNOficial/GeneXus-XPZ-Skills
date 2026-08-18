#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Test-XpzGlobalInstructions.ps1.

.DESCRIPTION
    Sem rede. Monta perfis de usuário falsos via $env:USERPROFILE e confere:
      - deteccao positiva e por variacao verbal das ancoras (status "presente");
      - ausencia de cobertura (status "nao_detectado" e overall REVIEW);
      - seguimento de referencia '@<caminho>' (Claude -> AGENTS.md referenciado);
      - paridade contrato <-> SKILL.md: cada SkillHeading do contrato existe no
        bloco "## AGENTS.MD RECOMENDADO" do SKILL.md (anti-drift).

    As ferramentas são consideradas instaladas pelo PATH real; as FONTES vêm do
    perfil falso, isolando a deteccao.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptUnderTest = Join-Path $PSScriptRoot 'Test-XpzGlobalInstructions.ps1'
$contractPath = Join-Path $PSScriptRoot 'xpz-global-instructions-topics.psd1'
$skillMd = Join-Path $repoRoot 'xpz-skills-setup\SKILL.md'

foreach ($p in @($scriptUnderTest, $contractPath, $skillMd)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "BLOCK: arquivo ausente: $p" }
}

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('xpz-glselftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}
function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Write-File {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}
function Get-Coverage {
    param($Report, [string]$Tool, [string]$Topic)
    $t = $Report.tools | Where-Object { $_.name -eq $Tool }
    if (-not $t) { return '<tool-ausente>' }
    $c = $t.coverage | Where-Object { $_.topic -eq $Topic }
    if (-not $c) { return '<topico-ausente>' }
    return $c.status
}
function Assert-Equal {
    param([string]$CaseName, [string]$Expected, [string]$Actual)
    $script:cases++
    if ($Actual -eq $Expected) { Write-Output ("PASS: {0} -> {1}" -f $CaseName, $Expected) }
    else { $script:failures++; Write-Output ("FAIL: {0} -> esperado '{1}', obtido '{2}'" -f $CaseName, $Expected, $Actual) }
}

$covered = @'
## Ferramentas de busca e shell
- Nunca usar cd "path" && <comando> no shell.
## Cherry-pick em worktrees
- Ao fazer cherry-pick com git -C <path>, nunca HEAD@{0}.
'@

$variant = @'
Politica de shell: evite rodar cd numa pasta && em seguida outro comando.
Sobre cherry-pick: sempre use o hash do commit literal ao integrar.
'@

$originalProfile = $env:USERPROFILE

# --- Setup A: todas as fontes cobrem; Codex usa variacao; Claude usa @ref; Antigravity usa conteudo/vinculo ------
$fpA = New-TempDir
try {
    Write-File -Path (Join-Path $fpA '.codex\AGENTS.md') -Content $variant
    Write-File -Path (Join-Path $fpA '.claude\CLAUDE.md') -Content '@~/.codex/AGENTS.md'
    Write-File -Path (Join-Path $fpA '.config\opencode\AGENTS.md') -Content $covered
    Write-File -Path (Join-Path $fpA '.gemini\config\AGENTS.md') -Content $covered
    Write-File -Path (Join-Path $fpA '.cursor\xpz-global-instructions-mcp\config.json') `
        -Content ('{ "agentsPath": "' + ((Join-Path $fpA '.codex\AGENTS.md') -replace '\\', '\\') + '" }')

    $env:USERPROFILE = $fpA
    $repA = (& $scriptUnderTest -RepoRoot $repoRoot -AsJson | Out-String | ConvertFrom-Json)
    $env:USERPROFILE = $originalProfile

    Assert-Equal 'A: Codex busca-shell (variacao)' 'presente' (Get-Coverage $repA 'Codex' 'busca-shell')
    Assert-Equal 'A: Codex cherry-pick (variacao)' 'presente' (Get-Coverage $repA 'Codex' 'cherry-pick-worktree')
    Assert-Equal 'A: Claude busca-shell (via @ref)' 'presente' (Get-Coverage $repA 'ClaudeCode' 'busca-shell')
    Assert-Equal 'A: OpenCode cherry-pick' 'presente' (Get-Coverage $repA 'OpenCode' 'cherry-pick-worktree')
    Assert-Equal 'A: Antigravity busca-shell (conteudo/vinculo)' 'presente' (Get-Coverage $repA 'Antigravity' 'busca-shell')
    Assert-Equal 'A: Antigravity cherry-pick (conteudo/vinculo)' 'presente' (Get-Coverage $repA 'Antigravity' 'cherry-pick-worktree')
    Assert-Equal 'A: overall OK' 'GLOBAL_INSTRUCTIONS_OK' $repA.overall
}
finally { $env:USERPROFILE = $originalProfile; Remove-TempDir -Path $fpA }

# --- Setup B: Codex sem topicos; demais fontes ausentes -> REVIEW --------------
$fpB = New-TempDir
try {
    Write-File -Path (Join-Path $fpB '.codex\AGENTS.md') -Content 'Texto qualquer sem regras relevantes.'

    $env:USERPROFILE = $fpB
    $repB = (& $scriptUnderTest -RepoRoot $repoRoot -AsJson | Out-String | ConvertFrom-Json)
    $env:USERPROFILE = $originalProfile

    Assert-Equal 'B: Codex busca-shell nao_detectado' 'nao_detectado' (Get-Coverage $repB 'Codex' 'busca-shell')
    Assert-Equal 'B: overall REVIEW' 'GLOBAL_INSTRUCTIONS_REVIEW' $repB.overall
}
finally { $env:USERPROFILE = $originalProfile; Remove-TempDir -Path $fpB }

# --- Setup C: Antigravity com @ref textual -> nao_detectado (runtime nao expande @ref) ---
$fpC = New-TempDir
try {
    Write-File -Path (Join-Path $fpC '.codex\AGENTS.md') -Content $covered
    Write-File -Path (Join-Path $fpC '.claude\CLAUDE.md') -Content '@~/.codex/AGENTS.md'
    Write-File -Path (Join-Path $fpC '.config\opencode\AGENTS.md') -Content $covered
    Write-File -Path (Join-Path $fpC '.gemini\config\AGENTS.md') -Content '@~/.codex/AGENTS.md'
    Write-File -Path (Join-Path $fpC '.cursor\xpz-global-instructions-mcp\config.json') `
        -Content ('{ "agentsPath": "' + ((Join-Path $fpC '.codex\AGENTS.md') -replace '\\', '\\') + '" }')

    $env:USERPROFILE = $fpC
    $repC = (& $scriptUnderTest -RepoRoot $repoRoot -AsJson | Out-String | ConvertFrom-Json)
    $env:USERPROFILE = $originalProfile

    Assert-Equal 'C: Antigravity busca-shell nao_detectado por @ref' 'nao_detectado' (Get-Coverage $repC 'Antigravity' 'busca-shell')
    Assert-Equal 'C: overall REVIEW por Antigravity @ref' 'GLOBAL_INSTRUCTIONS_REVIEW' $repC.overall
}
finally { $env:USERPROFILE = $originalProfile; Remove-TempDir -Path $fpC }

# --- Paridade contrato <-> SKILL.md -------------------------------------------
$contract = Import-PowerShellDataFile -LiteralPath $contractPath
$skillText = Get-Content -LiteralPath $skillMd -Raw -Encoding UTF8
foreach ($topic in @($contract.Topics)) {
    $script:cases++
    if ($skillText.Contains([string]$topic.SkillHeading)) {
        Write-Output ("PASS: paridade SKILL.md contem '{0}'" -f $topic.SkillHeading)
    }
    else {
        $script:failures++
        Write-Output ("FAIL: paridade SKILL.md NAO contem '{0}' (drift contrato<->doc)" -f $topic.SkillHeading)
    }
}

Write-Output '---'
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} casos passaram" -f $cases)
    exit 0
}
else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} casos falharam" -f $failures, $cases)
    exit 1
}
