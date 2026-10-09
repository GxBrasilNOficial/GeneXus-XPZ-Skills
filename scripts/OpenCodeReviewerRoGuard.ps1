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
                       excluindo `external_directory`) e EXATAMENTE {read,glob,list}, com mapa
                       read canonico e grep deny, e que
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

    Pos-check (defesa-em-profundidade, NAO a barreira do spawn): Test-OpenCodeReviewerRoFallbackWarning
    varre stderr pelo warning generico de fallback silencioso (`agent "..." not found. Falling back to
    default agent`), que o opencode emite quando `--agent <ausente>` cai no agente default.

    Claims empiricos medidos na versao em
    xpz-llm-delegate/fixtures/opencode-reviewer-ro/VERSION.txt. Se um claim nao reproduzir na
    versao instalada, o pre-check (versao) ja bloqueia — NAO ativar sem revisitar D2/D3.
.NOTES
    Este arquivo so DEFINE funcoes (dot-source); nao executa nada ao ser carregado.
#>

Set-StrictMode -Version Latest

# Allow-set esperado do reviewer-ro (last-match-wins, excluindo `external_directory`).
$script:OpenCodeReviewerRoExpectedAllowSet = @('read', 'glob', 'list')

# Denies nominais esperados no frontmatter (reforco documental; `*: deny` ja cobre).
$script:OpenCodeReviewerRoExpectedDeny = @('grep', 'edit', 'bash', 'webfetch', 'websearch', 'task', 'external_directory')

function Get-OpenCodeReviewerRoCanonicalPermission {
    # Ordem faz parte do contrato; nao emula paths/wildcards do CLI.
    return [ordered]@{
        '*' = 'deny'
        read = [ordered]@{ '*' = 'allow'; '*.env' = 'deny'; '*.env.*' = 'deny'; '.env.example' = 'allow'; '*/.env.example' = 'allow' }
        grep = 'deny'; glob = 'allow'; list = 'allow'; edit = 'deny'; bash = 'deny'
        webfetch = 'deny'; websearch = 'deny'; task = 'deny'; external_directory = 'deny'
    }
}

