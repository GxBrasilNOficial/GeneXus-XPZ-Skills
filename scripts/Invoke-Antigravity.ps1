#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Antigravity CLI (agy, sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend antigravity da skill xpz-llm-delegate. Usa `agy -p` com `--mode plan`
    e `--output-format json`, modo consultivo/read-only.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir ao Antigravity. Antes de
    enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1 -Backend antigravity.
.PARAMETER Message
    Prompt a enviar ao Antigravity CLI. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando na linha de comando do chamador. ATENCAO: este adapter e argument-based
    (o prompt vai no argv via runner), entao -MessagePath NAO levanta o teto ~32KB do command line
    do Windows; um guard fail-closed (~30000 chars) recusa prompts grandes.
.PARAMETER Model
    Modelo aceito pelo Antigravity CLI. Default: gemini-3.6-flash-high.
.PARAMETER Mode
    Modo de execucao do Antigravity CLI. Somente 'plan' e permitido na delegacao XPZ. Default: plan.
.PARAMETER Cd
    Diretorio de trabalho do processo Antigravity. Default: diretorio atual do chamador.
.PARAMETER AntigravityExe
    Forca caminho do executavel agy.exe.
.PARAMETER TimeoutSec
    Tempo maximo de espera em segundos. Default: 300.
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model = 'gemini-3.6-flash-high',
    [ValidateSet('plan')] [string] $Mode = 'plan',
    [string] $Cd,
    [string] $AntigravityExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'AntigravityCliSupport.ps1')

# $Mode e barrado em tempo de binding pelo [ValidateSet('plan')] na assinatura; nao ha fluxo
# alternativo a proteger aqui (paridade com Invoke-Gemini.ps1 / Invoke-Copilot.ps1).

# Prompt: inline (-Message) ou de arquivo (-MessagePath, UTF-8). Le ANTES do guard de tamanho.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

$MaxArgvPromptChars = 30000
if ($Message.Length -gt $MaxArgvPromptChars) {
    throw "BLOCK: prompt com $($Message.Length) caracteres excede a margem de $MaxArgvPromptChars para o adapter argument-based Antigravity (o prompt vai no argv; teto ~32767 do command line do Windows). Use prompt menor ou um backend stdin-based (Codex/Claude Code/opencode)."
}

$exe = Resolve-AntigravityExe -Override $AntigravityExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')

$rawModel = $Model.Trim()
if ($rawModel -like 'antigravity/*') {
    $rawModel = ($rawModel -split '/', 2)[1].Trim()
}
if ([string]::IsNullOrWhiteSpace($rawModel)) { $rawModel = 'gemini-3.6-flash-high' }

$request = [ordered]@{
    exe          = $exe
    prompt       = $Message
    model        = $rawModel
    mode         = $Mode
    timeoutSec   = $TimeoutSec
    stdoutPath   = $out.FullName
    stderrPath   = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8

@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$agyArgs = @(
    '-p', [string]$req.prompt,
    '--mode', [string]$req.mode,
    '--output-format', 'json',
    '--print-timeout', "$([string]$req.timeoutSec)s",
    '--model', [string]$req.model
)
# Stdin fechado ($null) para agy nao travar aguardando TTY
$null | & ([string]$req.exe) @agyArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

$proc = $null
try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'pwsh'
    $psi.ArgumentList.Add('-NoProfile')
    $psi.ArgumentList.Add('-File')
    $psi.ArgumentList.Add($runner)
    $psi.ArgumentList.Add($req.FullName)
    $psi.WorkingDirectory = $workDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $finished = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $finished) {
        try { $proc.Kill($true) } catch { }
        throw "BLOCK: timeout de $($TimeoutSec)s atingido na execucao do Antigravity CLI."
    }

    $stdoutText = Get-Content -LiteralPath $out.FullName -Raw -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err.FullName -Raw -ErrorAction SilentlyContinue

    if ($proc.ExitCode -ne 0) {
        $errMsg = Get-AntigravityErrorMessage -StdoutText $stdoutText -StderrText $stderrText
        if ([string]::IsNullOrWhiteSpace($errMsg)) {
            $errMsg = "processo finalizado com codigo $($proc.ExitCode)"
        }
        throw "BLOCK: erro na execucao do Antigravity CLI: $errMsg"
    }

    if ([string]::IsNullOrWhiteSpace($stdoutText)) {
        throw "BLOCK: Antigravity CLI retornou resposta vazia."
    }

    $isJson = $false
    $respStatus = $null
    $respText = $null
    try {
        $jsonResp = $stdoutText | ConvertFrom-Json
        $respStatus = [string]$jsonResp.status
        $respText = [string]$jsonResp.response
        $isJson = $true
    } catch {
        # ConvertFrom-Json em PS 7.4 lanca Microsoft.PowerShell.Commands.JsonConvertionException
        # (herda de System.SystemException, nao de System.Text.Json.JsonException). Catch sem
        # filtro de tipo e robusto sob StrictMode e cobre qualquer falha de parse, devolvendo
        # o fluxo ao fallback de texto bruto abaixo (paridade com o comentario da funcao).
        $isJson = $false
    }

    if ($isJson) {
        if ($respStatus -and $respStatus -ne 'SUCCESS') {
            throw "BLOCK: Antigravity CLI retornou status '$respStatus'."
        }
        return $respText.Trim()
    }

    # Fallback a texto bruto se nao for JSON - mas FAIL-CLOSED contra erro conhecido.
    # Sem este guard, um CLI que sai 0 e escreve texto humano no stdout tem esse texto devolvido
    # como PARECER do modelo. Nao e hipotetico: medido em 2026-08-06 no Gemini CLI (mesma familia,
    # sem credencial em cache), que imprime "Opening authentication page in your browser..." no
    # stdout e sai 0. Como `responded` no dispatcher e mecanico (texto nao-vazio basta), uma falha
    # de autenticacao entraria no recibo do painel como revisor que RESPONDEU, contando para o piso
    # de diversidade. O fallback segue existindo para stdout que nao e JSON NEM casa erro conhecido
    # (resiliencia a mudanca de formato do CLI); o que ele deixa de fazer e promover erro a parecer.
    $rawErrMsg = Get-AntigravityErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($rawErrMsg) {
        throw "BLOCK: Antigravity CLI nao retornou JSON e a saida casa erro conhecido (exit 0): $rawErrMsg"
    }

    $cleanText = [regex]::Replace([string]$stdoutText, '\x1B\[[0-9;]*[a-zA-Z]', '').Trim()
    return $cleanText

} finally {
    if ($null -ne $proc) { $proc.Dispose() }
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
