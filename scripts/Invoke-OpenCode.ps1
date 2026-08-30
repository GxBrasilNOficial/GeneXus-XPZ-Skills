#requires -Version 7.4
<#
.SYNOPSIS
    Chama o opencode (one-shot, sincrono) e devolve a resposta em texto.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Resolve o opencode.exe por -OpenCodeExe, PATH
    (WinGet/Scoop/binario direto) ou npm legado, e o executa com o prompt entregue por STDIN
    (arquivo), FORA do argv. Entregar o prompt por
    stdin (e nao como argumento posicional de 'run') resolve o limite ~32KB de linha de comando do
    Windows para prompts grandes e usa redirecao EXPLICITA de stdout/stderr a arquivo
    (Start-Process -RedirectStandard*), evitando o erro nao-deterministico "StandardOutputEncoding
    is only supported when standard output is redirected" do padrao antigo (& exe 1> arquivo dentro
    de um runner temporario). Bloqueia ate a resposta (ou ate -TimeoutSec).

    O opencode le o prompt do stdin quando o argumento posicional de 'run' e omitido (verificado
    empiricamente no opencode em uso nesta maquina, 2026-06). Espelha o padrao stdin-based de
    Invoke-Codex.ps1.

    Esta e a invocacao sincrona canonica. Para tarefas longas que você quer disparar sem
    bloquear, use Start-OpenCodeJob.ps1.

    CONFIDENCIALIDADE: este script NÃO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteúdo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.
.PARAMETER Message
    Prompt a enviar ao agente (posicional). Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Util para prompts
    grandes (acima do limite ~32KB de linha de comando) e para evitar substituicao de comando
    ("$(cat ...)") na linha de comando do chamador.
.PARAMETER Model
    Modelo no formato provider/modelo (ex: openai/gpt-5.4). Opcional: omitido usa o default
    da config do opencode (~/.config/opencode/opencode.json).
.PARAMETER Agent
    Nome do agente do opencode a usar. Opcional.
.PARAMETER OpenCodeExe
    Forca um caminho de opencode.exe (contorna a descoberta automatica). Usado tambem pelos
    self-tests para injetar um fake-exe.
.PARAMETER Raw
    Devolve o stream JSON cru (um evento por linha) em vez do texto final. Sem retry. No timeout,
    o adapter ainda classifica limite de uso/taxa (nao ha stream util para devolver). Nos demais
    terminais (exit!=0, etc.), -Raw nao classifica limite.
.PARAMETER AllText
    Devolve toda a narracao (preambulos de passo + resposta final) concatenada, em vez de só a resposta final.
.PARAMETER TimeoutSec
    Tempo máximo de espera pela resposta (default 180s). É POR TENTATIVA: com -MaxAttempts > 1,
    o tempo de parede total pode ser múltiplo deste valor.
.PARAMETER MaxAttempts
    Número máximo de tentativas (1-3, default 1 = comportamento histórico, sem re-tentativa).
    Com 2+, re-despacha UMA vez por tentativa adicional APENAS quando o veredito de conclusão for
    'truncated' ou 'no-completion' (truncagem intermitente de cauda do opencode). NUNCA re-tenta
    timeout, exit code != 0, erro explícito de stream, 429 detectado na janela da tentativa, nem
    'empty' (conclusão limpa sem texto). Não tem efeito com -Raw (que devolve a 1ª execução).
    Cada re-tentativa emite, em stderr, uma linha 'OPENCODE_RETRY: attempt=N status=... reason=...'.
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi"
.EXAMPLE
    .\Invoke-OpenCode.ps1 "resuma este log" -Model openai/gpt-5.4
.EXAMPLE
    .\Invoke-OpenCode.ps1 -MessagePath .\prompt-grande.txt -Model ollama-cloud/deepseek-v4-pro
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi" -Raw      # stream JSON cru (tool-calls, custo, tokens)
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model,
    [string] $Agent,
    [string] $OpenCodeExe,
    [switch] $Raw,
    [switch] $AllText,
    [int]    $TimeoutSec = 180,
    [ValidateRange(1, 3)] [int] $MaxAttempts = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Garante saida UTF-8 (acentos) ao devolver o texto pelo stdout
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Funções compartilhadas de parsing do stream do opencode (dot-source)
. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')
# Descoberta do opencode CLI (npm, WinGet/PATH, override explicito)
. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')
# Guard least-privilege do reviewer-ro (default escopado + pre/pos-check fail-closed)
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Le como UTF-8.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

# 1) Resolve o opencode.exe: override explicito, PATH (WinGet/Scoop/binario direto) ou npm legado.
$exe = Resolve-OpenCodeExe -Override $OpenCodeExe