function Test-OpenCodeReviewerRoDefinition {
    <# Acumula TODAS as divergencias (nao para na primeira) para o diagnostico mostrar o reparo
       inteiro; qualquer divergencia mantem ok=$false (fail-closed inalterado). Devolve
       @{ ok; detail = divergencias unidas por '; '; divergences = @(...) }. #>
    param($Definition)
    # Descreve o valor encontrado sem ecoar texto arbitrario do arquivo: so as acoes conhecidas
    # aparecem literalmente; qualquer outra coisa vira 'outro valor'/'mapa'.
    function Format-ReviewerRoFoundAction($Value) {
        if ($Value -is [string] -and @('allow', 'deny', 'ask') -ccontains $Value) { return "'$Value'" }
        if ($Value -is [System.Collections.IDictionary]) { return 'mapa' }
        return 'outro valor'
    }
    $div = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $Definition) {
        return @{ ok = $false; detail = 'mode obrigatorio: all / definicao invalida'; divergences = @('mode obrigatorio: all / definicao invalida') }
    }
    if ($Definition.mode -cne 'all') { $div.Add('mode obrigatorio: all / definicao invalida') }
    $want = Get-OpenCodeReviewerRoCanonicalPermission
    $got = $Definition.permission
    if ($got -isnot [System.Collections.IDictionary]) {
        $div.Add('permission: ausente ou nao e mapa')
    } else {
        $gotKeys = @($got.Keys)
        if (($gotKeys -join "`n") -cne (@($want.Keys) -join "`n")) {
            $missing = @($want.Keys | Where-Object { $gotKeys -cnotcontains $_ })
            $extra = @($gotKeys | Where-Object { @($want.Keys) -cnotcontains $_ })
            $msg = 'permission: chaves/ordem divergentes do contrato canonico'
            if ($missing.Count -gt 0) { $msg += " (ausentes: $($missing -join ','))" }
            if ($extra.Count -gt 0) { $msg += " (extras: $($extra -join ','))" }
            $div.Add($msg)
        }
        foreach ($key in $want.Keys) {
            if (-not $got.Contains($key)) { continue }
            if ($want[$key] -is [System.Collections.IDictionary]) {
                $map = $got[$key]
                if ($map -isnot [System.Collections.IDictionary]) {
                    $div.Add("mapa ${key}: chaves/ordem divergentes (esperado mapa, encontrado escalar $(Format-ReviewerRoFoundAction $map))")
                    continue
                }
                if ((@($map.Keys) -join "`n") -cne (@($want[$key].Keys) -join "`n")) {
                    $div.Add("mapa ${key}: chaves/ordem divergentes")
                }
                foreach ($pattern in $want[$key].Keys) {
                    if (-not $map.Contains($pattern)) { continue }
                    if ($map[$pattern] -isnot [string] -or $map[$pattern] -cne $want[$key][$pattern]) {
                        $div.Add("mapa ${key}: acao divergente para $pattern (encontrado $(Format-ReviewerRoFoundAction $map[$pattern]), esperado '$($want[$key][$pattern])')")
                    }
                }
            } elseif ($got[$key] -isnot [string] -or $got[$key] -cne $want[$key]) {
                $div.Add("permission ${key}: acao divergente (encontrado $(Format-ReviewerRoFoundAction $got[$key]), esperado '$($want[$key])')")
            }
        }
    }
    if ($div.Count -gt 0) { return @{ ok = $false; detail = ($div -join '; '); divergences = @($div) } }
    return @{ ok = $true; detail = 'definicao canonica OK'; divergences = @() }
}

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
        Exige raiz OBJETO (o opencode.jsonc e um objeto): lista, escalar ou null lancam. Sem isso,
        ConvertFrom-Json desembrulha `[{...}]` no objeto interno e `$obj.agent` acharia o agent
        dentro da lista, aprovando (e o instalador gravando) configuracao invalida.
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
            if ($i + 1 -ge $n) { throw 'JSONC: comentario de bloco nao fechado' }
            [void]$sb.Append(' ')
            $i += 2
            continue
        }
        [void]$sb.Append($ch)
        $i++
    }
    # JsonDocument enumera duplicatas que ConvertFrom-Json sobrescreveria silenciosamente.
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $true
    $doc = [System.Text.Json.JsonDocument]::Parse($sb.ToString(), $options)
    function Assert-UniqueJsonKeys($Element) {
        if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($prop in $Element.EnumerateObject()) {
                if (-not $seen.Add($prop.Name)) { throw "JSONC: chave duplicada/ambigua '$($prop.Name)'" }
                Assert-UniqueJsonKeys $prop.Value
            }
        } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
            foreach ($item in $Element.EnumerateArray()) { Assert-UniqueJsonKeys $item }
        }
    }
    try {
        if ($doc.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw "JSONC: raiz nao e objeto ($($doc.RootElement.ValueKind))"
        }
        Assert-UniqueJsonKeys $doc.RootElement
    } finally { $doc.Dispose() }
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
    $top = [ordered]@{}
    $section = ''
    $mapKey = $null
    $closed = $false
    for ($idx = 1; $idx -lt $lines.Count; $idx++) {
        $line = $lines[$idx]
        if ($line -ceq '---') { $closed = $true; break }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Contains("`t")) { throw 'Markdown: tab/indentacao invalida' }
        if ($line -cmatch '^(?<k>[a-z_]+):\s*(?<v>.*)$') {
            $section = $Matches.k; $value = $Matches.v
            if ($top.Contains($section)) { throw "Markdown: chave duplicada $section" }
            $top[$section] = $value
            if ($section -eq 'mode') { $mode = $value }
            elseif ($section -eq 'permission' -and $value -ne '') { throw 'Markdown: permission deve ser mapa' }
            elseif ($section -notin @('description', 'mode', 'permission')) { throw "Markdown: chave fora do parser restrito $section" }
            $mapKey = $null
            continue
        }
        if ($section -eq 'description' -and $top['description'] -in @('>-', '>', '|', '|-') -and $line -match '^  \S') { continue }
        if ($section -ne 'permission' -or $line -cnotmatch '^(?<indent> {2}| {4})(?<token>"[^"\r\n]+"|''[^''\r\n]+''|[a-z_]+):\s*(?<v>allow|deny|ask)?\s*$') {
            throw "Markdown: linha invalida/ambigua ou profundidade nao suportada ($($idx + 1))"
        }
        $indent = $Matches.indent.Length
        $key = $Matches.token.Trim('"', "'")
        $value = $Matches['v']
        if ($indent -eq 2) {
            if ($perm.Contains($key)) { throw "Markdown: permission duplicada $key" }
            $mapKey = $null
            if ([string]::IsNullOrEmpty($value)) { $perm[$key] = [ordered]@{}; $mapKey = $key }
            else { $perm[$key] = $value }
        } else {
            if ($null -eq $mapKey -or [string]::IsNullOrEmpty($value)) { throw 'Markdown: mapa/acao invalida' }
            if ($perm[$mapKey].Contains($key)) { throw "Markdown: padrao duplicado $key" }
            $perm[$mapKey][$key] = $value
        }
    }
    if (-not $closed) { throw 'Markdown: frontmatter nao fechado' }
    return @{ mode = $mode; permission = $perm }
}

