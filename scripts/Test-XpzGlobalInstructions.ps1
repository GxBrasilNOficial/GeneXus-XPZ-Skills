#requires -Version 7.4

<#
.SYNOPSIS
    Auditoria dos instrucionais globais (passo 9 de xpz-skills-setup): resolve a
    fonte efetiva por ferramenta instalada e sinaliza a cobertura dos topicos
    minimos de forma conservadora.

.DESCRIPTION
    Camada 1 (deterministica): para cada ferramenta instalada, descobre o texto
    efetivo das instrucoes globais, seguindo centralizacao e referencias:
      - Codex      -> ~/.codex/AGENTS.md
      - ClaudeCode -> ~/.claude/CLAUDE.md (segue linhas '@<caminho>')
      - OpenCode   -> ~/.config/opencode/AGENTS.md + instructions[] de opencode.json(c)
      - Cursor     -> agentsPath de ~/.cursor/xpz-global-instructions-mcp/config.json
    Referencias '@<caminho>.md' são seguidas recursivamente (com protecao a loop).

    Camada 2 (sinal conservador): aplica as ancoras do contrato
    scripts/xpz-global-instructions-topics.psd1. Por topico: QUALQUER ancora que
    case -> "presente"; nenhuma -> "nao_detectado" (NUNCA "ausente"). nao_detectado
    significa "o agente revisa", não "falta, pode duplicar".

    NÃO escreve nada. A oferta e a gravacao de correcoes seguem manuais, sob
    confirmacao explicita do usuário (passo 9 do SKILL.md).

.OUTPUTS
    Texto legivel por padrão; objeto JSON com -AsJson. "overall" e os "status" são
    destinados a interpretacao por agente.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ContractPath,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Requested)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        return (Resolve-Path -LiteralPath $Requested).Path
    }
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'BLOCK: nao foi possivel inferir a raiz do repositorio a partir de PSScriptRoot.'
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'BLOCK: USERPROFILE nao definido.'
    }
    return $env:USERPROFILE
}

function Expand-UserPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    if ($Path.StartsWith('~/') -or $Path.StartsWith('~\')) {
        return (Join-Path (Get-ProfileRoot) $Path.Substring(2))
    }
    return $Path
}

function Test-UsableCliOnPath {
    param([string]$Name)
    $cmds = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmds) { return $false }
    foreach ($cmd in @($cmds)) {
        if ([string]::IsNullOrWhiteSpace($cmd.Source)) { continue }
        if ($cmd.Source -match '\\WindowsApps\\') { continue }
        if (Test-Path -LiteralPath $cmd.Source -PathType Leaf) {
            try {
                if ((Get-Item -LiteralPath $cmd.Source).Length -gt 0) {
                    return $true
                }
            } catch {}
        }
    }
    return $false
}

function Test-ToolInstalled {
    param([string]$Tool)
    $profileRoot = Get-ProfileRoot
    switch ($Tool) {
        'ClaudeCode' {
            if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\settings.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\CLAUDE.md') -PathType Leaf) { return $true }
            return $false
        }
        'Codex' {
            if (Get-Command codex -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.codex\config.toml') -PathType Leaf) { return $true }
            return $false
        }
        'Cursor' {
            if (Get-Command cursor -ErrorAction SilentlyContinue) { return $true }
            $cursorRoot = Join-Path $profileRoot '.cursor'
            if (-not (Test-Path -LiteralPath $cursorRoot -PathType Container)) { return $false }
            foreach ($name in @('mcp.json', 'skills-cursor', 'rules')) {
                if (Test-Path -LiteralPath (Join-Path $cursorRoot $name)) { return $true }
            }
            return $false
        }
        'OpenCode' {
            if (Get-Command opencode -ErrorAction SilentlyContinue) { return $true }
            $configDir = Join-Path $profileRoot '.config\opencode'
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.jsonc') -PathType Leaf) { return $true }
            return $false
        }
        'Antigravity' {
            if (Test-UsableCliOnPath -Name 'agy') { return $true }
            if (Test-UsableCliOnPath -Name 'antigravity') { return $true }
            $geminiConfigDir = Join-Path $profileRoot '.gemini\config'
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'config.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'AGENTS.md') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'GEMINI.md') -PathType Leaf) { return $true }
            $geminiDir = Join-Path $profileRoot '.gemini'
            if (Test-Path -LiteralPath (Join-Path $geminiDir 'AGENTS.md') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiDir 'GEMINI.md') -PathType Leaf) { return $true }
            return $false
        }
    }
    return $false
}

