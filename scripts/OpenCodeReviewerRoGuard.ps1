#requires -Version 7.4
<#
.SYNOPSIS
    Guard fail-closed do agente opencode `reviewer-ro` (least-privilege, "sem execucao/escrita").
.DESCRIPTION
    Funcoes COMPARTILHADAS (dot-source) pelos adapters Invoke-OpenCode.ps1 e Start-OpenCodeJob.ps1
    (skill xpz-llm-delegate). Implementa o pre-check fail-closed do D2 do design congelado
    (opencode-reviewer-ro-least-privilege-design.md):

      1. estatico   -> frontmatter do reviewer-ro (project-local .md ou bloco global do jsonc)
                       confere a forma `permission` esperada (deterministico, nao toca o DB);
      2. agent list -> `opencode agent list` confirma que o allow-set RESOLVIDO (last-match-wins,
                       excluindo `external_directory`) e EXATAMENTE {read,grep,glob,list} e que
                       `external_directory` para o padrao `*` NAO resolve `allow` (confinamento de
                       leitura ao cwd); assere o CONJUNTO -> trava divergencia por ausencia E por
                       excesso (ex.: `bash` reaparecendo por regra tardia da config global);
      3. versao     -> `opencode --version` bate com a versao dos fixtures (cláusula de validade).

    Fail-closed TOTAL: qualquer falha -> BLOCK, com o MOTIVO distinguido no recibo:
      - 'static'   = provisionamento quebrado (consertar o reviewer-ro / rodar o instalador);
      - 'version'  = versao do opencode nao testada (revisitar D2/D3 antes de ativar);
      - 'allowset' = allow-set resolvido divergente (regra tardia da global mudou a resolucao);
      - 'agentlist'= `opencode agent list` falhou/timeout/erro (INTERMITENTE — SQLite
                     `PRAGMA wal_checkpoint`; transitorio -> retentar).

    Pos-check (defesa-em-profundidade, NAO a barreira): Test-OpenCodeReviewerRoFallbackWarning
    varre stderr pelo warning de fallback silencioso (`agent "..." not found. Falling back to
    default agent`), que o opencode emite quando `--agent <ausente>` cai no `build` full-access.

    Claims empiricos medidos em opencode 1.4.4 (fixtures versionados em
    xpz-llm-delegate/fixtures/opencode-reviewer-ro/). Se um claim nao reproduzir na versao
    instalada, o pre-check (versao) ja bloqueia — NAO ativar sem revisitar D2/D3.
.NOTES
    Este arquivo so DEFINE funcoes (dot-source); nao executa nada ao ser carregado.
#>

Set-StrictMode -Version Latest

# Allow-set esperado do reviewer-ro (last-match-wins, excluindo `external_directory`).
$script:OpenCodeReviewerRoExpectedAllowSet = @('read', 'grep', 'glob', 'list')

# Denies nominais esperados no frontmatter (reforco documental; `*: deny` ja cobre).
$script:OpenCodeReviewerRoExpectedDeny = @('edit', 'bash', 'webfetch', 'websearch', 'task', 'external_directory')

function Get-OpenCodeReviewerRoFixtureDir {
    <# Resolve xpz-llm-delegate/fixtures/opencode-reviewer-ro relativo a este script. #>
    $candidate = Join-Path $PSScriptRoot '..\xpz-llm-delegate\fixtures\opencode-reviewer-ro'
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    return $null
}

function Get-OpenCodeReviewerRoTestedVersion {
    <# Versao do opencode contra a qual os fixtures/claims foram capturados (VERSION.txt). #>
    param([string] $FixtureDir)

    if (-not $FixtureDir) { $FixtureDir = Get-OpenCodeReviewerRoFixtureDir }
    if (-not $FixtureDir) { return $null }
    $vPath = Join-Path $FixtureDir 'VERSION.txt'
    if (-not (Test-Path -LiteralPath $vPath -PathType Leaf)) { return $null }
    return ((Get-Content -LiteralPath $vPath -Raw -Encoding utf8).Trim())
}