function Get-OpenCodeReviewerRoPermissionFromJsonc {
    <#
        Le o bloco agent.reviewer-ro do opencode.jsonc global e devolve
        @{ mode; permission = @{...} }, preservando mapas e ordem. Rejeita a forma antiga
        `tools:` (interino); migre pelo instalador. Devolve $null se ausente.
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
    if ($rro.PSObject.Properties['tools']) { throw 'JSONC: tools ambiguo com contrato permission; migre pelo instalador' }

    $mode = if ($rro.PSObject.Properties['mode']) { [string]$rro.mode } else { $null }
    $permission = [ordered]@{}
    $tools = [ordered]@{}
    if ($rro.PSObject.Properties['permission']) {
        foreach ($p in $rro.permission.PSObject.Properties) {
            if ($p.Value -is [pscustomobject]) {
                $map = [ordered]@{}
                foreach ($child in $p.Value.PSObject.Properties) { $map[$child.Name] = $child.Value }
                $permission[$p.Name] = $map
            } else { $permission[$p.Name] = $p.Value }
        }
    }
    if ($rro.PSObject.Properties['tools']) {
        foreach ($p in $rro.tools.PSObject.Properties) { $tools[$p.Name] = $p.Value }
    }
    return @{ mode = $mode; permission = $permission; tools = $tools }
}

function Test-OpenCodeReviewerRoJsoncEditable {
    <#
        Pre-checagem da edicao LOCALIZADA do instalador (Install-OpenCodeReviewerRoAgent.ps1), exposta
        aqui para a auditoria de setup usar a MESMA regra: o que esta funcao recusa, o instalador
        recusa. O localizador e propositalmente restrito: recusa JSONC que nao parseia ou cuja raiz
        nao e objeto, chave
        aparente/homonima/escapada `agent`/`reviewer-ro` e comentario com chaves, sem motor JSONC geral.
        Conteudo vazio/so espaco e editavel (o instalador cria o minimo).
        Devolve @{ ok = $bool; detail = <str> }; o detail nunca contem o conteudo do arquivo.
    #>
    param([AllowEmptyString()] [string] $Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return @{ ok = $true; detail = 'vazio: criacao minima' } }
    try { $existing = ConvertFrom-Jsonc -Raw $Raw }
    catch { return @{ ok = $false; detail = "JSONC invalido: $($_.Exception.Message)" } }
    foreach ($key in @('agent', 'reviewer-ro')) {
        $count = ([regex]::Matches($Raw, ('"' + [regex]::Escape($key) + '"\s*:'))).Count
        $expectedCount = 0
        if ($key -eq 'agent' -and $existing.PSObject.Properties['agent']) { $expectedCount = 1 }
        if ($key -eq 'reviewer-ro' -and $existing.PSObject.Properties['agent'] -and $existing.agent.PSObject.Properties['reviewer-ro']) { $expectedCount = 1 }
        if ($count -ne $expectedCount) { return @{ ok = $false; detail = "chave aparente/homonima/escapada '$key'; localizacao ambigua." } }
    }
    if ($Raw -match '(?s)/\*(?:(?!\*/).)*[{}](?:(?!\*/).)*\*/|(?m)//[^\r\n]*[{}]') { return @{ ok = $false; detail = 'comentario com chaves; localizacao ambigua.' } }
    return @{ ok = $true; detail = 'editavel pelo instalador' }
}

