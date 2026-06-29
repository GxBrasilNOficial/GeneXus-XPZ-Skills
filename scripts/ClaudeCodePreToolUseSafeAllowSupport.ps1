# ClaudeCodePreToolUseSafeAllowSupport.ps1 - logica pura do hook PreToolUse do CLAUDE CODE (auto-allow).
# Solucao especifica do Claude Code; nao se aplica a Codex/Cursor/OpenCode.
# Dot-source este arquivo para reusar as funcoes (decisor e self-test).
# Ver claude-code-pretooluse-auto-allow-design.md. NUNCA decide 'deny': so 'allow' ou 'defer'.
#
# Quirks de case: flags git diferem so por caixa (-c config = perigoso vs -C chdir = seguro);
# por isso a logica de git usa operadores case-sensitive (-ceq/-clike), nao -eq/-like.

Set-StrictMode -Version Latest

$script:PtuSafeAllowVersion = '1.0.0'

function Get-PtuRoots {
    $envRoots = [Environment]::GetEnvironmentVariable('PTU_SAFE_ALLOW_ROOTS')
    if (-not [string]::IsNullOrWhiteSpace($envRoots)) {
        $parts = @($envRoots -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($parts.Count -ge 1) { return $parts }
    }
    return @('C:\Dev\Knowledge\GeneXus-XPZ-Skills')
}

function Test-PtuCwdInScope {
    param([string] $Cwd, [string[]] $Roots)
    if ([string]::IsNullOrWhiteSpace($Cwd)) { return $false }
    $rootList = @($Roots)
    if ($rootList.Count -lt 1) { return $false }
    $c = $Cwd.Replace('/', '\').TrimEnd('\')
    foreach ($r in $rootList) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $rr = $r.Replace('/', '\').TrimEnd('\')
        if ($c.Equals($rr, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($c.StartsWith($rr + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-PtuGitSegmentAllowed {
    param([string[]] $Tokens)
    $t = @($Tokens)
    if ($t.Count -lt 2) { return $false }  # 'git' nu -> defer

    # Flags perigosas em qualquer posicao (injecao de config / programa externo / escrita).
    $danger = @('-c', '--exec-path', '--config-env', '--ext-diff', '--upload-pack', '--receive-pack', '--open-files-in-pager')
    foreach ($tok in $t) {
        foreach ($d in $danger) { if ($tok -ceq $d -or $tok -clike "$d=*") { return $false } }
        if ($tok -ceq '--output' -or $tok -clike '--output=*') { return $false }
        if ($tok -clike '-O*') { return $false }
    }

    # Localiza o subcomando, pulando opcoes globais. -C/--git-dir/--work-tree consomem o argumento.
    $i = 1
    while ($i -lt $t.Count) {
        $tok = $t[$i]
        if ($tok -ceq '-C' -or $tok -ceq '--git-dir' -or $tok -ceq '--work-tree') { $i += 2; continue }
        if ($tok.StartsWith('-')) { $i += 1; continue }
        break
    }
    if ($i -ge $t.Count) { return $false }  # sem subcomando

    $sub = $t[$i]
    $allowedSubs = @('status', 'log', 'show', 'diff', 'rev-parse', 'branch')
    if ($allowedSubs -cnotcontains $sub) { return $false }

    if ($sub -ceq 'branch') {
        $listFlags = @('--list', '-a', '--all', '-v', '-vv', '-r', '--show-current')
        for ($j = $i + 1; $j -lt $t.Count; $j++) {
            $tok = $t[$j]
            if ($tok.StartsWith('-')) {
                if ($listFlags -cnotcontains $tok) { return $false }
            }
            else {
                return $false  # posicional -> 'git branch <nome>' cria branch -> defer
            }
        }
    }
    return $true
}

function Test-PtuHeadTailAllowed {
    param([string[]] $Tokens)
    $t = @($Tokens)
    $bad = @('-f', '-F', '--follow', '--retry', '--pid')
    for ($j = 1; $j -lt $t.Count; $j++) {
        $tok = $t[$j]
        foreach ($b in $bad) { if ($tok -eq $b -or $tok -like "$b=*") { return $false } }
        if ($tok -like '--follow*') { return $false }
    }
    return $true
}

function Test-PtuRgAllowed {
    param([string[]] $Tokens)
    $t = @($Tokens)
    $bad = @('--pre', '--pre-glob', '--hostname-bin')
    for ($j = 1; $j -lt $t.Count; $j++) {
        $tok = $t[$j]
        foreach ($b in $bad) { if ($tok -eq $b -or $tok -like "$b=*") { return $false } }
    }
    return $true
}

function Test-PtuDateAllowed {
    param([string[]] $Tokens)
    $t = @($Tokens)
    for ($j = 1; $j -lt $t.Count; $j++) {
        $tok = $t[$j]
        if (-not $tok.StartsWith('-') -and -not $tok.StartsWith('+')) { return $false }  # set de relogio
    }
    return $true
}

function Test-PtuBashSegmentAllowed {
    param([string[]] $Tokens)
    $t = @($Tokens)
    if ($t.Count -lt 1) { return $false }
    $verb = $t[0]
    switch -CaseSensitive ($verb) {
        'git'  { return (Test-PtuGitSegmentAllowed $t) }
        'head' { return (Test-PtuHeadTailAllowed $t) }
        'tail' { return (Test-PtuHeadTailAllowed $t) }
        'rg'   { return (Test-PtuRgAllowed $t) }
        'date' { return (Test-PtuDateAllowed $t) }
        'cat'  { return $true }
        'wc'   { return $true }
        'ls'   { return $true }
        default { return $false }
    }
}

function Get-PtuBashFastPath {
    # Pre-filtro barato, in-process. Retorna 'defer' (decide na hora, sem parser) ou
    # 'escalate' (subir ao parser pesado/python). NUNCA retorna 'allow' (invariante do
    # design, secao 4.4): allow so vem do parser completo. Conservador: na duvida, defer.
    param([string] $Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return 'defer' }
    if ($Command.Contains("`n") -or $Command.Contains("`r")) { return 'defer' }  # multilinha
    $parts = @($Command.TrimStart() -split '\s+')
    if ($parts.Count -lt 1) { return 'defer' }
    $firstToken = $parts[0]
    if ([string]::IsNullOrEmpty($firstToken)) { return 'defer' }
    # Expansao/substituicao logo no primeiro token (ex.: $FOO, `cmd`) -> defer barato.
    if ($firstToken.Contains('$') -or $firstToken.Contains('`')) { return 'defer' }
    # O primeiro token do comando e o verbo do primeiro segmento. Se nao for um verbo
    # read-only conhecido, nenhum segmento-inicial pode ser allow -> defer sem python.
    $allowedLeading = @('git', 'head', 'tail', 'rg', 'date', 'cat', 'wc', 'ls')
    if ($allowedLeading -ccontains $firstToken) { return 'escalate' }
    return 'defer'
}

function Get-PtuSegmentsVerdict {
    # Veredito PURO a partir do objeto parsed do tokenizador ({status, segments}). Fonte unica
    # do veredito de segmentos (in-process E daemon). Contrato ESTRITO sob StrictMode: segments =
    # array NAO-VAZIO de arrays NAO-VAZIOS de strings. Rejeita string escalar como segmento (em PS
    # string e' IEnumerable<char> e passaria por engano). Qualquer violacao -> 'defer' (fail-closed).
    # NAO e' 2o ponto de despacho: escopo/ferramenta/shape ficam em Get-PtuDecision.
    param($Parsed)
    if ($null -eq $Parsed) { return 'defer' }
    if (-not ($Parsed.PSObject.Properties.Name -contains 'status')) { return 'defer' }
    if ($Parsed.status -ne 'ok') { return 'defer' }
    if (-not ($Parsed.PSObject.Properties.Name -contains 'segments')) { return 'defer' }
    $segments = $Parsed.segments
    if ($null -eq $segments -or $segments -is [string]) { return 'defer' }
    if (-not ($segments -is [System.Collections.IEnumerable])) { return 'defer' }
    $segList = @($segments)
    if ($segList.Count -lt 1) { return 'defer' }
    foreach ($seg in $segList) {
        if ($null -eq $seg -or $seg -is [string]) { return 'defer' }  # segmento NAO e' string escalar
        if (-not ($seg -is [System.Collections.IEnumerable])) { return 'defer' }
        $tokens = @($seg)
        if ($tokens.Count -lt 1) { return 'defer' }
        foreach ($tok in $tokens) { if ($tok -isnot [string]) { return 'defer' } }
        if (-not (Test-PtuBashSegmentAllowed $tokens)) { return 'defer' }
    }
    return 'allow'
}

function Invoke-PtuOneShotTokenizer {
    # Tokenizador IN-PROCESS (default): spawn one-shot do python helper (Get-ClaudeCodeBashSafeSegments.py).
    # Retorna o objeto parsed {status, segments} ou $null em qualquer falha (o chamador trata como defer).
    param([string] $Command, [string] $PythonExe, [string] $HelperPath)
    if ([string]::IsNullOrWhiteSpace($PythonExe) -or -not (Test-Path -LiteralPath $PythonExe)) { return $null }
    if ([string]::IsNullOrWhiteSpace($HelperPath) -or -not (Test-Path -LiteralPath $HelperPath)) { return $null }
    try { $json = $Command | & $PythonExe $HelperPath 2>$null } catch { return $null }
    if ($LASTEXITCODE -ne 0) { return $null }
    if ([string]::IsNullOrWhiteSpace($json)) { return $null }
    try { return ($json | ConvertFrom-Json) } catch { return $null }
}

function Get-PtuBashDecision {
    # Fast-path -> tokenizacao -> Get-PtuSegmentsVerdict. A tokenizacao e' INJETAVEL (-Tokenizer):
    # sem -Tokenizer = one-shot in-process (comportamento atual, assinatura preservada); com -Tokenizer
    # (caminho DAEMON) = round-trip ao python persistente que roda a MESMA classify (fonte unica).
    # -Decompose devolve os SEGMENTOS (objeto parsed) em vez do veredito, para o gate de transporte.
    param(
        [string] $Command,
        [string] $PythonExe,
        [string] $HelperPath,
        [scriptblock] $Tokenizer,
        [switch] $Decompose
    )
    if ([string]::IsNullOrWhiteSpace($Command)) { if ($Decompose) { return $null } return 'defer' }
    if ($Decompose) {
        # Modo de decomposicao: expoe os SEGMENTOS crus do tokenizador (sem fast-path nem veredito).
        if ($Tokenizer) { try { return (& $Tokenizer $Command) } catch { return $null } }
        return (Invoke-PtuOneShotTokenizer -Command $Command -PythonExe $PythonExe -HelperPath $HelperPath)
    }
    if ((Get-PtuBashFastPath -Command $Command) -eq 'defer') { return 'defer' }  # caminho comum: sem python
    if ($Tokenizer) {
        try { $parsed = & $Tokenizer $Command } catch { $parsed = $null }
    }
    else {
        $parsed = Invoke-PtuOneShotTokenizer -Command $Command -PythonExe $PythonExe -HelperPath $HelperPath
    }
    return (Get-PtuSegmentsVerdict $parsed)
}

function Get-PtuPowerShellDecision {
    param([string] $Command)
    # Fase 0: o campo de input PowerShell nao e documentado; ate confirmar -> defer (fail-closed).
    # O classificador via AST nativo entra na Fase 5 (ver design, secao 3/5).
    return 'defer'
}

function Get-PtuDecision {
    # Despacho TOP-LEVEL e fonte unica da decisao: escopo (Test-PtuCwdInScope), ferramenta (switch),
    # shape invalido -> defer. -Tokenizer OPCIONAL e' repassado ao caminho Bash: ausente = one-shot
    # in-process (comportamento atual); presente = round-trip ao python persistente do daemon.
    param(
        [string] $ToolName,
        [string] $Command,
        [string] $Cwd,
        [string[]] $Roots,
        [string] $PythonExe,
        [string] $HelperPath,
        [scriptblock] $Tokenizer
    )
    try {
        if (-not (Test-PtuCwdInScope -Cwd $Cwd -Roots $Roots)) { return 'defer' }
        switch -CaseSensitive ($ToolName) {
            'Bash'       { return (Get-PtuBashDecision -Command $Command -PythonExe $PythonExe -HelperPath $HelperPath -Tokenizer $Tokenizer) }
            'PowerShell' { return (Get-PtuPowerShellDecision -Command $Command) }
            default      { return 'defer' }
        }
    }
    catch { return 'defer' }
}
