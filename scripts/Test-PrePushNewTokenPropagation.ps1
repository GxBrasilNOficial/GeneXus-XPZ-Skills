#requires -Version 7.4
<#
.SYNOPSIS
    Gate consultivo: detecta termo de contrato introduzido no diff e mencoes
    equivalentes do repositório que podem ter ficado com o conjunto antigo.

.DESCRIPTION
    Suporte mecanico da regra simetrica do passo 2 de 13-revisao-pre-push.md:
    quando a frente ADICIONA parametro/alias/flag a um contrato, o termo novo
    deve aparecer em todas as mencoes equivalentes da mesma operacao.

    Heuristica determinista por TRANSICAO no diff (não por novidade global do
    token no repo — um alias pode já existir noutro fluxo e ainda assim ser novo
    para este contrato):

      1. Quebra o diff BaseRef..HEAD em hunks.
      2. Em cada hunk, compara tokens de contrato (-Xxx, --xxx, .PARAMETER Xxx)
         das linhas removidas e adicionadas. Um token T e INTRODUZIDO no hunk se
         aparece em linha adicionada e em nenhuma linha removida do mesmo hunk.
      3. Quando uma linha adicionada co-localiza T (introduzido) com um token P
         que existia no hunk (presente em linha removida), registra o par (T, P):
         e a assinatura de "alias acrescentado a uma enumeracao existente"
         (ex.: '- ...-ObjectNames ou -ObjectGuids' -> '+ ...-ObjectList,
         -ObjectNames ou -ObjectGuids').
      4. Varre o estado atual do repositório (.md, .ps1, .py VERSIONADOS, fora de
         historico/) por linhas que mencionam P sem T (ignorando a própria
         declaracao de P: .PARAMETER P e bloco param): cada uma e uma CANDIDATA a
         mencao defasada. A varredura usa `git ls-files` porque material ignorado
         ou nao rastreado (rascunho de rodada em Temp/, node_modules/ vendorizado)
         não e documento do repositório e não pode ficar defasado num push — so
         inflaria o livro-razao de vereditos. Sem fallback para walk de
         filesystem: o contrato ja exige repositório Git (a ref base BaseRef e
         validada antes da varredura), entao falha de `ls-files` e defeito de
         ambiente e o gate para fail-closed.

    Consultivo: não prova propagacao completa nem reprova sozinho. Findings são
    severity 'warn'; o orquestrador os despeja em agentWarnings e a fase
    semantica confronta e justifica ou corrige cada candidata. Falso positivo e
    barato (justificar/descartar); o custo alto e o falso negativo (termo novo
    que ficou só com o conjunto antigo, invisivel no diff). Limitacao conhecida:
    só dispara quando ha transicao co-localizada no diff; alias adicionado sem
    enumeracao pre-existente no mesmo hunk não gera par.

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo BaseRef..HEAD. Default: origin/main.

.PARAMETER ChangedFiles
    Arquivos alterados no intervalo (informativo; aceito para o contrato comum
    dos gates do orquestrador). A deteccao usa o diff e o estado atual do repo.

.PARAMETER MaxFindings
    Teto de candidatas de classe `prose` reportadas. Default: 30. Candidatas
    nao-prosa (`param-list-item`, `param-table-cell`, `command-example`) NÃO são
    truncadas — são as mais acionaveis e poderiam estar em arquivos varridos
    depois que o teto de prosa encheu. `truncatedProseCount` informa quantas
    candidatas de prosa foram descartadas pelo teto.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [ValidateRange(1, 500)]
    [int]$MaxFindings = 30,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

# Tokens de contrato: parâmetro PowerShell (-Xxx, inicial maiuscula para não
# casar operadores -eq/-not/-join), flag CLI/Python (--xxx) e bloco .PARAMETER Xxx.
$psParamRegex  = [regex]::new('(?<![A-Za-z0-9_])-(?<name>[A-Z][A-Za-z0-9]+)')
$cliFlagRegex  = [regex]::new('(?<![A-Za-z0-9_])--(?<name>[a-z][a-z0-9-]+)')
$paramDocRegex = [regex]::new('\.PARAMETER\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)')

function Get-LineTokens {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($rx in @($psParamRegex, $cliFlagRegex, $paramDocRegex)) {
        foreach ($m in $rx.Matches($Line)) {
            [void]$names.Add($m.Groups['name'].Value)
        }
    }
    return @($names | Sort-Object -Unique)
}

function Test-TokensRelated {
    # Reduz ruido de co-localizacao coincidente (ex.: linhas de invocacao
    # 'pwsh -NoProfile -File ... -FrontPrefix'): só trata como par quando os dois
    # tokens compartilham morfema (prefixo OU sufixo comum >= 4 chars,
    # case-insensitive). Alias/enumeracao de contrato quase sempre compartilham
    # raiz (ObjectList/ObjectNames -> 'Object'; InputPath/Path -> 'Path').
    param(
        [Parameter(Mandatory = $true)][string]$A,
        [Parameter(Mandatory = $true)][string]$B
    )

    $a = $A.ToLowerInvariant()
    $b = $B.ToLowerInvariant()
    $min = [Math]::Min($a.Length, $b.Length)

    $prefix = 0
    while ($prefix -lt $min -and $a[$prefix] -eq $b[$prefix]) { $prefix++ }

    $suffix = 0
    while ($suffix -lt $min -and $a[$a.Length - 1 - $suffix] -eq $b[$b.Length - 1 - $suffix]) { $suffix++ }

    return ($prefix -ge 4 -or $suffix -ge 4)
}

$wordRegexCache = @{}
function Get-WordRegex {
    # Casa o token como palavra em qualquer forma (inclui $Token de código).
    param([Parameter(Mandatory = $true)][string]$Token)

    if (-not $wordRegexCache.ContainsKey($Token)) {
        $pattern = '(?<![A-Za-z0-9_])' + [regex]::Escape($Token) + '(?![A-Za-z0-9_])'
        $wordRegexCache[$Token] = [regex]::new($pattern)
    }
    return $wordRegexCache[$Token]
}

$mentionRegexCache = @{}
function Get-MentionRegex {
    # Casa o token apenas como mencao de contrato (prosa, doc, -Param), NÃO como
    # variável $Token de código interno (a lookbehind exclui '$').
    param([Parameter(Mandatory = $true)][string]$Token)

    if (-not $mentionRegexCache.ContainsKey($Token)) {
        $pattern = '(?<![A-Za-z0-9_$])' + [regex]::Escape($Token) + '(?![A-Za-z0-9_])'
        $mentionRegexCache[$Token] = [regex]::new($pattern)
    }
    return $mentionRegexCache[$Token]
}

$declRegexCache = @{}
function Test-IsOwnDeclarationLine {
    # Linha que apenas declara/documenta o próprio token P (não e enumeracao da
    # operacao): .PARAMETER P, [tipo]$P, $P = ...
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line
    )

    if (-not $declRegexCache.ContainsKey($Token)) {
        $escaped = [regex]::Escape($Token)
        # .PARAMETER P  |  declaracao de parâmetro terminando em $P[,)]  |  atribuicao $P =
        $pattern = '(^\s*\.PARAMETER\s+' + $escaped + '\b)|(\$' + $escaped + '\s*[,)]?\s*$)|(\$' + $escaped + '\s*=)'
        $declRegexCache[$Token] = [regex]::new($pattern)
    }
    return $declRegexCache[$Token].IsMatch($Line)
}