function Test-OpenCodeReviewerRoStatic {
    <#
        Check ESTATICO (barato/deterministico) da definicao do reviewer-ro. Prefere o project-local
        .opencode/agent/reviewer-ro.md relativo a -WorkingDirectory; se ausente, o bloco global do
        opencode.jsonc. Valida a forma canonica: "*"=deny, read=mapa, glob/list=allow, grep=deny,
        edit/bash/webfetch/websearch/task/external_directory=deny, mode=all.
        Devolve @{ ok = $bool; reason = <str>; source = <path/descricao>; detail = <str> } e, quando a
        definicao foi lida e comparada, `divergences` (lista completa; vazia se canonica).
        -GlobalOnly pula a descoberta project-local e le so o bloco global (auditoria de setup: a
        instalacao global e o alvo, independentemente do cwd). Os adapters NAO usam -GlobalOnly.
    #>
    param(
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $GlobalJsoncPath,
        [switch] $GlobalOnly
    )

    if (-not $GlobalJsoncPath) {
        $GlobalJsoncPath = Join-Path $env:USERPROFILE '.config\opencode\opencode.jsonc'
    }

    # Descoberta project-local: sobe a arvore de diretorios a partir do cwd procurando
    # .opencode/agent/reviewer-ro.md (mesma semantica do opencode, que descobre o project-local
    # subindo ate a raiz). Assim o static nao e fragil a subdiretorios do cwd.
    $projectLocal = $null
    $dir = if ($GlobalOnly) { $null } else { $WorkingDirectory }
    while (-not [string]::IsNullOrEmpty($dir)) {
        $candidate = Join-Path $dir '.opencode\agent\reviewer-ro.md'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $projectLocal = $candidate; break }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $def = $null
    $source = $null
    try {
    if ($projectLocal) {
        $source = $projectLocal
        $def = Get-OpenCodeReviewerRoPermissionFromMarkdown -Path $projectLocal
    }
    else {
        $source = "global:$GlobalJsoncPath"
        $def = Get-OpenCodeReviewerRoPermissionFromJsonc -Path $GlobalJsoncPath
    }
    } catch {
        return @{ ok = $false; reason = 'static'; source = $source; detail = "definicao invalida: $($_.Exception.Message)" }
    }
    if ($null -eq $def) {
        if ($projectLocal) { return @{ ok = $false; reason = 'static'; source = $source; detail = 'definicao local encontrada invalida; sem fallback global' } }
        return @{ ok = $false; reason = 'static'; source = $source
            detail = "definicao do reviewer-ro ausente (nem project-local .opencode/agent/reviewer-ro.md subindo de '$WorkingDirectory' nem global $GlobalJsoncPath). Rode scripts/Install-OpenCodeReviewerRoAgent.ps1 e/ou versione .opencode/agent/reviewer-ro.md." }
    }

    $perm = $def.permission
    if ($null -eq $perm -or $perm.Count -eq 0) {
        return @{ ok = $false; reason = 'static'; source = $source
            detail = "reviewer-ro sem bloco 'permission' (forma antiga 'tools:'? migre com o instalador). Fonte: $source." }
    }

    $validation = Test-OpenCodeReviewerRoDefinition -Definition $def
    if (-not $validation.ok) {
        return @{ ok = $false; reason = 'static'; source = $source; detail = $validation.detail; divergences = $validation.divergences }
    }
    return @{ ok = $true; reason = $null; source = $source; detail = $validation.detail; divergences = @() }
}

