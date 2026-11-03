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
      2. debug agents -> `opencode debug agents` confirma que o allow-set RESOLVIDO (last-match-wins,
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
      - 'agentlist'= `opencode debug agents` falhou/timeout/erro (INTERMITENTE — SQLite
                     `PRAGMA wal_checkpoint`; transitorio -> retentar).

    Pos-check (defesa-em-profundidade, NAO a barreira do spawn): Test-OpenCodeReviewerRoFallbackWarning
    reconhece no stdout apenas eventos JSONL `type=error` cuja mensagem comece por `Agent not found:`;
    no stderr, reconhece o aviso legado `agent "..." not found. Falling back to default agent`.
    Texto comum do modelo ou de ferramentas nao e tratado como fallback.

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

function Get-OpenCodeReviewerRoCanonicalEffectivePermission {
    # Bloco efetivo medido no `opencode debug agents` da 2.2.5. A ancora e o ultimo
    # `* / * / deny` e o sufixo abaixo e comparado na ordem. `shell` e `subagent` sao os
    # nomes efetivos das ferramentas `bash`/`task`; `browser` e `skill/browser` sao denies
    # nativos observados no mesmo sufixo. Nao emula paths/wildcards.
    return [ordered]@{
        '*' = 'deny'
        read = [ordered]@{ '*' = 'allow'; '*.env' = 'deny'; '*.env.*' = 'deny'; '.env.example' = 'allow'; '*/.env.example' = 'allow' }
        grep = 'deny'; glob = 'allow'; list = 'allow'; edit = 'deny'; bash = 'deny'
        webfetch = 'deny'; websearch = 'deny'; task = 'deny'; external_directory = 'deny'
        browser = 'deny'
        skill = [ordered]@{ browser = 'deny' }
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
    # Ancora no ULTIMO catch-all `* / * / deny`; valida o sufixo efetivo ordenado e
    # exige que ele termine exatamente no contrato medido. Qualquer regra adicional
    # depois do bloco bloqueia (reabertura/regra desconhecida). Regras antes da ancora
    # podem variar: a ancora existe justamente para isolar o sufixo efetivo.
    param([Parameter(Mandatory)] $Rules)
    $rows = @($Rules)
    $anchor = -1
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].permission -ceq '*' -and $rows[$i].pattern -ceq '*') { $anchor = $i }
    }
    if ($anchor -lt 0 -or $rows[$anchor].action -cne 'deny') { return @{ ok = $false; detail = 'catch-all final ausente/divergente' } }
    $canonical = Get-OpenCodeReviewerRoCanonicalEffectivePermission
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
    if ($offset -ne $rows.Count) {
        $r = $rows[$offset]
        return @{ ok = $false; detail = "regra efetiva adicional apos o bloco canonico: $($r.permission) / $($r.pattern) / $($r.action) na posicao $offset" }
    }
    return @{ ok = $true; detail = 'bloco efetivo canonico ordenado OK' }
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

function Get-OpenCodeDebugAgentsJson {
    <#
        Roda `opencode debug agents` com RETRY CURTO (design D2 `:73`: "retry curto, senao BLOCK")
        para tolerar a falha transitoria de SQLite (`PRAGMA wal_checkpoint`) medida em campo.
        Retenta SOMENTE quando o stderr capturado contiver a string `PRAGMA wal_checkpoint` (nao
        qualquer exit!=0 — outros erros sao terminais). O stderr e capturado em arquivo temporario
        e removido em finally. Devolve @{ ok; json; error }.
        -Retries = tentativas EXTRAS (default 2 => ate 3 execucoes);
        -RetryDelayMs = pausa entre tentativas (0 nos self-tests).
        -WorkingDirectory (opcional): pasta em que o `debug agents` roda — o opencode descobre o
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
    $lastErr = "falha desconhecida ao executar 'opencode debug agents'."
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        for ($i = 1; $i -le $attempts; $i++) {
            $failed = $false
            $stdout = $null
            $stderrText = ''
            try {
                $prev = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
                if ([string]::IsNullOrEmpty($WorkingDirectory)) {
                    $stdout = & $Exe debug agents 2>$stderrFile
                } else {
                    Push-Location -LiteralPath $WorkingDirectory
                    try { $stdout = & $Exe debug agents 2>$stderrFile }
                    finally { Pop-Location }
                }
                $code = $LASTEXITCODE
                $global:LASTEXITCODE = $prev
                if (Test-Path -LiteralPath $stderrFile) {
                    $rawStderr = Get-Content -LiteralPath $stderrFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                    if ($null -ne $rawStderr) { $stderrText = [string]$rawStderr }
                }
                if ($code -ne 0) {
                    if ($stderrText -match 'PRAGMA wal_checkpoint') {
                        $failed = $true
                        $lastErr = "'opencode debug agents' falhou com o marcador transitorio SQLite (PRAGMA wal_checkpoint; tentativa $i/$attempts)."
                    } else {
                        # Erro nao-transitorio: nao retentar e nao ecoar o stderr bruto.
                        return @{ ok = $false; json = $null; error = "'opencode debug agents' saiu com codigo $code (erro terminal; tentativa $i/$attempts)." }
                    }
                }
            } catch {
                $stderrText = ''
                if (Test-Path -LiteralPath $stderrFile) {
                    $rawStderr = Get-Content -LiteralPath $stderrFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                    if ($null -ne $rawStderr) { $stderrText = [string]$rawStderr }
                }
                if ($stderrText -match 'PRAGMA wal_checkpoint') {
                    $failed = $true
                    $lastErr = "excecao transitoria ao executar 'opencode debug agents' (PRAGMA wal_checkpoint; tentativa $i/$attempts)."
                } else {
                    return @{ ok = $false; json = $null; error = "excecao ao executar 'opencode debug agents' (tentativa $i/$attempts)." }
                }
            }
            if (-not $failed) { return @{ ok = $true; json = ($stdout -join "`n"); error = $null } }
            if ($i -lt $attempts -and $RetryDelayMs -gt 0) { Start-Sleep -Milliseconds $RetryDelayMs }
        }
    } finally {
        if (Test-Path -LiteralPath $stderrFile) { Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue }
    }
    return @{ ok = $false; json = $null; error = $lastErr }
}