function ConvertFrom-Jsonc {
    <#
        Le um arquivo JSONC (JSON com comentarios) e devolve o objeto. Remove comentarios de linha
        (//...) e de bloco (/* ... */) FORA de strings, depois ConvertFrom-Json. Usado para ler o
        opencode.jsonc global. NAO preserva a formatacao (so leitura); a ESCRITA localizada que
        preserva comentarios vive no instalador.
    #>
    param([Parameter(Mandatory)] [string] $Raw)

    $sb = [System.Text.StringBuilder]::new($Raw.Length)
    $inString = $false
    $escape = $false
    $i = 0
    $n = $Raw.Length
    while ($i -lt $n) {
        $ch = $Raw[$i]
        if ($inString) {
            [void]$sb.Append($ch)
            if ($escape) { $escape = $false }
            elseif ($ch -eq '\') { $escape = $true }
            elseif ($ch -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($ch -eq '"') { $inString = $true; [void]$sb.Append($ch); $i++; continue }
        if ($ch -eq '/' -and $i + 1 -lt $n -and $Raw[$i + 1] -eq '/') {
            while ($i -lt $n -and $Raw[$i] -ne "`n") { $i++ }
            continue
        }
        if ($ch -eq '/' -and $i + 1 -lt $n -and $Raw[$i + 1] -eq '*') {
            $i += 2
            while ($i + 1 -lt $n -and -not ($Raw[$i] -eq '*' -and $Raw[$i + 1] -eq '/')) { $i++ }
            $i += 2
            continue
        }
        [void]$sb.Append($ch)
        $i++
    }
    return ($sb.ToString() | ConvertFrom-Json)
}

function Get-OpenCodeReviewerRoPermissionFromMarkdown {
    <#
        Parseia o frontmatter YAML de um .opencode/agent/reviewer-ro.md e devolve
        @{ mode = <str>; permission = @{ nome = 'allow'|'deny'|... } }. Parser de LINHAS (o
        frontmatter e simples: `key: value` e um bloco `permission:` indentado); nao depende de
        modulo YAML. Chaves podem vir com aspas ("*"). Devolve $null se nao houver frontmatter.
    #>
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }

    $mode = $null
    $perm = [ordered]@{}
    $inPermission = $false
    for ($idx = 1; $idx -lt $lines.Count; $idx++) {
        $line = $lines[$idx]
        if ($line.Trim() -eq '---') { break }

        # dentro do bloco permission: linhas indentadas `  key: value`
        if ($inPermission) {
            if ($line -match '^\s+("?)(?<k>[^":]+)\1\s*:\s*(?<v>\S+)\s*$') {
                $k = $Matches['k'].Trim().Trim('"')
                $perm[$k] = $Matches['v'].Trim()
                continue
            }
            # linha nao-indentada (ou vazia com conteudo top-level) encerra o bloco
            if ($line -match '^\S') { $inPermission = $false }
            else { continue }
        }

        if ($line -match '^\s*mode\s*:\s*(?<v>\S+)\s*$') { $mode = $Matches['v'].Trim(); continue }
        if ($line -match '^\s*permission\s*:\s*$') { $inPermission = $true; continue }
    }

    return @{ mode = $mode; permission = $perm }
}

function Get-OpenCodeReviewerRoPermissionFromJsonc {
    <#
        Le o bloco agent.reviewer-ro do opencode.jsonc global e devolve
        @{ mode; permission = @{...} }. Tolera a forma antiga `tools:` (interino) devolvendo
        tools em vez de permission (o chamador decide). Devolve $null se ausente.
    #>
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $obj = ConvertFrom-Jsonc -Raw $raw
    if ($null -eq $obj.PSObject.Properties['agent']) { return $null }
    $agent = $obj.agent
    if ($null -eq $agent.PSObject.Properties['reviewer-ro']) { return $null }
    $rro = $agent.'reviewer-ro'

    $mode = if ($rro.PSObject.Properties['mode']) { [string]$rro.mode } else { $null }
    $permission = [ordered]@{}
    $tools = [ordered]@{}
    if ($rro.PSObject.Properties['permission']) {
        foreach ($p in $rro.permission.PSObject.Properties) { $permission[$p.Name] = [string]$p.Value }
    }
    if ($rro.PSObject.Properties['tools']) {
        foreach ($p in $rro.tools.PSObject.Properties) { $tools[$p.Name] = $p.Value }
    }
    return @{ mode = $mode; permission = $permission; tools = $tools }
}

function Test-OpenCodeReviewerRoStatic {
    <#
        Check ESTATICO (barato/deterministico) da definicao do reviewer-ro. Prefere o project-local
        .opencode/agent/reviewer-ro.md relativo a -WorkingDirectory; se ausente, o bloco global do
        opencode.jsonc. Valida a forma `permission`: "*"=deny, read/grep/glob/list=allow,
        edit/bash/webfetch/websearch/task/external_directory=deny, mode=all.
        Devolve @{ ok = $bool; reason = <str>; source = <path/descricao> }.
    #>
    param(
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $GlobalJsoncPath
    )

    if (-not $GlobalJsoncPath) {
        $GlobalJsoncPath = Join-Path $env:USERPROFILE '.config\opencode\opencode.jsonc'
    }

    # Descoberta project-local: sobe a arvore de diretorios a partir do cwd procurando
    # .opencode/agent/reviewer-ro.md (mesma semantica do opencode, que descobre o project-local
    # subindo ate a raiz). Assim o static nao e fragil a subdiretorios do cwd.
    $projectLocal = $null
    $dir = $WorkingDirectory
    while (-not [string]::IsNullOrEmpty($dir)) {
        $candidate = Join-Path $dir '.opencode\agent\reviewer-ro.md'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $projectLocal = $candidate; break }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $def = $null
    $source = $null
    if ($projectLocal) {
        $def = Get-OpenCodeReviewerRoPermissionFromMarkdown -Path $projectLocal
        $source = $projectLocal
    }
    if ($null -eq $def) {
        $def = Get-OpenCodeReviewerRoPermissionFromJsonc -Path $GlobalJsoncPath
        $source = "global:$GlobalJsoncPath"
    }
    if ($null -eq $def) {
        return @{ ok = $false; reason = 'static'; source = $source
            detail = "definicao do reviewer-ro ausente (nem project-local .opencode/agent/reviewer-ro.md subindo de '$WorkingDirectory' nem global $GlobalJsoncPath). Rode scripts/Install-OpenCodeReviewerRoAgent.ps1 e/ou versione .opencode/agent/reviewer-ro.md." }
    }

    $perm = $def.permission
    if ($null -eq $perm -or $perm.Count -eq 0) {
        return @{ ok = $false; reason = 'static'; source = $source
            detail = "reviewer-ro sem bloco 'permission' (forma antiga 'tools:'? migre com o instalador). Fonte: $source." }
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    # `mode: all` e OBRIGATORIO (design D3: garante selecao por --agent em headless). Ausente
    # tambem e divergencia — nao basta "se presente, ser all".
    if ($def.mode -ne 'all') { $problems.Add("mode='$($def.mode)' (esperado 'all'; obrigatorio)") }

    $star = if ($perm.Contains('*')) { $perm['*'] } else { $null }
    if ($star -ne 'deny') { $problems.Add("'*'='$star' (esperado 'deny')") }

    foreach ($a in $script:OpenCodeReviewerRoExpectedAllowSet) {
        $v = if ($perm.Contains($a)) { $perm[$a] } else { $null }
        if ($v -ne 'allow') { $problems.Add("'$a'='$v' (esperado 'allow')") }
    }
    foreach ($d in $script:OpenCodeReviewerRoExpectedDeny) {
        $v = if ($perm.Contains($d)) { $perm[$d] } else { $null }
        if ($v -ne 'deny') { $problems.Add("'$d'='$v' (esperado 'deny')") }
    }

    if ($problems.Count -gt 0) {
        return @{ ok = $false; reason = 'static'; source = $source
            detail = "frontmatter do reviewer-ro divergente: $($problems -join '; '). Fonte: $source." }
    }
    return @{ ok = $true; reason = $null; source = $source; detail = 'frontmatter OK' }
}

function Get-OpenCodeReviewerRoBlockFromAgentList {
    <#
        Extrai o array JSON de regras do agente <Name> da saida textual de `opencode agent list`.
        A saida intercala varios agentes (cabecalho `nome (modo)` + array JSON pretty). Localiza o
        cabecalho e acumula linhas ate a profundidade de colchetes voltar a zero. Devolve o array de
        objetos (@{permission;action;pattern}) ou $null se o agente nao aparecer.
    #>
    param(
        [Parameter(Mandatory)] [string[]] $Lines,
        [string] $Name = 'reviewer-ro'
    )

    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ("^" + [regex]::Escape($Name) + "\s*\(")) { $start = $i; break }
    }
    if ($start -lt 0) { return $null }

    $buf = [System.Collections.Generic.List[string]]::new()
    $depth = 0
    $started = $false
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        $s = $Lines[$i]
        # novo cabecalho de agente antes de abrir o array => bloco vazio/inesperado
        if (-not $started -and $s -match '^\S.*\(.*\)\s*$') { break }
        $buf.Add($s)
        $open = ([regex]::Matches($s, '\[')).Count
        $close = ([regex]::Matches($s, '\]')).Count
        $depth += ($open - $close)
        if ($open -gt 0) { $started = $true }
        if ($started -and $depth -le 0) { break }
    }
    if (-not $started) { return $null }
    try {
        return ($buf -join "`n" | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Resolve-OpenCodeReviewerRoAllowSet {
    <#
        Reduz o array de regras a resolucao EFETIVA por last-match-wins e devolve
        @{ allowSet = @(nomes com allow, excl external_directory);
           externalDirStar = <acao efetiva de external_directory padrao '*'> }.
    #>
    param([Parameter(Mandatory)] $Rules)

    $eff = [ordered]@{}
    $extStar = $null
    foreach ($r in $Rules) {
        $p = [string]$r.permission
        $a = [string]$r.action
        if ($p -eq 'external_directory') {
            if ([string]$r.pattern -eq '*') { $extStar = $a }
            continue
        }
        $eff[$p] = $a
    }
    $allow = @($eff.Keys | Where-Object { $eff[$_] -eq 'allow' } | Sort-Object)
    return @{ allowSet = $allow; externalDirStar = $extStar; effective = $eff }
}

function Get-OpenCodeAgentListLines {
    <#
        Roda `opencode agent list` com RETRY CURTO (design D2 `:73`: "retry curto, senao BLOCK") para
        tolerar a falha transitoria de SQLite (`PRAGMA wal_checkpoint`) medida em campo. Retenta so
        em falha TRANSITORIA (exit!=0 ou excecao), com um sleep breve entre tentativas; exit 0 (mesmo
        que o bloco procurado nao apareca) NAO e transitorio e nao retenta. Devolve
        @{ ok; lines; error }. -Retries = tentativas EXTRAS (default 2 => ate 3 execucoes);
        -RetryDelayMs = pausa entre tentativas (0 nos self-tests).
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250
    )
    $attempts = [Math]::Max(1, $Retries + 1)
    $lastErr = $null
    for ($i = 1; $i -le $attempts; $i++) {
        $failed = $false
        $stdout = $null
        try {
            $prev = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            $stdout = & $Exe agent list 2>$null
            $code = $LASTEXITCODE
            $global:LASTEXITCODE = $prev
            if ($code -ne 0) {
                $failed = $true
                $lastErr = "'opencode agent list' saiu com codigo $code (INTERMITENTE — SQLite PRAGMA wal_checkpoint transitorio; tentativa $i/$attempts)."
            }
        } catch {
            $failed = $true
            $lastErr = "excecao ao rodar 'opencode agent list' (tentativa $i/$attempts): $($_.Exception.Message)"
        }
        if (-not $failed) { return @{ ok = $true; lines = @($stdout); error = $null } }
        if ($i -lt $attempts -and $RetryDelayMs -gt 0) { Start-Sleep -Milliseconds $RetryDelayMs }
    }
    return @{ ok = $false; lines = @(); error = $lastErr }
}

function Get-OpenCodeReviewerRoAllowSetFromExe {
    <#
        Roda `opencode agent list` (com retry curto) e devolve @{ ok; allowSet; externalDirStar;
        error }. ok=$false em qualquer falha (exit!=0 apos retries, excecao, agente ausente) — o
        chamador trata como BLOCK (transitorio-SQLite vs agente-ausente distinguidos na `error`).
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [string] $Name = 'reviewer-ro',
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250
    )

    $al = Get-OpenCodeAgentListLines -Exe $Exe -Retries $Retries -RetryDelayMs $RetryDelayMs
    if (-not $al.ok) {
        return @{ ok = $false; error = $al.error }
    }
    $rules = Get-OpenCodeReviewerRoBlockFromAgentList -Lines $al.lines -Name $Name
    if ($null -eq $rules) {
        return @{ ok = $false; error = "agente '$Name' nao encontrado / bloco ilegivel na saida de 'opencode agent list'." }
    }
    $resolved = Resolve-OpenCodeReviewerRoAllowSet -Rules $rules
    return @{ ok = $true; allowSet = $resolved.allowSet; externalDirStar = $resolved.externalDirStar; error = $null }
}

function Get-OpenCodeVersionFromExe {
    param([Parameter(Mandatory)] [string] $Exe)
    try {
        $prev = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
        $out = & $Exe --version 2>$null
        $global:LASTEXITCODE = $prev
        $v = ([string]($out | Select-Object -First 1)).Trim()
        if ([string]::IsNullOrWhiteSpace($v)) { return $null }
        return $v
    } catch {
        return $null
    }
}

function Test-OpenCodeReviewerRoPrecheck {
    <#
        Orquestra o pre-check fail-closed (D2). Devolve @{ pass = $bool; reason; detail }.
        A ORDEM prioriza o motivo mais barato/deterministico (static) e distingue transitorio
        (agentlist) de estrutural (static/allowset/version) no recibo.
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [string] $AgentName = 'reviewer-ro',
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $ExpectedVersion = (Get-OpenCodeReviewerRoTestedVersion),
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250
    )

    # 1) estatico
    $static = Test-OpenCodeReviewerRoStatic -WorkingDirectory $WorkingDirectory
    if (-not $static.ok) {
        return @{ pass = $false; reason = 'static'; detail = $static.detail }
    }

    # 2) versao (cláusula de validade dos claims empiricos)
    if ($ExpectedVersion) {
        $installed = Get-OpenCodeVersionFromExe -Exe $Exe
        if ([string]::IsNullOrWhiteSpace($installed)) {
            return @{ pass = $false; reason = 'version'
                detail = "nao foi possivel obter 'opencode --version' (fail-closed)." }
        }
        if ($installed -ne $ExpectedVersion) {
            return @{ pass = $false; reason = 'version'
                detail = "opencode $installed != versao testada dos fixtures ($ExpectedVersion). Os claims de resolucao podem nao valer; revisitar D2/D3 e re-capturar fixtures antes de ativar." }
        }
    }

    # 3) agent list -> allow-set exato + external_directory nao-allow
    $al = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $Exe -Name $AgentName -Retries $Retries -RetryDelayMs $RetryDelayMs
    if (-not $al.ok) {
        return @{ pass = $false; reason = 'agentlist'; detail = $al.error }
    }
    $expected = @($script:OpenCodeReviewerRoExpectedAllowSet | Sort-Object)
    $got = @($al.allowSet)
    $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $got
    if ($null -ne $diff) {
        return @{ pass = $false; reason = 'allowset'
            detail = "allow-set resolvido = {$($got -join ',')} != esperado {$($expected -join ',')}. Regra tardia da config global pode ter mudado a resolucao (ex.: bash reaparecendo)." }
    }
    if ($al.externalDirStar -eq 'allow') {
        return @{ pass = $false; reason = 'allowset'
            detail = "external_directory padrao '*' resolveu 'allow' — leitura NAO confinada ao cwd; confinamento quebrado." }
    }

    return @{ pass = $true; reason = $null
        detail = "reviewer-ro OK: allow-set {$($got -join ',')}, external_directory[*]='$($al.externalDirStar)'." }
}

function Test-OpenCodeAgentResolves {
    <#
        Opt-out check (D1, fold-in G2): quando o chamador passa -Agent <x> EXPLICITO (uso agentico
        fora do painel), o enforce read-only NAO se aplica, mas confirma-se que <x> RESOLVE (aparece
        em `opencode agent list`) — senao o opencode cairia SILENCIOSAMENTE no `build` full-access
        (`--agent <ausente>` nao falha). Devolve @{ ok = $bool; detail }.
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [Parameter(Mandatory)] [string] $Name,
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250
    )
    $al = Get-OpenCodeAgentListLines -Exe $Exe -Retries $Retries -RetryDelayMs $RetryDelayMs
    if (-not $al.ok) {
        return @{ ok = $false; detail = $al.error }
    }
    $rules = Get-OpenCodeReviewerRoBlockFromAgentList -Lines $al.lines -Name $Name
    if ($null -eq $rules) {
        return @{ ok = $false; detail = "agente '$Name' nao resolve em 'opencode agent list' — cairia no fallback silencioso ao 'build' full-access." }
    }
    return @{ ok = $true; detail = "agente '$Name' resolve." }
}

function Test-OpenCodeReviewerRoFallbackWarning {
    <#
        Pos-check (defesa-em-profundidade): $true se o texto contiver o warning de fallback
        silencioso do opencode (`agent "..." not found. Falling back to default agent`), sinal de
        que o `--agent` caiu no `build` full-access. Tolera codigos ANSI e o nome entre aspas.
    #>
    param([string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    return ($Text -match 'not found\. Falling back to default agent')
}
