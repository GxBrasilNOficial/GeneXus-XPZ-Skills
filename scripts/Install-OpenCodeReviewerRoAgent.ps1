#requires -Version 7.4
<#
.SYNOPSIS
    Instala/atualiza o agente global `reviewer-ro` do opencode (least-privilege, "sem
    execucao/escrita") no opencode.jsonc do usuario, por edicao LOCALIZADA.
.DESCRIPTION
    Dono: skill xpz-llm-delegate. Provisiona o agente `reviewer-ro` para QUALQUER cwd (o
    project-local `.opencode/agent/reviewer-ro.md` cobre so a raiz do repo). Alvo:
    ~/.config/opencode/opencode.jsonc.

    Contrato (design congelado, D3):
      - A definicao e DERIVADA do markdown project-local (.opencode/agent/reviewer-ro.md) — fonte
        unica do bloco `permission` e do `mode`.
      - Edicao LOCALIZADA: substitui/insere APENAS o bloco `agent.reviewer-ro`, preservando
        comentarios, formatacao e demais chaves do opencode.jsonc (NAO reescreve o arquivo via
        ConvertTo-Json). NAO reusa Read-McpRoot (hardcoded p/ mcpServers).
      - MIGRACAO: se o reviewer-ro global estiver na forma antiga `tools: { edit:false, ... }`
        (interino), substitui pela forma `permission` (default-deny curinga + allowlist).

    Espelha convencoes de scripts/Install-CursorGlobalInstructionsMcp.ps1 (Get-ProfileRoot,
    UTF-8 sem BOM, SupportsShouldProcess).
.PARAMETER JsoncPath
    Caminho do opencode.jsonc global. Default: ~/.config/opencode/opencode.jsonc.
.PARAMETER AgentMarkdownPath
    Caminho do markdown project-local do agente (fonte da derivacao).
    Default: <repo>/.opencode/agent/reviewer-ro.md (relativo a este script).
.EXAMPLE
    pwsh -NoProfile -File scripts/Install-OpenCodeReviewerRoAgent.ps1
.EXAMPLE
    pwsh -NoProfile -File scripts/Install-OpenCodeReviewerRoAgent.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $JsoncPath,
    [string] $AgentMarkdownPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Suporte a UTF-8 sem BOM (mesma convencao do instalador do Cursor)
$utf8Support = Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8Support -PathType Leaf)) {
    throw "BLOCK: suporte de encoding UTF-8 sem BOM ausente: $utf8Support"
}
. $utf8Support

# Guard (parser de markdown + JSONC + forma esperada)
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) { throw 'BLOCK: USERPROFILE nao definido.' }
    return $env:USERPROFILE
}

function Get-AgentMarkdownDescription {
    <# Extrai e achata a `description:` (escalar folded `>-`) do frontmatter markdown numa linha. #>
    param([Parameter(Mandatory)] [string] $Path)
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    $out = [System.Collections.Generic.List[string]]::new()
    $inDesc = $false
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '---') { break }
        if ($inDesc) {
            if ($line -match '^\s+\S') { $out.Add($line.Trim()); continue }
            if ($line -match '^\S') { $inDesc = $false }  # nova chave top-level encerra
        }
        if ($line -match '^\s*description\s*:\s*(>[-+]?|\|[-+]?)?\s*(?<inline>\S.*)?$') {
            $inline = $Matches['inline']
            if ($inline) { $out.Add($inline.Trim()) } else { $inDesc = $true }
            continue
        }
    }
    return (($out -join ' ') -replace '\s+', ' ').Trim()
}

function Find-JsoncMatchingBrace {
    <# Dado o indice de um '{' em $Text, devolve o indice do '}' correspondente, ignorando chaves
       dentro de strings. -1 se nao fechar. #>
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [int] $OpenIndex)
    $depth = 0; $inStr = $false; $esc = $false
    for ($i = $OpenIndex; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($inStr) {
            if ($esc) { $esc = $false }
            elseif ($c -eq '\') { $esc = $true }
            elseif ($c -eq '"') { $inStr = $false }
            continue
        }
        if ($c -eq '"') { $inStr = $true; continue }
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { return $i } }
    }
    return -1
}

function Find-JsoncKeyValueSpan {
    <# Localiza a chave "Key" (fora de string) cujo valor e um objeto {...} e devolve
       @{ keyStart; valueOpen; valueClose } (indices) ou $null. Busca a partir de -From; se -To >= 0,
       a chave so conta se comecar ANTES de -To (limite exclusivo — para escopar a um bloco pai). #>
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [string] $Key, [int] $From = 0, [int] $To = -1)
    $needle = '"' + $Key + '"'
    $idx = $From
    while ($true) {
        $k = $Text.IndexOf($needle, $idx)
        if ($k -lt 0) { return $null }
        if ($To -ge 0 -and $k -ge $To) { return $null }
        # confirmar que nao esta dentro de uma string (heuristica: contar aspas nao-escapadas antes)
        $j = $k + $needle.Length
        while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
        if ($j -lt $Text.Length -and $Text[$j] -eq ':') {
            $j++
            while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
            if ($j -lt $Text.Length -and $Text[$j] -eq '{') {
                $close = Find-JsoncMatchingBrace -Text $Text -OpenIndex $j
                if ($close -lt 0) { throw "BLOCK: chave '$Key' com objeto nao fechado no JSONC." }
                return @{ keyStart = $k; valueOpen = $j; valueClose = $close }
            }
        }
        $idx = $k + $needle.Length
    }
}