function Get-ReferencePaths {
    param([string]$BaseFile, [string]$Content)
    $paths = @()
    $matches = [regex]::Matches($Content, '(?m)^\s*@(?<path>(?:~[\\/][^\s]+|[^\s]+\.md))\s*$')
    foreach ($m in $matches) {
        $raw = $m.Groups['path'].Value
        $expanded = Expand-UserPath $raw
        if (-not [System.IO.Path]::IsPathRooted($expanded)) {
            $expanded = Join-Path (Split-Path -Parent $BaseFile) $expanded
        }
        $paths += $expanded
    }
    return $paths
}

function Read-EffectiveText {
    param([string[]]$RootFiles)

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $sb = [System.Text.StringBuilder]::new()
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($f in $RootFiles) {
        if (-not [string]::IsNullOrWhiteSpace($f)) { $queue.Enqueue($f) }
    }

    while ($queue.Count -gt 0) {
        $file = $queue.Dequeue()
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
        $full = (Resolve-Path -LiteralPath $file).Path
        if ($visited.Contains($full)) { continue }
        [void]$visited.Add($full)

        $content = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        if ($null -eq $content) { $content = '' }
        [void]$sb.AppendLine($content)

        foreach ($ref in (Get-ReferencePaths -BaseFile $full -Content $content)) {
            $queue.Enqueue($ref)
        }
    }
    return $sb.ToString()
}

function Get-EffectiveSources {
    param([string]$Tool)
    $profileRoot = Get-ProfileRoot
    $sources = @()

    switch ($Tool) {
        'Codex' {
            $sources += (Join-Path $profileRoot '.codex\AGENTS.md')
        }
        'ClaudeCode' {
            $sources += (Join-Path $profileRoot '.claude\CLAUDE.md')
        }
        'OpenCode' {
            $sources += (Join-Path $profileRoot '.config\opencode\AGENTS.md')
            foreach ($cfgName in @('opencode.json', 'opencode.jsonc')) {
                $cfgPath = Join-Path $profileRoot ('.config\opencode\' + $cfgName)
                if (-not (Test-Path -LiteralPath $cfgPath -PathType Leaf)) { continue }
                try {
                    $json = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($json.PSObject.Properties.Name -contains 'instructions') {
                        foreach ($i in @($json.instructions)) {
                            if (-not [string]::IsNullOrWhiteSpace($i)) { $sources += (Expand-UserPath ([string]$i)) }
                        }
                    }
                }
                catch { }
            }
        }
        'Cursor' {
            $cfgPath = Join-Path $profileRoot '.cursor\xpz-global-instructions-mcp\config.json'
            if (Test-Path -LiteralPath $cfgPath -PathType Leaf) {
                try {
                    $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($cfg.PSObject.Properties.Name -contains 'agentsPath') {
                        $ap = [string]$cfg.agentsPath
                        if (-not [string]::IsNullOrWhiteSpace($ap)) { $sources += (Expand-UserPath $ap) }
                    }
                }
                catch { }
            }
        }
        'Antigravity' {
            $candidates = @(
                (Join-Path $profileRoot '.gemini\config\AGENTS.md'),
                (Join-Path $profileRoot '.gemini\config\GEMINI.md'),
                (Join-Path $profileRoot '.gemini\AGENTS.md'),
                (Join-Path $profileRoot '.gemini\GEMINI.md')
            )
            foreach ($cand in $candidates) {
                if (Test-Path -LiteralPath $cand -PathType Leaf) {
                    try {
                        if ((Get-Item -LiteralPath $cand).Length -gt 0) {
                            $sources += $cand
                            break
                        }
                    } catch {}
                }
            }
        }
    }
    return @($sources | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# --- Carregar contrato --------------------------------------------------------
$root = Resolve-RepoRoot -Requested $RepoRoot
if ([string]::IsNullOrWhiteSpace($ContractPath)) {
    $ContractPath = Join-Path $root 'scripts\xpz-global-instructions-topics.psd1'
}
if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf)) {
    throw "BLOCK: contrato de topicos ausente: $ContractPath"
}
$contract = Import-PowerShellDataFile -LiteralPath $ContractPath
$topics = @($contract.Topics)
if ($topics.Count -eq 0) {
    throw "BLOCK: contrato sem topicos: $ContractPath"
}

$regexOpts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
    [System.Text.RegularExpressions.RegexOptions]::Singleline

function Get-TopicStatus {
    param([string]$Text, [string[]]$AnchorsAny)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 'nao_detectado' }
    foreach ($anchor in $AnchorsAny) {
        if ([regex]::IsMatch($Text, $anchor, $regexOpts)) { return 'presente' }
    }
    return 'nao_detectado'
}