function Get-MentionClass {
    # Classifica a FORMA da linha onde a candidata foi encontrada. A fase
    # semantica do 13 usa isso para não descartar candidatas em lote: 'prose'
    # admite justificativa coletiva (só cita o nome canonico); 'param-list-item',
    # 'param-table-cell' e 'command-example' exigem veredito item a item,
    # confrontados contra a lista/tabela/exemplo gemeo em outro documento.
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
        [bool]$InFence = $false
    )

    if ($InFence) { return 'command-example' }
    if ($Line -match '^\s*\|') { return 'param-table-cell' }
    if ($Line -match '^\s*[-*]\s+`?-') { return 'param-list-item' }
    return 'prose'
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

# Confirma que a ref base existe (sem fallback automático).
$refCheck = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--verify', $BaseRef)
if ($refCheck.ExitCode -ne 0) {
    throw ("Ref base '{0}' nao encontrada; rode git fetch origin ou passe -BaseRef valido." -f $BaseRef)
}

$range = "$BaseRef..HEAD"
$diffResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', $range)
if ($diffResult.ExitCode -ne 0) {
    throw ("Falha ao obter diff do intervalo {0}." -f $range)
}

# Quebra o patch em hunks; coleta linhas adicionadas e removidas de cada hunk.
$hunks = [System.Collections.Generic.List[object]]::new()
$currentAdded = $null
$currentRemoved = $null

