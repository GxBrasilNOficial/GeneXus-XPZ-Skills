#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono (nao-bloqueante) do opencode e abre o watcher.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Cria um job identificado por GUID em
    <TempDir> e dispara `opencode run` desanexado, com o prompt entregue por STDIN (arquivo) e o
    stream JSON crescendo em <GUID>.stream.jsonl. Entregar o prompt por stdin (fora do argv)
    resolve o limite ~32KB de linha de comando do Windows e usa redirecao EXPLICITA a arquivo
    (Start-Process -RedirectStandard*). Retorna imediatamente jobId+pid do runner pwsh (não bloqueia
    o chamador).
    Por padrão abre Watch-OpenCodeJob.ps1 numa janela visivel para acompanhar ao vivo; use
    -NoWatcher para suprimir. Espelha o padrao stdin-based de Start-CodexJob.ps1.

    Para perguntas curtas (resposta na hora) use Invoke-OpenCode.ps1. Este script e para
    tarefas longas (ex: 3-6 min) que você quer disparar e acompanhar sem bloquear.

    CONFIDENCIALIDADE: este script NÃO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteúdo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.

    Arquivos do job (todos compartilham o mesmo GUID, em <TempDir>):
        <GUID>.request.json   o que foi pedido (model, prompt, agent)
        <GUID>.stream.jsonl   saida do opencode, cresce incrementalmente
        <GUID>.stderr.txt     erros do processo
        <GUID>.stdin.txt      o prompt enviado via stdin
        <GUID>.exitcode.txt   exit code observado do processo opencode, gravado pelo runner
        <GUID>.result.json    resultado aceito/rejeitado + custo (gravado pelo watcher no fim)
.PARAMETER Message
    Prompt a enviar (posicional). Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Util para prompts
    grandes (acima do limite ~32KB de linha de comando) e para evitar substituicao de comando.
.PARAMETER Model
    Modelo provider/modelo. Opcional: omitido usa o default da config do opencode.
.PARAMETER Agent
    Nome do agente do opencode. Opcional.
.PARAMETER OpenCodeExe
    Forca um caminho de opencode.exe (contorna a descoberta automatica por PATH/npm).
.PARAMETER NoWatcher
    Não abrir a janela do watcher (apenas dispara o job). Sem watcher nao ha result.json promovido nem deteccao de limite nesta frente.
.PARAMETER WatchTimeoutSec
    Timeout opt-in do observador (0 = desligado). Incompativel com -NoWatcher quando maior que 0.
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuário>\opencode-jobs.
.PARAMETER KeepDays
    Idade máxima (dias) dos arquivos de job antes da auto-limpeza. Default 3.
.EXAMPLE
    .\Start-OpenCodeJob.ps1 "tarefa longa" -NoWatcher   # dispara sem janela
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model,
    [string] $Agent,
    [string] $OpenCodeExe,
    [switch] $NoWatcher,
    [ValidateRange(0, 86400)] [int] $WatchTimeoutSec = 0,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'opencode-jobs'),
    [int]    $KeepDays = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($WatchTimeoutSec -gt 0 -and $NoWatcher) {
    throw 'BLOCK: -WatchTimeoutSec exige watcher; omita -NoWatcher ou use WatchTimeoutSec=0.'
}

# Guard least-privilege do reviewer-ro (default escopado + pre-check fail-closed no spawn)
. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')
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

# 1b) D1/D2: default -Agent reviewer-ro ESCOPADO + pre-check fail-closed ANTES do Start-Process (o
#     spawn e a barreira; o assincrono nao tem finally-remove, entao o pos-check e diagnostico no
#     Watch-OpenCodeJob.ps1). Opt-out consciente com -Agent <x> explicito (confirma que resolve).
$agentExplicit = $PSBoundParameters.ContainsKey('Agent') -and -not [string]::IsNullOrWhiteSpace($Agent)
if (-not $agentExplicit) { $Agent = 'reviewer-ro' }
$cwd = (Get-Location).Path
if ($Agent -eq 'reviewer-ro') {
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

# 2) Pasta de jobs
if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# 2b) Auto-limpeza: remove arquivos de jobs com mais de -KeepDays dias.
#     Remove por arquivo (LiteralPath); jobs em andamento têm arquivos recentes e são preservados.
try {
    $limite = (Get-Date).AddDays(-[Math]::Abs($KeepDays))
    Get-ChildItem -LiteralPath $TempDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limite } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
} catch { }

# 3) Identidade do job (GUID sem hifens) e caminhos
$jobId      = [guid]::NewGuid().ToString('N')
$base       = Join-Path $TempDir $jobId
$reqPath    = "$base.request.json"
$streamPath = "$base.stream.jsonl"
$errPath    = "$base.stderr.txt"
$stdinPath  = "$base.stdin.txt"
$resultPath = "$base.result.json"
$exitCodePath = "$base.exitcode.txt"
$argsPath = "$base.args.json"
$runnerPath = "$base.runner.ps1"

