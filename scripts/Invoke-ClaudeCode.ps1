#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Claude Code CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend claude-code da skill xpz-llm-delegate. Envia o prompt por stdin para evitar
    payload em argumento de processo, usa `claude -p` e captura stdout. Por padrao roda em
    modo de consulta curta restrita: sem persistencia de sessao, permission-mode plan e
    ferramentas somente leitura. Nao limita turnos agenticos: a CLI 2.1.215 removeu
    `--max-turns` do `--help` e o adapter nao tem como negociar esse limite (ver CHANGELOG).

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir para Anthropic. Antes de
    enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1 -Backend
    claude-code.
.PARAMETER Message
    Prompt a enviar ao Claude Code. Enviado por stdin. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando ("(Get-Content ...)") na linha de comando do chamador (sem comando
    composto = sem prompt de autorizacao desnecessario no harness). O prompt ja vai por stdin;
    -MessagePath muda so a origem do texto.
.PARAMETER Model
    Modelo aceito pelo Claude Code. Default: claude-opus-4-8.
.PARAMETER PermissionMode
    Modo de permissao do Claude Code. Default: plan.
.PARAMETER Tools
    Lista de ferramentas disponiveis. Default: Read,Glob,Grep. Use "" para desabilitar todas
    (vira --tools "" na CLI) ou "default" para liberar o conjunto padrao completo da CLI.
.PARAMETER Cd
    Diretorio de trabalho do processo Claude Code. Default: diretorio atual do chamador.
.PARAMETER ClaudeExe
    Forca caminho de claude.exe.
.PARAMETER TimeoutSec
    Tempo maximo de espera. Modelos externos podem ser lentos.
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
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Le como UTF-8 antes de qualquer uso.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

if ($PSBoundParameters.ContainsKey('PermissionMode') -and $PermissionMode -eq 'bypassPermissions') {
    throw 'BLOCK: Invoke-ClaudeCode.ps1 nao permite PermissionMode=bypassPermissions.'
}

$exe = Resolve-ClaudeCodeExe -Override $ClaudeExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$arguments = @(
    '-p',
    '--model', $Model,
    '--output-format', 'text',
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

$in = (New-TemporaryFile).FullName
$out = (New-TemporaryFile).FullName
$err = (New-TemporaryFile).FullName
Set-Content -LiteralPath $in -Value $Message -Encoding utf8 -NoNewline

try {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $workDir `
        -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err `
        -RedirectStandardInput $in
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Claude Code excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($stdoutText)) {
        return $stdoutText.TrimEnd("`r", "`n")
    }

    $errMsg = Get-ClaudeCodeErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) {
        throw "BLOCK: Claude Code retornou erro: $errMsg"
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Claude Code saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Claude Code nao produziu resposta.'
}
finally {
    Remove-Item -LiteralPath $in, $out, $err -Force -ErrorAction SilentlyContinue
}
