#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Gemini CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend gemini da skill xpz-llm-delegate. Usa `gemini -p` com `--approval-mode plan`
    e `--output-format json`, modo consultivo/read-only comprovado nos testes locais.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir ao Google. Antes de
    enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1 -Backend
    gemini.
.PARAMETER Message
    Prompt a enviar ao Gemini. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando ("(Get-Content ...)") na linha de comando do chamador. ATENCAO:
    este adapter e argument-based (o prompt vai no argv via runner), entao -MessagePath NAO
    levanta o teto ~32KB do command line do Windows; um guard fail-closed (~30000 chars) recusa
    prompts grandes. So os adapters stdin-based (Codex/Claude Code/opencode) sao imunes ao teto.
.PARAMETER Model
    Modelo aceito pelo Gemini CLI. Default: gemini-3-flash-preview.
.PARAMETER ApprovalMode
    Modo de aprovacao do Gemini CLI. Default: plan.
.PARAMETER Cd
    Diretorio de trabalho do processo Gemini. Default: diretorio atual do chamador.
.PARAMETER GeminiExe
    Forca caminho do comando gemini.
.PARAMETER TimeoutSec
    Tempo maximo de espera.
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model = 'gemini-3-flash-preview',
    [ValidateSet('default', 'auto_edit', 'yolo', 'plan')] [string] $ApprovalMode = 'plan',
    [string] $Cd,
    [string] $GeminiExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'GeminiCliSupport.ps1')

if ($ApprovalMode -ne 'plan') {
    throw 'BLOCK: Invoke-Gemini.ps1 permite somente ApprovalMode=plan na delegacao XPZ.'
}

# Prompt: inline (-Message) ou de arquivo (-MessagePath, UTF-8). Le ANTES do guard de tamanho.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

# Guard de tamanho fail-closed (cobre -Message E -MessagePath). Este adapter e argument-based:
# o prompt vai no argv do runner, entao acima da margem o command line do Windows estoura. O
# limite e HEURISTICO em chars (UTF-16 code units), nao em bytes: margem conservadora sob o teto
# ~32767 do command line, reservando espaco para as demais flags. -MessagePath NAO levanta o teto.
$MaxArgvPromptChars = 30000
if ($Message.Length -gt $MaxArgvPromptChars) {
    throw "BLOCK: prompt com $($Message.Length) caracteres excede a margem de $MaxArgvPromptChars para o adapter argument-based Gemini (o prompt vai no argv; teto ~32767 do command line do Windows). Use prompt menor ou um backend stdin-based (Codex/Claude Code/opencode). Migracao do Gemini a stdin: follow-up em 999-ideias-pendentes.md."
}

$exe = Resolve-GeminiExe -Override $GeminiExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')
$request = [ordered]@{
    exe = $exe
    prompt = $Message
    model = $Model
    approvalMode = $ApprovalMode
    stdoutPath = $out.FullName
    stderrPath = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$gmArgs = @(
    '-p', [string]$req.prompt,
    '--approval-mode', [string]$req.approvalMode,
    '--output-format', 'json',
    '--model', [string]$req.model
)
# stdin fechado ($null = EOF puro, sem bytes) para o gemini nao travar lendo o stdin
# herdado de uma shell headless sem TTY. Depende deste runner ser 'pwsh -File' (nao -Command).
$null | & ([string]$req.exe) @gmArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

try {
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runner, '-RequestPath', $req.FullName) `
        -WorkingDirectory $workDir -NoNewWindow -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Gemini CLI excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($stdoutText)) {
        $json = $null
        try { $json = $stdoutText | ConvertFrom-Json } catch {
            # O CLI pode sair 0 e ainda assim escrever TEXTO HUMANO no stdout em vez do JSON -
            # medido em 2026-08-06 com o gemini sem credencial em cache, que imprime o prompt
            # interativo de login ("Opening authentication page in your browser..."). Antes desta
            # ordem, o parse estourava aqui e o adapter morria com "JSON invalido: Unexpected
            # character... O" - o 'O' de "Opening" -, sem NUNCA consultar Get-GeminiErrorMessage,
            # que fica adiante e teria achado o motivo real. Consultar o extrator ANTES de
            # desistir: erro de auth/servico vira mensagem acionavel; so o que ele nao reconhece
            # e que continua sendo reportado como contrato JSON quebrado, agora com uma amostra
            # do stdout para o diagnostico nao ficar cego.
            $parseErr = $_.Exception.Message
            $errMsgOnParse = Get-GeminiErrorMessage -StdoutText $stdoutText -StderrText $stderrText
            if ($errMsgOnParse) { throw "BLOCK: Gemini CLI retornou erro: $errMsgOnParse" }
            $amostra = ([string]$stdoutText).Trim()
            if ($amostra.Length -gt 400) { $amostra = $amostra.Substring(0, 400) + '...' }
            throw "BLOCK: Gemini CLI retornou JSON invalido: $parseErr`nstdout:`n$amostra"
        }
        if ($json.PSObject.Properties['response'] -and -not [string]::IsNullOrWhiteSpace([string]$json.response)) {
            return ([string]$json.response).TrimEnd("`r", "`n")
        }
    }

    $errMsg = Get-GeminiErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: Gemini CLI retornou erro: $errMsg" }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Gemini CLI saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Gemini CLI nao produziu response no JSON.'
}
finally {
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