# --- Auditar por ferramenta ---------------------------------------------------
$toolNames = @('Codex', 'ClaudeCode', 'OpenCode', 'Cursor', 'Antigravity')
$toolsReport = @()
$needsReview = $false

foreach ($tool in $toolNames) {
    $installed = Test-ToolInstalled -Tool $tool
    $existing = @()
    $sourceFound = $false
    $coverage = @()

    if ($installed) {
        $sources = @(Get-EffectiveSources -Tool $tool)
        $existing = @($sources | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        if ($existing.Count -gt 0) { $text = Read-EffectiveText -RootFiles $existing } else { $text = '' }
        $sourceFound = -not [string]::IsNullOrWhiteSpace($text)

        foreach ($topic in $topics) {
            $status = Get-TopicStatus -Text $text -AnchorsAny @($topic.AnchorsAny)
            if ($status -ne 'presente') { $needsReview = $true }
            $coverage += [ordered]@{ topic = [string]$topic.Id; label = [string]$topic.Label; status = $status }
        }
        if (-not $sourceFound) { $needsReview = $true }
    }

    $toolsReport += [ordered]@{
        name             = $tool
        installed        = $installed
        effectiveSources = @($existing)
        sourceFound      = $sourceFound
        coverage         = @($coverage)
    }
}

if ($needsReview) { $overall = 'GLOBAL_INSTRUCTIONS_REVIEW' } else { $overall = 'GLOBAL_INSTRUCTIONS_OK' }

$result = [ordered]@{
    overall  = $overall
    repoRoot = $root
    contract = $ContractPath
    topics   = @($topics | ForEach-Object { [ordered]@{ id = [string]$_.Id; label = [string]$_.Label } })
    tools    = $toolsReport
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8 | Write-Output
    return
}

# Saida legivel
Write-Output ("OVERALL: {0}" -f $overall)
Write-Output ("Contrato: {0}" -f $ContractPath)
Write-Output ''
foreach ($t in $toolsReport) {
    if (-not $t.installed) {
        Write-Output ("[{0}] nao instalada" -f $t.name)
        continue
    }
    if (-not $t.sourceFound) {
        Write-Output ("[{0}] instalada - FONTE EFETIVA NAO ENCONTRADA (revisar)" -f $t.name)
        continue
    }
    Write-Output ("[{0}] instalada - fonte: {1}" -f $t.name, (@($t.effectiveSources) -join '; '))
    foreach ($c in $t.coverage) {
        Write-Output ("    {0,-24} {1}" -f $c.topic, $c.status)
    }
}
Write-Output ''
Write-Output 'Legenda: presente = topico coberto no texto efetivo; nao_detectado = o agente deve revisar (NAO significa ausente).'
