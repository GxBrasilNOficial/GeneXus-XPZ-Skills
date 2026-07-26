#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono do Claude Code CLI e abre um watcher.
.DESCRIPTION
    Backend claude-code da skill xpz-llm-delegate. Cria arquivos de job em <TempDir>,
    executa `claude -p --output-format stream-json` desanexado e retorna jobId+pid.
    Por padrao abre Watch-ClaudeCodeJob.ps1 em janela visivel.

    CONFIDENCIALIDADE: passe pelo gate Resolve-LlmDelegateAuthorization.ps1 -Backend
    claude-code antes de enviar payload sensivel.
.PARAMETER Message
    Prompt a enviar (posicional). Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando ("(Get-Content ...)") na linha de comando do chamador. O texto do
    prompt segue persistido em <GUID>.request.json e <GUID>.stdin.txt como hoje; -MessagePath
    muda so a origem do texto.
.PARAMETER Model
    Modelo aceito pelo Claude Code. Default: claude-opus-4-8.
.PARAMETER PermissionMode
    Modo de permissao do Claude Code. Default: plan. bypassPermissions e recusado.
.PARAMETER Tools
    Lista de ferramentas disponiveis. Default: Read,Glob,Grep. Use "" para desabilitar todas
    (vira --tools "" na CLI) ou "default" para liberar o conjunto padrao completo da CLI.
    Mesmo contrato do adapter sincrono Invoke-ClaudeCode.ps1.
.PARAMETER Cd
    Diretorio de trabalho do processo Claude Code. Default: diretorio atual do chamador.
.PARAMETER ClaudeExe
    Forca caminho de claude.exe.
.PARAMETER NoWatcher
    Nao abrir a janela do watcher (apenas dispara o job).
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuario>\claude-code-jobs.
.PARAMETER KeepDays
    Idade maxima (dias) dos arquivos de job antes da auto-limpeza. Default 3.
.EXAMPLE
    .\Start-ClaudeCodeJob.ps1 "tarefa longa" -NoWatcher
.EXAMPLE
    .\Start-ClaudeCodeJob.ps1 -MessagePath .\prompt-grande.txt -Tools "" -NoWatcher
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model = 'claude-opus-4-8',
    [ValidateSet('default', 'acceptEdits', 'plan', 'auto', 'dontAsk', 'bypassPermissions')] [string] $PermissionMode = 'plan',
    [string] $Tools = 'Read,Glob,Grep',
    [string] $Cd,
    [string] $ClaudeExe,
    [switch] $NoWatcher,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'claude-code-jobs'),
    [int] $KeepDays = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Le como UTF-8 ANTES de montar
# request.json / stdin.txt (que persistem o texto de $Message).
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

if ($PSBoundParameters.ContainsKey('PermissionMode') -and $PermissionMode -eq 'bypassPermissions') {
    throw 'BLOCK: Start-ClaudeCodeJob.ps1 nao permite PermissionMode=bypassPermissions.'
}

$exe = Resolve-ClaudeCodeExe -Override $ClaudeExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}
try {
    $limite = (Get-Date).AddDays(-[Math]::Abs($KeepDays))
    Get-ChildItem -LiteralPath $TempDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limite } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
} catch { }

$jobId = [guid]::NewGuid().ToString('N')
$base = Join-Path $TempDir $jobId
$reqPath = "$base.request.json"
$streamPath = "$base.stream.jsonl"
$errPath = "$base.stderr.txt"
$stdinPath = "$base.stdin.txt"
$resultPath = "$base.result.json"

$request = [ordered]@{
    jobId = $jobId
    model = $Model
    prompt = $Message
    startedAt = (Get-Date).ToString('o')
    workingDirectory = $workDir
    streamPath = $streamPath
    resultPath = $resultPath
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8
Set-Content -LiteralPath $stdinPath -Value $Message -Encoding utf8 -NoNewline

$arguments = @(
    '-p',
    '--model', $Model,
    '--output-format', 'stream-json',
    '--no-session-persistence',
    '--permission-mode', $PermissionMode
)
# Sem limite de turnos: a CLI 2.1.215 nao anuncia mais `--max-turns` no `--help`. O adapter
# tinha um parametro -MaxTurns cujo valor era descartado em silencio por causa dessa sondagem,
# entao o parametro foi removido em vez de mantido mentindo (medido em 2026-07-25).
# A CLI aceita --tools "" para desabilitar todas as ferramentas. O valor vazio precisa ir
# aspado: Start-Process descarta string vazia do ArgumentList e, como --tools e variadica,
# ela passaria a consumir o argumento seguinte.
if ([string]::IsNullOrWhiteSpace($Tools)) {
    $arguments += @('--tools', '""')
} else {
    $arguments += @('--tools', $Tools)
}

$proc = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $workDir `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $streamPath `
    -RedirectStandardError $errPath -RedirectStandardInput $stdinPath
$procId = $proc.Id

$watcher = Join-Path $PSScriptRoot 'Watch-ClaudeCodeJob.ps1'
if (-not $NoWatcher) {
    if (Test-Path -LiteralPath $watcher -PathType Leaf) {
        Start-Process pwsh -WindowStyle Normal -ArgumentList @(
            '-NoExit', '-NoProfile', '-File', $watcher,
            '-JobId', $jobId, '-ProcessId', "$procId", '-TempDir', $TempDir
        ) | Out-Null
    } else {
        Write-Warning "Watcher nao encontrado em $watcher; job segue rodando sem janela."
    }
}

[pscustomobject]@{
    jobId = $jobId
    pid = $procId
    stream = $streamPath
    result = $resultPath
    watcher = (-not $NoWatcher)
} | ConvertTo-Json -Compress