function Save-CurrentHunk {
    if ($null -ne $currentAdded -and ($currentAdded.Count -gt 0 -or $currentRemoved.Count -gt 0)) {
        $script:hunks.Add([pscustomobject]@{
            Added   = @($currentAdded)
            Removed = @($currentRemoved)
        })
    }
}

foreach ($line in @($diffResult.Lines)) {
    if ($line.StartsWith('@@')) {
        Save-CurrentHunk
        $currentAdded = [System.Collections.Generic.List[string]]::new()
        $currentRemoved = [System.Collections.Generic.List[string]]::new()
        continue
    }
    if ($line.StartsWith('diff --git') -or $line.StartsWith('+++') -or $line.StartsWith('---')) {
        # Fronteira de arquivo / cabecalho: encerra hunk corrente.
        Save-CurrentHunk
        $currentAdded = $null
        $currentRemoved = $null
        continue
    }
    if ($null -eq $currentAdded) {
        continue
    }
    if ($line.StartsWith('+')) {
        [void]$currentAdded.Add($line.Substring(1))
    } elseif ($line.StartsWith('-')) {
        [void]$currentRemoved.Add($line.Substring(1))
    }
}
Save-CurrentHunk

# Pares (TokenIntroduzido, TokenPreExistente) por transicao co-localizada.
$pairKeys = [System.Collections.Generic.HashSet[string]]::new()
$pairs = [System.Collections.Generic.List[object]]::new()
$introducedTokens = [System.Collections.Generic.HashSet[string]]::new()

