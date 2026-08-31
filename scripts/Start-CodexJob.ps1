#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono (nao-bloqueante) do Codex CLI e abre o watcher.
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Cria um job identificado por GUID em <TempDir> e
    dispara `codex exec --json` desanexado, com o stream JSONL crescendo em <GUID>.stream.jsonl
    e a resposta final escrita por -o em <GUID>.lastmsg.txt. Retorna imediatamente jobId+pid
    (nao bloqueia o chamador). Por padrao abre Watch-CodexJob.ps1 numa janela visivel quando a
    hora de inicio do processo for utilizavel; use -NoWatcher para suprimir.

    Para perguntas curtas (resposta na hora) use Invoke-Codex.ps1. Este script e para tarefas
    longas que voce quer disparar e acompanhar sem bloquear.

    Sandbox read-only fixo. CONFIDENCIALIDADE: este script NAO decide para onde o dado pode ir;
    passe antes pelo gate Resolve-LlmDelegateAuthorization.ps1 (-Backend codex).

    Arquivos do job (todos compartilham o mesmo GUID, em <TempDir>):
        <GUID>.request.json   pedido (schema 1, source start-job, prompt persistido)
        <GUID>.stream.jsonl   eventos do codex exec --json, cresce incrementalmente
        <GUID>.lastmsg.txt    resposta final (output-last-message do codex)
        <GUID>.stderr.txt     erros do processo
        <GUID>.stdin.txt      o prompt enviado via stdin
        <GUID>.identity.json  fallback de pid/processStartTimeUtc se o rewrite do request falhar
        <GUID>.result.json    resposta final + status (gravado pelo watcher no fim)
.PARAMETER Message
    Prompt a enviar (posicional). Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando ("(Get-Content ...)") na linha de comando do chamador. O texto do
    prompt segue persistido em <GUID>.request.json e <GUID>.stdin.txt; -MessagePath muda so a
    origem do texto, nao o transporte.
.PARAMETER Model
    Modelo do Codex (nu). Opcional; quando omitido, o adapter nao passa -m e deixa o
    default do proprio Codex/config valer.
.PARAMETER Oss
    Usa provider open-source local (--oss). Implica modelo local.
.PARAMETER LocalProvider
    Provider OSS local quando -Oss: 'ollama' ou 'lmstudio'.
.PARAMETER Profile
    Profile da config do Codex (-p <id>).
.PARAMETER Cd
    Diretorio de trabalho do agente (-C <dir>).
.PARAMETER CodexExe
    Forca um caminho de codex.exe (contorna a descoberta automatica).
.PARAMETER NoWatcher
    Nao abrir a janela do watcher (apenas dispara o job).
.PARAMETER TempDir
    Pasta dos arquivos de job. Sem default no param(); o default efetivo vive em
    Resolve-CodexJobTempDir (Bound nao-branco -> env XPZ_CODEX_JOBS_DIR -> %TEMP%\codex-jobs),
    sempre absoluto.
.PARAMETER KeepDays
    Idade maxima (dias) dos arquivos de job antes da auto-limpeza por classe. Default 3
    (ValidateRange 1..3650). Limpeza best-effort; falha nao bloqueia o spawn.
.EXAMPLE
    .\Start-CodexJob.ps1 "tarefa longa" -NoWatcher
.EXAMPLE
    .\Start-CodexJob.ps1 -MessagePath .\prompt-grande.txt -NoWatcher
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model,
    [switch] $Oss,
    [ValidateSet('ollama', 'lmstudio')] [string] $LocalProvider,
    [string] $Profile,
    [string] $Cd,
    [string] $CodexExe,
    [switch] $NoWatcher,
    [string] $TempDir,
    [ValidateRange(1, 3650)] [int] $KeepDays = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Zero ficheiros de job ate o exe.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

$exe = Resolve-CodexExe -Override $CodexExe

$tempOverride = $null
if ($PSBoundParameters.ContainsKey('TempDir') -and -not [string]::IsNullOrWhiteSpace($TempDir)) {
    $tempOverride = $TempDir.Trim()
}
$TempDir = Resolve-CodexJobTempDir -Override $tempOverride

try {
    Invoke-CodexJobsKeepDaysCleanup -TempDir $TempDir -KeepDays $KeepDays
} catch { }

$jobId       = [guid]::NewGuid().ToString('N')
$base        = Join-Path $TempDir $jobId
$reqPath     = "$base.request.json"
$streamPath  = "$base.stream.jsonl"
$lastMsgPath = "$base.lastmsg.txt"
$errPath     = "$base.stderr.txt"
$stdinPath   = "$base.stdin.txt"
$resultPath  = "$base.result.json"
$identityPath = "$base.identity.json"

$startedAt = Format-CodexUtcTimestamp -Value (Get-Date).ToUniversalTime()
$request = [ordered]@{
    schemaVersion = 1
    source        = 'start-job'
    jobId         = $jobId
    model         = if ($Model) { $Model } else { $null }
    prompt        = $Message
    startedAt     = $startedAt
    streamPath    = $streamPath
    lastMsgPath   = $lastMsgPath
    resultPath    = $resultPath
}
Write-CodexJsonAtomic -Object $request -Path $reqPath

Set-Content -LiteralPath $stdinPath -Value $Message -Encoding utf8 -NoNewline