# 1b) D1/D2: postura de seguranca no ADAPTER (design congelado). Default -Agent reviewer-ro
#     ESCOPADO ao caminho revisor: sem -Agent explicito, o agente efetivo e reviewer-ro e o
#     enforce read-only fail-closed (pre-check) se aplica. Com -Agent <x> EXPLICITO, o chamador
#     faz opt-out consciente (uso agentico fora do painel; assume a postura de seguranca), mas o
#     pre-check ainda confirma que <x> RESOLVE, para nao recair no fallback silencioso ao 'build'
#     (`--agent <ausente>` nao falha). D1 e D2 sao inseparaveis: nunca "default sem guard".
$agentExplicit = $PSBoundParameters.ContainsKey('Agent') -and -not [string]::IsNullOrWhiteSpace($Agent)
if (-not $agentExplicit) { $Agent = 'reviewer-ro' }
$isReviewerPath = ($Agent -eq 'reviewer-ro')
# cwd HERDADO (o opencode nao tem -Cd; a leitura do reviewer-ro confina-se a ele). ATENCAO:
# no Windows, `opencode run` FALHA (stdout vazio / uv_spawn ENAMETOOLONG) quando este cwd e um
# git WORKTREE (.git gitlink). Rode de um dir plano sem .git (ex.: git archive HEAD -> dir).
# Ver SKILL.md, secao "LIMITE CONHECIDO - opencode run FALHA EM CWD DE GIT WORKTREE (WINDOWS)".
$cwd = (Get-Location).Path
if ($isReviewerPath) {
    $pc = Test-OpenCodeReviewerRoPrecheck -Exe $exe -WorkingDirectory $cwd
    if (-not $pc.pass) {
        throw "BLOCK: guard reviewer-ro fail-closed (motivo=$($pc.reason)): $($pc.detail)"
    }
} else {
    $res = Test-OpenCodeAgentResolves -Exe $exe -Name $Agent
    if (-not $res.ok) {
        throw "BLOCK: -Agent '$Agent' nao resolve (evita fallback silencioso ao 'build' full-access): $($res.detail)"
    }
}

# 2) Prompt via STDIN (arquivo), fora do argv. O opencode le o stdin quando o argumento
#    posicional de 'run' e omitido; -RedirectStandardInput entrega o arquivo e da EOF ao final
#    (anti-hang headless preservado: o CLI nao fica preso lendo um stdin herdado sem fim).
$ocArgs = @('run', '--format', 'json')
if (-not [string]::IsNullOrWhiteSpace($Model)) { $ocArgs += @('--model', $Model) }
if (-not [string]::IsNullOrWhiteSpace($Agent)) { $ocArgs += @('--agent', $Agent) }

$in  = (New-TemporaryFile).FullName
Set-Content -LiteralPath $in -Value $Message -Encoding utf8 -NoNewline
$out = $null
$err = $null
$attempt = 0