foreach ($hunk in $hunks) {
    $removedTokens = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($removedLine in @($hunk.Removed)) {
        foreach ($token in @(Get-LineTokens -Line $removedLine)) {
            [void]$removedTokens.Add($token)
        }
    }

    foreach ($addedLine in @($hunk.Added)) {
        $tokens = @(Get-LineTokens -Line $addedLine)
        if ($tokens.Count -lt 2) {
            continue
        }

        $introducedInLine = @($tokens | Where-Object { -not $removedTokens.Contains($_) })
        $preExistingInLine = @($tokens | Where-Object { $removedTokens.Contains($_) })
        if ($introducedInLine.Count -eq 0 -or $preExistingInLine.Count -eq 0) {
            continue
        }

        foreach ($newToken in $introducedInLine) {
            [void]$introducedTokens.Add($newToken)
            foreach ($oldToken in $preExistingInLine) {
                if ($newToken -eq $oldToken) {
                    continue
                }
                if (-not (Test-TokensRelated -A $newToken -B $oldToken)) {
                    continue
                }
                $key = '{0}|{1}' -f $newToken, $oldToken
                if ($pairKeys.Add($key)) {
                    $pairs.Add([pscustomobject][ordered]@{
                        newToken = $newToken
                        oldToken = $oldToken
                    })
                }
            }
        }
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$findingKeys = [System.Collections.Generic.HashSet[string]]::new()
$truncated = $false
$proseCount = 0
$truncatedProseCount = 0

if ($pairs.Count -gt 0) {
    # Universo da varredura = arquivos VERSIONADOS. Material ignorado/nao rastreado
    # (Temp/ de rodadas de revisao, node_modules/ vendorizado) nao e documento do
    # repositório: nao pode ficar defasado num push e so infla o livro-razao de
    # vereditos exigido pelo orquestrador. Nao ha fallback para walk de filesystem:
    # o contrato ja exige repositório Git (a ref base e validada acima), entao uma
    # falha aqui e defeito de ambiente, nao raiz sem Git — fail-closed.
    $trackedResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('ls-files', '--cached', '--', '*.md', '*.ps1', '*.py')
    if ($trackedResult.ExitCode -ne 0) {
        throw ("Falha ao listar arquivos versionados em '{0}': {1}" -f $resolvedRoot, $trackedResult.Text)
    }
    $files = @($trackedResult.Lines |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { [System.IO.FileInfo]::new((Join-Path $resolvedRoot $_)) } |
        Where-Object {
            $_.Exists -and
            $_.FullName -notmatch '[\\/](\.git|historico)[\\/]'
        })

    foreach ($file in $files) {
        $fileLines = @()
        try {
            $fileLines = @([System.IO.File]::ReadAllLines($file.FullName))
        } catch {
            continue
        }

        $relPath = ([System.IO.Path]::GetRelativePath($resolvedRoot, $file.FullName) -replace '\\', '/')
        $inFence = $false

        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            $text = $fileLines[$i]

            # Rastreia blocos de código cercados (```), para classificar linhas
            # internas como command-example. O delimitador em si não e candidato.
            if ($text -match '^\s*```') {
                $inFence = -not $inFence
                continue
            }

            foreach ($pair in $pairs) {
                # Mencao de contrato do token antigo (prosa/doc/-Param), não $variável.
                $oldMentionRx = Get-MentionRegex -Token $pair.oldToken
                if (-not $oldMentionRx.IsMatch($text)) {
                    continue
                }
                # Token novo presente em qualquer forma -> mencao já propagada.
                $newRx = Get-WordRegex -Token $pair.newToken
                if ($newRx.IsMatch($text)) {
                    continue
                }
                # Declaracao do próprio parâmetro antigo (.PARAMETER P / bloco param).
                if (Test-IsOwnDeclarationLine -Token $pair.oldToken -Line $text) {
                    continue
                }

                $lineNumber = $i + 1
                $findingKey = '{0}:{1}:{2}|{3}' -f $relPath, $lineNumber, $pair.newToken, $pair.oldToken
                if (-not $findingKeys.Add($findingKey)) {
                    continue
                }

                $mentionClass = Get-MentionClass -Line $text -InFence $inFence

                # Truncamento ciente de classe: candidatas nao-prosa
                # (param-list-item/param-table-cell/command-example) NUNCA são
                # truncadas — são as mais acionaveis e podem estar em arquivos
                # varridos depois que o teto de prosa encheu. Só a prosa e
                # limitada por -MaxFindings.
                if ($mentionClass -eq 'prose') {
                    if ($proseCount -ge $MaxFindings) {
                        $truncated = $true
                        $truncatedProseCount++
                        continue
                    }
                    $proseCount++
                }

                $findings.Add([pscustomobject][ordered]@{
                    code         = 'NEW_TOKEN_PROPAGATION_CANDIDATE'
                    severity     = 'warn'
                    path         = ('{0}:{1}' -f $relPath, $lineNumber)
                    mentionClass = $mentionClass
                    message      = ("termo '{0}' foi introduzido no diff junto de '{1}'; esta mencao tem '{1}' sem '{0}' — confirmar propagacao ou justificar a omissao [classe={2}]" -f $pair.newToken, $pair.oldToken, $mentionClass)
                })
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$classCounts = [ordered]@{}
foreach ($f in $findings) {
    if ($classCounts.Contains($f.mentionClass)) {
        $classCounts[$f.mentionClass] = $classCounts[$f.mentionClass] + 1
    } else {
        $classCounts[$f.mentionClass] = 1
    }
}

$result = [ordered]@{
    status              = $status
    range               = $range
    introducedTokens    = @($introducedTokens | Sort-Object)
    pairsConsidered     = @($pairs)
    candidateCount      = $findings.Count
    classCounts         = $classCounts
    truncated           = $truncated
    truncatedProseCount = $truncatedProseCount
    findings            = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("RANGE={0}" -f $range)
    Write-Output ("INTRODUCED_TOKENS={0}" -f (@($introducedTokens | Sort-Object) -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    foreach ($finding in @($findings)) {
        Write-Output ("NEW_TOKEN_PROPAGATION_CANDIDATE: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output ("PROSE_CANDIDATES_TRUNCATED={0}" -f $truncatedProseCount)
        Write-Output 'NON_PROSE_CANDIDATES_COMPLETE=true'
    }
}

exit 0
