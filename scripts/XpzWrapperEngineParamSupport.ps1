#requires -Version 7.4
<#
.SYNOPSIS
  Suporte (dot-source) para dois checks do inventario de wrappers locais
  (Test-XpzWrapperInventory.ps1): (1) forwards_unknown_engine_param — repasse a motor
  compartilhado advanced de parametro nao-declarado (direcao wrapper->motor); (2) diff de
  superficie wrapper-local vs molde — surface_mismatch (bloqueio) e INVENTORY_SURFACE_ADVISORY
  (aviso), ver bloco proprio no fim do arquivo (direcao wrapper->molde).

.DESCRIPTION
  Este arquivo hospeda DOIS checks do inventario. Esta secao .DESCRIPTION e os LIMITES
  CONHECIDOS abaixo cobrem o check (1) forwards_unknown_engine_param (direcao wrapper->motor);
  o check (2) diff de superficie wrapper->molde (`surface_mismatch`/`INVENTORY_SURFACE_ADVISORY`,
  helpers Get-XpzScriptParamSurface/Get-XpzWrapperSurfaceFinding) tem documentacao propria no
  bloco de comentario no fim do arquivo.

  Check (1): verifica, por AST + Get-Command (sem executar o motor, sem KB), que todo parametro
  que um wrapper local REPASSA a um motor compartilhado ADVANCED de fato EXISTE no motor (nome
  canonico ou alias). Em motor advanced, repassar um parametro nao-declarado e erro de
  binding em runtime, invisivel ao parse/STRUCTURE_OK/GATE_OK e ao naming-contract.

  NAO e um self-test; nao emite sentinela. E dot-sourced por Test-XpzWrapperInventory.ps1.

  Discriminador de escopo (por VALOR, nao pelo nome da variavel-raiz):
    - site = `& $V ...` onde $V e atribuido (profundidade 1, mesmo escopo) de uma expressao
      `Join-Path <raiz> 'scripts\<Leaf>.ps1'` (formas literal/aninhada/multi-arg);
    - o discriminador opera no LITERAL 'scripts' da expressao Join-Path (AST), nao no caminho
      resolvido: `Join-Path $PSScriptRoot 'Rebuild.ps1'` resolve para .../scripts/Rebuild.ps1
      mas NAO tem o literal 'scripts' -> irmao local, fora de escopo;
    - leaf existente na pasta de motores do auditor (EnginesRoot) -> motor compartilhado;
    - leaf inexistente sob expressao com literal 'scripts' -> shared_engine_unresolved
      (sinal de desvio-de-wrapper; coerente com 8.a.ii do xpz-kb-parallel-setup);
    - alvo nao-resoluvel a uma expressao Join-Path literal (raiz dinamica, reatribuicao,
      multi-hop) -> pular o site (conservador; ver LIMITES).

  Deteccao advanced (sem executar): advanced sse os CommonParameters foram INJETADOS pelo
  runtime, i.e. presentes em Get-Command.Parameters mas AUSENTES do param() block declarado
  no AST do motor. Um SIMPLE que declare $Verbose literalmente nao e confundido com advanced.

  Comparacao de nomes: OrdinalIgnoreCase em todo o pipeline (binding e case-insensitive).

  LIMITES CONHECIDOS (pular o site + follow-up no 999-ideias-pendentes.md), nao auditados:
    - reatribuicao da variavel-raiz/intermediaria por expressao nao-rastreavel, multi-hop,
      basename composto por variavel, raiz totalmente dinamica;
    - invocacao direta sem variavel, Invoke-Expression, dot-source, pipeline, repasse
      posicional;
    - colisao de nome via `Join-Path $repoRoot 'scripts\<X>.ps1'` apontando para arquivo
      LOCAL cujo leaf coincide com motor canonico (fora do padrao dos moldes).
#>

Set-StrictMode -Version Latest

