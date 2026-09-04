#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Codex CLI (codex exec, sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Resolve o codex.exe compativel (app desktop,
    nao o shim npm), envia o prompt via stdin e captura a resposta final pelo arquivo de
    output-last-message (-o) no grupo duravel sob TempDir, com stream `--json` em
    <GUID>.stream.jsonl (mesmo transporte do Start-CodexJob). Bloqueia ate a resposta (ou ate
    -TimeoutSec). Se o timeout matar o processo mas o lastmsg ja tiver bytes, o parecer e
    recuperado (captureOutcome=success + sentinela XPZ_CODEX_RECOVERED_AFTER_TIMEOUT); sem
    bytes no lastmsg, lanca timeout como antes.

    Esta e a invocacao sincrona canonica (o painel chama este adapter com TimeoutSec alto).
    Para disparar sem bloquear o chamador, use Start-CodexJob.ps1.

    Sandbox: read-only fixo (delegacao e leitura/segunda-opiniao, nunca escrita). O Codex
    exec e agentico e PODE ler o filesystem do workspace; isso NAO contorna o gate de
    confidencialidade.

    CONFIDENCIALIDADE: este script NAO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteudo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1 (use -Backend codex), conforme a skill.

    request.json (source invoke-sync) NAO persiste o prompt; o prompt vive em invoke-in.txt
    ate a limpeza. Sentinelas XPZ_CODEX_* saem por [Console]::Error (nunca Write-Error).
    Stdout de sucesso: so o parecer.
.PARAMETER Message
    Prompt a enviar ao agente (posicional). Enviado via stdin. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Util para
    prompts grandes e para evitar substituicao de comando ("(Get-Content ...)") na linha de
    comando do chamador (sem comando composto = sem prompt de autorizacao desnecessario no
    harness). O Codex ja entrega o prompt por stdin, entao -MessagePath nao muda o transporte;
    so muda a origem do texto.
.PARAMETER Model
    Modelo do Codex (nu). Opcional; quando omitido, o adapter nao passa -m e deixa o
    default do proprio Codex/config valer.
.PARAMETER Oss
    Usa provider open-source local (codex exec --oss). Implica modelo local.
.PARAMETER LocalProvider
    Provider OSS local quando -Oss: 'ollama' ou 'lmstudio'.
.PARAMETER Profile
    Profile da config do Codex (codex exec -p <id>).
.PARAMETER Cd
    Diretorio de trabalho do agente (codex exec -C <dir>).
.PARAMETER CodexExe
    Forca um caminho de codex.exe (contorna a descoberta automatica).
.PARAMETER TimeoutSec
    Tempo maximo de espera pela resposta (default 180s). Modelos externos podem ser lentos.
.PARAMETER TempDir
    Pasta dos arquivos de job. Sem default no param(); o default efetivo vive em
    Resolve-CodexJobTempDir (Bound nao-branco -> env XPZ_CODEX_JOBS_DIR -> %TEMP%\codex-jobs),
    sempre absoluto.
.PARAMETER KeepDays
    Idade maxima (dias) dos arquivos de job antes da auto-limpeza por classe. Default 3
    (ValidateRange 1..3650). Limpeza best-effort; falha nao bloqueia a invocacao.
.PARAMETER RetentionMode
    public (default): lastmsg/request permanecem no disco; so invoke-* e apagado apos
    rewrite de captureOutcome. kb-sensitive: apaga lastmsg/invoke-* e o request apos
    rewrite; em falha de execucao copia o lastmsg para a Exception.Message.
.EXAMPLE
    .\Invoke-Codex.ps1 "resuma este log"
.EXAMPLE
    .\Invoke-Codex.ps1 "oi" -Model gpt-5.5 -TimeoutSec 300
.EXAMPLE
    .\Invoke-Codex.ps1 -MessagePath .\prompt-grande.txt -Model gpt-5.5
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
    [ValidateRange(1, 3600)] [int] $TimeoutSec = 180,
    [string] $TempDir,
    [ValidateRange(1, 3650)] [int] $KeepDays = 3,
    [ValidateSet('public', 'kb-sensitive')] [string] $RetentionMode = 'public'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