function Get-OpenCodeReviewerRoBlockFromDebugAgents {
    <#
        Extrai o array de regras do agente <Name> do JSON devolvido por `opencode debug agents`.
        O JSON e um array de objetos com campos id, mode, permissions[]{action,resource,effect}.
        Converte cada permissao para o modelo interno {permission, action, pattern}:
          - permission = item.action  (tipo de ferramenta: read, glob, *, ...)
          - pattern    = item.resource (padrao de caminho: *, *.env, ...)
          - action     = item.effect   (resultado: allow, deny, ask)
        Devolve @{ rules = @(...); mode = <str> } ou $null se agente nao encontrado/JSON invalido.
    #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Json,
        [string] $Name = 'reviewer-ro'
    )
    if ([string]::IsNullOrWhiteSpace($Json)) { return $null }
    try {
        $agents = $Json | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($null -eq $agents) { return $null }
    $found = @()
    foreach ($a in @($agents)) {
        if ($null -eq $a) { continue }
        $idProp = $a.PSObject.Properties['id']
        if ($null -ne $idProp -and [string]$idProp.Value -ceq $Name) { $found += $a }
    }
    if ($found.Count -ne 1) { return $null }   # ausente ou ambiguo (duplicado) => bloqueia
    $agentObj = $found[0]
    $modeProp = $agentObj.PSObject.Properties['mode']
    if ($null -eq $modeProp) { return $null }
    $mode = [string]$modeProp.Value
    if ($mode -cnotin @('subagent', 'primary', 'all')) { return $null }
    $permProp = $agentObj.PSObject.Properties['permissions']
    if ($null -eq $permProp -or $null -eq $permProp.Value) { return $null }
    $actionMap = @{ 'shell' = 'bash'; 'subagent' = 'task' }
    $rules = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($p in @($permProp.Value)) {
        if ($null -eq $p) { return $null }
        $actionProp = $p.PSObject.Properties['action']
        $resourceProp = $p.PSObject.Properties['resource']
        $effectProp = $p.PSObject.Properties['effect']
        if ($null -eq $actionProp -or $null -eq $resourceProp -or $null -eq $effectProp) { return $null }
        $action = [string]$actionProp.Value
        $resource = [string]$resourceProp.Value
        $effect = [string]$effectProp.Value
        if ([string]::IsNullOrWhiteSpace($action) -or [string]::IsNullOrWhiteSpace($resource)) { return $null }
        if ($effect -cnotin @('allow', 'deny', 'ask')) { return $null }
        $permission = if ($actionMap.ContainsKey($action)) { [string]$actionMap[$action] } else { $action }
        $rules.Add([pscustomobject]@{
            permission = $permission
            pattern    = $resource
            action     = $effect
        })
    }
    return @{ rules = @($rules); mode = $mode }
}