# CommonParameters que so coexistem em funcoes/scripts ADVANCED (injetados pelo runtime).
# Subconjunto estavel entre versoes do PowerShell 7.x usado como discriminador.
$script:XpzEngineParamCommonMarkers = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'OutBuffer')

function Get-XpzAstJoinPathLeaf {
    <#
      Recebe um Ast de expressao (lado direito de uma atribuicao ou o alvo do &).
      Se for (ou contiver) uma chamada Join-Path com um segmento literal 'scripts' e um
      leaf literal '<algo>.ps1', devolve [pscustomobject]@{ HasScriptsSegment; Leaf }.
      Caso nao seja Join-Path resoluvel a literais, devolve $null (alvo nao-resoluvel).
    #>
    param([System.Management.Automation.Language.Ast]$Ast)

    if ($null -eq $Ast) { return $null }

    # Desembrulhar Pipeline/CommandExpression ate o CommandAst do Join-Path, ou ParenExpression.
    $node = $Ast
    while ($true) {
        if ($node -is [System.Management.Automation.Language.PipelineAst]) {
            if (@($node.PipelineElements).Count -ne 1) { return $null }
            $node = $node.PipelineElements[0]; continue
        }
        if ($node -is [System.Management.Automation.Language.CommandExpressionAst]) { $node = $node.Expression; continue }
        if ($node -is [System.Management.Automation.Language.ParenExpressionAst]) { $node = $node.Pipeline; continue }
        break
    }

    if (-not ($node -is [System.Management.Automation.Language.CommandAst])) { return $null }

    $elements = @($node.CommandElements)
    if ($elements.Count -lt 1) { return $null }
    $cmdName = $elements[0]
    if (-not ($cmdName -is [System.Management.Automation.Language.StringConstantExpressionAst])) { return $null }
    if ($cmdName.Value -ine 'Join-Path') { return $null }

    # Coletar literais string desta chamada + de Join-Path aninhados nos argumentos.
    $literals = [System.Collections.Generic.List[string]]::new()
    for ($ei = 1; $ei -lt $elements.Count; $ei++) {
        $el = $elements[$ei]
        if ($el -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $literals.Add([string]$el.Value)
        } elseif ($el -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            # string interpolada (ex.: "scripts\$leaf") -> nao-resoluvel a literal seguro
            return $null
        } elseif ($el -is [System.Management.Automation.Language.ParenExpressionAst] -or
                  $el -is [System.Management.Automation.Language.CommandExpressionAst] -or
                  $el -is [System.Management.Automation.Language.PipelineAst]) {
            $nested = Get-XpzAstJoinPathLeaf -Ast $el
            if ($null -ne $nested) {
                if ($nested.HasScriptsSegment) { return $nested }
                # aninhado resolveu mas sem 'scripts' -> agrega seus segmentos via leaf
                if ($nested.Leaf) { $literals.Add([string]$nested.Leaf) }
            }
        }
        # VariableExpressionAst (a raiz) e ignorado de proposito: o discriminador e por forma+leaf.
    }

    if ($literals.Count -eq 0) { return $null }

    # Quebrar cada literal em segmentos por \ ou /.
    $segments = [System.Collections.Generic.List[string]]::new()
    foreach ($lit in $literals) {
        foreach ($seg in @($lit -split '[\\/]+')) {
            if (-not [string]::IsNullOrWhiteSpace($seg)) { $segments.Add($seg) }
        }
    }

    $hasScripts = $false
    foreach ($seg in $segments) { if ($seg -ieq 'scripts') { $hasScripts = $true; break } }

    $leaf = $null
    for ($i = $segments.Count - 1; $i -ge 0; $i--) {
        if ($segments[$i] -imatch '\.ps1$') { $leaf = $segments[$i]; break }
    }

    if ($null -eq $leaf) { return $null }
    return [pscustomobject]@{ HasScriptsSegment = $hasScripts; Leaf = $leaf }
}