function Build-ReviewerRoFragment {
    <# Monta o VALOR JSON (objeto) do reviewer-ro a partir da definicao derivada, indentado para
       insercao. -Indent = indentacao (espacos) da linha da chave "reviewer-ro".

       ESCOPO DA PRESERVACAO (nota de contrato): o valor do reviewer-ro e RECONSTRUIDO por inteiro a
       partir da fonte canonica (markdown project-local: description + mode + permission). Portanto
       chaves EXTRAS *dentro* de um `agent.reviewer-ro` preexistente (ex.: `temperature`, `model`,
       `prompt` custom) NAO sao preservadas na migracao/atualizacao — o reviewer-ro e definido
       integralmente pela frente, nao e um agente que o usuario customiza campo a campo. O claim
       "preserva comentarios/formatacao/demais chaves" refere-se as demais chaves do opencode.jsonc
       *fora* do bloco agent.reviewer-ro (schema, instructions, outros agentes) — essas sim intactas. #>
    param(
        [Parameter(Mandatory)] [string] $Description,
        [Parameter(Mandatory)] [string] $Mode,
        [Parameter(Mandatory)] $Permission,   # [ordered] nome->acao
        [string] $Indent = '    '
    )
    $i2 = $Indent + '  '
    $i3 = $i2 + '  '
    $descEsc = $Description -replace '\\', '\\' -replace '"', '\"'
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('{')
    [void]$sb.AppendLine("$i2`"description`": `"$descEsc`",")
    [void]$sb.AppendLine("$i2`"mode`": `"$Mode`",")
    [void]$sb.AppendLine("$i2`"permission`": {")
    $keys = @($Permission.Keys)
    for ($n = 0; $n -lt $keys.Count; $n++) {
        $key = $keys[$n]
        $val = $Permission[$key]
        $comma = if ($n -lt $keys.Count - 1) { ',' } else { '' }
        [void]$sb.AppendLine("$i3`"$key`": `"$val`"$comma")
    }
    [void]$sb.AppendLine("$i2}")
    [void]$sb.Append("$Indent}")
    return $sb.ToString()
}

# ── Resolucao de caminhos ──────────────────────────────────────────────────────
if (-not $JsoncPath) {
    $JsoncPath = Join-Path (Get-ProfileRoot) '.config\opencode\opencode.jsonc'
}
if (-not $AgentMarkdownPath) {
    $AgentMarkdownPath = Join-Path $PSScriptRoot '..\.opencode\agent\reviewer-ro.md'
}
if (-not (Test-Path -LiteralPath $AgentMarkdownPath -PathType Leaf)) {
    throw "BLOCK: markdown project-local do agente ausente (fonte da derivacao): $AgentMarkdownPath"
}

# ── Derivacao (fonte unica = markdown) ─────────────────────────────────────────
$def = Get-OpenCodeReviewerRoPermissionFromMarkdown -Path $AgentMarkdownPath
if ($null -eq $def -or $null -eq $def.permission -or $def.permission.Count -eq 0) {
    throw "BLOCK: nao foi possivel derivar o bloco `permission` do markdown: $AgentMarkdownPath"
}
$mode = if ($def.mode) { $def.mode } else { 'all' }
$desc = Get-AgentMarkdownDescription -Path $AgentMarkdownPath
if ([string]::IsNullOrWhiteSpace($desc)) {
    $desc = 'Revisor por pares sem execucao/escrita: le fontes (read/grep/glob/list) e emite um parecer.'
}

# Guarda de deriva: a definicao derivada tem de bater com a forma esperada (mesma do static check).
$expectedStar = $def.permission['*']
if ($expectedStar -ne 'deny') {
    throw "BLOCK: markdown com '*'='$expectedStar' (esperado 'deny'). Corrija $AgentMarkdownPath antes de instalar."
}

# ── Leitura/edicao localizada do JSONC ─────────────────────────────────────────
$existed = Test-Path -LiteralPath $JsoncPath -PathType Leaf
$nl = "`n"
if ($existed) {
    $raw = Get-Content -LiteralPath $JsoncPath -Raw -Encoding utf8
    if ($raw -match "`r`n") { $nl = "`r`n" }
} else {
    $raw = ''
}

$action = 'atualizar'
if (-not $existed -or [string]::IsNullOrWhiteSpace($raw)) {
    # Arquivo novo/vazio: cria minimo com schema + agent.reviewer-ro
    $frag = Build-ReviewerRoFragment -Description $desc -Mode $mode -Permission $def.permission -Indent '    '
    $new = @(
        '{',
        '  "$schema": "https://opencode.ai/config.json",',
        '  "agent": {',
        "    `"reviewer-ro`": $frag",
        '  }',
        '}'
    ) -join $nl
    $new += $nl
    $action = 'criar'
} else {
    # Escopa a chave `reviewer-ro` ao bloco `agent` — NAO busca globalmente (uma chave homonima
    # fora de `agent`, ex.: em `metadata.reviewer-ro`, nao pode ser confundida com agent.reviewer-ro,
    # senao o instalador editaria o bloco errado e falharia a validacao pos-edicao).
    $ag = Find-JsoncKeyValueSpan -Text $raw -Key 'agent'
    if ($null -ne $ag) {
        $rr = Find-JsoncKeyValueSpan -Text $raw -Key 'reviewer-ro' -From $ag.valueOpen -To $ag.valueClose
        if ($null -ne $rr) {
            # Substitui o VALOR do reviewer-ro DENTRO do agent (migracao tools:->permission cai aqui).
            # Detecta a indentacao da linha da chave (agnostico a `\n`/`\r\n`).
            $p = $rr.keyStart - 1
            while ($p -ge 0 -and $raw[$p] -ne "`n" -and $raw[$p] -ne "`r") { $p-- }
            $p++
            $indent = ''
            while ($p -lt $rr.keyStart -and ($raw[$p] -eq ' ' -or $raw[$p] -eq "`t")) { $indent += $raw[$p]; $p++ }
            $frag = Build-ReviewerRoFragment -Description $desc -Mode $mode -Permission $def.permission -Indent $indent
            $new = $raw.Substring(0, $rr.valueOpen) + $frag + $raw.Substring($rr.valueClose + 1)
        } else {
            # agent existe mas sem reviewer-ro: insere como primeira propriedade do agent
            $frag = Build-ReviewerRoFragment -Description $desc -Mode $mode -Permission $def.permission -Indent '    '
            $afterOpen = $ag.valueOpen + 1
            $insertion = "$nl    `"reviewer-ro`": $frag,"
            $new = $raw.Substring(0, $afterOpen) + $insertion + $raw.Substring($afterOpen)
            $action = 'inserir (bloco agent existente)'
        }
    } else {
        # sem bloco agent: insere apos o '{' raiz
        $rootOpen = $raw.IndexOf('{')
        if ($rootOpen -lt 0) { throw "BLOCK: opencode.jsonc sem objeto raiz." }
        $frag = Build-ReviewerRoFragment -Description $desc -Mode $mode -Permission $def.permission -Indent '    '
        $insertion = "$nl  `"agent`": {$nl    `"reviewer-ro`": $frag$nl  },"
        $new = $raw.Substring(0, $rootOpen + 1) + $insertion + $raw.Substring($rootOpen + 1)
        $action = 'inserir (novo bloco agent)'
    }
}

# ── Validacao pos-edicao (parse + forma) ───────────────────────────────────────
$parsed = $null
try { $parsed = ConvertFrom-Jsonc -Raw $new } catch { throw "BLOCK: JSONC resultante nao parseia: $($_.Exception.Message)" }
if ($null -eq $parsed.PSObject.Properties['agent'] -or $null -eq $parsed.agent.PSObject.Properties['reviewer-ro']) {
    throw 'BLOCK: apos a edicao o agent.reviewer-ro nao esta presente/parseavel.'
}
$rroPerm = $parsed.agent.'reviewer-ro'.permission
if ($null -eq $rroPerm -or [string]$rroPerm.'*' -ne 'deny') {
    throw "BLOCK: apos a edicao o reviewer-ro.permission['*'] nao resolveu 'deny'."
}
foreach ($a in @('read', 'grep', 'glob', 'list')) {
    if ([string]$rroPerm.$a -ne 'allow') { throw "BLOCK: reviewer-ro.permission['$a'] != 'allow' apos edicao." }
}

# ── Escrita ────────────────────────────────────────────────────────────────────
if ($PSCmdlet.ShouldProcess($JsoncPath, "Instalar/atualizar agente global reviewer-ro ($action)")) {
    $dir = Split-Path -Parent $JsoncPath
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($JsoncPath, $new, (Get-Utf8NoBomEncoding))
    Write-Output "OK: reviewer-ro global $action em $JsoncPath"
    Write-Output "OK: derivado de $AgentMarkdownPath (mode=$mode; allow-set {read,grep,glob,list})"
    Write-Output "NEXT: valide com 'opencode agent list' (bloco reviewer-ro) e rode scripts/Test-OpenCodeReviewerRoSelfTest.ps1."
}