function Test-OpenCodeReviewerRoEffectiveRules {
    # Ancora no catch-all final; todo o sufixo deve ter a forma canonica medida.
    param([Parameter(Mandatory)] $Rules)
    $rows = @($Rules)
    $anchor = -1
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].permission -ceq '*' -and $rows[$i].pattern -ceq '*') { $anchor = $i }
    }
    if ($anchor -lt 0 -or $rows[$anchor].action -cne 'deny') { return @{ ok = $false; detail = 'catch-all final ausente/divergente' } }
    $canonical = Get-OpenCodeReviewerRoCanonicalPermission
    $offset = $anchor
    foreach ($key in $canonical.Keys) {
        $patterns = [ordered]@{ '*' = $canonical[$key] }
        if ($canonical[$key] -is [System.Collections.IDictionary]) { $patterns = $canonical[$key] }
        foreach ($pattern in $patterns.Keys) {
            if ($offset -ge $rows.Count -or $rows[$offset].permission -cne $key -or $rows[$offset].pattern -cne $pattern -or $rows[$offset].action -cne $patterns[$pattern]) {
                return @{ ok = $false; detail = "bloco efetivo divergente: esperado $key / $pattern / $($patterns[$pattern]) na posicao $offset" }
            }
            $offset++
        }
    }
    # Unica excecao tardia medida: tool-output interno. Deve coincidir com a regra
    # nativa ANTERIOR a ancora e com o diretorio interno conhecido; nao ampliar allows.
    for ($i = $offset; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]
        $native = @($rows | Select-Object -First $anchor | Where-Object {
            $_.permission -ceq 'external_directory' -and $_.action -ceq 'allow' -and $_.pattern -ceq $r.pattern
        })
        if ($r.permission -cne 'external_directory' -or $r.action -cne 'allow' -or $native.Count -eq 0 -or
            $r.pattern -notmatch '(?:^<SANITIZED_OPENCODE_TOOL_OUTPUT_DIR>|[\\/]opencode[\\/]tool-output)[\\/]\*$') {
            return @{ ok = $false; detail = "regra tardia fora do contrato: $($r.permission) / $($r.pattern) / $($r.action)" }
        }
    }
    return @{ ok = $true; detail = 'bloco efetivo canonico e excecoes internas OK' }
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
    $readRules = @($Rules | Where-Object { $_.permission -ceq 'read' })
    foreach ($r in $Rules) {
        $p = [string]$r.permission
        $a = [string]$r.action
        if ($p -eq 'external_directory') {
            if ([string]$r.pattern -eq '*') { $extStar = $a }
            continue
        }
        if ($p -cne 'read') { $eff[$p] = $a }
    }
    # Read e mapa, nunca a acao da ultima excecao. So o bloco estrutural canonico
    # pode promovê-lo ao conjunto de ferramentas disponiveis.
    $policy = Test-OpenCodeReviewerRoEffectiveRules -Rules $Rules
    if ($policy.ok) { $eff['read'] = 'allow' }
    $allow = @($eff.Keys | Where-Object { $eff[$_] -eq 'allow' } | Sort-Object)
    return @{ allowSet = $allow; externalDirStar = $extStar; effective = $eff; readRules = $readRules; policyOk = $policy.ok; policyDetail = $policy.detail }
}