function Get-OpenCodeReviewerRoAllowSetFromExe {
    <#
        Roda `opencode debug agents` (com retry curto) e devolve @{ ok; allowSet; externalDirStar;
        error }. ok=$false em qualquer falha (exit!=0 apos retries, excecao, agente ausente) — o
        chamador trata como BLOCK (transitorio-SQLite vs agente-ausente distinguidos na `error`).
        Exige mode=all para o reviewer-ro (modo obrigatorio do design).
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [string] $Name = 'reviewer-ro',
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250,
        [string] $WorkingDirectory
    )

    $da = Get-OpenCodeDebugAgentsJson -Exe $Exe -Retries $Retries -RetryDelayMs $RetryDelayMs -WorkingDirectory $WorkingDirectory
    if (-not $da.ok) {
        return @{ ok = $false; error = $da.error }
    }
    $block = Get-OpenCodeReviewerRoBlockFromDebugAgents -Json $da.json -Name $Name
    if ($null -eq $block) {
        return @{ ok = $false; error = "agente '$Name' nao encontrado / JSON invalido na saida de 'opencode debug agents'." }
    }
    if ($Name -eq 'reviewer-ro' -and $block.mode -cne 'all') {
        return @{ ok = $false; error = "agente '$Name' tem mode='$($block.mode)' — mode obrigatorio para reviewer-ro e 'all'." }
    }
    $resolved = Resolve-OpenCodeReviewerRoAllowSet -Rules $block.rules
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
        # A CLI 2.2.5 imprime "opencode v2.2.5"; VERSION.txt guarda a versao semantica
        # (2.2.5). Extrai o primeiro semver da linha, preservando sufixos de prerelease.
        if ($v -match '(?<semver>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)') { return [string]$Matches.semver }
        return $v
    } catch {
        return $null
    }
}

function Test-OpenCodeReviewerRoPrecheck {
    <#
        Orquestra o pre-check fail-closed (D2). Devolve @{ pass = $bool; reason; detail }.
        A ORDEM prioriza o motivo mais barato/deterministico (static) e distingue transitorio
        (agentlist, falha de `debug agents`) de estrutural (static/allowset/version) no recibo.
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

    # 3) debug agents -> allow-set exato + external_directory nao-allow
    $al = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $Exe -Name $AgentName -Retries $Retries -RetryDelayMs $RetryDelayMs -WorkingDirectory $WorkingDirectory
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
        em `opencode debug agents`) — senao o opencode cairia SILENCIOSAMENTE no `build` full-access
        (`--agent <ausente>` nao falha). Exige mode=primary ou mode=all (agente disponivel em run).
        Devolve @{ ok = $bool; detail }.
    #>
    param(
        [Parameter(Mandatory)] [string] $Exe,
        [Parameter(Mandatory)] [string] $Name,
        [int] $Retries = 2,
        [int] $RetryDelayMs = 250
    )
    $da = Get-OpenCodeDebugAgentsJson -Exe $Exe -Retries $Retries -RetryDelayMs $RetryDelayMs
    if (-not $da.ok) {
        return @{ ok = $false; detail = $da.error }
    }
    $block = Get-OpenCodeReviewerRoBlockFromDebugAgents -Json $da.json -Name $Name
    if ($null -eq $block) {
        return @{ ok = $false; detail = "agente '$Name' nao resolve em 'opencode debug agents' — cairia no fallback silencioso ao 'build' full-access." }
    }
    if ($block.mode -cne 'primary' -and $block.mode -cne 'all') {
        return @{ ok = $false; detail = "agente '$Name' tem mode='$($block.mode)' — apenas primary/all sao validos para uso em run." }
    }
    return @{ ok = $true; detail = "agente '$Name' resolve (mode=$($block.mode))." }
}

function Test-OpenCodeReviewerRoFallbackWarning {
    <#
        Pos-check (defesa-em-profundidade): inspeciona os canais separadamente. O stdout e JSONL;
        so um evento type=error com error.message iniciado por `Agent not found:` conta como fallback.
        O aviso legado e procurado apenas no stderr. Conteudo textual do modelo/ferramenta nao conta.
    #>
    [CmdletBinding()]
    param(
        [string[]] $StdoutLines = @(),
        [string] $StderrText = ''
    )
    if (-not [string]::IsNullOrEmpty($StderrText) -and $StderrText -match (Get-OpenCodeReviewerRoFallbackWarningPattern)) {
        return $true
    }
    foreach ($line in @($StdoutLines)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $event = ConvertFrom-Json -InputObject $line -ErrorAction Stop
        } catch {
            continue
        }
        if ($event -isnot [System.Management.Automation.PSCustomObject]) { continue }
        $typeProperty = $event.PSObject.Properties['type']
        $errorProperty = $event.PSObject.Properties['error']
        if ($null -eq $typeProperty -or $typeProperty.Value -cne 'error' -or $null -eq $errorProperty) { continue }
        $errorObject = $errorProperty.Value
        if ($errorObject -isnot [System.Management.Automation.PSCustomObject]) { continue }
        $messageProperty = $errorObject.PSObject.Properties['message']
        if ($null -eq $messageProperty -or $messageProperty.Value -isnot [string]) { continue }
        if ($messageProperty.Value.StartsWith('Agent not found:', [System.StringComparison]::Ordinal)) { return $true }
    }
    return $false
}

function Get-OpenCodeReviewerRoFallbackWarningPattern {
    <# Padrao exclusivo do aviso legado no stderr; o JSONL stdout e validado estruturalmente. #>
    return 'not found\. Falling back to default agent'
}