function Resolve-XpzEngineTarget {
    <#
      Resolve o alvo de um `& <target> ...` a um leaf de motor (profundidade 1, mesmo
      ScriptBlock raiz). Devolve [pscustomobject]@{ Kind; Leaf } onde Kind e:
        'shared'      -> Join-Path com literal 'scripts' + leaf (auditar; checar existencia)
        'local'       -> Join-Path sem literal 'scripts' (irmao local; fora de escopo)
        'unresolved'  -> nao-resoluvel a literal (pular)
    #>
    param(
        [System.Management.Automation.Language.Ast]$TargetAst,
        [System.Management.Automation.Language.Ast]$RootAst
    )

    # Caso 1: alvo e a propria expressao Join-Path (ex.: & (Join-Path ...) -P) — defensivo.
    $direct = Get-XpzAstJoinPathLeaf -Ast $TargetAst
    if ($null -ne $direct) {
        if ($direct.HasScriptsSegment) { return [pscustomobject]@{ Kind = 'shared'; Leaf = $direct.Leaf } }
        return [pscustomobject]@{ Kind = 'local'; Leaf = $direct.Leaf }
    }

    # Caso 2: alvo e uma variavel -> resolver a UNICA atribuicao literal no escopo.
    if (-not ($TargetAst -is [System.Management.Automation.Language.VariableExpressionAst])) {
        return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null }
    }
    $varName = $TargetAst.VariablePath.UserPath

    $assignments = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Left.VariablePath.UserPath -ieq $varName
            }, $true))

    if ($assignments.Count -ne 1) {
        # nenhuma, ou multiplas (reatribuicao) -> nao-rastreavel
        return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null }
    }

    $resolved = Get-XpzAstJoinPathLeaf -Ast $assignments[0].Right
    if ($null -eq $resolved) { return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null } }
    if ($resolved.HasScriptsSegment) { return [pscustomobject]@{ Kind = 'shared'; Leaf = $resolved.Leaf } }
    return [pscustomobject]@{ Kind = 'local'; Leaf = $resolved.Leaf }
}

function Get-XpzForwardedParamName {
    <#
      Extrai os NOMES de parametros repassados num site `& <target> <elements...>`.
      Explicitos via CommandParameterAst; splat via resolucao das chaves literais da
      variavel splatada. Redirecionamentos nao sao CommandElement -> ignorados.
    #>
    param(
        [System.Management.Automation.Language.CommandAst]$CommandAst,
        [System.Management.Automation.Language.Ast]$RootAst
    )

    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $elements = @($CommandAst.CommandElements)
    # elemento 0 e o alvo (& $V); demais sao parametros/argumentos.
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
            [void]$names.Add([string]$el.ParameterName)
        } elseif ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
            foreach ($k in (Get-XpzSplatLiteralKey -SplatVarName $el.VariablePath.UserPath -RootAst $RootAst)) {
                [void]$names.Add($k)
            }
        }
    }
    return @($names)
}