# Retry-once (opt-in por -MaxAttempts; default 1 = comportamento historico, sem re-tentativa).
# Re-tentar SO um veredito de conclusao truncada/sem-conclusao (nao-determinismo de cauda do
# opencode); NUNCA timeout, exit!=0, erro explicito de stream, 429 mascarado ou 'empty' (conclusao
# limpa). A decisao de re-tentar le $verdict.status DIRETAMENTE (nao captura o throw), entao os
# terminais lancados antes do veredito escapam do laco. Precedencia por tentativa:
#   (1) timeout / exit!=0 / erro explicito de stream  -> terminal (sai do laco)
#   (2) veredito de conclusao: 'ok' retorna; 'empty' terminal; so {truncated, no-completion} re-tentaveis
#   (3) ao DECIDIR re-tentar, checa 429 na janela      -> terminal (gate da re-tentativa). Sem
#       re-tentativa pendente (-MaxAttempts 1 / ultima tentativa), reporta o veredito de conclusao.
# -TimeoutSec e POR TENTATIVA (com -MaxAttempts 2 o tempo de parede pode dobrar).
try {
    while ($true) {
        $attempt++
        $startedAt = (Get-Date).ToUniversalTime()
        $out = (New-TemporaryFile).FullName
        $err = (New-TemporaryFile).FullName

        $p = Start-Process -FilePath $exe -ArgumentList $ocArgs -NoNewWindow -PassThru `
            -RedirectStandardInput $in -RedirectStandardOutput $out -RedirectStandardError $err
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill($true) } catch { }
            $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors @(Get-OpenCodeStreamErrorCandidates -Lines @(Get-Content -LiteralPath $out -Encoding utf8 -ErrorAction SilentlyContinue)) -StderrText ([string](Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue)) -SinceTime $startedAt
            if ($null -ne $limitHit) {
                throw (Format-OpenCodeLimitBlock -Kind ([string](Get-OcProp $limitHit 'kind')) -Message ([string](Get-OcProp $limitHit 'message')))
            }
            throw "BLOCK: opencode excedeu ${TimeoutSec}s e foi encerrado."
        }
        if ($p.ExitCode -ne 0) {
            if (-not $Raw) {
                $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors @(Get-OpenCodeStreamErrorCandidates -Lines @(Get-Content -LiteralPath $out -Encoding utf8 -ErrorAction SilentlyContinue)) -StderrText ([string](Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue)) -SinceTime $startedAt
                if ($null -ne $limitHit) {
                    throw (Format-OpenCodeLimitBlock -Kind ([string](Get-OcProp $limitHit 'kind')) -Message ([string](Get-OcProp $limitHit 'message')))
                }
            }
            throw "BLOCK: opencode saiu com codigo $($p.ExitCode).`nstderr:`n$(Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)"
        }

        # Pos-check (DEFESA-EM-PROFUNDIDADE, nao a barreira): no caminho revisor, le o CONTEUDO de
        # $err (descartado no finally) ANTES do Remove-Item e varre o warning de fallback silencioso.
        # Se aparecer, o --agent nao resolveu no runtime apesar do pre-check -> descartar a saida.
        if ($isReviewerPath) {
            $errText = Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if (Test-OpenCodeReviewerRoFallbackWarning -Text $errText) {
                throw "BLOCK: pos-check reviewer-ro: warning de fallback ao 'build' detectado no stderr (o --agent nao resolveu no runtime apesar do pre-check). Saida descartada por seguranca."
            }
        }

        $lines = Get-Content -LiteralPath $out -Encoding utf8
        # -Raw: stream literal da 1a execucao, SEM retry (o chamador quer o stream cru de uma chamada).
        if ($Raw) { return $lines }

        $events = ConvertFrom-OpenCodeStreamLines -Lines $lines

        # Erro explicito do agente no stream tem prioridade sobre a ausencia de texto e e terminal.
        $errMsg = Get-OpenCodeStreamErrorMessage -Events $events
        if ($errMsg) {
            $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors @(Get-OpenCodeStreamErrorCandidates -Lines @($lines)) -StderrText ([string](Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue)) -SinceTime $startedAt
            if ($null -ne $limitHit) {
                throw (Format-OpenCodeLimitBlock -Kind ([string](Get-OcProp $limitHit 'kind')) -Message ([string](Get-OcProp $limitHit 'message')))
            }
            throw "BLOCK: opencode retornou erro no stream: $errMsg"
        }

        $parts = @(Get-OpenCodeTextParts -Events $events)
        $finalText = Get-OpenCodeFinalText -TextParts $parts

        # Achado D: NAO devolver preambulo como resposta. Precedencia de conclusao SEMPRE sobre a
        # resposta final (Get-OpenCodeFinalText), nunca sobre a narracao do -AllText: reason!=stop ->
        # truncado; step_finish/reason ausente -> sem-conclusao; texto final vazio -> empty.
        $signal = Get-OpenCodeCompletionSignal -Events $events
        $verdict = Get-OpenCodeCompletionVerdict -HasStepFinish $signal.hasStepFinish -Reason $signal.reason -FinalText $finalText

        if ($verdict.status -eq 'ok') {
            # -AllText: narracao da tentativa BEM-SUCEDIDA; default: resposta final concatenada.
            if ($AllText) { return (Get-OpenCodeAllText -TextParts $parts) }
            return $finalText
        }

        # So 'truncated'/'no-completion' sao re-tentaveis; 'empty' (conclusao limpa) e terminal.
        $retryable = ($verdict.status -eq 'truncated' -or $verdict.status -eq 'no-completion')
        if ($retryable -and $attempt -lt $MaxAttempts) {
            $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors @(Get-OpenCodeStreamErrorCandidates -Lines @($lines)) -StderrText ([string](Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue)) -SinceTime $startedAt
            if ($null -ne $limitHit) {
                throw (Format-OpenCodeLimitBlock -Kind ([string](Get-OcProp $limitHit 'kind')) -Message ([string](Get-OcProp $limitHit 'message')))
            }
            [Console]::Error.WriteLine("OPENCODE_RETRY: attempt=$attempt status=$($verdict.status) reason=$($verdict.reason)")
            Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
            $out = $null
            $err = $null
            continue
        }

        # Esgotado ou nao-retryable (inclui 'empty'): lanca com o status da ULTIMA tentativa.
        $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors @(Get-OpenCodeStreamErrorCandidates -Lines @($lines)) -StderrText ([string](Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue)) -SinceTime $startedAt
        if ($null -ne $limitHit) {
            throw (Format-OpenCodeLimitBlock -Kind ([string](Get-OcProp $limitHit 'kind')) -Message ([string](Get-OcProp $limitHit 'message')))
        }
        if ($attempt -gt 1) {
            throw "$($verdict.message) (apos $attempt tentativas; ultimo status=$($verdict.status) reason=$($verdict.reason))"
        }
        throw $verdict.message
    }
}
finally {
    Remove-Item -LiteralPath $in -Force -ErrorAction SilentlyContinue
    if ($out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    if ($err) { Remove-Item -LiteralPath $err -Force -ErrorAction SilentlyContinue }
}