# 4) request.json
$agentLabel = if ($Agent) { $Agent } else { $null }
$request = [ordered]@{
    jobId      = $jobId
    model      = if ($Model) { $Model } else { $null }
    modelLabel = if ($Model) { $Model } else { '(default da config)' }
    agent      = $agentLabel
    prompt     = $Message
    startedAt  = (Get-Date).ToString('o')
    streamPath = $streamPath
    stderrPath = $errPath
    stdinPath  = $stdinPath
    resultPath = $resultPath
    exitCodePath = $exitCodePath
    argsPath = $argsPath
    exe        = $exe
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8

# 5) stdin = o prompt (UTF-8 sem BOM). O opencode le o prompt do stdin quando o argumento
#    posicional de 'run' e omitido; o fim do arquivo da EOF (anti-hang headless preservado).
Set-Content -LiteralPath $stdinPath -Value $Message -Encoding utf8 -NoNewline

# 6) Dispara o opencode desanexado (janela oculta): prompt por stdin, stream a arquivo.
#    Um runner minimo grava <GUID>.exitcode.txt para o watcher, pois um processo separado que
#    recebe apenas PID nao consegue recuperar ExitCode de forma confiavel no Windows.
$ocArgs = @('run', '--format', 'json')
if (-not [string]::IsNullOrWhiteSpace($Model)) { $ocArgs += @('--model', $Model) }
if (-not [string]::IsNullOrWhiteSpace($Agent)) { $ocArgs += @('--agent', $Agent) }
$ocArgs | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $argsPath -Encoding utf8

$runner = @'
param(
    [Parameter(Mandatory)] [string] $Exe,
    [Parameter(Mandatory)] [string] $ArgsPath,
    [Parameter(Mandatory)] [string] $StdinPath,
    [Parameter(Mandatory)] [string] $StdoutPath,
    [Parameter(Mandatory)] [string] $StderrPath,
    [Parameter(Mandatory)] [string] $ExitCodePath
)
$ErrorActionPreference = 'Stop'
$OpenCodeArgs = @(Get-Content -LiteralPath $ArgsPath -Raw -Encoding utf8 | ConvertFrom-Json | ForEach-Object { [string]$_ })
$p = Start-Process -FilePath $Exe -ArgumentList $OpenCodeArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardInput $StdinPath -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
$p.WaitForExit()
Set-Content -LiteralPath $ExitCodePath -Value ([string]$p.ExitCode) -Encoding ascii -NoNewline
exit ([int]$p.ExitCode)
'@
Set-Content -LiteralPath $runnerPath -Value $runner -Encoding utf8

$runnerArgs = @(
    '-NoProfile', '-File', $runnerPath,
    '-Exe', $exe,
    '-ArgsPath', $argsPath,
    '-StdinPath', $stdinPath,
    '-StdoutPath', $streamPath,
    '-StderrPath', $errPath,
    '-ExitCodePath', $exitCodePath
)
$t0 = (Get-Date).ToUniversalTime()
$request.startedAt = $t0.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8
$proc = Start-Process -FilePath pwsh -ArgumentList $runnerArgs -WindowStyle Hidden -PassThru
$procId = $proc.Id
$expectedStartUtc = $null
try {
    $st = $proc.StartTime
    if ($st.Kind -ne [DateTimeKind]::Utc) { $st = $st.ToUniversalTime() }
    $expectedStartUtc = $st.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
} catch {
    [Console]::Error.WriteLine('AVISO: StartTime do runner indisponivel; kill por identidade ficara nao verificavel.')
}

# 7) Abre o watcher numa janela visivel (a menos que -NoWatcher)
$watcher = Join-Path $PSScriptRoot 'Watch-OpenCodeJob.ps1'
if (-not $NoWatcher) {
    if (Test-Path -LiteralPath $watcher -PathType Leaf) {
        $watchArgs = [System.Collections.Generic.List[string]]::new()
        [void]$watchArgs.AddRange([string[]]@(
            '-NoExit', '-NoProfile', '-File', $watcher,
            '-JobId', $jobId, '-ProcessId', "$procId", '-TempDir', $TempDir,
            '-WatchTimeoutSec', "$WatchTimeoutSec"
        ))
        if (-not [string]::IsNullOrWhiteSpace($expectedStartUtc)) {
            [void]$watchArgs.Add('-ExpectedStartTimeUtc')
            [void]$watchArgs.Add($expectedStartUtc)
        }
        Start-Process pwsh -WindowStyle Normal -ArgumentList @($watchArgs) | Out-Null
    } else {
        Write-Warning "Watcher nao encontrado em $watcher; job segue rodando sem janela."
    }
}

# 8) Devolve a identidade do job ao chamador (JSON compacto numa linha)
[pscustomobject]@{
    jobId  = $jobId
    pid    = $procId
    stream = $streamPath
    result = $resultPath
    watcher = (-not $NoWatcher)
} | ConvertTo-Json -Compress