function Get-XpzSplatLiteralKey {
    <#
      Coleta as chaves literais de uma hashtable de splat (@var):
        - HashtableAst literal atribuido a $var;
        - membro  $var.Chave = ...
        - indice  $var['Chave'] = ...
        - metodo  $var.Add('Chave', ...)
      Chave nao-literal (dinamica) -> ignorada. Se $var sofrer mutacao por .Remove/.Clear
      ou reatribuicao por expressao nao-rastreavel, o chamador ja tera pulado o site; aqui
      apenas coletamos o que e literal.
    #>
    param([string]$SplatVarName, [System.Management.Automation.Language.Ast]$RootAst)

    $keys = [System.Collections.Generic.List[string]]::new()

    # (a) HashtableAst literal atribuido diretamente a $var.
    $assigns = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Left.VariablePath.UserPath -ieq $SplatVarName
            }, $true))
    foreach ($a in $assigns) {
        $right = $a.Right
        if ($right -is [System.Management.Automation.Language.CommandExpressionAst]) { $right = $right.Expression }
        if ($right -is [System.Management.Automation.Language.HashtableAst]) {
            foreach ($pair in $right.KeyValuePairs) {
                $keyAst = $pair.Item1
                if ($keyAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $keys.Add([string]$keyAst.Value)
                }
            }
        }
    }

    # (b) membro/indice: $var.Chave = ... ou $var['Chave'] = ...
    $memberAssigns = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $true))
    foreach ($a in $memberAssigns) {
        $left = $a.Left
        if ($left -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $left.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $left.Expression.VariablePath.UserPath -ieq $SplatVarName -and
            $left.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$left.Member.Value)
        } elseif ($left -is [System.Management.Automation.Language.IndexExpressionAst] -and
            $left.Target -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $left.Target.VariablePath.UserPath -ieq $SplatVarName -and
            $left.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$left.Index.Value)
        }
    }

    # (c) metodo .Add('Chave', ...)
    $invokes = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $n.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Expression.VariablePath.UserPath -ieq $SplatVarName -and
                $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $n.Member.Value -ieq 'Add'
            }, $true))
    foreach ($inv in $invokes) {
        $argList = @($inv.Arguments)
        if ($argList.Count -ge 1 -and $argList[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$argList[0].Value)
        }
    }

    return @($keys)
}

function Test-XpzSplatVarMutated {
    <# True se a variavel de splat sofre .Remove/.Clear ou foi reatribuida >1 vez (nao-rastreavel). #>
    param([string]$SplatVarName, [System.Management.Automation.Language.Ast]$RootAst)

    $mutators = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $n.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Expression.VariablePath.UserPath -ieq $SplatVarName -and
                $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                ($n.Member.Value -ieq 'Remove' -or $n.Member.Value -ieq 'Clear')
            }, $true))
    return $mutators.Count -gt 0
}

function Get-XpzEngineAcceptedParam {
    <#
      Resolve o conjunto de parametros aceitos por um motor ADVANCED, ou um diagnostico.
      Devolve [pscustomobject]@{ Status; Accepted } onde Status e:
        'advanced'   -> Accepted = HashSet (OrdinalIgnoreCase) de nomes + aliases aceitos
        'simple'     -> motor nao-advanced (binder permissivo); nao auditavel
        'unparseable'-> parse-error/Get-Command falhou/Parameters nulo
        'dynamic'    -> motor declara DynamicParam (nao enxergavel estaticamente)
    #>
    param([string]$EngineFullPath)

    # Parse primario (fonte de unparseable).
    $perrs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($EngineFullPath, [ref]$null, [ref]$perrs)
    if ($null -ne $perrs -and @($perrs).Count -gt 0) {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }

    $cmd = $null
    try { $cmd = Get-Command -Name $EngineFullPath -ErrorAction Stop } catch {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }
    if ($null -eq $cmd -or $null -eq $cmd.Parameters) {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }

    # Guard DynamicParam (nao aparece estaticamente em Get-Command).
    $body = [System.IO.File]::ReadAllText($EngineFullPath)
    if ($body -imatch '(?m)^\s*dynamicparam\b') {
        return [pscustomobject]@{ Status = 'dynamic'; Accepted = $null }
    }

    $surface = @($cmd.Parameters.Keys)

    # Nomes declarados no param() block do AST (TrimStart '$').
    $declared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $engineAst = [System.Management.Automation.Language.Parser]::ParseFile($EngineFullPath, [ref]$null, [ref]$null)
    $paramBlocks = @($engineAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.ParamBlockAst]
            }, $true))
    foreach ($pb in $paramBlocks) {
        foreach ($p in $pb.Parameters) {
            [void]$declared.Add(([string]$p.Name.VariablePath.UserPath))
        }
    }

    # injetados = surface - declarados.
    $injected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $surface) { if (-not $declared.Contains([string]$s)) { [void]$injected.Add([string]$s) } }

    $isAdvanced = $true
    foreach ($marker in $script:XpzEngineParamCommonMarkers) {
        if (-not $injected.Contains($marker)) { $isAdvanced = $false; break }
    }
    if (-not $isAdvanced) { return [pscustomobject]@{ Status = 'simple'; Accepted = $null } }

    $accepted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $surface) { [void]$accepted.Add([string]$s) }
    foreach ($pname in $cmd.Parameters.Keys) {
        foreach ($alias in @($cmd.Parameters[$pname].Aliases)) { [void]$accepted.Add([string]$alias) }
    }
    return [pscustomobject]@{ Status = 'advanced'; Accepted = $accepted }
}