# Zero ficheiros de job ate o exe resolver.
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
$lastMsgPath = "$base.lastmsg.txt"
$streamPath  = "$base.stream.jsonl"
$invokeIn    = "$base.invoke-in.txt"
$invokeOut   = "$base.invoke-out.txt"
$invokeErr   = "$base.invoke-err.txt"

$startedAt = Format-CodexUtcTimestamp -Value (Get-Date).ToUniversalTime()
$requestObj = [ordered]@{
    schemaVersion = 1
    source        = 'invoke-sync'
    jobId         = $jobId
    model         = if ($Model) { $Model } else { $null }
    startedAt     = $startedAt
    lastMsgPath   = $lastMsgPath
}
Write-CodexJsonAtomic -Object $requestObj -Path $reqPath

Set-Content -LiteralPath $invokeIn -Value $Message -Encoding utf8 -NoNewline
Set-Content -LiteralPath $invokeOut -Value '' -Encoding utf8 -NoNewline
Set-Content -LiteralPath $invokeErr -Value '' -Encoding utf8 -NoNewline

$arguments = @(
    'exec', '--skip-git-repo-check', '-s', 'read-only', '--color', 'never',
    '--json', '-o', $lastMsgPath
)
if ($Model) { $arguments += @('-m', $Model) }
if ($Oss) { $arguments += '--oss' }
if ($LocalProvider) { $arguments += @('--local-provider', $LocalProvider) }
if ($Profile) { $arguments += @('-p', $Profile) }
if ($Cd) { $arguments += @('-C', $Cd) }
$arguments += '-'

$script:captureOutcome = 'success'
$script:pendingExceptionMessage = $null
$script:successText = $null
$script:recoveredAfterTimeout = $false

function Append-CodexPendingBlock {
    param([Parameter(Mandatory)] [string] $Block)
    if ($null -eq $script:pendingExceptionMessage) {
        $script:pendingExceptionMessage = $Block
    } else {
        $script:pendingExceptionMessage = $script:pendingExceptionMessage + "`n" + $Block
    }
}

function Ensure-CodexPendingSentinels {
    if ($null -eq $script:pendingExceptionMessage) { return }
    if ($script:pendingExceptionMessage -notmatch '(?m)^XPZ_CODEX_LASTMSG=') {
        $script:pendingExceptionMessage = $script:pendingExceptionMessage + "`nXPZ_CODEX_LASTMSG=$lastMsgPath"
    }
    if ($script:pendingExceptionMessage -notmatch '(?m)^XPZ_CODEX_REQUEST=') {
        $script:pendingExceptionMessage = $script:pendingExceptionMessage + "`nXPZ_CODEX_REQUEST=$reqPath"
    }
}

function Write-CodexInvokeRequestRewrite {
    param(
        [Parameter(Mandatory)] [string] $Outcome,
        [bool] $IncludeRetentionFlag = $false,
        [bool] $RetentionCleanupFailed = $false
    )
    if ($env:XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE -eq '1') {
        throw 'hook: request rewrite fail'
    }
    $requestObj['captureOutcome'] = $Outcome
    if ($script:recoveredAfterTimeout) {
        $requestObj['recoveredAfterTimeout'] = $true
    } elseif ($requestObj.Contains('recoveredAfterTimeout')) {
        $requestObj.Remove('recoveredAfterTimeout')
    }
    if ($IncludeRetentionFlag) {
        $requestObj['retentionCleanupFailed'] = [bool]$RetentionCleanupFailed
    } elseif ($requestObj.Contains('retentionCleanupFailed')) {
        $requestObj.Remove('retentionCleanupFailed')
    }
    Write-CodexJsonAtomic -Object $requestObj -Path $reqPath -Force
}

