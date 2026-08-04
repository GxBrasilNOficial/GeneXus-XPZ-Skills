#requires -Version 7.4

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AgentsPath,

    [string]$SkillsRepoRoot,

    [string]$PythonCommand = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$McpServerKey = 'xpz-global-instructions'
$CursorMcpDirName = 'xpz-global-instructions-mcp'

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'BLOCK: USERPROFILE nao definido.'
    }
    return $env:USERPROFILE
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
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Codex', 'Claude', 'Cursor', 'OpenCode', 'Antigravity')]
        [string]$Tool
    )

    $profileRoot = Get-ProfileRoot
    switch ($Tool) {
        'Codex' {
            if (Get-Command codex -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.codex\config.toml') -PathType Leaf) { return $true }
            return $false
        }
        'Claude' {
            if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\settings.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\CLAUDE.md') -PathType Leaf) { return $true }
            return $false
        }
        'Cursor' {
            if (Get-Command cursor -ErrorAction SilentlyContinue) { return $true }
            $cursorRoot = Join-Path $profileRoot '.cursor'
            if (-not (Test-Path -LiteralPath $cursorRoot -PathType Container)) { return $false }
            $signals = @('mcp.json', 'skills-cursor', 'rules')
            foreach ($name in $signals) {
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
}

function Expand-UserPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path.StartsWith('~/')) {
        return (Join-Path (Get-ProfileRoot) $Path.Substring(2))
    }
    if ($Path.StartsWith('~\')) {
        return (Join-Path (Get-ProfileRoot) $Path.Substring(2))
    }
    return $Path
}

function Get-InstructionReferencePaths {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return @()
    }

    $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    $matches = [regex]::Matches(
        $content,
        '(?m)^\s*@(?<path>(?:~[\\/][^\s]+|[^\s]+\.md))\s*$'
    )
    $paths = @()
    foreach ($match in $matches) {
        $paths += (Expand-UserPath $match.Groups['path'].Value)
    }
    return $paths
}

function Resolve-GlobalAgentsInstructionsPath {
    param([string]$ExplicitAgentsPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitAgentsPath)) {
        return (Resolve-Path -LiteralPath (Expand-UserPath $ExplicitAgentsPath)).Path
    }

    $profileRoot = Get-ProfileRoot
    $codexInstalled = Test-ToolInstalled -Tool 'Codex'
    $claudeInstalled = Test-ToolInstalled -Tool 'Claude'
    $opencodeInstalled = Test-ToolInstalled -Tool 'OpenCode'
    $antigravityInstalled = Test-ToolInstalled -Tool 'Antigravity'

    $claudePath = Join-Path $profileRoot '.claude\CLAUDE.md'
    foreach ($referenced in (Get-InstructionReferencePaths -FilePath $claudePath)) {
        if ((Test-Path -LiteralPath $referenced -PathType Leaf) -and ((Get-Item -LiteralPath $referenced).Length -gt 0)) {
            return (Resolve-Path -LiteralPath $referenced).Path
        }
    }

    $opencodeConfigCandidates = @(
        (Join-Path $profileRoot '.config\opencode\opencode.json'),
        (Join-Path $profileRoot '.config\opencode\opencode.jsonc')
    )
    foreach ($configPath in $opencodeConfigCandidates) {
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
        try {
            $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            $json = $raw | ConvertFrom-Json
            $instructionPaths = @()
            if ($null -ne $json.instructions) {
                $instructionPaths = @($json.instructions)
            }
            foreach ($instructionPath in $instructionPaths) {
                if ([string]::IsNullOrWhiteSpace($instructionPath)) { continue }
                $expanded = Expand-UserPath $instructionPath
                if ((Test-Path -LiteralPath $expanded -PathType Leaf) -and ((Get-Item -LiteralPath $expanded).Length -gt 0)) {
                    return (Resolve-Path -LiteralPath $expanded).Path
                }
            }
        }
        catch {
            continue
        }
    }

    if ($codexInstalled) {
        $codexAgents = Join-Path $profileRoot '.codex\AGENTS.md'
        if ((Test-Path -LiteralPath $codexAgents -PathType Leaf) -and ((Get-Item -LiteralPath $codexAgents).Length -gt 0)) {
            return (Resolve-Path -LiteralPath $codexAgents).Path
        }
        throw "BLOCK: Codex instalado, mas arquivo ausente ou vazio: $codexAgents. Crie o arquivo ou passe -AgentsPath."
    }

    if ($claudeInstalled) {
        if ((Test-Path -LiteralPath $claudePath -PathType Leaf) -and ((Get-Item -LiteralPath $claudePath).Length -gt 0)) {
            return (Resolve-Path -LiteralPath $claudePath).Path
        }
        throw "BLOCK: Claude Code instalado, mas arquivo ausente ou vazio: $claudePath. Crie o arquivo ou passe -AgentsPath."
    }

    if ($opencodeInstalled) {
        $openCodeAgents = Join-Path $profileRoot '.config\opencode\AGENTS.md'
        if ((Test-Path -LiteralPath $openCodeAgents -PathType Leaf) -and ((Get-Item -LiteralPath $openCodeAgents).Length -gt 0)) {
            return (Resolve-Path -LiteralPath $openCodeAgents).Path
        }
        throw "BLOCK: OpenCode instalado, mas arquivo ausente ou vazio: $openCodeAgents. Crie o arquivo ou passe -AgentsPath."
    }

    if ($antigravityInstalled) {
        $antigravityCandidates = @(
            (Join-Path $profileRoot '.gemini\config\AGENTS.md'),
            (Join-Path $profileRoot '.gemini\config\GEMINI.md'),
            (Join-Path $profileRoot '.gemini\AGENTS.md'),
            (Join-Path $profileRoot '.gemini\GEMINI.md')
        )
        foreach ($cand in $antigravityCandidates) {
            if ((Test-Path -LiteralPath $cand -PathType Leaf) -and ((Get-Item -LiteralPath $cand).Length -gt 0)) {
                return (Resolve-Path -LiteralPath $cand).Path
            }
        }
        throw "BLOCK: Antigravity instalado, mas arquivo de instrucoes ausente ou vazio em ~/.gemini/config/ ou ~/.gemini/. Crie o arquivo ou passe -AgentsPath."
    }

    throw @(
        'BLOCK: nenhuma ferramenta de agente com instrucionais globais detectada (Codex, Claude Code, OpenCode, Antigravity).',
        'Instale ao menos uma delas e crie o arquivo global correspondente, ou passe -AgentsPath explicitamente.'
    ) -join ' '
}