$cxArgs = @(
    'exec', '--skip-git-repo-check', '-s', 'read-only', '--color', 'never',
    '--json', '-o', $lastMsgPath
)
if ($Model) { $cxArgs += @('-m', $Model) }
if ($Oss) { $cxArgs += '--oss' }
if ($LocalProvider) { $cxArgs += @('--local-provider', $LocalProvider) }
if ($Profile) { $cxArgs += @('-p', $Profile) }
if ($Cd) { $cxArgs += @('-C', $Cd) }
$cxArgs += '-'

$procId = $null
$processStartTimeUtc = $null
$spawnFailed = $false

try {
    if ($env:XPZ_TEST_CODEX_START_FAIL_SPAWN -eq '1') {
        throw 'BLOCK: falha ao iniciar processo Codex.'
    }
    $proc = Start-Process -FilePath $exe -ArgumentList $cxArgs -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $streamPath -RedirectStandardError $errPath -RedirectStandardInput $stdinPath
    $procId = $proc.Id
    try {
        $st = $proc.StartTime
        if ($st.Kind -ne [DateTimeKind]::Utc) { $st = $st.ToUniversalTime() }
        $processStartTimeUtc = Format-CodexUtcTimestamp -Value $st
    } catch {
        $processStartTimeUtc = $null
    }
} catch {
    $spawnFailed = $true
}

if ($spawnFailed) {
    $rewriteOk = $false
    try {
        if ($env:XPZ_TEST_CODEX_START_FAIL_REQUEST_REWRITE -eq '1') {
            throw 'hook: request rewrite fail'
        }
        $request['captureOutcome'] = 'error'
        Write-CodexJsonAtomic -Object $request -Path $reqPath -Force
        $rewriteOk = $true
    } catch {
        $rewriteOk = $false
    }

    if (-not $rewriteOk) {
        [Console]::Error.WriteLine('BLOCK: falha ao iniciar processo Codex.')
        [Console]::Error.WriteLine('BLOCK: falha ao gravar request.json.')
        try {
            $ident = [ordered]@{ jobId = $jobId }
            if ($null -ne $procId) { $ident['pid'] = $procId }
            if (-not [string]::IsNullOrWhiteSpace($processStartTimeUtc)) {
                $ident['processStartTimeUtc'] = $processStartTimeUtc
            }
            Write-CodexJsonAtomic -Object $ident -Path $identityPath -Force
        } catch { }
        throw 'BLOCK: falha ao iniciar processo Codex.'
    }

    throw 'BLOCK: falha ao iniciar processo Codex.'
}

# Spawn ok: gravar pid + processStartTimeUtc no request (Force).
$rewritePidOk = $false
try {
    if ($env:XPZ_TEST_CODEX_START_FAIL_REQUEST_REWRITE -eq '1') {
        throw 'hook: request rewrite fail'
    }
    $request['pid'] = $procId
    if (-not [string]::IsNullOrWhiteSpace($processStartTimeUtc)) {
        $request['processStartTimeUtc'] = $processStartTimeUtc
    }
    Write-CodexJsonAtomic -Object $request -Path $reqPath -Force
    $rewritePidOk = $true
} catch {
    $rewritePidOk = $false
}

if (-not $rewritePidOk) {
    [Console]::Error.WriteLine('BLOCK: falha ao gravar request.json.')
    try {
        $ident = [ordered]@{
            jobId = $jobId
            pid   = $procId
        }
        if (-not [string]::IsNullOrWhiteSpace($processStartTimeUtc)) {
            $ident['processStartTimeUtc'] = $processStartTimeUtc
        }
        Write-CodexJsonAtomic -Object $ident -Path $identityPath -Force
    } catch { }
}

# Watcher: true so se a janela foi tentada E o Start-Process do watcher teve sucesso.
$watcherFlag = $false
if (-not $NoWatcher) {
    $resolved = Resolve-CodexPidAndStartTime -TempDir $TempDir -JobId $jobId
    $expectedUtc = $resolved.processStartTimeUtc
    if (-not [string]::IsNullOrWhiteSpace($expectedUtc)) {
        $watcherScript = Join-Path $PSScriptRoot 'Watch-CodexJob.ps1'
        if (Test-Path -LiteralPath $watcherScript -PathType Leaf) {
            try {
                $watchPid = if ($null -ne $resolved.pid) { $resolved.pid } else { $procId }
                Start-Process pwsh -WindowStyle Normal -ArgumentList @(
                    '-NoExit', '-NoProfile', '-File', $watcherScript,
                    '-JobId', $jobId,
                    '-ProcessId', "$watchPid",
                    '-TempDir', $TempDir,
                    '-ExpectedStartTimeUtc', $expectedUtc
                ) | Out-Null
                $watcherFlag = $true
            } catch {
                Write-Warning 'Falha ao lancar o watcher; job segue rodando sem janela.'
            }
        } else {
            Write-Warning "Watcher nao encontrado em $watcherScript; job segue rodando sem janela."
        }
    }
}

[pscustomobject]@{
    jobId   = $jobId
    pid     = $procId
    stream  = $streamPath
    lastmsg = $lastMsgPath
    result  = $resultPath
    watcher = [bool]$watcherFlag
} | ConvertTo-Json -Compress