try {
    if ($env:XPZ_TEST_CODEX_INVOKE_UNEXPECTED -eq '1') {
        throw 'BLOCK: falha inesperada de teste.'
    }

    $p = Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $streamPath -RedirectStandardError $invokeErr -RedirectStandardInput $invokeIn

    $timedOut = $false
    if ($env:XPZ_TEST_CODEX_FORCE_TIMEOUT -eq '1') {
        # Hook de teste: espera o fake gravar -o e sair; classifica como timeout com ficheiros destrancados.
        try { [void]$p.WaitForExit(60000) } catch { }
        $timedOut = $true
    }
    elseif (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill($true) } catch {
            try { $p.Kill() } catch { }
        }
        try { [void]$p.WaitForExit(5000) } catch { }
        Start-Sleep -Milliseconds 300
        $timedOut = $true
    }

    # Stream JSONL e a saida primaria; invoke-out fica vazio (legado do contrato pre--json).
    $stdoutText = (Get-Content -LiteralPath $streamPath -Raw -ErrorAction SilentlyContinue)
    if ([string]::IsNullOrWhiteSpace($stdoutText)) {
        $stdoutText = (Get-Content -LiteralPath $invokeOut -Raw -ErrorAction SilentlyContinue)
    }
    $stderrText = (Get-Content -LiteralPath $invokeErr -Raw -ErrorAction SilentlyContinue)

    $final = ''
    if (Test-Path -LiteralPath $lastMsgPath -PathType Leaf) {
        $final = (Get-Content -LiteralPath $lastMsgPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue)
    }
    if ($null -eq $final) { $final = '' }

    if ($timedOut) {
        # FORCE_TIMEOUT preserva o contrato historico dos self-tests (sempre timeout).
        # Em timeout real, se o lastmsg ja tiver bytes, recupera o parecer (Kill prematuro).
        if ($env:XPZ_TEST_CODEX_FORCE_TIMEOUT -eq '1') {
            $script:captureOutcome = 'timeout'
            $script:pendingExceptionMessage = "BLOCK: codex excedeu ${TimeoutSec}s e foi encerrado."
        }
        elseif (-not [string]::IsNullOrWhiteSpace($final)) {
            $script:captureOutcome = 'success'
            $script:successText = $final.TrimEnd("`r", "`n")
            $script:recoveredAfterTimeout = $true
        }
        else {
            $script:captureOutcome = 'timeout'
            $script:pendingExceptionMessage = "BLOCK: codex excedeu ${TimeoutSec}s e foi encerrado."
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($final)) {
        $script:successText = $final.TrimEnd("`r", "`n")
    }
    elseif ($p.ExitCode -eq 0) {
        $script:captureOutcome = 'empty'
        $script:pendingExceptionMessage = 'BLOCK: codex nao produziu resposta (output-last-message vazio).'
    }
    else {
        $script:captureOutcome = 'error'
        $errMsg = Get-CodexExecErrorMessage -StdoutText $stdoutText -StderrText $stderrText
        if ($errMsg) {
            $script:pendingExceptionMessage = "BLOCK: codex retornou erro: $errMsg"
        } else {
            $stdoutClean = if ($stdoutText) { $stdoutText.Trim() } else { '' }
            $stderrClean = if ($stderrText) { $stderrText.Trim() } else { '' }
            if ($stdoutClean -or $stderrClean) {
                $parts = @()
                if ($stdoutClean) {
                    $stdoutLines = @($stdoutClean -split "`r?`n" | Select-Object -First 8) -join "`n"
                    $parts += "stdout:`n$stdoutLines"
                }
                if ($stderrClean) {
                    $stderrLines = @($stderrClean -split "`r?`n" | Select-Object -First 8) -join "`n"
                    $parts += "stderr:`n$stderrLines"
                }
                $detailsText = $parts -join "`n---`n"
                $script:pendingExceptionMessage = "BLOCK: codex saiu com codigo $($p.ExitCode).`n$detailsText"
            } else {
                $script:pendingExceptionMessage = "BLOCK: codex saiu com codigo $($p.ExitCode) sem resposta."
            }
        }
    }
}
catch {
    $script:captureOutcome = 'error'
    $msg = [string]$_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = 'erro inesperado' }
    if ($msg -notlike 'BLOCK:*') {
        $msg = "BLOCK: $msg"
    }
    $script:pendingExceptionMessage = $msg
}
finally {
    # NUNCA throw a partir do finally.

    # 2b. Sentinelas em stderr (sucesso e falha).
    try {
        [Console]::Error.WriteLine("XPZ_CODEX_LASTMSG=$lastMsgPath")
        [Console]::Error.WriteLine("XPZ_CODEX_REQUEST=$reqPath")
        if ($script:recoveredAfterTimeout) {
            [Console]::Error.WriteLine('XPZ_CODEX_RECOVERED_AFTER_TIMEOUT=1')
        }
    } catch { }

    if ($RetentionMode -eq 'public') {
        $rewriteOk = $false
        try {
            Write-CodexInvokeRequestRewrite -Outcome $script:captureOutcome -IncludeRetentionFlag:$false
            $rewriteOk = $true
        } catch {
            $rewriteOk = $false
        }

        if (-not $rewriteOk) {
            if ($null -ne $script:pendingExceptionMessage) {
                Append-CodexPendingBlock -Block 'BLOCK: falha ao gravar request.json.'
            }
            # Sucesso: nao bloqueia successText; nao apaga o grupo.
        } else {
            foreach ($f in @($invokeIn, $invokeOut, $invokeErr)) {
                Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
            }
            # stream.jsonl permanece em public (paridade Start-CodexJob / diagnostico).
        }
    }
    else {
        # kb-sensitive
        $isExecFailure = ($null -ne $script:pendingExceptionMessage) -or (
            $script:captureOutcome -eq 'timeout' -or
            $script:captureOutcome -eq 'error' -or
            $script:captureOutcome -eq 'empty'
        )

        if ($isExecFailure) {
            if ((Test-Path -LiteralPath $lastMsgPath -PathType Leaf)) {
                $captured = $null
                try {
                    $captured = Get-Content -LiteralPath $lastMsgPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                } catch { $captured = $null }
                if (-not [string]::IsNullOrWhiteSpace($captured)) {
                    Ensure-CodexPendingSentinels
                    Append-CodexPendingBlock -Block 'XPZ_CODEX_CAPTURED_TEXT_BEGIN'
                    $script:pendingExceptionMessage = $script:pendingExceptionMessage + "`n" + $captured
                }
            }
        }

        $rewriteOk = $false
        try {
            Write-CodexInvokeRequestRewrite -Outcome $script:captureOutcome -IncludeRetentionFlag:$true -RetentionCleanupFailed:$false
            $rewriteOk = $true
        } catch {
            $rewriteOk = $false
        }

        if (-not $rewriteOk) {
            try {
                if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
                    [Console]::Error.WriteLine("XPZ_CODEX_REQUEST=$reqPath")
                }
                if (Test-Path -LiteralPath $lastMsgPath -PathType Leaf) {
                    [Console]::Error.WriteLine("XPZ_CODEX_LASTMSG=$lastMsgPath")
                }
            } catch { }
            Append-CodexPendingBlock -Block 'BLOCK: falha ao gravar request.json antes da limpeza kb-sensitive.'
        }
        else {
            $deleteFailed = $false
            foreach ($pass in 1..5) {
                $deleteFailed = $false
                foreach ($f in @($invokeIn, $invokeOut, $invokeErr, $lastMsgPath, $streamPath)) {
                    try {
                        if (Test-Path -LiteralPath $f -PathType Leaf) {
                            Remove-Item -LiteralPath $f -Force -ErrorAction Stop
                        }
                    } catch {
                        $deleteFailed = $true
                    }
                }
                if (-not $deleteFailed) { break }
                Start-Sleep -Milliseconds 200
            }
            if (-not $deleteFailed) {
                try {
                    if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
                        Remove-Item -LiteralPath $reqPath -Force -ErrorAction Stop
                    }
                } catch {
                    $deleteFailed = $true
                }
            }

            if ($deleteFailed) {
                try {
                    Write-CodexInvokeRequestRewrite -Outcome $script:captureOutcome -IncludeRetentionFlag:$true -RetentionCleanupFailed:$true
                } catch { }
                Append-CodexPendingBlock -Block 'BLOCK: falha ao limpar artefatos kb-sensitive.'
                try {
                    if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
                        [Console]::Error.WriteLine("XPZ_CODEX_REQUEST=$reqPath")
                    }
                    if (Test-Path -LiteralPath $lastMsgPath -PathType Leaf) {
                        [Console]::Error.WriteLine("XPZ_CODEX_LASTMSG=$lastMsgPath")
                    }
                } catch { }
            }
        }
    }

    if ($null -ne $script:pendingExceptionMessage) {
        Ensure-CodexPendingSentinels
    }
}

if ($null -ne $script:pendingExceptionMessage) {
    throw $script:pendingExceptionMessage
}
elseif ($null -ne $script:successText) {
    return $script:successText
}
else {
    throw 'BLOCK: Invoke-Codex sem parecer nem erro pendente.'
}