function Get-XpzWrapperEngineParamFinding {
    <#
      Ponto de entrada. Para um wrapper local, devolve:
        [pscustomobject]@{
          Signals          = @( @{ Reason; Detail } )   # desvios-de-wrapper (-> INVENTORY_CUSTOMIZED)
          EngineDiagnostics = @( @{ Reason; Detail } )   # infra brando (-> INVENTORY_ENGINE_DIAGNOSTIC)
          AuditedSiteCount = <int>                        # nº de sites de motor advanced auditados
        }
      EnginesRoot = pasta dos motores canonicos do auditor (tipicamente $PSScriptRoot do inventory).
    #>
    param(
        [Parameter(Mandatory)][string]$WrapperPath,
        [Parameter(Mandatory)][string]$EnginesRoot
    )

    $signals = [System.Collections.Generic.List[object]]::new()
    $diagnostics = [System.Collections.Generic.List[object]]::new()
    $audited = 0

    $perrs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($WrapperPath, [ref]$null, [ref]$perrs)
    if ($null -eq $ast) {
        return [pscustomobject]@{ Signals = @(); EngineDiagnostics = @(); AuditedSiteCount = 0 }
    }

    $callSites = @($ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand
            }, $true))

    foreach ($site in $callSites) {
        $elements = @($site.CommandElements)
        if ($elements.Count -lt 1) { continue }
        $target = Resolve-XpzEngineTarget -TargetAst $elements[0] -RootAst $ast
        if ($target.Kind -eq 'local' -or $target.Kind -eq 'unresolved') { continue }
        # target.Kind = 'shared'
        $leaf = $target.Leaf
        $enginePath = Join-Path $EnginesRoot $leaf
        if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
            $signals.Add(@{ Reason = 'shared_engine_unresolved'; Detail = $leaf })
            continue
        }

        # Se a variavel de splat sofre mutacao nao-rastreavel, pular o site (conservador).
        $splatVar = $null
        for ($i = 1; $i -lt $elements.Count; $i++) {
            if ($elements[$i] -is [System.Management.Automation.Language.VariableExpressionAst] -and $elements[$i].Splatted) {
                $splatVar = $elements[$i].VariablePath.UserPath; break
            }
        }
        if ($splatVar -and (Test-XpzSplatVarMutated -SplatVarName $splatVar -RootAst $ast)) { continue }

        $engine = Get-XpzEngineAcceptedParam -EngineFullPath $enginePath
        # NOTA: 'continue' dentro de switch continua o switch, nao o foreach; por isso o
        # switch e a ultima instrucao do corpo do laco e cada caso so faz seu trabalho.
        switch ($engine.Status) {
            'unparseable' { $diagnostics.Add(@{ Reason = 'engine_unresolved_or_unparseable'; Detail = $leaf }) }
            'dynamic'     { }
            'simple'      { }
            'advanced' {
                $audited++
                $forwarded = Get-XpzForwardedParamName -CommandAst $site -RootAst $ast
                foreach ($name in $forwarded) {
                    if (-not $engine.Accepted.Contains([string]$name)) {
                        $signals.Add(@{ Reason = 'forwards_unknown_engine_param'; Detail = ('-{0} -> {1}' -f $name, $leaf) })
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        Signals           = @($signals)
        EngineDiagnostics = @($diagnostics)
        AuditedSiteCount  = $audited
    }
}

# ============================================================================
# Diff de superficie de wrapper (check surface_mismatch / INVENTORY_SURFACE_ADVISORY)
#
# Compara a superficie {nomes de parametro; Mandatory; conjunto de valores de cada
# [ValidateSet]} do wrapper LOCAL contra o MOLDE canonico (.example.ps1). VALOR DEFAULT
# NAO faz parte da superficie (o molde usa placeholders como SharedSkillsRoot). Severidade
# consciente de direcao: o falso-positivo mora no lado "a mais / a frente" (o repo remove
# [ValidateSet] de proposito para delegar ao motor; ha index-gate runtime), entao esse lado
# NAO e punido. BLOQUEIA so PERDA de contrato obrigatorio; AVISA reducoes opcionais/ValidateSet;
# QUIETO no excedente/delegacao legitima. Complementa (nao duplica) o check por direcao inversa
# forwards_unknown_engine_param acima: la o wrapper repassa demais; aqui o wrapper acompanha de
# menos o molde.
# ============================================================================

function Test-XpzAttributeAstIsType {
    <# True se $Attr e um AttributeAst cujo TypeName casa (accelerator OU FQN) um dos $Names. #>
    param([System.Management.Automation.Language.Ast]$Attr, [string[]]$Names)
    if (-not ($Attr -is [System.Management.Automation.Language.AttributeAst])) { return $false }
    $fn = [string]$Attr.TypeName.FullName
    foreach ($n in $Names) { if ($fn -ieq $n) { return $true } }
    return $false
}

function Test-XpzParamAstMandatory {
    <#
      Um parametro e obrigatorio SSE QUALQUER [Parameter] o marca Mandatory=$true (uniao entre
      parameter-sets). Atributo [Parameter] ausente OU sem Mandatory=opcional; Mandatory sem valor
      (ExpressionOmitted)=obrigatorio; =$true=obrigatorio; =$false=opcional por esse attr; QUALQUER
      expressao nao-literal-bool (=$var, =[bool]"x")=conservador OBRIGATORIO (nao avaliar). Casa
      [Parameter] por accelerator E FQN.
    #>
    param([System.Management.Automation.Language.ParameterAst]$ParameterAst)
    foreach ($attr in $ParameterAst.Attributes) {
        if (-not (Test-XpzAttributeAstIsType -Attr $attr -Names @('Parameter', 'ParameterAttribute', 'System.Management.Automation.ParameterAttribute'))) { continue }
        foreach ($na in $attr.NamedArguments) {
            if ($na.ArgumentName -ine 'Mandatory') { continue }
            if ($na.ExpressionOmitted) { return $true }
            $arg = $na.Argument
            if ($arg -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $vp = $arg.VariablePath.UserPath
                if ($vp -ieq 'true') { return $true }
                elseif ($vp -ieq 'false') { continue }
                else { return $true }
            } else {
                return $true
            }
        }
    }
    return $false
}

function Get-XpzParamAstValidateSet {
    <#
      Devolve [pscustomobject]@{ Comparable; Values }. Comparavel (Values=HashSet OrdinalIgnoreCase)
      SSE existe EXATAMENTE 1 [ValidateSet] e TODOS os posicionais sao literais STRING. Nao-comparavel
      (Values=$null) quando: zero ou >1 [ValidateSet] (multiplos = AND/INTERSECAO, nao uniao); vazio;
      qualquer posicional nao-literal (misto/gerador/variavel) ou literal nao-string (ex.: 1,2,3).
      Argumentos NOMEADOS (IgnoreCase=/ErrorMessage=) sao ignorados. Cobre posicional direto e
      ArrayLiteralAst. Casa [ValidateSet] por accelerator E FQN.
    #>
    param([System.Management.Automation.Language.ParameterAst]$ParameterAst)
    $vsAttrs = @($ParameterAst.Attributes | Where-Object {
            Test-XpzAttributeAstIsType -Attr $_ -Names @('ValidateSet', 'ValidateSetAttribute', 'System.Management.Automation.ValidateSetAttribute')
        })
    if ($vsAttrs.Count -ne 1) { return [pscustomobject]@{ Comparable = $false; Values = $null } }

    $attr = $vsAttrs[0]
    $positionals = [System.Collections.Generic.List[object]]::new()
    foreach ($pa in $attr.PositionalArguments) {
        if ($pa -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            foreach ($el in $pa.Elements) { $positionals.Add($el) }
        } else {
            $positionals.Add($pa)
        }
    }
    if ($positionals.Count -eq 0) { return [pscustomobject]@{ Comparable = $false; Values = $null } }

    $values = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($pa in $positionals) {
        if (-not ($pa -is [System.Management.Automation.Language.StringConstantExpressionAst])) {
            return [pscustomobject]@{ Comparable = $false; Values = $null }
        }
        [void]$values.Add(([string]$pa.Value).Trim())
    }
    return [pscustomobject]@{ Comparable = $true; Values = $values }
}

function Get-XpzScriptParamSurface {
    <#
      Extrai a superficie de parametros do ParamBlock de TOPO do ScriptBlock raiz
      ($ast.ParamBlock), NUNCA FindAll(ParamBlockAst) recursivo — recursivo colheria os param()
      de funcoes/filtros internos (ex.: Update-KbFromXpz.example.ps1 tem param() de topo E ~5
      funcoes internas com param() Mandatory). Script sem param() de topo (so funcao/filtro) tem
      ParamBlock NULO -> HasParamBlock=$false, sem fallback para param() interno. CUIDADO:
      [CmdletBinding()] sem param() gera ParamBlock nulo (parse-error); [CmdletBinding()] COM
      param() vazio gera ParamBlock nao-nulo Count 0 (molde zero-superficie).

      Devolve [pscustomobject]@{ Parseable; HasParamBlock; Params(Dictionary OrdinalIgnoreCase);
      ParamCount; MandatoryCount }. Extrai de AST, nao de Get-Command (que injeta CommonParameters
      em advanced).
    #>
    param([Parameter(Mandatory)][string]$ScriptPath)

    $perrs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$perrs)
    $parseable = ($null -ne $ast) -and ($null -eq $perrs -or @($perrs).Count -eq 0)

    $paramBlock = if ($null -ne $ast) { $ast.ParamBlock } else { $null }
    $hasParamBlock = ($null -ne $paramBlock)

    $params = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $mandatoryCount = 0
    if ($hasParamBlock) {
        foreach ($p in $paramBlock.Parameters) {
            $name = [string]$p.Name.VariablePath.UserPath
            if ($params.ContainsKey($name)) { continue }
            $mandatory = Test-XpzParamAstMandatory -ParameterAst $p
            $vs = Get-XpzParamAstValidateSet -ParameterAst $p
            $params[$name] = [pscustomobject]@{
                Name                  = $name
                Mandatory             = $mandatory
                ValidateSetComparable = $vs.Comparable
                ValidateSetValues     = $vs.Values
            }
            if ($mandatory) { $mandatoryCount++ }
        }
    }

    return [pscustomobject]@{
        Parseable      = $parseable
        HasParamBlock  = $hasParamBlock
        Params         = $params
        ParamCount     = $params.Count
        MandatoryCount = $mandatoryCount
    }
}

function Get-XpzWrapperSurfaceFinding {
    <#
      Compara a superficie do wrapper LOCAL contra o MOLDE canonico. Devolve
      [pscustomobject]@{ Blocking; Advisory } onde cada item e @{ Reason; Detail }.
        Blocking (-> INVENTORY_CUSTOMIZED reason=surface_mismatch): mandatory_param_missing,
          mandatory_downgraded, no_param_block (quando o molde tem obrigatorio).
        Advisory (-> INVENTORY_SURFACE_ADVISORY, fora do regex de pendencia do agregador):
          optional_param_missing, validateset_reduced (DIFERENCA DE CONJUNTO molde-local),
          optional_promoted_to_mandatory, extra_mandatory_added, no_param_block (molde >=1 param
          todos opcionais).
      QUIETO: param extra opcional; ValidateSet local superset/removido/nao-comparavel; molde
      zero-superficie sem obrigatorio; qualquer lado nao-parseavel (conservador — wrapper quebrado
      e pego por outro gate).
    #>
    param(
        [Parameter(Mandatory)][string]$MoldePath,
        [Parameter(Mandatory)][string]$LocalPath
    )
    $blocking = [System.Collections.Generic.List[object]]::new()
    $advisory = [System.Collections.Generic.List[object]]::new()

    $molde = Get-XpzScriptParamSurface -ScriptPath $MoldePath
    $local = Get-XpzScriptParamSurface -ScriptPath $LocalPath

    if (-not $molde.Parseable -or -not $local.Parseable) {
        return [pscustomobject]@{ Blocking = @(); Advisory = @() }
    }

    # LOCAL sem param() de topo -> no_param_block; severidade pela superficie do MOLDE.
    if (-not $local.HasParamBlock) {
        if ($molde.MandatoryCount -gt 0) {
            $blocking.Add(@{ Reason = 'no_param_block'; Detail = '' })
        } elseif ($molde.ParamCount -gt 0) {
            $advisory.Add(@{ Reason = 'no_param_block'; Detail = '' })
        }
        return [pscustomobject]@{ Blocking = @($blocking); Advisory = @($advisory) }
    }

    foreach ($mName in @($molde.Params.Keys)) {
        $mp = $molde.Params[$mName]
        if (-not $local.Params.ContainsKey($mName)) {
            if ($mp.Mandatory) {
                $blocking.Add(@{ Reason = 'mandatory_param_missing'; Detail = ('-{0}' -f $mp.Name) })
            } else {
                $advisory.Add(@{ Reason = 'optional_param_missing'; Detail = ('-{0}' -f $mp.Name) })
            }
            continue
        }
        $lp = $local.Params[$mName]
        if ($mp.Mandatory -and -not $lp.Mandatory) {
            $blocking.Add(@{ Reason = 'mandatory_downgraded'; Detail = ('-{0}' -f $mp.Name) })
        } elseif (-not $mp.Mandatory -and $lp.Mandatory) {
            $advisory.Add(@{ Reason = 'optional_promoted_to_mandatory'; Detail = ('-{0}' -f $mp.Name) })
        }
        if ($mp.ValidateSetComparable -and $lp.ValidateSetComparable) {
            $missing = [System.Collections.Generic.List[string]]::new()
            foreach ($v in $mp.ValidateSetValues) {
                if (-not $lp.ValidateSetValues.Contains($v)) { $missing.Add($v) }
            }
            if ($missing.Count -gt 0) {
                $sorted = @($missing | Sort-Object)
                $advisory.Add(@{ Reason = 'validateset_reduced'; Detail = ('-{0} [{1}]' -f $mp.Name, ($sorted -join ', ')) })
            }
        }
    }

    foreach ($lName in @($local.Params.Keys)) {
        if ($molde.Params.ContainsKey($lName)) { continue }
        $lp = $local.Params[$lName]
        if ($lp.Mandatory) {
            $advisory.Add(@{ Reason = 'extra_mandatory_added'; Detail = ('-{0}' -f $lp.Name) })
        }
    }

    return [pscustomobject]@{ Blocking = @($blocking); Advisory = @($advisory) }
}