function Get-OpenCodeAgentListLines {
    <#
        Roda `opencode agent list` com RETRY CURTO (design D2 `:73`: "retry curto, senao BLOCK") para
        tolerar a falha transitoria de SQLite (`PRAGMA wal_checkpoint`) medida em campo. Retenta so
        em falha TRANSITORIA (exit!=0 ou excecao), com um sleep breve entre tentativas; exit 0 (mesmo
        que o bloco procurado nao apareca) NAO e transitorio e nao retenta. Devolve
        @{ ok; lines; error }. -Retries = tentativas EXTRAS (default 2 => ate 3 execucoes);
        -RetryDelayMs = pausa entre tentativas (0 nos self-tests).
        -WorkingDirectory (opcional): pasta em que o `agent list` roda — o opencode descobre o
        project-local a partir dela. Sem o parametro, roda na pasta atual (comportamento dos adapters).
        A pasta original e restaurada em try/finally, mesmo com erro.
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250,
        [string] $WorkingDirectory
    )
    $attempts = [Math]::Max(1, $Retries + 1)
    $lastErr = $null
    for ($i = 1; $i -le $attempts; $i++) {
        $failed = $false
        $stdout = $null
        try {
            $prev = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            if ([string]::IsNullOrEmpty($WorkingDirectory)) {
                $stdout = & $Exe agent list 2>$null
            } else {
                Push-Location -LiteralPath $WorkingDirectory
                try { $stdout = & $Exe agent list 2>$null }
                finally { Pop-Location }
            }
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
        [int] $RetryDelayMs = 250,
        [string] $WorkingDirectory
    )

    $al = Get-OpenCodeAgentListLines -Exe $Exe -Retries $Retries -RetryDelayMs $RetryDelayMs -WorkingDirectory $WorkingDirectory
    if (-not $al.ok) {
        return @{ ok = $false; error = $al.error }
    }
    $rules = Get-OpenCodeReviewerRoBlockFromAgentList -Lines $al.lines -Name $Name
    if ($null -eq $rules) {
        return @{ ok = $false; error = "agente '$Name' nao encontrado / bloco ilegivel na saida de 'opencode agent list'." }
    }
    $resolved = Resolve-OpenCodeReviewerRoAllowSet -Rules $rules
    return @{ ok = $true; allowSet = $resolved.allowSet; externalDirStar = $resolved.externalDirStar; policyOk = $resolved.policyOk; policyDetail = $resolved.policyDetail; error = $null }
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

    # 2) versao (cláusula de validade dos claims empiricos). FAIL-CLOSED TOTAL: se a versao esperada
    #    nao pode ser determinada (VERSION.txt do fixture ausente/vazio/inacessivel), NAO despachar —
    #    nao ha como validar a clausula de validade. String vazia e falsy em PS; um `if ($ExpectedVersion)`
    #    puro PULARIA o check silenciosamente (fail-OPEN) — proibido pelo design D2.
    if ([string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        return @{ pass = $false; reason = 'version'
            detail = "versao esperada ausente (VERSION.txt do fixture nao encontrado/vazio) — nao e possivel validar a clausula de validade; fail-closed." }
    }
    $installed = Get-OpenCodeVersionFromExe -Exe $Exe
    if ([string]::IsNullOrWhiteSpace($installed)) {
        return @{ pass = $false; reason = 'version'
            detail = "nao foi possivel obter 'opencode --version' (fail-closed)." }
    }
    if ($installed -ne $ExpectedVersion) {
        return @{ pass = $false; reason = 'version'
            detail = "opencode $installed != versao testada dos fixtures ($ExpectedVersion). Os claims de resolucao podem nao valer; antes de desistir, rode scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson para diagnostico estrutural. Se a estrutura estiver OK, re-capture os fixtures empiricos do reviewer-ro para esta versao antes de ativar." }
    }

    # 3) agent list -> allow-set exato + external_directory nao-allow
    $al = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $Exe -Name $AgentName -Retries $Retries -RetryDelayMs $RetryDelayMs
    if (-not $al.ok) {
        return @{ pass = $false; reason = 'agentlist'; detail = $al.error }
    }
    if (-not $al.policyOk) {
        return @{ pass = $false; reason = 'allowset'; detail = $al.policyDetail }
    }
    $expected = @($script:OpenCodeReviewerRoExpectedAllowSet | Sort-Object)
    $got = @($al.allowSet)
    $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $got
    if ($null -ne $diff) {
        return @{ pass = $false; reason = 'allowset'
            detail = "allow-set resolvido = {$($got -join ',')} != esperado {$($expected -join ',')}. Regra tardia da config global pode ter mudado a resolucao (ex.: bash reaparecendo)." }
    }
    if ($al.externalDirStar -ne 'deny') {
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
        Pos-check (defesa-em-profundidade): $true se o texto contiver o warning generico de
        fallback silencioso do opencode (`agent "..." not found. Falling back to default agent`),
        sinal de que o `--agent` caiu no agente default. O padrao logico e exposto por
        Get-OpenCodeReviewerRoFallbackWarningPattern.
    #>
    param([string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    return ($Text -match (Get-OpenCodeReviewerRoFallbackWarningPattern))
}

function Get-OpenCodeReviewerRoFallbackWarningPattern {
    <# Padrao logico unico do warning de fallback silencioso emitido pelo opencode. #>
    return 'not found\. Falling back to default agent'
}