function Get-SkillsRepoRoot {
    param([string]$RequestedRoot)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $resolved = Resolve-Path -LiteralPath $RequestedRoot
        return $resolved.Path
    }

    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        throw 'BLOCK: nao foi possivel inferir a raiz do repositorio a partir de PSScriptRoot.'
    }
    return (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
}

function Read-McpRoot {
    param([string]$Path)

    $root = [ordered]@{ mcpServers = [ordered]@{} }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $root
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $root
    }

    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed.mcpServers) {
        return $root
    }

    foreach ($prop in $parsed.mcpServers.PSObject.Properties) {
        $root.mcpServers[$prop.Name] = $prop.Value
    }
    return $root
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Object
    )

    $json = $Object | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

function Test-PythonCommandOrBlock {
    param([Parameter(Mandatory = $true)][string]$Command)

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "BLOCK: comando Python nao encontrado: $Command. Instale Python, ajuste PATH ou passe -PythonCommand com um comando valido antes de gravar mcp.json."
    }
}

$resolvedAgentsPath = Resolve-GlobalAgentsInstructionsPath -ExplicitAgentsPath $AgentsPath
$repoRoot = Get-SkillsRepoRoot -RequestedRoot $SkillsRepoRoot
$sourceServer = Join-Path $repoRoot 'scripts\cursor-global-instructions-mcp\server.py'
if (-not (Test-Path -LiteralPath $sourceServer -PathType Leaf)) {
    throw "BLOCK: servidor MCP canonico ausente no repositorio: $sourceServer"
}
Test-PythonCommandOrBlock -Command $PythonCommand

$cursorRoot = Join-Path (Get-ProfileRoot) '.cursor'
$targetDir = Join-Path $cursorRoot $CursorMcpDirName
$targetServer = Join-Path $targetDir 'server.py'
$targetConfig = Join-Path $targetDir 'config.json'
$mcpJsonPath = Join-Path $cursorRoot 'mcp.json'

if (-not (Test-ToolInstalled -Tool 'Cursor')) {
    Write-Warning 'Cursor nao detectado pelos sinais usuais; a instalacao ainda sera gravada em ~/.cursor/.'
}

if ($PSCmdlet.ShouldProcess($targetDir, 'Instalar MCP de instrucionais globais do Cursor')) {
    if (-not (Test-Path -LiteralPath $cursorRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $cursorRoot -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourceServer -Destination $targetServer -Force

    $configObject = [ordered]@{
        agentsPath = $resolvedAgentsPath
    }
    Write-JsonFile -Path $targetConfig -Object $configObject

    $mcpObject = Read-McpRoot -Path $mcpJsonPath
    $mcpObject.mcpServers[$McpServerKey] = [ordered]@{
        type    = 'stdio'
        command = $PythonCommand
        args    = @($targetServer)
    }
    Write-JsonFile -Path $mcpJsonPath -Object $mcpObject

    Write-Output "OK: MCP instalado em $targetDir"
    Write-Output "OK: fonte efetiva: $resolvedAgentsPath"
    Write-Output "OK: registro em $mcpJsonPath (chave $McpServerKey)"
    Write-Output 'NEXT: reinicie o Cursor ou recarregue MCPs e valide em nova sessao (mcps/user-xpz-global-instructions e comportamento do AGENTS.md).'
}
